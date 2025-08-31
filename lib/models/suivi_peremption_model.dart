// lib/models/suivi_peremption_model.dart

import '../utils/date_formatter.dart';

class SuiviPeremption {
  final String cip;
  final String libelle;
  final DateTime? datePeremption;
  final int prixVente;
  final int stockActuel;
  final String grossiste;
  final String emplacement;
  final String statut;

  SuiviPeremption({
    required this.cip,
    required this.libelle,
    this.datePeremption,
    required this.prixVente,
    required this.stockActuel,
    required this.grossiste,
    required this.emplacement,
    required this.statut,
  });

  factory SuiviPeremption.fromJson(Map<String, dynamic> json) {
    return SuiviPeremption(
      cip: json['intCIP'] as String? ?? '',
      libelle: json['strNAME'] as String? ?? 'N/A',
      datePeremption: DateFormatter.parseDDMMYYYY(json['dtCREATED'] as String?),
      prixVente: (json['intPRICE'] as num?)?.toInt() ?? 0,
      stockActuel: (json['intQUANTITY'] as num?)?.toInt() ?? 0,
      grossiste: json['typeVente'] as String? ?? 'N/A',
      emplacement: json['operateur'] as String? ?? 'N/A',
      statut: json['strSTATUT'] as String? ?? '',
    );
  }
}