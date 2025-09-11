// lib/models/fichier_journal_model.dart

import '../utils/date_formatter.dart';

class FichierJournal {
  final DateTime? operationDate;
  final String typeLog;
  final String userFullName;
  final String heure;
  final String description;

  FichierJournal({
    this.operationDate,
    required this.typeLog,
    required this.userFullName,
    required this.heure,
    required this.description,
  });

  factory FichierJournal.fromJson(Map<String, dynamic> json) {
    return FichierJournal(
      operationDate: DateFormatter.parseIsoDateTime(json['operationDate'] as String?),
      typeLog: json['strTYPELOG'] as String? ?? 'N/A',
      userFullName: json['userFullName'] as String? ?? 'N/A',
      heure: json['HEURE'] as String? ?? '',
      description: json['strDESCRIPTION'] as String? ?? '',
    );
  }
}