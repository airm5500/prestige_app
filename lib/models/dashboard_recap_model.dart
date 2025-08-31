// lib/models/dashboard_recap_model.dart

import 'achat_recap_model.dart';
import 'reglement_type_recap_model.dart';

class DashboardRecap {
  final double montantTtc;
  final double montantHt;
  final double marge;
  final double montantCredit;
  final double montantRegle;
  final double montantTVA;
  final double ratio;
  final List<AchatRecap> achats;
  final List<ReglementTypeRecap> reglements;
  final List<dynamic> mvtsCaisse; // Gardé générique pour le moment

  DashboardRecap({
    required this.montantTtc,
    required this.montantHt,
    required this.marge,
    required this.montantCredit,
    required this.montantRegle,
    required this.montantTVA,
    required this.ratio,
    required this.achats,
    required this.reglements,
    required this.mvtsCaisse,
  });

  factory DashboardRecap.fromJson(Map<String, dynamic> json) {
    return DashboardRecap(
      montantTtc: (json['montantTTC'] as num?)?.toDouble() ?? 0.0,
      montantHt: (json['montantHT'] as num?)?.toDouble() ?? 0.0,
      marge: (json['marge'] as num?)?.toDouble() ?? 0.0,
      montantCredit: (json['montantCredit'] as num?)?.toDouble() ?? 0.0,
      montantRegle: (json['montantRegle'] as num?)?.toDouble() ?? 0.0,
      montantTVA: (json['montantTotalTVA'] as num?)?.toDouble() ?? 0.0,
      ratio: (json['ratio'] as num?)?.toDouble() ?? 0.0,
      achats: (json['achats'] as List<dynamic>?)
          ?.map((item) => AchatRecap.fromJson(item))
          .toList() ??
          [],
      reglements: (json['reglements'] as List<dynamic>?)
          ?.map((item) => ReglementTypeRecap.fromJson(item))
          .toList() ??
          [],
      mvtsCaisse: json['mvtsCaisse'] as List<dynamic>? ?? [],
    );
  }
}