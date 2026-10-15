// PERFORMANCE — GÉNÉRATION DES PDF (plafond de temps), faux serveur « en mémoire » :
//  - ticket Z (Récap de caisse) : 40 caissiers × 8 modes ; Stat TVA ; Marge Produits Vendus : 1 000 produits ;
//    CA Crédit : 1 000 ventes — chacun par le VRAI menu « Exporter » de l'écran (contenu construit par l'écran,
//    toutes les lignes), puis fabrication des octets du PDF A4 compressé (ce que reçoit le dialogue d'impression) ;
//  - Suivi Péremption : 1 000 lots (police intégrée, hors ligne : voir README, défaut corrigé en 3.9.1).
// Temps réel (Stopwatch) comparé à [Seuils.pdfMs] ; aucune requête pendant l'export.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_pdf.dart';
import 'package:prestige_app/donnees/peremption_donnees.dart';
import 'package:prestige_app/donnees/recap_caisse_pdf.dart';
import 'package:prestige_app/models/suivi_peremption_model.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/marge_produits_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/recap_caisse_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/stat_tva_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';

import '../support/donnees_lot3.dart';
import '../support/donnees_lot4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/grandes_donnees.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

bool estPdf(Uint8List o) => o.length > 1000 && String.fromCharCodes(o.sublist(0, 4)) == '%PDF';

/// Menu « Exporter » → [libelle] ; renvoie le temps de l'appui jusqu'au contenu remis à la sortie (capturée).
Future<double> exporter(WidgetTester tester, String libelle, bool Function() recu) async {
  await tester.tap(find.byKey(const Key('menu_exports')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  final sw = Stopwatch()..start();
  await tester.tap(find.text(libelle).last);
  await pomper(tester, recu, raison: 'PDF remis à l\'impression', pas: const Duration(milliseconds: 10));
  return sw.elapsedMicroseconds / 1000;
}

/// Fabrique les octets en temps réel (hors horloge simulée) et les chronomètre.
Future<(double, Uint8List)> fabriquer(WidgetTester tester, Future<Uint8List> Function() octets) async {
  Uint8List? o;
  Object? erreur;
  final sw = Stopwatch()..start();
  await tester.runAsync(() async {
    try {
      o = await octets();
    } catch (e, pile) {
      erreur = '$e\n$pile';
    }
  });
  final ms = sw.elapsedMicroseconds / 1000;
  expect(erreur, isNull, reason: 'fabrication du PDF en échec');
  return (ms, o!);
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    brancherEnMemoire(serveur);
    preparerNouvelle(serveur, p: Presentation.compact);
  });

  /// Sorties des PDF d'analyse capturées (aucun dialogue du système en test).
  List<ContenuAnalysePdf> capturerAnalyses() {
    final l = <ContenuAnalysePdf>[];
    final avant = AnalysesPdf.sortie;
    AnalysesPdf.sortie = (c, _) async => l.add(c);
    addTearDown(() => AnalysesPdf.sortie = avant);
    return l;
  }

  testWidgets('ticket Z (Récap de caisse) : 40 caissiers × 8 modes, Exporter → PDF', (tester) async {
    telephone(tester);
    donneesLot4(serveur);
    serveur.quand('/caisse/fetch-tickez', ReponseFausse.json(GrandesDonnees.ticketZ()), methode: 'POST');
    final sorties = <ContenuTicketZ>[];
    final avant = RecapCaissePdf.sortie;
    RecapCaissePdf.sortie = (c, _) async => sorties.add(c);
    addTearDown(() => RecapCaissePdf.sortie = avant);
    await ouvrirEcran(tester, serveur, const RecapCaisseNouveau(), pret: find.byType(LigneDetail));
    final requetes = serveur.requetes.length;
    final contenu = await exporter(tester, 'PDF du ticket Z', () => sorties.isNotEmpty);
    expect(serveur.requetes, hasLength(requetes), reason: 'export sans requête');
    expect(sorties.single.caissiers, hasLength(40));
    final (ms, o) = await fabriquer(tester, () => RecapCaissePdf.octets(sorties.single));
    expect(estPdf(o), isTrue);
    mesurer('PDF ticket Z, 40 caissiers × 8 modes — Exporter → PDF prêt', contenu + ms, seuil: Seuils.pdfMs, unite: 'ms',
        detail: '${(o.length / 1024).round()} Ko');
    await fermerApplication(tester);
  });

  testWidgets('Stat TVA : Exporter → PDF', (tester) async {
    telephone(tester);
    donneesLot3(serveur);
    final sorties = capturerAnalyses();
    await ouvrirEcran(tester, serveur, const StatTvaNouveau(), pret: find.byType(CarteLigne));
    final contenu = await exporter(tester, 'PDF des statistiques TVA', () => sorties.isNotEmpty);
    final (ms, o) = await fabriquer(tester, () => AnalysesPdf.octets(sorties.single));
    expect(estPdf(o), isTrue);
    mesurer('PDF Stat TVA — Exporter → PDF prêt', contenu + ms, seuil: Seuils.pdfMs, unite: 'ms', detail: '${(o.length / 1024).round()} Ko');
    await fermerApplication(tester);
  });

  testWidgets('Marge Produits Vendus : 1 000 produits, Exporter → PDF (toutes les lignes)', (tester) async {
    telephone(tester);
    donneesLot3(serveur);
    serveur.quand('/datareporting/margeproduitsvendus', ReponseFausse.json(GrandesDonnees.marges(1000)), methode: 'GET');
    final sorties = capturerAnalyses();
    await ouvrirEcran(tester, serveur, const MargeProduitsNouveau(), pret: find.byType(CarteLigne));
    final contenu = await exporter(tester, 'PDF des marges', () => sorties.isNotEmpty);
    expect(sorties.single.lignes, hasLength(1000), reason: 'toutes les lignes, pas seulement celles construites');
    final (ms, o) = await fabriquer(tester, () => AnalysesPdf.octets(sorties.single));
    expect(estPdf(o), isTrue);
    mesurer('PDF Marge, 1 000 produits — Exporter → PDF prêt', contenu + ms, seuil: Seuils.pdfMs, unite: 'ms', detail: '${(o.length / 1024).round()} Ko');
    await fermerApplication(tester);
  });

  testWidgets('CA Crédit : 1 000 ventes, Exporter → PDF (toutes les lignes)', (tester) async {
    telephone(tester);
    donneesLot3(serveur);
    serveur.quand('/ca-credit', ReponseFausse.json(GrandesDonnees.caCredit(1000)), methode: 'GET');
    final sorties = capturerAnalyses();
    await ouvrirEcran(tester, serveur, const CaCreditNouveau(), pret: find.byType(CarteLigne));
    final contenu = await exporter(tester, 'PDF des ventes à crédit', () => sorties.isNotEmpty);
    expect(sorties.single.lignes, hasLength(1000));
    final (ms, o) = await fabriquer(tester, () => AnalysesPdf.octets(sorties.single));
    expect(estPdf(o), isTrue);
    mesurer('PDF CA Crédit, 1 000 ventes — Exporter → PDF prêt', contenu + ms, seuil: Seuils.pdfMs, unite: 'ms', detail: '${(o.length / 1024).round()} Ko');
    await fermerApplication(tester);
  });

  testWidgets('Suivi Péremption : 1 000 lots, PDF hors ligne (police intégrée)', (tester) async {
    final donnees = SuiviPeremptionResponse.fromJson(GrandesDonnees.perimes(1000));
    final (ms, o) = await fabriquer(tester, () => SuiviPeremption.octets(donnees));
    expect(estPdf(o), isTrue);
    mesurer('PDF Suivi Péremption, 1 000 lots', ms, seuil: Seuils.pdfMs, unite: 'ms', detail: '${(o.length / 1024).round()} Ko');
  });
}
