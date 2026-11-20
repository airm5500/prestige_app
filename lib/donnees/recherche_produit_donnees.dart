// lib/donnees/recherche_produit_donnees.dart
// Recherche de produit de l'onglet « Analyses » de la nouvelle interface (3.9.0, demande du pharmacien : chercher
// un produit en mode « CONTIENT » et ouvrir son analyse).
//
// Vérifié dans le serveur Prestige :
//  - GET /info?search= (Analyse Article, InfoArticleServiceImpl.fetchInfoArticles) n'a PAS de mode « contient » :
//    le serveur ajoute lui-même le joker final (« CIP ou libellé COMMENCE PAR ») et ne lit aucun autre paramètre ;
//  - GET /espace-produit/recherche?q= (EspaceProduitRessource.rechercher) cherche en mode « contient » dans le CIP,
//    le nom et le code EAN, à partir de 2 caractères, 50 résultats au plus, sans donnée d'achat ni de marge, en
//    UNE requête (rapide) → {total, data: [{cip, designation, emplacement, prixVente, stockRayon, stockReserve,
//    stockTotal, id}]}.
// Donc : 1. liste par /espace-produit/recherche (contient) ; 2. au toucher, détail de l'analyse par
// /info?search=<CIP> et on garde l'article dont le code CIP est EXACTEMENT celui choisi (même écran de détail
// qu'Analyse Article, mêmes données).
// Serveur plus ancien sans /espace-produit (404) : la recherche passe par /info (mode « commence par », comme
// Analyse Article) et l'écran le dit.
//
// 3.16.0 (« Analyse article lente », retour du pharmacien) : Analyse Article utilise aussi cette recherche légère
// (avant : GET /info?search= à chaque saisie, la route la plus lourde : ventes, achats, inventaire de chaque article
// trouvé). Comme la fiche produit de Prestige Mobile (lib/accueil/fiche_produit_screen.dart) :
//  - liste par /espace-produit/recherche (publique, sans droit ; déployée en officine, 76aa5fc1) ;
//  - 404 (serveur plus ancien) ou 403 (route fermée par l'officine) → GET /vente/search?query=&start=0&limit=30
//    (VenteRessource.searchProduct, session seule, la recherche de l'écran de vente : CIP, nom, emplacement, prix,
//    stock) ; 404 / 403 encore → /info (« commence par », dit à l'écran) ;
//  - au toucher : GET /info?search=<CIP exact> pour CE produit seulement ;
//  - cache mémoire court (60 s, lib/donnees/cache_court.dart) des listes et des analyses : retaper la même saisie ou
//    rouvrir le même produit ne relit rien ; une lecture en cours est partagée.
import 'package:flutter/widgets.dart';

import '../models/analyse_article_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/saisie.dart';
import 'articles_donnees.dart';
import 'cache_court.dart';

/// Produit trouvé (ligne de la liste).
class ProduitTrouve {
  final String cip;
  final String designation;
  final String? emplacement;
  final num? prixVente;
  final num? stockTotal;

  /// Article déjà complet (repli par /info) : son détail s'ouvre sans nouvelle requête.
  final AnalyseArticle? analyse;
  const ProduitTrouve({required this.cip, required this.designation, this.emplacement, this.prixVente, this.stockTotal, this.analyse});

  static num? _nombre(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}'.trim());

  /// Ligne de /espace-produit/recherche (lecture tolérante) ; null sans CIP ni désignation.
  static ProduitTrouve? lire(dynamic j) {
    if (j is! Map) return null;
    final cip = '${j['cip'] ?? ''}'.trim();
    final nom = '${j['designation'] ?? ''}'.trim();
    if (cip.isEmpty || nom.isEmpty) return null;
    final empl = '${j['emplacement'] ?? ''}'.trim();
    return ProduitTrouve(
      cip: cip,
      designation: nom,
      emplacement: empl.isEmpty ? null : empl,
      prixVente: _nombre(j['prixVente']),
      stockTotal: _nombre(j['stockTotal']) ?? _nombre(j['stockRayon']),
    );
  }

  /// Ligne de GET /vente/search (SearchDTO : intCIP, strNAME, strLIBELLEE, intPRICE, intNUMBERAVAILABLE) ; null
  /// sans CIP ni nom.
  static ProduitTrouve? lireVente(dynamic j) {
    if (j is! Map) return null;
    final cip = '${j['intCIP'] ?? ''}'.trim();
    final nom = '${j['strNAME'] ?? ''}'.trim();
    if (cip.isEmpty || nom.isEmpty) return null;
    final empl = '${j['strLIBELLEE'] ?? ''}'.trim();
    return ProduitTrouve(
      cip: cip,
      designation: nom,
      emplacement: empl.isEmpty ? null : empl,
      prixVente: _nombre(j['intPRICE']),
      stockTotal: _nombre(j['intNUMBERAVAILABLE']),
    );
  }

  factory ProduitTrouve.deAnalyse(AnalyseArticle a) => ProduitTrouve(
        cip: a.codeCip,
        designation: a.libelle,
        emplacement: a.emplacement,
        prixVente: a.prixVente,
        stockTotal: a.stock,
        analyse: a,
      );
}

/// Route qui a répondu à une recherche.
enum SourceRecherche {
  /// GET /espace-produit/recherche (« contient », 50 au plus).
  espaceProduit,

  /// GET /vente/search (recherche de l'écran de vente, 30 au plus).
  vente,

  /// GET /info (« commence par », serveur ancien).
  info,
}

/// Résultat d'une recherche : produits et mode réellement appliqué.
class ResultatRechercheProduit {
  final List<ProduitTrouve> produits;

  /// Vrai : liste légère (/espace-produit/recherche, ou /vente/search) ; faux : repli « commence par » (/info, serveur
  /// ancien).
  final bool contient;

  /// Route qui a répondu.
  final SourceRecherche source;
  const ResultatRechercheProduit(this.produits, {required this.contient, SourceRecherche? source})
      : source = source ?? (contient ? SourceRecherche.espaceProduit : SourceRecherche.info);

  /// Le serveur limite la liste (50, ou 30 par /vente/search) : au-delà, préciser la recherche.
  bool get limiteAtteinte => switch (source) {
        SourceRecherche.espaceProduit => produits.length >= RechercheProduit.maxResultats,
        SourceRecherche.vente => produits.length >= RechercheProduit.maxResultatsVente,
        SourceRecherche.info => false,
      };

  /// Nombre de produits au plus rendus par la route qui a répondu.
  int get maximum => source == SourceRecherche.vente ? RechercheProduit.maxResultatsVente : RechercheProduit.maxResultats;
}

class RechercheProduit {
  RechercheProduit._();

  static const route = AppConstants.rechercheProduitEndpoint;

  /// Nombre de résultats rendus au plus par le serveur (EspaceProduitRessource.MAX_RESULTATS).
  static const maxResultats = 50;

  /// Même minimum que le serveur (EspaceProduitRessource.LONGUEUR_MINIMALE) : 2 caractères.
  static bool assezLong(String texte) => Saisie.recherche(texte).length >= 2;

  /// Paramètres de la recherche « contient » (seul « q » : pas de DCI).
  static Map<String, String> parametres(String texte) => {'q': Saisie.recherche(texte)};

  /// Produits de la réponse ({data: [...]} ou liste), lignes illisibles écartées.
  static List<ProduitTrouve> lire(dynamic data) {
    final liste = data is Map && data['data'] is List ? data['data'] as List : (data is List ? data : const []);
    return [for (final j in liste) ProduitTrouve.lire(j)].whereType<ProduitTrouve>().toList();
  }

  /// Route de repli (3.16.0) : la recherche de l'écran de vente.
  static const routeVente = '/vente/search';

  /// Produits rendus au plus par /vente/search (limit envoyé).
  static const maxResultatsVente = 30;

  static Map<String, String> parametresVente(String texte) => {'query': Saisie.recherche(texte), 'start': '0', 'limit': '$maxResultatsVente'};

  /// Produits de la réponse de /vente/search ({data: [...]}).
  static List<ProduitTrouve> lireVente(dynamic data) {
    final liste = data is Map && data['data'] is List ? data['data'] as List : (data is List ? data : const []);
    return [for (final j in liste) ProduitTrouve.lireVente(j)].whereType<ProduitTrouve>().toList();
  }

  /// Cache court des listes (60 s) et des analyses par CIP (60 s).
  static final cacheListes = CacheCourt<ResultatRechercheProduit?>(duree: const Duration(seconds: 60));
  static final cacheAnalyses = CacheCourt<AnalyseArticle?>(duree: const Duration(seconds: 60));

  /// 404 « route absente » (Prestige déployé) ou 403 : la route suivante est essayée.
  static bool _repli(ApiLoadException e) => (e.code == 404 && !e.serveurIndisponible) || e.code == 403 || e.nature == NatureErreur.droit;

  /// Recherche « contient » (cache court) ; serveur sans la route (404) ou route refusée (403) : /vente/search, puis
  /// /info (« commence par »).
  static Future<ResultatRechercheProduit?> rechercher(BuildContext context, String texte, {VoidCallback? onSessionInvalid}) async {
    if (!assezLong(texte)) return null;
    final cle = '${CacheCourt.source(context)}|${Saisie.recherche(texte).toLowerCase()}';
    return cacheListes.lire(cle, () => _rechercher(context, texte, onSessionInvalid: onSessionInvalid));
  }

  static Future<ResultatRechercheProduit?> _rechercher(BuildContext context, String texte, {VoidCallback? onSessionInvalid}) async {
    try {
      final data = await ApiService().get(context, route, queryParams: parametres(texte), onSessionInvalid: onSessionInvalid);
      return ResultatRechercheProduit(lire(data), contient: true);
    } on ApiLoadException catch (e) {
      // Repli « serveur ancien » seulement sur un vrai 404 de la route, jamais quand Prestige n'est pas déployé (3.10.3).
      if (!_repli(e)) rethrow;
    }
    if (!context.mounted) return null;
    try {
      final data = await ApiService().get(context, routeVente, queryParams: parametresVente(texte), onSessionInvalid: onSessionInvalid);
      return ResultatRechercheProduit(lireVente(data), contient: true, source: SourceRecherche.vente);
    } on ApiLoadException catch (e) {
      if (!_repli(e)) rethrow;
    }
    if (!context.mounted) return null;
    final articles = await RechercheArticles.analyse(context, texte, onSessionInvalid: onSessionInvalid);
    return ResultatRechercheProduit([for (final a in articles ?? const <AnalyseArticle>[]) ProduitTrouve.deAnalyse(a)], contient: false);
  }

  /// Article de /info dont le code CIP est exactement [cip] (null si absent).
  static AnalyseArticle? choisirParCip(List<AnalyseArticle> articles, String cip) {
    final c = cip.trim();
    for (final a in articles) {
      if (a.codeCip.trim() == c) return a;
    }
    return null;
  }

  /// Analyse du produit [p] : celle déjà lue (repli) ou GET /info?search=<CIP> puis le CIP exact (cache court).
  static Future<AnalyseArticle?> analyse(BuildContext context, ProduitTrouve p, {VoidCallback? onSessionInvalid}) async {
    if (p.analyse != null) return p.analyse;
    if (!context.mounted) return null;
    return cacheAnalyses.lire('${CacheCourt.source(context)}|${p.cip.trim()}', () async {
      final articles = await RechercheArticles.analyse(context, p.cip, onSessionInvalid: onSessionInvalid);
      return articles == null ? null : choisirParCip(articles, p.cip);
    });
  }
}
