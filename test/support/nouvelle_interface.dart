// Outils des tests de la NOUVELLE interface (lib/nouvelle_interface/) : téléphone préparé dans la présentation
// voulue, données de l'accueil « A · Tableau de bord », connexion et navigation dans le nouvel accueil.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/utils/constants.dart';

import 'application.dart';
import 'donnees_fictives.dart';
import 'faux_serveur_prestige.dart';

/// Présentations de la nouvelle interface testées, avec l'appareil où elles s'affichent.
const presentationsTestees = <(String, Presentation)>[
  ('A', Presentation.tableauDeBord),
  ('B', Presentation.compact),
  ('C', Presentation.guide),
];

/// Réponses des chiffres du jour (accueil A) : récapitulatif du jour et équipe fictive.
void donneesAccueil(FauxServeurPrestige serveur) {
  serveur.quand('/recap/dashboard', ReponseFausse.json(DonneesFictives.recapDuJour()), methode: 'GET');
  serveur.route('/rh/presence', (r) => ReponseFausse.json(DonneesFictives.presenceEquipe(r.parametres['jour'] ?? '2026-10-13')),
      methode: 'GET');
}

/// Réponses des routes que comptent les alertes de l'accueil A (seulement après un appui sur ⟳) et que lisent les
/// modules Suivi Péremption et Etat Contrôle Achat.
void donneesAlertes(FauxServeurPrestige serveur) {
  serveur.quand(AppConstants.suiviPeremptionEndpoint, ReponseFausse.json(DonneesFictives.perimes()), methode: 'GET');
  serveur.quand(AppConstants.etatControleAchatEndpoint, ReponseFausse.json(DonneesFictives.etatControleAchat()), methode: 'GET');
}

/// Réponses des modules refaits du lot 1 (Rapport d'Activité, Détail CA, Suivi Crédit, Suivi Péremption) ; Analyse
/// et Fiche Article ont déjà leurs routes par défaut (/info, /checkproduit).
void donneesLot1(FauxServeurPrestige serveur) {
  serveur
    ..quand(AppConstants.dashboardRecapEndpoint, ReponseFausse.json(DonneesFictives.rapportActivite()), methode: 'GET')
    ..quand(AppConstants.creditsRecapEndpoint, ReponseFausse.json(DonneesFictives.creditsTiersPayants()), methode: 'GET')
    ..quand(AppConstants.creditTotalsRecapEndpoint, ReponseFausse.json(DonneesFictives.creditsTotaux()), methode: 'GET')
    ..quand(AppConstants.reglementsRecapEndpoint, ReponseFausse.json(DonneesFictives.reglementsRecus()), methode: 'GET')
    ..quand(AppConstants.caComptantEndpoint, ReponseFausse.json(DonneesFictives.caParJour()), methode: 'GET')
    ..quand(AppConstants.suiviPeremptionEndpoint, ReponseFausse.json(DonneesFictives.perimes()), methode: 'GET');
}

/// Téléphone configuré, nouvelle interface dans la présentation [p].
void preparerNouvelle(FauxServeurPrestige serveur,
        {Presentation p = Presentation.automatique,
        AffichageMenus affichage = AffichageMenus.unePage,
        StyleIcones style = StyleIcones.actuel,
        Map<String, Object> prefs = const {}}) =>
    preparerTelephone(serveur, nouvelle: true, presentation: p, affichageMenus: affichage, styleIcones: style, autres: prefs);

/// Connexion depuis l'écran de connexion de la nouvelle interface (bouton « Se connecter »).
Future<void> seConnecterNouvelle(WidgetTester tester,
    {String identifiant = DonneesFictives.identifiant, String motDePasse = DonneesFictives.motDePasse}) async {
  await attendreWidget(tester, find.byType(LoginScreen));
  await stabiliser(tester);
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), motDePasse);
  await tester.tap(find.byKey(const Key('connexion_se_connecter')));
}

/// Lancement → connexion → nouvel accueil.
Future<void> jusquAccueilNouveau(WidgetTester tester) async {
  await lancerApplication(tester);
  await seConnecterNouvelle(tester);
  await attendreWidget(tester, find.byType(AccueilNouveau));
  await stabiliser(tester);
}

/// Pompe l'horloge simulée (tests « en mémoire » : client HTTP sans socket) jusqu'à [condition].
Future<void> pomperJusqua(WidgetTester tester, bool Function() condition, {String raison = 'condition', int max = 80}) async {
  for (var i = 0; i < max && !condition(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(condition(), isTrue, reason: raison);
}

/// Connexion « en mémoire » (ergonomie, captures) jusqu'au nouvel accueil.
Future<void> connecterEnMemoire(WidgetTester tester) async {
  await lancerApplication(tester);
  await pomperJusqua(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'écran de connexion');
  await tester.pump(const Duration(milliseconds: 500));
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
  await tester.tap(find.byKey(const Key('connexion_se_connecter')));
  await pomperJusqua(tester, () => find.byType(AccueilNouveau).evaluate().isNotEmpty, raison: 'nouvel accueil');
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Réglages : bouton engrenage en haut à droite de l'accueil (page à part).
Future<void> toucherReglages(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('bouton_reglages')));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Onglet de la barre du bas (téléphone) ou du menu latéral (tablette, présentation B).
Future<void> ouvrirOnglet(WidgetTester tester, String nom) async {
  final barre = find.descendant(of: find.byKey(const Key('barre_accueil')), matching: find.text(nom));
  await tester.tap(barre.evaluate().isNotEmpty ? barre : find.descendant(of: find.byType(AccueilNouveau), matching: find.text(nom)).first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}
