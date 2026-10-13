// Serveur Prestige simulé pour le module Présences, à partir de VRAIES réponses du serveur de test
// (test/fixtures/presences/*.json, capturées le 13/10/2026 sur 2 employés de test, puis données supprimées).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Lit une réponse réelle enregistrée.
String fixture(String nom) => File('test/fixtures/presences/$nom').readAsStringSync();
List<int> fixtureOctets(String nom) => File('test/fixtures/presences/$nom').readAsBytesSync();

enum PanneRh { aucune, reseau, delai, serveur500, session401, droit, absente404, illisible }

class ServeurPresences {
  /// Panne appliquée à toutes les routes /rh/… (ou seulement à [routePanne] si elle est donnée).
  PanneRh panne = PanneRh.aucune;
  String? routePanne;

  /// Appels reçus : « GET /rh/presence?jour=2026-10-13 ».
  final appels = <String>[];

  /// Réponses particulières par chemin (prioritaires).
  final reponses = <String, http.Response Function(http.Request)>{};

  /// Statut des téléphones (modifié par retirer / réactiver).
  final statutTerminaux = <String, String>{'test-term-1': 'ACTIF', 'test-term-2': 'REVOQUE'};

  /// Nombre de codes QR servis (le code change à chaque appel).
  int codesServis = 0;

  static const json = {'content-type': 'application/json; charset=utf-8'};

  Future<http.Response> repondre(http.Request req) async {
    final chemin = req.url.path.replaceFirst(RegExp(r'^.*/api/v1'), '');
    appels.add('${req.method} $chemin${req.url.query.isEmpty ? '' : '?${req.url.query}'}');
    final concerne = routePanne == null || chemin.startsWith(routePanne!);
    if (chemin.startsWith('/rh/') && concerne) {
      switch (panne) {
        case PanneRh.reseau:
          throw const SocketException('Connection refused');
        case PanneRh.delai:
          return Completer<http.Response>().future;
        case PanneRh.serveur500:
          return http.Response('<html>java.lang.NullPointerException</html>', 500);
        case PanneRh.session401:
          return http.Response('Veuillez vous connecter', 401);
        case PanneRh.droit:
          // Prestige : 200 {success:false} pour les routes JSON, 401 pour les exports (RhRessource.controle()).
          if (chemin.contains('/excel') || chemin.contains('/pdf')) return http.Response('', 401);
          return http.Response.bytes(fixtureOctets('refus_droit.json'), 200, headers: json);
        case PanneRh.absente404:
          return http.Response('<html>Not Found</html>', 404);
        case PanneRh.illisible:
          return http.Response('<html>pas du JSON</html>', 200);
        case PanneRh.aucune:
          break;
      }
    }
    final special = reponses[chemin];
    if (special != null) return special(req);
    switch (chemin) {
      case '/rh/presence':
        final jour = req.url.queryParameters['jour'];
        final f = switch (jour) {
          '2026-10-13' => 'presence_aujourdhui.json',
          '2026-10-12' => 'presence_hier.json',
          _ => 'presence_vide.json',
        };
        return http.Response.bytes(fixtureOctets(f), 200, headers: json);
      case '/rh/tableau':
        final employe = req.url.queryParameters['employeId'];
        return http.Response.bytes(fixtureOctets(employe == null ? 'tableau.json' : 'tableau_employe.json'), 200, headers: json);
      case '/rh/tableau/excel':
        return http.Response.bytes(fixtureOctets('tableau.xlsx'), 200, headers: {
          'content-type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'content-disposition': 'attachment; filename=${req.url.queryParameters['detail'] == 'true' ? 'presence' : 'tableau_rh'}.xlsx',
        });
      case '/rh/tableau/pdf':
        return http.Response.bytes(fixtureOctets('tableau.pdf'), 200,
            headers: {'content-type': 'application/pdf', 'content-disposition': 'inline; filename=tableau_rh.pdf'});
      case '/rh/droits':
        return http.Response('{"valider":true,"success":true}', 200, headers: json);
      case '/rh/mobile/code':
        codesServis++;
        final code = ['WPYX5V', 'K7MN2Q', 'ZZ34AB', 'HJ56CD'][(codesServis - 1) % 4];
        return http.Response(
            '{"qr":true,"periodeSec":60,"code":"$code","success":true,"latitude":"","resteSec":${codesServis == 1 ? 3 : 60},'
            '"actif":true,"gps":false,"contenu":"PRESTIGE-POINTAGE:$code","rayon":150,"longitude":""}',
            200,
            headers: json);
      case '/rh/mobile/terminaux':
        final t = jsonDecode(fixture('terminaux.json')) as Map<String, dynamic>;
        for (final e in t['data'] as List) {
          e['statut'] = statutTerminaux[e['id']] ?? e['statut'];
        }
        return http.Response.bytes(utf8.encode(jsonEncode(t)), 200, headers: json);
    }
    final m = RegExp(r'^/rh/mobile/terminaux/([^/]+)/(retirer|reactiver)$').firstMatch(chemin);
    if (m != null && req.method == 'POST') {
      final id = Uri.decodeComponent(m.group(1)!);
      if (!statutTerminaux.containsKey(id)) return http.Response.bytes(fixtureOctets('retirer_inconnu.json'), 200, headers: json);
      final reactiver = m.group(2) == 'reactiver';
      statutTerminaux[id] = reactiver ? 'ACTIF' : 'REVOQUE';
      return http.Response.bytes(fixtureOctets(reactiver ? 'reactiver.json' : 'retirer.json'), 200, headers: json);
    }
    return http.Response('{"data":[],"total":0}', 200, headers: json);
  }
}
