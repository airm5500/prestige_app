// lib/models/marge_produit_vendu_model.dart

class MargeProduitVendu {
  final String code;
  final String libelle;
  final double montantAchat;
  final double montantVente;
  final double montantMarge;
  final int margePourcentage;

  MargeProduitVendu({
    required this.code,
    required this.libelle,
    required this.montantAchat,
    required this.montantVente,
    required this.montantMarge,
    required this.margePourcentage,
  });

  factory MargeProduitVendu.fromJson(Map<String, dynamic> json) {
    return MargeProduitVendu(
      code: json['code'] as String? ?? '',
      libelle: json['libelle'] as String? ?? 'N/A',
      montantAchat: (json['montantCumulAchat'] as num?)?.toDouble() ?? 0.0,
      montantVente: (json['montantCumulTTC'] as num?)?.toDouble() ?? 0.0,
      montantMarge: (json['montantCumulMarge'] as num?)?.toDouble() ?? 0.0,
      margePourcentage: (json['pourcentageCumulMage'] as num?)?.toInt() ?? 0,
    );
  }
}