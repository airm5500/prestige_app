// lib/nouvelle_interface/vague2/ca_zone_vague2.dart
// Menu « CA emplacement / famille » (web « cazonegeomanager »), onglet Comparatif, en LECTURE SEULE :
//  - GET /ca-zone-geo?typePeriode=&dtStart=&dtEnd=&regroupement=&zoneId=&familleId=&grossisteId= ;
//    période : 3 semaines (par défaut, chargée à l'ouverture), 3 mois, 6 mois, 3 ans, période libre (dates
//    contrôlées : début ≤ fin, rien dans le futur, 3 ans au plus). 3 ans (ou période libre de plus d'un an) est un
//    choix normal : indication discrète pendant le chargement, « Annuler », délai d'attente plus long mais borné,
//    jamais de relance automatique ;
//  - regroupement Emplacement / Famille / Emplacement et famille, filtres emplacement, famille, grossiste à CHOIX
//    MULTIPLE (cases à cocher, « Tout » / « Aucun », compteur ; feuille des filtres ; listes /common/rayons,
//    /common/famillearticles, /common/grossiste), envoyés comme le web : identifiants séparés par des virgules
//    (« Z1,Z2 ») ; aucun coché ou tout coché = aucun filtre (paramètre vide) ;
//  - colonnes dynamiques t_<cle> (montant), q_<cle> (quantité), e_<cle> (évolution) par tranche : une carte par
//    ligne sur téléphone (tranches en liste, évolution en flèche + texte), tableau dense sur tablette ; totaux
//    généraux en cartes ;
//  - détail d'une ligne (GET /ca-zone-geo/detail) : produits de la ligne. Pas de « Créer inventaire ».
import 'package:flutter/material.dart';

import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/periode.dart';
import 'commun_vague2.dart';
import 'donnees_vague2.dart';

/// Tranches montrées sur la carte d'une ligne (les plus récentes) ; toutes dans le détail.
const tranchesSurCarte = 6;

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class CaZoneScreen extends StatefulWidget {
  final DateTime Function() maintenant;
  final FiltresCa filtresInitiaux;
  const CaZoneScreen({super.key, this.maintenant = DateTime.now, this.filtresInitiaux = const FiltresCa()});

  @override
  State<CaZoneScreen> createState() => _CaZoneScreenState();
}

class _CaZoneScreenState extends State<CaZoneScreen> with ChargementSuivi<CaZoneScreen, ComparatifCa> {
  late FiltresCa _filtres = widget.filtresInitiaux;
  FiltresCa? _enCalcul;
  final _options = <String, List<OptionListe>>{};
  final _erreursOptions = <String, Object>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calculer();
    });
  }

  void _calculer() {
    final f = _filtres;
    _enCalcul = f;
    charger(() => ApiCaZone.comparatif(context, f, maintenant: widget.maintenant()));
  }

  void _appliquer(FiltresCa f) {
    setState(() => _filtres = f);
    _calculer();
  }

  Future<void> _choisirType(TypePeriodeCa t) async {
    if (t != TypePeriodeCa.libre) {
      _appliquer(_filtres.copie(type: t));
      return;
    }
    final now = widget.maintenant();
    final aujourdhui = Periode.jour(now);
    final r = await showDateRangePicker(
      context: context,
      firstDate: ControlePeriode.borneMin,
      lastDate: aujourdhui,
      initialDateRange: DateTimeRange(start: _filtres.debut ?? aujourdhui.subtract(const Duration(days: 30)), end: _filtres.fin ?? aujourdhui),
      locale: const Locale('fr', 'FR'),
      helpText: 'Période libre',
      saveText: 'Valider',
    );
    if (r == null || !mounted) return;
    final erreur = ControlePeriode.erreur(r.start, r.end, now);
    if (erreur != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erreur)));
      return;
    }
    _appliquer(_filtres.copie(type: TypePeriodeCa.libre, debut: Periode.jour(r.start), fin: Periode.jour(r.end)));
  }

  /// Change quand une liste arrive (la feuille des filtres se redessine).
  final _versionOptions = ValueNotifier<int>(0);

  @override
  void dispose() {
    _versionOptions.dispose();
    super.dispose();
  }

  Future<void> _chargerOption(String route, String quoi) async {
    if (_options.containsKey(route)) return;
    _erreursOptions.remove(route);
    try {
      final o = await ApiVague2.options(context, route, quoi);
      _options[route] = o;
    } catch (e) {
      _erreursOptions[route] = e;
    }
    if (!mounted) return;
    setState(() {});
    _versionOptions.value++;
  }

  Future<void> _ouvrirFiltres() async {
    var f = _filtres;
    _chargerOption(ApiVague2.routeRayons, 'la liste des emplacements');
    _chargerOption(ApiVague2.routeFamilles, 'la liste des familles');
    _chargerOption(ApiVague2.routeGrossistes, 'la liste des grossistes');
    final ok = await ouvrirFeuilleFiltres(
      context,
      titre: 'Regroupement et filtres',
      effacer: () => f = f.copie(regroupement: RegroupementCa.zone, zones: const [], familles: const [], grossistes: const []),
      contenu: (ctx, setState) => ValueListenableBuilder<int>(
        valueListenable: _versionOptions,
        builder: (_, __, ___) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Regrouper par', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          PucesChoix<RegroupementCa>(
            choix: [for (final r in RegroupementCa.values) (r, r.libelle)],
            valeur: f.regroupement,
            cle: (r, _) => Key('regroupement_${r.code}'),
            onChanged: (r) => setState(() => f = f.copie(regroupement: r)),
          ),
          const SizedBox(height: 14),
          ChoixMultiple(
            key: const Key('filtre_emplacement'),
            cle: 'emplacement',
            libelle: 'Emplacements',
            icone: Icons.shelves,
            options: _options[ApiVague2.routeRayons],
            erreur: _erreursOptions[ApiVague2.routeRayons],
            valeurs: f.zones,
            onChanged: (v) => setState(() => f = f.copie(zones: v)),
          ),
          const SizedBox(height: 12),
          ChoixMultiple(
            key: const Key('filtre_famille'),
            cle: 'famille',
            libelle: 'Familles',
            icone: Icons.category_outlined,
            options: _options[ApiVague2.routeFamilles],
            erreur: _erreursOptions[ApiVague2.routeFamilles],
            valeurs: f.familles,
            onChanged: (v) => setState(() => f = f.copie(familles: v)),
          ),
          const SizedBox(height: 12),
          ChoixMultiple(
            key: const Key('filtre_grossiste'),
            cle: 'grossiste',
            libelle: 'Grossistes',
            icone: Icons.local_shipping_outlined,
            options: _options[ApiVague2.routeGrossistes],
            erreur: _erreursOptions[ApiVague2.routeGrossistes],
            valeurs: f.grossistes,
            onChanged: (v) => setState(() => f = f.copie(grossistes: v)),
          ),
        ]),
      ),
    );
    if (ok && mounted) {
      List<String>? ids(String route) => _options[route]?.map((o) => o.id).toList();
      _appliquer(f.copie(
        zones: FiltresCa.normaliser(f.zones, ids(ApiVague2.routeRayons)),
        familles: FiltresCa.normaliser(f.familles, ids(ApiVague2.routeFamilles)),
        grossistes: FiltresCa.normaliser(f.grossistes, ids(ApiVague2.routeGrossistes)),
      ));
    }
  }

  /// « Emplacement : RAYON A » (un seul) ou « Emplacements : 3 sélectionnés ».
  String _etiquette(String singulier, String pluriel, String route, List<String> ids) =>
      ids.length == 1 ? '$singulier : ${_libelleOption(route, ids.single)}' : '$pluriel : ${ids.length} sélectionnés';

  String _libelleOption(String route, String id) => (_options[route] ?? const <OptionListe>[]).where((o) => o.id == id).firstOrNull?.libelle ?? id;

  String get _resumePeriode {
    final d = donnees;
    if (d != null && d.debut.isNotEmpty) return '${_filtres.type.libelle} · du ${dateApiLisible(d.debut)} au ${dateApiLisible(d.fin)}';
    if (_filtres.type == TypePeriodeCa.libre && _filtres.debut != null) return 'Période libre · du ${_date(_filtres.debut!)} au ${_date(_filtres.fin!)}';
    return _filtres.type.libelle;
  }

  @override
  Widget build(BuildContext context) {
    final d = donnees;
    final f = _enCalcul ?? _filtres;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CA emplacement / famille'),
        actions: [
          BoutonFiltres(actifs: _filtres.actifs + (_filtres.regroupement == RegroupementCa.zone ? 0 : 1), onPressed: _ouvrirFiltres),
          IconButton(key: const Key('ca_actualiser'), tooltip: 'Actualiser', icon: const Icon(Icons.refresh), onPressed: enCours ? null : _calculer),
        ],
      ),
      body: ListView(key: const Key('defilement_ca'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        SingleChildScrollView(
          key: const Key('ca_periodes'),
          scrollDirection: Axis.horizontal,
          child: PucesChoix<TypePeriodeCa>(
            choix: [for (final t in TypePeriodeCa.values) (t, t.libelle)],
            valeur: _filtres.type,
            cle: (t, _) => Key('periode_ca_${t.code}'),
            onChanged: _choisirType,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
          child: Text('$_resumePeriode · par ${_filtres.regroupement.libelle.toLowerCase()}',
              key: const Key('ca_resume'), style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        if (_filtres.actifs > 0)
          Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (_filtres.zones.isNotEmpty) Etiquette(_etiquette('Emplacement', 'Emplacements', ApiVague2.routeRayons, _filtres.zones)),
            if (_filtres.familles.isNotEmpty) Etiquette(_etiquette('Famille', 'Familles', ApiVague2.routeFamilles, _filtres.familles)),
            if (_filtres.grossistes.isNotEmpty) Etiquette(_etiquette('Grossiste', 'Grossistes', ApiVague2.routeGrossistes, _filtres.grossistes)),
            TextButton(
              key: const Key('filtres_retirer'),
              onPressed: () => _appliquer(_filtres.copie(zones: const [], familles: const [], grossistes: const [])),
              child: const Text('Retirer les filtres'),
            ),
          ]),
        const SizedBox(height: 8),
        if (enCours)
          ChargementAnnulable(
            texte: 'Calcul du chiffre d\'affaires…',
            indication: f.long ? (f.type == TypePeriodeCa.troisAns ? 'Calcul sur 3 ans, peut prendre un moment.' : 'Longue période, le calcul peut prendre un moment.') : null,
            annuler: abandonner,
          ),
        if (erreur != null) EtatErreur(erreur: erreur!, reessayer: _calculer),
        if (!enCours && d == null && erreur == null)
          const EtatVide(key: Key('ca_annule'), titre: 'Aucun calcul affiché', texte: 'Choisissez une période ou touchez ⟳.', icone: Icons.touch_app_outlined),
        if (d != null && !enCours) ..._resultat(d, _enCalcul ?? _filtres),
      ]),
    );
  }

  List<Widget> _resultat(ComparatifCa d, FiltresCa f) {
    if (d.lignes.isEmpty) {
      return [const EtatVide(titre: 'Aucune vente', texte: 'Aucun chiffre d\'affaires sur cette période pour ces filtres.', icone: Icons.search_off)];
    }
    final premiere = d.tranches.isEmpty ? null : d.tranches.first.libelle, derniere = d.tranches.isEmpty ? null : d.tranches.last.libelle;
    return [
      GrilleChiffres([
        ChiffreCle(libelle: 'Chiffre d\'affaires', valeur: formaterMontant(d.totalGeneral), enAvant: true, id: 'ca_total'),
        ChiffreCle(libelle: 'Marge', valeur: formaterMontant(d.margeGenerale), detail: 'taux ${pourcentTexte(d.pourcentageMargeGeneral)}', id: 'ca_marge'),
        _CarteEvolution(
            libelle: premiere == null ? 'Évolution' : 'Évolution de $premiere à $derniere', valeur: d.evolutionGenerale),
        ChiffreCle(libelle: 'Lignes', valeur: grouperMilliers(d.lignes.length), detail: '${d.tranches.length} tranches', id: 'ca_lignes'),
      ]),
      const TitreSection('Total par tranche'),
      CarteSection(key: const Key('ca_totaux_tranches'), enfants: [
        for (final t in d.tranches) _LigneTranche(t, d.totauxTranches[t.cle] ?? 0, d.evolutionsTranches[t.cle]),
      ]),
      TitreSection('Par ${f.regroupement.libelle.toLowerCase()} (${grouperMilliers(d.lignes.length)})'),
      // Largeur utile = largeur de l'écran − marges de la liste (16 + 16), comme le LayoutBuilder d'origine.
      if (MediaQuery.sizeOf(context).width - 32 >= largeurTableau)
        LayoutBuilder(builder: (context, c) => _tableau(d, f, c.maxWidth))
      else
        // 3.10.3 : une carte par élément de la liste défilante (construite à la demande), et non une seule colonne de
        // toutes les cartes : sur téléphone, l'arrivée de la colonne entière à l'écran coûtait une image de 0,4 à
        // 0,7 s (relevé par test/performance/listes_longues_test.dart, 60 tranches × 40 lignes).
        for (var i = 0; i < d.lignes.length; i++) _carte(d, f, d.lignes[i], i),
    ];
  }

  Widget _carte(ComparatifCa d, FiltresCa f, LigneCa l, int i) {
    final tranches = d.tranches.length <= tranchesSurCarte ? d.tranches : d.tranches.sublist(d.tranches.length - tranchesSurCarte);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarteBande(
        key: Key('ligne_ca_$i'),
        bande: Charte.navy2,
        onTap: () => _ouvrir(d, f, l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(l.titre(f.regroupement), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Charte.encre))),
            Text(formaterMontant(l.total), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Charte.navy)),
            const Icon(Icons.chevron_right, color: Charte.gris),
          ]),
          Variation(l.evolution, suffixe: '(1re à dernière tranche)'),
          const Divider(height: 14),
          for (final t in tranches) _LigneTranche(t, l.de(t.cle).montant, l.de(t.cle).evolution, quantite: l.de(t.cle).quantite),
          if (d.tranches.length > tranchesSurCarte)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('+ ${d.tranches.length - tranchesSurCarte} tranches plus anciennes : touchez pour le détail',
                  style: const TextStyle(color: Charte.gris, fontSize: 12.5)),
            ),
        ]),
      ),
    );
  }

  Widget _tableau(ComparatifCa d, FiltresCa f, double largeur) {
    final colonnes = [
      const Colonne('Ligne', flex: 5),
      for (final t in d.tranches) Colonne('${t.libelle}${t.enCours ? ' (en cours)' : ''}', flex: 3, droite: true),
      const Colonne('Total', flex: 3, droite: true),
      const Colonne('Évol.', flex: 2, droite: true),
    ];
    String cellule(int montant, double? e) => e == null ? formaterMontant(montant) : '${formaterMontant(montant)}\n${variationTexte(e)}';
    final tableau = TableauDense(
      colonnes: colonnes,
      onTap: (i) => _ouvrir(d, f, d.lignes[i]),
      lignes: [
        for (final l in d.lignes)
          [l.titre(f.regroupement), for (final t in d.tranches) cellule(l.de(t.cle).montant, l.de(t.cle).evolution), formaterMontant(l.total), variationTexte(l.evolution)],
      ],
      total: ['Total', for (final t in d.tranches) cellule(d.totauxTranches[t.cle] ?? 0, d.evolutionsTranches[t.cle]), formaterMontant(d.totalGeneral), variationTexte(d.evolutionGenerale)],
    );
    final besoin = 260.0 + d.tranches.length * 140 + 260;
    if (besoin <= largeur) return tableau;
    return Scrollbar(
      child: SingleChildScrollView(key: const Key('ca_tableau_defilement'), scrollDirection: Axis.horizontal, child: SizedBox(width: besoin, child: tableau)),
    );
  }

  void _ouvrir(ComparatifCa d, FiltresCa f, LigneCa l) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaLigneDetailScreen(filtres: f, ligne: l, tranches: d.tranches, maintenant: widget.maintenant)));
}

class _CarteEvolution extends StatelessWidget {
  final String libelle;
  final double? valeur;
  const _CarteEvolution({required this.libelle, required this.valeur});

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('ca_evolution'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(libelle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Charte.gris, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Variation(valeur),
        ]),
      );
}

/// Une tranche : libellé (« en cours » signalé), montant, quantité, évolution par rapport à la tranche précédente.
class _LigneTranche extends StatelessWidget {
  final TrancheCa t;
  final int montant;
  final double? evolution;
  final int? quantite;
  const _LigneTranche(this.t, this.montant, this.evolution, {this.quantite});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 2, children: [
          Text('${t.libelle}${t.enCours ? ' (en cours)' : ''}',
              style: TextStyle(color: t.enCours ? Charte.gris : Charte.encre, fontSize: 14, fontWeight: FontWeight.w600)),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${formaterMontant(montant)}${quantite == null ? '' : ' · ${grouperMilliers(quantite!)} u.'}',
                style: const TextStyle(color: Charte.encre, fontSize: 14, fontWeight: FontWeight.w700)),
            if (evolution != null) Variation(evolution, compacte: true),
          ]),
        ]),
      );
}

/// Détail d'une ligne : toutes ses tranches et les produits (GET /ca-zone-geo/detail).
class CaLigneDetailScreen extends StatefulWidget {
  final FiltresCa filtres;
  final LigneCa ligne;
  final List<TrancheCa> tranches;
  final DateTime Function() maintenant;
  const CaLigneDetailScreen({super.key, required this.filtres, required this.ligne, required this.tranches, this.maintenant = DateTime.now});

  @override
  State<CaLigneDetailScreen> createState() => _CaLigneDetailScreenState();
}

class _CaLigneDetailScreenState extends State<CaLigneDetailScreen> with ChargementSuivi<CaLigneDetailScreen, DetailLigneCa> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  void _charger() {
    if (mounted) charger(() => ApiCaZone.detail(context, widget.filtres, widget.ligne, maintenant: widget.maintenant()));
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.ligne, f = widget.filtres, d = donnees;
    return Scaffold(
      appBar: AppBar(title: Text(l.titre(f.regroupement))),
      body: ListView(key: const Key('defilement_detail_ca'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        CarteSection(titre: 'Chiffre d\'affaires par tranche', icone: Icons.bar_chart, enfants: [
          for (final t in widget.tranches) _LigneTranche(t, l.de(t.cle).montant, l.de(t.cle).evolution, quantite: l.de(t.cle).quantite),
          const Divider(height: 16),
          LigneDetail('Total', formaterMontant(l.total), gras: true),
          LigneDetail('Marge', '${formaterMontant(l.marge)} (${pourcentTexte(l.pourcentageMarge)})'),
          Padding(padding: const EdgeInsets.only(top: 4), child: Variation(l.evolution, suffixe: '(1re à dernière tranche)')),
        ]),
        const TitreSection('Produits de la ligne'),
        if (enCours)
          ChargementAnnulable(
            texte: 'Chargement des produits…',
            indication: f.long ? 'Longue période, le calcul peut prendre un moment.' : null,
            annuler: f.long ? abandonner : null,
          ),
        if (erreur != null) EtatErreur(erreur: erreur!, reessayer: _charger),
        if (!enCours && d == null && erreur == null)
          OutlinedButton(key: const Key('detail_ca_relancer'), onPressed: _charger, child: const Text('Charger les produits')),
        if (d != null && !enCours) ...[
          if (d.produits.isEmpty)
            const EtatVide(titre: 'Aucun produit')
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('${grouperMilliers(d.produits.length)} produits · ${formaterMontant(d.montant)} · ${grouperMilliers(d.quantite)} unités',
                  key: const Key('detail_ca_total'), style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
            ),
            ListeOuTableau(
              nombre: d.produits.length,
              colonnes: const [
                Colonne('CIP', flex: 2),
                Colonne('Produit', flex: 5),
                Colonne('Qté', flex: 2, droite: true),
                Colonne('Montant', flex: 3, droite: true),
                Colonne('Marge', flex: 3, droite: true),
                Colonne('Taux', flex: 2, droite: true),
              ],
              cellules: (i) {
                final p = d.produits[i];
                return [p.cip, p.designation, grouperMilliers(p.quantite), formaterMontant(p.montant), formaterMontant(p.marge), pourcentTexte(p.pourcentageMarge)];
              },
              carte: (i) {
                final p = d.produits[i];
                return CarteLigne(
                  titre: p.designation.isEmpty ? 'Produit' : p.designation,
                  lignes: [
                    [if (p.cip.isNotEmpty) 'CIP ${p.cip}', '${grouperMilliers(p.quantite)} unités'].join(' · '),
                    'Marge ${formaterMontant(p.marge)} (${pourcentTexte(p.pourcentageMarge)})',
                  ],
                  libelleValeur: 'Montant',
                  valeur: formaterMontant(p.montant),
                );
              },
            ),
          ],
        ],
      ]),
    );
  }
}
