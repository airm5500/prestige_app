// Réponses du pharmacien sur la vague 2 (3.2.1+30), contre le faux serveur Prestige (client « en mémoire ») :
//  - CA emplacement / famille : cases à cocher dans la feuille des filtres (« Tout » / « Aucun », compteur) ;
//    paramètres transmis comme le web : zoneId=Z1,Z3 ; tout coché ou rien coché = paramètre vide ;
//  - Analyse de garde : pages de 100 ; changer la largeur des tranches ne relit que la synthèse (limit=1) et garde
//    les produits déjà chargés (pages comprises) ; changer d'onglet ne relit rien.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/vague2/ca_zone_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/garde_vague2.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague2.dart';
import '../support/faux_serveur_prestige.dart';

final serveur = FauxServeurPrestige();

Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> monter(WidgetTester tester, Widget Function() ecran) async {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 2000 * 2.625);
  addTearDown(tester.view.reset);
  preparerTelephone(serveur, nouvelle: true);
  ApiService.client = serveur.clientMemoire();
  serveur.oublierRequetes();
  await ecranConnecte(ecran)(tester, serveur);
  await pomper(tester);
}

Future<void> demonter(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 3));
}

Future<void> toucher(WidgetTester tester, String cle) async {
  await tester.ensureVisible(find.byKey(Key(cle)));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.byKey(Key(cle)));
  await pomper(tester, 5);
}

Map<String, String> derniere(String route) => serveur.recues(route).last.parametres;

void main() {
  setUpAll(serveur.demarrer);
  tearDownAll(serveur.arreter);

  setUp(() {
    serveur
      ..installerRoutesParDefaut()
      ..coupe = false;
    listesCommunesVague1(serveur);
    // Trois emplacements (pour en cocher deux sur trois).
    serveur.quand(
        ApiVague2.routeRayons,
        ReponseFausse.json(DonneesVague1.combo([('ZONE-TEST-1', 'RAYON A'), ('ZONE-TEST-2', 'RAYON B'), ('ZONE-TEST-3', 'RAYON C')])),
        methode: 'GET');
  });
  tearDown(restaurerClient);

  group('CA emplacement / famille : choix multiple', () {
    testWidgets('2 emplacements sur 3 et 1 famille → zoneId=Z1,Z3, familleId=F2 ; compteur ; étiquettes', (tester) async {
      await monter(tester, () => const CaZoneScreen());
      expect(derniere(ApiCaZone.route)['zoneId'], '', reason: 'ouverture sans filtre');
      await toucher(tester, 'bouton_filtres');
      await toucher(tester, 'multi_emplacement');
      expect(tester.widget<Text>(find.byKey(const Key('multi_emplacement_resume'))).data, 'Aucun filtre (tous)');
      await toucher(tester, 'multi_emplacement_ZONE-TEST-1');
      await toucher(tester, 'multi_emplacement_ZONE-TEST-3');
      expect(tester.widget<Text>(find.byKey(const Key('multi_emplacement_resume'))).data, '2 sélectionnés');
      await toucher(tester, 'multi_famille');
      await toucher(tester, 'multi_famille_FAM-TEST-2');
      expect(tester.widget<Text>(find.byKey(const Key('multi_famille_resume'))).data, '1 sélectionné');
      final avant = serveur.recues(ApiCaZone.route).length;
      await toucher(tester, 'filtres_appliquer');
      await pomper(tester);
      expect(serveur.recues(ApiCaZone.route).length, avant + 1);
      final p = derniere(ApiCaZone.route);
      expect(p['zoneId'], 'ZONE-TEST-1,ZONE-TEST-3');
      expect(p['familleId'], 'FAM-TEST-2');
      expect(p['grossisteId'], '');
      expect(find.text('Emplacements : 2 sélectionnés'), findsOneWidget);
      expect(find.text('Famille : SIROPS IMAGINAIRES'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('« Tout » (tout coché) et « Aucun » : aucun filtre transmis', (tester) async {
      await monter(tester, () => const CaZoneScreen(filtresInitiaux: FiltresCa(grossistes: ['GRO-TEST-1'])));
      expect(derniere(ApiCaZone.route)['grossisteId'], 'GRO-TEST-1');
      await toucher(tester, 'bouton_filtres');
      await toucher(tester, 'multi_grossiste');
      expect(tester.widget<Text>(find.byKey(const Key('multi_grossiste_resume'))).data, '1 sélectionné');
      await toucher(tester, 'multi_grossiste_tout');
      expect(tester.widget<Text>(find.byKey(const Key('multi_grossiste_resume'))).data, 'Tous (2)');
      await toucher(tester, 'filtres_appliquer');
      await pomper(tester);
      expect(derniere(ApiCaZone.route)['grossisteId'], '', reason: 'tout coché = aucun filtre');

      await toucher(tester, 'bouton_filtres');
      await toucher(tester, 'multi_emplacement');
      await toucher(tester, 'multi_emplacement_ZONE-TEST-2');
      await toucher(tester, 'multi_emplacement_aucun');
      expect(tester.widget<Text>(find.byKey(const Key('multi_emplacement_resume'))).data, 'Aucun filtre (tous)');
      await toucher(tester, 'filtres_appliquer');
      await pomper(tester);
      expect(derniere(ApiCaZone.route)['zoneId'], '');
      await demonter(tester);
    });

    testWidgets('détail d\'une ligne : mêmes filtres multiples transmis', (tester) async {
      await monter(tester, () => const CaZoneScreen(filtresInitiaux: FiltresCa(zones: ['ZONE-TEST-1', 'ZONE-TEST-2'])));
      expect(derniere(ApiCaZone.route)['zoneId'], 'ZONE-TEST-1,ZONE-TEST-2');
      const l = LigneCa(zoneId: 'ZONE-TEST-1');
      expect(ApiCaZone.parametresDetail(const FiltresCa(zones: ['ZONE-TEST-1', 'ZONE-TEST-2']), l)['zoneId'], 'ZONE-TEST-1,ZONE-TEST-2');
      await demonter(tester);
    });
  });

  group('Analyse de garde : pages de 100, produits gardés', () {
    final garde = Garde.depuis(Map<String, dynamic>.from(DonneesVague2.garde('GARDE-TEST-1', 'Garde du 05/09', '2026-09-05 20:00', '2026-09-06 08:00')));
    const route = '/gardes/GARDE-TEST-1/rapport';

    /// Pied de la liste des produits (en bas d'une liste paresseuse : on y descend).
    Future<void> pied(WidgetTester tester, String texte) async {
      final produits = find.descendant(of: find.byKey(const Key('defilement_garde_produits')), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.textContaining('affichées sur'), 800, scrollable: produits, maxScrolls: 100);
      expect(find.text(texte), findsOneWidget);
    }

    Future<void> onglet(WidgetTester tester, String nom) async {
      await tester.tap(find.descendant(of: find.byType(TabBar), matching: find.text(nom)).first);
      await pomper(tester, 8);
    }

    testWidgets('100 par page ; tranches changées → limit=1, produits (2 pages) gardés ; onglets sans rechargement', (tester) async {
      await monter(tester, () => GardeDetailScreen(garde: garde));
      expect(serveur.recues(route).single.parametres, {'heures': '2', 'tri': 'montant', 'classe': '', 'start': '0', 'limit': '100'});

      await onglet(tester, 'Produits');
      final produits = find.descendant(of: find.byKey(const Key('defilement_garde_produits')), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.byKey(const Key('bouton_afficher_plus')), 500, scrollable: produits);
      await tester.tap(find.byKey(const Key('bouton_afficher_plus')));
      await pomper(tester);
      expect(derniere(route), containsPair('start', '100'));
      await pied(tester, '130 lignes affichées sur 130');
      final appels = serveur.recues(route).length;

      await onglet(tester, 'Synthèse');
      await onglet(tester, 'Produits');
      expect(serveur.recues(route).length, appels, reason: 'changer d\'onglet ne relit rien');
      await pied(tester, '130 lignes affichées sur 130');

      await onglet(tester, 'Synthèse');
      await toucher(tester, 'heures_4');
      await pomper(tester);
      expect(serveur.recues(route).length, appels + 1);
      expect(derniere(route), {'heures': '4', 'tri': 'montant', 'classe': '', 'start': '0', 'limit': '1'});
      expect(find.byKey(const Key('garde_tranches')), findsOneWidget);
      await onglet(tester, 'Produits');
      await pied(tester, '130 lignes affichées sur 130'); // produits déjà chargés gardés
      expect(serveur.recues(route).length, appels + 1);

      // Un tri change la liste : rechargement normal de la première page.
      await tester.drag(find.descendant(of: find.byKey(const Key('defilement_garde_produits')), matching: find.byType(Scrollable)).first, const Offset(0, 100000));
      await pomper(tester, 3);
      await toucher(tester, 'tri_quantite');
      await pomper(tester);
      expect(derniere(route), {'heures': '4', 'tri': 'quantite', 'classe': '', 'start': '0', 'limit': '100'});
      await demonter(tester);
    });

    testWidgets('échec de la synthèse seule : erreur sur la synthèse, produits intacts', (tester) async {
      await monter(tester, () => GardeDetailScreen(garde: garde));
      serveur.quand(route, ReponseFausse.erreurServeur());
      await toucher(tester, 'heures_3');
      await pomper(tester);
      expect(find.byKey(const Key('erreur_serveur')), findsOneWidget);
      await onglet(tester, 'Produits');
      await pied(tester, '100 lignes affichées sur 130');
      await demonter(tester);
    });
  });
}
