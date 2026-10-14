// lib/nouvelle_interface/modules/suivi_peremption_nouveau.dart
// Suivi Péremption de la nouvelle interface. Mêmes données que l'écran d'origine (SuiviPeremption.page :
// GET /fichearticle/perimes, mêmes paramètres query / nbreMois / page / start / limit, pages suivantes chargées au
// défilement), mise en page refaite : recherche contrôlée (anti-rebond), chiffres clés (lots, quantité, valeurs),
// filtre « mois avant péremption » dans une feuille du bas, PDF d'origine dans le menu Exporter, lots en cartes
// (téléphone) ou en tableau (tablette). Chargé à l'ouverture, sans filtre (comme l'écran d'origine).
import 'package:flutter/material.dart';

import '../../donnees/peremption_donnees.dart';
import '../../models/suivi_peremption_model.dart';
import '../../utils/saisie.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';

class SuiviPeremptionNouveau extends StatefulWidget {
  const SuiviPeremptionNouveau({super.key});

  @override
  State<SuiviPeremptionNouveau> createState() => _SuiviPeremptionNouveauState();
}

class _SuiviPeremptionNouveauState extends State<SuiviPeremptionNouveau> {
  final _recherche = TextEditingController();
  final _defilement = ScrollController();

  /// Champ de la feuille des filtres (gardé par l'écran : la feuille peut encore s'animer après sa fermeture).
  final _champMois = TextEditingController();
  String _mois = '';

  SuiviPeremptionResponse? _donnees;
  bool _enCours = false;
  bool _suiteEnCours = false;
  Object? _erreur;
  int _page = 1;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(() {
      if (_defilement.position.pixels >= _defilement.position.maxScrollExtent - 200 &&
          !_enCours &&
          !_suiteEnCours &&
          SuiviPeremption.aSuite(_donnees)) {
        _suite();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    _defilement.dispose();
    _champMois.dispose();
    super.dispose();
  }

  /// Première page (nouvelle recherche, nouveau filtre, Réessayer) : toute requête précédente est abandonnée.
  Future<void> _charger() async {
    final g = ++_generation;
    setState(() {
      _enCours = true;
      _suiteEnCours = false;
      _erreur = null;
      _page = 1;
    });
    try {
      final r = await SuiviPeremption.page(context, recherche: _recherche.text, mois: _mois, page: 1);
      if (!mounted || g != _generation) return;
      setState(() {
        _donnees = r;
        _enCours = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _donnees = null;
        _erreur = e;
        _enCours = false;
      });
    }
  }

  /// Page suivante (défilement).
  Future<void> _suite() async {
    final g = _generation;
    final page = _page + 1;
    setState(() => _suiteEnCours = true);
    try {
      final r = await SuiviPeremption.page(context, recherche: _recherche.text, mois: _mois, page: page);
      if (!mounted || g != _generation) return;
      setState(() {
        _donnees = SuiviPeremption.fusionner(_donnees, r);
        _page = page;
        _suiteEnCours = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() => _suiteEnCours = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(DiagnosticErreur.de(e).message)));
    }
  }

  Future<void> _filtres() async {
    final champ = _champMois..text = _mois;
    String? erreur;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les lots',
      effacer: () {
        champ.clear();
        erreur = null;
      },
      valider: () {
        if (SuiviPeremption.moisValide(champ.text)) return true;
        return false; // le motif est déjà affiché sous le champ
      },
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Lots qui périment dans les prochains mois. Laissez vide pour voir tous les lots suivis.',
            style: TextStyle(color: Charte.grisTexte, fontSize: 14)),
        const SizedBox(height: 12),
        TextField(
          key: const Key('filtre_mois'),
          controller: champ,
          keyboardType: TextInputType.number,
          inputFormatters: Saisie.entierFormatters(3),
          onChanged: (_) =>
              setState(() => erreur = SuiviPeremption.moisValide(champ.text) ? null : 'Nombre de mois invalide (0 à ${Saisie.maxMois}).'),
          decoration: InputDecoration(
            labelText: 'Nombre de mois (0 à ${Saisie.maxMois})',
            suffixText: 'mois',
            errorText: erreur,
          ),
        ),
      ]),
    );
    if (applique && mounted) {
      setState(() => _mois = champ.text.trim());
      _charger();
    }
  }

  Future<void> _pdf() async {
    final d = _donnees;
    if (d == null || d.data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune donnée à imprimer')));
      return;
    }
    await SuiviPeremption.imprimerPdf(d);
  }

  static bool _perime(PeremptionItem l) => l.statut.toLowerCase().contains('périmé');

  void _detail(PeremptionItem l) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SingleChildScrollView(
          key: const Key('detail_lot'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(l.libelle, style: const TextStyle(color: Charte.navy, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: Etiquette(l.statut, ton: _perime(l) ? Ton.rouge : Ton.ambre)),
            const SizedBox(height: 8),
            LigneDetail('Code CIP', l.codeCip),
            LigneDetail('Lot', l.numLot),
            LigneDetail('Date Péremption', l.datePerement, gras: true, couleur: Charte.rougeTexte),
            LigneDetail('Quantité', '${l.quantiteLot.toInt()}', gras: true),
            const Divider(),
            LigneDetail('Prix Achat', '${l.valeurAchat.toInt()}'),
            LigneDetail('Prix Vente', '${l.valeurVente.toInt()}'),
            const Divider(),
            LigneDetail('Rayon', l.libelleRayon),
            LigneDetail('Famille', l.libelleFamille),
            LigneDetail('Grossiste', l.libelleGrossiste),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Suivi Péremption'), actions: [
          BoutonFiltres(actifs: _mois.isEmpty ? 0 : 1, onPressed: _filtres),
          MenuExports(actions: [ActionExport('PDF de la liste', Icons.picture_as_pdf_outlined, _pdf)]),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child:
              ListView(controller: _defilement, key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            ChampRecherche(
              controleur: _recherche,
              libelle: 'Rechercher un produit',
              aide: 'Libellé ou code CIP',
              enCours: _enCours,
              onRecherche: (_) => _charger(),
            ),
            if (_mois.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Etiquette('Péremption dans $_mois mois'),
                  TextButton(
                    key: const Key('filtres_retirer'),
                    onPressed: () {
                      setState(() => _mois = '');
                      _charger();
                    },
                    child: const Text('Retirer le filtre'),
                  ),
                ]),
              ),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (_enCours && _donnees == null) return const [EtatChargement(texte: 'Recherche des lots…')];
    if (_erreur != null) return [EtatErreur(erreur: _erreur!, reessayer: _charger)];
    final d = _donnees;
    if (d == null || d.data.isEmpty) {
      return const [
        EtatVide(
            titre: 'Aucun produit périmé ou proche de la péremption', texte: 'Modifiez la recherche ou le filtre.', icone: Icons.verified_outlined)
      ];
    }
    final m = d.metaData;
    final l = d.data;
    return [
      GrilleKpi([
        ChiffreCle(
            libelle: 'Lots', valeur: formaterNombre(d.total), id: 'lots', enAvant: true, detail: '${l.length} affiché${l.length > 1 ? 's' : ''}'),
        ChiffreCle(libelle: 'Qté Totale', valeur: formaterNombre(m.totalQuantiteLot.toInt()), id: 'quantite'),
        ChiffreCle(libelle: 'Val. Achat', valeur: formaterMontant(m.totalValeurAchat.toInt()), id: 'achat'),
        ChiffreCle(libelle: 'Val. Vente', valeur: formaterMontant(m.totalValeurVente.toInt()), id: 'vente'),
      ]),
      const TitreSection('Lots'),
      ListeOuTableau(
        nombre: l.length,
        onTap: (i) => _detail(l[i]),
        colonnes: const [
          Colonne('Code', flex: 2),
          Colonne('Libellé', flex: 5),
          Colonne('Lot', flex: 2),
          Colonne('Péremption', flex: 2),
          Colonne('Qté', flex: 1, droite: true),
          Colonne('Statut', flex: 3),
        ],
        cellules: (i) => [l[i].codeCip, l[i].libelle, l[i].numLot, l[i].datePerement, '${l[i].quantiteLot.toInt()}', l[i].statut],
        carte: (i) => CarteLigne(
          titre: l[i].libelle,
          bande: _perime(l[i]) ? Charte.rouge : Charte.ambre,
          etiquette: Etiquette(l[i].statut, ton: _perime(l[i]) ? Ton.rouge : Ton.ambre),
          lignes: ['Lot ${l[i].numLot} · ${l[i].datePerement}', 'CIP ${l[i].codeCip}'],
          libelleValeur: 'Qté',
          valeur: '${l[i].quantiteLot.toInt()}',
          onTap: () => _detail(l[i]),
        ),
      ),
      if (_suiteEnCours) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
    ];
  }
}
