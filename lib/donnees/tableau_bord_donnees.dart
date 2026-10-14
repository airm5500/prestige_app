// lib/donnees/tableau_bord_donnees.dart
// Tableau de bord achats / ventes, logique COMMUNE aux deux interfaces (Tableau : Analyses, Tableau : Ratios et
// Ratios mensuels) : GET /ws/ca-achats-ventes?dtStart=&dtEnd= → une ligne par jour (dateMvt « JJ/MM/AAAA »,
// montantAchat, montantVente). Mêmes calculs que les écrans d'origine :
//  - Analyses : lignes triées par date (dates absentes à la fin) ;
//  - Ratios : lignes dans l'ordre du serveur, ratio du jour = ventes / achats (0 sans achat), norme 1,51
//    (AppConstants.ratioNormeVenteAchat), achat normé = vente / norme, vente normée = achat × norme ;
//  - Ratios mensuels : année en cours (1er janvier → aujourd'hui), cumul par mois, ratio = ventes / achats.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../models/tableau_bord_achats_ventes_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

/// Cumul d'un mois (Ratios mensuels).
class MonthlyRatioData {
  final int month;
  double totalAchats;
  double totalVentes;

  MonthlyRatioData({required this.month, this.totalAchats = 0.0, this.totalVentes = 0.0});

  double get ratio => totalAchats == 0 ? 0.0 : totalVentes / totalAchats;
  String get monthName => DateFormat.MMMM('fr_FR').format(DateTime(0, month));
}

/// Position d'un ratio par rapport à la norme (même règle de couleur que l'origine : 0 = gris, ≥ norme = vert,
/// sinon rouge).
enum PositionNorme { sansAchat, conforme, sousLaNorme }

class TableauBord {
  TableauBord._();

  /// Norme du ratio ventes / achats (1,51).
  static const norme = AppConstants.ratioNormeVenteAchat;

  static Map<String, String> parametres(DateTime debut, DateTime fin) =>
      {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin)};

  /// Lignes de la réponse dans l'ordre du serveur (liste attendue ; sinon null).
  static List<TableauBordAchatsVentes>? lire(dynamic data) =>
      data is List ? data.map((item) => TableauBordAchatsVentes.fromJson(item)).toList() : null;

  /// Lignes triées par date, dates absentes à la fin (Tableau : Analyses).
  static List<TableauBordAchatsVentes> trier(List<TableauBordAchatsVentes> lignes) {
    final l = [...lignes];
    l.sort((a, b) {
      if (a.dateMvt == null && b.dateMvt == null) return 0;
      if (a.dateMvt == null) return 1;
      if (b.dateMvt == null) return -1;
      return a.dateMvt!.compareTo(b.dateMvt!);
    });
    return l;
  }

  static Future<List<TableauBordAchatsVentes>?> charger(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async =>
      lire(await ApiService().get(context, AppConstants.tableauBordAchatsVentesEndpoint,
          queryParams: parametres(debut, fin), onSessionInvalid: onSessionInvalid));

  /// Période des Ratios mensuels : du 1er janvier de l'année de [maintenant] à [maintenant].
  static (DateTime, DateTime) anneeEnCours(DateTime maintenant) => (DateTime(maintenant.year, 1, 1), maintenant);

  /// Cumul par mois (lignes datées seulement), mois croissants.
  static List<MonthlyRatioData> mensuels(List<TableauBordAchatsVentes> lignes) {
    final Map<int, MonthlyRatioData> parMois = {};
    for (final item in lignes) {
      if (item.dateMvt == null) continue;
      final month = item.dateMvt!.month;
      parMois.putIfAbsent(month, () => MonthlyRatioData(month: month));
      parMois[month]!.totalAchats += item.montantAchat;
      parMois[month]!.totalVentes += item.montantVente;
    }
    return parMois.values.toList()..sort((a, b) => a.month.compareTo(b.month));
  }

  /// Ratio ventes / achats (0 sans achat), même règle que le ratio d'un jour ou d'un mois.
  static double ratio(double achats, double ventes) => achats == 0 ? 0.0 : ventes / achats;

  static PositionNorme position(double ratio) =>
      ratio == 0 ? PositionNorme.sansAchat : (ratio >= norme ? PositionNorme.conforme : PositionNorme.sousLaNorme);

  /// Achat normé pour une vente (null si la vente n'est pas un montant positif).
  static double? achatNorme(double? vente) => vente != null && vente > 0 ? vente / norme : null;

  /// Vente normée pour un achat (null si l'achat n'est pas un montant positif).
  static double? venteNormee(double? achat) => achat != null && achat > 0 ? achat * norme : null;

  /// Totaux de la période.
  static double totalAchats(List<TableauBordAchatsVentes> l) => l.fold(0.0, (s, e) => s + e.montantAchat);
  static double totalVentes(List<TableauBordAchatsVentes> l) => l.fold(0.0, (s, e) => s + e.montantVente);
}
