// lib/nouvelle_interface/modules/retours_fournisseurs_nouveau.dart
// Retours fournisseurs de la nouvelle interface, en LECTURE SEULE comme l'écran d'origine. Mêmes données
// (RetoursFournisseurs, lib/donnees/retours_fournisseurs_donnees.dart) : fournisseurs (GET /grossiste/all), retours
// GET /produit/retours-data (query, fourId, filtre, dtEnd, dtStart, page, start, limit=9999), détail d'un retour
// GET /retourfournisseur/retours-items, produits retournés de la période GET /avoirs-fournisseurs. Mise en page
// refaite : période commune (chargée à l'ouverture sur « Aujourd'hui »), recherche contrôlée, filtres (fournisseur,
// réponse) dans la feuille du bas, chiffres clés, cartes (téléphone) ou tableau (tablette), détail en page.
// Aucune création de retour (prévue plus tard).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../donnees/retours_fournisseurs_donnees.dart';
import '../../models/avoir_fournisseur_produit_model.dart';
import '../../models/fournisseur_model.dart';
import '../../models/retour_fournisseur_detail_model.dart';
import '../../models/retour_fournisseur_model.dart';
import '../../utils/date_formatter.dart';
import '../charte.dart';
import '../composants.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import 'commun.dart';
import 'commun_lot2.dart';
import 'periode.dart';

class RetoursFournisseursNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const RetoursFournisseursNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<RetoursFournisseursNouveau> createState() => _RetoursFournisseursNouveauState();
}

class _RetoursFournisseursNouveauState extends State<RetoursFournisseursNouveau>
    with ChargementSuivi<RetoursFournisseursNouveau, List<RetourFournisseur>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  final _recherche = TextEditingController();
  List<Fournisseur>? _fournisseurs;
  Object? _erreurFournisseurs;
  Fournisseur? _fournisseur;
  FiltreReponse _reponse = FiltreReponse.tout;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chargerFournisseurs();
      _charger();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _chargerFournisseurs() async {
    setState(() => _erreurFournisseurs = null);
    try {
      final f = await RetoursFournisseurs.fournisseurs(context, onSessionInvalid: sessionInvalide(context));
      if (mounted) setState(() => _fournisseurs = f ?? const []);
    } catch (e) {
      if (mounted) setState(() => _erreurFournisseurs = e);
    }
  }

  Future<void> _charger() => charger(() async =>
      await RetoursFournisseurs.retours(context,
          recherche: _recherche.text,
          fourId: _fournisseur?.fournisseurId ?? '',
          filtre: _reponse,
          debut: _periode.debut,
          fin: _periode.fin,
          onSessionInvalid: sessionInvalide(context)) ??
      const <RetourFournisseur>[]);

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  int get _actifs => (_fournisseur == null ? 0 : 1) + (_reponse == FiltreReponse.tout ? 0 : 1);

  Future<void> _filtres() async {
    if (_fournisseurs == null && _erreurFournisseurs != null) _chargerFournisseurs();
    var fournisseur = _fournisseur?.fournisseurId ?? '';
    var reponse = _reponse;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les retours',
      effacer: () {
        fournisseur = '';
        reponse = FiltreReponse.tout;
      },
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChoixListe(
          key: const Key('filtre_fournisseur'),
          libelle: 'Fournisseur',
          icone: Icons.local_shipping_outlined,
          options: _fournisseurs == null ? null : [for (final f in _fournisseurs!) OptionListe(f.fournisseurId, f.fournisseurLibelle)],
          erreur: _erreurFournisseurs,
          valeur: fournisseur,
          tous: 'Tous',
          onChanged: (v) => setState(() => fournisseur = v),
        ),
        const SizedBox(height: 14),
        const Text('Réponse du fournisseur', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        PucesChoix<FiltreReponse>(
          choix: [for (final f in FiltreReponse.values) (f, f.libelle)],
          valeur: reponse,
          cle: (v, _) => Key('filtre_reponse_${v.name}'),
          onChanged: (v) => setState(() => reponse = v),
        ),
      ]),
    );
    if (!applique || !mounted) return;
    setState(() {
      _fournisseur = fournisseur.isEmpty ? null : _fournisseurs?.where((f) => f.fournisseurId == fournisseur).firstOrNull;
      _reponse = reponse;
    });
    _charger();
  }

  void _ouvrir(RetourFournisseur r) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailRetourNouveau(retour: r)));

  void _produits() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProduitsRetournesNouveau(periode: _periode)));

  static String _date(RetourFournisseur r) => r.dtCreated != null ? DateFormatter.toDisplayFormat(r.dtCreated!) : 'N/A';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Retours Fournisseurs'), actions: [
          IconButton(key: const Key('retours_produits'), tooltip: 'Produits retournés', icon: const Icon(Icons.list_alt), onPressed: _produits),
          BoutonFiltres(actifs: _actifs, onPressed: _filtres),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ChampRecherche(controleur: _recherche, libelle: 'Rechercher un retour', aide: 'Référence, produit…', enCours: enCours, onRecherche: (_) => _charger()),
            EtiquettesFiltres(etiquettes: [
              if (_fournisseur != null) 'Fournisseur : ${_fournisseur!.fournisseurLibelle}',
              if (_reponse != FiltreReponse.tout) _reponse.libelle,
            ], onRetirer: () {
              setState(() {
                _fournisseur = null;
                _reponse = FiltreReponse.tout;
              });
              _charger();
            }),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des retours…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <RetourFournisseur>[];
    if (l.isEmpty) {
      return const [
        EtatVide(titre: 'Aucun retour fournisseur', texte: 'Aucun retour pour les critères sélectionnés.', icone: Icons.assignment_return_outlined),
      ];
    }
    final montant = RetoursFournisseurs.montantTotal(l);
    final fournisseurs = {for (final r in l) r.strGrossisteLibelle}.length;
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Montant des retours', valeur: formaterMontant(montant), id: 'montant', enAvant: true),
        ChiffreCle(libelle: 'Retours', valeur: formaterNombre(l.length), id: 'retours'),
        ChiffreCle(libelle: 'Fournisseurs', valeur: formaterNombre(fournisseurs), id: 'fournisseurs'),
      ]),
      const TitreSection('Retours'),
      ListeOuTableau(
        nombre: l.length,
        onTap: (i) => _ouvrir(l[i]),
        colonnes: const [
          Colonne('Fournisseur', flex: 4),
          Colonne('Réf. retour', flex: 3),
          Colonne('Réf. livraison', flex: 3),
          Colonne('Date', flex: 2),
          Colonne('Montant', flex: 3, droite: true),
        ],
        cellules: (i) => [l[i].strGrossisteLibelle, l[i].strRefRetourFrs, l[i].strRefLivraison, _date(l[i]), formaterMontant(l[i].montantRetour)],
        total: ['Total', '', '', '', formaterMontant(montant)],
        carte: (i) => CarteLigne(
          titre: l[i].strGrossisteLibelle,
          lignes: ['Réf. Retour : ${l[i].strRefRetourFrs}', 'Réf. Livraison : ${l[i].strRefLivraison}', 'Date : ${_date(l[i])}'],
          libelleValeur: 'Montant',
          valeur: formaterMontant(l[i].montantRetour),
          onTap: () => _ouvrir(l[i]),
        ),
      ),
    ];
  }
}

/// Détail d'un retour (produits retournés, quantités retournée / répondue, motif, opérateur).
class DetailRetourNouveau extends StatefulWidget {
  final RetourFournisseur retour;
  const DetailRetourNouveau({super.key, required this.retour});

  @override
  State<DetailRetourNouveau> createState() => _DetailRetourNouveauState();
}

class _DetailRetourNouveauState extends State<DetailRetourNouveau> with ChargementSuivi<DetailRetourNouveau, List<RetourFournisseurDetail>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() async =>
      await RetoursFournisseurs.details(context, widget.retour.lgRetourFrsId, onSessionInvalid: sessionInvalide(context)) ?? const <RetourFournisseurDetail>[]);

  static String _quand(RetourFournisseurDetail d) => d.dtCreated != null ? DateFormat('dd/MM/yyyy HH:mm').format(d.dtCreated!) : 'N/A';

  @override
  Widget build(BuildContext context) {
    final r = widget.retour;
    return Scaffold(
      appBar: AppBar(title: const Text('Détails du Retour')),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(key: const Key('defilement_detail'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Text(r.strGrossisteLibelle, style: const TextStyle(color: Charte.navy, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Wrap(spacing: 8, runSpacing: 4, children: [
            Etiquette('Retour ${r.strRefRetourFrs}', ton: Ton.gris),
            Etiquette('BL ${r.strRefLivraison}', ton: Ton.gris),
          ]),
          const SizedBox(height: 8),
          ..._corps(),
        ]),
      ),
    );
  }

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement du retour…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <RetourFournisseurDetail>[];
    if (l.isEmpty) return const [EtatVide(titre: 'Aucun détail trouvé pour ce retour.', icone: Icons.inventory_2_outlined)];
    final retournes = l.fold<int>(0, (s, d) => s + d.intNUMBERRETURN);
    final repondus = l.fold<int>(0, (s, d) => s + d.intNUMBERANSWER);
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Montant', valeur: formaterMontant(widget.retour.montantRetour), id: 'retour_montant', enAvant: true),
        ChiffreCle(libelle: 'Produits', valeur: formaterNombre(l.length), id: 'retour_produits'),
        ChiffreCle(libelle: 'Quantité retournée', valeur: formaterNombre(retournes), id: 'retour_qte'),
        ChiffreCle(libelle: 'Quantité répondue', valeur: formaterNombre(repondus), id: 'retour_reponse'),
      ]),
      const TitreSection('Produits'),
      ListeOuTableau(
        nombre: l.length,
        colonnes: const [
          Colonne('CIP', flex: 2),
          Colonne('Produit', flex: 5),
          Colonne('Retournée', flex: 2, droite: true),
          Colonne('Répondue', flex: 2, droite: true),
          Colonne('Prix d\'achat', flex: 2, droite: true),
          Colonne('Motif', flex: 3),
          Colonne('Opérateur', flex: 3),
          Colonne('Date', flex: 3),
        ],
        cellules: (i) => [l[i].intCIP, l[i].strNAME, '${l[i].intNUMBERRETURN}', '${l[i].intNUMBERANSWER}', formaterMontant(l[i].prixPaf), l[i].motif, l[i].operateur, _quand(l[i])],
        carte: (i) => CarteLigne(
          titre: l[i].strNAME,
          lignes: [
            'CIP ${l[i].intCIP}',
            'Quantité retournée : ${l[i].intNUMBERRETURN} · répondue : ${l[i].intNUMBERANSWER}',
            'Motif : ${l[i].motif}',
            'Opérateur : ${l[i].operateur} · ${_quand(l[i])}',
          ],
          libelleValeur: 'Prix d\'achat',
          valeur: formaterMontant(l[i].prixPaf),
        ),
      ),
    ];
  }
}

/// Produits retournés (avoirs) de la période choisie dans la liste des retours.
class ProduitsRetournesNouveau extends StatefulWidget {
  final Periode periode;
  const ProduitsRetournesNouveau({super.key, required this.periode});

  @override
  State<ProduitsRetournesNouveau> createState() => _ProduitsRetournesNouveauState();
}

class _ProduitsRetournesNouveauState extends State<ProduitsRetournesNouveau>
    with ChargementSuivi<ProduitsRetournesNouveau, List<AvoirFournisseurProduit>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() async =>
      await RetoursFournisseurs.produits(context, widget.periode.debut, widget.periode.fin, onSessionInvalid: sessionInvalide(context)) ??
      const <AvoirFournisseurProduit>[]);

  static String _quand(AvoirFournisseurProduit p) => p.dateAvoir != null ? DateFormat('dd/MM/yyyy HH:mm').format(p.dateAvoir!) : 'N/A';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Produits Retournés')),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_detail'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            Row(children: [
              const Icon(Icons.event_outlined, size: 16, color: Charte.gris),
              const SizedBox(width: 6),
              Expanded(child: Text(widget.periode.resume, style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des produits retournés…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <AvoirFournisseurProduit>[];
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucun produit retourné', texte: 'Aucun produit retourné sur cette période.', icone: Icons.inventory_2_outlined)];
    }
    final quantite = l.fold<int>(0, (s, p) => s + p.quantite);
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Produits', valeur: formaterNombre(l.length), id: 'avoirs_produits', enAvant: true),
        ChiffreCle(libelle: 'Quantité', valeur: formaterNombre(quantite), id: 'avoirs_quantite'),
      ]),
      const TitreSection('Produits retournés'),
      ListeOuTableau(
        nombre: l.length,
        colonnes: const [
          Colonne('CIP', flex: 2),
          Colonne('Produit', flex: 5),
          Colonne('Quantité', flex: 2, droite: true),
          Colonne('Prix d\'achat', flex: 2, droite: true),
          Colonne('Motif', flex: 3),
          Colonne('N° BL', flex: 2),
          Colonne('Date avoir', flex: 3),
        ],
        cellules: (i) => [l[i].cip, l[i].libelle, '${l[i].quantite}', formaterMontant(l[i].prixAchatHt), l[i].natureReclamation, l[i].numeroBl, _quand(l[i])],
        carte: (i) => CarteLigne(
          titre: l[i].libelle,
          lignes: ['CIP ${l[i].cip} · Quantité ${l[i].quantite}', 'Motif : ${l[i].natureReclamation}', 'N° BL ${l[i].numeroBl} · ${_quand(l[i])}'],
          libelleValeur: 'Prix d\'achat',
          valeur: formaterMontant(l[i].prixAchatHt),
        ),
      ),
    ];
  }
}
