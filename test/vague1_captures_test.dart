// Captures PNG RÉELLES des écrans de la vague 1 (rendu de l'application, données fictives), à la demande seulement :
//   CAPTURES_VAGUE1=1 flutter test test/vague1_captures_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_vague1/*.png, téléphone 1080 × 2400 px (411 × 914 dp), plus une
// capture tablette 1920 × 1200 px. Police Roboto du SDK Flutter (sous les noms Lato, voir support/polices.dart).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/alertes_accueil.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/alertes_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/journaux_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/valorisation_vague1.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/donnees_vague1.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_VAGUE1'] == '1';

Future<void> _chargerIcones() async {
  final dossier = dossierPolicesSdk();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('$dossier/MaterialIcons-Regular.otf').readAsBytesSync()))))
      .load();
}

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
    preparerNouvelle(serveur, p: p);
    ApiService.client = serveur.clientMemoire();
  }

  void appareil(WidgetTester tester, {bool tablette = false}) {
    tester.view.devicePixelRatio = tablette ? 1.5 : 2.625;
    tester.view.physicalSize = tablette ? const Size(1920, 1200) : const Size(1080, 2400);
    addTearDown(tester.view.reset);
  }

  Future<void> pomper(WidgetTester tester, {int fois = 10}) async {
    for (var i = 0; i < fois; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> photo(WidgetTester tester, String nom) async {
    await pomper(tester, fois: 6);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_vague1/$nom.png'));
  }

  Future<void> ouvrir(WidgetTester tester, Widget ecran) async {
    Navigator.of(tester.element(find.byType(AccueilNouveau))).push(MaterialPageRoute(builder: (_) => ecran));
    await pomper(tester, fois: 20);
  }

  Future<void> retour(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await pomper(tester);
  }

  Future<void> fin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('captures de la vague 1', (tester) async {
    debugDisableShadows = false;
    final jour = DateTime.now();
    AlertesAccueil.maintenant = () => DateTime(jour.year, jour.month, jour.day, 14, 32);

    await preparer(Presentation.tableauDeBord);
    appareil(tester);
    await connecterEnMemoire(tester);
    await pomperJusqua(tester, () => find.text('…').evaluate().isEmpty, raison: 'chiffres du jour chargés');

    // 1. Alertes : invitation (aucun appel), puis comptées.
    await ouvrir(tester, const AlertesScreen());
    await photo(tester, '1_alertes_invitation');
    await tester.tap(find.byKey(const Key('alertes_compter')));
    await pomper(tester, fois: 15);
    await photo(tester, '2_alertes_comptees');

    // 3. Liste d'une alerte (ruptures).
    await tester.tap(find.byKey(const Key('carte_alerte_ruptures')));
    await pomper(tester, fois: 15);
    await photo(tester, '3_alerte_liste_ruptures');
    await retour(tester);
    await retour(tester);

    // 4. Accueil A : « À surveiller » (péremption et ruptures du même appel, Toutes les alertes).
    await tester.ensureVisible(find.byKey(const Key('alerte_toutes')));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 150));
    await pomper(tester);
    await photo(tester, '4_accueil_A_a_surveiller');

    // 5-7. Valorisation : rayon (aujourd'hui), total, relevé indisponible.
    await ouvrir(tester, const ValorisationVague1());
    await photo(tester, '5_valorisation_rayon');
    await tester.tap(find.text('Total'));
    await pomper(tester);
    await photo(tester, '6_valorisation_total');
    await retour(tester);
    serveur.quand('/produit/valorisation', ReponseFausse.json(DonneesVague1.valorisationProduit(releve: false)));
    await ouvrir(tester, ValorisationVague1(dateInitiale: DateTime.now().subtract(const Duration(days: 40)), modeInitial: ModeValorisation.famille));
    await tester.tap(find.byKey(const Key('valorisation_calculer')));
    await pomper(tester, fois: 15);
    await photo(tester, '7_valorisation_releve_indisponible');
    await retour(tester);

    // 8. Retraits et abandons ; 9-10. Ventes modifiées et détail.
    await ouvrir(tester, const RetraitsAbandonsScreen());
    await photo(tester, '8_retraits_abandons');
    await retour(tester);
    await ouvrir(tester, const VentesModifieesScreen());
    await photo(tester, '9_ventes_modifiees');
    await tester.tap(find.byKey(const Key('vente_modifiee_MOD-TEST-1')));
    await pomper(tester, fois: 10);
    await photo(tester, '10_vente_modifiee_detail');
    await fin(tester);

    // 11. Tablette : retraits et abandons en tableau.
    await preparer(Presentation.automatique);
    appareil(tester, tablette: true);
    await connecterEnMemoire(tester);
    await ouvrir(tester, const RetraitsAbandonsScreen());
    await photo(tester, '11_tablette_retraits_tableau');
    await fin(tester);

    AlertesAccueil.maintenant = DateTime.now;
    debugDisableShadows = true;
  }, skip: !_actif);
}
