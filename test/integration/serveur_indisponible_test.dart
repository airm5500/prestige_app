// Connexion et modules quand Prestige est injoignable ou pas déployé (3.10.2, revu en 3.10.3 : deux cas du
// pharmacien), contre le faux serveur (vrai réseau local) :
//  - connexion : 404 de POST /user/auth, 502 / 503 / 504 → « Serveur indisponible : … » (cas 2), pas connecté, une
//    seule requête ; Prestige arrêté (connexion refusée) → « Serveur injoignable… » (cas 1) ; mot de passe faux, 500,
//    réponse illisible inchangés ;
//  - modules : 404 d'une route → vérification par GET /officine (une requête, seulement sur ce 404) : /officine répond
//    → 404 d'origine (métier ou serveur ancien) ; /officine en 404 ou 503 → « Serveur indisponible » ; 503 d'un
//    module → « Serveur indisponible » sans vérification ; fonctionnement normal : AUCUNE requête /officine ;
//  - recherche « contient » : repli « serveur ancien » (/info) sur un vrai 404, jamais quand Prestige n'est pas déployé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/recherche_produit_donnees.dart';
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

  testWidgets('404 MÉTIER d\'un module, /officine répond : 404 d\'origine ; UNE vérification /officine', (tester) async {
    final app = await monter(tester);
    serveur.controlerSession = false;
    serveur.quand('/analyse-commande/produit/INCONNU', ReponseFausse.introuvable(), methode: 'GET');
    serveur.oublierRequetes();
    final e = await appel(tester, () => ApiService().get(app.ctx, '/analyse-commande/produit/INCONNU'));
    expect(e, isA<ApiLoadException>());
    expect((e as ApiLoadException).message, 'Le serveur a refusé la demande (code 404).');
    expect(e.serveurIndisponible, isFalse);
    expect(serveur.recues(AppConstants.officineEndpoint), hasLength(1), reason: 'vérification seulement sur ce 404');
  });

  for (final (cas, officine) in [('404', ReponseFausse.introuvable()), ('503', ReponseFausse.erreurServeur(statut: 503))]) {
    testWidgets('404 d\'un module et /officine en $cas : Prestige pas déployé → « Serveur indisponible »', (tester) async {
      final app = await monter(tester);
      serveur.controlerSession = false;
      serveur
        ..quand('/analyse-commande/tableau', ReponseFausse.introuvable(), methode: 'GET')
        ..quand(AppConstants.officineEndpoint, officine, methode: 'GET');
      final e = await appel(tester, () => ApiService().get(app.ctx, '/analyse-commande/tableau'));
      expect((e as ApiLoadException).serveurIndisponible, isTrue);
      expect(e.message, ApiLoadException.messageServeurIndisponible);
    });
  }

  testWidgets('503 d\'un module : « Serveur indisponible » sans vérification ; réponses normales : aucune requête /officine', (tester) async {
    final app = await monter(tester);
    serveur.controlerSession = false;
    serveur.quand('/analyse-commande/tableau', ReponseFausse.erreurServeur(statut: 503), methode: 'GET');
    serveur.oublierRequetes();
    final e = await appel(tester, () => ApiService().get(app.ctx, '/analyse-commande/tableau'));
    expect((e as ApiLoadException).serveurIndisponible, isTrue);
    serveur.installerRoutesParDefaut();
    serveur.controlerSession = false;
    await appel(tester, () => ApiService().get(app.ctx, '/fournisseurs'));
    await appel(tester, () => ApiService().get(app.ctx, '/fournisseurs'));
    expect(serveur.recues(AppConstants.officineEndpoint), isEmpty, reason: 'aucune requête de plus en fonctionnement normal');
  });

  testWidgets('recherche « contient » : vrai 404 (serveur ancien) → repli /info ; Prestige pas déployé → message, pas de repli',
      (tester) async {
    final app = await monter(tester);
    serveur.controlerSession = false;
    serveur.quand(RechercheProduit.route, ReponseFausse.introuvable(), methode: 'GET');
    final r = await appel(tester, () => RechercheProduit.rechercher(app.ctx, 'para'));
    expect(r, isA<ResultatRechercheProduit>());
    expect((r as ResultatRechercheProduit).contient, isFalse, reason: 'serveur ancien : « commence par »');
    expect(serveur.recues(AppConstants.infoEndpoint), hasLength(1));

    serveur.oublierRequetes();
    serveur.quand(AppConstants.officineEndpoint, ReponseFausse.introuvable(), methode: 'GET');
    final e = await appel(tester, () => RechercheProduit.rechercher(app.ctx, 'para'));
    expect((e as ApiLoadException).serveurIndisponible, isTrue);
    expect(serveur.recues(AppConstants.infoEndpoint), isEmpty, reason: 'jamais conclu « serveur ancien »');
  });

  testWidgets('connexion avec Prestige arrêté (connexion refusée) : « Serveur injoignable » (cas 1)', (tester) async {
    final app = await monter(tester);
    await tester.runAsync(serveur.arreter);
    expect(await seConnecter(tester, app), ApiLoadException.messageReseau);
  });

  testWidgets('/officine en 404 après une connexion réussie : connecté, aucune erreur', (tester) async {
    final app = await monter(tester);
    serveur.quand(AppConstants.officineEndpoint, ReponseFausse.introuvable(), methode: 'GET');
    expect(await seConnecter(tester, app), isNull);
    expect(app.auth.isLoggedIn, isTrue);
    expect(app.auth.errorMessage, isNull);
  });
}
