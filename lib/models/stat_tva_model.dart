// lib/models/stat_tva_model.dart

class StatTva {
  final double totalTva;
  final double totalTtc;
  final int taux;
  final double totalHt;
  final double montantUg;

  StatTva({
    required this.totalTva,
    required this.totalTtc,
    required this.taux,
    required this.totalHt,
    required this.montantUg,
  });

  factory StatTva.fromJson(Map<String, dynamic> json) {
    return StatTva(
      totalTva: (json['Total TVA'] as num?)?.toDouble() ?? 0.0,
      totalTtc: (json['Total TTC'] as num?)?.toDouble() ?? 0.0,
      taux: (json['TAUX'] as num?)?.toInt() ?? 0,
      totalHt: (json['Total HT'] as num?)?.toDouble() ?? 0.0,
      montantUg: (json['montantUg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}