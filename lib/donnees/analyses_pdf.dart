// lib/donnees/analyses_pdf.dart
// Exports PDF de trois analyses de la nouvelle interface (3.8.0, demande du pharmacien) : Stat TVA, Marge Produits
// Vendus et CA Crédit, dans le menu « Exporter » de chaque écran. Même style que le PDF du ticket Z
// (recap_caisse_pdf.dart) : A4, en-tête bleu nuit avec le nom de l'officine et le titre, période, filtres appliqués,
// date d'impression, chiffres clés en cartes, puis le détail en tableau avec sa ligne de total ; pied « Page x / y ».
// Les textes sont EXACTEMENT ceux de l'écran (montants déjà formatés par l'écran, mêmes lignes après filtres et
// recherche, TOUTES les lignes et pas seulement les 50 construites) : aucun recalcul, aucune requête.
// Le contenu est d'abord décrit en texte ([ContenuAnalysePdf.lignes], vérifiable par les tests), puis dessiné avec le
// paquet `pdf` ; impression / partage par le dialogue du système (`printing`). Police Helvetica intégrée (hors
// ligne) ; caractères hors Latin-1 remplacés ([pdfTexte]).
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'recap_caisse_pdf.dart' show pdfTexte;

export 'recap_caisse_pdf.dart' show pdfTexte;

/// Contenu d'un PDF d'analyse (textes de l'écran).
class ContenuAnalysePdf {
  final String officine;
  final String titre;
  final String periode;

  /// Filtres appliqués (libellé, valeur) ; vide : « Aucun filtre ».
  final List<(String, String)> filtres;
  final String imprimeLe;

  /// Chiffres clés de l'écran (libellé, valeur).
  final List<(String, String)> chiffres;
  final String titreDetail;
  final List<String> colonnes;

  /// Colonnes alignées à droite (montants).
  final Set<int> droite;
  final List<List<String>> lignes;
  final List<String>? total;

  const ContenuAnalysePdf({
    required this.officine,
    required this.titre,
    required this.periode,
    required this.filtres,
    required this.imprimeLe,
    required this.chiffres,
    required this.titreDetail,
    required this.colonnes,
    this.droite = const {},
    required this.lignes,
    this.total,
  });

  /// « 14/10/2026 à 09:05 ».
  static String horodatage(DateTime d) {
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(d.day)}/${d2(d.month)}/${d.year} à ${d2(d.hour)}:${d2(d.minute)}';
  }

  /// Texte du PDF, ligne par ligne, dans l'ordre du document (cellules séparées par « | »).
  List<String> get texte => [
        officine,
        titre,
        'Période : $periode',
        if (filtres.isEmpty) 'Filtres : aucun' else for (final (l, v) in filtres) '$l : $v',
        'Imprimé le $imprimeLe',
        for (final (l, v) in chiffres) '$l : $v',
        titreDetail,
        colonnes.join(' | '),
        for (final l in lignes) l.join(' | '),
        if (total != null) total!.join(' | '),
      ];
}

/// Nom de l'officine connectée (en-tête des PDF), comme le PDF du ticket Z.
String officineConnectee(BuildContext context) {
  try {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return auth.officine?.nomComplet ?? auth.user?.officineName ?? 'Officine';
  } catch (_) {
    return 'Officine';
  }
}

class AnalysesPdf {
  AnalysesPdf._();

  static const _navy = PdfColor.fromInt(0xFF14213D);
  static const _ambre = PdfColor.fromInt(0xFFF0A202);
  static const _gris = PdfColor.fromInt(0xFF5F6368);
  static const _fond = PdfColor.fromInt(0xFFEEF1F6);

  /// Fabrique le PDF de [contenu] et ouvre le dialogue d'impression / partage du système.
  static Future<void> imprimer(ContenuAnalysePdf contenu, String nom) async {
    final o = await octets(contenu);
    await Printing.layoutPdf(onLayout: (_) async => o, name: nom);
  }

  /// Sortie du PDF (remplaçable par les tests : aucun dialogue du système en test).
  static Future<void> Function(ContenuAnalysePdf contenu, String nom) sortie = imprimer;

  static String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Nom du document : « Stat_TVA_2026-10-14 » ou « Stat_TVA_2026-10-01_au_2026-10-14 ».
  static String nom(String prefixe, DateTime debut, DateTime fin) =>
      debut == fin ? '${prefixe}_${_date(debut)}' : '${prefixe}_${_date(debut)}_au_${_date(fin)}';

  /// Octets du PDF A4 ([compresser] = false : flux lisibles, pour les tests).
  static Future<Uint8List> octets(ContenuAnalysePdf c, {bool compresser = true}) {
    final doc = pw.Document(compress: compresser, title: pdfTexte('${c.titre} - ${c.officine}'), creator: 'Prestige Pharmacien');
    pw.Widget texte(String s, {double taille = 9.5, bool gras = false, PdfColor? couleur, pw.TextAlign? aligne}) => pw.Text(pdfTexte(s),
        textAlign: aligne, style: pw.TextStyle(fontSize: taille, fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal, color: couleur));

    pw.Widget cellule(String s, int i, {bool gras = false, PdfColor? couleur}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          child: pw.Align(
            alignment: c.droite.contains(i) ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
            child: texte(s, taille: 8.5, gras: gras, couleur: couleur, aligne: c.droite.contains(i) ? pw.TextAlign.right : pw.TextAlign.left),
          ),
        );

    pw.Widget section(String titre) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 4),
          padding: const pw.EdgeInsets.only(bottom: 2),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ambre, width: 1.5))),
          child: texte(titre, taille: 12.5, gras: true, couleur: _navy),
        );

    final entete = [
      ('Période', c.periode),
      if (c.filtres.isEmpty) ('Filtres', 'aucun') else for (final f in c.filtres) f,
      ('Imprimé le', c.imprimeLe),
    ];

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 32),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        texte('Prestige Pharmacien - ${c.titre} - imprimé le ${c.imprimeLe}', taille: 8, couleur: _gris),
        texte('Page ${ctx.pageNumber} / ${ctx.pagesCount}', taille: 8, couleur: _gris),
      ]),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          color: _navy,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            texte(c.officine, taille: 17, gras: true, couleur: PdfColors.white),
            pw.SizedBox(height: 3),
            texte(c.titre, taille: 12, couleur: _ambre),
          ]),
        ),
        pw.SizedBox(height: 8),
        pw.Table(columnWidths: const {0: pw.FixedColumnWidth(80), 1: pw.FlexColumnWidth()}, children: [
          for (final (l, v) in entete)
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: texte(l, taille: 10, couleur: _gris)),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: texte(v, taille: 10, gras: true)),
            ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (l, v) in c.chiffres)
            pw.Container(
              width: 122,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                texte(l, taille: 9, couleur: _gris),
                pw.SizedBox(height: 2),
                texte(v, taille: 12.5, gras: true, couleur: _navy),
              ]),
            ),
        ]),
        section(c.titreDetail),
        pw.Table(
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _navy),
              children: [for (var i = 0; i < c.colonnes.length; i++) cellule(c.colonnes[i], i, gras: true, couleur: PdfColors.white)],
            ),
            for (final l in c.lignes) pw.TableRow(children: [for (var i = 0; i < l.length; i++) cellule(l[i], i)]),
            if (c.total != null)
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _fond),
                children: [for (var i = 0; i < c.total!.length; i++) cellule(c.total![i], i, gras: true)],
              ),
          ],
        ),
        if (c.lignes.isEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 6), child: texte('Aucune ligne.', couleur: _gris)),
      ],
    ));
    return doc.save();
  }
}
