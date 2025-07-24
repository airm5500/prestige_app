// lib/models/ajustement_detail_model.dart

class AjustementDetail {
  final String strNAME;
  final int intNUMBER; // Quantité ajustée. Peut être positive ou négative.
  final int intPAF; // Prix d'achat
  final String motifAjustement;
  final int intNUMBERCURRENTSTOCK; // Stock avant
  final int intNUMBERAFTERSTOCK; // Stock après

  AjustementDetail({
    required this.strNAME,
    required this.intNUMBER,
    required this.intPAF,
    required this.motifAjustement,
    required this.intNUMBERCURRENTSTOCK,
    required this.intNUMBERAFTERSTOCK,
  });

  factory AjustementDetail.fromJson(Map<String, dynamic> json) {
    return AjustementDetail(
      strNAME: json['strNAME'] as String? ?? 'N/A',
      intNUMBER: (json['intNUMBER'] as num?)?.toInt() ?? 0,
      intPAF: (json['intPAF'] as num?)?.toInt() ?? 0,
      motifAjustement: json['motifAjustement'] as String? ?? '',
      intNUMBERCURRENTSTOCK: (json['intNUMBERCURRENTSTOCK'] as num?)?.toInt() ?? 0,
      intNUMBERAFTERSTOCK: (json['intNUMBERAFTERSTOCK'] as num?)?.toInt() ?? 0,
    );
  }

  // Détermine si l'ajustement est positif ou négatif
  bool get isPositive => intNUMBER > 0;
  // Calcule la valeur de l'ajustement
  double get valeurAjustement => (intNUMBER * intPAF).toDouble();
}
