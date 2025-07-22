// lib/models/suivi_credit_model.dart

class SuiviCredit {
  final String libelleTypeTiersPayant;
  final int nbreBons;
  final int nbreClient;
  final String libelleTiersPayant;
  final double montant;

  SuiviCredit({
    required this.libelleTypeTiersPayant,
    required this.nbreBons,
    required this.nbreClient,
    required this.libelleTiersPayant,
    required this.montant,
  });

  factory SuiviCredit.fromJson(Map<String, dynamic> json) {
    return SuiviCredit(
      libelleTypeTiersPayant: json['libelleTypeTiersPayant'] as String? ?? 'N/A',
      nbreBons: (json['nbreBons'] as num?)?.toInt() ?? 0,
      nbreClient: (json['nbreClient'] as num?)?.toInt() ?? 0,
      libelleTiersPayant: json['libelleTiersPayant'] as String? ?? 'N/A',
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
