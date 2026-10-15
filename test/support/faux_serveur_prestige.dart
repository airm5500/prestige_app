// Faux serveur Prestige réutilisable : un VRAI serveur HTTP local (127.0.0.1, port libre choisi par le système)
// qui imite les routes de Prestige (/prestige/api/v1/…, /prestige/api/v3/…), avec :
//  - des routes scriptables par test (réponse fixe ou fonction de la requête) ;
//  - des réponses types : 200, 200 {success:false}, 401 « Veuillez vous connecter », 500, délai, aucune réponse ;
//  - le contrôle du cookie de session JSESSIONID (délivré par POST /user/auth, exigé sur les routes privées) ;
//  - le journal des requêtes reçues (méthode, chemin, paramètres, cookie, corps).
// Données : test/support/donnees_fictives.dart (fictives uniquement).
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

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'donnees_fictives.dart';
import 'donnees_vague1.dart';
import 'donnees_vague2.dart';
import 'donnees_vague3.dart';

/// Requête reçue par le faux serveur.
class RequeteRecue {
  final String methode;

  /// Chemin (décodé) après « /prestige/api/v1 » (ou v3), ex. « /licence/find ».
  final String chemin;

  /// « v1 » ou « v3 ».
  final String versionApi;
  final Map<String, String> parametres;

  /// En-tête Cookie envoyé (null si absent).
  final String? cookie;
  final String corps;

  const RequeteRecue(this.methode, this.chemin, this.versionApi, this.parametres, this.cookie, this.corps);

  /// Corps JSON décodé (POST).
  dynamic get json => corps.isEmpty ? null : jsonDecode(corps);

  /// Valeur du cookie JSESSIONID envoyé (« JSESSIONID=… »), ou null.
  String? get sessionEnvoyee {
    for (final c in (cookie ?? '').split(';')) {
      final t = c.trim();
      if (t.startsWith('JSESSIONID=')) return t;
    }
    return null;
  }

  @override
  String toString() => '$methode $chemin${parametres.isEmpty ? '' : '?${Uri(queryParameters: parametres).query}'}';
}

/// Réponse scriptée du faux serveur.
class ReponseFausse {
  final int statut;
  final List<int> octets;
  /// En-têtes ; plusieurs valeurs d'un même en-tête (Set-Cookie) séparées par « \n ».
  final Map<String, String> entetes;

  /// Attente (horloge réelle) avant de répondre.
  final Duration delai;

  /// Ne répond jamais (la connexion reste ouverte jusqu'à l'arrêt du serveur) : délai dépassé côté application.
  final bool jamais;

  /// Réponse TRONQUÉE (tests réseau) : la longueur annoncée (Content-Length) dépasse le corps envoyé, puis la
  /// connexion est fermée au milieu du corps (coupure pendant le transfert).
  final bool tronquee;

  /// Connexion fermée sans aucune réponse (coupure en pleine requête).
  final bool coupee;

  const ReponseFausse._(this.statut, this.octets, this.entetes,
      {this.delai = Duration.zero, this.jamais = false, this.tronquee = false, this.coupee = false});

  static const _json = {'content-type': 'application/json; charset=utf-8'};

  /// Corps JSON (Map, List…) ou chaîne JSON déjà encodée.
  factory ReponseFausse.json(Object? corps, {int statut = 200, Map<String, String> entetes = const {}, Duration delai = Duration.zero}) =>
      ReponseFausse._(statut, utf8.encode(corps is String ? corps : jsonEncode(corps)), {..._json, ...entetes}, delai: delai);

  factory ReponseFausse.texte(String corps, {int statut = 200, String type = 'text/html; charset=utf-8', Duration delai = Duration.zero}) =>
      ReponseFausse._(statut, utf8.encode(corps), {'content-type': type}, delai: delai);

  factory ReponseFausse.octets(List<int> octets, {required String type, int statut = 200, Map<String, String> entetes = const {}}) =>
      ReponseFausse._(statut, octets, {'content-type': type, ...entetes});

  /// Réponse vide (200, aucun contenu) : Prestige l'utilise pour « aucune licence ».
  factory ReponseFausse.vide({int statut = 200}) => ReponseFausse._(statut, const [], const {});

  /// Refus métier de Prestige : HTTP 200 {success:false, message:…}.
  factory ReponseFausse.refus(String message) => ReponseFausse.json({'success': false, 'message': message});

  /// Session expirée : HTTP 401 « Veuillez vous connecter ».
  factory ReponseFausse.sessionExpiree() => ReponseFausse.texte('Veuillez vous connecter', statut: 401);

  /// Session expirée signalée en 200 {success:false, message:"Veuillez vous connecter"} (certains services).
  factory ReponseFausse.sessionExpireeEn200() => ReponseFausse.json({'success': false, 'message': 'Veuillez vous connecter'});

  /// Erreur interne (500) avec une page HTML technique qui ne doit jamais être affichée.
  factory ReponseFausse.erreurServeur({int statut = 500}) =>
      ReponseFausse.texte('<html><body>java.lang.NullPointerException at com.fictif.Ressource</body></html>', statut: statut);

  /// Application Prestige absente à cette adresse (404).
  factory ReponseFausse.introuvable() => ReponseFausse.texte('<html>Not Found</html>', statut: 404);

  /// Réponse retardée de [delai] (horloge réelle ; horloge simulée avec [FauxServeurPrestige.clientMemoire]).
  ReponseFausse apres(Duration delai) => ReponseFausse._(statut, octets, entetes, delai: delai, tronquee: tronquee, coupee: coupee);

  /// Corps [corps] coupé pendant le transfert : longueur annoncée non atteinte, connexion fermée (tests réseau).
  factory ReponseFausse.tronquee(String corps) =>
      ReponseFausse._(200, utf8.encode(corps), const {'content-type': 'application/json; charset=utf-8'}, tronquee: true);

  /// Connexion fermée par le serveur avant toute réponse (tests réseau).
  factory ReponseFausse.coupee() => const ReponseFausse._(200, [], {}, coupee: true);

  /// Ne répond jamais.
  factory ReponseFausse.sansReponse() => const ReponseFausse._(200, [], {}, jamais: true);
}

typedef RouteFausse = FutureOr<ReponseFausse> Function(RequeteRecue requete);

class FauxServeurPrestige {
  static const application = 'prestige';

  HttpServer? _serveur;
  final _routes = <String, RouteFausse>{};
  final _enAttente = <HttpRequest>{};

  /// Requêtes reçues, dans l'ordre.
  final requetes = <RequeteRecue>[];

  /// Exige un JSESSIONID valide sur les routes privées (comme Prestige).
  bool controlerSession = true;

  /// Routes accessibles sans session (préfixes).
  final routesPubliques = <String>{'/licence/', '/user/auth', '/officine', '/espace-produit/'};

  /// Réponse d'une route privée sans session valide.
  RouteFausse reponseSansSession = (_) => ReponseFausse.sessionExpiree();

  /// Réponse des routes non scriptées (liste vide de Prestige).
  RouteFausse parDefaut = (_) => ReponseFausse.json(DonneesFictives.listeVide());

  final _sessions = <String>{};
  int _numeroSession = 0;
  int _codesServis = 0;

  /// Dernier cookie de session délivré (« JSESSIONID=fictif-… »).
  String? derniereSession;

  FauxServeurPrestige() {
    installerRoutesParDefaut();
  }

  int get port => _serveur?.port ?? (throw StateError('Faux serveur non démarré'));
  bool get demarre => _serveur != null;

  /// Servi en HTTPS ([demarrerSecurise]) ?
  bool https = false;

  /// « http://127.0.0.1:port/prestige » (« https://… » si [demarrerSecurise]).
  String get racine => '${https ? 'https' : 'http'}://127.0.0.1:$port/$application';

  /// Préférences qui font viser ce serveur par l'application (même format que la Configuration IP).
  Map<String, Object> preferencesApp({Map<String, Object> autres = const {}}) => {
        'local_ip': https ? 'https://127.0.0.1' : '127.0.0.1',
        'port_key': '$port',
        'app_name_key': application,
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

  // --- Scénario ---

  /// Route scriptée : [chemin] exact après /api/v1 (ex. « /info ») ; [methode] null = toutes les méthodes
  /// (remplace alors aussi les routes de ce chemin déjà définies pour une méthode précise).
  void route(String chemin, RouteFausse reponse, {String? methode}) {
    if (methode == null) _routes.removeWhere((cle, _) => cle.endsWith(' $chemin'));
    _routes['${methode ?? '*'} $chemin'] = reponse;
  }

  /// Raccourci : réponse fixe.
  void quand(String chemin, ReponseFausse reponse, {String? methode}) => route(chemin, (_) => reponse, methode: methode);

  /// Toutes les sessions deviennent invalides (session expirée côté serveur).
  void expirerSessions() => _sessions.clear();

  /// Remet à zéro le journal des requêtes.
  void oublierRequetes() => requetes.clear();

  /// Requêtes reçues sur [chemin].
  Iterable<RequeteRecue> recues(String chemin, {String? methode}) =>
      requetes.where((r) => r.chemin == chemin && (methode == null || r.methode == methode));

  void installerRoutesParDefaut() {
    _routes.clear();
    quand('/licence/find', ReponseFausse.json(DonneesFictives.licenceValide()), methode: 'GET');
    route('/user/auth', _authentifier, methode: 'POST');
    route('/user/logout', (r) {
      final s = r.sessionEnvoyee;
      if (s != null) _sessions.remove(s);
      return ReponseFausse.json({'success': true});
    }, methode: 'POST');
    quand('/officine', ReponseFausse.json(DonneesFictives.officine()), methode: 'GET');
    // Liste des fournisseurs : tableau JSON (l'écran Fournisseurs refuse tout autre format).
    quand('/fournisseurs', ReponseFausse.json(const <Object>[]), methode: 'GET');
    route('/info', (r) => ReponseFausse.json(_filtrer(DonneesFictives.articlesAnalyse(), 'libelle', r.parametres['search'])), methode: 'GET');
    // Recherche « contient » (EspaceProduitRessource.rechercher : route publique, 2 caractères, 50 au plus), 3.9.0.
    route('/espace-produit/recherche', (r) => ReponseFausse.json(DonneesFictives.rechercheProduit(r.parametres['q'])), methode: 'GET');
    route('/checkproduit', (r) => ReponseFausse.json(_filtrer(DonneesFictives.produitsFiche(), 'familleLibelle', r.parametres['nompdt'])),
        methode: 'GET');
    route('/rh/presence', (r) => ReponseFausse.json(DonneesFictives.presenceDuJour(r.parametres['jour'] ?? '2026-10-13')), methode: 'GET');
    route('/rh/tableau', (r) => ReponseFausse.json(DonneesFictives.tableauPresences(r.parametres['du'] ?? '', r.parametres['au'] ?? '')),
        methode: 'GET');
    quand('/rh/droits', ReponseFausse.json({'success': true, 'valider': true}), methode: 'GET');
    route('/rh/mobile/code', (_) => ReponseFausse.json(DonneesFictives.codePointage(_codesServis++)), methode: 'GET');
    quand('/rh/mobile/terminaux', ReponseFausse.json(DonneesFictives.terminaux()), methode: 'GET');
    // Détail Mobile Money du Détail CA (appel complémentaire, au premier dépliage seulement).
    quand('/stats-recette-caisse/modes', ReponseFausse.json(DonneesFictives.modesPaiement()), methode: 'GET');
    installerRoutesVague1(this);
    installerRoutesVague2(this);
    installerRoutesVague3(this);
  }

  static List<Map<String, Object?>> _filtrer(List<Map<String, Object?>> liste, String champ, String? recherche) {
    final q = (recherche ?? '').trim().toLowerCase();
    if (q.isEmpty) return liste;
    return [for (final e in liste) if ('${e[champ]}'.toLowerCase().contains(q) || '${e['codeCip'] ?? e['familleCip']}'.contains(q)) e];
  }

  ReponseFausse _authentifier(RequeteRecue r) {
    final corps = r.json;
    final ok = corps is Map && corps['login'] == DonneesFictives.identifiant && corps['password'] == DonneesFictives.motDePasse;
    if (!ok) return ReponseFausse.refus(DonneesFictives.messageIdentifiantsIncorrects);
    // Comme Prestige : nouvelle session à chaque connexion ; un autre cookie peut arriver dans le même en-tête.
    final session = 'JSESSIONID=fictif-${++_numeroSession}';
    _sessions.add(session);
    derniereSession = session;
    return ReponseFausse.json(DonneesFictives.utilisateur(), entetes: {'set-cookie': '$session; Path=/$application; HttpOnly'});
  }

  // --- Traitement ---

  /// Mode « en mémoire » ([clientMemoire]) : le serveur est éteint (connexion refusée).
  bool coupe = false;

  /// Client HTTP « en mémoire » : mêmes routes, mêmes contrôles et même journal que le serveur réseau, sans
  /// socket. Pour les tests qui avancent l'horloge simulée (ergonomie, délais) ; les tests e2e utilisent le
  /// vrai serveur ([demarrer] + http.Client()).
  http.Client clientMemoire() => MockClient((req) async {
        if (coupe) throw const SocketException('Connection refused');
        final r = await repondre(req.method, req.url, req.headers['cookie'], req.body);
        if (r.jamais) return Completer<http.Response>().future;
        if (r.delai > Duration.zero) await Future<void>.delayed(r.delai);
        // Même exception que le client HTTP réel (IOClient) quand la connexion se ferme avant / pendant le corps.
        if (r.coupee) throw http.ClientException('Connection closed before full header was received', req.url);
        if (r.tronquee) throw http.ClientException('Connection closed while receiving data', req.url);
        // Plusieurs en-têtes de même nom : réunis par « , » (comme le fait package:http).
        return http.Response.bytes(r.octets, r.statut, headers: r.entetes.map((k, v) => MapEntry(k, v.replaceAll('\n', ', '))), request: req);
      });

  /// Réponse du faux serveur à une requête (commune au serveur réseau et au client en mémoire).
  Future<ReponseFausse> repondre(String methode, Uri uri, String? cookie, String corps) async {
    final m = RegExp('^/$application/api/(v1|v3)(/.*)\$').firstMatch(uri.path);
    if (m == null) return ReponseFausse.introuvable();
    final requete = RequeteRecue(methode, Uri.decodeComponent(m.group(2)!), m.group(1)!, uri.queryParameters, cookie, corps);
    requetes.add(requete);
    final publique = routesPubliques.any((p) => requete.chemin.startsWith(p));
    if (controlerSession && !publique && !_sessions.contains(requete.sessionEnvoyee)) {
      return reponseSansSession(requete);
    }
    final route = _routes['$methode ${requete.chemin}'] ?? _routes['* ${requete.chemin}'] ?? parDefaut;
    return route(requete);
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
