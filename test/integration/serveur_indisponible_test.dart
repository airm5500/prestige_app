// Connexion pendant un redéploiement de Prestige (3.10.2), AuthProvider.login contre le faux serveur (vrai réseau
// local) : 404 de POST /user/auth, 502 / 503 / 504, connexion refusée → « Serveur indisponible, veuillez réessayer. »,
// pas connecté, une seule requête (aucune relance automatique) ; mot de passe faux, 500 et réponse illisible gardent
// leur message ; 404 d'une route MÉTIER (hors connexion) inchangé ; /officine en 404 après une connexion réussie :
// connecté, aucune erreur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';

final serveur = FauxServeurPrestige();

Future<({BuildContext ctx, AuthProvider auth})> monter(WidgetTester tester) async {
  final auth = AuthProvider();
  final ctx = await monterAvecProviders(tester, auth: auth, licence: LicenceProvider());
  return (ctx: ctx, auth: auth);
}

Future<Object?> appel(WidgetTester tester, Future<Object?> Function() f) async {
  Object? resultat;
  await tester.runAsync(() async {
    try {
      resultat = await f();
    } catch (e) {
      resultat = e;
    }
  });
  return resultat;
}

Future<Object?> seConnecter(WidgetTester tester, ({BuildContext ctx, AuthProvider auth}) app, {String mdp = DonneesFictives.motDePasse}) =>
    appel(tester, () => app.auth.login(app.ctx, DonneesFictives.identifiant, mdp, false));

void main() {
  setUp(() async {
    await serveur.demarrer();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..oublierRequetes();
    preparerTelephone(serveur);
    utiliserReseauReel();
  });
  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
  });

  for (final (cas, reponse) in [
    ('404 (redéploiement)', ReponseFausse.introuvable()),
    ('502', ReponseFausse.erreurServeur(statut: 502)),
    ('503', ReponseFausse.erreurServeur(statut: 503)),
    ('504', ReponseFausse.erreurServeur(statut: 504)),
  ]) {
    testWidgets('connexion en $cas : « Serveur indisponible », pas connecté, une seule requête', (tester) async {
      final app = await monter(tester);
      serveur.quand(AppConstants.authEndpoint, reponse, methode: 'POST');
      expect(await seConnecter(tester, app), ApiLoadException.messageServeurIndisponible);
      expect(app.auth.isLoggedIn, isFalse);
      expect(serveur.recues(AppConstants.authEndpoint), hasLength(1), reason: 'aucune relance automatique');
      // Prestige revenu : la connexion suivante réussit.
      serveur.installerRoutesParDefaut();
      expect(await seConnecter(tester, app), isNull);
      expect(app.auth.isLoggedIn, isTrue);
    });
  }

  testWidgets('autres échecs : messages inchangés (mot de passe faux, 500, réponse illisible)', (tester) async {
    final app = await monter(tester);
    expect(await seConnecter(tester, app, mdp: 'faux'), DonneesFictives.messageIdentifiantsIncorrects);
    serveur.quand(AppConstants.authEndpoint, ReponseFausse.erreurServeur(), methode: 'POST');
    expect(await seConnecter(tester, app), contains('code 500'));
    serveur.quand(AppConstants.authEndpoint, ReponseFausse.texte('{"success":tr', type: 'application/json'), methode: 'POST');
    expect(await seConnecter(tester, app), ApiLoadException.messageReponse);
    expect(app.auth.isLoggedIn, isFalse);
  });

  testWidgets('404 MÉTIER d\'une route de module : inchangé (« refusé, code 404 »), pas « Serveur indisponible »', (tester) async {
    final app = await monter(tester);
    serveur.controlerSession = false;
    serveur.quand('/analyse-commande/produit/INCONNU', ReponseFausse.introuvable(), methode: 'GET');
    final e = await appel(tester, () => ApiService().get(app.ctx, '/analyse-commande/produit/INCONNU'));
    expect(e, isA<ApiLoadException>());
    expect((e as ApiLoadException).message, 'Le serveur a refusé la demande (code 404).');
  });

  testWidgets('/officine en 404 après une connexion réussie : connecté, aucune erreur', (tester) async {
    final app = await monter(tester);
    serveur.quand(AppConstants.officineEndpoint, ReponseFausse.introuvable(), methode: 'GET');
    expect(await seConnecter(tester, app), isNull);
    expect(app.auth.isLoggedIn, isTrue);
    expect(app.auth.errorMessage, isNull);
  });
}
