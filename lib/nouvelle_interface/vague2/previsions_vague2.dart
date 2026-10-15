// lib/nouvelle_interface/vague2/previsions_vague2.dart
// Menu « Prévisions » (web « analysecommande ») en LECTURE SEULE, trois onglets :
//  - Prévisions : synthèse du dernier calcul (GET /analyse-commande/tableau) en cartes, filtres À commander /
//    En rupture / Surstock / Rotation lente / Peu fiables (puces), méthode et stock (feuille des filtres), recherche
//    contrôlée (anti-rebond), pages de 25 lignes (GET /analyse-commande/previsions) ; détail d'un produit
//    (GET /analyse-commande/produit/{id} : historique mensuel en barres, méthode retenue, détail du calcul) et ses
//    équivalents à la demande (GET /analyse-commande/equivalents/{id}) ;
//  - Analyse d'une suggestion / commande : liste (GET /analyse-commande/a-analyser, lue à la première ouverture de
//    l'onglet), puis analyse (GET /analyse-commande/analyse?type=&id=) : résumé et lignes avec alertes ;
//  - Analyse de la demande : calcul SEULEMENT sur « Calculer » (GET /analyse-commande/demande?mois=12|24|36),
//    12 mois par défaut ; 24 / 36 mois proposés normalement, chargement annulable avec une indication discrète.
// Aucune écriture : ni « appliquer », ni génération de suggestion / d'inventaire, ni recalcul, ni paramètres.
import 'package:flutter/material.dart';

import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import 'commun_vague2.dart';
import 'donnees_vague2.dart';

class PrevisionsScreen extends StatefulWidget {
  final int ongletInitial;
  const PrevisionsScreen({super.key, this.ongletInitial = 0});

  @override
  State<PrevisionsScreen> createState() => _PrevisionsScreenState();
}

class _PrevisionsScreenState extends State<PrevisionsScreen> with SingleTickerProviderStateMixin {
  late final _onglets = TabController(length: 3, vsync: this, initialIndex: widget.ongletInitial.clamp(0, 2));
  final _cleListe = GlobalKey<_OngletPrevisionsState>();

  @override
  void initState() {
    super.initState();
    _onglets.addListener(() {
      if (mounted && !_onglets.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i = _onglets.index;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prévisions'),
        actions: [
          if (i == 0) ...[
            BoutonFiltres(actifs: _cleListe.currentState?._filtres.actifs ?? 0, onPressed: () => _cleListe.currentState?._ouvrirFiltres()),
            IconButton(
              key: const Key('previsions_actualiser'),
              tooltip: 'Actualiser',
              icon: const Icon(Icons.refresh),
              onPressed: () => _cleListe.currentState?._toutRecharger(),
            ),
          ],
        ],
        bottom: ongletsBlancs(_onglets, const ['Prévisions', 'Analyse suggestion / commande', 'Analyse de la demande'],
            key: const Key('previsions_onglets')),
      ),
      body: IndexedStack(index: i, children: [
        _OngletPrevisions(key: _cleListe, auChangement: () => setState(() {})),
        _OngletSuggestions(actif: i == 1),
        _OngletDemande(actif: i == 2),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Onglet Prévisions
// ---------------------------------------------------------------------------------------------------------------

class _OngletPrevisions extends StatefulWidget {
  final VoidCallback auChangement;
  const _OngletPrevisions({super.key, required this.auChangement});

  @override
  State<_OngletPrevisions> createState() => _OngletPrevisionsState();
}

class _OngletPrevisionsState extends State<_OngletPrevisions> {
  FiltresPrevisions _filtres = const FiltresPrevisions();
  final _recherche = TextEditingController();

  TableauPrevisions? _tableau;
  Object? _erreurTableau;
  bool _chargementTableau = false;

  final _lignes = <LignePrevision>[];
  int _total = 0;
  bool _charge = false;
  bool _chargement = false;
  bool _chargementPlus = false;
  Object? _erreur;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _toutRecharger();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _toutRecharger() {
    _chargerTableau();
    _recharger();
  }

  Future<void> _chargerTableau() async {
    if (_chargementTableau) return;
    setState(() {
      _chargementTableau = true;
      _erreurTableau = null;
    });
    try {
      final t = await ApiPrevisions.tableau(context);
      if (mounted) setState(() => _tableau = t);
    } catch (e) {
      if (mounted) setState(() => _erreurTableau = e);
    } finally {
      if (mounted) setState(() => _chargementTableau = false);
    }
  }

  Future<void> _recharger() async {
    final g = ++_generation;
    final f = _filtres;
    setState(() {
      _chargement = true;
      _chargementPlus = false;
      _erreur = null;
    });
    try {
      final p = await ApiPrevisions.previsions(context, f);
      if (!mounted || g != _generation) return;
      setState(() {
        _lignes
          ..clear()
          ..addAll(p.lignes);
        _total = p.total;
        _charge = true;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _chargement = false;
      });
    }
  }

  Future<void> _plus() async {
    if (_chargement || _chargementPlus) return;
    final g = _generation;
    setState(() => _chargementPlus = true);
    try {
      final p = await ApiPrevisions.previsions(context, _filtres, start: _lignes.length);
      if (!mounted || g != _generation) return;
      setState(() {
        _lignes.addAll(p.lignes);
        _total = p.lignes.isEmpty ? _lignes.length : (p.total < _lignes.length ? _lignes.length : p.total);
        _chargementPlus = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _chargementPlus = false;
      });
    }
  }

  void _filtrer(FiltresPrevisions f) {
    setState(() => _filtres = f);
    widget.auChangement();
    _recharger();
  }

  Future<void> _ouvrirFiltres() async {
    var methode = _filtres.methode;
    var stock = _filtres.stock;
    final ok = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les prévisions',
      effacer: () {
        methode = MethodePrevision.toutes;
        stock = StockPrevision.tous;
      },
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Méthode de prévision', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        PucesChoix<MethodePrevision>(
          choix: [for (final m in MethodePrevision.values) (m, m.libelle)],
          valeur: methode,
          cle: (m, _) => Key('filtre_methode_${m.name}'),
          onChanged: (m) => setState(() => methode = m),
        ),
        const SizedBox(height: 14),
        const Text('Stock', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        PucesChoix<StockPrevision>(
          choix: [for (final s in StockPrevision.values) (s, s.libelle)],
          valeur: stock,
          cle: (s, _) => Key('filtre_stock_${s.name}'),
          onChanged: (s) => setState(() => stock = s),
        ),
      ]),
    );
    if (ok && mounted && (methode != _filtres.methode || stock != _filtres.stock)) {
      _filtrer(_filtres.copie(methode: methode, stock: stock));
    }
  }

  void _ouvrir(LignePrevision l) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailPrevisionScreen(id: l.id, nom: l.nom)));

  @override
  Widget build(BuildContext context) {
    final t = _tableau;
    return ListView(key: const Key('defilement_previsions'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      if (_chargementTableau && t == null) const LinearProgressIndicator(),
      if (_erreurTableau != null && t == null)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: EtatErreur(erreur: _erreurTableau!, reessayer: _chargerTableau)),
      if (t != null) _SyntheseTableau(t),
      const SizedBox(height: 8),
      PucesChoix<FiltrePrevision>(
        choix: [for (final f in FiltrePrevision.values) (f, f.libelle)],
        valeur: _filtres.filtre,
        cle: (f, _) => Key('filtre_prevision_${f.name}'),
        onChanged: (f) => _filtrer(_filtres.copie(filtre: f)),
      ),
      if (_filtres.actifs > 0)
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (_filtres.methode != MethodePrevision.toutes) Etiquette('Méthode : ${_filtres.methode.libelle}'),
          if (_filtres.stock != StockPrevision.tous) Etiquette('Stock : ${_filtres.stock.libelle}'),
          TextButton(
            key: const Key('filtres_retirer'),
            onPressed: () => _filtrer(_filtres.copie(methode: MethodePrevision.toutes, stock: StockPrevision.tous)),
            child: const Text('Retirer les filtres'),
          ),
        ]),
      const SizedBox(height: 8),
      ChampRecherche(
        controleur: _recherche,
        libelle: 'Rechercher un produit',
        aide: 'Nom ou CIP',
        onRecherche: (q) => _filtrer(_filtres.copie(recherche: q)),
      ),
      const SizedBox(height: 8),
      if (_chargement) const EtatChargement(texte: 'Chargement des prévisions…'),
      if (_erreur != null) EtatErreur(erreur: _erreur!, reessayer: _lignes.isEmpty ? _recharger : _plus),
      if (_charge && !_chargement) ...[
        if (_lignes.isEmpty && _erreur == null)
          const EtatVide(titre: 'Aucun produit', texte: 'Aucun produit ne correspond à ces filtres.', icone: Icons.search_off)
        else if (_lignes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
            child: Text('${grouperMilliers(_total)} ${_total > 1 ? 'produits' : 'produit'} · ${_filtres.filtre.libelle}',
                key: const Key('previsions_total'), style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
          ),
          ListeOuTableau(
            nombre: _lignes.length,
            onTap: (i) => _ouvrir(_lignes[i]),
            colonnes: const [
              Colonne('Produit', flex: 5),
              Colonne('Méthode', flex: 3),
              Colonne('Prévu/mois', flex: 2, droite: true),
              Colonne('Stock', flex: 2, droite: true),
              Colonne('En cours', flex: 2, droite: true),
              Colonne('Couv.', flex: 2, droite: true),
              Colonne('Fiab.', flex: 2, droite: true),
              Colonne('Recomm.', flex: 2, droite: true),
              Colonne('Valeur', flex: 3, droite: true),
            ],
            cellules: (i) {
              final l = _lignes[i];
              return [
                l.nom,
                l.methodeLibelle,
                decimalTexte(l.prevuMois),
                grouperMilliers(l.stock),
                grouperMilliers(l.enCours),
                l.couvertureTexte,
                '${l.fiabilite} %',
                grouperMilliers(l.recommande),
                formaterMontant(l.valeur),
              ];
            },
            carte: (i) {
              final l = _lignes[i];
              return CarteLigne(
                key: Key('prevision_${l.id}'),
                titre: l.nom.isEmpty ? 'Produit' : l.nom,
                etiquette: Wrap(spacing: 6, runSpacing: 4, children: [
                  Etiquette(l.methodeLibelle, ton: Ton.gris),
                  if (l.stock <= 0 && l.prevuMois >= 1) const Etiquette('Rupture', ton: Ton.rouge),
                ]),
                lignes: [
                  [if (l.cip.isNotEmpty) 'CIP ${l.cip}', if (l.grossiste.isNotEmpty) l.grossiste].join(' · '),
                  'Prévu ${decimalTexte(l.prevuMois)}/mois · stock ${grouperMilliers(l.stock)} · en cours ${grouperMilliers(l.enCours)}',
                  'Couverture ${l.couvertureTexte} · fiabilité ${l.fiabilite} %',
                ],
                libelleValeur: 'À commander',
                valeur: grouperMilliers(l.recommande),
                bande: l.recommande > 0 ? Charte.ambre : null,
                onTap: () => _ouvrir(l),
              );
            },
          ),
          PiedPagination(affichees: _lignes.length, total: _total, enCours: _chargementPlus, onPlus: _plus),
        ],
      ],
    ]);
  }
}

class _SyntheseTableau extends StatelessWidget {
  final TableauPrevisions t;
  const _SyntheseTableau(this.t);

  @override
  Widget build(BuildContext context) {
    if (!t.calcule) {
      return const Encadre(
        key: Key('previsions_non_calculees'),
        titre: 'Prévisions pas encore calculées',
        texte: 'Le calcul des prévisions est fait chaque nuit par Prestige ; revenez après le premier calcul.',
        icone: Icons.hourglass_empty,
        avertissement: true,
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GrilleChiffres([
        ChiffreCle(libelle: 'À commander', valeur: grouperMilliers(t.aCommander), detail: formaterMontant(t.valeurACommander), enAvant: true, id: 'a_commander'),
        ChiffreCle(libelle: 'En rupture', valeur: grouperMilliers(t.ruptures), detail: 'taux ${pourcentTexte(t.tauxRupture)}', id: 'ruptures'),
        ChiffreCle(libelle: 'Surstock', valeur: grouperMilliers(t.surstock), detail: 'couverture > ${t.joursSurstock} j', id: 'surstock'),
        ChiffreCle(libelle: 'Invendus', valeur: grouperMilliers(t.invendus), detail: formaterMontant(t.valeurInvendus), id: 'invendus'),
        ChiffreCle(libelle: 'Fiabilité moyenne', valeur: t.fiabilite == null ? '—' : '${t.fiabilite} %', id: 'fiabilite'),
        ChiffreCle(libelle: 'Couverture moyenne', valeur: t.couvertureMoyenne == null ? '—' : '${t.couvertureMoyenne} j', id: 'couverture'),
      ]),
      if (t.dernierCalcul.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text('Dernier calcul : ${t.dernierCalcul} · ${grouperMilliers(t.produits)} produits suivis',
              key: const Key('previsions_dernier_calcul'), style: const TextStyle(color: Charte.gris, fontSize: 13)),
        ),
      // Heure de la dernière relecture des commandes en cours (serveurs récents, demande 23) ; absente sinon.
      if (t.enCoursAJour.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
          child: Text('Commandes en cours à jour le ${t.enCoursAJour}',
              key: const Key('previsions_en_cours_a_jour'), style: const TextStyle(color: Charte.gris, fontSize: 13)),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Détail d'un produit
// ---------------------------------------------------------------------------------------------------------------

class DetailPrevisionScreen extends StatefulWidget {
  final String id;
  final String nom;
  const DetailPrevisionScreen({super.key, required this.id, this.nom = ''});

  @override
  State<DetailPrevisionScreen> createState() => _DetailPrevisionScreenState();
}

class _DetailPrevisionScreenState extends State<DetailPrevisionScreen> with ChargementSuivi<DetailPrevisionScreen, DetailPrevision> {
  Equivalents? _equivalents;
  Object? _erreurEquivalents;
  bool _chargementEquivalents = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  void _charger() {
    if (mounted) charger(() => ApiPrevisions.produit(context, widget.id));
  }

  Future<void> _chargerEquivalents() async {
    if (_chargementEquivalents) return;
    setState(() {
      _chargementEquivalents = true;
      _erreurEquivalents = null;
    });
    try {
      final e = await ApiPrevisions.equivalents(context, widget.id);
      if (mounted) setState(() => _equivalents = e);
    } catch (e) {
      if (mounted) setState(() => _erreurEquivalents = e);
    } finally {
      if (mounted) setState(() => _chargementEquivalents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = donnees;
    return Scaffold(
      appBar: AppBar(title: const Text('Prévision du produit')),
      body: ListView(key: const Key('defilement_detail_prevision'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        if (enCours) const EtatChargement(texte: 'Chargement du produit…'),
        if (erreur != null) EtatErreur(erreur: erreur!, reessayer: _charger),
        if (d != null && !enCours) ...[
          CarteSection(titre: d.ligne.nom.isEmpty ? widget.nom : d.ligne.nom, icone: Icons.medication_outlined, enfants: [
            if (d.ligne.cip.isNotEmpty) LigneDetail('CIP', d.ligne.cip),
            if (d.ligne.grossiste.isNotEmpty) LigneDetail('Grossiste', d.ligne.grossiste),
            LigneDetail('Méthode retenue', d.ligne.methodeLibelle),
            LigneDetail('Fiabilité', '${d.ligne.fiabilite} %'),
            if (d.ligne.derniereVente.isNotEmpty)
              LigneDetail('Dernière vente', '${d.ligne.derniereVente}${d.derniereVenteQte == null ? '' : ' (${grouperMilliers(d.derniereVenteQte!)} u.)'}'),
          ]),
          GrilleChiffres([
            ChiffreCle(libelle: 'Recommandé', valeur: grouperMilliers(d.ligne.recommande), detail: formaterMontant(d.ligne.valeur), enAvant: true, id: 'recommande'),
            ChiffreCle(libelle: 'Prévu / mois', valeur: decimalTexte(d.ligne.prevuMois), id: 'prevu'),
            ChiffreCle(
                libelle: 'Stock',
                valeur: grouperMilliers(d.ligne.stock),
                detail: d.rayon == null ? null : 'rayon ${grouperMilliers(d.rayon!)} · réserve ${grouperMilliers(d.reserve ?? 0)}',
                id: 'stock'),
            ChiffreCle(libelle: 'En cours', valeur: grouperMilliers(d.ligne.enCours), id: 'en_cours'),
            ChiffreCle(libelle: 'Couverture', valeur: d.ligne.couvertureTexte, id: 'couverture'),
            ChiffreCle(libelle: 'Ventes 12 mois', valeur: grouperMilliers(d.ligne.ventes12), id: 'ventes12'),
          ]),
          const TitreSection('Ventes par mois'),
          if (d.historique.isEmpty)
            const EtatVide(titre: 'Pas d\'historique', texte: 'Aucune vente mensuelle connue pour ce produit.')
          else
            CarteSection(enfants: [
              BarresHorizontales(
                key: const Key('historique_mensuel'),
                barres: [for (final (m, v) in d.historique) (m, v.toDouble(), grouperMilliers(v))],
                largeurLibelle: 70,
              ),
              if (d.prochainMois.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Prévision pour ${d.prochainMois} : ${decimalTexte(d.ligne.prevuMois)} unités',
                      style: const TextStyle(color: Charte.navy, fontWeight: FontWeight.w700)),
                ),
            ]),
          const TitreSection('Détail du calcul'),
          CarteSection(key: const Key('detail_calcul'), enfants: [
            LigneDetail('Ventes prévues par jour', decimalTexte(d.parJour, decimales: 2)),
            LigneDetail('Délai de livraison', '${d.delai} j${d.delaiOrigine.isEmpty ? '' : ' (${d.delaiOrigine})'}'),
            LigneDetail('Couverture voulue', '${d.couvertureVoulue} j'),
            LigneDetail('Besoin (par jour × (délai + couverture))', decimalTexte(d.besoin)),
            LigneDetail('Stock de sécurité', decimalTexte(d.securite)),
            LigneDetail('Stock + en cours', grouperMilliers(d.ligne.stock + d.ligne.enCours)),
            const Divider(height: 16),
            LigneDetail('Quantité recommandée', grouperMilliers(d.ligne.recommande), gras: true),
          ]),
          if (d.methodes.isNotEmpty) ...[
            const TitreSection('Méthodes comparées'),
            CarteSection(enfants: [
              for (final (m, e, retenue) in d.methodes)
                LigneDetail('${MethodePrevision.libelleDe(m)}${retenue ? ' (retenue)' : ''}', 'erreur ${decimalTexte(e, decimales: 2)}', gras: retenue),
            ]),
          ],
          const TitreSection('Équivalents'),
          if (_equivalents == null && !_chargementEquivalents && _erreurEquivalents == null)
            OutlinedButton.icon(
              key: const Key('bouton_equivalents'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _chargerEquivalents,
              icon: const Icon(Icons.swap_horiz),
              label: Text('Voir les équivalents (${grouperMilliers(d.ligne.equivalents)} en stock)'),
            ),
          if (_chargementEquivalents) const EtatChargement(texte: 'Recherche des équivalents…'),
          if (_erreurEquivalents != null) EtatErreur(erreur: _erreurEquivalents!, reessayer: _chargerEquivalents),
          if (_equivalents != null) _ListeEquivalents(_equivalents!),
        ],
      ]),
    );
  }
}

class _ListeEquivalents extends StatelessWidget {
  final Equivalents e;
  const _ListeEquivalents(this.e);

  @override
  Widget build(BuildContext context) => Column(key: const Key('liste_equivalents'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (e.avertissement.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Encadre(texte: e.avertissement, icone: Icons.info_outline, avertissement: true)),
        if (e.lignes.isEmpty)
          EtatVide(titre: 'Aucun équivalent', texte: e.message.isEmpty ? null : e.message)
        else
          for (final q in e.lignes)
            CarteLigne(
              titre: q.nom,
              etiquette: Etiquette(q.direct ? 'Équivalent direct' : 'À adapter', ton: q.direct ? Ton.vert : Ton.ambre),
              lignes: [
                [if (q.cip.isNotEmpty) 'CIP ${q.cip}', 'rayon ${grouperMilliers(q.rayon)} · réserve ${grouperMilliers(q.reserve)}'].join(' · '),
                if (q.raison.isNotEmpty) q.raison,
              ],
              libelleValeur: 'Prix',
              valeur: formaterMontant(q.prix),
            ),
      ]);
}

// ---------------------------------------------------------------------------------------------------------------
// Onglet Analyse d'une suggestion / commande
// ---------------------------------------------------------------------------------------------------------------

class _OngletSuggestions extends StatefulWidget {
  final bool actif;
  const _OngletSuggestions({required this.actif});

  @override
  State<_OngletSuggestions> createState() => _OngletSuggestionsState();
}

class _OngletSuggestionsState extends State<_OngletSuggestions> with ChargementSuivi<_OngletSuggestions, List<ElementAAnalyser>> {
  bool _demande = false;

  @override
  void initState() {
    super.initState();
    if (widget.actif) WidgetsBinding.instance.addPostFrameCallback((_) => _premiere());
  }

  @override
  void didUpdateWidget(covariant _OngletSuggestions old) {
    super.didUpdateWidget(old);
    if (widget.actif && !old.actif) WidgetsBinding.instance.addPostFrameCallback((_) => _premiere());
  }

  void _premiere() {
    if (_demande || !mounted) return;
    _demande = true;
    _charger();
  }

  void _charger() => charger(() => ApiPrevisions.aAnalyser(context));

  @override
  Widget build(BuildContext context) {
    final l = donnees;
    return ListView(key: const Key('defilement_suggestions'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      const Text('Choisissez une suggestion ou une commande en cours : chaque ligne est comparée à la prévision.',
          style: TextStyle(color: Charte.gris, fontSize: 13)),
      const SizedBox(height: 8),
      if (enCours) const EtatChargement(texte: 'Chargement des suggestions et commandes…'),
      if (erreur != null) EtatErreur(erreur: erreur!, reessayer: _charger),
      if (l != null && !enCours) ...[
        if (l.isEmpty)
          const EtatVide(titre: 'Rien à analyser', texte: 'Aucune suggestion ni commande en cours.', icone: Icons.check_circle_outline)
        else
          ListeOuTableau(
            nombre: l.length,
            onTap: (i) => _ouvrir(l[i]),
            colonnes: const [
              Colonne('Type', flex: 2),
              Colonne('Référence', flex: 3),
              Colonne('Grossiste', flex: 4),
              Colonne('Date', flex: 3),
              Colonne('Lignes', flex: 2, droite: true),
            ],
            cellules: (i) => [l[i].typeLibelle, l[i].ref, l[i].grossiste, l[i].date, grouperMilliers(l[i].lignes)],
            carte: (i) => CarteLigne(
              key: Key('a_analyser_${l[i].id}'),
              titre: l[i].ref.isEmpty ? l[i].typeLibelle : l[i].ref,
              etiquette: Etiquette(l[i].typeLibelle, ton: l[i].commande ? Ton.bleu : Ton.ambre),
              lignes: [if (l[i].grossiste.isNotEmpty) l[i].grossiste, if (l[i].date.isNotEmpty) 'Mise à jour le ${l[i].date}'],
              libelleValeur: 'Lignes',
              valeur: grouperMilliers(l[i].lignes),
              onTap: () => _ouvrir(l[i]),
            ),
          ),
      ],
    ]);
  }

  void _ouvrir(ElementAAnalyser e) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnalyseSuggestionScreen(element: e)));
}

class AnalyseSuggestionScreen extends StatefulWidget {
  final ElementAAnalyser element;
  const AnalyseSuggestionScreen({super.key, required this.element});

  @override
  State<AnalyseSuggestionScreen> createState() => _AnalyseSuggestionScreenState();
}

class _AnalyseSuggestionScreenState extends State<AnalyseSuggestionScreen> with ChargementSuivi<AnalyseSuggestionScreen, AnalyseSuggestion> {
  bool _alertesSeules = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  void _charger() {
    if (mounted) charger(() => ApiPrevisions.analyse(context, widget.element));
  }

  @override
  Widget build(BuildContext context) {
    final a = donnees;
    final e = widget.element;
    final lignes = a == null ? const <LigneAnalysee>[] : [for (final l in a.lignes) if (!_alertesSeules || l.alertes.isNotEmpty) l];
    return Scaffold(
      appBar: AppBar(title: Text('Analyse ${e.typeLibelle.toLowerCase()}')),
      body: ListView(key: const Key('defilement_analyse'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        if (enCours) const EtatChargement(texte: 'Analyse en cours…'),
        if (erreur != null) EtatErreur(erreur: erreur!, reessayer: _charger),
        if (a != null && !enCours) ...[
          Text('${e.typeLibelle} ${a.ref.isEmpty ? e.ref : a.ref}${(a.grossiste.isEmpty ? e.grossiste : a.grossiste).isEmpty ? '' : ' · ${a.grossiste.isEmpty ? e.grossiste : a.grossiste}'}',
              key: const Key('analyse_titre'), style: const TextStyle(color: Charte.navy, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GrilleChiffres([
            ChiffreCle(libelle: 'Lignes', valeur: grouperMilliers(a.nombreLignes), id: 'lignes'),
            ChiffreCle(libelle: 'Avec alerte', valeur: grouperMilliers(a.lignesAlerte), enAvant: a.lignesAlerte > 0, id: 'lignes_alerte'),
            ChiffreCle(libelle: 'Valeur proposée', valeur: formaterMontant(a.valeurProposee), id: 'valeur_proposee'),
            ChiffreCle(libelle: 'Valeur recommandée', valeur: formaterMontant(a.valeurRecommandee), id: 'valeur_recommandee'),
          ]),
          if (!a.calcule)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Encadre(texte: 'Prévisions pas encore calculées pour ces produits : les recommandations sont incomplètes.', icone: Icons.info_outline, avertissement: true),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Lecture seule : les quantités recommandées s\'appliquent depuis Prestige.', style: TextStyle(color: Charte.gris, fontSize: 13)),
          ),
          const SizedBox(height: 8),
          PucesChoix<bool>(
            choix: const [(false, 'Toutes les lignes'), (true, 'Avec alerte')],
            valeur: _alertesSeules,
            cle: (v, _) => Key('analyse_alertes_$v'),
            onChanged: (v) => setState(() => _alertesSeules = v),
          ),
          const SizedBox(height: 8),
          if (lignes.isEmpty)
            EtatVide(titre: _alertesSeules ? 'Aucune ligne en alerte' : 'Aucune ligne', icone: Icons.check_circle_outline)
          else
            ListeOuTableau(
              nombre: lignes.length,
              colonnes: const [
                Colonne('Produit', flex: 5),
                Colonne('Proposé', flex: 2, droite: true),
                Colonne('Recomm.', flex: 2, droite: true),
                Colonne('Écart', flex: 2, droite: true),
                Colonne('Stock', flex: 2, droite: true),
                Colonne('Prix', flex: 2, droite: true),
                Colonne('Alertes', flex: 6),
              ],
              cellules: (i) {
                final l = lignes[i];
                return [
                  l.nom,
                  grouperMilliers(l.quantite),
                  grouperMilliers(l.recommande),
                  '${l.ecart > 0 ? '+' : ''}${grouperMilliers(l.ecart)}',
                  grouperMilliers(l.stock),
                  formaterMontant(l.prix),
                  l.alertes.map((a) => a.$1).join(' ; '),
                ];
              },
              carte: (i) {
                final l = lignes[i];
                return CarteLigne(
                  titre: l.nom.isEmpty ? 'Produit' : l.nom,
                  bande: l.grave ? Charte.rouge : (l.alertes.isNotEmpty ? Charte.ambre : null),
                  lignes: [
                    if (l.cip.isNotEmpty) 'CIP ${l.cip}',
                    'Proposé ${grouperMilliers(l.quantite)} · recommandé ${grouperMilliers(l.recommande)} · écart ${l.ecart > 0 ? '+' : ''}${grouperMilliers(l.ecart)}',
                    'Stock ${grouperMilliers(l.stock)} · en cours ${grouperMilliers(l.enCours)} · prévu ${decimalTexte(l.prevuMois)}/mois',
                    'Prix ${formaterMontant(l.prix)}${l.dernierPrix > 0 ? ' · dernier ${formaterMontant(l.dernierPrix)}' : ''}',
                  ],
                  pied: l.alertes.isEmpty
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(spacing: 6, runSpacing: 4, children: [
                            for (final (t, g) in l.alertes) Etiquette(t, ton: g ? Ton.rouge : Ton.ambre),
                          ]),
                        ),
                );
              },
            ),
        ],
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Onglet Analyse de la demande
// ---------------------------------------------------------------------------------------------------------------

class _OngletDemande extends StatefulWidget {
  final bool actif;
  const _OngletDemande({required this.actif});

  @override
  State<_OngletDemande> createState() => _OngletDemandeState();
}

class _ChoixDemande {
  final int mois;
  final String recherche;
  final String rayonId;
  const _ChoixDemande(this.mois, this.recherche, this.rayonId);
  bool egal(_ChoixDemande o) => o.mois == mois && o.recherche == recherche && o.rayonId == rayonId;
}

class _OngletDemandeState extends State<_OngletDemande> with ChargementSuivi<_OngletDemande, DemandeSaisonniere> {
  int _mois = 12;
  String _recherche = '';
  String _rayon = '';
  final _champ = TextEditingController();
  List<OptionListe>? _rayons;
  Object? _erreurRayons;
  bool _rayonsDemandes = false;
  _ChoixDemande? _calcule;
  _ChoixDemande? _enCalcul;

  @override
  void initState() {
    super.initState();
    if (widget.actif) WidgetsBinding.instance.addPostFrameCallback((_) => _chargerRayons());
  }

  @override
  void didUpdateWidget(covariant _OngletDemande old) {
    super.didUpdateWidget(old);
    if (widget.actif && !old.actif) WidgetsBinding.instance.addPostFrameCallback((_) => _chargerRayons());
  }

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  /// Liste des rayons (légère) à la première ouverture de l'onglet ; le calcul attend « Calculer ».
  Future<void> _chargerRayons() async {
    if (_rayonsDemandes || !mounted) return;
    _rayonsDemandes = true;
    try {
      final r = await ApiVague2.options(context, ApiVague2.routeRayons, 'la liste des rayons');
      if (mounted) setState(() => _rayons = r);
    } catch (e) {
      if (mounted) setState(() => _erreurRayons = e);
    }
  }

  _ChoixDemande get _choix => _ChoixDemande(_mois, _recherche, _rayon);

  void _calculer() {
    if (enCours) return;
    final c = _choix;
    _enCalcul = c;
    charger(() async {
      final r = await ApiPrevisions.demande(context, mois: c.mois, recherche: c.recherche, rayonId: c.rayonId);
      _calcule = c;
      return r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = donnees;
    final perime = d != null && _calcule != null && !_calcule!.egal(_choix);
    final long = (_enCalcul?.mois ?? _mois) > 12;
    return ListView(key: const Key('defilement_demande'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      CarteSection(titre: 'Saisonnalité de la demande', icone: Icons.calendar_month_outlined, enfants: [
        const Text('Unités vendues mois par mois : quels mois vendent plus, quels produits anticiper.',
            style: TextStyle(color: Charte.gris, fontSize: 13)),
        const SizedBox(height: 10),
        PucesChoix<int>(
          choix: [for (final m in moisDemande) (m, '$m mois')],
          valeur: _mois,
          cle: (m, _) => Key('demande_mois_$m'),
          onChanged: (m) => setState(() => _mois = m),
        ),
        const SizedBox(height: 10),
        ChoixListe(
          key: const Key('demande_rayon'),
          libelle: 'Rayon',
          icone: Icons.shelves,
          options: _rayons,
          erreur: _erreurRayons,
          valeur: _rayon,
          tous: 'Tous les rayons',
          onChanged: (v) => setState(() => _rayon = v),
        ),
        const SizedBox(height: 10),
        ChampRecherche(
          controleur: _champ,
          libelle: 'Produit (facultatif)',
          aide: 'Nom ou CIP',
          antiRebond: const Duration(milliseconds: 300),
          onRecherche: (q) => setState(() => _recherche = q),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          key: const Key('demande_calculer'),
          onPressed: enCours ? null : () {
            setState(() => _recherche = _champ.text.trim());
            _calculer();
          },
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Calculer'),
        ),
      ]),
      if (enCours)
        ChargementAnnulable(
          texte: 'Analyse de la demande…',
          indication: long ? 'Calcul sur ${_enCalcul?.mois ?? _mois} mois, peut prendre un moment.' : null,
          annuler: abandonner,
        ),
      if (erreur != null) EtatErreur(erreur: erreur!, reessayer: _calculer),
      if (!enCours && d == null && erreur == null)
        const EtatVide(
          key: Key('demande_invite'),
          titre: 'Touchez « Calculer »',
          texte: 'Le calcul porte sur l\'historique des ventes : il n\'est lancé qu\'à votre demande.',
          icone: Icons.touch_app_outlined,
        ),
      if (d != null && !enCours) ...[
        if (perime)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Encadre(
                key: Key('demande_perimee'),
                texte: 'Les choix ont changé : touchez « Calculer » pour mettre l\'analyse à jour.',
                icone: Icons.info_outline,
                avertissement: true),
          ),
        _ResultatDemande(d),
      ],
    ]);
  }
}

class _ResultatDemande extends StatelessWidget {
  final DemandeSaisonniere d;
  const _ResultatDemande(this.d);

  @override
  Widget build(BuildContext context) {
    if (d.vide) {
      return const EtatVide(key: Key('demande_vide'), titre: 'Aucune vente', texte: 'Aucune vente sur la période pour ces choix.');
    }
    return Column(key: const Key('demande_resultat'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Du ${dateApiLisible(d.debut)} au ${dateApiLisible(d.fin)} · ${d.mois} mois',
          style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      GrilleChiffres([
        ChiffreCle(libelle: 'Unités vendues', valeur: grouperMilliers(d.total), id: 'demande_total'),
        ChiffreCle(libelle: 'Mois le plus fort', valeur: nomMois(d.pic), enAvant: true, id: 'demande_pic'),
        ChiffreCle(libelle: 'Force de la saison', valeur: decimalTexte(d.force, decimales: 2), detail: '0 = demande régulière', id: 'demande_force'),
        if (d.tendanceEvolution != null || d.tendanceRecent != null)
          ChiffreCle(
              libelle: '12 derniers mois',
              valeur: d.tendanceEvolution == null ? '—' : variationTexte(d.tendanceEvolution),
              detail: d.tendanceAvant == null ? null : '${grouperMilliers(d.tendanceRecent ?? 0)} u. contre ${grouperMilliers(d.tendanceAvant!)}',
              id: 'demande_tendance'),
      ]),
      const TitreSection('Indice par mois (1 = mois moyen)'),
      CarteSection(enfants: [
        BarresHorizontales(
          key: const Key('demande_indices'),
          barres: [for (var i = 0; i < 12; i++) (nomsMoisLongs[i], d.indices[i], decimalTexte(d.indices[i], decimales: 2))],
          enAvant: d.pic == null ? null : d.pic! - 1,
          reference: 1,
        ),
      ]),
      if (d.anticiper.isNotEmpty) ...[
        TitreSection('À anticiper (${nomMois(d.prochainMois)} et le mois suivant)'),
        for (final p in d.anticiper) _carteProduit(p),
      ],
      if (d.produits.isNotEmpty) ...[
        TitreSection('Produits les plus saisonniers (${grouperMilliers(d.produitsClasses)} classés)'),
        for (final p in d.produits) _carteProduit(p),
      ],
      const TitreSection('Unités vendues par année'),
      for (final a in d.annees)
        CarteSection(titre: '${a.annee} · ${grouperMilliers(a.total)} unités', enfants: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (var i = 0; i < 12; i++)
              if (a.mois[i] != null)
                SizedBox(
                  width: 92,
                  child: Text('${nomsMois[i]} ${grouperMilliers(a.mois[i]!)}', style: const TextStyle(color: Charte.encre, fontSize: 13)),
                ),
          ]),
        ]),
    ]);
  }

  Widget _carteProduit(ProduitSaisonnier p) => CarteLigne(
        titre: p.libelle,
        etiquette: p.anticiper ? const Etiquette('À anticiper', ton: Ton.ambre) : null,
        lignes: [
          [if (p.cip.isNotEmpty) 'CIP ${p.cip}', '${grouperMilliers(p.unites)} unités'].join(' · '),
          'Pic en ${nomMois(p.pic)} (indice ${decimalTexte(p.indicePic, decimales: 2)}) · force ${decimalTexte(p.force, decimales: 2)}',
        ],
      );
}
