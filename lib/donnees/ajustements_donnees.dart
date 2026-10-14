// lib/donnees/ajustements_donnees.dart
// Suivi des Ajustements, logique COMMUNE aux deux interfaces :
//  - motifs : GET /common/type-ajustements → « data » ;
//  - ajustements : GET /ajustement?dtStart=&dtEnd=&typeFiltre=&page=1&start=0&limit=100 → « data » ;
//  - produits d'un ajustement : GET /ajustement/items?ajustementId=&page=1&start=0&limit=100 → « data » ;
//  - analyse : valeur ajoutée (quantités positives × prix d'achat), valeur retirée (négatives) et leurs parts
//    dans le total absolu (même calcul que l'écran d'origine).
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
