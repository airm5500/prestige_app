// RÉSEAU — HTTPS RÉEL. Le faux serveur Prestige est servi en VRAI HTTPS (HttpServer.bindSecure, 127.0.0.1) avec un
// certificat de test AUTO-SIGNÉ généré au lancement du test par openssl (jamais versionné : aucune clé privée dans
// le dépôt), l'application visant « https://127.0.0.1 » (adresse acceptée depuis l'étape 1h) :
//  - certificat approuvé SEULEMENT dans ce test (client HTTP dont le SecurityContext ne reconnaît que lui) : licence,
//    connexion (cookie JSESSIONID), liste, écriture fonctionnent comme en HTTP ;
//  - client de l'application tel quel (certificat inconnu) : « certificat du serveur refusé », message DISTINCT de
//    « serveur injoignable » (licence, connexion, liste, écriture) ; serveur réellement arrêté : « injoignable » ;
//  - écrans (certificat refusé simulé par le client, comme vérifié en vrai HTTPS ci-dessus) : connexion (deux
//    interfaces), lancement (titre « Certificat du serveur refusé », 3.9.1 — avant : « Le serveur ne répond pas »,
//    « Vérifiez le Wi-Fi »), module (titre dédié, 3.9.1 — avant : « Serveur injoignable »), alertes de l'accueil A.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/testing.dart';
import 'package:prestige_app/donnees/suggestions_donnees.dart';
import 'package:prestige_app/donnees/suivi_credit_donnees.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/serveur_injoignable_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot2.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';
import '../support/reseau.dart';

/// Certificat de test auto-signé (127.0.0.1 / localhost), valable 2 jours, généré dans un dossier temporaire.
/// null si openssl est absent (tests sautés, motif affiché).
({String cert, String cle})? genererCertificat() {
  try {
    final d = Directory.systemTemp.createTempSync('prestige_tls_');
    final r = Process.runSync('openssl', [
      'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2', //
      '-keyout', '${d.path}/cle.pem', '-out', '${d.path}/cert.pem',
      '-subj', '/CN=127.0.0.1', '-addext', 'subjectAltName=IP:127.0.0.1,DNS:localhost',
    ]);
    if (r.exitCode != 0) return null;
    return (cert: '${d.path}/cert.pem', cle: '${d.path}/cle.pem');
  } on ProcessException {
    return null;
  }
}

final certificat = genererCertificat();
final sansOpenssl = certificat == null ? 'openssl absent : certificat de test impossible à générer' : null;

/// Client HTTP qui approuve le certificat de test (et lui seul).
http.Client clientApprouvant() =>
    IOClient(HttpClient(context: SecurityContext(withTrustedRoots: false)..setTrustedCertificates(certificat!.cert)));

/// Message dédié au certificat, distinct de « serveur injoignable ».
bool dedie(String? m) => m == ApiLoadException.messageCertificat && !m!.toLowerCase().contains('injoignable');

Future<Object?> appel(WidgetTester tester, Future<Object?> Function() f) async {
  Object? resultat;
  await tester.runAsync(() async {
    try {
      resultat = await f();
    } catch (e) {
      resultat = e;
    }
  });
  await tester.pump();
  return resultat;
}

/// Faux serveur dont le client lève HandshakeException, comme le vrai client quand le certificat est refusé
/// (vérifié en vrai HTTPS ci-dessus) : pour les écrans (temps simulé, pas de vrai socket).
http.Client clientCertificatRefuse(FauxServeurPrestige s, bool Function() refuser) {
  final memoire = s.clientMemoire();
  return MockClient((req) async {
    if (refuser()) throw const HandshakeException('CERTIFICATE_VERIFY_FAILED: self signed certificate');
    final copie = http.Request(req.method, req.url)
      ..headers.addAll(req.headers)
      ..bodyBytes = req.bodyBytes;
    return http.Response.fromStream(await memoire.send(copie));
  });
}

void main() {
  group('HTTPS réel (serveur local, certificat de test auto-signé)', () {
    late FauxServeurPrestige serveur;

    setUp(() async {
      if (certificat == null) return;
      serveur = FauxServeurPrestige();
      final ctx = SecurityContext()
        ..useCertificateChain(certificat!.cert)
        ..usePrivateKey(certificat!.cle);
      await serveur.demarrerSecurise(ctx);
      utiliserReseauReel(); // vrai client HTTP (certificats du système : le certificat de test y est inconnu)
      preparerTelephone(serveur); // adresse « https://127.0.0.1 »
      await ApiService().clearSessionCookie();
    });

    tearDown(() async {
      if (certificat == null) return;
      restaurerClient();
      await serveur.arreter();
    });

    testWidgets('l\'application appelle bien le serveur en https://', (tester) async {
      expect(serveur.racine, startsWith('https://127.0.0.1:'));
      expect(serveur.preferencesApp()['local_ip'], 'https://127.0.0.1');
    }, skip: sansOpenssl != null);

    testWidgets('certificat approuvé : licence, connexion (cookie), liste, écriture d\'une quantité', (tester) async {
      ApiService.client = clientApprouvant();
      final licence = LicenceProvider(), auth = AuthProvider();
      final ctx = await monterAvecProviders(tester, licence: licence, auth: auth);
      await appel(tester, () => licence.checkLicence(ctx));
      expect(licence.status, LicenceStatus.valid, reason: '${licence.dernierEchec?.detail}');
      expect(await appel(tester, () => auth.login(ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false)), isNull);
      expect(auth.isLoggedIn, isTrue);
      serveur.quand(AppConstants.suiviCreditEndpoint, ReponseFausse.json(DonneesFictives.creditsTiersPayants()), methode: 'GET');
      final credits = await appel(tester, () => SuiviCredits.charger(ctx, DateTime(2026, 10, 14), DateTime(2026, 10, 14)));
      expect(credits, isA<List>().having((l) => l.length, 'lignes', 3));
      expect(serveur.recues(AppConstants.suiviCreditEndpoint).single.sessionEnvoyee, serveur.derniereSession, reason: 'cookie JSESSIONID en HTTPS');
      serveur.quand(AppConstants.suggestionUpdateQteEndpoint, ReponseFausse.json({'success': true}), methode: 'POST');
      final r = await appel(tester, () => Suggestions.enregistrerQuantite(ctx, DonneesLot2.article1, 7));
      expect(r, isA<Map>().having((m) => m['success'], 'success', true));
      expect(serveur.recues(AppConstants.suggestionUpdateQteEndpoint).single.json, {'itemId': DonneesLot2.article1, 'qte': 7});
    }, skip: sansOpenssl != null);

    group('certificat refusé (client de l\'application, certificat inconnu)', () {
      testWidgets('licence au lancement : motif « certificat », serveur en cause (pas « aucune licence »)', (tester) async {
        final licence = LicenceProvider();
        final ctx = await monterAvecProviders(tester, licence: licence);
        await appel(tester, () => licence.checkLicence(ctx));
        expect(licence.status, LicenceStatus.error);
        expect(licence.dernierEchec?.issue, LicenceIssue.unreachable);
        expect(dedie(licence.dernierEchec?.detail), isTrue, reason: '${licence.dernierEchec?.detail}');
      }, skip: sansOpenssl != null);

      testWidgets('connexion : message dédié, rien n\'est parti (poignée de main refusée)', (tester) async {
        final auth = AuthProvider();
        final ctx = await monterAvecProviders(tester, auth: auth);
        final m = await appel(tester, () => auth.login(ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false));
        expect(dedie(m as String?), isTrue, reason: '$m');
        expect(auth.isLoggedIn, isFalse);
        expect(serveur.recues(AppConstants.authEndpoint), isEmpty);
      }, skip: sansOpenssl != null);

      testWidgets('liste et écriture : message dédié (≠ « Serveur injoignable »)', (tester) async {
        final ctx = await monterAvecProviders(tester);
        final l = await appel(tester, () => SuiviCredits.charger(ctx, DateTime(2026, 10, 14), DateTime(2026, 10, 14)));
        expect(l, isA<ApiLoadException>().having((e) => dedie(e.message), 'message dédié', isTrue));
        final rayons = await appel(tester, () => ApiService().getRayons(ctx));
        expect(rayons, isA<ApiLoadException>().having((e) => dedie(e.message), 'message dédié (« … non chargés » non ajouté)', isTrue));
        final w = await appel(tester, () => Suggestions.enregistrerQuantite(ctx, DonneesLot2.article1, 3));
        expect(w, isA<ApiLoadException>().having((e) => dedie(e.message), 'message dédié', isTrue));
        expect(serveur.requetes, isEmpty, reason: 'rien n\'est parti');
      }, skip: sansOpenssl != null);

      testWidgets('serveur réellement arrêté : toujours « injoignable » (pas « certificat »)', (tester) async {
        final ctx = await monterAvecProviders(tester);
        await tester.runAsync(serveur.arreter);
        final l = await appel(tester, () => SuiviCredits.charger(ctx, DateTime(2026, 10, 14), DateTime(2026, 10, 14)));
        expect(l, isA<ApiLoadException>().having((e) => e.message, 'message', ApiLoadException.messageReseau));
      }, skip: sansOpenssl != null);
    });
  });

  group('Écrans (certificat refusé simulé : exception levée par le client HTTPS)', () {
    final serveur = FauxServeurPrestige();
    var refuser = true;

    setUpAll(() async {
      await chargerPolicesReelles();
      await serveur.demarrer();
    });
    tearDownAll(serveur.arreter);
    setUp(() {
      brancherEnMemoire(serveur);
      refuser = true;
      ApiService.client = clientCertificatRefuse(serveur, () => refuser);
      donneesAccueil(serveur);
      donneesAlertes(serveur);
    });

    void telephone(WidgetTester tester) {
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
      addTearDown(tester.view.reset);
    }

    Future<void> connexionRefusee(WidgetTester tester) async {
      await pomper(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'connexion', max: 100);
      await tester.pump(const Duration(milliseconds: 500));
      refuser = true; // certificat du serveur changé après le lancement
      await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
      final nv = find.byKey(const Key('connexion_se_connecter'));
      await tester.tap(nv.evaluate().isNotEmpty ? nv : find.widgetWithText(ElevatedButton, 'Connexion'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text(ApiLoadException.messageCertificat), findsOneWidget);
      expect(find.textContaining('injoignable'), findsNothing);
    }

    for (final nouvelle in [true, false]) {
      final nom = nouvelle ? 'nouvelle interface' : 'ancienne interface';
      testWidgets('connexion ($nom) : « certificat du serveur refusé », pas « injoignable »', (tester) async {
        telephone(tester);
        preparerTelephone(serveur, nouvelle: nouvelle);
        refuser = false;
        await lancerApplication(tester);
        await connexionRefusee(tester);
        await fermerApplication(tester);
      });

      testWidgets('lancement ($nom, aucune licence en cache) : titre « Certificat du serveur refusé »', (tester) async {
        telephone(tester);
        preparerTelephone(serveur, nouvelle: nouvelle);
        await lancerApplication(tester);
        await pomper(tester, () => find.byType(ServeurInjoignableScreen).evaluate().isNotEmpty, raison: 'écran du lancement', max: 100);
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.widget<Text>(find.byKey(const Key('injoignable_titre'))).data, ApiLoadException.titreCertificat);
        expect(find.text('Le serveur ne répond pas'), findsNothing);
        expect(find.textContaining('Wi-Fi'), findsNothing, reason: 'pas un conseil réseau trompeur');
        expect(find.textContaining('certificat'), findsWidgets);
        expect(find.textContaining('licence n\'est pas en cause'), findsWidgets);
        await fermerApplication(tester);
      });
    }

    testWidgets('module (Suivi Crédit) : titre « Certificat du serveur refusé », message dédié, « Réessayer »', (tester) async {
      telephone(tester);
      preparerNouvelle(serveur, p: Presentation.compact);
      await ouvrirDepuisAccueil(tester, serveur, const SuiviCreditNouveau());
      await pomper(tester, () => find.byKey(const Key('bouton_reessayer')).evaluate().isNotEmpty, raison: 'erreur');
      expect(find.text(ApiLoadException.titreCertificat), findsOneWidget);
      expect(find.text('Serveur injoignable'), findsNothing);
      expect(find.text(ApiLoadException.messageCertificat), findsOneWidget);
      // Certificat de nouveau accepté : « Réessayer » charge les crédits.
      refuser = false;
      serveur.quand(AppConstants.suiviCreditEndpoint, ReponseFausse.json(DonneesFictives.creditsTiersPayants()), methode: 'GET');
      await tester.tap(find.byKey(const Key('bouton_reessayer')));
      await pomper(tester, () => find.byKey(const Key('chiffre_montant')).evaluate().isNotEmpty, raison: 'crédits');
      expect(erreursAffichees(), findsNothing);
      await fermerApplication(tester);
    });

    testWidgets('alertes de l\'accueil A : « Certificat du serveur refusé », pas « Serveur injoignable »', (tester) async {
      telephone(tester);
      preparerNouvelle(serveur, p: Presentation.tableauDeBord);
      refuser = false;
      await lancerApplication(tester);
      await pomper(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'connexion', max: 100);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
      await tester.tap(find.byKey(const Key('connexion_se_connecter')));
      await pomper(tester, () => find.byType(AccueilNouveau).evaluate().isNotEmpty, raison: 'accueil');
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      refuser = true;
      final bouton = find.byKey(const Key('alerte_peremption_actualiser'));
      await tester.ensureVisible(bouton);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(bouton);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.ensureVisible(find.byKey(const Key('alerte_peremption_echec')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('alerte_peremption_echec'))).data, contains('Certificat du serveur refusé'));
      expect(find.text(ApiLoadException.messageReseau), findsNothing);
      await fermerApplication(tester);
    });
  });
}
