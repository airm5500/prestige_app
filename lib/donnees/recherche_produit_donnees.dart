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
import 'package:flutter/widgets.dart';

import '../models/analyse_article_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/saisie.dart';
import 'articles_donnees.dart';

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

  factory ProduitTrouve.deAnalyse(AnalyseArticle a) => ProduitTrouve(
        cip: a.codeCip,
        designation: a.libelle,
        emplacement: a.emplacement,
        prixVente: a.prixVente,
        stockTotal: a.stock,
        analyse: a,
      );
}

/// Résultat d'une recherche : produits et mode réellement appliqué.
class ResultatRechercheProduit {
  final List<ProduitTrouve> produits;

  /// Vrai : « contient » (/espace-produit/recherche) ; faux : repli « commence par » (/info, serveur ancien).
  final bool contient;
  const ResultatRechercheProduit(this.produits, {required this.contient});

  /// Le serveur limite la liste à 50 : au-delà, préciser la recherche.
  bool get limiteAtteinte => contient && produits.length >= RechercheProduit.maxResultats;
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

  /// Recherche « contient » ; serveur sans la route (404) : repli sur /info (« commence par »).
  static Future<ResultatRechercheProduit?> rechercher(BuildContext context, String texte, {VoidCallback? onSessionInvalid}) async {
    if (!assezLong(texte)) return null;
    try {
      final data = await ApiService().get(context, route, queryParams: parametres(texte), onSessionInvalid: onSessionInvalid);
      return ResultatRechercheProduit(lire(data), contient: true);
    } on ApiLoadException catch (e) {
      // Repli « serveur ancien » seulement sur un vrai 404 de la route, jamais quand Prestige n'est pas déployé (3.10.3).
      if (e.code != 404 || e.serveurIndisponible) rethrow;
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

  /// Analyse du produit [p] : celle déjà lue (repli) ou GET /info?search=<CIP> puis le CIP exact.
  static Future<AnalyseArticle?> analyse(BuildContext context, ProduitTrouve p, {VoidCallback? onSessionInvalid}) async {
    if (p.analyse != null) return p.analyse;
    if (!context.mounted) return null;
    final articles = await RechercheArticles.analyse(context, p.cip, onSessionInvalid: onSessionInvalid);
    return articles == null ? null : choisirParCip(articles, p.cip);
  }
}
