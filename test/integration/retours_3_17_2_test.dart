// 3.17.2 — tableau-bord/version exige une session (réponse du serveur du 21/11 aux retours des demandes 67 et 68,
// docs/notices/REPONSE_RETOUR_DEMANDES67_68_2026-11-20.md §6) : sans session, elle répond 200
// { success: false, msg: <message de déconnexion> }, sans version ni routes. Ce n'est PAS un serveur antérieur.
//  - success false (session expirée ou autre message), réponse qui n'est pas un objet, « routes » illisible, 401,
//    403, 5xx, coupure, délai : rien n'est retenu ni changé, aucune nouvelle requête dans la même session (⟳ compris),
//    nouvel essai à la session suivante ;
//  - success true sans routes : serveur antérieur retenu 24 h (puis relu) ;
//  - success true avec routes : routes annoncées.
//  - « Veuillez vous connecter » (msg) : retour à la connexion comme pour les autres routes du tableau de bord.
// Faux serveur en mémoire, horloge simulée, données fictives.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/routes_serveur.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/donnees_3_17_1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';
import 'retours_3_10_0_test.dart' show demonter, pomper, serveur;
import 'retours_3_16_0_test.dart' show cle, maintenant;
import 'retours_3_17_1_test.dart' show ecran, monterHote, nouvelleSession, racine;

/// Réponse de tableau-bord/version sans session (TableauBordRessource.deconnecte du serveur).
final deconnecte = {'success': false, 'msg': 'Veuillez vous connecter'};

void main() {
  late int sessionsExpirees;
  late VoidCallback? avant;

  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    serveur.installerRoutesParDefaut();
    RoutesServeur.oublierSession();
    RoutesServeur.horloge = DateTime.now;
    sessionsExpirees = 0;
    avant = ApiService.surSessionExpiree;
  });
  tearDown(() {
    ApiService.surSessionExpiree = avant;
    RoutesServeur.horloge = DateTime.now;
  });

  /// Accueil monté, puis le retour à la connexion (AuthProvider, abonné à [ApiService.surSessionExpiree]) est
  /// COMPTÉ au lieu d'être fait : l'accueil reste affiché pour la suite du test.
  Future<void> monter(WidgetTester tester) async {
    await monterHote(tester, hauteur: 3000);
    Provider.of<AuthProvider>(tester.element(find.byType(Scaffold).first), listen: false); // provider créé (paresseux)
    expect(ApiService.surSessionExpiree, isNotNull, reason: 'mécanisme de reconnexion de l\'application en place');
    ApiService.surSessionExpiree = () => sessionsExpirees++;
  }

  int n(String chemin) => serveur.recues(chemin).length;
  List<int> compte() => [n('/tableau-bord/tva'), n('/tvas'), n(RoutesServeur.route)];

  /// Nouvelle session (reconnexion) et ouverture de l'accueil.
  Future<void> session(WidgetTester tester, {Duration attente = Duration.zero}) async {
    ecran.value = null;
    await pomper(tester, 2);
    nouvelleSession();
    serveur.oublierRequetes();
    ecran.value = Scaffold(body: AccueilTableauPrestige(maintenant: () => maintenant, memoire: MemoireTableauBord()));
    await pomper(tester, 15);
    if (attente > Duration.zero) {
      await tester.pump(attente);
      await pomper(tester, 5);
    }
  }

  /// ⟳ dans la même session.
  Future<void> actualiser(WidgetTester tester) async {
    serveur.oublierRequetes();
    await tester.tap(cle('tableau_bord_actualiser'));
    await pomper(tester, 10);
  }

  Future<Map<String, Object?>?> retenu(WidgetTester tester) async {
    final p = await tester.runAsync(SharedPreferences.getInstance);
    final j = jsonDecode(p!.getString(RoutesServeur.cle) ?? '{}') as Map;
    return (j[racine(tester)] as Map?)?.cast<String, Object?>();
  }

  Future<void> retenir(WidgetTester tester, Map<String, Object?> etat) async {
    final p = await tester.runAsync(SharedPreferences.getInstance);
    await tester.runAsync(() => p!.setString(RoutesServeur.cle, jsonEncode({racine(tester): etat})));
  }

  void version(ReponseFausse r) => serveur.quand(RoutesServeur.route, r, methode: 'GET');

  group('tableau-bord/version sans session ({ success: false, msg })', () {
    testWidgets('session expirée : rien retenu ni changé, retour à la connexion, aucune requête de plus (⟳), relue après reconnexion', (tester) async {
      Donnees3171.installer(serveur, ServeurOfficine.retour);
      await monter(tester);
      // Version sans routes lue il y a plus de 24 h : relue après le succès de /tableau-bord/tva.
      final ancien = {'sansRoutesLe': DateTime.now().subtract(const Duration(hours: 30)).millisecondsSinceEpoch};
      await retenir(tester, ancien);
      version(ReponseFausse.json(deconnecte));
      await session(tester);
      expect(compte(), [1, 0, 1]);
      expect(await retenu(tester), ancien, reason: 'session expirée ≠ serveur antérieur : état retenu inchangé');
      expect(sessionsExpirees, 1, reason: 'même retour à la connexion que les autres routes du tableau de bord');
      await actualiser(tester);
      expect(compte(), [1, 0, 0], reason: 'pas de nouvelle lecture dans la même session (aucune boucle)');
      expect(await retenu(tester), ancien);

      // Reconnexion : la lecture est refaite, la réponse cette fois connue est retenue.
      Donnees3171.installer(serveur, ServeurOfficine.retour);
      await session(tester);
      expect(compte(), [1, 0, 1]);
      expect((await retenu(tester))!['routes'], ['ca-credit', 'tva']);
      expect((await retenu(tester))!.containsKey('sansRoutesLe'), isFalse);
      await session(tester);
      expect(compte(), [1, 0, 0], reason: 'routes connues : plus de lecture');
      await demonter(tester);
    });

    testWidgets('success false avec un autre message : rien retenu, pas de déconnexion, nouvel essai à la session suivante', (tester) async {
      Donnees3171.installer(serveur, ServeurOfficine.initial);
      await monter(tester);
      version(ReponseFausse.json({'success': false, 'msg': 'Session terminée, reconnectez-vous'}));
      await session(tester);
      expect(compte(), [1, 0, 1]);
      expect(await retenu(tester), isNull);
      expect(sessionsExpirees, 0);
      await actualiser(tester);
      expect(n(RoutesServeur.route), 0);

      // Session suivante : serveur antérieur (success true sans routes) → retenu 24 h.
      Donnees3171.installer(serveur, ServeurOfficine.initial);
      await session(tester);
      expect(compte(), [1, 0, 1]);
      expect((await retenu(tester))!.keys, ['sansRoutesLe']);
      await demonter(tester);
    });
  });

  group('success true', () {
    testWidgets('sans routes : serveur antérieur retenu 24 h (aucune relecture), relu passé ce délai', (tester) async {
      Donnees3171.installer(serveur, ServeurOfficine.initial);
      await monter(tester);
      var horloge = DateTime.now();
      RoutesServeur.horloge = () => horloge;
      await session(tester);
      expect(compte(), [1, 0, 1]);
      expect((await retenu(tester))!['sansRoutesLe'], horloge.millisecondsSinceEpoch);
      horloge = horloge.add(const Duration(hours: 23, minutes: 59));
      await session(tester);
      expect(compte(), [1, 0, 0], reason: 'moins de 24 h');
      horloge = horloge.add(const Duration(minutes: 2));
      await session(tester);
      expect(compte(), [1, 0, 1], reason: 'plus de 24 h : relu');
      await demonter(tester);
    });

    testWidgets('avec routes : routes annoncées retenues', (tester) async {
      Donnees3171.installer(serveur, ServeurOfficine.retour);
      await monter(tester);
      await session(tester);
      expect(compte(), [1, 0, 1]);
      expect(await retenu(tester), {'routes': ['ca-credit', 'tva']});
      expect(sessionsExpirees, 0);
      await demonter(tester);
    });
  });

  group('échecs et réponses inattendues : rien retenu, nouvel essai à la session suivante', () {
    for (final (nom, reponse, attente, expiree) in [
      ('HTTP 401', ReponseFausse.sessionExpiree(), Duration.zero, 1),
      ('HTTP 403', ReponseFausse.json({'success': false}, statut: 403), Duration.zero, 0),
      ('HTTP 404', ReponseFausse.introuvable(), Duration.zero, 0),
      ('HTTP 500', ReponseFausse.erreurServeur(), Duration.zero, 0),
      ('HTTP 503', ReponseFausse.erreurServeur(statut: 503), Duration.zero, 0),
      ('coupure réseau', ReponseFausse.coupee(), Duration.zero, 0),
      ('délai dépassé', ReponseFausse.sansReponse(), ApiService.delaiGet + const Duration(seconds: 2), 0),
      ('réponse vide', ReponseFausse.vide(), Duration.zero, 0),
      ('liste', ReponseFausse.json([]), Duration.zero, 0),
      ('JSON illisible', ReponseFausse.texte('<html>maintenance</html>'), Duration.zero, 0),
      ('success absent', ReponseFausse.json({'version': 'NOUVEAU', 'routes': ['tva']}), Duration.zero, 0),
      ('« routes » illisible', ReponseFausse.json({'success': true, 'routes': 'tva'}), Duration.zero, 0),
    ]) {
      testWidgets(nom, (tester) async {
        Donnees3171.installer(serveur, ServeurOfficine.retour);
        await monter(tester);
        version(reponse);
        await session(tester, attente: attente);
        expect(compte(), [1, 0, 1]);
        expect(await retenu(tester), isNull, reason: 'rien n\'est conclu');
        expect(sessionsExpirees, expiree);
        expect(tester.takeException(), isNull);
        await actualiser(tester);
        expect(n(RoutesServeur.route), 0, reason: 'une lecture par session');
        Donnees3171.installer(serveur, ServeurOfficine.retour);
        await session(tester);
        expect(compte(), [1, 0, 1]);
        expect(await retenu(tester), {'routes': ['ca-credit', 'tva']});
        await demonter(tester);
      });
    }
  });

  test('lireVersion : seule « success: true » conclut', () {
    NatureVersion nature(Object? j) => RoutesServeur.lireVersion(j).nature;
    expect(nature(Donnees3171.version(routes: Donnees3171.routes)), NatureVersion.annoncees);
    expect(RoutesServeur.lireVersion(Donnees3171.version(routes: Donnees3171.routes)).routes, {'tva', 'ca-credit'});
    expect(RoutesServeur.lireVersion({'success': true, 'routes': []}).routes, isEmpty);
    expect(nature(Donnees3171.version()), NatureVersion.anterieur);
    expect(nature({'success': true, 'version': 'ANCIEN', 'routes': null}), NatureVersion.anterieur);
    expect(nature(deconnecte), NatureVersion.inconnue);
    expect(nature({'success': false, 'msg': 'Veuillez vous connecter', 'routes': ['tva']}), NatureVersion.inconnue);
    expect(nature({'success': 'true', 'version': 'NOUVEAU'}), NatureVersion.inconnue);
    expect(nature({'version': 'NOUVEAU'}), NatureVersion.inconnue);
    expect(nature({'success': true, 'routes': 'tva'}), NatureVersion.inconnue);
    expect(nature([]), NatureVersion.inconnue);
    expect(nature(null), NatureVersion.inconnue);
    expect(nature('Veuillez vous connecter'), NatureVersion.inconnue);
  });
}
