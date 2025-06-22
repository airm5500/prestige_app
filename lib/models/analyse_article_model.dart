// lib/models/analyse_article_model.dart

import 'package:fl_chart/fl_chart.dart';

class AnalyseArticle {
  final String codeCip;
  final String? emplacement;
  final String? grossiste;
  final String libelle;
  final double moyenne;
  final double prixAchat;
  final double prixVente;
  final String? produitId;
  final String? quantiteMois;
  final int quantiteVendue;
  final int? stock; // AJOUT: Champ pour le stock

  AnalyseArticle({
    required this.codeCip,
    this.emplacement,
    this.grossiste,
    required this.libelle,
    required this.moyenne,
    required this.prixAchat,
    required this.prixVente,
    this.produitId,
    this.quantiteMois,
    required this.quantiteVendue,
    this.stock, // AJOUT: au constructeur
  });

  factory AnalyseArticle.fromJson(Map<String, dynamic> json) {
    return AnalyseArticle(
      codeCip: json['codeCip'] as String? ?? '',
      emplacement: json['emplacement'] as String?,
      grossiste: json['grossiste'] as String?,
      libelle: json['libelle'] as String? ?? 'N/A',
      moyenne: (json['moyenne'] as num?)?.toDouble() ?? 0.0,
      prixAchat: (json['prixAchat'] as num?)?.toDouble() ?? 0.0,
      prixVente: (json['prixVente'] as num?)?.toDouble() ?? 0.0,
      produitId: json['produitId'] as String?,
      quantiteMois: json['quantiteMois'] as String?,
      quantiteVendue: (json['quantiteVendue'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt(), // AJOUT: Parsing du stock (peut être null)
    );
  }

  // Helper pour parser la chaîne quantiteMois
  List<String> get ventesMensuelles {
    if (quantiteMois == null || quantiteMois!.isEmpty) return [];

    const Map<int, String> moisMap = {
      1: 'Janvier', 2: 'Février', 3: 'Mars', 4: 'Avril', 5: 'Mai', 6: 'Juin',
      7: 'Juillet', 8: 'Août', 9: 'Septembre', 10: 'Octobre', 11: 'Novembre', 12: 'Décembre',
    };

    List<String> result = [];
    final pairs = quantiteMois!.split(',');

    for (var pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final quantite = parts[0].trim();
        final moisNum = int.tryParse(parts[1].trim());
        if (moisNum != null && moisMap.containsKey(moisNum)) {
          result.add('${moisMap[moisNum]}: $quantite');
        }
      }
    }
    return result;
  }

  List<FlSpot> getVentesChartData() {
    if (quantiteMois == null || quantiteMois!.isEmpty) {
      return [];
    }

    List<FlSpot> spots = [];
    final currentMonth = DateTime.now().month;
    final pairs = quantiteMois!.split(',');

    for (var pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        final quantite = double.tryParse(parts[0].trim());
        final moisNum = double.tryParse(parts[1].trim());

        if (quantite != null && moisNum != null && moisNum <= currentMonth) {
          spots.add(FlSpot(moisNum, quantite));
        }
      }
    }
    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }
}
