// Module Présences : essai RÉEL contre un serveur Prestige (sauté si aucun serveur ne répond).
// Adresse et compte : variables d'environnement PRESTIGE_TEST_HOTE (localhost), PRESTIGE_TEST_PORT (8080),
// PRESTIGE_TEST_APP (prestige), PRESTIGE_TEST_LOGIN / PRESTIGE_TEST_MOT_DE_PASSE (compte de l'instance de test).
// Lecture seule, sauf PRESTIGE_TEST_ECRITURE=1 : un téléphone actif est alors retiré PUIS réactivé (état rendu).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:prestige_app/presences/presences_api.dart';
import 'package:prestige_app/presences/presences_modeles.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';

final _env = Platform.environment;
final hote = _env['PRESTIGE_TEST_HOTE'] ?? 'localhost';
final port = int.tryParse(_env['PRESTIGE_TEST_PORT'] ?? '') ?? 8080;
final appli = _env['PRESTIGE_TEST_APP'] ?? 'prestige';
final login = _env['PRESTIGE_TEST_LOGIN'] ?? 'admin';
final motDePasse = _env['PRESTIGE_TEST_MOT_DE_PASSE'] ?? 'Test1234';

Future<bool> serveurJoignable() async {
  try {
    final s = await Socket.connect(hote, port, timeout: const Duration(seconds: 2));
    s.destroy();
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    final r = await (await c.getUrl(Uri.parse('http://$hote:$port/$appli/api/v1/officine'))).close().timeout(const Duration(seconds: 5));
    c.close(force: true);
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

Future<void> main() async {
  final joignable = await serveurJoignable();
  final saut = joignable ? false : 'Serveur Prestige de test injoignable ($hote:$port) : essai réel sauté.';

  testWidgets('serveur réel : connexion, présence aujourd\'hui / hier, tableau, exports, QR, téléphones', (tester) async {
    SharedPreferences.setMockInitialValues({
      'local_ip': hote,
      'port_key': '$port',
      'app_name_key': appli,
      'use_local_ip': true,
      'is_app_configured': true,
    });
    FlutterSecureStorage.setMockInitialValues({});
    JournalApp.actif = false;
    final ctx = await monterAvecProviders(tester);
    await tester.runAsync(() async {
      // Vrai réseau (l'environnement de test de Flutter bloque HttpClient par défaut).
      HttpOverrides.global = null;
      ApiService.client = http.Client();
      final api = ApiService();
      final auth = await api.post(ctx, '/user/auth', {'login': login, 'password': motDePasse});
      expect(auth['success'], isTrue, reason: 'connexion refusée');

      const rh = PresencesApi();
      final aujourdhui = jourSeul(DateTime.now());
      final jour = await rh.presence(ctx, aujourdhui);
      final hier = await rh.presence(ctx, aujourdhui.subtract(const Duration(days: 1)));
      for (final p in [jour, hier]) {
        for (final l in p.lignes) {
          expect(l.employeId, isNotEmpty);
          expect(StatutPresence.values, contains(l.statut(60, DateTime.now())));
          for (final a in l.anomalies) {
            expect(anomalieEnPhrase(a), isNot(contains('_')));
          }
        }
        trierPresences(p.lignes, 60, DateTime.now());
      }

      final periode = PeriodePresence.mois(aujourdhui);
      final t = await rh.tableau(ctx, periode);
      expect(t.au, aujourdhui);
      if (t.lignes.isNotEmpty) {
        final un = await rh.tableau(ctx, periode, employeId: t.lignes.first.employeId);
        expect(un.lignes.map((l) => l.employeId).toSet(), {t.lignes.first.employeId});
      }
      // Période trop longue : bornée côté application ET côté serveur.
      final longue = PeriodePresence.bornee(DateTime(2020), aujourdhui, aujourdhui: aujourdhui);
      final tl = await rh.tableau(ctx, longue);
      expect(tl.au.difference(tl.du).inDays, lessThanOrEqualTo(366));

      final xlsx = await rh.exporter(ctx, periode, FormatExport.excel);
      expect(String.fromCharCodes(xlsx.octets.sublist(0, 2)), 'PK');
      final detail = await rh.exporter(ctx, periode, FormatExport.excelDetaille);
      expect(String.fromCharCodes(detail.octets.sublist(0, 2)), 'PK');
      final pdf = await rh.exporter(ctx, periode, FormatExport.pdf);
      expect(String.fromCharCodes(pdf.octets.sublist(0, 4)), '%PDF');

      final code = await rh.codePointage(ctx);
      expect(code.contenu, 'PRESTIGE-POINTAGE:${code.code}');
      expect(code.resteSec, inInclusiveRange(1, code.periodeSec));

      final terminaux = await rh.terminaux(ctx);
      if (_env['PRESTIGE_TEST_ECRITURE'] == '1') {
        final actif = terminaux.where((x) => x.actif).firstOrNull;
        if (actif != null) {
          expect(await rh.changerTerminal(ctx, actif.id, reactiver: false), contains('retiré'));
          expect((await rh.terminaux(ctx)).firstWhere((x) => x.id == actif.id).actif, isFalse);
          expect(await rh.changerTerminal(ctx, actif.id, reactiver: true), contains('réactivé'));
          expect((await rh.terminaux(ctx)).firstWhere((x) => x.id == actif.id).actif, isTrue);
        }
      }
      // Route absente : message « non disponible sur cette version du serveur ».
      Object? e;
      try {
        await api.get(ctx, '/rh/route-inexistante');
      } catch (x) {
        e = x;
      }
      expect(e, isA<ApiLoadException>().having((x) => x.code, 'code', 404));

      await api.post(ctx, '/user/logout', {});
      ApiService.client = http.Client();
    });
    // Le compte rendu (sans données personnelles) apparaît dans la sortie du test.
    debugPrint('Essai réel Présences : OK ($hote:$port/$appli)');
  }, skip: saut != false, timeout: const Timeout(Duration(minutes: 2)));

  if (saut != false) debugPrint('$saut');
}
