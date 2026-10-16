// PERFORMANCE — retours de la 3.11.1 (téléphone 411 dp et Sunmi 360 dp), faux serveur Prestige « en mémoire » :
//  - tableau de bord : toujours 7 requêtes à l'ouverture (la veille de la fréquentation et des chiffres est dans la
//    même réponse : 0 requête de plus) ; chiffres d'hier : 1 requête (tuiles?date=) ; fréquentation par 2 h et plage
//    7 h – 22 h : 0 requête, pire image ;
//  - Balance : camembert (modes ↔ type de vente) : 0 requête, pire image ; barres de l'évolution par mode : pire image ;
//  - sélecteur de période (3.11.1) : menu du premier bouton puis « Ce mois » : une requête, comme avant.
// Seuils : test/support/performance.dart et test/README.md (« Seuils de performance »).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague4/balance_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/donnees_vague4.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart' show choisirAutrePeriode;
import '../support/donnees_lot2.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void appareil(WidgetTester tester, {double dpr = 2.625, Size dp = const Size(411, 891)}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(dp.width * dpr, dp.height * dpr);
  addTearDown(tester.view.reset);
}

Future<void> toucher(WidgetTester tester, ChronoImages chrono, Finder f, {int images = 12}) async {
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(f.first);
  for (var i = 0; i < images; i++) {
    await chrono.pump(tester, const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    brancherEnMemoire(serveur);
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
    donneesLot2(serveur);
    donneesLot3(serveur);
  });

  for (final (nom, dp) in const [('téléphone', Size(411, 891)), ('Sunmi', Size(360, 720))]) {
    testWidgets('tableau de bord ($nom) : chiffres d\'hier (1 requête), fréquentation 2 h / 7 h – 22 h (0 requête)', (tester) async {
      appareil(tester, dpr: nom == 'Sunmi' ? 2.0 : 2.625, dp: dp);
      preparerNouvelle(serveur, p: Presentation.tableauPrestige, style: null);
      brancherEnMemoire(serveur);
      donneesAccueil(serveur);
      donneesLot3(serveur);
      await ouvrirEcran(tester, serveur, const AccueilNouveau(), pret: find.byKey(const Key('chiffre_tb_ca')));
      final chrono = ChronoImages();
      final hier = await compter(serveur, () => toucher(tester, chrono, find.byKey(const Key('chiffres_hier'))));
      mesurer('Tableau de bord ($nom) — chiffres d\'hier : requêtes', hier.length, seuil: 1, unite: 'requêtes', detail: detailRequetes(hier));
      expect(hier.single.chemin, '/tableau-bord/tuiles');

      final liste = find.descendant(of: find.byKey(const Key('defilement_tableau_bord')), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.byKey(const Key('frequentation_largeur_2')), 300, scrollable: liste, maxScrolls: 40);
      await pomper(tester, () => find.byKey(const Key('frequentation_resume')).evaluate().isNotEmpty, raison: 'fréquentation');
      final affichage = await compter(serveur, () async {
        await toucher(tester, chrono, find.byKey(const Key('frequentation_largeur_2')));
        await toucher(tester, chrono, find.byKey(const Key('frequentation_plage')));
        await toucher(tester, chrono, find.byKey(const Key('frequentation_plage_septVingtDeux')).last);
        await toucher(tester, chrono, find.byKey(const Key('frequentation_largeur_1')));
      });
      mesurer('Tableau de bord ($nom) — fréquentation 1 h / 2 h / plage : requêtes', affichage.length, seuil: 0, unite: 'requêtes', detail: detailRequetes(affichage));
      mesurer('Tableau de bord ($nom) — pire image (jour, tranches, plage)', chrono.max, seuil: Seuils.imageDefilementMs, unite: 'ms', detail: chrono.resume);
      await fermerApplication(tester);
    });
  }

  testWidgets('Balance : camembert modes ↔ type de vente (0 requête), barres de l\'évolution par mode ; pire image', (tester) async {
    appareil(tester);
    await ouvrirEcran(tester, serveur, const BalanceCaisseScreen(), pret: find.byKey(const Key('chiffre_balance_net')));
    final liste = find.descendant(of: find.byKey(const Key('defilement_balance')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('repartition_modes_paiement')), 300, scrollable: liste, maxScrolls: 30);
    final chrono = ChronoImages();
    final camembert = await compter(serveur, () async {
      await toucher(tester, chrono, find.byKey(const Key('repartition_type')));
      await toucher(tester, chrono, find.byKey(const Key('repartition_modes')));
    });
    mesurer('Balance — camembert modes ↔ type de vente : requêtes', camembert.length, seuil: 0, unite: 'requêtes', detail: detailRequetes(camembert));
    final barres = await compter(serveur, () => toucher(tester, chrono, find.byKey(const Key('balance_onglet_modes')), images: 30));
    expect(barres.map((r) => r.chemin), [ApiBalance.routeAnalyse], reason: 'l\'analyse, une fois, comme en 3.11.0');
    mesurer('Balance — pire image (camembert, barres)', chrono.max, seuil: Seuils.imageGraphiqueMs, unite: 'ms', detail: chrono.resume);
    await fermerApplication(tester);
  });

  testWidgets('sélecteur de période : [Aujourd\'hui ▾] → Ce mois : une requête, comme avant', (tester) async {
    appareil(tester, dpr: 2.0, dp: const Size(360, 720));
    await ouvrirEcran(tester, serveur, const DetailCaNouveau(), pret: find.byKey(const Key('periode_autres')));
    await pomper(tester, () => serveur.recues(AppConstants.caComptantEndpoint).isNotEmpty, raison: 'ouverture');
    final rs = await compter(serveur, () async {
      await choisirAutrePeriode(tester, 'ceMois');
      await pomper(tester, () => serveur.recues(AppConstants.caComptantEndpoint).length >= 2, raison: 'Ce mois');
    });
    final ca = rs.where((r) => r.chemin == AppConstants.caComptantEndpoint).toList();
    mesurer('Sélecteur de période — Ce mois : requêtes du Détail CA', ca.length, seuil: 1, unite: 'requêtes', detail: detailRequetes(rs));
    expect(find.descendant(of: find.byKey(const Key('periode_autres')), matching: find.text('Ce mois')), findsOneWidget);
    await fermerApplication(tester);
  });
}
