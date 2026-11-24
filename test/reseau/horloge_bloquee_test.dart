// RÉSEAU — 3.18.1 : HEURE DU SERVEUR FAUSSE (serveur Prestige du 24/11, plan/24112026). Tant que l'heure du serveur est
// fausse, il refuse toute écriture (POST / PUT / DELETE / PATCH, sauf connexion / déconnexion / routes de l'horloge) :
// HTTP 423 {"success":false,"horlogeBloquee":true,"msg":"Opération refusée : l'heure du serveur est fausse. …"} ; les
// lectures (GET) restent permises. Avant 3.18.1 : « Le serveur a refusé la demande (code 423). ».
//
// Contre le faux serveur Prestige joint en HTTP RÉEL, avec la session de la connexion (données fictives) :
//  - chaque écriture de l'application (pointage BL : pointer / séquence / avoir ; avis : traiter ; rappels : marquer,
//    actualiser ; péremptions courtes : statut ; suggestions : quantité, retrait d'un article, suppression ; présences :
//    retirer / réactiver un téléphone ; ticket Z, lu en POST) → ApiLoadException.horloge : message du serveur TEL QUEL,
//    jamais « serveur injoignable », « erreur du serveur », « erreur inconnue » ; titre « Heure du serveur fausse » ;
//  - UNE requête par action (aucune relance), session gardée (pas de retour à la connexion) ;
//  - les lectures continuent ; la même action passe quand l'heure est remise ;
//  - 423 sans message lisible → « Opération refusée par le serveur (code 423). » ;
//  - GET horloge/public : BLOQUE → message ; OK / REGULARISATION / 404 / autre / injoignable / démonstration → rien ;
//  - journal : le code seulement, jamais le message.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/demo/mode_demo.dart';
import 'package:prestige_app/donnees/horloge_serveur.dart';
import 'package:prestige_app/donnees/recap_caisse_donnees.dart';
import 'package:prestige_app/donnees/suggestions_donnees.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague4/peremptions_courtes_vague4.dart';
import 'package:prestige_app/presences/presences_api.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/utils/constants.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';

final serveur = FauxServeurPrestige();

/// Message du serveur (forme exacte de HorlogeBlocageFilter, plan du 24/11).
const msg = 'Opération refusée : l\'heure du serveur est fausse. Faites « Mettre à jour » ou appelez '
    'l\'administrateur pour remettre l\'heure dans Windows.';

ReponseFausse refus423() => ReponseFausse.json({'success': false, 'horlogeBloquee': true, 'msg': msg}, statut: 423);

typedef App = ({BuildContext ctx, AuthProvider auth});

Future<App> connecte(WidgetTester tester) async {
  final auth = AuthProvider();
  final ctx = await monterAvecProviders(tester, auth: auth, licence: LicenceProvider());
  await tester.runAsync(() => auth.login(ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false));
  await tester.pump();
  expect(auth.isLoggedIn, isTrue);
  serveur.oublierRequetes();
  return (ctx: ctx, auth: auth);
}

Future<(T?, Object?)> essayer<T>(WidgetTester tester, Future<T> Function() appel) async {
  T? r;
  Object? e;
  await tester.runAsync(() async {
    try {
      r = await appel();
    } catch (x) {
      e = x;
    }
  });
  await tester.pump();
  return (r, e);
}

/// Refus « heure du serveur fausse » : message tel quel, demande refusée, code 423, titre dédié.
final Matcher estRefusHorloge = isA<ApiLoadException>()
    .having((e) => e.horlogeBloquee, 'horlogeBloquee', isTrue)
    .having((e) => e.message, 'message', msg)
    .having((e) => e.nature, 'nature', NatureErreur.refus)
    .having((e) => e.code, 'code', 423);

void main() {
  final lignesJournal = <String>[];
  late void Function(String) sortieJournal;
  late bool journalActif;

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerTelephone(serveur, nouvelle: true);
    listesCommunesVague1(serveur);
    await ApiService().clearSessionCookie();
    lignesJournal.clear();
    sortieJournal = JournalApp.sortie;
    journalActif = JournalApp.actif;
    JournalApp.sortie = lignesJournal.add;
    JournalApp.actif = true;
  });

  tearDown(() async {
    JournalApp.sortie = sortieJournal;
    JournalApp.actif = journalActif;
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..reponseSansSession = ((_) => ReponseFausse.sessionExpiree())
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
  });

  /// Vérifie le refus d'une écriture : une requête [methode] [chemin], message tel quel, session gardée, journal sans
  /// le message ; puis l'heure est remise ([remettre]) et la même action passe.
  Future<void> verifier(WidgetTester tester, App app, String methode, String chemin, Future<Object?> Function() action) async {
    serveur.quand(chemin, refus423(), methode: methode);
    final (_, e) = await essayer(tester, action);
    expect(e, estRefusHorloge, reason: '$methode $chemin');
    expect(serveur.recues(chemin, methode: methode), hasLength(1), reason: '$methode $chemin : une seule requête, aucune relance');
    expect(app.auth.isLoggedIn, isTrue, reason: 'pas de retour à la connexion');
    final d = DiagnosticErreur.de(e!);
    expect((d.titre, d.message, d.cause), (ApiLoadException.titreHorloge, msg, CauseErreur.autre));
    for (final mot in ['injoignable', 'inconnue', 'Erreur du serveur', 'code 423']) {
      expect(d.message, isNot(contains(mot)));
    }
    expect(lignesJournal.join('\n'), isNot(contains('heure du serveur est fausse.')), reason: 'message jamais journalisé');
    expect(lignesJournal.where((l) => l.contains('423')), isNotEmpty, reason: 'le code seulement');
  }

  group('Chaque écriture : 423 → message du serveur tel quel, une requête, session gardée', () {
    testWidgets('pointage BL : pointer, N° de séquence, référence d\'avoir (PUT)', (tester) async {
      final app = await connecte(tester);
      final (l, _) = await essayer(tester,
          () => ApiPointage.liste(app.ctx, FiltresPointage(grossiste: DonneesVague3.grossiste, debut: DateTime(2026, 10, 1), fin: DateTime(2026, 10, 14))));
      expect(l, isNotNull, reason: 'les lectures restent permises');
      final bl = l!.pieces.firstWhere((p) => p.cle == 'BL:BL-TEST-3');
      final retour = l.pieces.firstWhere((p) => p.cle == 'RETOUR:RET-TEST-1');
      await verifier(tester, app, 'PUT', '/pointage-bl/pointer/BL/BL-TEST-3', () => ApiPointage.pointer(app.ctx, bl, true));
      await verifier(tester, app, 'PUT', '/pointage-bl/sequence/BL-TEST-3', () => ApiPointage.sequence(app.ctx, bl, 'S1'));
      await verifier(tester, app, 'PUT', '/pointage-bl/avoir/RET-TEST-1', () => ApiPointage.referenceAvoir(app.ctx, retour, 'AV-1'));
      // L'heure est remise : la même action passe.
      serveur.installerRoutesParDefaut();
      listesCommunesVague1(serveur);
      final (_, e) = await essayer(tester, () => ApiPointage.pointer(app.ctx, bl, true));
      expect(e, isNull);
    });

    testWidgets('avis clients : traiter (POST) ; rappels : marquer, actualiser (POST)', (tester) async {
      final app = await connecte(tester);
      await verifier(tester, app, 'POST', ApiAvis.routeTraiter('AV-TEST-1'), () => ApiAvis.traiter(app.ctx, 'AV-TEST-1', StatutAvis.traite, 'Note fictive'));
      await verifier(tester, app, 'POST', ApiRappels.routeMarquer, () => ApiRappels.marquer(app.ctx, ['RAP-TEST-1'], StatutRappel.prepare));
      await verifier(tester, app, 'POST', ApiRappels.routeActualiser, () => ApiRappels.actualiser(app.ctx));
    });

    testWidgets('« Racheté » refusé par l\'horloge : jamais pris pour un serveur ancien', (tester) async {
      final app = await connecte(tester);
      await verifier(tester, app, 'POST', ApiRappels.routeMarquer, () => ApiRappels.marquer(app.ctx, ['RAP-TEST-1'], StatutRappel.achete));
    });

    testWidgets('péremptions courtes : statut (PUT)', (tester) async {
      final app = await connecte(tester);
      await verifier(tester, app, 'PUT', ApiPeremptionsCourtes.routeStatut('PC-TEST-1'),
          () => ApiPeremptionsCourtes.statut(app.ctx, 'PC-TEST-1', StatutPeremptionCourte.reclame));
    });

    testWidgets('suggestions : quantité (POST), retrait d\'un article et suppression (DELETE)', (tester) async {
      final app = await connecte(tester);
      await verifier(tester, app, 'POST', AppConstants.suggestionUpdateQteEndpoint, () => Suggestions.enregistrerQuantite(app.ctx, 'ITEM-TEST-1', 3));
      await verifier(tester, app, 'DELETE', '${AppConstants.suggestionDeleteItemEndpoint}/ITEM-TEST-1', () => Suggestions.supprimerLigne(app.ctx, 'ITEM-TEST-1'));
      await verifier(tester, app, 'DELETE', '${AppConstants.suggestionDeleteEndpoint}/SUG-TEST-1', () => Suggestions.supprimer(app.ctx, 'SUG-TEST-1'));
    });

    testWidgets('présences : retirer / réactiver un téléphone (POST)', (tester) async {
      final app = await connecte(tester);
      await verifier(tester, app, 'POST', '/rh/mobile/terminaux/TERM-TEST-1/retirer',
          () => const PresencesApi().changerTerminal(app.ctx, 'TERM-TEST-1', reactiver: false));
      await verifier(tester, app, 'POST', '/rh/mobile/terminaux/TERM-TEST-1/reactiver',
          () => const PresencesApi().changerTerminal(app.ctx, 'TERM-TEST-1', reactiver: true));
    });

    testWidgets('ticket Z (lu en POST) : message du serveur tel quel', (tester) async {
      final app = await connecte(tester);
      final corps = RecapCaisse.corps(debut: DateTime(2026, 11, 24), fin: DateTime(2026, 11, 24));
      await verifier(tester, app, 'POST', '/caisse/fetch-tickez', () => RecapCaisse.charger(app.ctx, corps));
    });

    testWidgets('423 sans message lisible : « Opération refusée par le serveur (code 423). »', (tester) async {
      final app = await connecte(tester);
      serveur.quand(AppConstants.suggestionUpdateQteEndpoint, ReponseFausse.vide(statut: 423), methode: 'POST');
      final (_, e) = await essayer(tester, () => Suggestions.enregistrerQuantite(app.ctx, 'ITEM-TEST-1', 3));
      expect(e, isA<ApiLoadException>().having((x) => x.horlogeBloquee, 'horloge', isTrue).having((x) => x.message, 'message', ApiLoadException.messageHorlogeParDefaut));
      expect(app.auth.isLoggedIn, isTrue);
    });
  });

  group('GET /horloge/public (écran de connexion, sans session)', () {
    // Comme le vrai serveur : route publique (sans session).
    setUp(() => serveur.routesPubliques.add(HorlogeServeur.route));
    tearDown(() => serveur.routesPubliques.remove(HorlogeServeur.route));

    Future<HorlogeServeur?> lire(WidgetTester tester) async {
      HorlogeServeur? h;
      await tester.runAsync(() async => h = await HorlogeServeur.lire('${serveur.racine}/api/v1'));
      return h;
    }

    testWidgets('BLOQUE → bandeau avec l\'heure du serveur ; une seule requête, sans cookie', (tester) async {
      serveur.quand(HorlogeServeur.route, ReponseFausse.json({'etat': 'BLOQUE', 'serveur': '24/11/2026 20:52'}), methode: 'GET');
      final h = await lire(tester);
      expect(h?.bloque, isTrue);
      expect(h!.message,
          'L\'heure du serveur est fausse (heure du serveur : 24/11/2026 20:52) : le serveur refuse les enregistrements (validations, '
          'pointages, avis…) tant qu\'elle n\'est pas remise. La consultation reste possible.');
      final r = serveur.recues(HorlogeServeur.route).single;
      expect(r.methode, 'GET');
      expect(r.sessionEnvoyee, isNull);
    });

    testWidgets('OK et REGULARISATION (écritures permises) → rien', (tester) async {
      for (final etat in ['OK', 'REGULARISATION']) {
        serveur.quand(HorlogeServeur.route, ReponseFausse.json({'etat': etat, 'serveur': '24/11/2026 20:52'}), methode: 'GET');
        final h = await lire(tester);
        expect(h?.etat, etat);
        expect(h!.message, isNull, reason: etat);
      }
    });

    testWidgets('ancien serveur (404), 401, 500, page HTML, JSON inattendu, injoignable → rien', (tester) async {
      final cas = <String, ReponseFausse>{
        '404': ReponseFausse.introuvable(),
        '401': ReponseFausse.sessionExpiree(),
        '500': ReponseFausse.erreurServeur(),
        '200 HTML': ReponseFausse.texte('<html>portail</html>'),
        '200 sans etat': ReponseFausse.json({'success': true}),
        '200 etat inconnu': ReponseFausse.json({'etat': 'PEUT-ETRE'}),
        '200 liste': ReponseFausse.json(const <Object>[]),
      };
      for (final e in cas.entries) {
        serveur.quand(HorlogeServeur.route, e.value, methode: 'GET');
        expect(await lire(tester), isNull, reason: e.key);
      }
      final base = '${serveur.racine}/api/v1';
      await tester.runAsync(serveur.arreter);
      HorlogeServeur? h;
      await tester.runAsync(() async => h = await HorlogeServeur.lire(base));
      expect(h, isNull, reason: 'injoignable');
    });

    testWidgets('mode démonstration : aucune requête', (tester) async {
      serveur.quand(HorlogeServeur.route, ReponseFausse.json({'etat': 'BLOQUE'}), methode: 'GET');
      ModeDemo.actif.value = true;
      addTearDown(() => ModeDemo.actif.value = false);
      expect(await lire(tester), isNull);
      expect(serveur.recues(HorlogeServeur.route), isEmpty);
    });
  });
}
