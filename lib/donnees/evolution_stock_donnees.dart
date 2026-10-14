// lib/donnees/evolution_stock_donnees.dart
// Évolution du stock, logique COMMUNE aux deux interfaces : GET /valorisation/all?dtStart=&dtEnd= → une
// valorisation par jour (liste), datée dans l'ordre à partir de la date de début (même calcul que l'écran
// d'origine). PDF « Évolution de la Valeur d'Achat du Stock » : image du graphique + période.
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/evolution_stock_point_model.dart';
import '../models/valorisation_model.dart';
import '../services/api_service.dart';
import '../services/journal_app.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

/// Chiffres de la période (valeur d'achat).
class ResumeEvolution {
  final double debut;
  final double fin;
  final double maximum;
  final double minimum;
  final DateTime dateMax;
  final DateTime dateMin;
  const ResumeEvolution(this.debut, this.fin, this.maximum, this.minimum, this.dateMax, this.dateMin);

  double get variation => fin - debut;

  /// Variation en % de la valeur de début (null si elle est nulle).
  double? get variationPourcent => debut == 0 ? null : variation / debut * 100;
}

class EvolutionStock {
  EvolutionStock._();

  static Map<String, String> parametres(DateTime debut, DateTime fin) =>
      {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin)};

  /// Points de la réponse (liste attendue ; sinon null) : le i-ème point est daté [debut] + i jours.
  static List<EvolutionStockPoint>? lire(dynamic data, DateTime debut, DateTime fin) {
    if (data is! List) return null;
    if (data.length != fin.difference(debut).inDays + 1) {
      JournalApp.debug('Evolution stock : nombre de points différent de la période');
    }
    final points = [
      for (var i = 0; i < data.length; i++) EvolutionStockPoint(date: debut.add(Duration(days: i)), data: ValorisationStock.fromJson(data[i])),
    ];
    points.sort((a, b) => a.date.compareTo(b.date));
    return points;
  }

  static Future<List<EvolutionStockPoint>?> charger(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async =>
      lire(await ApiService().get(context, AppConstants.valorisationAllEndpoint, queryParams: parametres(debut, fin), onSessionInvalid: onSessionInvalid),
          debut, fin);

  /// Valeur de début, de fin, plus haute et plus basse (null si aucun point).
  static ResumeEvolution? resume(List<EvolutionStockPoint> points) {
    if (points.isEmpty) return null;
    var max = points.first, min = points.first;
    for (final p in points) {
      if (p.data.valeurAchat > max.data.valeurAchat) max = p;
      if (p.data.valeurAchat < min.data.valeurAchat) min = p;
    }
    return ResumeEvolution(points.first.data.valeurAchat, points.last.data.valeurAchat, max.data.valeurAchat, min.data.valeurAchat, max.date, min.date);
  }

  /// PDF du graphique ([png] : image du graphique) pour la période, ouvert dans l'impression / le partage du système.
  static Future<void> imprimerPdf(Uint8List png, DateTime debut, DateTime fin) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Évolution de la Valeur d\'Achat du Stock', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('Période du ${DateFormatter.toDisplayFormat(debut)} au ${DateFormatter.toDisplayFormat(fin)}'),
          pw.SizedBox(height: 20),
          pw.Image(pw.MemoryImage(png)),
          pw.SizedBox(height: 20),
          pw.Text('Généré par Prestige App', style: pw.TextStyle(font: pw.Font.helveticaOblique())),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
