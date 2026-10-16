// lib/donnees/analyse_bl_donnees.dart
// Analyse des Saisies BL, logique COMMUNE aux deux interfaces : GET /etat-control-bon/list?dtStart=&dtEnd=&limit=9999
// → « data » ; délai de saisie = jours entre la livraison et la saisie (BonLivraisonStat.delayInDays), statut
// « Bon » (≤ 1 jour), « Pas bon » (> 1 jour) ou « N/A » (date manquante) ; filtre local par statut (aucune
// nouvelle requête), comme l'écran d'origine.
// 3.11.0 (demande du pharmacien) : temps de saisie moyen par BL = moyenne, sur les BL CLÔTURÉS, de la durée entre
// la création du BL (dtCREATED) et sa clôture (dtUPDATED) — mêmes données, aucune requête de plus. Les durées de plus
// de 24 h (BL laissé ouvert) sont écartées du calcul et comptées à part.
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

  /// Temps de saisie moyen des BL clôturés (durées ≤ 24 h), le nombre de BL retenus et le nombre de BL écartés
  /// (ouverts plus de 24 h). Moyenne null si aucun BL n'est retenu.
  static ({Duration? moyenne, int retenus, int ecartes}) tempsSaisieMoyen(List<BonLivraisonStat> bl) {
    var total = Duration.zero;
    var retenus = 0, ecartes = 0;
    for (final b in bl) {
      final t = b.tempsSaisie;
      if (t == null) continue;
      if (t > BonLivraisonStat.dureeSaisieMax) {
        ecartes++;
      } else {
        total += t;
        retenus++;
      }
    }
    return (moyenne: retenus == 0 ? null : Duration(seconds: (total.inSeconds / retenus).round()), retenus: retenus, ecartes: ecartes);
  }

  /// « 12 min », « 1 h 05 », « < 1 min ».
  static String duree(Duration d) {
    if (d.inMinutes < 1) return '< 1 min';
    if (d.inHours < 1) return '${d.inMinutes} min';
    return '${d.inHours} h ${(d.inMinutes % 60).toString().padLeft(2, '0')}';
  }
}
