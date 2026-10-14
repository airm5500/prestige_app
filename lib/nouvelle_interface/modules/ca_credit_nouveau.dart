// lib/nouvelle_interface/modules/ca_credit_nouveau.dart
// CA Crédit (ventes à crédit) de la nouvelle interface. Mêmes données et même recherche que l'écran d'origine
// (CaCreditDonnees, lib/donnees/analyses_ventes_donnees.dart) : GET /ca-credit?dtStart=&dtEnd= → liste, recherche
// LOCALE (client, ayant droit, N° de facture, tiers payant ; aucune nouvelle requête). Mise en page refaite : période
// commune chargée dès l'ouverture (« Aujourd'hui », dates par défaut d'origine), recherche contrôlée, tiers payant
// dans la feuille des filtres (filtre local parmi les tiers payants de la période), chiffres clés, cartes
// (téléphone) ou tableau avec total (tablette) construits 50 par 50, détail d'une vente en feuille.
// 3.8.0 (demande du pharmacien) : menu « Exporter » → PDF A4 (AnalysesPdf, lib/donnees/analyses_pdf.dart) des ventes
// AFFICHÉES (recherche et tiers payant appliqués, toutes les lignes), chiffres clés et total identiques à l'écran.
import 'package:flutter/material.dart';

import '../../donnees/analyses_pdf.dart';
import '../../donnees/analyses_ventes_donnees.dart';
import '../../models/ca_credit_model.dart';
import '../../utils/date_formatter.dart';
import '../charte.dart';
import '../composants.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import 'commun.dart';
import 'commun_lot2.dart';
import 'commun_lot3.dart';
import 'periode.dart';

class CaCreditNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const CaCreditNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<CaCreditNouveau> createState() => _CaCreditNouveauState();
}

class _CaCreditNouveauState extends State<CaCreditNouveau> with ChargementSuivi<CaCreditNouveau, List<CaCredit>>, AffichageParTranches {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  final _recherche = TextEditingController();
  String _texte = '';

  /// Tiers payant choisi (libellé ; vide = tous).
  String _tiers = '';

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
    super.dispose();
  }

  /// Période de la requête affichée (le PDF reprend exactement ce qui est affiché).
  Periode? _periodeLue;

  Future<void> _charger() {
    reinitialiserTranches();
    final p = _periode;
    _periodeLue = null;
    return charger(() async {
      final r = await CaCreditDonnees.charger(context, p.debut, p.fin, onSessionInvalid: sessionInvalide(context)) ?? const <CaCredit>[];
      _periodeLue = p;
      return r;
    });
  }

  /// PDF des ventes affichées (aucune requête, aucun recalcul).
  Future<void> _pdf() async {
    final tout = donnees;
    final p = _periodeLue;
    final l = tout == null ? const <CaCredit>[] : _affichees(tout);
    if (enCours || erreur != null || l.isEmpty || p == null) {
      messageResultat(context, 'Aucune donnée à exporter', echec: true);
      return;
    }
    final contenu = contenuPdf(l, tout!.length,
        periode: p,
        filtres: [
          if (_texte.isNotEmpty) ('Recherche', _texte),
          if (_tiers.isNotEmpty) ('Tiers payant', _tiers),
        ],
        officine: officineConnectee(context),
        imprimeLe: widget.maintenant());
    try {
      await AnalysesPdf.sortie(contenu, AnalysesPdf.nom('CA_credit', p.debut, p.fin));
    } catch (_) {
      if (mounted) messageResultat(context, 'Erreur lors de la préparation du PDF.', echec: true);
    }
  }

  /// Contenu du PDF : mêmes chiffres clés, mêmes lignes et même total que l'écran.
  static ContenuAnalysePdf contenuPdf(List<CaCredit> l, int ventes,
      {required Periode periode, required List<(String, String)> filtres, required String officine, required DateTime imprimeLe}) {
    final total = CaCreditDonnees.total(l);
    return ContenuAnalysePdf(
      officine: officine,
      titre: 'Ventes à crédit (CA Crédit)',
      periode: periode.resume,
      filtres: filtres,
      imprimeLe: ContenuAnalysePdf.horodatage(imprimeLe),
      chiffres: [
        ('Montant à crédit', formaterMontant(total)),
        ('Ventes', formaterNombre(l.length)),
        ('Clients', formaterNombre({for (final c in l) c.clientName}.length)),
        ('Tiers payants', formaterNombre({for (final c in l) c.tiersPayantLibelle}.length)),
        if (l.length != ventes) ('Ventes de la période (sans filtre)', formaterNombre(ventes)),
      ],
      titreDetail: 'Ventes à crédit',
      colonnes: const ['Date', 'Client', 'Ayant droit', 'N° facture', 'Tiers payant', 'Montant'],
      droite: const {5},
      lignes: [
        for (final c in l) [_date(c), c.clientName, _ayantDroitDistinct(c) ? c.ayantDroitName : '', c.numFacturation, c.tiersPayantLibelle, formaterMontant(c.montant)],
      ],
      total: ['Total', '', '', '', '', formaterMontant(total)],
    );
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  List<String> get _tiersPayants => ({for (final c in donnees ?? const <CaCredit>[]) c.tiersPayantLibelle}.toList()..sort());

  Future<void> _filtres() async {
    var tiers = _tiers;
    final options = [for (final t in _tiersPayants) OptionListe(t, t)];
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les ventes à crédit',
      effacer: () => tiers = '',
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChoixListe(
          key: const Key('filtre_tiers'),
          libelle: 'Tiers payant',
          icone: Icons.account_balance_outlined,
          options: options,
          erreur: null,
          valeur: tiers,
          tous: 'Tous',
          onChanged: (v) => setState(() => tiers = v),
        ),
        const SizedBox(height: 6),
        const Text('Parmi les tiers payants des ventes de la période (aucune nouvelle requête).', style: TextStyle(color: Charte.gris, fontSize: 13)),
      ]),
    );
    if (!applique || !mounted) return;
    setState(() {
      _tiers = tiers;
      reinitialiserTranches();
    });
  }

  /// Ventes affichées : recherche d'origine puis tiers payant.
  List<CaCredit> _affichees(List<CaCredit> l) {
    final r = CaCreditDonnees.filtrer(l, _texte);
    return _tiers.isEmpty ? r : [for (final c in r) if (c.tiersPayantLibelle == _tiers) c];
  }

  static String _date(CaCredit c) => c.mvtDate != null ? DateFormatter.toDisplayFormat(c.mvtDate!).replaceAll('-', '/') : 'N/A';

  static bool _ayantDroitDistinct(CaCredit c) => c.ayantDroitName.isNotEmpty && c.ayantDroitName != c.clientName;

  void _detail(CaCredit c) => ouvrirFeuilleDetail(context, titre: c.clientName, sousTitre: 'Facture ${c.numFacturation}', lignes: [
        if (_ayantDroitDistinct(c)) LigneDetail('Ayant droit', c.ayantDroitName),
        LigneDetail('Date', _date(c)),
        LigneDetail('N° facture', c.numFacturation),
        LigneDetail('Tiers payant', c.tiersPayantLibelle),
        LigneDetail('Montant', formaterMontant(c.montant), gras: true),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ventes à Crédit'), actions: [
          MenuExports(actions: [ActionExport('PDF des ventes à crédit', Icons.picture_as_pdf_outlined, _pdf)]),
          BoutonFiltres(actifs: _tiers.isEmpty ? 0 : 1, onPressed: _filtres),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ChampRecherche(
              controleur: _recherche,
              libelle: 'Rechercher une vente',
              aide: 'Client, N° de facture, tiers payant',
              onRecherche: (t) => setState(() {
                _texte = t;
                reinitialiserTranches();
              }),
            ),
            EtiquettesFiltres(
              etiquettes: [if (_tiers.isNotEmpty) 'Tiers payant : $_tiers'],
              onRetirer: () => setState(() {
                _tiers = '';
                reinitialiserTranches();
              }),
            ),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des ventes à crédit…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final tout = donnees ?? const <CaCredit>[];
    if (tout.isEmpty) {
      return const [EtatVide(titre: 'Aucune vente à crédit', texte: 'Aucune vente à crédit trouvée pour la période.', icone: Icons.credit_card_outlined)];
    }
    final l = _affichees(tout);
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucune vente ne correspond', texte: 'Modifiez la recherche ou le filtre.', icone: Icons.filter_alt_off_outlined)];
    }
    final total = CaCreditDonnees.total(l);
    final n = affichees.clamp(0, l.length);
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Montant à crédit', valeur: formaterMontant(total), id: 'montant', enAvant: true),
        ChiffreCle(
          libelle: 'Ventes',
          valeur: formaterNombre(l.length),
          id: 'ventes',
          detail: l.length == tout.length ? null : 'sur ${formaterNombre(tout.length)}',
        ),
        ChiffreCle(libelle: 'Clients', valeur: formaterNombre({for (final c in l) c.clientName}.length), id: 'clients'),
        ChiffreCle(libelle: 'Tiers payants', valeur: formaterNombre({for (final c in l) c.tiersPayantLibelle}.length), id: 'tiers'),
      ]),
      const TitreSection('Ventes à crédit'),
      ListeOuTableau(
        nombre: n,
        onTap: (i) => _detail(l[i]),
        colonnes: const [
          Colonne('Date', flex: 2),
          Colonne('Client', flex: 4),
          Colonne('Ayant droit', flex: 4),
          Colonne('N° facture', flex: 3),
          Colonne('Tiers payant', flex: 4),
          Colonne('Montant', flex: 3, droite: true),
        ],
        cellules: (i) => [_date(l[i]), l[i].clientName, _ayantDroitDistinct(l[i]) ? l[i].ayantDroitName : '', l[i].numFacturation, l[i].tiersPayantLibelle,
          formaterMontant(l[i].montant)],
        total: n == l.length ? ['Total', '', '', '', '', formaterMontant(total)] : null,
        carte: (i) => CarteLigne(
          titre: l[i].clientName,
          lignes: [
            if (_ayantDroitDistinct(l[i])) 'Ayant droit : ${l[i].ayantDroitName}',
            '${_date(l[i])} · Facture ${l[i].numFacturation}',
            'Tiers payant : ${l[i].tiersPayantLibelle}',
          ],
          libelleValeur: 'Montant',
          valeur: formaterMontant(l[i].montant),
          onTap: () => _detail(l[i]),
        ),
      ),
      piedTranches(l.length),
    ];
  }
}
