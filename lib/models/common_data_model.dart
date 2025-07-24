// lib/models/common_data_model.dart

class CommonData {
  final String id;
  final String libelle;

  CommonData({required this.id, required this.libelle});

  factory CommonData.fromJson(Map<String, dynamic> json) {
    return CommonData(
      id: json['id'].toString(), // Convertir en String pour plus de sécurité
      libelle: json['libelle'] as String? ?? 'N/A',
    );
  }
}
