// lib/models/achat_recap_model.dart

class AchatRecap {
  final double montantHT;
  final String libelleGroupeGrossiste;
  final double montantTTC;
  final double montantTVA;

  AchatRecap({
    required this.montantHT,
    required this.libelleGroupeGrossiste,
    required this.montantTTC,
    required this.montantTVA,
  });

  factory AchatRecap.fromJson(Map<String, dynamic> json) {
    return AchatRecap(
      montantHT: (json['montantHT'] as num?)?.toDouble() ?? 0.0,
      libelleGroupeGrossiste: json['libelleGroupeGrossiste'] as String? ?? 'N/A',
      montantTTC: (json['montantTTC'] as num?)?.toDouble() ?? 0.0,
      montantTVA: (json['montantTVA'] as num?)?.toDouble() ?? 0.0,
    );
  }
}