// lib/donnees/articles_donnees.dart
// Recherches d'articles COMMUNES aux deux interfaces (mêmes routes, mêmes paramètres, mêmes règles) :
//  - Analyse Article : GET /info?search= (libellé ≥ 2 caractères, code CIP numérique ≥ 3), articles sans libellé
//    écartés ;
//  - Fiche Article : GET /checkproduit?nompdt= (≥ 3 caractères).
// Le texte envoyé est nettoyé par Saisie.recherche (longueur maximale, caractères de contrôle retirés).
import 'package:flutter/widgets.dart';

import '../models/analyse_article_model.dart';
import '../models/produit_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/saisie.dart';

class RechercheArticles {
  RechercheArticles._();

  /// Analyse Article : la recherche part-elle pour [texte] (saisi, avant nettoyage) ?
  static bool assezLongPourAnalyse(String texte) {
    final t = texte.trim();
    return t.length >= (int.tryParse(t) != null ? 3 : 2);
  }

  /// Fiche Article : 3 caractères au moins.
  static bool assezLongPourFiche(String texte) => texte.trim().length >= 3;

  /// Articles de la réponse de /info ({data: [...]} ou liste), sans ceux dont le libellé manque.
  static List<AnalyseArticle> lireAnalyse(dynamic data) {
    List<dynamic> liste = [];
    if (data is Map<String, dynamic> && data['data'] is List) {
      liste = data['data'];
    } else if (data is List) {
      liste = data;
    }
    return liste.map((i) => AnalyseArticle.fromJson(i)).where((a) => a.libelle.isNotEmpty && a.libelle != 'N/A').toList();
  }

  /// Produits de la réponse de /checkproduit (liste attendue ; tout autre format = null).
  static List<Produit>? lireFiche(dynamic data) => data is List ? data.map((i) => Produit.fromJson(i)).toList() : null;

  static Future<List<AnalyseArticle>?> analyse(BuildContext context, String texte, {VoidCallback? onSessionInvalid}) async {
    final terme = Saisie.recherche(texte);
    if (terme.isEmpty) return null;
    final data = await ApiService().get(context, AppConstants.infoEndpoint, queryParams: {'search': terme}, onSessionInvalid: onSessionInvalid);
    return data == null ? null : lireAnalyse(data);
  }

  static Future<List<Produit>?> fiche(BuildContext context, String texte, {VoidCallback? onSessionInvalid}) async {
    final terme = Saisie.recherche(texte);
    if (terme.isEmpty) return null;
    return lireFiche(
        await ApiService().get(context, AppConstants.checkProduitEndpoint, queryParams: {'nompdt': terme}, onSessionInvalid: onSessionInvalid));
  }
}
