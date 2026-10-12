// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import '../providers/ip_config_provider.dart';
import 'journal_app.dart';
import 'stockage_securise.dart';
import '../utils/adresse_serveur.dart';
import '../utils/constants.dart';
// Assurez-vous que ces fichiers existent bien dans votre projet
import '../models/common_data_model.dart';
import '../models/etat_stock_article_model.dart';
import '../models/suivi_peremption_model.dart';
import '../models/licence_model.dart';
import '../models/bon_livraison_model.dart';
import '../models/licence_lookup.dart';

export '../models/licence_lookup.dart';

/// Nature d'un échec d'appel au serveur (≠ liste vide).
enum NatureErreur {
  /// Aucun serveur ne répond (Wi-Fi, données mobiles, adresse, serveur éteint).
  reseau,

  /// Le serveur n'a pas répondu à temps.
  delai,

  /// Erreur interne du serveur (HTTP 5xx).
  serveur,

  /// Session expirée (HTTP 401 ou « Veuillez vous connecter ») : reconnexion.
  session,

  /// Droit manquant (HTTP 403).
  droit,

  /// Demande refusée (autre code HTTP 4xx).
  refus,

  /// Réponse illisible.
  reponse,
}

/// Échec de chargement (à distinguer d'une liste vide). Même nom et même usage que dans prestige_vente_app.
class ApiLoadException implements Exception {
  final String message;
  final NatureErreur nature;
  final int? code;
  const ApiLoadException(this.message, {this.nature = NatureErreur.reseau, this.code});

  static const messageReseau = 'Serveur injoignable. Vérifiez le Wi-Fi ou les données mobiles puis réessayez.';
  static const messageDelai = 'Le serveur met trop de temps à répondre. Vérifiez le réseau puis réessayez.';
  static const messageSession = 'Session expirée. Reconnectez-vous.';
  static const messageDroit = 'Accès refusé : ce compte n\'a pas le droit de consulter ces données.';
  static const messageReponse = 'Réponse inattendue du serveur.';
  static const messageCertificat = 'Connexion sécurisée (HTTPS) impossible : certificat du serveur refusé.';
  static const messageAdresse = 'Adresse du serveur incorrecte. Vérifiez la configuration.';

  /// Même échec, précisé par ce qui n'a pas pu être chargé (« … (rayons non chargés) »).
  ApiLoadException pour(String quoi) {
    switch (nature) {
      case NatureErreur.reseau:
        return ApiLoadException(message == messageReseau
            ? 'Serveur injoignable ($quoi non chargés). Vérifiez le Wi-Fi ou les données mobiles puis réessayez.'
            : message, nature: nature, code: code);
      case NatureErreur.delai:
        return ApiLoadException('Le serveur met trop de temps à répondre ($quoi non chargés). Vérifiez le réseau puis réessayez.',
            nature: nature, code: code);
      case NatureErreur.serveur:
        return ApiLoadException('Erreur du serveur (code $code) lors du chargement des $quoi.', nature: nature, code: code);
      case NatureErreur.session:
      case NatureErreur.droit:
      case NatureErreur.refus:
      case NatureErreur.reponse:
        return this;
    }
  }

  @override
  String toString() => message;
}

class ApiService {
  ApiService._privateConstructor();
  static final ApiService _instance = ApiService._privateConstructor();
  factory ApiService() {
    return _instance;
  }

  String? _sessionCookie;

  /// Client HTTP (remplaçable dans les tests par un `MockClient` de package:http/testing.dart).
  static http.Client client = http.Client();

  // --- INFRASTRUCTURE DE BASE ---

  static Future<bool> ping(String ip, String port, String appName) async {
    if (ip.trim().isEmpty) {
      return false;
    }
    // Adresse avec ou sans protocole (« https://… » accepté, HTTP par défaut).
    final url = Uri.parse(AdresseServeur.racine(ip, port, appName));
    try {
      await client.head(url).timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      JournalApp.debug('Test de connexion échoué (${JournalApp.requete('HEAD', url)}) : ${e.runtimeType}');
      return false;
    }
  }

  // Cookie de session : stockage sécurisé (migration transparente de l'ancienne clé en clair
  // `session_cookie`, repli sans perte si le stockage sûr échoue) — voir stockage_securise.dart.
  Future<void> loadSessionCookie() async {
    _sessionCookie = await CookieSecurise.instance.lire();
  }

  Future<void> setSessionCookie(String rawCookie) async {
    if (rawCookie.contains(';')) {
      _sessionCookie = rawCookie.substring(0, rawCookie.indexOf(';'));
    } else {
      _sessionCookie = rawCookie;
    }
    await CookieSecurise.instance.ecrire(_sessionCookie!);
  }

  Future<void> clearSessionCookie() async {
    _sessionCookie = null;
    await CookieSecurise.instance.effacer();
  }

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    };
    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }
    return headers;
  }

  // --- MÉTHODES GÉNÉRIQUES HTTP ---
  //
  // Tout échec lève une [ApiLoadException] dont la [NatureErreur] distingue : serveur injoignable,
  // délai dépassé, erreur du serveur (5xx), session expirée (401 → reconnexion), droit manquant (403),
  // demande refusée (autre 4xx) et réponse illisible. Une réponse vide ou une liste vide n'est JAMAIS
  // une erreur : c'est une vraie absence de données. Les messages reprennent ceux de prestige_vente_app.

  static const delaiPost = Duration(seconds: 20);
  static const delaiGet = Duration(seconds: 45);

  /// Appelé à chaque session expirée détectée (en plus du `onSessionInvalid` de l'appel) :
  /// AuthProvider s'y abonne pour revenir à l'écran de connexion, même depuis un écran qui ne passe pas
  /// de `onSessionInvalid`.
  static VoidCallback? surSessionExpiree;

  Future<Map<String, dynamic>> post(BuildContext context, String endpoint, Map<String, dynamic> body, {VoidCallback? onSessionInvalid}) async {
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    final url = Uri.parse('${ipProvider.activeBaseUrl}$endpoint');
    JournalApp.debug(JournalApp.requete('POST', url));

    final response = await _envoyer(() => client.post(url, headers: _getHeaders(), body: jsonEncode(body)), delaiPost);
    if (endpoint == AppConstants.authEndpoint && response.headers['set-cookie'] != null) {
      await setSessionCookie(response.headers['set-cookie']!);
    }
    final decoded = _handleResponse(response, onSessionInvalid);
    if (decoded == null) return <String, dynamic>{};
    if (decoded is! Map<String, dynamic>) {
      throw const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse);
    }
    return decoded;
  }

  Future<dynamic> get(BuildContext context, String endpoint, {Map<String, String>? queryParams, VoidCallback? onSessionInvalid}) async {
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    var uri = Uri.parse('${ipProvider.activeBaseUrl}$endpoint');

    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }
    JournalApp.debug(JournalApp.requete('GET', uri));
    final response = await _envoyer(() => client.get(uri, headers: _getHeaders()), delaiGet);
    return _handleResponse(response, onSessionInvalid);
  }

  Future<dynamic> getV3(BuildContext context, String endpoint, {Map<String, String>? queryParams, VoidCallback? onSessionInvalid}) async {
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    final baseUrl = ipProvider.activeBaseUrlV3;

    var uri = Uri.parse('$baseUrl$endpoint');

    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }
    JournalApp.debug(JournalApp.requete('GET', uri));
    final response = await _envoyer(() => client.get(uri, headers: _getHeaders()), delaiGet);
    return _handleResponse(response, onSessionInvalid);
  }

  Future<Map<String, dynamic>> delete(BuildContext context, String endpoint, {VoidCallback? onSessionInvalid}) async {
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    final baseUrl = ipProvider.activeBaseUrl;
    final url = Uri.parse('$baseUrl$endpoint');
    JournalApp.debug(JournalApp.requete('DELETE', url));

    final response = await _envoyer(() => client.delete(url, headers: _getHeaders()), delaiGet);
    final decoded = _handleResponse(response, onSessionInvalid);
    if (decoded == null) return <String, dynamic>{};
    if (decoded is! Map<String, dynamic>) {
      throw const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse);
    }
    return decoded;
  }

  /// Envoie la requête ; les échecs réseau et les délais deviennent des [ApiLoadException].
  static Future<http.Response> _envoyer(Future<http.Response> Function() requete, Duration delai) async {
    try {
      return await requete().timeout(delai);
    } on TimeoutException {
      throw const ApiLoadException(ApiLoadException.messageDelai, nature: NatureErreur.delai);
    } on HandshakeException {
      throw const ApiLoadException(ApiLoadException.messageCertificat, nature: NatureErreur.reseau);
    } on SocketException {
      throw const ApiLoadException(ApiLoadException.messageReseau, nature: NatureErreur.reseau);
    } on http.ClientException {
      throw const ApiLoadException(ApiLoadException.messageReseau, nature: NatureErreur.reseau);
    } on HttpException {
      throw const ApiLoadException(ApiLoadException.messageReseau, nature: NatureErreur.reseau);
    } on ArgumentError {
      // Adresse du serveur mal formée.
      throw const ApiLoadException(ApiLoadException.messageAdresse, nature: NatureErreur.reseau);
    }
  }

  dynamic _handleResponse(http.Response response, VoidCallback? onSessionInvalid) {
    final code = response.statusCode;
    if (code == 401 || (code != 200 && response.body.contains("Veuillez vous connecter"))) {
      _sessionExpiree(onSessionInvalid);
    }
    if (code == 403) {
      JournalApp.debug('Accès refusé HTTP 403');
      throw const ApiLoadException(ApiLoadException.messageDroit, nature: NatureErreur.droit, code: 403);
    }

    if (code >= 200 && code < 300) {
      if (response.body.trim().isEmpty) return null;
      final dynamic decodedBody;
      try {
        // Décodage UTF8 manuel pour éviter les problèmes d'accent
        decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        JournalApp.debug('Réponse illisible (JSON incorrect)');
        throw const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse);
      }
      // Certains services répondent 200 avec success:false « Veuillez vous connecter ».
      if (decodedBody is Map &&
          decodedBody['success'] == false &&
          (decodedBody['message'] == 'Veuillez vous connecter' || decodedBody['msg'] == 'Veuillez vous connecter')) {
        _sessionExpiree(onSessionInvalid);
      }
      return decodedBody;
    }
    JournalApp.debug('Erreur serveur HTTP $code');
    if (code >= 500) {
      throw ApiLoadException('Erreur du serveur (code $code). Réessayez dans un instant.', nature: NatureErreur.serveur, code: code);
    }
    throw ApiLoadException('Le serveur a refusé la demande (code $code).', nature: NatureErreur.refus, code: code);
  }

  Never _sessionExpiree(VoidCallback? onSessionInvalid) {
    // D'abord le traitement global (déconnexion AVEC message), puis celui de l'appel.
    surSessionExpiree?.call();
    onSessionInvalid?.call();
    throw const ApiLoadException(ApiLoadException.messageSession, nature: NatureErreur.session, code: 401);
  }

  /// Liste `{data: [...]}` ou `[...]` : une liste vide n'est renvoyée que si le serveur a bien répondu ;
  /// tout échec lève [ApiLoadException] (≠ « aucun résultat »), précisé par [quoi].
  static List<T> _liste<T>(dynamic response, String quoi, T Function(Map<String, dynamic>) parse) {
    if (response == null) return <T>[];
    final dynamic data = response is Map ? (response['data'] ?? response['items']) : response;
    if (data == null) return <T>[];
    if (data is! List) throw ApiLoadException('Réponse inattendue du serveur pour les $quoi.', nature: NatureErreur.reponse);
    try {
      return [for (final e in data) parse(Map<String, dynamic>.from(e as Map))];
    } catch (_) {
      throw ApiLoadException('Données des $quoi illisibles.', nature: NatureErreur.reponse);
    }
  }

  /// Exécute [appel] ; un échec est requalifié avec [quoi] (« … ($quoi non chargés) »).
  static Future<T> _charger<T>(String quoi, Future<T> Function() appel) async {
    try {
      return await appel();
    } on ApiLoadException catch (e) {
      throw e.pour(quoi);
    }
  }

  // --- MÉTHODES MÉTIER SPÉCIFIQUES (ETAT DE STOCK) ---

  // Récupérer la liste des rayons (Emplacements). Échec : ApiLoadException (≠ liste vide).
  Future<List<CommonData>> getRayons(BuildContext context) => _charger('rayons', () async {
        final response = await get(context, '/common/rayons', queryParams: {'limit': '9999', 'page': '1', 'start': '0'});
        return _liste(response, 'rayons', CommonData.fromJson);
      });

  // Récupérer la liste des grossistes. Échec : ApiLoadException (≠ liste vide).
  Future<List<CommonData>> getGrossistes(BuildContext context) => _charger('grossistes', () async {
        final response = await get(context, '/common/grossiste', queryParams: {'limit': '9999', 'page': '1', 'start': '0'});
        return _liste(response is Map ? {'data': response['data']} : response, 'grossistes', CommonData.fromJson);
      });

  // Recherche avec filtres multiples (Stock, Rayon, Query)
  Future<Map<String, dynamic>> getEtatStockArticles(
      BuildContext context, {
        String query = '',
        String codeRayon = '',
        String codeGrossiste = '',
        String stock = '',
        String filtreStock = '',
        int page = 1,
        int limit = 15,
      }) => _charger('articles', () async {
        final response = await get(
          context,
          '/fichearticle/comparaison',
          queryParams: {
            'query': query,
            'codeRayon': codeRayon,
            'codeGrossiste': codeGrossiste,
            'seuil': '',
            'stock': stock,
            'filtreSeuil': '',
            'filtreStock': filtreStock,
            'codeFamile': '',
            'page': page.toString(),
            'start': ((page - 1) * limit).toString(),
            'limit': limit.toString(),
          },
        );
        if (response == null) return {'total': 0, 'data': <EtatStockArticleModel>[]};
        if (response is! Map) throw const ApiLoadException('Réponse inattendue du serveur pour les articles.', nature: NatureErreur.reponse);
        return {
          'total': response['total'] ?? 0,
          'data': _liste(response, 'articles', EtatStockArticleModel.fromJson),
        };
      });

  // --- GESTION PEREMPTION --- (échec : ApiLoadException ; réponse vide du serveur : null = aucun produit)
  Future<SuiviPeremptionResponse?> getSuiviPeremption(
      BuildContext context, {
        String query = '',
        String nbreMois = '',
        String codeRayon = '',
        String codeGrossiste = '',
        String dtStart = '',
        String dtEnd = '',
        int page = 1,
        int limit = 20,
      }) => _charger('produits périmés', () async {
        final response = await get(
          context,
          AppConstants.suiviPeremptionEndpoint,
          queryParams: {
            'query': query,
            'nbreMois': nbreMois,
            'codeRayon': codeRayon,
            'codeGrossiste': codeGrossiste,
            'dtStart': dtStart,
            'dtEnd': dtEnd,
            'page': page.toString(),
            'start': ((page - 1) * limit).toString(),
            'limit': limit.toString(),
          },
        );
        if (response == null) return null;
        if (response is! Map<String, dynamic>) {
          throw const ApiLoadException('Réponse inattendue du serveur pour les produits périmés.', nature: NatureErreur.reponse);
        }
        try {
          return SuiviPeremptionResponse.fromJson(response);
        } catch (_) {
          throw const ApiLoadException('Données des produits périmés illisibles.', nature: NatureErreur.reponse);
        }
      });

  // --- GESTION LICENCE ---

  /// Vérification de licence qui distingue la cause d'un échec (même principe que prestige_vente_app) :
  /// serveur injoignable / erreur du serveur ≠ licence absente (réponse vide du serveur) ≠ licence trouvée.
  Future<LicenceLookup> lookupLicence(BuildContext context) async {
    try {
      final response = await get(context, '/licence/find');
      if (response == null) return const LicenceLookup.noLicence();
      if (response is! Map<String, dynamic>) {
        return const LicenceLookup.failure(LicenceIssue.unexpectedResponse, 'Réponse inattendue du serveur.');
      }
      final licence = LicenceModel.fromJson(response);
      if (licence.id.isEmpty && licence.dateEnd.isEmpty) return const LicenceLookup.noLicence();
      return LicenceLookup.found(licence);
    } on ApiLoadException catch (e) {
      switch (e.nature) {
        case NatureErreur.reseau:
        case NatureErreur.delai:
          return LicenceLookup.failure(LicenceIssue.unreachable, e.message);
        case NatureErreur.refus:
          // 404 : l'application Prestige n'est pas déployée à cette adresse (nom ou port incorrect).
          return LicenceLookup.failure(e.code == 404 ? LicenceIssue.appNotFound : LicenceIssue.serverError, e.message);
        case NatureErreur.reponse:
          return LicenceLookup.failure(LicenceIssue.unexpectedResponse, e.message);
        case NatureErreur.serveur:
        case NatureErreur.session:
        case NatureErreur.droit:
          return LicenceLookup.failure(LicenceIssue.serverError, e.message);
      }
    }
  }

  // Vérifier la licence existante (ancienne méthode : null seulement si aucune licence ; échec : exception).
  Future<LicenceModel?> findLicence(BuildContext context) async {
    final r = await lookupLicence(context);
    if (r.isConnectionProblem) throw ApiLoadException(r.detail ?? ApiLoadException.messageReseau);
    return r.licence;
  }

  // Enregistrer une nouvelle licence
  // Note: L'URL demandée est /licence/save/{KEY}
  Future<bool> registerLicence(BuildContext context, String licenceKey) async {
    try {
      // GET (route serveur existante) : la clé fait partie de l'URL ; elle n'est jamais journalisée.
      final response = await get(
        context,
        '/licence/save/${Uri.encodeComponent(licenceKey)}',
      );

      // On suppose que l'API renvoie la licence ou un succès si ça marche
      return response != null;
    } on ApiLoadException catch (e) {
      JournalApp.debug('registerLicence : ${e.nature.name}');
      if (e.nature == NatureErreur.reseau || e.nature == NatureErreur.delai) throw e;
      throw const ApiLoadException("Clé de licence invalide ou erreur serveur.", nature: NatureErreur.refus);
    }
  }

  // 1. Récupérer les Bons de Livraison. Échec : ApiLoadException (≠ « aucun BL »).
  Future<Map<String, dynamic>> getBonLivraisons(
      BuildContext context, {
        String search = '',
        String grossisteId = '',
        String groupeId = '',
        String userId = '',
        String statut = '', // "checked" dans l'API
        String dtStart = '',
        String dtEnd = '',
        int page = 1,
        int limit = 20,
      }) => _charger('bons de livraison', () async {
        // Construction des paramètres de tri (codés en dur comme dans votre exemple)
        final sortParam = jsonEncode([{"property":"fournisseurId","direction":"ASC"}]);

        final response = await get(
          context,
          '/etat-control-bon/list',
          queryParams: {
            'search': search,
            'grossisteId': grossisteId,
            'groupeId': groupeId,
            'userId': userId,
            'checked': statut, // TERMINE, NON_TRAITE, etc.
            'dtStart': dtStart,
            'dtEnd': dtEnd,
            'page': page.toString(),
            'start': ((page - 1) * limit).toString(),
            'limit': limit.toString(),
            'group': sortParam,
            'sort': sortParam,
          },
        );
        if (response == null) return {'total': 0, 'data': <BonLivraisonModel>[]};
        if (response is! Map) throw const ApiLoadException('Réponse inattendue du serveur pour les bons de livraison.', nature: NatureErreur.reponse);
        return {
          'total': response['total'] ?? 0,
          'data': _liste(response, 'bons de livraison', BonLivraisonModel.fromJson),
        };
      });

  // 2. Récupérer les Groupes Grossistes. Échec : ApiLoadException (≠ liste vide).
  Future<List<CommonData>> getGroupeGrossistes(BuildContext context) => _charger('groupes de grossistes', () async {
        final response = await get(context, '/groupegrossiste', queryParams: {'limit': '9999'});
        return _liste(response is Map ? {'data': response['data']} : response, 'groupes de grossistes', CommonData.fromJson);
      });

  // 3. Récupérer les Utilisateurs. Échec : ApiLoadException (≠ liste vide).
  Future<List<CommonData>> getUsers(BuildContext context) => _charger('utilisateurs', () async {
        final response = await get(context, '/common/users', queryParams: {'limit': '9999'});
        // Mapping spécifique car l'API User renvoie "fullName" et "lgUSERID"
        return _liste(
          response is Map ? {'data': response['data']} : response,
          'utilisateurs',
          (e) => CommonData(id: e['lgUSERID']?.toString() ?? '', libelle: e['fullName']?.toString() ?? ''),
        );
      });

  // --- NOUVELLE MÉTHODE : TICKET Z / RECAP CAISSE ---
  Future<Map<String, dynamic>?> fetchTicketZ(BuildContext context, Map<String, dynamic> payload) async {
    try {
      // Utilisation du point de terminaison spécifié pour fetch-tickez
      final response = await post(context, '/caisse/fetch-tickez', payload);
      return response;
    } on ApiLoadException catch (e) {
      JournalApp.debug('fetchTicketZ : ${e.nature.name}');
      // Message précis (serveur injoignable, délai, session…) au lieu d'un message unique.
      throw e.pour('ticket Z');
    }
  }

}