// lib/models/credit_recap_model.dart

class CreditRecap {
  final String typeTiersPayant;
  final String tiersPayant;
  final int nbreClients;
  final int nbreBons;
  final double montant;

  CreditRecap({
    required this.typeTiersPayant,
    required this.tiersPayant,
    required this.nbreClients,
    required this.nbreBons,
    required this.montant,
  });

  factory CreditRecap.fromJson(Map<String, dynamic> json) {
    return CreditRecap(
      typeTiersPayant: json['libelleTypeTiersPayant'] as String? ?? 'N/A',
      tiersPayant: json['libelleTiersPayant'] as String? ?? 'N/A',
      nbreClients: (json['nbreClient'] as num?)?.toInt() ?? 0,
      nbreBons: (json['nbreBons'] as num?)?.toInt() ?? 0,
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CreditTotalsRecap {
  final int totalClients;
  final int totalBons;
  final double totalMontant;

  CreditTotalsRecap({
    required this.totalClients,
    required this.totalBons,
    required this.totalMontant,
  });

  // CORRECTION: Le modèle est ajusté pour un objet simple, pas une liste
  factory CreditTotalsRecap.fromJson(Map<String, dynamic> json) {
    return CreditTotalsRecap(
      totalClients: (json['nbreClient'] as num?)?.toInt() ?? 0,
      totalBons: (json['nbreBons'] as num?)?.toInt() ?? 0,
      totalMontant: (json['montant'] as num?)?.toDouble() ?? 0.0,
    );
  }
}