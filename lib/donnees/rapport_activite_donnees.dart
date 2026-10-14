// lib/donnees/rapport_activite_donnees.dart
// Données du Rapport d'Activité, COMMUNES aux deux interfaces (écran d'origine et nouvel écran) : mêmes routes,
// mêmes paramètres, même lecture des réponses. Quatre appels en parallèle sur la période [debut, fin] :
//   GET /recap/dashboard, /recap/credits, /recap/credits/totaux, /recap/reglements ?dtStart=&dtEnd=
// Tout échec est une ApiLoadException (réseau, délai, serveur, session…) propagée à l'écran.
import 'package:flutter/widgets.dart';

import '../models/credit_recap_model.dart';
import '../models/dashboard_recap_model.dart';
import '../models/reglement_recap_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class RapportActivite {
  final DashboardRecap? dashboard;
  final List<CreditRecap> credits;
  final CreditTotalsRecap? creditTotals;
  final List<ReglementRecap> reglements;
  const RapportActivite({this.dashboard, this.credits = const [], this.creditTotals, this.reglements = const []});

  /// Rien à afficher (même règle que l'écran d'origine).
  bool get vide => dashboard == null && credits.isEmpty && reglements.isEmpty;

  /// Paramètres envoyés pour la période.
  static Map<String, String> parametres(DateTime debut, DateTime fin) =>
      {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin)};

  /// Lecture des quatre réponses (même règle que l'écran d'origine : un format inattendu = section absente).
  static RapportActivite lire(List<dynamic> r) => RapportActivite(
        dashboard: r[0] is Map && r[0]['data'] is Map ? DashboardRecap.fromJson(r[0]['data']) : null,
        credits: r[1] is Map && r[1]['data'] is List ? (r[1]['data'] as List).map((i) => CreditRecap.fromJson(i)).toList() : const [],
        creditTotals: r[2] is Map ? CreditTotalsRecap.fromJson(r[2] as Map<String, dynamic>) : null,
        reglements:
            r[3] is Map && r[3]['data'] is List ? (r[3]['data'] as List).map((i) => ReglementRecap.fromJson(i)).toList() : const [],
      );

  static Future<RapportActivite> charger(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async {
    final api = ApiService();
    final p = parametres(debut, fin);
    final results = await Future.wait([
      api.get(context, AppConstants.dashboardRecapEndpoint, queryParams: p, onSessionInvalid: onSessionInvalid),
      api.get(context, AppConstants.creditsRecapEndpoint, queryParams: p, onSessionInvalid: onSessionInvalid),
      api.get(context, AppConstants.creditTotalsRecapEndpoint, queryParams: p, onSessionInvalid: onSessionInvalid),
      api.get(context, AppConstants.reglementsRecapEndpoint, queryParams: p, onSessionInvalid: onSessionInvalid),
    ]);
    return lire(results);
  }
}
