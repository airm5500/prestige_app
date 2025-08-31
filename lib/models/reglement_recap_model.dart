// lib/models/reglement_recap_model.dart

class ReglementRecap {
  final String type;
  final String description;
  final String reference;
  final double montant;

  ReglementRecap({
    required this.type,
    required this.description,
    required this.reference,
    required this.montant,
  });

  factory ReglementRecap.fromJson(Map<String, dynamic> json) {
    return ReglementRecap(
      type: json['type'] as String? ?? 'N/A',
      description: json['description'] as String? ?? 'N/A',
      reference: json['reference'] as String? ?? '',
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
    );
  }
}