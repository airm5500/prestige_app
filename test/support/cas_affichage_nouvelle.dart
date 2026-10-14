// Écrans de la NOUVELLE interface rendus par les tests d'ergonomie et de cohérence (test/ergonomie/) : parcours
// de démarrage (Configuration, serveur injoignable, licence, connexion A et B), accueil A / B / C, onglets
// Analyses / Équipe / Réglages, écrans de la présentation C, puis chaque module de l'accueil et les états
// supplémentaires, avec le thème de la nouvelle interface. Données : faux serveur Prestige « en mémoire ».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/screens/licence_registration_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/serveur_injoignable_screen.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/utils/constants.dart';

import 'cas_affichage.dart';
import 'catalogue_ecrans.dart';
import 'donnees_fictives.dart';
import 'faux_serveur_prestige.dart';
import 'nouvelle_interface.dart';

/// [ouvrir] dans la nouvelle interface, présentation [p] (données de l'accueil A fournies par le serveur).
Future<void> Function(WidgetTester, FauxServeurPrestige) enNouvelle(Future<void> Function(WidgetTester, FauxServeurPrestige) ouvrir,
        {Presentation p = Presentation.automatique, Future<void> Function(WidgetTester)? ensuite, void Function(FauxServeurPrestige)? donnees}) =>
    (tester, serveur) async {
      preparerNouvelle(serveur, p: p);
      donneesAccueil(serveur);
      donnees?.call(serveur);
      await ouvrir(tester, serveur);
      if (ensuite != null) await ensuite(tester);
    };

Future<void> Function(WidgetTester) onglet(String nom) => (tester) async {
      await ouvrirOnglet(tester, nom);
      await tester.pump(const Duration(milliseconds: 500));
    };

/// Appuie sur le ⟳ de chaque alerte de l'accueil A et attend la fin des comptages (ou [attendre] seulement).
/// [attendus] : clés qui doivent alors être affichées (le cas rend bien l'état voulu).
Future<void> Function(WidgetTester) compterAlertes(List<String> attendus, {Duration attendre = const Duration(seconds: 2)}) =>
    (tester) async {
      for (final cle in ['peremption', 'controle']) {
        final bouton = find.byKey(Key('alerte_${cle}_actualiser'));
        tester.widget<IconButton>(bouton).onPressed!();
        await tester.pump(const Duration(milliseconds: 100));
      }
      for (var i = 0; i < attendre.inMilliseconds ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(find.byKey(const Key('alerte_controle')));
      await tester.pump(const Duration(milliseconds: 500));
      for (final cle in attendus) {
        expect(find.byKey(Key(cle)), findsOneWidget, reason: cle);
      }
    };

final casAffichageNouvelle = <CasAffichage>[
  CasAffichage('Configuration IP (premier lancement)', enNouvelle(parcoursDemarrage(SettingsScreen, configure: false))),
  CasAffichage('Serveur injoignable', enNouvelle(parcoursDemarrage(ServeurInjoignableScreen, preparer: (s) => s.coupe = true))),
  CasAffichage('Licence requise',
      enNouvelle(parcoursDemarrage(LicenceRegistrationScreen, preparer: (s) => s.quand('/licence/find', ReponseFausse.vide())))),
  CasAffichage('Connexion A', enNouvelle(parcoursDemarrage(LoginScreen))),
  CasAffichage('Connexion B', enNouvelle(parcoursDemarrage(LoginScreen), p: Presentation.compact)),
  for (final (lettre, p) in presentationsTestees)
    CasAffichage('Accueil $lettre', enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: p)),
  // Alertes de l'accueil A : nombres affichés ; puis échec (500) et comptage en cours (réponse lente).
  CasAffichage('Accueil A · alertes comptées',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, donnees: donneesAlertes, ensuite: compterAlertes(['alerte_peremption_nombre', 'alerte_controle_nombre']))),
  CasAffichage(
      'Accueil A · alertes en échec et en cours',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()),
          p: Presentation.tableauDeBord,
          donnees: (s) => s
            ..quand('/tableau-bord/alertes', ReponseFausse.erreurServeur())
            ..quand(AppConstants.etatControleAchatEndpoint, ReponseFausse.json(DonneesFictives.etatControleAchat()).apres(const Duration(seconds: 30))),
          ensuite: compterAlertes(['alerte_peremption_echec', 'alerte_controle_encours']))),
  CasAffichage('Onglet Analyses', enNouvelle(ecranConnecte(() => const AccueilNouveau()), ensuite: onglet('Analyses'))),
  CasAffichage('Onglet Équipe', enNouvelle(ecranConnecte(() => const AccueilNouveau()), ensuite: onglet('Équipe'))),
  CasAffichage('Onglet Réglages', enNouvelle(ecranConnecte(() => const AccueilNouveau()), ensuite: onglet('Réglages'))),
  for (final q in Question.values) CasAffichage('Question C : ${q.titre}', enNouvelle(ecranConnecte(() => QuestionScreen(question: q)))),
  CasAffichage('Tous les menus (C)', enNouvelle(ecranConnecte(() => const TousLesMenusScreen()))),
  for (final m in modulesAccueil) CasAffichage(m.tuile, enNouvelle(ecranConnecte(m.ecran))),
  for (final e in etatsSupplementaires) CasAffichage(e.nom, enNouvelle(ecranConnecte(e.ecran, recherche: e.recherche))),
];

/// Noms des cas qui sont des écrans de MODULES d'origine (seuls à pouvoir garder leurs écarts connus).
final modulesOuEtats = <String>{for (final m in modulesAccueil) m.tuile, for (final e in etatsSupplementaires) e.nom};
