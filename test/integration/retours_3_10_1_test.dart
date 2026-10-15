// Réponses du pharmacien sur la 3.10.0, appliquées en 3.10.1 (écrans contre le faux serveur en mémoire) :
//  - P4 « icônes illustrées » PAR DÉFAUT, disposition « tout sur une page » par défaut (comme p4_1_accueil_A.png) ;
//  - migration : un style jamais choisi passe en P4 ; un style choisi explicitement est gardé ; rien n'est écrit tant
//    que l'utilisateur ne choisit pas ;
//  - « Style des icônes » VISIBLE dans les Réglages, mêmes droits que « Menus de l'accueil » : compte « admin » et
//    profils administrateur / pharmacien le changent (choix mémorisé) ; autres comptes : verrouillé, explication,
//    aucun code, rien de changé ni d'écrit.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/icones_illustrees.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/reglages_nouveaux.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/cas_affichage.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

Finder cle(String k) => find.byKey(Key(k));

Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Compte connecté : « admin », pharmacien (profil « dashboard ») ou compte simple (caissier).
enum Compte { admin, pharmacien, simple }

Map<String, Object?> utilisateur(Compte c) => {
      ...DonneesFictives.utilisateur(),
      if (c == Compte.admin) 'str_LOGIN': 'admin',
      if (c == Compte.simple) 'xtypeuser': 'mainmenumanager',
    };

Future<void> monter(WidgetTester tester, Widget Function() ecran, {required Compte compte, StyleIcones? style = StyleIcones.actuel}) async {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 3000 * 2.625);
  addTearDown(tester.view.reset);
  preparerNouvelle(serveur, p: Presentation.tableauDeBord, style: style, prefs: {AppConstants.userDataKey: jsonEncode(utilisateur(compte))});
  ApiService.client = serveur.clientMemoire();
  ProfilAcces.utilisateur.value = AppUser.fromJson(utilisateur(compte));
  // Lecture des préférences comme au lancement (main → InterfaceVersion.load → ApparenceAccueilPrefs.charger).
  await ApparenceAccueilPrefs.charger();
  await ecranConnecte(ecran)(tester, serveur);
  await pomper(tester);
}

Future<void> demonter(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
  ProfilAcces.utilisateur.value = null;
}

Future<String?> styleMemorise(WidgetTester tester) async =>
    (await tester.runAsync(SharedPreferences.getInstance))!.getString(ApparenceAccueilPrefs.cleStyle);

Future<void> toucher(WidgetTester tester, String k) async {
  await tester.ensureVisible(cle(k));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(cle(k));
  await pomper(tester, 8);
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    serveur
      ..installerRoutesParDefaut()
      ..coupe = false;
    donneesAccueil(serveur);
  });

  group('défaut et migration', () {
    testWidgets('jamais choisi : P4 et « tout sur une page » (accueil A illustré) ; rien n\'est écrit', (tester) async {
      await monter(tester, () => const AccueilNouveau(), compte: Compte.pharmacien, style: null);
      expect(ApparenceAccueilPrefs.style.value, StyleIcones.p4);
      expect(ApparenceAccueilPrefs.affichage.value, AffichageMenus.unePage);
      expect(find.byType(IconeIllustree), findsWidgets);
      expect(cle('pages_menus'), findsNothing);
      expect(await styleMemorise(tester), isNull);
      await demonter(tester);
    });

    for (final s in [StyleIcones.actuel, StyleIcones.p1, StyleIcones.p2, StyleIcones.p3]) {
      testWidgets('style « ${s.name} » choisi explicitement : gardé (pas d\'icônes illustrées)', (tester) async {
        await monter(tester, () => const AccueilNouveau(), compte: Compte.pharmacien, style: s);
        expect(ApparenceAccueilPrefs.style.value, s);
        expect(find.byType(IconeIllustree), findsNothing);
        expect(await styleMemorise(tester), s.name);
        await demonter(tester);
      });
    }
  });

  group('réglage « Style des icônes » visible, droits de « Menus de l\'accueil »', () {
    for (final c in [Compte.admin, Compte.pharmacien]) {
      testWidgets('${c.name} : visible, P4 marqué « par défaut », choix appliqué et mémorisé, retour à P4 mémorisé aussi', (tester) async {
        await monter(tester, () => const ReglagesScreen(), compte: c, style: null);
        expect(cle('style_icones_verrouille'), findsNothing);
        expect(find.text('P4 · Icônes illustrées (par défaut)'), findsOneWidget);
        await toucher(tester, 'style_icones_p3');
        expect(ApparenceAccueilPrefs.style.value, StyleIcones.p3);
        expect(await styleMemorise(tester), 'p3');
        await toucher(tester, 'style_icones_p4');
        expect(ApparenceAccueilPrefs.style.value, StyleIcones.p4);
        expect(await styleMemorise(tester), 'p4', reason: 'choix explicite, même égal au défaut');
        expect(cle('pin_admin_saisie'), findsNothing);
        await demonter(tester);
      });
    }

    testWidgets('compte simple : visible, verrouillé avec explication, aucun code, rien changé ni écrit', (tester) async {
      await monter(tester, () => const ReglagesScreen(), compte: Compte.simple, style: null);
      expect(ProfilAcces.responsable, isFalse);
      expect(cle('style_icones_verrouille'), findsOneWidget);
      expect(cle('style_icones_p1'), findsOneWidget, reason: 'visible (plus caché)');
      await toucher(tester, 'style_icones_p1');
      expect(cle('pin_admin_saisie'), findsNothing);
      expect(cle('style_icones_refus'), findsOneWidget);
      expect(ApparenceAccueilPrefs.style.value, StyleIcones.p4);
      expect(await styleMemorise(tester), isNull);
      await demonter(tester);
    });
  });

  testWidgets('changerStyle refusé sans les droits (appel direct)', (tester) async {
    await monter(tester, () => const ReglagesScreen(), compte: Compte.simple, style: StyleIcones.actuel);
    final ctx = tester.element(find.byType(ReglagesScreen));
    expect(await ApparenceAccueilPrefs.changerStyle(ctx, StyleIcones.p2), isFalse);
    expect(ApparenceAccueilPrefs.style.value, StyleIcones.actuel);
    expect(await styleMemorise(tester), 'actuel');
    await demonter(tester);
  });
}
