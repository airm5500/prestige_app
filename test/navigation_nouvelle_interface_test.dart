// Navigation de la nouvelle interface (demande du pharmacien, lot 1) :
//  - le menu « Fournisseurs » (liste des fournisseurs) n'apparaît plus dans la nouvelle interface : accueil A, B,
//    C (questions, tous les menus), recherche de menu, personnalisation de l'accueil ; il reste dans l'ancienne ;
//  - Réglages : bouton engrenage en haut à droite de l'accueil (libellé « Réglages », 48 dp), dans A, B, C et sur
//    tablette ; la barre du bas devient Accueil · Analyses · Équipe (plus d'onglet Réglages).
// Client HTTP en mémoire (faux serveur Prestige), horloge simulée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/reglages_nouveaux.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/personalize_home_screen.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/application.dart';
import 'support/cas_affichage.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final serveur = FauxServeurPrestige();

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);

  setUp(() {
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..coupe = false;
    ApiService.client = serveur.clientMemoire();
  });

  /// Téléphone 411 dp de large ; [haut] : écran très haut pour que toutes les tuiles soient construites.
  void telephone(WidgetTester tester, {bool haut = false}) {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = Size(411 * 2.625, (haut ? 4000 : 891) * 2.625);
    addTearDown(tester.view.reset);
  }

  void tablette(WidgetTester tester) {
    tester.view.devicePixelRatio = 1.5;
    tester.view.physicalSize = const Size(1920, 1200);
    addTearDown(tester.view.reset);
  }

  Future<void> connecter(WidgetTester tester, Presentation p) async {
    preparerNouvelle(serveur, p: p);
    donneesAccueil(serveur);
    ApiService.client = serveur.clientMemoire();
    await connecterEnMemoire(tester);
  }

  Future<void> fermer(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  Future<void> pomper(WidgetTester tester, [int fois = 6]) async {
    for (var i = 0; i < fois; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Finder dansAccueil(String texte) => find.descendant(of: find.byType(AccueilNouveau), matching: find.text(texte));

  group('« Fournisseurs » retiré de la nouvelle interface', () {
    test('liste des menus : plus de « Fournisseurs », les autres menus fournisseurs restent', () {
      final titres = [for (final m in menusModules) m.titre];
      expect(titres, isNot(contains('Fournisseurs')));
      expect(titres, containsAll(['Achats Fourn.', 'Retours Fournisseurs', 'Visualisation BL', 'Etat Contrôle Achat', 'Analyse Saisies BL']));
      expect(menusModules, hasLength(33),
          reason: '27 menus d\'origine (sans Fournisseurs) + 3 nouveaux menus de la vague 1 + 3 de la vague 2 (le Pilotage est un onglet)');
    });

    testWidgets('accueil A (familles) : « Fournisseurs » absent, « Retours Fournisseurs » présent', (tester) async {
      telephone(tester, haut: true);
      await connecter(tester, Presentation.tableauDeBord);
      expect(dansAccueil('Retours Fournisseurs'), findsOneWidget);
      expect(dansAccueil('Achats Fourn.'), findsOneWidget);
      expect(dansAccueil('Fournisseurs'), findsNothing);
      await fermer(tester);
    });

    testWidgets('accueil B et recherche de menu : « Fournisseurs » introuvable', (tester) async {
      telephone(tester, haut: true);
      await connecter(tester, Presentation.compact);
      expect(dansAccueil('Retours Fournisseurs'), findsOneWidget);
      expect(dansAccueil('Fournisseurs'), findsNothing);
      await tester.enterText(find.byKey(const Key('recherche_menu')), 'fournisseur');
      await pomper(tester, 2);
      expect(dansAccueil('Retours Fournisseurs'), findsOneWidget);
      expect(dansAccueil('Achats Fourn.'), findsOneWidget);
      expect(dansAccueil('Fournisseurs'), findsNothing);
      // Sous-titre de l'ancien menu « Fournisseurs » : plus aucun résultat.
      await tester.enterText(find.byKey(const Key('recherche_menu')), 'coordonnées');
      await pomper(tester, 2);
      expect(find.text('Aucun menu ne correspond.'), findsOneWidget);
      await fermer(tester);
    });

    testWidgets('accueil C : question « Mes fournisseurs » et « Voir tous les menus » sans « Fournisseurs »', (tester) async {
      telephone(tester, haut: true);
      await connecter(tester, Presentation.guide);
      await tester.tap(dansAccueil('Mes fournisseurs'));
      await pomper(tester);
      expect(find.byType(QuestionScreen), findsOneWidget);
      expect(find.text('Retours Fournisseurs'), findsOneWidget);
      expect(find.text('Fournisseurs'), findsNothing);
      await tester.binding.handlePopRoute();
      await pomper(tester);
      await tester.tap(find.text('Voir tous les menus'));
      await pomper(tester);
      expect(find.byType(TousLesMenusScreen), findsOneWidget);
      expect(find.text('Retours Fournisseurs'), findsOneWidget);
      expect(find.text('Fournisseurs'), findsNothing);
      await fermer(tester);
    });

    testWidgets('personnalisation de l\'accueil (nouvelle interface) : « Fournisseurs » non proposé', (tester) async {
      telephone(tester, haut: true);
      await connecter(tester, Presentation.tableauDeBord);
      await toucherReglages(tester);
      await tester.tap(find.text('Personnaliser l\'accueil'));
      await pomper(tester);
      final titres = [for (final i in tester.widget<PersonalizeHomeScreen>(find.byType(PersonalizeHomeScreen)).allItems) i['title']];
      expect(titres, isNot(contains('Fournisseurs')));
      expect(titres, contains('Retours Fournisseurs'));
      expect(find.text('Fournisseurs'), findsNothing);
      await fermer(tester);
    });

    testWidgets('ancienne interface intacte : « Fournisseurs » dans l\'accueil et la personnalisation', (tester) async {
      telephone(tester);
      preparerTelephone(serveur); // interface d'origine
      ApiService.client = serveur.clientMemoire();
      await ecranConnecte(() => const HomeScreen())(tester, serveur);
      final titres = [];
      await tester.tap(find.byTooltip('Personnaliser l\'accueil'));
      await pomper(tester);
      titres.addAll([for (final i in tester.widget<PersonalizeHomeScreen>(find.byType(PersonalizeHomeScreen)).allItems) i['title']]);
      expect(titres, contains('Fournisseurs'));
      expect(titres, hasLength(28));
      await tester.binding.handlePopRoute();
      await pomper(tester);
      // Tuile « Fournisseurs » sur l'une des pages de l'accueil d'origine.
      for (var page = 0; find.text('Fournisseurs').evaluate().isEmpty && page < 6; page++) {
        await tester.drag(find.byType(PageView), const Offset(-300, 0));
        await pomper(tester, 4);
      }
      expect(find.text('Fournisseurs'), findsOneWidget);
      await fermer(tester);
    });
  });

  group('Réglages : bouton engrenage en haut à droite, barre du bas sans Réglages', () {
    test('onglets : Accueil · Analyses · Équipe, plus Pilotage pour l\'administrateur et le pharmacien (3.2.0)', () {
      expect([for (final o in ongletsAccueil(responsable: false)) o.libelle], ['Accueil', 'Analyses', 'Équipe']);
      expect([for (final o in ongletsAccueil(responsable: true)) o.libelle], ['Accueil', 'Analyses', 'Équipe', 'Pilotage']);
    });

    for (final (lettre, p) in presentationsTestees) {
      testWidgets('accueil $lettre : engrenage « Réglages » en haut à droite (48 dp), barre Accueil · Analyses · Équipe · Pilotage (compte pharmacien)',
          (tester) async {
        telephone(tester);
        await connecter(tester, p);
        final bouton = find.byKey(const Key('bouton_reglages'));
        expect(bouton, findsOneWidget);
        final zone = tester.getRect(bouton);
        final largeur = tester.view.physicalSize.width / tester.view.devicePixelRatio;
        expect(zone.width, greaterThanOrEqualTo(48));
        expect(zone.height, greaterThanOrEqualTo(48));
        expect(zone.right, greaterThan(largeur - 24), reason: 'à droite');
        expect(zone.top, lessThan(110), reason: 'en haut');
        expect(find.byTooltip('Réglages'), findsOneWidget);
        expect(find.descendant(of: bouton, matching: find.byIcon(Icons.settings_outlined)), findsOneWidget);
        final semantique = tester.ensureSemantics();
        expect(tester.getSemantics(bouton), containsSemantics(tooltip: 'Réglages', isButton: true, hasTapAction: true, isEnabled: true));
        semantique.dispose();

        final barre = tester.widget<NavigationBar>(find.byKey(const Key('barre_accueil')));
        // Compte fictif « dashboard » (administrateur / pharmacien) : onglet Pilotage en plus (3.2.0).
        expect([for (final d in barre.destinations) (d as NavigationDestination).label], ['Accueil', 'Analyses', 'Équipe', 'Pilotage']);
        expect(find.descendant(of: find.byKey(const Key('barre_accueil')), matching: find.text('Réglages')), findsNothing);

        await tester.tap(bouton);
        await pomper(tester);
        expect(find.byType(ReglagesScreen), findsOneWidget);
        expect(find.byKey(const Key('interrupteur_nouvelle_interface')), findsOneWidget);
        expect(find.byTooltip('Retour'), findsOneWidget);
        await tester.tap(find.byTooltip('Retour'));
        await pomper(tester);
        expect(find.byType(ReglagesScreen), findsNothing);
        expect(find.byType(AccueilNouveau), findsOneWidget);
        await fermer(tester);
      });
    }

    testWidgets('tablette (B, menu latéral) : engrenage en haut à droite et entrée « Réglages » du menu latéral', (tester) async {
      tablette(tester);
      await connecter(tester, Presentation.automatique);
      final zone = tester.getRect(find.byKey(const Key('bouton_reglages')));
      expect(zone.right, greaterThan(1280 - 24));
      expect(zone.top, lessThan(110));
      expect(find.byKey(const Key('barre_accueil')), findsNothing);
      await tester.tap(find.descendant(of: find.byType(AccueilNouveau), matching: find.text('Réglages')));
      await pomper(tester);
      expect(find.byType(ReglagesScreen), findsOneWidget);
      await fermer(tester);
    });
  });
}
