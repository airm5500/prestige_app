// RÉSEAU — passage LOCAL ↔ DISTANT (deux faux serveurs Prestige « en mémoire » derrière le client HTTP de
// l'application : « 127.0.0.1 » = serveur local de l'officine, « distant.invalid » = accès distant) :
//  - serveur local injoignable au lancement → « Passer en Distant » → licence, connexion, chiffres de l'accueil et
//    modules sur le distant ; RIEN n'est envoyé au local après le changement ;
//  - retour en local depuis la pastille de l'accueil : les requêtes repartent vers le local ; la session du distant
//    n'y vaut rien → « session expirée » → connexion sur le local, sans boucle ni double envoi ;
//  - adresse changée dans la configuration : la requête suivante part vers la nouvelle adresse.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/serveur_injoignable_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:provider/provider.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final local = FauxServeurPrestige();
final distant = FauxServeurPrestige();
const hoteDistant = 'distant.invalid';

/// Hôtes visés par chaque requête de l'application, dans l'ordre.
final hotes = <String>[];

/// Client de l'application : « distant.invalid » → [distant], tout le reste → [local].
http.Client deuxServeurs() {
  final l = local.clientMemoire(), d = distant.clientMemoire();
  return MockClient((req) async {
    hotes.add(req.url.host);
    final c = req.url.host == hoteDistant ? d : l;
    final copie = http.Request(req.method, req.url)
      ..headers.addAll(req.headers)
      ..bodyBytes = req.bodyBytes;
    return http.Response.fromStream(await c.send(copie));
  });
}

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

Future<void> laisser(WidgetTester tester, {int dixiemes = 30}) async {
  for (var i = 0; i < dixiemes; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> seConnecter(WidgetTester tester) async {
  await pomper(tester, () => find.byKey(const Key('connexion_se_connecter')).evaluate().isNotEmpty, raison: 'connexion', max: 100);
  await laisser(tester, dixiemes: 5);
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
  await tester.tap(find.byKey(const Key('connexion_se_connecter')));
  await pomper(tester, () => find.byType(AccueilNouveau).evaluate().isNotEmpty, raison: 'accueil');
  await laisser(tester);
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await local.demarrer();
  });
  tearDownAll(local.arreter);
  setUp(() {
    for (final s in [local, distant]) {
      s
        ..installerRoutesParDefaut()
        ..controlerSession = true
        ..coupe = false
        ..oublierRequetes();
      donneesAccueil(s);
    }
    hotes.clear();
    preparerNouvelle(local, p: Presentation.tableauDeBord, prefs: {'remote_ip': hoteDistant});
    ApiService.client = deuxServeurs();
  });

  testWidgets('local injoignable au lancement → « Passer en Distant » → tout passe par le distant, rien vers le local', (tester) async {
    telephone(tester);
    local.coupe = true;
    await lancerApplication(tester);
    await pomper(tester, () => find.byType(ServeurInjoignableScreen).evaluate().isNotEmpty, raison: 'local injoignable', max: 100);
    expect(find.textContaining('Serveur local'), findsWidgets, reason: 'adresse du serveur local rappelée');
    await tester.tap(find.byKey(const Key('injoignable_basculer')));
    await seConnecter(tester);
    expect(distant.recues('/licence/find'), hasLength(1), reason: 'licence lue sur le distant');
    expect(distant.recues(AppConstants.authEndpoint), hasLength(1));
    expect(distant.recues('/recap/dashboard'), hasLength(1), reason: 'chiffres du jour lus sur le distant');
    expect(find.text('Serveur distant'), findsOneWidget, reason: 'pastille de l\'accueil');
    final n = hotes.lastIndexWhere((h) => h != hoteDistant);
    expect(hotes.sublist(n + 1).every((h) => h == hoteDistant), isTrue, reason: 'après le changement, plus rien vers le local');
    expect(local.requetes, isEmpty, reason: 'serveur local coupé : aucune requête ne l\'a atteint');
    await fermerApplication(tester);
  });

  testWidgets('distant → local par la pastille : requêtes vers le local, session du distant refusée → connexion sur le local', (tester) async {
    telephone(tester);
    preparerNouvelle(local, p: Presentation.tableauDeBord, prefs: {'remote_ip': hoteDistant, 'use_local_ip': false});
    await lancerApplication(tester);
    await seConnecter(tester);
    expect(distant.recues(AppConstants.authEndpoint), hasLength(1));
    expect(local.requetes, isEmpty);
    final avant = distant.requetes.length;

    // Pastille « Serveur distant » → local : les chiffres sont relus sur le local, où la session du distant n'existe pas.
    await tester.tap(find.text('Serveur distant'));
    await laisser(tester);
    expect(local.recues('/recap/dashboard'), isNotEmpty, reason: 'chiffres demandés au local');
    expect(distant.requetes.length, avant, reason: 'plus rien vers le distant');
    await pomper(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'session expirée → connexion');
    await laisser(tester);
    expect(find.text('Votre session a expiré. Reconnectez-vous pour continuer.'), findsOneWidget, reason: 'motif expliqué');
    expect(find.textContaining('injoignable'), findsNothing, reason: 'pas un faux message réseau');
    await tester.tap(find.text('OK'));
    await laisser(tester, dixiemes: 5);
    await seConnecter(tester);
    expect(local.recues(AppConstants.authEndpoint), hasLength(1), reason: 'connexion sur le local');
    expect(find.text('Serveur local'), findsOneWidget);
    expect(local.recues('/recap/dashboard').last.sessionEnvoyee, local.derniereSession, reason: 'session du local utilisée');
    expect(distant.requetes.length, avant);
    await fermerApplication(tester);
  });

  testWidgets('adresse changée dans la configuration : la requête suivante part vers la nouvelle adresse', (tester) async {
    telephone(tester);
    await lancerApplication(tester);
    await seConnecter(tester);
    final ctx = tester.element(find.byType(AccueilNouveau));
    final ip = Provider.of<IpConfigProvider>(ctx, listen: false);
    expect(hotes.last, '127.0.0.1');
    await tester.runAsync(() => ip.updateSettings(hoteDistant, ip.remoteIp, ip.port, ip.sessionTimeout, ip.appName));
    await tester.pump();
    final avant = local.requetes.length;
    await tester.tap(find.byTooltip('Actualiser les chiffres'));
    await laisser(tester);
    expect(hotes.last, hoteDistant, reason: 'nouvelle adresse utilisée');
    expect(local.requetes.length, avant, reason: 'ancienne adresse abandonnée');
    await fermerApplication(tester);
  });
}
