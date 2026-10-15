// Tests d'intégration des services (ApiService, AuthProvider, LicenceProvider, PresencesApi) contre le faux
// serveur Prestige joint en HTTP RÉEL sur 127.0.0.1 : construction des adresses depuis la configuration,
// cookie de session JSESSIONID, natures d'échec (réseau, délai, 5xx, 401, 403, 404, refus métier, réponse
// illisible), règle « serveur injoignable ≠ problème de licence ».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/presences/presences_api.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';

final serveur = FauxServeurPrestige();

/// Contexte avec les providers de l'application, configurés pour viser le faux serveur.
Future<({BuildContext ctx, AuthProvider auth, LicenceProvider licence})> monter(WidgetTester tester) async {
  final auth = AuthProvider();
  final licence = LicenceProvider();
  final ctx = await monterAvecProviders(tester, auth: auth, licence: licence);
  return (ctx: ctx, auth: auth, licence: licence);
}

/// Exécute un appel réseau réel ; renvoie le résultat ou l'erreur levée.
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

Matcher echecDeNature(NatureErreur nature, {int? code}) => isA<ApiLoadException>()
    .having((e) => e.nature, 'nature', nature)
    .having((e) => e.code, 'code', code ?? anything);

Future<void> connecter(WidgetTester tester, ({BuildContext ctx, AuthProvider auth, LicenceProvider licence}) app) async {
  final erreur = await appel(tester, () => app.auth.login(app.ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false));
  expect(erreur, isNull);
  expect(app.auth.isLoggedIn, isTrue);
}

void main() {
  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerTelephone(serveur);
    await ApiService().clearSessionCookie();
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..reponseSansSession = ((_) => ReponseFausse.sessionExpiree())
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
  });

  group('ApiService : adresses', () {
    testWidgets('GET : adresse issue de la configuration (hôte, port, application, /api/v1) et paramètres', (tester) async {
      final app = await monter(tester);
      serveur.controlerSession = false;
      serveur.quand('/common/rayons', ReponseFausse.json({'data': [{'id': 'R1', 'libelle': 'RAYON FICTIF'}], 'total': 1}));
      final rayons = await appel(tester, () => ApiService().getRayons(app.ctx));
      expect(rayons, isA<List>().having((l) => l.length, 'taille', 1));
      final r = serveur.recues('/common/rayons').single;
      expect(r.versionApi, 'v1');
      expect(r.methode, 'GET');
      expect(r.parametres, {'limit': '9999', 'page': '1', 'start': '0'});
    });

    testWidgets('GET v3 (statistiques TVA) : même serveur, /api/v3', (tester) async {
      final app = await monter(tester);
      serveur.controlerSession = false;
      await appel(tester, () => ApiService().getV3(app.ctx, '/tvas', queryParams: {'dtStart': '2026-10-01'}));
      expect(serveur.recues('/tvas').single.versionApi, 'v3');
    });

    testWidgets('liste vide du serveur : liste vide, jamais une erreur', (tester) async {
      final app = await monter(tester);
      serveur.controlerSession = false;
      final r = await appel(tester, () => ApiService().getEtatStockArticles(app.ctx, query: 'rien'));
      expect(r, {'total': 0, 'data': isEmpty});
    });

    testWidgets('accents : la réponse UTF-8 est décodée correctement', (tester) async {
      final app = await monter(tester);
      serveur.controlerSession = false;
      serveur.quand('/x', ReponseFausse.json({'libelle': 'Crème hydratante à l\'aloé'}));
      expect(await appel(tester, () => ApiService().get(app.ctx, '/x')), {'libelle': 'Crème hydratante à l\'aloé'});
    });
  });

  group('Connexion et cookie de session', () {
    testWidgets('connexion : JSESSIONID de la réponse renvoyé ensuite ; déconnexion : plus de cookie', (tester) async {
      final app = await monter(tester);
      await connecter(tester, app);
      expect(app.auth.user?.fullName, DonneesFictives.nomComplet);
      final auth = serveur.recues('/user/auth').single;
      expect(auth.json, {'login': DonneesFictives.identifiant, 'password': DonneesFictives.motDePasse});
      // L'officine est chargée avec la session.
      expect(serveur.recues('/officine').last.sessionEnvoyee, serveur.derniereSession);
      expect(app.auth.officine?.nomComplet, DonneesFictives.nomOfficine);

      expect(await appel(tester, () => ApiService().get(app.ctx, '/fournisseurs')), isA<List>());
      expect(serveur.recues('/fournisseurs').single.sessionEnvoyee, serveur.derniereSession);

      await appel(tester, () => app.auth.logout(app.ctx));
      expect(serveur.recues('/user/logout').single.sessionEnvoyee, serveur.derniereSession);
      expect(app.auth.isLoggedIn, isFalse);
      serveur.controlerSession = false;
      await appel(tester, () => ApiService().get(app.ctx, '/apres'));
      expect(serveur.recues('/apres').single.cookie, isNull);
    });

    testWidgets('nouvelle connexion : le serveur renouvelle la session, seul le nouveau cookie est envoyé', (tester) async {
      final app = await monter(tester);
      await connecter(tester, app);
      final premiere = serveur.derniereSession;
      await connecter(tester, app);
      expect(serveur.derniereSession, isNot(premiere));
      expect(serveur.recues('/user/auth').last.sessionEnvoyee, premiere, reason: 'l\'ancien cookie part avec la demande');
      await appel(tester, () => ApiService().get(app.ctx, '/fournisseurs'));
      expect(serveur.recues('/fournisseurs').single.sessionEnvoyee, serveur.derniereSession);
    });

    testWidgets('plusieurs Set-Cookie dans la réponse de connexion : JSESSIONID gardé', (tester) async {
      final app = await monter(tester);
      serveur.route('/user/auth', (_) {
        return ReponseFausse.json(DonneesFictives.utilisateur(),
            entetes: {'set-cookie': 'preference=fr; Path=/\nJSESSIONID=fictif-multi; Path=/prestige; HttpOnly'});
      }, methode: 'POST');
      serveur.controlerSession = false;
      await appel(tester, () => app.auth.login(app.ctx, 'x', 'y', false));
      await appel(tester, () => ApiService().get(app.ctx, '/fournisseurs'));
      expect(serveur.recues('/fournisseurs').single.cookie, 'JSESSIONID=fictif-multi');
    });

    testWidgets('identifiants refusés (200 {success:false}) : message du serveur, pas connecté', (tester) async {
      final app = await monter(tester);
      final message = await appel(tester, () => app.auth.login(app.ctx, DonneesFictives.identifiant, 'faux', false));
      expect(message, DonneesFictives.messageIdentifiantsIncorrects);
      expect(app.auth.isLoggedIn, isFalse);
      expect(app.auth.isLoading, isFalse);
    });

    testWidgets('serveur arrêté (connexion refusée) à la connexion : « Serveur injoignable » (3.10.3, cas 1)', (tester) async {
      final app = await monter(tester);
      await tester.runAsync(serveur.arreter);
      final message = await appel(tester, () => app.auth.login(app.ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false));
      expect(message, ApiLoadException.messageReseau);
    });

    testWidgets('« Rester connecté » : identifiant mémorisé, mot de passe dans le stockage sûr (pas en clair)', (tester) async {
      final app = await monter(tester);
      await appel(tester, () => app.auth.login(app.ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, true));
      final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
      expect(prefs.getString('saved_username'), DonneesFictives.identifiant);
      expect(prefs.containsKey('saved_password'), isFalse);
      expect([for (final k in prefs.getKeys()) '${prefs.get(k)}'], isNot(contains(DonneesFictives.motDePasse)));
    });
  });

  group('Session expirée', () {
    testWidgets('401 « Veuillez vous connecter » : échec « session » et déconnexion avec message', (tester) async {
      final app = await monter(tester);
      await connecter(tester, app);
      final messages = <String>[];
      final abo = app.auth.events.listen(messages.add);
      serveur.expirerSessions();
      final e = await appel(tester, () => ApiService().get(app.ctx, '/fournisseurs'));
      expect(e, echecDeNature(NatureErreur.session, code: 401));
      expect(app.auth.isLoggedIn, isFalse);
      await tester.pump();
      expect(messages, [AuthProvider.messageSessionExpiree]);
      // Pas d'« await » : l'annulation attend la zone à horloge simulée et ne se terminerait jamais ici.
      abo.cancel();
    });

    testWidgets('200 {success:false, message:"Veuillez vous connecter"} : même traitement', (tester) async {
      final app = await monter(tester);
      await connecter(tester, app);
      serveur.reponseSansSession = (_) => ReponseFausse.sessionExpireeEn200();
      serveur.expirerSessions();
      expect(await appel(tester, () => ApiService().get(app.ctx, '/fournisseurs')), echecDeNature(NatureErreur.session));
      expect(app.auth.isLoggedIn, isFalse);
    });
  });

  group('Natures d\'échec', () {
    Future<Object?> echec(WidgetTester tester, ReponseFausse reponse, {String route = '/officine'}) async {
      final app = await monter(tester);
      serveur.controlerSession = false;
      serveur.quand(route, reponse);
      return appel(tester, () => ApiService().get(app.ctx, route));
    }

    testWidgets('500 : erreur serveur avec le code, page technique jamais affichée', (tester) async {
      final e = await echec(tester, ReponseFausse.erreurServeur());
      expect(e, echecDeNature(NatureErreur.serveur, code: 500));
      expect('$e', contains('500'));
      expect('$e', isNot(contains('NullPointer')));
    });

    testWidgets('403 : droit manquant', (tester) async {
      expect(await echec(tester, ReponseFausse.texte('Forbidden', statut: 403)), echecDeNature(NatureErreur.droit, code: 403));
    });

    testWidgets('404 d\'une route de module (/officine répond) : demande refusée (code 404)', (tester) async {
      expect(await echec(tester, ReponseFausse.introuvable(), route: '/fournisseurs'), echecDeNature(NatureErreur.refus, code: 404));
    });

    testWidgets('404 d\'une route toujours présente (/officine) : Prestige pas déployé (3.10.3)', (tester) async {
      final e = await echec(tester, ReponseFausse.introuvable());
      expect(e, echecDeNature(NatureErreur.serveur, code: 404));
      expect((e as ApiLoadException).serveurIndisponible, isTrue);
    });

    testWidgets('réponse illisible (HTML en 200)', (tester) async {
      expect(await echec(tester, ReponseFausse.texte('<html>pas du JSON</html>')), echecDeNature(NatureErreur.reponse));
    });

    testWidgets('serveur arrêté : serveur injoignable', (tester) async {
      final app = await monter(tester);
      await tester.runAsync(serveur.arreter);
      final e = await appel(tester, () => ApiService().get(app.ctx, '/officine'));
      expect(e, echecDeNature(NatureErreur.reseau));
      expect('$e', ApiLoadException.messageReseau);
    });

    testWidgets('serveur qui ne répond pas : délai dépassé après 45 s', (tester) async {
      final app = await monter(tester);
      serveur.controlerSession = false;
      serveur.quand('/officine', ReponseFausse.sansReponse());
      Object? resultat;
      ApiService().get(app.ctx, '/officine').then((r) => resultat = r, onError: (Object e) => resultat = e);
      await stabiliser(tester, tours: 4); // la requête part
      expect(resultat, isNull);
      await tester.pump(ApiService.delaiGet + const Duration(seconds: 1));
      await tester.pump();
      expect(resultat, echecDeNature(NatureErreur.delai));
    });

    testWidgets('réponse lente mais dans les temps : reçue normalement', (tester) async {
      final app = await monter(tester);
      serveur.controlerSession = false;
      serveur.quand('/officine', ReponseFausse.json(DonneesFictives.officine()).apres(const Duration(milliseconds: 300)));
      expect(await appel(tester, () => ApiService().get(app.ctx, '/officine')), isA<List>());
    });
  });

  group('Licence : serveur injoignable ≠ problème de licence', () {
    Future<LicenceStatus> verifier(WidgetTester tester) async {
      final app = await monter(tester);
      await tester.runAsync(() => app.licence.checkLicence(app.ctx));
      return app.licence.status;
    }

    testWidgets('licence valide', (tester) async {
      expect(await verifier(tester), LicenceStatus.valid);
    });

    testWidgets('réponse vide du serveur : aucune licence', (tester) async {
      serveur.quand('/licence/find', ReponseFausse.vide());
      expect(await verifier(tester), LicenceStatus.notFound);
    });

    testWidgets('licence expirée', (tester) async {
      serveur.quand('/licence/find', ReponseFausse.json(DonneesFictives.licenceExpiree()));
      expect(await verifier(tester), LicenceStatus.expired);
    });

    testWidgets('serveur arrêté : erreur de connexion, JAMAIS « licence absente »', (tester) async {
      final app = await monter(tester);
      await tester.runAsync(serveur.arreter);
      await tester.runAsync(() => app.licence.checkLicence(app.ctx));
      expect(app.licence.status, LicenceStatus.error);
      expect(app.licence.dernierEchec?.issue, LicenceIssue.unreachable);
    });

    testWidgets('500 : erreur serveur ; 404 : Prestige absent ; HTML : réponse inattendue', (tester) async {
      final app = await monter(tester);
      final attendus = {
        ReponseFausse.erreurServeur(): LicenceIssue.serverError,
        ReponseFausse.introuvable(): LicenceIssue.appNotFound,
        ReponseFausse.texte('<html>autre application</html>'): LicenceIssue.unexpectedResponse,
      };
      for (final e in attendus.entries) {
        serveur.quand('/licence/find', e.key);
        final r = await appel(tester, () => ApiService().lookupLicence(app.ctx)) as LicenceLookup;
        expect(r.issue, e.value);
        expect(r.isConnectionProblem, isTrue);
      }
    });

    testWidgets('enregistrement d\'une clé : GET /licence/save/<clé encodée>', (tester) async {
      final app = await monter(tester);
      serveur.quand('/licence/save/CLE FICTIVE', ReponseFausse.json({'success': true}));
      final ok = await appel(tester, () => ApiService().registerLicence(app.ctx, 'CLE FICTIVE'));
      expect(ok, isTrue);
      expect(serveur.recues('/licence/save/CLE FICTIVE'), hasLength(1));
    });
  });

  group('Présences (routes /rh)', () {
    testWidgets('présence du jour et tableau lus depuis le serveur, avec la session', (tester) async {
      final app = await monter(tester);
      await connecter(tester, app);
      final jour = await appel(tester, () => const PresencesApi().presence(app.ctx, DateTime(2026, 10, 13)));
      expect(jour, isNot(isA<Exception>()));
      final r = serveur.recues('/rh/presence').single;
      expect(r.parametres['jour'], '2026-10-13');
      expect(r.sessionEnvoyee, serveur.derniereSession);
      final terminaux = await appel(tester, () => const PresencesApi().terminaux(app.ctx));
      expect(terminaux, isA<List>().having((l) => l.length, 'taille', 1));
    });

    testWidgets('droit RH absent (200 {success:false}) : message clair « droit »', (tester) async {
      final app = await monter(tester);
      await connecter(tester, app);
      serveur.quand('/rh/presence', ReponseFausse.json({'success': false, 'msg': 'Vous n\'avez pas accès aux ressources humaines.'}));
      final e = await appel(tester, () => const PresencesApi().presence(app.ctx, DateTime(2026, 10, 13)));
      expect(e, echecDeNature(NatureErreur.droit));
      expect('$e', PresencesApi.messageDroit);
      expect(app.auth.isLoggedIn, isTrue, reason: 'un droit manquant ne déconnecte pas');
    });
  });

  group('Fichiers', () {
    testWidgets('PDF : octets et nom de fichier ; page HTML à la place : refusée', (tester) async {
      final app = await monter(tester);
      serveur.controlerSession = false;
      serveur.quand('/export.pdf', ReponseFausse.octets('%PDF-1.4 fictif'.codeUnits, type: 'application/pdf',
          entetes: {'content-disposition': 'inline; filename=rapport_fictif.pdf'}));
      final f = await appel(tester, () => ApiService().getBytes(app.ctx, '/export.pdf')) as FichierTelecharge;
      expect(f.nom, 'rapport_fictif.pdf');
      expect(String.fromCharCodes(f.octets.take(4)), '%PDF');

      serveur.quand('/export.pdf', ReponseFausse.texte('<html>Erreur</html>'));
      expect(await appel(tester, () => ApiService().getBytes(app.ctx, '/export.pdf')), echecDeNature(NatureErreur.reponse));
    });
  });
}
