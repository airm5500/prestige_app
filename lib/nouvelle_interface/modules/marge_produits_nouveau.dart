// lib/nouvelle_interface/modules/marge_produits_nouveau.dart
// Marge Produits Vendus de la nouvelle interface. Mêmes données et même filtre que l'écran d'origine (MargeDonnees,
// lib/donnees/analyses_ventes_donnees.dart) : GET /datareporting/margeproduitsvendus?dtStart=&dtEnd=&limit=9999 →
// « data », filtre LOCAL sur la marge (%) (=, >, <, ≥, ≤, ≠, environ ± 1 ; aucune nouvelle requête). Mise en page
// refaite : période commune chargée dès l'ouverture (« Aujourd'hui », dates par défaut d'origine), filtre de marge
// dans la feuille du bas, recherche contrôlée locale (produit ou CIP), chiffres clés des produits affichés, cartes
// (téléphone) ou tableau (tablette) construits 50 par 50, détail d'un produit en feuille.
// 3.8.0 (demande du pharmacien) : menu « Exporter » → PDF A4 (AnalysesPdf, lib/donnees/analyses_pdf.dart) des
// produits AFFICHÉS (filtre de marge et recherche appliqués, toutes les lignes et pas seulement les 50 construites),
// chiffres clés et total identiques à l'écran.
import 'package:flutter/material.dart';

import '../../donnees/analyses_pdf.dart';
import '../../donnees/analyses_ventes_donnees.dart';
import '../../models/marge_produit_vendu_model.dart';
import '../../utils/saisie.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot2.dart';
import 'commun_lot3.dart';
import 'periode.dart';

class MargeProduitsNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const MargeProduitsNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<MargeProduitsNouveau> createState() => _MargeProduitsNouveauState();
}

class _MargeProduitsNouveauState extends State<MargeProduitsNouveau> with ChargementSuivi<MargeProduitsNouveau, List<MargeProduitVendu>>, AffichageParTranches {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  final _recherche = TextEditingController();
  final _champMarge = TextEditingController();
  String _texte = '';
  OperateurMarge _operateur = OperateurMarge.egal;
  String _marge = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    _champMarge.dispose();
    super.dispose();
  }

  /// Période de la requête affichée (le PDF reprend exactement ce qui est affiché).
  Periode? _periodeLue;

  Future<void> _charger() {
    reinitialiserTranches();
    final p = _periode;
    _periodeLue = null;
    return charger(() async {
      final r = await MargeDonnees.charger(context, p.debut, p.fin, onSessionInvalid: sessionInvalide(context)) ?? const <MargeProduitVendu>[];
      _periodeLue = p;
      return r;
    });
  }

  /// PDF des produits affichés (aucune requête, aucun recalcul).
  Future<void> _pdf() async {
    final tout = donnees;
    final p = _periodeLue;
    final l = tout == null ? const <MargeProduitVendu>[] : _affiches(tout);
    if (enCours || erreur != null || l.isEmpty || p == null) {
      messageResultat(context, 'Aucune donnée à exporter', echec: true);
      return;
    }
    final contenu = contenuPdf(l, tout!.length,
        periode: p,
        filtres: [
          if (_filtreActif) ('Marge', '${_operateur.symbole} $_marge %'),
          if (_texte.isNotEmpty) ('Recherche', _texte),
        ],
        officine: officineConnectee(context),
        imprimeLe: widget.maintenant());
    try {
      await AnalysesPdf.sortie(contenu, AnalysesPdf.nom('Marge_produits_vendus', p.debut, p.fin));
    } catch (_) {
      if (mounted) messageResultat(context, 'Erreur lors de la préparation du PDF.', echec: true);
    }
  }

  /// Contenu du PDF : mêmes chiffres clés, mêmes lignes et même total que l'écran.
  static ContenuAnalysePdf contenuPdf(List<MargeProduitVendu> l, int vendus,
          {required Periode periode, required List<(String, String)> filtres, required String officine, required DateTime imprimeLe}) =>
      ContenuAnalysePdf(
        officine: officine,
        titre: 'Marge Produits Vendus',
        periode: periode.resume,
        filtres: filtres,
        imprimeLe: ContenuAnalysePdf.horodatage(imprimeLe),
        chiffres: [
          ('Marge', formaterMontant(MargeDonnees.totalMarge(l))),
          ('Vente', formaterMontant(MargeDonnees.totalVente(l))),
          ('Achat', formaterMontant(MargeDonnees.totalAchat(l))),
          ('Produits', formaterNombre(l.length)),
          if (l.length != vendus) ('Produits vendus (sans filtre)', formaterNombre(vendus)),
        ],
        titreDetail: 'Produits',
        colonnes: const ['CIP', 'Produit', 'Achat', 'Vente', 'Marge', 'Marge %'],
        droite: const {2, 3, 4, 5},
        lignes: [
          for (final p in l)
            [p.code, p.libelle, formaterMontant(p.montantAchat), formaterMontant(p.montantVente), formaterMontant(p.montantMarge), '${p.margePourcentage} %'],
        ],
        total: ['', 'Total', formaterMontant(MargeDonnees.totalAchat(l)), formaterMontant(MargeDonnees.totalVente(l)), formaterMontant(MargeDonnees.totalMarge(l)), ''],
      );

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  bool get _filtreActif => int.tryParse(_marge) != null;

  /// Valeur de marge refusée (vide accepté : aucun filtre).
  static String? _erreurMarge(String t) =>
      t.isEmpty || Saisie.entier(t, min: -Saisie.maxMarge, max: Saisie.maxMarge) != null ? null : 'Entier de -${Saisie.maxMarge} à ${Saisie.maxMarge}';

  Future<void> _filtres() async {
    var op = _operateur;
    _champMarge.text = _marge;
    String? erreurChamp;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer par marge',
      effacer: () {
        op = OperateurMarge.egal;
        _champMarge.clear();
        erreurChamp = null;
      },
      valider: () => _erreurMarge(_champMarge.text.trim()) == null,
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Marge (%)', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        PucesChoix<OperateurMarge>(
          choix: [for (final o in OperateurMarge.values) (o, o.libelle)],
          valeur: op,
          cle: (v, _) => Key('filtre_operateur_${v.name}'),
          onChanged: (v) => setState(() => op = v),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('filtre_marge'),
          controller: _champMarge,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: Saisie.entierSigneFormatters(3), // -999 à 999 %
          onChanged: (t) => setState(() => erreurChamp = _erreurMarge(t.trim())),
          decoration: InputDecoration(
            labelText: 'Valeur de la marge (%)',
            errorText: erreurChamp,
            prefixIcon: const Icon(Icons.percent),
          ),
        ),
        const SizedBox(height: 6),
        const Text('Laisser vide pour ne pas filtrer.', style: TextStyle(color: Charte.grisTexte, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
    if (!applique || !mounted) return;
    setState(() {
      _operateur = op;
      _marge = _champMarge.text.trim();
      reinitialiserTranches();
    });
  }

  void _retirer() => setState(() {
        _operateur = OperateurMarge.egal;
        _marge = '';
        reinitialiserTranches();
      });

  /// Produits affichés : filtre de marge (règle d'origine) puis recherche locale.
  List<MargeProduitVendu> _affiches(List<MargeProduitVendu> l) {
    final f = MargeDonnees.filtrer(l, _operateur, _marge);
    final q = _texte.toLowerCase();
    return q.isEmpty ? f : [for (final p in f) if (p.libelle.toLowerCase().contains(q) || p.code.toLowerCase().contains(q)) p];
  }

  void _detail(MargeProduitVendu p) => ouvrirFeuilleDetail(context, titre: p.libelle, sousTitre: 'CIP ${p.code}', lignes: [
        LigneDetail('Achat', formaterMontant(p.montantAchat)),
        LigneDetail('Vente', formaterMontant(p.montantVente)),
        LigneDetail('Marge', formaterMontant(p.montantMarge), gras: true),
        LigneDetail('Marge (%)', '${p.margePourcentage} %', gras: true),
      ]);

  static Ton _ton(int marge) => marge < 0 ? Ton.rouge : (marge == 0 ? Ton.gris : Ton.vert);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Marge Produits Vendus'), actions: [
          MenuExports(actions: [ActionExport('PDF des marges', Icons.picture_as_pdf_outlined, _pdf)]),
          BoutonFiltres(actifs: _filtreActif ? 1 : 0, onPressed: _filtres),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ChampRecherche(
              controleur: _recherche,
              libelle: 'Rechercher un produit',
              aide: 'Libellé ou CIP (dans la liste chargée)',
              onRecherche: (t) => setState(() {
                _texte = t;
                reinitialiserTranches();
              }),
            ),
            EtiquettesFiltres(etiquettes: [if (_filtreActif) 'Marge ${_operateur.symbole} $_marge %'], onRetirer: _retirer),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des marges…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final tout = donnees ?? const <MargeProduitVendu>[];
    if (tout.isEmpty) {
      return const [EtatVide(titre: 'Aucune donnée trouvée', texte: 'Aucun produit vendu pour cette période.', icone: Icons.percent_outlined)];
    }
    final l = _affiches(tout);
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucun produit ne correspond', texte: 'Modifiez le filtre de marge ou la recherche.', icone: Icons.filter_alt_off_outlined)];
    }
    final n = affichees.clamp(0, l.length);
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Marge', valeur: formaterMontant(MargeDonnees.totalMarge(l)), id: 'marge', enAvant: true),
        ChiffreCle(libelle: 'Vente', valeur: formaterMontant(MargeDonnees.totalVente(l)), id: 'vente'),
        ChiffreCle(libelle: 'Achat', valeur: formaterMontant(MargeDonnees.totalAchat(l)), id: 'achat'),
        ChiffreCle(
          libelle: 'Produits',
          valeur: formaterNombre(l.length),
          id: 'produits',
          detail: l.length == tout.length ? null : 'sur ${formaterNombre(tout.length)} vendus',
        ),
      ]),
      const TitreSection('Produits'),
      ListeOuTableau(
        nombre: n,
        onTap: (i) => _detail(l[i]),
        colonnes: const [
          Colonne('CIP', flex: 3),
          Colonne('Produit', flex: 6),
          Colonne('Achat', flex: 3, droite: true),
          Colonne('Vente', flex: 3, droite: true),
          Colonne('Marge', flex: 3, droite: true),
          Colonne('Marge %', flex: 2, droite: true),
        ],
        cellules: (i) => [
          l[i].code,
          l[i].libelle,
          formaterMontant(l[i].montantAchat),
          formaterMontant(l[i].montantVente),
          formaterMontant(l[i].montantMarge),
          '${l[i].margePourcentage} %',
        ],
        total: n == l.length
            ? ['', 'Total', formaterMontant(MargeDonnees.totalAchat(l)), formaterMontant(MargeDonnees.totalVente(l)), formaterMontant(MargeDonnees.totalMarge(l)), '']
            : null,
        carte: (i) => CarteLigne(
          titre: l[i].libelle,
          lignes: ['CIP ${l[i].code}', 'Achat ${formaterMontant(l[i].montantAchat)} · Vente ${formaterMontant(l[i].montantVente)}'],
          etiquette: Etiquette('Marge ${l[i].margePourcentage} %', ton: _ton(l[i].margePourcentage)),
          libelleValeur: 'Marge',
          valeur: formaterMontant(l[i].montantMarge),
          onTap: () => _detail(l[i]),
        ),
      ),
      piedTranches(l.length),
    ];
  }
}
