// Module Présences : appels au serveur (routes RH existantes) sur un serveur simulé qui renvoie les VRAIES réponses
// enregistrées. Erreurs : mêmes règles que l'étape 1 (réseau / délai / 5xx / 401 session / droit manquant / vraie
// liste vide / route absente 404 « non disponible sur cette version du serveur »). Téléchargement binaire robuste.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/presences/presences_api.dart';
import 'package:prestige_app/presences/presences_modeles.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';
import 'outils/serveur_presences.dart';

late ServeurPresences serveur;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true});
    FlutterSecureStorage.setMockInitialValues({});
    serveur = ServeurPresences();
    ApiService.client = MockClient(serveur.repondre);
    JournalApp.actif = false;
    HorlogePresences.maintenant = () => DateTime(2026, 10, 13, 8, 46);
  });

  tearDown(() {
    ApiService.client = http.Client();
    HorlogePresences.maintenant = DateTime.now;
  });

  /// Exécute [appel] dans un contexte de l'application et renvoie le résultat ou l'erreur.
  Future<Object?> lancer(WidgetTester tester, Future<Object?> Function(BuildContext) appel, {Duration attente = Duration.zero}) async {
    final ctx = await monterAvecProviders(tester);
    Object? r;
    final f = appel(ctx).then((v) => r = v, onError: (Object e) => r = e);
    await tester.pump(attente);
    await tester.pump();
    await f;
    return r;
  }

  const api = PresencesApi();
  final periode = PeriodePresence.bornee(DateTime(2026, 10, 1), DateTime(2026, 10, 13), aujourdhui: DateTime(2026, 10, 13));

  group('Lectures', () {
    testWidgets('présence du jour : route, paramètre jour=AAAA-MM-JJ, lignes et pointages', (tester) async {
      final r = await lancer(tester, (c) => api.presence(c, DateTime(2026, 10, 12, 15, 30))) as PresenceDuJour;
      expect(serveur.appels.last, 'GET /rh/presence?jour=2026-10-12');
      expect(r.lignes, hasLength(2));
      expect(r.pointages, hasLength(5));
      expect(r.jour, DateTime(2026, 10, 12));
    });

    testWidgets('vraie liste vide (jour sans planning ni pointage) ≠ erreur', (tester) async {
      final r = await lancer(tester, (c) => api.presence(c, DateTime(2026, 9, 1))) as PresenceDuJour;
      expect(r.lignes, isEmpty);
    });

    testWidgets('tableau : période et employé transmis, période appliquée par le serveur relue', (tester) async {
      final r = await lancer(tester, (c) => api.tableau(c, periode, employeId: '57d09b7a-00a2-4a7d-a5b1-820c047c959c')) as TableauPeriode;
      expect(serveur.appels.last, 'GET /rh/tableau?du=2026-10-01&au=2026-10-13&employeId=57d09b7a-00a2-4a7d-a5b1-820c047c959c');
      expect(r.lignes.single.employe, 'KONE Awa Test');
      expect((r.du, r.au), (DateTime(2026, 10, 1), DateTime(2026, 10, 13)));
    });

    testWidgets('QR du moment et téléphones', (tester) async {
      final code = await lancer(tester, (c) => api.codePointage(c)) as CodePointageMoment;
      expect(code.contenu, startsWith('PRESTIGE-POINTAGE:'));
      final t = await lancer(tester, (c) => api.terminaux(c)) as List<TerminalMobile>;
      expect(t.map((x) => x.statut), ['ACTIF', 'REVOQUE']);
    });

    testWidgets('retirer / réactiver : POST sur la bonne route, message du serveur ; téléphone inconnu → refus clair', (tester) async {
      final m = await lancer(tester, (c) => api.changerTerminal(c, 'test-term-1', reactiver: false));
      expect(serveur.appels.last, 'POST /rh/mobile/terminaux/test-term-1/retirer');
      expect(m, 'Téléphone retiré : il est déconnecté.');
      expect(serveur.statutTerminaux['test-term-1'], 'REVOQUE');
      final m2 = await lancer(tester, (c) => api.changerTerminal(c, 'test-term-2', reactiver: true));
      expect(serveur.appels.last, 'POST /rh/mobile/terminaux/test-term-2/reactiver');
      expect(m2, 'Téléphone réactivé.');
      final e = await lancer(tester, (c) => api.changerTerminal(c, 'inconnu', reactiver: false));
      expect(e, isA<ApiLoadException>().having((x) => x.message, 'message', 'Téléphone introuvable.'));
    });
  });

  group('Erreurs : chacune son message (≠ liste vide)', () {
    Future<ApiLoadException> echec(WidgetTester tester, PanneRh p, {Duration attente = Duration.zero}) async {
      serveur.panne = p;
      final e = await lancer(tester, (c) => api.presence(c, DateTime(2026, 10, 13)), attente: attente);
      expect(e, isA<ApiLoadException>());
      return e as ApiLoadException;
    }

    testWidgets('serveur injoignable', (tester) async {
      final e = await echec(tester, PanneRh.reseau);
      expect(e.nature, NatureErreur.reseau);
      expect(e.message, contains('Serveur injoignable'));
    });

    testWidgets('délai dépassé', (tester) async {
      final e = await echec(tester, PanneRh.delai, attente: const Duration(seconds: 46));
      expect(e.nature, NatureErreur.delai);
    });

    testWidgets('erreur 5xx : code donné, page d\'erreur jamais affichée', (tester) async {
      final e = await echec(tester, PanneRh.serveur500);
      expect(e.nature, NatureErreur.serveur);
      expect(e.message, contains('500'));
      expect(e.message, isNot(contains('NullPointer')));
    });

    testWidgets('session expirée : retour à la connexion (rappel global)', (tester) async {
      var rappels = 0;
      final ctx = await monterAvecProviders(tester);
      final avant = ApiService.surSessionExpiree;
      ApiService.surSessionExpiree = () => rappels++;
      serveur.panne = PanneRh.session401;
      Object? e;
      try {
        await api.presence(ctx, DateTime(2026, 10, 13));
      } catch (x) {
        e = x;
      }
      ApiService.surSessionExpiree = avant;
      expect(e, isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.session));
      expect(rappels, 1);
    });

    testWidgets('droit manquant P_SM_RH (réponse réelle success:false) : message clair, pas de déconnexion', (tester) async {
      var rappels = 0;
      final avant = ApiService.surSessionExpiree;
      ApiService.surSessionExpiree = () => rappels++;
      final e = await echec(tester, PanneRh.droit);
      ApiService.surSessionExpiree = avant;
      expect(e.nature, NatureErreur.droit);
      expect(e.message, contains('P_SM_RH'));
      expect(rappels, 0);
    });

    testWidgets('route absente (404) : « non disponible sur cette version du serveur »', (tester) async {
      final e = await echec(tester, PanneRh.absente404);
      expect(e.message, contains('non disponible sur cette version du serveur'));
    });

    testWidgets('réponse illisible', (tester) async {
      final e = await echec(tester, PanneRh.illisible);
      expect(e.nature, NatureErreur.reponse);
    });
  });

  group('Téléchargement des exports (ApiService.getBytes)', () {
    testWidgets('Excel, Excel détaillé, PDF : bons paramètres, octets intacts, nom explicite', (tester) async {
      final x = await lancer(tester, (c) => api.exporter(c, periode, FormatExport.excel)) as FichierTelecharge;
      expect(serveur.appels.last, 'GET /rh/tableau/excel?du=2026-10-01&au=2026-10-13');
      expect(x.octets, fixtureOctets('tableau.xlsx'));
      expect(x.nom, 'tableau_presences_2026-10-01_2026-10-13.xlsx');

      final d = await lancer(tester, (c) => api.exporter(c, periode, FormatExport.excelDetaille)) as FichierTelecharge;
      expect(serveur.appels.last, 'GET /rh/tableau/excel?du=2026-10-01&au=2026-10-13&detail=true');
      expect(d.nom, 'presences_detail_2026-10-01_2026-10-13.xlsx');

      final p = await lancer(tester, (c) => api.exporter(c, periode, FormatExport.pdf)) as FichierTelecharge;
      expect(serveur.appels.last, 'GET /rh/tableau/pdf?du=2026-10-01&au=2026-10-13');
      expect(p.octets, fixtureOctets('tableau.pdf'));
      expect(p.type, 'application/pdf');
    });

    testWidgets('page HTML « L\'édition n\'a pas pu être générée » à la place du PDF → refusée', (tester) async {
      serveur.reponses['/rh/tableau/pdf'] = (_) => http.Response(
          '<html><h3>L\'édition n\'a pas pu être générée.</h3></html>', 200, headers: {'content-type': 'text/html;charset=UTF-8'});
      final e = await lancer(tester, (c) => api.exporter(c, periode, FormatExport.pdf));
      expect(e, isA<ApiLoadException>().having((x) => x.message, 'message', contains('pas pu produire le fichier')));
    });

    testWidgets('fichier vide ou signature incorrecte → refusé (jamais partagé)', (tester) async {
      serveur.reponses['/rh/tableau/excel'] = (_) => http.Response.bytes([], 200, headers: {'content-type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'});
      expect(await lancer(tester, (c) => api.exporter(c, periode, FormatExport.excel)),
          isA<ApiLoadException>().having((x) => x.message, 'message', contains('vide')));
      serveur.reponses['/rh/tableau/pdf'] = (_) => http.Response.bytes([1, 2, 3, 4, 5], 200, headers: {'content-type': 'application/pdf'});
      expect(await lancer(tester, (c) => api.exporter(c, periode, FormatExport.pdf)),
          isA<ApiLoadException>().having((x) => x.message, 'message', contains('illisible')));
    });

    testWidgets('401 de l\'export avec session valide → droit manquant (vérifié par /rh/droits), sans déconnexion', (tester) async {
      var rappels = 0;
      final ctx = await monterAvecProviders(tester);
      final avant = ApiService.surSessionExpiree;
      ApiService.surSessionExpiree = () => rappels++;
      serveur.panne = PanneRh.droit;
      Object? e;
      try {
        await api.exporter(ctx, periode, FormatExport.excel);
      } catch (x) {
        e = x;
      }
      ApiService.surSessionExpiree = avant;
      expect(serveur.appels, contains('GET /rh/droits'));
      expect(e, isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.droit));
      expect(rappels, 0);
    });

    testWidgets('401 de l\'export avec session expirée → reconnexion', (tester) async {
      var rappels = 0;
      final ctx = await monterAvecProviders(tester);
      final avant = ApiService.surSessionExpiree;
      ApiService.surSessionExpiree = () => rappels++;
      serveur.panne = PanneRh.session401;
      Object? e;
      try {
        await api.exporter(ctx, periode, FormatExport.pdf);
      } catch (x) {
        e = x;
      }
      ApiService.surSessionExpiree = avant;
      expect(e, isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.session));
      expect(rappels, 1);
    });

    testWidgets('export : réseau coupé, 5xx', (tester) async {
      serveur.panne = PanneRh.reseau;
      expect(await lancer(tester, (c) => api.exporter(c, periode, FormatExport.excel)),
          isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.reseau));
      serveur.panne = PanneRh.serveur500;
      expect(await lancer(tester, (c) => api.exporter(c, periode, FormatExport.excel)),
          isA<ApiLoadException>().having((x) => x.nature, 'nature', NatureErreur.serveur));
    });

    test('nom de fichier tiré de l\'en-tête, sans chemin ni caractère dangereux', () {
      expect(FichierTelecharge.nomDepuisEntete('attachment; filename=tableau_rh.xlsx', 'x'), 'tableau_rh.xlsx');
      expect(FichierTelecharge.nomDepuisEntete('inline; filename="rapport été.pdf"', 'x'), 'rapport__t_.pdf');
      expect(FichierTelecharge.nomDepuisEntete('attachment; filename=../../etc/passwd', 'x'), 'passwd');
      expect(FichierTelecharge.nomDepuisEntete('attachment; filename=..', 'x'), 'x');
      expect(FichierTelecharge.nomDepuisEntete(null, 'defaut.pdf'), 'defaut.pdf');
    });
  });
}
