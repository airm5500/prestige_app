// Écrans de la NOUVELLE interface rendus par les tests d'ergonomie et de cohérence (test/ergonomie/) : parcours
// de démarrage (Configuration, serveur injoignable, licence, connexion A et B), accueil A / B / C, onglets
// Analyses / Équipe / Réglages, écrans de la présentation C, puis chaque module de l'accueil et les états
// supplémentaires, avec le thème de la nouvelle interface. Données : faux serveur Prestige « en mémoire ».
import 'package:flutter/material.dart';
import 'package:prestige_app/nouvelle_interface/vague2/previsions_vague2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/rapport_activite_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_peremption_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/screens/licence_registration_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/serveur_injoignable_screen.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:prestige_app/widgets/taille_ecran_reglage.dart';

import 'cas_affichage.dart';
import 'catalogue_ecrans.dart';
import 'donnees_fictives.dart';
import 'donnees_vague1.dart';
import 'faux_serveur_prestige.dart';
import 'nouvelle_interface.dart';
import 'cas_lot2.dart';
import 'cas_lot3.dart';
import 'cas_lot4.dart';
import 'cas_retours_3_10_0.dart';
import 'cas_retours_3_9_0.dart';

/// [ouvrir] dans la nouvelle interface, présentation [p] (données de l'accueil A fournies par le serveur).
Future<void> Function(WidgetTester, FauxServeurPrestige) enNouvelle(Future<void> Function(WidgetTester, FauxServeurPrestige) ouvrir,
        {Presentation p = Presentation.automatique,
        Future<void> Function(WidgetTester)? ensuite,
        void Function(FauxServeurPrestige)? donnees,
        AffichageMenus affichage = AffichageMenus.unePage,
        StyleIcones? style = StyleIcones.actuel,
        Map<String, Object> prefs = const {}}) =>
    (tester, serveur) async {
      preparerNouvelle(serveur, p: p, affichage: affichage, style: style, prefs: prefs);
      donneesAccueil(serveur);
      donnees?.call(serveur);
      await ouvrir(tester, serveur);
      if (ensuite != null) await ensuite(tester);
    };

Future<void> Function(WidgetTester) onglet(String nom) => (tester) async {
      await ouvrirOnglet(tester, nom);
      await tester.pump(const Duration(milliseconds: 500));
    };

/// Appuie sur le ⟳ de l'accueil A (un seul appel pour tout le bloc) et attend la fin du comptage (ou [attendre]).
/// [attendus] : clés qui doivent alors être affichées (le cas rend bien l'état voulu).
Future<void> Function(WidgetTester) compterAlertes(List<String> attendus, {Duration attendre = const Duration(seconds: 2)}) =>
    (tester) async {
      tester.widget<IconButton>(find.byKey(const Key('alerte_peremption_actualiser'))).onPressed!();
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < attendre.inMilliseconds ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(find.byKey(const Key('alerte_ruptures')));
      await tester.pump(const Duration(milliseconds: 500));
      for (final cle in attendus) {
        expect(find.byKey(Key(cle)), findsOneWidget, reason: cle);
      }
    };

final casAffichageNouvelle = <CasAffichage>[
  CasAffichage('Configuration IP (premier lancement)', enNouvelle(parcoursDemarrage(SettingsScreen, configure: false))),
  CasAffichage('Serveur injoignable', enNouvelle(parcoursDemarrage(ServeurInjoignableScreen, preparer: (s) => s.coupe = true))),
  // 3.10.3 : démarrage avec Prestige pas déployé ; module pendant un redéploiement (404 confirmé par /officine).
  CasAffichage('Démarrage · serveur indisponible',
      enNouvelle(parcoursDemarrage(ServeurInjoignableScreen, preparer: (s) => s.quand('/licence/find', ReponseFausse.erreurServeur(statut: 503))))),
  CasAffichage(
      'Module · serveur indisponible (redéploiement)',
      enNouvelle(ecranConnecte(() => const PrevisionsScreen()),
          donnees: (s) => s
            ..quand('/analyse-commande/tableau', ReponseFausse.introuvable(), methode: 'GET')
            ..quand('/officine', ReponseFausse.introuvable(), methode: 'GET'))),
  CasAffichage('Licence requise',
      enNouvelle(parcoursDemarrage(LicenceRegistrationScreen, preparer: (s) => s.quand('/licence/find', ReponseFausse.vide())))),
  CasAffichage('Connexion A', enNouvelle(parcoursDemarrage(LoginScreen))),
  CasAffichage('Connexion B', enNouvelle(parcoursDemarrage(LoginScreen), p: Presentation.compact)),
  // 3.10.2 : connexion pendant un redéploiement de Prestige.
  CasAffichage('Connexion A · serveur indisponible', enNouvelle(connexionIndisponible(parcoursDemarrage(LoginScreen)))),
  CasAffichage('Connexion B · serveur indisponible', enNouvelle(connexionIndisponible(parcoursDemarrage(LoginScreen)), p: Presentation.compact)),
  for (final (lettre, p) in presentationsTestees)
    CasAffichage('Accueil $lettre', enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: p)),
  // Alertes de l'accueil A : nombres affichés ; puis échec (500) et comptage en cours (réponse lente).
  CasAffichage('Accueil A · alertes comptées',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, donnees: donneesAlertes, ensuite: compterAlertes(['alerte_peremption_nombre', 'alerte_ruptures_nombre']))),
  CasAffichage(
      'Accueil A · alertes en échec',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()),
          p: Presentation.tableauDeBord,
          donnees: (s) => s.quand('/tableau-bord/alertes', ReponseFausse.erreurServeur()),
          ensuite: compterAlertes(['alerte_peremption_echec', 'alerte_ruptures_echec']))),
  CasAffichage(
      'Accueil A · alertes en cours',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()),
          p: Presentation.tableauDeBord,
          donnees: (s) => s.quand('/tableau-bord/alertes', ReponseFausse.json(DonneesVague1.alertes()).apres(const Duration(seconds: 30))),
          ensuite: compterAlertes(['alerte_peremption_encours', 'alerte_ruptures_encours']))),
  CasAffichage('Onglet Analyses', enNouvelle(ecranConnecte(() => const AccueilNouveau()), ensuite: onglet('Analyses'))),
  CasAffichage('Onglet Équipe', enNouvelle(ecranConnecte(() => const AccueilNouveau()), ensuite: onglet('Équipe'))),
  CasAffichage('Réglages (bouton engrenage)', enNouvelle(ecranConnecte(() => const AccueilNouveau()), ensuite: (tester) async {
    await toucherReglages(tester);
    await tester.pump(const Duration(milliseconds: 500));
  })),
  // 3.8.0 (D1) : taille de l'écran pour le compte « admin » (sans code, sans cadenas).
  CasAffichage('Réglages · taille de l\'écran (administrateur)', enNouvelle(ecranConnecte(() => Scaffold(
        appBar: AppBar(title: const Text('Réglages')),
        body: ListView(children: const [TailleEcranSetting(couleurAide: Charte.gris, administrateur: true)]),
      )))),
  for (final q in Question.values) CasAffichage('Question C : ${q.titre}', enNouvelle(ecranConnecte(() => QuestionScreen(question: q)))),
  CasAffichage('Tous les menus (C)', enNouvelle(ecranConnecte(() => const TousLesMenusScreen()))),
  // Modules ouverts par leur menu (nouvel écran pour le lot 1), « Fournisseurs » n'en fait plus partie.
  for (final m in modulesNouvelleInterface) CasAffichage(m.tuile, enNouvelle(ecranConnecte(m.ecran))),
  for (final e in _etatsOrigine) CasAffichage(e.nom, enNouvelle(ecranConnecte(e.ecran, recherche: e.recherche))),
  ...casLot1,
  ...casLot2,
  ...casLot3,
  ...casLot4,
  ...casRetours390,
  ...casRetours3100,
];

/// États supplémentaires des modules d'origine encore ouverts dans la nouvelle interface (ceux d'Analyse et de Fiche
/// Article concernent les écrans d'origine, remplacés par les états du lot 1 ci-dessous).
final _etatsOrigine = [for (final e in etatsSupplementaires) if (!modulesRefaits.any((m) => e.nom.startsWith(m.tuile))) e];

Future<void> Function(WidgetTester) toucher(Finder cible) => (tester) async {
      await tester.tap(cible.first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    };

/// Amène [cle] à l'écran en faisant défiler [defilement] (liste paresseuse), puis la touche.
Future<void> Function(WidgetTester) toucherApresDefilementLot1(String cle, {String defilement = 'defilement_module', String? attendu}) =>
    (tester) async {
      final f = find.byKey(Key(cle));
      final s = find.descendant(of: find.byKey(Key(defilement)), matching: find.byType(Scrollable)).first;
      for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
        await tester.drag(s, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(f);
      await tester.pump(const Duration(milliseconds: 300));
      await toucher(f)(tester);
      if (attendu != null) expect(find.byKey(Key(attendu)), findsOneWidget, reason: 'état rendu : $attendu');
    };

/// États des modules refaits (lot 1) : remplis, filtres, détail, exports, erreurs. Écrans propres à la nouvelle
/// interface : aucun écart toléré.
final casLot1 = <CasAffichage>[
  CasAffichage('Lot 1 · Rapport d\'Activité rempli', enNouvelle(ecranConnecte(() => const RapportActiviteNouveau()), donnees: donneesLot1)),
  CasAffichage('Lot 1 · Détail CA rempli', enNouvelle(ecranConnecte(() => const DetailCaNouveau()), donnees: donneesLot1)),
  CasAffichage('Lot 1 · Détail CA Mobile Money déplié',
      enNouvelle(ecranConnecte(() => const DetailCaNouveau()), donnees: donneesLot1,
          ensuite: toucherApresDefilementLot1('deplier_mobile', attendu: 'mobile_ligne_Autres / écart'))),
  CasAffichage(
      'Lot 1 · Détail CA Mobile Money en erreur',
      enNouvelle(ecranConnecte(() => const DetailCaNouveau()),
          donnees: (s) {
            donneesLot1(s);
            s.quand('/stats-recette-caisse/modes', ReponseFausse.erreurServeur(), methode: 'GET');
          },
          ensuite: toucherApresDefilementLot1('deplier_mobile', attendu: 'mobile_erreur_serveur'))),
  CasAffichage('Lot 1 · Suivi Crédit rempli', enNouvelle(ecranConnecte(() => const SuiviCreditNouveau()), donnees: donneesLot1)),
  CasAffichage('Lot 1 · Suivi Crédit filtres',
      enNouvelle(ecranConnecte(() => const SuiviCreditNouveau()), donnees: donneesLot1, ensuite: toucher(find.byKey(const Key('bouton_filtres'))))),
  CasAffichage('Lot 1 · Suivi Péremption rempli', enNouvelle(ecranConnecte(() => const SuiviPeremptionNouveau()), donnees: donneesLot1)),
  CasAffichage('Lot 1 · Suivi Péremption filtres',
      enNouvelle(ecranConnecte(() => const SuiviPeremptionNouveau()), donnees: donneesLot1, ensuite: toucher(find.byKey(const Key('bouton_filtres'))))),
  CasAffichage('Lot 1 · Suivi Péremption menu Exporter',
      enNouvelle(ecranConnecte(() => const SuiviPeremptionNouveau()), donnees: donneesLot1, ensuite: toucher(find.byKey(const Key('menu_exports'))))),
  CasAffichage('Lot 1 · Suivi Péremption détail du lot',
      enNouvelle(ecranConnecte(() => const SuiviPeremptionNouveau()), donnees: donneesLot1, ensuite: toucher(find.text(DonneesFictives.libelleArticle1)))),
  CasAffichage('Lot 1 · Analyse Article résultats', enNouvelle(ecranConnecte(() => const AnalyseArticleNouveau(), recherche: 'PARAFICTIF'))),
  CasAffichage('Lot 1 · Analyse Article détail',
      enNouvelle(ecranConnecte(() => const AnalyseArticleNouveau(), recherche: 'PARAFICTIF'), ensuite: toucher(find.text(DonneesFictives.libelleArticle1)))),
  CasAffichage('Lot 1 · Analyse Article aucun résultat', enNouvelle(ecranConnecte(() => const AnalyseArticleNouveau(), recherche: 'INTROUVABLE'))),
  CasAffichage('Lot 1 · Fiche Article résultats', enNouvelle(ecranConnecte(() => const FicheArticleNouveau(), recherche: 'PARAFICTIF'))),
  CasAffichage('Lot 1 · Fiche Article détail',
      enNouvelle(ecranConnecte(() => const FicheArticleNouveau(), recherche: 'PARAFICTIF'), ensuite: toucher(find.text(DonneesFictives.libelleArticle1)))),
  CasAffichage('Lot 1 · serveur injoignable', enNouvelle(ecranConnecte(() => const DetailCaNouveau()), donnees: (s) => s.coupe = true)),
  CasAffichage('Lot 1 · erreur du serveur',
      enNouvelle(ecranConnecte(() => const RapportActiviteNouveau()),
          donnees: (s) => s.quand(AppConstants.dashboardRecapEndpoint, ReponseFausse.erreurServeur()))),
  CasAffichage('Lot 1 · session expirée',
      enNouvelle(ecranConnecte(() => const SuiviCreditNouveau()), donnees: (s) => s.quand(AppConstants.suiviCreditEndpoint, ReponseFausse.sessionExpiree()))),
];

/// Noms des cas qui sont des écrans de MODULES d'origine (seuls à pouvoir garder leurs écarts connus). Les modules
/// refaits (lots 1, 2 et 3) n'en font pas partie : aucun écart toléré sur leurs nouveaux écrans.
final modulesOuEtats = <String>{
  for (final m in modulesNouvelleInterface)
    if (!modulesRefaits.any((l) => l.tuile == m.tuile)) m.tuile,
  for (final e in _etatsOrigine) e.nom,
};
