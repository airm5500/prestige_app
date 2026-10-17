// RÉSEAU iOS (3.12.0), faux serveur « en mémoire », plateforme iOS (iPhone 430×932) :
//  - serveur coupé (Wi-Fi absent, serveur éteint) : mêmes messages qu'Android (« Serveur injoignable » + Réessayer),
//    pas de déconnexion ; au retour, ⟳ recharge ;
//  - serveur lent : la carte attend sans bloquer les autres ;
//  - adresse du serveur : http vers une IP ou un nom du réseau local, https vers Internet — acceptés comme sur Android
//    (les connexions de l'application passent par dart:io, que l'ATS d'iOS ne filtre pas ; Info.plist n'autorise
//    d'ailleurs que le réseau local en clair).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/adresse_serveur.dart';

import '../support/donnees_fictives.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void iphone(WidgetTester tester) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = const Size(430 * 3.0, 2400 * 3.0); // toutes les cartes à l'écran
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    brancherEnMemoire(serveur);
    preparerNouvelle(serveur, p: Presentation.tableauPrestige);
    donneesAccueil(serveur);
    donneesLot3(serveur);
    ProfilAcces.utilisateur.value = AppUser.fromJson(DonneesFictives.utilisateur());
  });
  tearDown(() {
    ProfilAcces.utilisateur.value = null;
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS, serveur coupé : « Serveur injoignable » + Réessayer, sans déconnexion ; retour : ⟳ recharge', (tester) async {
    iphone(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      serveur.coupe = true;
      await ouvrirEcran(tester, serveur, const AccueilNouveau(), pret: find.textContaining(ApiLoadException.messageReseau));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Réessayer'), findsWidgets);
      expect(find.byType(LoginScreen), findsNothing);
      serveur.coupe = false;
      serveur.oublierRequetes();
      await tester.tap(find.byKey(const Key('tableau_bord_actualiser')));
      await pomper(tester, () => find.byKey(const Key('chiffre_tb_ca')).evaluate().isNotEmpty, raison: 'chiffres revenus');
      await fermerApplication(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS, fréquentation lente (8 s) : les autres cartes s\'affichent, puis la fréquentation', (tester) async {
    iphone(tester);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      serveur.route(ApiTableauBord.routeFrequentationPilotage,
          (r) => ReponseFausse.json(DonneesVague4.frequentationPilotage(r.parametres['dtStart'] ?? '')).apres(const Duration(seconds: 8)), methode: 'GET');
      await ouvrirEcran(tester, serveur, const AccueilNouveau(), pret: find.byKey(const Key('chiffre_tb_ca')));
      expect(find.byKey(const Key('frequentation_resume')), findsNothing);
      await pomper(tester, () => find.byKey(const Key('frequentation_resume')).evaluate().isNotEmpty, raison: 'fréquentation');
      await fermerApplication(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('adresses du serveur acceptées sur iOS comme sur Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    for (final a in ['192.168.1.10', 'serveur-pharmacie', 'serveur.local', 'https://pharmacie.example.com', 'http://41.202.10.5']) {
      expect(AdresseServeur.erreur(a, requis: true), isNull, reason: a);
    }
  });
}
