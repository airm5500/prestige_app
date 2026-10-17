// Captures PNG RÉELLES de l'application rendue comme sur iPhone et iPad (plateforme iOS, 3.12.0), à la demande :
//   CAPTURES_3_11=1 flutter test test/captures_3_12_0_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_3_12_0/<appareil>_<écran>.png. Rendu Flutter (police Roboto du SDK) :
// sur l'appareil, iOS affiche sa propre police système et sa barre d'état., téléphone 1080 × 2400 px (411 × 914 dp) et Sunmi
// 720 × 1440 px (360 × 720 dp). Police Roboto du SDK Flutter (sous les noms Lato, voir support/polices.dart).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/donnees_lot2.dart';
import 'support/donnees_lot3.dart';
import 'support/donnees_vague1.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_3_11'] == '1';

Future<void> _chargerIcones() async {
  final dossier = dossierPolicesSdk();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('$dossier/MaterialIcons-Regular.otf').readAsBytesSync()))))
      .load();
}

/// Appareils : iPhone SE, iPhone 15 Pro Max, iPad (portrait).
const appareils = <(String, Size, double)>[
  ('iphone_se', Size(750, 1334), 2.0),
  ('iphone_pro_max', Size(1290, 2796), 3.0),
  ('ipad', Size(1536, 2048), 2.0),
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

  Future<void> pomper(WidgetTester tester, {int fois = 10}) async {
    for (var i = 0; i < fois; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final (nom, taille, dpr) in appareils) {
    testWidgets('captures 3.12.0 · $nom', (tester) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = taille;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        serveur
          ..installerRoutesParDefaut()
          ..controlerSession = true;
        donneesAccueil(serveur);
        listesCommunesVague1(serveur);
        donneesLot2(serveur);
        donneesLot3(serveur);
        preparerNouvelle(serveur, p: Presentation.tableauPrestige);
        ApiService.client = serveur.clientMemoire();
        await connecterEnMemoire(tester);
        await pomper(tester, fois: 30);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_3_12_0/${nom}_tableau_de_bord.png'));
        await toucherReglages(tester);
        await pomper(tester, fois: 10);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_3_12_0/${nom}_reglages.png'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }, skip: !_actif);
  }
}
