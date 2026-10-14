// lib/donnees/analyse_bl_donnees.dart
// Analyse des Saisies BL, logique COMMUNE aux deux interfaces : GET /etat-control-bon/list?dtStart=&dtEnd=&limit=9999
// → « data » ; délai de saisie = jours entre la livraison et la saisie (BonLivraisonStat.delayInDays), statut
// « Bon » (≤ 1 jour), « Pas bon » (> 1 jour) ou « N/A » (date manquante) ; filtre local par statut (aucune
// nouvelle requête), comme l'écran d'origine.
import 'package:flutter/widgets.dart';

import '../models/bon_livraison_stat_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

/// Statuts du filtre (« Tous » = aucun filtre).
const statutsSaisieBl = ['Tous', 'Bon', 'Pas bon'];

class AnalyseSaisiesBl {
  AnalyseSaisiesBl._();

  static Map<String, String> parametres(DateTime debut, DateTime fin) =>
      {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin), 'limit': '9999'};

  static List<BonLivraisonStat>? lire(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => BonLivraisonStat.fromJson(i)).toList() : null;

  static Future<List<BonLivraisonStat>?> charger(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async =>
      lire(await ApiService().get(context, AppConstants.analyseSaisieBlEndpoint, queryParams: parametres(debut, fin), onSessionInvalid: onSessionInvalid));

  /// BL du statut choisi (« Tous » : tous).
  static List<BonLivraisonStat> filtrer(List<BonLivraisonStat> bl, String statut) =>
      statut == 'Tous' ? List.of(bl) : bl.where((b) => b.status == statut).toList();

  /// Délai moyen de saisie (jours) des BL dont le délai est connu, ou null.
  static double? delaiMoyen(List<BonLivraisonStat> bl) {
    final d = [for (final b in bl) if (b.delayInDays != null) b.delayInDays!];
    return d.isEmpty ? null : d.reduce((a, b) => a + b) / d.length;
  }
}
