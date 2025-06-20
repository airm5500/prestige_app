// lib/models/officine_model.dart

class Officine {
  final String id;
  final String fullName;
  final String nomComplet;

  Officine({
    required this.id,
    required this.fullName,
    required this.nomComplet,
  });

  // Factory constructor pour créer une instance de Officine à partir d'un JSON
  factory Officine.fromJson(Map<String, dynamic> json) {
    return Officine(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'Utilisateur', // Valeur par défaut
      nomComplet: json['nomComplet'] as String? ?? 'Pharmacie', // Valeur par défaut
    );
  }
}
