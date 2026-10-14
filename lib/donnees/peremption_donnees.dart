// lib/donnees/peremption_donnees.dart
// Suivi Péremption, logique COMMUNE aux deux interfaces : page demandée (ApiService.getSuiviPeremption, mêmes
// paramètres : query, nbreMois, page, start, limit), fusion des pages chargées au défilement, export PDF.
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/suivi_peremption_model.dart';
import '../services/api_service.dart';
import '../utils/saisie.dart';

class SuiviPeremption {
  SuiviPeremption._();

  /// Lignes demandées par page (mêmes paramètres que le comptage à la demande de l'accueil A).
  static const taillePage = 20;

  /// Nombre de mois valide (vide accepté : aucun filtre) ?
  static bool moisValide(String mois) => mois.trim().isEmpty || Saisie.entier(mois, min: 0, max: Saisie.maxMois) != null;

  static Future<SuiviPeremptionResponse?> page(BuildContext context, {required String recherche, required String mois, required int page}) =>
      ApiService().getSuiviPeremption(
        context,
        query: Saisie.recherche(recherche),
        nbreMois: mois.trim(),
        page: page,
        limit: taillePage,
      );

  /// Page suivante ajoutée aux lignes déjà chargées (métadonnées et total les plus récents).
  static SuiviPeremptionResponse? fusionner(SuiviPeremptionResponse? avant, SuiviPeremptionResponse? suite) {
    if (avant == null || suite == null) return suite;
    return SuiviPeremptionResponse(metaData: suite.metaData, data: [...avant.data, ...suite.data], total: suite.total);
  }

  /// Reste-t-il des lignes à charger ?
  static bool aSuite(SuiviPeremptionResponse? r) => r != null && r.data.length < r.total;

  /// PDF de la liste chargée (impression / partage du système).
  static Future<void> imprimerPdf(SuiviPeremptionResponse donnees) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final items = donnees.data;
    final meta = donnees.metaData;
    final dateImpression = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pw.Widget resume(String label, String value) => pw.Column(children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ]);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Suivi Péremption", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text("Imprimé le: $dateImpression", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                resume("Qté Totale", "${meta.totalQuantiteLot.toInt()}"),
                resume("Val. Achat", "${meta.totalValeurAchat.toInt()}"),
                resume("Val. Vente", "${meta.totalValeurVente.toInt()}"),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Code', 'Libellé', 'Lot', 'Date Pér.', 'Qté', 'Statut'],
            data: items
                .map((item) => [item.codeCip, item.libelle, item.numLot, item.datePerement, item.quantiteLot.toInt().toString(), item.statut])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellHeight: 25,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerLeft,
            },
            border: null,
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Suivi_Peremption_$dateImpression');
  }
}
