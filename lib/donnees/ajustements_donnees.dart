// lib/donnees/ajustements_donnees.dart
// Suivi des Ajustements, logique COMMUNE aux deux interfaces :
//  - motifs : GET /common/type-ajustements → « data » ;
//  - ajustements : GET /ajustement?dtStart=&dtEnd=&typeFiltre=&page=1&start=0&limit=100 → « data » ;
//  - produits d'un ajustement : GET /ajustement/items?ajustementId=&page=1&start=0&limit=100 → « data » ;
//  - analyse : valeur ajoutée (quantités positives × prix d'achat), valeur retirée (négatives) et leurs parts
//    dans le total absolu (même calcul que l'écran d'origine).
// Nouvelle interface (3.8.0, réponse du pharmacien) : « Afficher plus » au-delà de 100. Le serveur Prestige PAGINE
// déjà (AjustementRessource.allAjustement → MouvementProduitImpl.ajsutements : setFirstResult(start) /
// setMaxResults(limit), « total » = nombre d'ajustements de la période) : pages de 100 avec les MÊMES filtres,
// start=0, 100, 200… ([parametresPage], [page]). La première page est exactement la requête d'origine.
import 'package:flutter/widgets.dart';

import '../models/ajustement_detail_model.dart';
import '../models/ajustement_model.dart';
import '../models/common_data_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

/// Analyse d'un ajustement.
class AnalyseAjustement {
  final double positif;
  final double negatif;
  const AnalyseAjustement(this.positif, this.negatif);

  double get totalAbsolu => positif + negatif.abs();
  double get partPositif => totalAbsolu != 0 ? positif / totalAbsolu * 100 : 0;
  double get partNegatif => totalAbsolu != 0 ? negatif.abs() / totalAbsolu * 100 : 0;
}

/// Une page d'ajustements : [ajustements] reçus et [total] annoncé par le serveur (null : serveur sans total).
class PageAjustements {
  final List<Ajustement> ajustements;
  final int? total;
  const PageAjustements(this.ajustements, this.total);
}

class Ajustements {
  Ajustements._();

  static Map<String, String> parametres(DateTime debut, DateTime fin, {String typeId = ''}) => {
        'dtStart': DateFormatter.toApiFormat(debut),
        'dtEnd': DateFormatter.toApiFormat(fin),
        'typeFiltre': typeId,
        'page': '1',
        'start': '0',
        'limit': '100',
      };

  /// Taille d'une page (nouvelle interface) : la limite d'origine.
  static const taillePage = 100;

  /// Paramètres d'une page (nouvelle interface) : mêmes filtres que [parametres], page n° = start / 100 + 1,
  /// start = ajustements déjà chargés, limit = 100. start=0 : exactement [parametres].
  static Map<String, String> parametresPage(DateTime debut, DateTime fin, {String typeId = '', required int start}) => {
        ...parametres(debut, fin, typeId: typeId),
        'page': '${start ~/ taillePage + 1}',
        'start': '$start',
        'limit': '$taillePage',
      };

  /// Page lue : ajustements et « total » annoncé (null si le serveur ne l'indique pas). Réponse illisible : null.
  static PageAjustements? lirePage(dynamic data) {
    final l = lire(data);
    if (l == null) return null;
    final t = (data as Map)['total'];
    final total = t is num ? t.toInt() : (t is String ? int.tryParse(t.trim()) : null);
    return PageAjustements(l, total == null || total < 0 ? null : total);
  }

  static Future<PageAjustements> page(BuildContext context, DateTime debut, DateTime fin,
          {String typeId = '', required int start, VoidCallback? onSessionInvalid}) async =>
      lirePage(await ApiService().get(context, AppConstants.ajustementEndpoint,
          queryParams: parametresPage(debut, fin, typeId: typeId, start: start), onSessionInvalid: onSessionInvalid)) ??
      const PageAjustements([], 0);

  static Map<String, String> parametresDetail(String ajustementId) => {'ajustementId': ajustementId, 'page': '1', 'start': '0', 'limit': '100'};

  static List<CommonData>? lireTypes(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => CommonData.fromJson(i)).toList() : null;

  static List<Ajustement>? lire(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => Ajustement.fromJson(i)).toList() : null;

  static List<AjustementDetail>? lireDetails(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => AjustementDetail.fromJson(i)).toList() : null;

  static Future<List<CommonData>?> types(BuildContext context, {VoidCallback? onSessionInvalid}) async =>
      lireTypes(await ApiService().get(context, AppConstants.typeAjustementsEndpoint, onSessionInvalid: onSessionInvalid));

  static Future<List<Ajustement>?> charger(BuildContext context, DateTime debut, DateTime fin, {String typeId = '', VoidCallback? onSessionInvalid}) async =>
      lire(await ApiService().get(context, AppConstants.ajustementEndpoint,
          queryParams: parametres(debut, fin, typeId: typeId), onSessionInvalid: onSessionInvalid));

  static Future<List<AjustementDetail>?> details(BuildContext context, String ajustementId, {VoidCallback? onSessionInvalid}) async =>
      lireDetails(await ApiService().get(context, AppConstants.ajustementItemsEndpoint,
          queryParams: parametresDetail(ajustementId), onSessionInvalid: onSessionInvalid));

  static AnalyseAjustement analyser(List<AjustementDetail> details) {
    var pos = 0.0, neg = 0.0;
    for (final d in details) {
      if (d.isPositive) {
        pos += d.valeurAjustement;
      } else {
        neg += d.valeurAjustement;
      }
    }
    return AnalyseAjustement(pos, neg);
  }
}
