// lib/models/suggestion_model.dart

import '../utils/date_formatter.dart';

class Suggestion {
  final String id;
  final String name;
  final String status;
  final String grossiste;
  final DateTime? dtCreated; // AJOUT

  Suggestion({
    required this.id,
    required this.name,
    required this.status,
    required this.grossiste,
    this.dtCreated, // AJOUT
  });

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(
      id: json['lg_SUGGESTION_ORDER_ID'] as String? ?? '',
      name: json['str_REF'] as String? ?? 'Suggestion sans nom',
      status: json['str_STATUT'] as String? ?? 'pending',
      grossiste: json['lg_GROSSISTE_ID'] as String? ?? 'N/A',
      dtCreated: DateFormatter.parseDDMMYYYY(json['dt_CREATED'] as String?), // AJOUT
    );
  }
}