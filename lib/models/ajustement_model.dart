// lib/models/ajustement_model.dart

class Ajustement {
  final String heure;
  final String lgAJUSTEMENTID;
  final String userFullName;
  final String description;
  final String dtUPDATED;
  final String details; // Contient du HTML, sera parsé si nécessaire

  Ajustement({
    required this.heure,
    required this.lgAJUSTEMENTID,
    required this.userFullName,
    required this.description,
    required this.dtUPDATED,
    required this.details,
  });

  factory Ajustement.fromJson(Map<String, dynamic> json) {
    return Ajustement(
      heure: json['heure'] as String? ?? '',
      lgAJUSTEMENTID: json['lgAJUSTEMENTID'] as String? ?? '',
      userFullName: json['userFullName'] as String? ?? 'N/A',
      description: json['description'] as String? ?? '',
      dtUPDATED: json['dtUPDATED'] as String? ?? '',
      details: json['details'] as String? ?? '',
    );
  }
}
