// Parcours de bout en bout (3.10.2, revu en 3.10.3), application ENTIÈRE contre le faux serveur local (vrai réseau
// HTTP) : redéploiement de Prestige pendant la connexion — /user/auth et /officine en 404 → « Serveur indisponible :
// Prestige est en cours de démarrage ou de redéploiement… » (aucun « 404 » à l'écran) ; Prestige revenu → réessai →
// accueil ; puis Prestige ARRÊTÉ (port fermé, vraie connexion refusée) → « Serveur injoignable. Vérifiez le Wi-Fi et
// que le PC serveur est allumé. » (cas 1 du pharmacien).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

Future<void> saisir(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
}

Future<void> valider(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('connexion_se_connecter')));
  await stabiliser(tester, tours: 20);
}

Future<void> tenter(WidgetTester tester) async {
  await saisir(tester);
  await valider(tester);
}

void main() {
  setUpAll(chargerPolicesReelles);
  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerNouvelle(serveur, p: Presentation.compact);
    donneesAccueil(serveur);
  });
  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true;
  });

  testWidgets('redéploiement (404) → « Serveur indisponible » → réessai → accueil ; Prestige arrêté (connexion refusée) → « Serveur injoignable »', (tester) async {
    telephone(tester);
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(LoginScreen));
    await stabiliser(tester);

    // Redéploiement : l'application Prestige n'est plus servie (404) le temps du déploiement.
    serveur
      ..quand(AppConstants.authEndpoint, ReponseFausse.introuvable(), methode: 'POST')
      ..quand(AppConstants.officineEndpoint, ReponseFausse.introuvable(), methode: 'GET');
    await tenter(tester);
    await attendreWidget(tester, find.text(ApiLoadException.messageServeurIndisponible));
    expect(find.textContaining('404'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);

    // Redéployé : réessai → accueil.
    serveur.installerRoutesParDefaut();
    donneesAccueil(serveur);
    await tenter(tester);
    await attendreWidget(tester, find.byType(AccueilNouveau));
    await terminer(tester);

    // Prestige ARRÊTÉ pendant que l'écran de connexion est affiché : port fermé, vraie connexion refusée.
    serveur.installerRoutesParDefaut();
    donneesAccueil(serveur);
    utiliserReseauReel();
    await lancerApplication(tester);
    await attendreWidget(tester, find.byType(LoginScreen));
    await stabiliser(tester);
    await saisir(tester);
    await tester.runAsync(serveur.arreter);
    // Client neuf (aucune connexion gardée ouverte) : la requête ouvre un socket vers le port fermé.
    ApiService.client.close();
    ApiService.client = http.Client();
    await valider(tester);
    // 3.10.3 : PC serveur éteint ou Payara arrêté = cas 1 « Serveur injoignable… PC serveur allumé ».
    await attendreWidget(tester, find.text(ApiLoadException.messageReseau));
    expect(find.text(ApiLoadException.messageServeurIndisponible), findsNothing);
    await terminer(tester);
  });
}
