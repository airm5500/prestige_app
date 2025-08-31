// lib/models/reglement_type_recap_model.dart

class ReglementTypeRecap {
  final String libelle;
  final double montant;

  ReglementTypeRecap({
    required this.libelle,
    required this.montant,
  });

  factory ReglementTypeRecap.fromJson(Map<String, dynamic> json) {
    return ReglementTypeRecap(
      libelle: json['libelle'] as String? ?? 'N/A',
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
    );
  }
}