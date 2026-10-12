// Étape 1d : une panne n'est plus affichée comme une liste vide.
// ApiService distingue panne réseau / délai / erreur serveur 5xx / session expirée (401 → reconnexion) /
// droit manquant (403) / réponse illisible / vraie liste vide ; les écrans affichent « Chargement impossible »
// + « Réessayer » (mêmes widgets et textes que prestige_vente_app), et « Aucun … » seulement si le serveur
// a vraiment répondu une liste vide.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/main.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/screens/etat_stock_screen.dart';
import 'package:prestige_app/screens/suggestion_list_screen.dart';
import 'package:prestige_app/screens/suivi_peremption_screen.dart';
import 'package:prestige_app/screens/valorisation_screen.dart';
import 'package:prestige_app/screens/visualisation_bl_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/widgets/erreurs_chargement.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';

/// Comportement du serveur simulé.
enum Panne { aucune, reseau, delai, serveur500, session401, droit403, illisible }

Panne panne = Panne.aucune;
final appels = <String>[];

/// Réponses « normales » : listes vides (vraie absence de données) sauf indication contraire.
Map<String, String> reponses = {};

Future<http.Response> repondre(http.Request req) async {
  appels.add(req.url.path);
  switch (panne) {
    case Panne.reseau:
      throw const SocketException('Connection refused');
    case Panne.delai:
      return Completer<http.Response>().future; // ne répond jamais
    case Panne.serveur500:
      return http.Response('<html>NullPointerException</html>', 500);
    case Panne.session401:
      return http.Response('Veuillez vous connecter', 401);
    case Panne.droit403:
      return http.Response('Forbidden', 403);
    case Panne.illisible:
      return http.Response('<html>pas du JSON</html>', 200);
    case Panne.aucune:
      break;
  }
  if (req.url.path.endsWith('/user/auth')) {
    return http.Response('{"success":true,"str_LOGIN":"admin","str_FIRST_NAME":"Awa","str_LAST_NAME":"K"}', 200,
        headers: {'set-cookie': 'JSESSIONID=abc; Path=/prestige'});
  }
  for (final e in reponses.entries) {
    if (req.url.path.endsWith(e.key)) return http.Response(e.value, 200, headers: {'content-type': 'application/json; charset=utf-8'});
  }
  return http.Response('{"data":[],"total":0}', 200);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true});
    FlutterSecureStorage.setMockInitialValues({});
    panne = Panne.aucune;
    appels.clear();
    reponses = {};
    ApiService.client = MockClient(repondre);
    JournalApp.actif = false;
  });

  tearDown(() => ApiService.client = http.Client());

  group('ApiService : nature des échecs', () {
    Future<Object?> echec(WidgetTester tester, Future<Object?> Function(BuildContext) appel, {Duration attente = Duration.zero}) async {
      final ctx = await monterAvecProviders(tester);
      Object? erreur;
      Object? resultat;
      final f = appel(ctx).then((r) => resultat = r, onError: (Object e) => erreur = e);
      await tester.pump(attente);
      await tester.pump();
      await f;
      return erreur ?? resultat;
    }

    testWidgets('serveur injoignable', (tester) async {
      panne = Panne.reseau;
      final e = await echec(tester, (c) => ApiService().get(c, '/officine'));
      expect(e, isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.reseau));
      expect('$e', ApiLoadException.messageReseau);
    });

    testWidgets('délai dépassé (45 s)', (tester) async {
      panne = Panne.delai;
      final e = await echec(tester, (c) => ApiService().get(c, '/officine'), attente: const Duration(seconds: 46));
      expect(e, isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.delai));
      expect('$e', contains('trop de temps'));
    });

    testWidgets('erreur serveur 5xx : code donné, page HTML jamais affichée', (tester) async {
      panne = Panne.serveur500;
      final e = await echec(tester, (c) => ApiService().get(c, '/officine'));
      expect(e, isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.serveur));
      expect('$e', contains('500'));
      expect('$e', isNot(contains('NullPointer')));
    });

    testWidgets('droit manquant (403)', (tester) async {
      panne = Panne.droit403;
      final e = await echec(tester, (c) => ApiService().get(c, '/officine'));
      expect(e, isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.droit));
      expect('$e', contains('Accès refusé'));
    });

    testWidgets('session expirée (401) : rappel de déconnexion', (tester) async {
      panne = Panne.session401;
      var rappels = 0;
      final e = await echec(tester, (c) => ApiService().get(c, '/officine', onSessionInvalid: () => rappels++));
      expect(e, isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.session));
      expect(rappels, 1);
    });

    testWidgets('réponse illisible', (tester) async {
      panne = Panne.illisible;
      final e = await echec(tester, (c) => ApiService().get(c, '/officine'));
      expect(e, isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.reponse));
    });

    testWidgets('« Session invalide » n\'est plus ré-emballé dans « Une erreur inconnue… »', (tester) async {
      panne = Panne.session401;
      final e = await echec(tester, (c) => ApiService().post(c, '/caisse/fetch-tickez', {}));
      expect('$e', ApiLoadException.messageSession);
    });

    testWidgets('listes des filtres : un échec lève une exception (≠ liste vide) ; liste vide = vraie absence', (tester) async {
      for (final appel in <Future<Object?> Function(BuildContext)>[
        (c) => ApiService().getRayons(c),
        (c) => ApiService().getGrossistes(c),
        (c) => ApiService().getUsers(c),
        (c) => ApiService().getGroupeGrossistes(c),
        (c) => ApiService().getBonLivraisons(c),
        (c) => ApiService().getSuiviPeremption(c),
        (c) => ApiService().getEtatStockArticles(c),
      ]) {
        panne = Panne.reseau;
        final e = await echec(tester, appel);
        expect(e, isA<ApiLoadException>());
        expect('$e', contains('non chargés'));
        panne = Panne.aucune;
        final ok = await echec(tester, appel);
        expect(ok, isNot(isA<ApiLoadException>()));
      }
      expect(await echec(tester, (c) => ApiService().getRayons(c)), isEmpty);
    });
  });

  group('Écrans : erreur ≠ liste vide', () {
    Future<void> attendre(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('Visualisation BL : serveur injoignable → « Chargement impossible » + Réessayer → vraie liste vide', (tester) async {
      panne = Panne.reseau;
      await monterAvecProviders(tester, ecran: const VisualisationBlScreen());
      await attendre(tester);
      expect(find.text('Chargement impossible'), findsOneWidget);
      expect(find.textContaining('Serveur injoignable'), findsWidgets);
      expect(find.text('Aucun Bon de Livraison trouvé'), findsNothing);
      // Filtres (grossistes, groupes, opérateurs) non chargés : bandeau séparé.
      expect(find.byType(LoadErrorBanner), findsOneWidget);

      panne = Panne.aucune;
      await tester.tap(find.descendant(of: find.byType(LoadErrorView), matching: find.text('Réessayer')));
      await attendre(tester);
      expect(find.text('Chargement impossible'), findsNothing);
      expect(find.text('Aucun Bon de Livraison trouvé'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(LoadErrorBanner), matching: find.text('Réessayer')));
      await attendre(tester);
      expect(find.byType(LoadErrorBanner), findsNothing);
    });

    testWidgets('Suivi péremption : erreur serveur 500 ≠ « Aucun produit périmé »', (tester) async {
      panne = Panne.serveur500;
      await monterAvecProviders(tester, ecran: const SuiviPeremptionScreen());
      await attendre(tester);
      expect(find.text('Chargement impossible'), findsOneWidget);
      expect(find.textContaining('code 500'), findsOneWidget);
      expect(find.text('Aucun produit périmé ou proche péremption trouvé.'), findsNothing);
      panne = Panne.aucune;
      await tester.tap(find.text('Réessayer'));
      await attendre(tester);
      expect(find.text('Aucun produit périmé ou proche péremption trouvé.'), findsOneWidget);
    });

    testWidgets('État de stock : filtres non chargés (bandeau) ; recherche en panne ≠ « Aucun résultat trouvé »', (tester) async {
      panne = Panne.delai;
      await monterAvecProviders(tester, ecran: const EtatStockScreen());
      await tester.pump(const Duration(seconds: 46));
      await attendre(tester);
      expect(find.byType(LoadErrorBanner), findsOneWidget);
      expect(find.textContaining('trop de temps'), findsOneWidget);

      panne = Panne.reseau;
      await tester.tap(find.text('APPLIQUER FILTRES'));
      await attendre(tester);
      expect(find.text('Chargement impossible'), findsOneWidget);
      expect(find.text('Aucun résultat trouvé'), findsNothing);

      panne = Panne.aucune;
      await tester.tap(find.descendant(of: find.byType(LoadErrorView), matching: find.text('Réessayer')));
      await attendre(tester);
      expect(find.text('Aucun résultat trouvé'), findsOneWidget);
    });

    testWidgets('écran à mixin (Suggestions) : panne → Réessayer ; liste vide → message d\'absence', (tester) async {
      panne = Panne.reseau;
      await monterAvecProviders(tester, ecran: const SuggestionListScreen());
      await attendre(tester);
      expect(find.text('Chargement impossible'), findsOneWidget);
      expect(find.text('Aucune suggestion de commande disponible.'), findsNothing);
      panne = Panne.aucune;
      await tester.tap(find.text('Réessayer'));
      await attendre(tester);
      expect(find.text('Aucune suggestion de commande disponible.'), findsOneWidget);
    });

    testWidgets('écran défilant (Valorisation) : l\'erreur s\'affiche sans casser la mise en page', (tester) async {
      panne = Panne.droit403;
      await monterAvecProviders(tester, ecran: const ValorisationScreen());
      await tester.tap(find.text('Afficher la Valorisation'));
      await attendre(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Chargement impossible'), findsOneWidget);
      expect(find.textContaining('Accès refusé'), findsOneWidget);
    });
  });

  testWidgets('session expirée sur un écran : retour à la connexion avec un message', (tester) async {
    final auth = AuthProvider();
    late BuildContext racine;
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => IpConfigProvider()),
        ChangeNotifierProvider(create: (_) => LicenceProvider()),
        Provider(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        home: AppLifecycleObserver(
          child: Builder(builder: (c) {
            racine = c;
            return Consumer<AuthProvider>(builder: (_, a, __) => Text(a.isLoggedIn ? 'ACCUEIL' : 'CONNEXION'));
          }),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 3));
    await auth.login(racine, 'admin', 'x', false);
    await tester.pump();
    expect(find.text('ACCUEIL'), findsOneWidget);

    Navigator.of(racine).push(MaterialPageRoute(builder: (_) => const SuggestionListScreen()));
    panne = Panne.session401;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(auth.isLoggedIn, isFalse);
    expect(find.byType(SuggestionListScreen), findsNothing, reason: 'écrans ouverts fermés');
    expect(find.text('CONNEXION'), findsOneWidget);
    expect(find.text(AuthProvider.messageSessionExpiree), findsOneWidget);
  });
}

