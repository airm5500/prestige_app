// lib/nouvelle_interface/modules/articles_nouveau.dart
// Analyse Article et Fiche Article de la nouvelle interface. Mêmes données que les écrans d'origine
// (RechercheArticles : GET /info?search= et GET /checkproduit?nompdt=, mêmes longueurs minimales, même nettoyage
// du texte), mise en page refaite : recherche contrôlée (longueur, caractères, anti-rebond, réponse d'une
// recherche remplacée ignorée), résultats en cartes (téléphone) ou en tableau (tablette), fiche détaillée avec
// chiffres clés en cartes (au lieu d'une fenêtre).
// 3.16.0 (« Analyse article lente ») : la liste d'Analyse Article vient de la recherche légère (RechercheProduit :
// /espace-produit/recherche, replis /vente/search puis /info), l'analyse complète (GET /info?search=<CIP exact>) n'est
// lue qu'au toucher d'un produit ; historique des mouvements sur une ligne par mouvement.
import 'package:flutter/material.dart';

import '../../donnees/articles_donnees.dart';
import '../../donnees/recherche_produit_donnees.dart';
import '../../models/analyse_article_model.dart';
import '../../models/produit_model.dart';
import '../../widgets/stock_reserve.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot2.dart' show messageResultat;

// ---------------------------------------------------------------------------------------------------------------
// Analyse Article
// ---------------------------------------------------------------------------------------------------------------

class AnalyseArticleNouveau extends StatefulWidget {
  const AnalyseArticleNouveau({super.key});

  /// Anti-rebond de la saisie (3.16.0 : 300 ms, comme Prestige Mobile).
  static const antiRebond = Duration(milliseconds: 300);

  @override
  State<AnalyseArticleNouveau> createState() => _AnalyseArticleNouveauState();
}

/// 3.16.0 (« Analyse article lente ») : liste par la recherche LÉGÈRE (RechercheProduit : /espace-produit/recherche,
/// replis /vente/search puis /info), anti-rebond 300 ms, réponse d'une saisie remplacée ignorée ; au toucher,
/// GET /info?search=<CIP exact> pour ce seul produit (cache court), puis la même fiche détaillée qu'avant.
class _AnalyseArticleNouveauState extends State<AnalyseArticleNouveau> with ChargementSuivi<AnalyseArticleNouveau, ResultatRechercheProduit> {
  final _recherche = TextEditingController();
  final _focus = FocusNode();
  String _terme = '';

  /// CIP dont l'analyse est en cours d'ouverture (un seul à la fois : anti double appui).
  String? _ouverture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _rechercher(String texte) {
    _terme = texte;
    if (!RechercheArticles.assezLongPourAnalyse(texte)) {
      abandonner();
      return;
    }
    charger(() => RechercheProduit.rechercher(context, texte, onSessionInvalid: sessionInvalide(context)));
  }

  Future<void> _ouvrir(ProduitTrouve p) async {
    if (_ouverture != null) return;
    setState(() => _ouverture = p.cip);
    try {
      final a = await RechercheProduit.analyse(context, p, onSessionInvalid: sessionInvalide(context));
      // Écran fermé pendant la lecture : rien n'est ouvert (la réponse remplit seulement le cache court).
      if (!mounted) return;
      if (a == null) {
        messageResultat(context, 'Analyse introuvable pour le CIP ${p.cip}.', echec: true);
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailAnalyseArticle(article: a)));
    } catch (e) {
      if (!mounted) return;
      final d = DiagnosticErreur.de(e);
      messageResultat(context, d.cause == CauseErreur.autre ? d.message : '${d.titre}. ${d.message}', echec: true);
    } finally {
      if (mounted) setState(() => _ouverture = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Analyse Article')),
        body: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          ChampRecherche(
            controleur: _recherche,
            focus: _focus,
            libelle: 'Rechercher un article',
            aide: 'Libellé (2 car.) ou code CIP (3 chiffres)',
            enCours: enCours,
            antiRebond: AnalyseArticleNouveau.antiRebond,
            onRecherche: _rechercher,
          ),
          const SizedBox(height: 8),
          ..._corps(),
        ]),
      );

  Widget? _attente(ProduitTrouve p) => _ouverture == p.cip
      ? const Padding(
          padding: EdgeInsets.only(left: 8, top: 2),
          child: SizedBox(key: Key('analyse_ouverture'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
      : null;

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Recherche en cours…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: () => _rechercher(_terme))];
    final r = donnees;
    if (r == null) {
      return const [
        EtatVide(
            titre: 'Recherchez un article',
            texte: 'Saisissez au moins 2 lettres du libellé ou 3 chiffres du code CIP.',
            icone: Icons.query_stats)
      ];
    }
    final l = r.produits;
    if (l.isEmpty) return [EtatVide(titre: 'Aucun article trouvé', texte: 'Aucun article valide pour « $_terme ».', icone: Icons.search_off)];
    return [
      TitreSection('${l.length} article${l.length > 1 ? 's' : ''}'),
      if (r.limiteAtteinte)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text('Les ${r.maximum} premiers : précisez la recherche pour voir les autres.',
              key: const Key('analyse_limite'), style: const TextStyle(color: Charte.gris, fontSize: 13)),
        ),
      ListeOuTableau(
        nombre: l.length,
        onTap: (i) => _ouvrir(l[i]),
        colonnes: const [
          Colonne('Code CIP', flex: 2),
          Colonne('Libellé', flex: 5),
          Colonne('Prix vente', flex: 2, droite: true),
          Colonne('Stock', flex: 1, droite: true),
          Colonne('Emplacement', flex: 2),
        ],
        cellules: (i) => [
          l[i].cip,
          l[i].designation,
          l[i].prixVente == null ? '—' : formaterMontant(l[i].prixVente),
          l[i].stockTotal == null ? 'N/A' : formaterNombre(l[i].stockTotal!),
          l[i].emplacement ?? '—',
        ],
        carte: (i) => CarteLigne(
          key: Key('article_${l[i].cip}'),
          titre: l[i].designation,
          lignes: [
            ['CIP ${l[i].cip}', if (l[i].stockTotal != null) 'Stock ${formaterNombre(l[i].stockTotal!)}', if (l[i].emplacement != null) l[i].emplacement!]
                .join(' · '),
          ],
          valeur: l[i].prixVente == null ? null : formaterMontant(l[i].prixVente),
          action: _attente(l[i]),
          onTap: () => _ouvrir(l[i]),
        ),
      ),
    ];
  }
}

/// Fiche détaillée d'un article analysé (mêmes informations que la fenêtre d'origine).
class DetailAnalyseArticle extends StatelessWidget {
  final AnalyseArticle article;
  const DetailAnalyseArticle({super.key, required this.article});

  /// Historique des mouvements (les derniers de chaque sorte) : (clé, libellé court, date, quantité), dans
  /// l'ordre d'origine. Libellés courts : « Inventaire · 12/11/2026 » et « Qté 1234 » tiennent sur une ligne à 320 dp.
  static List<(String, String, String?, int?)> mouvements(AnalyseArticle a) => [
        ('vente', 'Vente', a.dateDerniereVente, a.qteDerniereVente),
        ('achat', 'Achat', a.dateDernierAchat, a.qteDernierAchat),
        ('inventaire', 'Inventaire', a.dateDernierInventaire, a.qteDernierInventaire),
      ];

  @override
  Widget build(BuildContext context) {
    final a = article;
    final ventes = a.getVentesChartData();
    final max = ventes.fold<double>(0, (m, s) => s.y > m ? s.y : m);
    const mois = ['Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'];
    return Scaffold(
      appBar: AppBar(title: const Text('Détails de l\'article')),
      body: ListView(key: const Key('defilement_detail'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Text(a.libelle, style: const TextStyle(color: Charte.navy, fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 4, children: [
          Etiquette('CIP ${a.codeCip}', ton: Ton.gris),
          if ((a.classe ?? '').isNotEmpty) Etiquette('Classe ${a.classe}', ton: Ton.ambre),
          PastilleReappro(reserve: a.reserve, rayon: a.stock),
        ]),
        const SizedBox(height: 12),
        GrilleKpi([
          ChiffreCle(libelle: 'Stock actuel', valeur: a.stock?.toString() ?? 'N/A', id: 'stock', enAvant: true),
          ChiffreCle(libelle: 'Prix de vente', valeur: formaterMontant(a.prixVente), id: 'prix_vente'),
          ChiffreCle(libelle: 'Moyenne sur 3 mois', valeur: a.moyenne.toStringAsFixed(2), id: 'moyenne'),
          ChiffreCle(libelle: 'Qté totale vendue', valeur: '${a.quantiteVendue}', id: 'quantite'),
        ]),
        const SizedBox(height: 12),
        CarteSection(titre: 'Article', icone: Icons.article_outlined, enfants: [
          LigneDetail('Code CIP', a.codeCip),
          LigneDetail('Désignation', a.libelle),
          LigneDetail('Prix d\'achat', formaterMontant(a.prixAchat)),
          LigneDetail('Prix de vente', formaterMontant(a.prixVente)),
          LigneDetail('Grossiste', a.grossiste ?? 'N/A'),
          LigneDetail('Emplacement', a.emplacement ?? 'N/A'),
          LigneDetail('Moyenne par jour', a.moyenneJour.toStringAsFixed(2)),
        ]),
        CarteSection(titre: 'Stock rayon et réserve', icone: Icons.inventory_2_outlined, enfants: [
          for (final (libelle, valeur) in stockReserveInfos(a.stock, a.reserve)) LigneDetail(libelle, valeur),
        ]),
        // 3.16.0 : une ligne par DERNIER mouvement, date et quantité sur la MÊME ligne (quantité de 1 à 4 chiffres
        // jamais renvoyée à la ligne, même à 320 dp).
        CarteSection(titre: 'Historique des mouvements', icone: Icons.history, enfants: [
          for (final (cle, libelle, date, qte) in mouvements(a))
            LigneDetail('$libelle · ${date ?? 'N/A'}', 'Qté ${qte ?? 0}', uneLigne: true, key: Key('mouvement_$cle')),
        ]),
        CarteSection(titre: 'Ventes mensuelles', icone: Icons.bar_chart, enfants: [
          if (ventes.isEmpty)
            const Text('Aucune donnée de vente pour le graphique.', style: TextStyle(color: Charte.gris))
          else
            for (final s in ventes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 52, child: Text(mois[s.x.toInt() - 1], style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: max == 0 ? 0 : s.y / max, minHeight: 10, color: Charte.navy, backgroundColor: Charte.grisClair),
                    ),
                  ),
                  SizedBox(width: 48, child: Text(formaterNombre(s.y), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
              ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Fiche Article
// ---------------------------------------------------------------------------------------------------------------

class FicheArticleNouveau extends StatefulWidget {
  const FicheArticleNouveau({super.key});

  @override
  State<FicheArticleNouveau> createState() => _FicheArticleNouveauState();
}

class _FicheArticleNouveauState extends State<FicheArticleNouveau> with ChargementSuivi<FicheArticleNouveau, List<Produit>> {
  final _recherche = TextEditingController();
  String _terme = '';

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _rechercher(String texte) {
    _terme = texte;
    if (!RechercheArticles.assezLongPourFiche(texte)) {
      abandonner();
      return;
    }
    charger(() => RechercheArticles.fiche(context, texte, onSessionInvalid: sessionInvalide(context)));
  }

  void _ouvrir(Produit p) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailFicheArticle(produit: p)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fiche Article')),
        body: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          ChampRecherche(
            controleur: _recherche,
            libelle: 'Rechercher un produit',
            aide: 'Au moins 3 caractères',
            enCours: enCours,
            onRecherche: _rechercher,
          ),
          const SizedBox(height: 8),
          ..._corps(),
        ]),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Recherche en cours…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: () => _rechercher(_terme))];
    final l = donnees;
    if (l == null) {
      return const [EtatVide(titre: 'Recherchez un produit', texte: 'Saisissez au moins 3 caractères.', icone: Icons.article_outlined)];
    }
    if (l.isEmpty) return [EtatVide(titre: 'Aucun produit trouvé', texte: 'Aucun produit pour « $_terme ».', icone: Icons.search_off)];
    return [
      TitreSection('${l.length} produit${l.length > 1 ? 's' : ''}'),
      ListeOuTableau(
        nombre: l.length,
        onTap: (i) => _ouvrir(l[i]),
        colonnes: const [
          Colonne('Code CIP', flex: 2),
          Colonne('Désignation', flex: 5),
          Colonne('Prix vente', flex: 2, droite: true),
          Colonne('Stock', flex: 1, droite: true),
          Colonne('Réserve', flex: 1, droite: true),
          Colonne('Emplacement', flex: 2),
        ],
        cellules: (i) => [
          l[i].familleCip,
          l[i].designation,
          formaterMontant(l[i].prixVente),
          '${l[i].stockActuel}',
          l[i].reserve.geree ? '${l[i].reserve.stockReserve}' : '—',
          l[i].emplacement ?? 'N/A',
        ],
        carte: (i) => CarteLigne(
          titre: l[i].designation,
          lignes: ['CIP ${l[i].familleCip} · Stock ${l[i].stockActuel}'],
          pied: StockReserveResume(reserve: l[i].reserve, rayon: l[i].stock),
          valeur: formaterMontant(l[i].prixVente),
          onTap: () => _ouvrir(l[i]),
        ),
      ),
    ];
  }
}

/// Fiche détaillée d'un produit (mêmes informations que la fenêtre d'origine).
class DetailFicheArticle extends StatelessWidget {
  final Produit produit;
  const DetailFicheArticle({super.key, required this.produit});

  @override
  Widget build(BuildContext context) {
    final p = produit;
    return Scaffold(
      appBar: AppBar(title: const Text('Détails de l\'article')),
      body: ListView(key: const Key('defilement_detail'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Text(p.familleLibelle, style: const TextStyle(color: Charte.navy, fontSize: 19, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 4, children: [
          Etiquette('CIP ${p.familleCip}', ton: Ton.gris),
          PastilleReappro(reserve: p.reserve, rayon: p.stock),
        ]),
        const SizedBox(height: 12),
        GrilleKpi([
          ChiffreCle(libelle: 'Stock', valeur: '${p.stock}', id: 'stock', enAvant: true),
          ChiffreCle(libelle: 'Prix de vente', valeur: formaterMontant(p.pvente), id: 'prix_vente'),
          ChiffreCle(libelle: 'Prix d\'achat', valeur: formaterMontant(p.pachat), id: 'prix_achat'),
          ChiffreCle(libelle: 'Emplacement', valeur: p.emplacement ?? 'N/A', id: 'emplacement'),
        ]),
        const SizedBox(height: 12),
        CarteSection(titre: 'Article', icone: Icons.article_outlined, enfants: [
          LigneDetail('Code CIP', p.familleCip),
          LigneDetail('Désignation', p.familleLibelle),
          LigneDetail('Stock', '${p.stock}'),
          for (final (libelle, valeur) in stockReserveInfos(p.stock, p.reserve, avecRayon: false)) LigneDetail(libelle, valeur),
          LigneDetail('Prix d\'achat', formaterMontant(p.pachat)),
          LigneDetail('Prix de vente', formaterMontant(p.pvente)),
          LigneDetail('Emplacement', p.emplacement ?? 'N/A'),
        ]),
      ]),
    );
  }
}
