// lib/donnees/recap_caisse_pdf.dart
// Export PDF du Récap de caisse (ticket Z) de la nouvelle interface (3.6.1, demande du pharmacien) : A4 lisible,
// en-tête de l'officine, période, caissier et heures filtrés, chiffres en tête (ceux de l'écran), totaux globaux
// puis un bloc par caissier (modes, puis totaux en gras ; négatifs en rouge et avec leur signe). Les montants sont
// EXACTEMENT les textes de l'écran (RecapCaisse.montant sur le montant formaté par le serveur) : aucun recalcul.
// Le contenu est d'abord décrit en texte ([ContenuTicketZ], vérifiable par les tests), puis dessiné avec le paquet
// `pdf` ; impression / partage par le dialogue du système (`printing`), comme les autres exports PDF de l'appli.
// Police : Helvetica intégrée au PDF (aucun téléchargement, fonctionne hors ligne) ; les rares caractères hors
// Latin-1 sont remplacés ([pdfTexte]).
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/ticket_z_model.dart';
import 'recap_caisse_donnees.dart';

/// Une ligne « libellé : montant » telle qu'affichée à l'écran.
class LigneTicketZ {
  final String libelle;
  final String montant;
  final bool gras;
  final bool negatif;
  const LigneTicketZ(this.libelle, this.montant, {this.gras = false, this.negatif = false});

  /// Même rendu que l'écran : montant « … F », gras pour les totaux et « TOTAL (VNO/VO) », rouge si négatif.
  factory LigneTicketZ.de(TicketZAmount a, {bool gras = false}) => LigneTicketZ(a.modeLibelle, RecapCaisse.montant(a.montant),
      gras: gras || RecapCaisse.estTotalVnoVo(a.modeLibelle), negatif: RecapCaisse.estNegatif(a.montant));

  String get texte => '$libelle : $montant';
}

class BlocCaissierTicketZ {
  final String nom;
  final List<LigneTicketZ> modes;
  final List<LigneTicketZ> totaux;
  const BlocCaissierTicketZ(this.nom, this.modes, this.totaux);
}

/// Contenu du PDF (textes de l'écran).
class ContenuTicketZ {
  final String officine;
  final String periode;
  final String caissier;
  final String heures;
  final String imprimeLe;
  final List<(String, String)> chiffres;
  final List<LigneTicketZ> totauxGlobaux;
  final List<BlocCaissierTicketZ> caissiers;
  const ContenuTicketZ({
    required this.officine,
    required this.periode,
    required this.caissier,
    required this.heures,
    required this.imprimeLe,
    required this.chiffres,
    required this.totauxGlobaux,
    required this.caissiers,
  });

  /// Contenu à partir du récapitulatif affiché ([chiffres] : les chiffres clés de l'écran, libellé et valeur).
  factory ContenuTicketZ.depuis(
    TicketZResponse r, {
    required String officine,
    required String periode,
    required String caissier,
    required String heures,
    required DateTime imprimeLe,
    required List<(String, String)> chiffres,
  }) {
    String d2(int n) => n.toString().padLeft(2, '0');
    return ContenuTicketZ(
      officine: officine,
      periode: periode,
      caissier: caissier,
      heures: heures,
      imprimeLe: '${d2(imprimeLe.day)}/${d2(imprimeLe.month)}/${imprimeLe.year} à ${d2(imprimeLe.hour)}:${d2(imprimeLe.minute)}',
      chiffres: chiffres,
      totauxGlobaux: [for (final t in r.totauxGlobaux) LigneTicketZ.de(t)],
      caissiers: [
        for (final u in r.datas)
          BlocCaissierTicketZ(u.user, [for (final a in u.modePaymentAmounts) LigneTicketZ.de(a)], [for (final a in u.totaux) LigneTicketZ.de(a, gras: true)]),
      ],
    );
  }

  /// Texte du PDF, ligne par ligne, dans l'ordre du document.
  List<String> get lignes => [
        officine,
        'Récapitulatif de caisse (ticket Z)',
        'Période : $periode',
        'Caissier : $caissier',
        'Heures : $heures',
        'Imprimé le $imprimeLe',
        for (final (l, v) in chiffres) '$l : $v',
        if (totauxGlobaux.isNotEmpty) 'Totaux globaux',
        for (final t in totauxGlobaux) t.texte,
        for (final c in caissiers) ...[
          c.nom,
          for (final m in c.modes) m.texte,
          for (final t in c.totaux) t.texte,
          if (c.modes.isEmpty && c.totaux.isEmpty) 'Aucun encaissement.',
        ],
      ];
}

/// Nombre maximal de pages d'un PDF de l'application (3.9.1). Le paquet `pdf` s'arrête par défaut à 20 pages
/// (TooManyPagesException) : une Marge ou un CA Crédit de plus de ~800 lignes n'était alors PAS produit. 500 pages
/// A4 ≈ 20 000 lignes.
const pagesMaxPdf = 500;

/// Texte compatible avec la police Helvetica intégrée (Latin-1) : espaces fines et insécables → espace, apostrophe
/// typographique → ', tirets longs → -, « … » → ..., flèche → -, tout autre caractère hors Latin-1 → ?.
String pdfTexte(String s) {
  const remplacements = {
    0x202F: ' ', 0x2009: ' ', 0x2007: ' ', 0x00A0: ' ', 0x2019: "'", 0x2018: "'", 0x201C: '"', 0x201D: '"', //
    0x2013: '-', 0x2014: '-', 0x2212: '-', 0x2026: '...', 0x2192: '-', 0x20AC: 'EUR',
  };
  final b = StringBuffer();
  for (final r in s.runes) {
    final rem = remplacements[r];
    if (rem != null) {
      b.write(rem);
    } else {
      b.writeCharCode(r < 0x100 ? r : 0x3F);
    }
  }
  return b.toString();
}

class RecapCaissePdf {
  RecapCaissePdf._();

  static const _navy = PdfColor.fromInt(0xFF14213D);
  static const _ambre = PdfColor.fromInt(0xFFF0A202);
  static const _rouge = PdfColor.fromInt(0xFFB3261E);
  static const _gris = PdfColor.fromInt(0xFF5F6368);

  /// Fabrique le PDF de [contenu] et ouvre le dialogue d'impression / partage du système.
  static Future<void> imprimer(ContenuTicketZ contenu, String nom) async {
    final o = await octets(contenu);
    await Printing.layoutPdf(onLayout: (_) async => o, name: nom);
  }

  /// Sortie du PDF (remplaçable par les tests : aucun dialogue du système en test).
  static Future<void> Function(ContenuTicketZ contenu, String nom) sortie = imprimer;

  /// Nom du document : « Ticket_Z_2026-10-14 » (ou « …_2026-10-01_au_2026-10-14 »).
  static String nom(DateTime debut, DateTime fin) =>
      debut == fin ? 'Ticket_Z_${RecapCaisse.date(debut)}' : 'Ticket_Z_${RecapCaisse.date(debut)}_au_${RecapCaisse.date(fin)}';

  /// Octets du PDF A4 ([compresser] = false : flux lisibles, pour les tests).
  static Future<Uint8List> octets(ContenuTicketZ c, {bool compresser = true}) {
    final doc = pw.Document(compress: compresser, title: pdfTexte('Récapitulatif de caisse - ${c.officine}'), creator: 'Prestige Pharmacien');
    pw.Widget texte(String s, {double taille = 10, bool gras = false, PdfColor? couleur}) => pw.Text(pdfTexte(s),
        style: pw.TextStyle(fontSize: taille, fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal, color: couleur));

    pw.Widget tableau(List<LigneTicketZ> lignes) => pw.Table(
          columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(2)},
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          children: [
            for (final l in lignes)
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6), child: texte(l.libelle, gras: l.gras, couleur: l.negatif ? _rouge : null)),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  child: pw.Align(alignment: pw.Alignment.centerRight, child: texte(l.montant, gras: l.gras, couleur: l.negatif ? _rouge : null)),
                ),
              ]),
          ],
        );

    pw.Widget section(String titre) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 14, bottom: 4),
          padding: const pw.EdgeInsets.only(bottom: 2),
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _ambre, width: 1.5))),
          child: texte(titre, taille: 12.5, gras: true, couleur: _navy),
        );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      maxPages: pagesMaxPdf,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        texte('Prestige Pharmacien - imprimé le ${c.imprimeLe}', taille: 8, couleur: _gris),
        texte('Page ${ctx.pageNumber} / ${ctx.pagesCount}', taille: 8, couleur: _gris),
      ]),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          color: _navy,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            texte(c.officine, taille: 17, gras: true, couleur: PdfColors.white),
            pw.SizedBox(height: 3),
            texte('Récapitulatif de caisse (ticket Z)', taille: 12, couleur: _ambre),
          ]),
        ),
        pw.SizedBox(height: 8),
        pw.Table(columnWidths: const {0: pw.FixedColumnWidth(70), 1: pw.FlexColumnWidth()}, children: [
          for (final (l, v) in [('Période', c.periode), ('Caissier', c.caissier), ('Heures', c.heures), ('Imprimé le', c.imprimeLe)])
            pw.TableRow(children: [
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: texte(l, couleur: _gris)),
              pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: texte(v, gras: true)),
            ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (l, v) in c.chiffres)
            pw.Container(
              width: 120,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                texte(l, taille: 9, couleur: _gris),
                pw.SizedBox(height: 2),
                texte(v, taille: 13, gras: true, couleur: _navy),
              ]),
            ),
        ]),
        if (c.totauxGlobaux.isNotEmpty) ...[section('Totaux globaux (tous les caissiers)'), tableau(c.totauxGlobaux)],
        if (c.caissiers.isNotEmpty) section('Par caissier'),
        for (final u in c.caissiers)
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              texte(u.nom, taille: 11, gras: true, couleur: _navy),
              pw.SizedBox(height: 4),
              if (u.modes.isNotEmpty) tableau(u.modes),
              if (u.totaux.isNotEmpty) ...[pw.Divider(color: PdfColors.grey500, height: 8), tableau(u.totaux)],
              if (u.modes.isEmpty && u.totaux.isEmpty) texte('Aucun encaissement.', couleur: _gris),
            ]),
          ),
      ],
    ));
    return doc.save();
  }
}
