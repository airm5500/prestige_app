// lib/utils/date_formatter.dart

import 'package:flutter/foundation.dart'; // Importer pour debugPrint
import 'package:intl/intl.dart';

class DateFormatter {
  // Format pour affichage: JJ-MM-AAAA
  static String toDisplayFormat(DateTime date) {
    return DateFormat('dd-MM-yyyy', 'fr_FR').format(date);
  }

  // Format pour API: YYYY-MM-DD
  static String toApiFormat(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Parse la chaîne YYYYMMDD de l'API en DateTime
  static DateTime? parseApiDateString(String? dateString) {
    if (dateString == null || dateString.length != 8) {
      return null;
    }
    try {
      // Format YYYYMMDD
      final year = int.parse(dateString.substring(0, 4));
      final month = int.parse(dateString.substring(4, 6));
      final day = int.parse(dateString.substring(6, 8));
      return DateTime(year, month, day);
    } catch (e) {
      // CORRECTION: Remplacement de 'print' par 'debugPrint'
      debugPrint('Error parsing date string: $dateString. Error: $e');
      return null;
    }
  }

  // Formate DateTime en YYYYMMDD (si nécessaire)
  static String toApiYYYYMMDDFormat(DateTime date) {
    return DateFormat('yyyyMMdd').format(date);
  }

  // Récupère la date de début par défaut (aujourd'hui)
  static DateTime getDefaultStartDate() {
    return DateTime.now();
  }

  // Récupère la date de fin par défaut (aujourd'hui)
  static DateTime getDefaultEndDate() {
    return DateTime.now();
  }
}
