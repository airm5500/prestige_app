// lib/models/ca_comptant_model.dart

import '../utils/date_formatter.dart';

class CaComptant {
  final double montantCredit; // Même si c'est CA comptant, l'API le retourne
  final DateTime? mvtDate;
  final double remiseSurCA;
  final double totCB; // Carte Bancaire
  final double totChq; // Chèque
  final double totEsp; // Espèces
  final double totMobile; // Mobile Money
  final double totTVA;
  final double totVirement; // Virement

  CaComptant({
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

  factory CaComptant.fromJson(Map<String, dynamic> json) {
    return CaComptant(
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

  // Pour le total et le camembert
  double get totalPaiements => totEsp + montantCredit + totMobile + totCB + totChq + totVirement;

  @override
  String toString() {
    return 'CaComptant{mvtDate: ${mvtDate != null ? DateFormatter.toDisplayFormat(mvtDate!) : 'N/A'}, totEsp: $totEsp, totalPaiements: $totalPaiements}';
  }
}
