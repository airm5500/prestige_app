// lib/models/tableau_bord_achats_ventes_model.dart

import 'package:flutter/foundation.dart'; // Importer pour debugPrint
import 'package:intl/intl.dart';

class TableauBordAchatsVentes {
  final DateTime? dateMvt; // Converti depuis String "DD/MM/YYYY"
  final double montantAchat;
  final double montantVente;

  TableauBordAchatsVentes({
    this.dateMvt,
    required this.montantAchat,
    required this.montantVente,
  });

  static DateTime? _parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      // L'API retourne "DD/MM/YYYY"
      return DateFormat('dd/MM/yyyy', 'fr_FR').parseStrict(dateString);
    } catch (e) {
      // CORRECTION: Remplacement de 'print' par 'debugPrint'
      debugPrint('Erreur de parsing de dateMvt: $dateString - $e');
      return null;
    }
  }

  factory TableauBordAchatsVentes.fromJson(Map<String, dynamic> json) {
    return TableauBordAchatsVentes(
      dateMvt: _parseDate(json['dateMvt'] as String?),
      montantAchat: (json['montantAchat'] as num?)?.toDouble() ?? 0.0,
      montantVente: (json['montantVente'] as num?)?.toDouble() ?? 0.0,
    );
  }

  double get ratio {
    if (montantAchat == 0) return 0.0;
    return montantVente / montantAchat;
  }
}
