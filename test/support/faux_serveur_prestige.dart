// Faux serveur Prestige des tests : le serveur fictif de l'application (lib/demo/serveur_fictif.dart : routes,
// sessions, journal, données fictives de lib/demo/donnees/) servi par un VRAI serveur HTTP local (127.0.0.1, port
// libre choisi par le système), avec en plus les coupures réseau (réponse tronquée, connexion fermée, aucune réponse).
//
// Utilisation :
//   final serveur = FauxServeurPrestige();
//   setUp(() => serveur.demarrer());          // HORS du corps de testWidgets (horloge réelle)
//   tearDown(() => serveur.arreter());
//   serveur.quand('/info', ReponseFausse.json([...]));
//   serveur.quand('/officine', ReponseFausse.erreurServeur(), methode: 'GET');
//   SharedPreferences.setMockInitialValues(serveur.preferencesApp());   // l'application vise ce serveur
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:prestige_app/demo/serveur_fictif.dart';

export 'package:prestige_app/demo/serveur_fictif.dart';

class FauxServeurPrestige extends ServeurFictif {
  HttpServer? _serveur;
  final _enAttente = <HttpRequest>{};

  int get port => _serveur?.port ?? (throw StateError('Faux serveur non démarré'));
  bool get demarre => _serveur != null;

  /// Servi en HTTPS ([demarrerSecurise]) ?
  bool https = false;

  /// « http://127.0.0.1:port/prestige » (« https://… » si [demarrerSecurise]).
  String get racine => '${https ? 'https' : 'http'}://127.0.0.1:$port/${ServeurFictif.application}';

  /// Préférences qui font viser ce serveur par l'application (même format que la Configuration IP).
  Map<String, Object> preferencesApp({Map<String, Object> autres = const {}}) => {
        'local_ip': https ? 'https://127.0.0.1' : '127.0.0.1',
        'port_key': '$port',
        'app_name_key': ServeurFictif.application,
        'use_local_ip': true,
        'is_app_configured': true,
        ...autres,
      };

  /// Démarre le serveur. À appeler HORS de la zone à horloge simulée de testWidgets (setUp, ou tester.runAsync).
  Future<void> demarrer() async {
    if (_serveur != null) return;
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _serveur = s;
    s.listen(_traiter);
  }

  /// Démarre le serveur en HTTPS (tests réseau) avec le certificat de [contexte] (certificat de test généré).
  Future<void> demarrerSecurise(SecurityContext contexte) async {
    if (_serveur != null) return;
    final s = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, contexte);
    https = true;
    _serveur = s;
    s.listen(_traiter, onError: (_) {}); // poignée de main refusée par le client : rien à faire
  }

  /// Arrête le serveur : les requêtes suivantes échouent (connexion refusée), comme un serveur éteint.
  Future<void> arreter() async {
    final s = _serveur;
    _serveur = null;
    for (final r in _enAttente.toList()) {
      try {
        r.response.detachSocket().then((sock) => sock.destroy(), onError: (_) {});
      } catch (_) {}
    }
    _enAttente.clear();
    await s?.close(force: true);
  }

  /// Un port local sur lequel rien n'écoute (serveur injoignable dès le lancement).
  static Future<int> portFerme() async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final p = s.port;
    await s.close();
    return p;
  }

  Future<void> _traiter(HttpRequest req) async {
    _enAttente.add(req);
    try {
      final corps = await utf8.decodeStream(req);
      final reponse = await repondre(req.method, req.uri, req.headers.value('cookie'), corps);
      if (reponse.jamais) return; // la connexion reste ouverte (fermée par arreter())
      if (reponse.delai > Duration.zero) await Future<void>.delayed(reponse.delai);
      if (reponse.coupee || reponse.tronquee) {
        // Coupure : en-têtes (longueur annoncée plus grande que le corps) puis une partie du corps, ou rien du tout.
        final res = req.response;
        res.statusCode = reponse.statut;
        reponse.entetes.forEach(res.headers.set);
        if (reponse.tronquee) res.contentLength = reponse.octets.length + 64;
        final sock = await res.detachSocket(writeHeaders: reponse.tronquee);
        if (reponse.tronquee) {
          sock.add(reponse.octets);
          await sock.flush();
        }
        sock.destroy();
        _enAttente.remove(req);
        return;
      }
      final res = req.response;
      res.statusCode = reponse.statut;
      // Plusieurs Set-Cookie (séparés par « \n » dans [ReponseFausse.entetes]) : un en-tête chacun, comme Prestige.
      reponse.entetes.forEach((k, v) {
        for (final valeur in v.split('\n')) {
          res.headers.add(k, valeur);
        }
      });
      res.add(reponse.octets);
      await res.close();
      _enAttente.remove(req);
    } catch (_) {
      // Connexion fermée par le client (délai dépassé) ou serveur arrêté : rien à faire.
    }
  }
}
