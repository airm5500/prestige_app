// lib/models/log_filtre_model.dart

class LogFiltre {
  final String description;
  final int order;

  LogFiltre({required this.description, required this.order});

  factory LogFiltre.fromJson(Map<String, dynamic> json) {
    return LogFiltre(
      description: json['strDESCRIPTION'] as String? ?? 'N/A',
      order: json['order'] as int? ?? -1,
    );
  }
}