// Captures PNG RÉELLES de la 3.15.0 (rendu de l'application, données fictives), à la demande seulement :
//   CAPTURES_3_15=1 flutter test test/captures_3_15_0_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_3_15_0/*.png, téléphone 1080 × 2400 px (411 × 914 dp) et Sunmi
// 720 × 1440 px (360 × 720 dp) : carte « Affluence (jour × heure) » du tableau de bord, écran « Péremptions courtes ».
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague4/peremptions_courtes_vague4.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/donnees_lot2.dart';
import 'support/donnees_lot3.dart';
import 'support/donnees_vague1.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_3_15'] == '1';

Future<void> _chargerIcones() async {
  final dossier = dossierPolicesSdk();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('$dossier/MaterialIcons-Regular.otf').readAsBytesSync()))))
      .load();
}

/// Appareils : téléphone courant et Sunmi (petit écran).
const appareils = <(String, Size, double)>[
  ('telephone', Size(1080, 2400), 2.625),
  ('sunmi', Size(720, 1440), 2.0),
];

void main() {
  final serveur = FauxServeurPrestige();

  setUpAll(() async {
    if (!_actif) return;
    await chargerPolicesReelles();
    await _chargerIcones();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);

  Future<void> preparer(Presentation p) async {
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true;
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
    donneesLot2(serveur);
    donneesLot3(serveur);
    preparerNouvelle(serveur, p: p);
    ApiService.client = serveur.clientMemoire();
  }

  Future<void> pomper(WidgetTester tester, {int fois = 10}) async {
    for (var i = 0; i < fois; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final (nom, taille, dpr) in appareils) {
    testWidgets('captures 3.15.0 · $nom', (tester) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = taille;
      addTearDown(tester.view.reset);
      Future<void> photo(String n) async {
        await pomper(tester, fois: 6);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_3_15_0/${nom}_$n.png'));
      }

      Finder defilement() => find.descendant(of: find.byKey(const Key('defilement_tableau_bord')), matching: find.byType(Scrollable)).first;

      await preparer(Presentation.tableauPrestige);
      await connecterEnMemoire(tester);
      await pomper(tester, fois: 30);
      // Défile jusqu'à ce que le haut de la carte (choix de la semaine) soit en haut de l'écran.
      final semaine = find.byKey(const Key('affluence_semaine'));
      // (Carte pas encore disposée : position NaN.)
      double haut() => semaine.evaluate().isEmpty ? double.nan : tester.getTopLeft(semaine).dy;
      for (var i = 0; i < 60 && !(haut() <= 260); i++) {
        final position = tester.state<ScrollableState>(defilement()).position;
        position.jumpTo(position.pixels + (haut().isNaN ? 200 : haut() - 200));
        await pomper(tester, fois: 3);
      }
      await pomper(tester, fois: 20);
      await photo('01_affluence_semaine');
      await tester.tap(find.byKey(const Key('affluence_precedente')));
      await pomper(tester, fois: 20);
      await photo('02_affluence_semaine_precedente');

      Navigator.of(tester.element(find.byType(AccueilNouveau, skipOffstage: false)))
          .push(MaterialPageRoute(builder: (_) => const PeremptionsCourtesScreen()));
      await pomper(tester, fois: 20);
      await photo('03_peremptions_courtes');
      await tester.tap(find.byKey(const Key('pc_statut_ligne_0')));
      await pomper(tester);
      await photo('04_peremptions_courtes_statut');
      await tester.binding.handlePopRoute();
      await pomper(tester);
      await tester.tap(find.byKey(const Key('bouton_filtres')));
      await pomper(tester);
      await photo('05_peremptions_courtes_criteres');
    }, skip: !_actif);
  }
}
