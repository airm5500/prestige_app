// PERFORMANCE — DÉMARRAGE de l'application (même racine que main()) jusqu'à l'écran de connexion, puis CONNEXION
// jusqu'à l'accueil, contre le faux serveur Prestige « en mémoire » (licence lue, temps simulé) :
//  - lancement → écran de connexion, nouvelle interface puis ancienne : temps réel mesuré, images rendues, requêtes
//    (à froid pour la première : tous les widgets construits pour la première fois) ;
//  - connexion → accueil A (tableau de bord), B (compact), C (guidé) et menus « par pages » (3.9.0) : temps réel
//    jusqu'à l'accueil immobile, images rendues ; 3.10.0 : « 6 tuiles par page » et icônes illustrées (P4).
// Seuils : test/support/performance.dart (README « Seuils de performance »).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

/// Lance l'application et pompe image par image (16 ms simulées) jusqu'à l'écran de connexion immobile.
Future<({double ms, int images, int requetes})> demarrer(WidgetTester tester) async {
  final images0 = imagesRendues();
  final requetes0 = serveur.requetes.length;
  final sw = Stopwatch()..start();
  await lancerApplication(tester);
  var n = 0;
  final connexion = find.byType(LoginScreen);
  while ((connexion.evaluate().isEmpty || tester.binding.hasScheduledFrame) && n < 600) {
    await tester.pump(const Duration(milliseconds: 16));
    n++;
  }
  final ms = sw.elapsedMicroseconds / 1000;
  expect(connexion, findsOneWidget, reason: 'écran de connexion affiché');
  return (ms: ms, images: imagesRendues() - images0, requetes: serveur.requetes.length - requetes0);
}

/// Saisit les identifiants, touche « Se connecter » (ou « CONNEXION ») et pompe jusqu'à [accueil] immobile.
Future<({double ms, int images})> connecter(WidgetTester tester, Finder accueil) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
  final images0 = imagesRendues();
  final sw = Stopwatch()..start();
  final bouton = find.byKey(const Key('connexion_se_connecter'));
  await tester.tap(bouton.evaluate().isNotEmpty ? bouton : find.widgetWithText(ElevatedButton, 'Connexion'));
  var n = 0;
  while ((accueil.evaluate().isEmpty || n < 40) && n < 400) {
    await tester.pump(const Duration(milliseconds: 16));
    n++;
  }
  final ms = sw.elapsedMicroseconds / 1000;
  expect(accueil, findsOneWidget, reason: 'accueil affiché');
  return (ms: ms, images: imagesRendues() - images0);
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer(); // seulement pour connaître un port ; les requêtes passent « en mémoire »
  });
  tearDownAll(serveur.arreter);
  setUp(() => brancherEnMemoire(serveur));

  testWidgets('nouvelle interface : lancement → écran de connexion (temps à froid, images, requêtes)', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.tableauDeBord);
    donneesAccueil(serveur);
    final r = await demarrer(tester);
    mesurer('Démarrage → connexion (nouvelle interface, à froid)', r.ms, seuil: Seuils.demarrageMs, unite: 'ms');
    mesurer('Démarrage → connexion (nouvelle interface) — images rendues', r.images, seuil: Seuils.demarrageImages, unite: 'images');
    mesurer('Démarrage → connexion (nouvelle interface) — requêtes', r.requetes, seuil: Seuils.demarrageRequetes, unite: 'requêtes',
        detail: detailRequetes(serveur.requetes));
    await fermerApplication(tester);
  });

  testWidgets('ancienne interface : lancement → écran de connexion d\'origine (temps, images, requêtes)', (tester) async {
    telephone(tester);
    preparerTelephone(serveur);
    final r = await demarrer(tester);
    mesurer('Démarrage → connexion (ancienne interface)', r.ms, seuil: Seuils.demarrageMs, unite: 'ms');
    mesurer('Démarrage → connexion (ancienne interface) — images rendues', r.images, seuil: Seuils.demarrageImages, unite: 'images');
    mesurer('Démarrage → connexion (ancienne interface) — requêtes', r.requetes, seuil: Seuils.demarrageRequetes, unite: 'requêtes',
        detail: detailRequetes(serveur.requetes));
    final c = await connecter(tester, find.byType(HomeScreen));
    mesurer('Connexion → accueil d\'origine', c.ms, seuil: Seuils.accueilMs, unite: 'ms', detail: '${c.images} images');
    await fermerApplication(tester);
  });

  // Préchauffage (non mesuré, 3.12.1) : la PREMIÈRE construction de la nouvelle interface dans ce processus de test
  // paie la compilation à la volée (JIT) de tous ses widgets — 450 à 630 ms selon la charge de la machine, contre 150 à
  // 330 ms ensuite — ce qui faisait varier le premier cas mesuré autour du seuil. Sur le téléphone (code compilé
  // d'avance, AOT), ce coût n'existe pas. Les mesures ci-dessous portent donc toutes sur une interface déjà compilée.
  testWidgets('préchauffage de la nouvelle interface (non mesuré)', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.tableauDeBord, affichage: AffichageMenus.unePage, style: StyleIcones.actuel);
    donneesAccueil(serveur);
    await demarrer(tester);
    await connecter(tester, find.byType(AccueilNouveau));
    await fermerApplication(tester);
  });

  for (final (String nom, Presentation p, AffichageMenus affichage, StyleIcones? style) in [
    ('A · Tableau de bord', Presentation.tableauDeBord, AffichageMenus.unePage, StyleIcones.actuel),
    ('B · Compact', Presentation.compact, AffichageMenus.unePage, StyleIcones.actuel),
    ('C · Guidé', Presentation.guide, AffichageMenus.unePage, StyleIcones.actuel),
    ('A · menus par pages', Presentation.tableauDeBord, AffichageMenus.parRubrique, StyleIcones.actuel),
    ('B · menus par pages', Presentation.compact, AffichageMenus.parRubrique, StyleIcones.actuel),
    // 3.10.0 : 6 tuiles par page, icônes illustrées (P4).
    ('A · 6 tuiles par page', Presentation.tableauDeBord, AffichageMenus.parSix, StyleIcones.actuel),
    ('B · 6 tuiles par page', Presentation.compact, AffichageMenus.parSix, StyleIcones.actuel),
    ('A · icônes illustrées (P4)', Presentation.tableauDeBord, AffichageMenus.unePage, StyleIcones.p4),
    ('B · icônes illustrées (P4)', Presentation.compact, AffichageMenus.unePage, StyleIcones.p4),
    // 3.10.1 : défaut (style jamais choisi → P4, tout sur une page).
    ('A · défaut 3.10.1 (P4 jamais choisi)', Presentation.tableauDeBord, AffichageMenus.unePage, null),
    // 3.11.0 : le tableau de bord, accueil par défaut.
    ('Tableau de bord (défaut 3.11.0)', Presentation.tableauPrestige, AffichageMenus.unePage, null),
  ]) {
    testWidgets('connexion → accueil $nom (temps, images)', (tester) async {
      telephone(tester);
      preparerNouvelle(serveur, p: p, affichage: affichage, style: style);
      donneesAccueil(serveur);
      await demarrer(tester);
      final c = await connecter(tester, find.byType(AccueilNouveau));
      mesurer('Connexion → accueil $nom', c.ms, seuil: Seuils.accueilMs, unite: 'ms', detail: '${c.images} images');
      await fermerApplication(tester);
    });
  }
}
