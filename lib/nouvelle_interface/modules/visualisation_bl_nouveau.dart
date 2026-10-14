// lib/nouvelle_interface/modules/visualisation_bl_nouveau.dart
// Visualisation BL de la nouvelle interface. Mêmes données que l'écran d'origine (VisualisationBl,
// lib/donnees/visualisation_bl_donnees.dart) : listes des filtres (grossistes, groupes, utilisateurs) et bons de
// livraison paginés GET /etat-control-bon/list (20 par page, mêmes paramètres), totaux HT / TVA / TTC des bons
// chargés et « Total BL » du serveur. Mise en page refaite : période commune (aujourd'hui à l'ouverture), recherche
// contrôlée, filtres (grossiste, groupe, utilisateur, statut) dans la feuille du bas, chiffres clés, bons en cartes
// (téléphone) ou tableau (tablette), « Afficher plus », détail d'un bon en page (lignes, écarts).
import 'package:flutter/material.dart';

import '../../donnees/visualisation_bl_donnees.dart';
import '../../models/bon_livraison_model.dart';
import '../../models/common_data_model.dart';
import '../charte.dart';
import '../composants.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import 'commun.dart';
import 'commun_lot2.dart';
import 'periode.dart';

/// Ton de l'étiquette d'un statut de BL (texte toujours affiché : jamais la couleur seule).
Ton tonStatutBl(String statut) => switch (statut) {
      'TERMINE' => Ton.vert,
      'EN_COURS' => Ton.ambre,
      _ => Ton.gris,
    };

String libelleStatutBl(String statut) => VisualisationBl.statuts[statut] ?? statut;

class VisualisationBlNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const VisualisationBlNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<VisualisationBlNouveau> createState() => _VisualisationBlNouveauState();
}

class _VisualisationBlNouveauState extends State<VisualisationBlNouveau> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  final _recherche = TextEditingController();

  OptionsVisualisationBl? _options;
  Object? _erreurOptions;
  CommonData? _grossiste, _groupe, _utilisateur;
  String? _statut;

  final _bons = <BonLivraisonModel>[];
  int _total = 0;
  int _page = 0;
  bool _enCours = false;
  bool _suiteEnCours = false;
  Object? _erreur;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chargerOptions();
      _charger();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _chargerOptions() async {
    setState(() => _erreurOptions = null);
    try {
      final o = await VisualisationBl.options(context);
      if (mounted) setState(() => _options = o);
    } catch (e) {
      if (mounted) setState(() => _erreurOptions = e);
    }
  }

  Future<PageBonsLivraison> _lire(int page) => VisualisationBl.page(
        context,
        recherche: _recherche.text,
        grossisteId: _grossiste?.id ?? '',
        groupeId: _groupe?.id ?? '',
        userId: _utilisateur?.id ?? '',
        statut: _statut,
        debut: _periode.debut,
        fin: _periode.fin,
        page: page,
      );

  Future<void> _charger() async {
    final g = ++_generation;
    setState(() {
      _enCours = true;
      _suiteEnCours = false;
      _erreur = null;
    });
    try {
      final p = await _lire(1);
      if (!mounted || g != _generation) return;
      setState(() {
        _bons
          ..clear()
          ..addAll(p.bons);
        _total = p.total;
        _page = 1;
        _enCours = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _bons.clear();
        _total = 0;
        _erreur = e;
        _enCours = false;
      });
    }
  }

  Future<void> _suite() async {
    if (_suiteEnCours || _enCours) return;
    final g = _generation;
    setState(() => _suiteEnCours = true);
    try {
      final p = await _lire(_page + 1);
      if (!mounted || g != _generation) return;
      setState(() {
        _bons.addAll(p.bons);
        _total = p.total;
        _page++;
        _suiteEnCours = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() => _suiteEnCours = false);
      messageResultat(context, DiagnosticErreur.de(e).message, echec: true);
    }
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  int get _actifs => [_grossiste, _groupe, _utilisateur, _statut].where((x) => x != null).length;

  List<OptionListe>? _opts(List<CommonData>? l) => l == null ? null : [for (final x in l) OptionListe(x.id, x.libelle)];
  static CommonData? _trouver(List<CommonData>? l, String id) => id.isEmpty ? null : l?.where((x) => x.id == id).firstOrNull;

  Future<void> _filtres() async {
    if (_options == null && _erreurOptions != null) _chargerOptions();
    var grossiste = _grossiste?.id ?? '', groupe = _groupe?.id ?? '', utilisateur = _utilisateur?.id ?? '';
    String? statut = _statut;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les bons de livraison',
      effacer: () {
        grossiste = groupe = utilisateur = '';
        statut = null;
      },
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChoixListe(
          key: const Key('filtre_grossiste'),
          libelle: 'Grossiste',
          icone: Icons.local_shipping_outlined,
          options: _opts(_options?.grossistes),
          erreur: _erreurOptions,
          valeur: grossiste,
          tous: 'Tous les grossistes',
          onChanged: (v) => setState(() => grossiste = v),
        ),
        const SizedBox(height: 12),
        ChoixListe(
          key: const Key('filtre_groupe'),
          libelle: 'Groupe',
          icone: Icons.groups_outlined,
          options: _opts(_options?.groupes),
          erreur: _erreurOptions,
          valeur: groupe,
          tous: 'Tous les groupes',
          onChanged: (v) => setState(() => groupe = v),
        ),
        const SizedBox(height: 12),
        ChoixListe(
          key: const Key('filtre_utilisateur'),
          libelle: 'Utilisateur',
          icone: Icons.person_outline,
          options: _opts(_options?.utilisateurs),
          erreur: _erreurOptions,
          valeur: utilisateur,
          tous: 'Tous les utilisateurs',
          onChanged: (v) => setState(() => utilisateur = v),
        ),
        const SizedBox(height: 14),
        const Text('Statut', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        PucesChoix<String?>(
          choix: [(null, 'Tous'), for (final e in VisualisationBl.statuts.entries) (e.key, e.value)],
          valeur: statut,
          cle: (v, _) => Key('filtre_statut_${v ?? 'tous'}'),
          onChanged: (v) => setState(() => statut = v),
        ),
      ]),
    );
    if (!applique || !mounted) return;
    setState(() {
      _grossiste = _trouver(_options?.grossistes, grossiste);
      _groupe = _trouver(_options?.groupes, groupe);
      _utilisateur = _trouver(_options?.utilisateurs, utilisateur);
      _statut = statut;
    });
    _charger();
  }

  void _retirerFiltres() {
    setState(() => _grossiste = _groupe = _utilisateur = _statut = null);
    _charger();
  }

  void _ouvrir(BonLivraisonModel bl) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailBlNouveau(bl: bl)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Visualisation BL'), actions: [BoutonFiltres(actifs: _actifs, onPressed: _filtres)]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ChampRecherche(controleur: _recherche, libelle: 'Rechercher un BL', aide: 'Référence, CIP, nom…', enCours: _enCours, onRecherche: (_) => _charger()),
            EtiquettesFiltres(etiquettes: [
              if (_grossiste != null) 'Grossiste : ${_grossiste!.libelle}',
              if (_groupe != null) 'Groupe : ${_groupe!.libelle}',
              if (_utilisateur != null) 'Utilisateur : ${_utilisateur!.libelle}',
              if (_statut != null) 'Statut : ${libelleStatutBl(_statut!)}',
            ], onRetirer: _retirerFiltres),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (_enCours) return const [EtatChargement(texte: 'Chargement des bons de livraison…')];
    if (_erreur != null) return [EtatErreur(erreur: _erreur!, reessayer: _charger)];
    if (_bons.isEmpty) {
      return const [EtatVide(titre: 'Aucun Bon de Livraison trouvé', texte: 'Choisissez une autre période ou modifiez les filtres.', icone: Icons.receipt_outlined)];
    }
    final l = _bons;
    final t = VisualisationBl.totaux(l);
    final partiel = l.length < _total;
    final detailTotaux = partiel ? 'sur les ${formaterNombre(l.length)} BL affichés' : null;
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'TTC', valeur: formaterMontant(t.ttc.toInt()), id: 'ttc', enAvant: true, detail: detailTotaux),
        ChiffreCle(libelle: 'Total BL', valeur: formaterNombre(_total), id: 'total_bl'),
        ChiffreCle(libelle: 'HT', valeur: formaterMontant(t.ht.toInt()), id: 'ht', detail: detailTotaux),
        ChiffreCle(libelle: 'TVA', valeur: formaterMontant(t.tva.toInt()), id: 'tva', detail: detailTotaux),
      ]),
      const TitreSection('Bons de livraison'),
      ListeOuTableau(
        nombre: l.length,
        onTap: (i) => _ouvrir(l[i]),
        colonnes: const [
          Colonne('Fournisseur', flex: 4),
          Colonne('Référence', flex: 3),
          Colonne('Livré le', flex: 2),
          Colonne('Utilisateur', flex: 3),
          Colonne('Statut', flex: 2),
          Colonne('TTC', flex: 2, droite: true),
        ],
        cellules: (i) => [
          l[i].fournisseurLibelle,
          l[i].refLivraison,
          l[i].dateLivraison,
          l[i].userFullName,
          libelleStatutBl(l[i].statut),
          formaterMontant(l[i].montantTTC.toInt()),
        ],
        carte: (i) => CarteLigne(
          titre: l[i].fournisseurLibelle,
          etiquette: Etiquette(libelleStatutBl(l[i].statut), ton: tonStatutBl(l[i].statut)),
          lignes: ['BL ${l[i].refLivraison} · ${l[i].dateLivraison}', if (l[i].userFullName.isNotEmpty) 'Par ${l[i].userFullName}'],
          libelleValeur: 'TTC',
          valeur: formaterMontant(l[i].montantTTC.toInt()),
          onTap: () => _ouvrir(l[i]),
        ),
      ),
      PiedPagination(affichees: l.length, total: _total, enCours: _suiteEnCours, onPlus: _suite),
    ];
  }
}

/// Détail d'un bon de livraison (mêmes informations que la fenêtre d'origine) : lignes avec quantités commandée,
/// reçue, contrôlée, écart (stock théorique − contrôlé), stock théorique, prix et unités gratuites.
class DetailBlNouveau extends StatelessWidget {
  final BonLivraisonModel bl;
  const DetailBlNouveau({super.key, required this.bl});

  @override
  Widget build(BuildContext context) {
    final d = bl.details;
    final ecarts = d.where((x) => x.ecart != 0).length;
    return Scaffold(
      appBar: AppBar(title: Text('BL N° ${bl.refLivraison}', overflow: TextOverflow.ellipsis)),
      body: ListView(key: const Key('defilement_detail'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Text(bl.fournisseurLibelle, style: const TextStyle(color: Charte.navy, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 4, children: [
          Etiquette(libelleStatutBl(bl.statut), ton: tonStatutBl(bl.statut)),
          Etiquette('Livré le ${bl.dateLivraison}', ton: Ton.gris),
        ]),
        const SizedBox(height: 12),
        GrilleKpi([
          ChiffreCle(libelle: 'Montant TTC', valeur: formaterMontant(bl.montantTTC.toInt()), id: 'bl_ttc', enAvant: true),
          ChiffreCle(libelle: 'Lignes', valeur: formaterNombre(d.length), id: 'bl_lignes'),
          ChiffreCle(libelle: 'Lignes avec écart', valeur: formaterNombre(ecarts), id: 'bl_ecarts'),
          ChiffreCle(libelle: 'Montant HT', valeur: formaterMontant(bl.montantHT.toInt()), id: 'bl_ht'),
        ]),
        const TitreSection('Lignes du bon'),
        if (d.isEmpty)
          const EtatVide(titre: 'Aucune ligne', texte: 'Ce bon ne contient aucune ligne.', icone: Icons.receipt_long_outlined)
        else
          ListeOuTableau(
            nombre: d.length,
            colonnes: const [
              Colonne('CIP', flex: 2),
              Colonne('Désignation', flex: 5),
              Colonne('Cmd', flex: 1, droite: true),
              Colonne('Reçu', flex: 1, droite: true),
              Colonne('Ctrl', flex: 1, droite: true),
              Colonne('Écart', flex: 1, droite: true),
              Colonne('Stock théo', flex: 2, droite: true),
              Colonne('PA', flex: 2, droite: true),
              Colonne('PV', flex: 2, droite: true),
              Colonne('UG', flex: 1, droite: true),
            ],
            cellules: (i) => [
              d[i].cip,
              d[i].designation,
              '${d[i].qteCmde}',
              '${d[i].qteRecue}',
              '${d[i].qteControle}',
              '${d[i].ecart}',
              '${d[i].stockTheorique}',
              formaterMontant(d[i].prixAchat.toInt()),
              formaterMontant(d[i].prixVente.toInt()),
              '${d[i].qteGratuite}',
            ],
            carte: (i) => CarteLigne(
              titre: d[i].designation,
              bande: d[i].ecart != 0 ? Charte.rouge : null,
              etiquette: d[i].ecart != 0 ? Etiquette('Écart ${d[i].ecart}', ton: Ton.rouge) : const Etiquette('Sans écart', ton: Ton.vert),
              lignes: [
                'CIP ${d[i].cip} · PV ${formaterMontant(d[i].prixVente.toInt())}',
                'Cmd ${d[i].qteCmde} · Reçu ${d[i].qteRecue} · Ctrl ${d[i].qteControle} · Écart ${d[i].ecart}',
                'Stock théo ${d[i].stockTheorique}${d[i].qteGratuite > 0 ? ' · UG ${d[i].qteGratuite}' : ''}',
              ],
              libelleValeur: 'PA',
              valeur: formaterMontant(d[i].prixAchat.toInt()),
            ),
          ),
      ]),
    );
  }
}
