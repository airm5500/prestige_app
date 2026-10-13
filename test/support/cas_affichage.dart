// Écrans rendus par les tests d'ergonomie et de cohérence du thème (test/ergonomie/) : parcours de démarrage
// (Configuration, serveur injoignable, licence, connexion), accueil, chaque module de l'accueil et quelques états
// supplémentaires (listes remplies, autres onglets). Données : faux serveur Prestige « en mémoire ».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/licence_registration_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/serveur_injoignable_screen.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'application.dart';
import 'catalogue_ecrans.dart';
import 'faux_serveur_prestige.dart';

/// Un écran à rendre : [ouvrir] monte l'application et l'amène dans l'état voulu.
class CasAffichage {
  final String nom;
  final Future<void> Function(WidgetTester tester, FauxServeurPrestige serveur) ouvrir;
  const CasAffichage(this.nom, this.ouvrir);
}

/// Démarrage normal de l'application jusqu'à l'écran [cible] (Configuration, licence, connexion…).
Future<void> Function(WidgetTester, FauxServeurPrestige) parcoursDemarrage(Type cible,
        {void Function(FauxServeurPrestige)? preparer, bool configure = true}) =>
    (tester, serveur) async {
      preparer?.call(serveur);
      if (!configure) SharedPreferences.setMockInitialValues({});
      await lancerApplication(tester);
      for (var i = 0; i < 20 && find.byType(cible).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(cible), findsOneWidget, reason: 'écran $cible non atteint');
      await tester.pump(const Duration(milliseconds: 500));
    };

/// Écran connecté rendu seul (avec le thème et les providers de l'application) ; [recherche] saisie ensuite.
Future<void> Function(WidgetTester, FauxServeurPrestige) ecranConnecte(Widget Function() ecran, {String? recherche}) =>
    (tester, serveur) async {
      serveur.controlerSession = false;
      await lancerApplication(tester, accueil: ecran());
      await tester.pump(const Duration(seconds: 3)); // providers prêts, premiers chargements
      await tester.pump(const Duration(milliseconds: 500));
      if (recherche != null) {
        await tester.enterText(find.byType(TextField).first, recherche);
        await tester.pump(const Duration(milliseconds: 600)); // anti-rebond de la recherche
        await tester.pump(const Duration(milliseconds: 500));
      }
      await tester.pump(const Duration(milliseconds: 500));
    };

final casAffichage = <CasAffichage>[
  CasAffichage('Configuration IP (premier lancement)', parcoursDemarrage(SettingsScreen, configure: false)),
  CasAffichage('Serveur injoignable', parcoursDemarrage(ServeurInjoignableScreen, preparer: (s) => s.coupe = true)),
  CasAffichage('Licence requise',
      parcoursDemarrage(LicenceRegistrationScreen, preparer: (s) => s.quand('/licence/find', ReponseFausse.vide()))),
  CasAffichage('Connexion', parcoursDemarrage(LoginScreen)),
  CasAffichage('Accueil', ecranConnecte(() => const HomeScreen())),
  for (final m in modulesAccueil) CasAffichage(m.tuile, ecranConnecte(m.ecran)),
  for (final e in etatsSupplementaires) CasAffichage(e.nom, ecranConnecte(e.ecran, recherche: e.recherche)),
];
