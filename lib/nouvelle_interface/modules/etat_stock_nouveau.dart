// lib/nouvelle_interface/modules/etat_stock_nouveau.dart
// État de Stock de la nouvelle interface. Mêmes données que l'écran d'origine (EtatStock,
// lib/donnees/etat_stock_donnees.dart) : emplacements et grossistes chargés à l'ouverture, recherche paginée
// GET /fichearticle/comparaison (15 articles par page, mêmes paramètres). Mise en page refaite : recherche contrôlée
// (anti-rebond), filtres (emplacement, comparaison de stock + quantité contrôlée) dans la feuille du bas, chiffres
// clés, articles en cartes (téléphone) ou tableau (tablette), « Afficher plus » (page suivante, un appel par appui),
// détail d'un article dans une feuille. Comme l'écran d'origine, rien n'est cherché avant une recherche ou un filtre.
import 'package:flutter/material.dart';

import '../../donnees/etat_stock_donnees.dart';
import '../../models/common_data_model.dart';
import '../../models/etat_stock_article_model.dart';
import '../../utils/saisie.dart';
import '../charte.dart';
import '../composants.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import 'commun.dart';
import 'commun_lot2.dart';

class EtatStockNouveau extends StatefulWidget {
  const EtatStockNouveau({super.key});

  @override
  State<EtatStockNouveau> createState() => _EtatStockNouveauState();
}

class _EtatStockNouveauState extends State<EtatStockNouveau> {
  final _recherche = TextEditingController();
  final _champQuantite = TextEditingController();

  OptionsEtatStock? _options;
  Object? _erreurOptions;

  // Filtres appliqués.
  CommonData? _rayon;
  String? _comparaison;
  String _quantite = '';

  // Résultats.
  final _articles = <EtatStockArticleModel>[];
  int _total = 0;
  int _page = 0;
  bool _cherche = false;
  bool _enCours = false;
  bool _suiteEnCours = false;
  Object? _erreur;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chargerOptions();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    _champQuantite.dispose();
    super.dispose();
  }

  Future<void> _chargerOptions() async {
    setState(() => _erreurOptions = null);
    try {
      final o = await EtatStock.options(context);
      if (mounted) setState(() => _options = o);
    } catch (e) {
      if (mounted) setState(() => _erreurOptions = e);
    }
  }

  int get _actifs => (_rayon == null ? 0 : 1) + (_comparaison == null ? 0 : 1);

  /// Première page (nouvelle recherche, filtres, Réessayer) ; toute recherche précédente est abandonnée.
  Future<void> _chercher() async {
    final g = ++_generation;
    setState(() {
      _cherche = true;
      _enCours = true;
      _suiteEnCours = false;
      _erreur = null;
    });
    try {
      final p = await EtatStock.page(context,
          recherche: _recherche.text, codeRayon: _rayon?.id ?? '', quantite: _quantite, comparaison: _comparaison, page: 1);
      if (!mounted || g != _generation) return;
      setState(() {
        _articles
          ..clear()
          ..addAll(p.articles);
        _total = p.total;
        _page = 1;
        _enCours = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _articles.clear();
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
      final p = await EtatStock.page(context,
          recherche: _recherche.text, codeRayon: _rayon?.id ?? '', quantite: _quantite, comparaison: _comparaison, page: _page + 1);
      if (!mounted || g != _generation) return;
      setState(() {
        _articles.addAll(p.articles);
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

  void _surRecherche(String texte) {
    if (texte.isEmpty && _actifs == 0) {
      _generation++;
      setState(() {
        _cherche = false;
        _articles.clear();
        _erreur = null;
        _enCours = false;
      });
      return;
    }
    _chercher();
  }

  Future<void> _filtres() async {
    if (_options == null && _erreurOptions != null) _chargerOptions();
    String rayon = _rayon?.id ?? '';
    String? comparaison = _comparaison;
    final champ = _champQuantite..text = _quantite;
    String? erreur;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer le stock',
      libelleAppliquer: 'Rechercher',
      effacer: () {
        rayon = '';
        comparaison = null;
        champ.clear();
        erreur = null;
      },
      valider: () => EtatStock.erreurFiltre(comparaison, champ.text.trim()) == null,
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChoixListe(
          key: const Key('filtre_emplacement'),
          libelle: 'Emplacement',
          icone: Icons.shelves,
          options: _options == null ? null : [for (final r in _options!.rayons) OptionListe(r.id, r.libelle)],
          erreur: _erreurOptions,
          valeur: rayon,
          tous: 'Tous les emplacements',
          onChanged: (v) => setState(() => rayon = v),
        ),
        const SizedBox(height: 14),
        const Text('Stock', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        PucesChoix<String?>(
          choix: [(null, 'Sans filtre'), for (final e in EtatStock.comparaisons.entries) (e.key, e.value)],
          valeur: comparaison,
          cle: (v, _) => Key('filtre_stock_${v ?? 'aucun'}'),
          onChanged: (v) => setState(() {
            comparaison = v;
            erreur = EtatStock.erreurFiltre(v, champ.text.trim());
          }),
        ),
        if (comparaison != null) ...[
          const SizedBox(height: 10),
          TextField(
            key: const Key('filtre_quantite'),
            controller: champ,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: Saisie.entierSigneFormatters(5), // -99 999 à 99 999
            onChanged: (_) => setState(() => erreur = EtatStock.erreurFiltre(comparaison, champ.text.trim())),
            decoration: InputDecoration(labelText: 'Quantité (${EtatStock.comparaisons[comparaison]})', errorText: erreur),
          ),
        ],
      ]),
    );
    if (!applique || !mounted) return;
    setState(() {
      _rayon = rayon.isEmpty ? null : _options?.rayons.where((r) => r.id == rayon).firstOrNull;
      _comparaison = comparaison;
      _quantite = comparaison == null ? '' : champ.text.trim();
    });
    _chercher();
  }

  void _retirerFiltres() {
    setState(() {
      _rayon = null;
      _comparaison = null;
      _quantite = '';
    });
    _surRecherche(Saisie.recherche(_recherche.text));
  }

  void _detail(EtatStockArticleModel a) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SingleChildScrollView(
          key: const Key('detail_article'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(a.libelle, style: const TextStyle(color: Charte.navy, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: _pastilleStock(a)),
            const SizedBox(height: 8),
            LigneDetail('Code', a.code),
            LigneDetail('EAN', a.codeEan ?? '-'),
            const Divider(),
            LigneDetail('Stock', '${a.stock.toInt()}', gras: true),
            LigneDetail('Prix Vente', formaterMontant(a.prixVente.toInt())),
            LigneDetail('Prix Achat', formaterMontant(a.prixAchat.toInt())),
            const Divider(),
            LigneDetail('Rayon', a.rayonLibelle),
            LigneDetail('Inventaire', a.dateInventaire ?? '-'),
            LigneDetail('Dernière Entrée', a.dateEntree ?? '-'),
            const Divider(),
            LigneDetail('Qté Réappro', '${a.qteReappro?.toInt() ?? 0}'),
            LigneDetail('Grossiste', _options?.grossistes[a.grossisteId] ?? 'Inconnu'),
          ]),
        ),
      );

  static Widget _pastilleStock(EtatStockArticleModel a) =>
      a.stock <= 0 ? Etiquette('Stock ${a.stock.toInt()} · rupture', ton: Ton.rouge) : Etiquette('Stock ${a.stock.toInt()}', ton: Ton.vert);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('État de Stock'), actions: [BoutonFiltres(actifs: _actifs, onPressed: _filtres)]),
        body: RefreshIndicator(
          onRefresh: () async {
            if (_cherche) await _chercher();
          },
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            ChampRecherche(
              controleur: _recherche,
              libelle: 'Rechercher un article',
              aide: 'Nom, code ou scan',
              enCours: _enCours,
              onRecherche: _surRecherche,
            ),
            EtiquettesFiltres(etiquettes: [
              if (_rayon != null) 'Emplacement : ${_rayon!.libelle}',
              if (_comparaison != null) 'Stock ${EtatStock.comparaisons[_comparaison]} $_quantite',
            ], onRetirer: _retirerFiltres),
            if (_erreurOptions != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: Charte.ambreTexte, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Emplacements non chargés : ${DiagnosticErreur.de(_erreurOptions!).titre}', style: const TextStyle(color: Charte.ambreTexte))),
                  TextButton(onPressed: _chargerOptions, child: const Text('Réessayer')),
                ]),
              ),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (!_cherche) {
      return const [
        EtatVide(
            titre: 'Recherchez un article',
            texte: 'Saisissez un nom ou un code, ou choisissez un filtre (bouton Filtres).',
            icone: Icons.warehouse_outlined),
      ];
    }
    if (_enCours) return const [EtatChargement(texte: 'Recherche des articles…')];
    if (_erreur != null) return [EtatErreur(erreur: _erreur!, reessayer: _chercher)];
    if (_articles.isEmpty) {
      return const [EtatVide(titre: 'Aucun résultat trouvé', texte: 'Modifiez la recherche ou les filtres.', icone: Icons.search_off)];
    }
    final l = _articles;
    final ruptures = l.where((a) => a.stock <= 0).length;
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Articles trouvés', valeur: formaterNombre(_total), id: 'articles', enAvant: true, detail: '${formaterNombre(l.length)} affichés'),
        ChiffreCle(libelle: 'Stock nul ou négatif', valeur: formaterNombre(ruptures), id: 'ruptures', detail: 'parmi les affichés'),
      ]),
      const TitreSection('Articles'),
      ListeOuTableau(
        nombre: l.length,
        onTap: (i) => _detail(l[i]),
        colonnes: const [
          Colonne('Code', flex: 2),
          Colonne('Libellé', flex: 5),
          Colonne('Rayon', flex: 3),
          Colonne('PA', flex: 2, droite: true),
          Colonne('PV', flex: 2, droite: true),
          Colonne('Stock', flex: 1, droite: true),
        ],
        cellules: (i) => [
          l[i].code,
          l[i].libelle,
          l[i].rayonLibelle,
          formaterMontant(l[i].prixAchat.toInt()),
          formaterMontant(l[i].prixVente.toInt()),
          '${l[i].stock.toInt()}',
        ],
        carte: (i) => CarteLigne(
          titre: l[i].libelle,
          bande: l[i].stock <= 0 ? Charte.rouge : null,
          etiquette: l[i].stock <= 0 ? const Etiquette('Rupture', ton: Ton.rouge) : null,
          lignes: ['Code ${l[i].code} · ${l[i].rayonLibelle}', 'PA ${formaterMontant(l[i].prixAchat.toInt())} · PV ${formaterMontant(l[i].prixVente.toInt())}'],
          libelleValeur: 'Stock',
          valeur: '${l[i].stock.toInt()}',
          onTap: () => _detail(l[i]),
        ),
      ),
      PiedPagination(affichees: l.length, total: _total, enCours: _suiteEnCours, onPlus: _suite),
    ];
  }
}
