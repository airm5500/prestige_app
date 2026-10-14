// lib/nouvelle_interface/modules/ca_credit_nouveau.dart
// CA Crédit (ventes à crédit) de la nouvelle interface. Mêmes données et même recherche que l'écran d'origine
// (CaCreditDonnees, lib/donnees/analyses_ventes_donnees.dart) : GET /ca-credit?dtStart=&dtEnd= → liste, recherche
// LOCALE (client, ayant droit, N° de facture, tiers payant ; aucune nouvelle requête). Mise en page refaite : période
// commune chargée dès l'ouverture (« Aujourd'hui », dates par défaut d'origine), recherche contrôlée, tiers payant
// dans la feuille des filtres (filtre local parmi les tiers payants de la période), chiffres clés, cartes
// (téléphone) ou tableau avec total (tablette) construits 50 par 50, détail d'une vente en feuille.
import 'package:flutter/material.dart';

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

  Future<void> _charger() {
    reinitialiserTranches();
    return charger(() async =>
        await CaCreditDonnees.charger(context, _periode.debut, _periode.fin, onSessionInvalid: sessionInvalide(context)) ?? const <CaCredit>[]);
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
