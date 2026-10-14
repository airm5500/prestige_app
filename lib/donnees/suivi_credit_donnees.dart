// lib/donnees/suivi_credit_donnees.dart
// Données du Suivi des Crédits, COMMUNES aux deux interfaces : GET /recap/credits?dtStart=&dtEnd= → « data » ;
// filtre local par tiers payant (aucune nouvelle requête), même règle que l'écran d'origine.
import 'package:flutter/widgets.dart';

import '../models/suivi_credit_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class SuiviCredits {
  SuiviCredits._();

  static Map<String, String> parametres(DateTime debut, DateTime fin) =>
      {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin)};

  /// Lignes de la réponse ({data: [...]} attendu ; tout autre format = null, rien n'est remplacé).
  static List<SuiviCredit>? lire(dynamic data) =>
      data is Map<String, dynamic> && data['data'] is List ? (data['data'] as List).map((i) => SuiviCredit.fromJson(i)).toList() : null;

  static Future<List<SuiviCredit>?> charger(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async =>
      lire(await ApiService().get(context, AppConstants.suiviCreditEndpoint,
          queryParams: parametres(debut, fin), onSessionInvalid: onSessionInvalid));

  /// Lignes dont le tiers payant contient [texte] (sans tenir compte de la casse).
  static List<SuiviCredit> filtrer(List<SuiviCredit> lignes, String texte) {
    final q = texte.toLowerCase();
    return lignes.where((l) => l.libelleTiersPayant.toLowerCase().contains(q)).toList();
  }
}
