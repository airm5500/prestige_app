// lib/models/ca_global_model.dart

import '../utils/date_formatter.dart';

// Ce modèle est très similaire à CaComptant, on pourrait envisager une classe de base
// ou un mixin si les champs étaient exactement les mêmes et nombreux.
// Pour l'instant, une classe séparée est claire.
class CaGlobal {
  final double montantCredit;
  final DateTime? mvtDate;
  final double remiseSurCA;
  final double totCB;
  final double totChq;
  final double totEsp;
  final double totMobile;
  final double totTVA;
  final double totVirement;

  CaGlobal({
    required this.montantCredit,
    this.mvtDate,
    required this.remiseSurCA,
    required this.totCB,
    required this.totChq,
    required this.totEsp,
    required this.totMobile,
    required this.totTVA,
    required this.totVirement,
  });

  factory CaGlobal.fromJson(Map<String, dynamic> json) {
    return CaGlobal(
      montantCredit: (json['montantCredit'] as num?)?.toDouble() ?? 0.0,
      mvtDate: DateFormatter.parseApiDateString(json['mvtDate'] as String?),
      remiseSurCA: (json['remiseSurCA'] as num?)?.toDouble() ?? 0.0,
      totCB: (json['totCB'] as num?)?.toDouble() ?? 0.0,
      totChq: (json['totChq'] as num?)?.toDouble() ?? 0.0,
      totEsp: (json['totEsp'] as num?)?.toDouble() ?? 0.0,
      totMobile: (json['totMobile'] as num?)?.toDouble() ?? 0.0,
      totTVA: (json['totTVA'] as num?)?.toDouble() ?? 0.0,
      totVirement: (json['totVirement'] as num?)?.toDouble() ?? 0.0,
    );
  }

  double get totalCa => totEsp + montantCredit + totMobile + totCB + totChq + totVirement;


  @override
  String toString() {
    return 'CaGlobal{mvtDate: ${mvtDate != null ? DateFormatter.toDisplayFormat(mvtDate!) : 'N/A'}, totalCa: $totalCa}';
  }
}
