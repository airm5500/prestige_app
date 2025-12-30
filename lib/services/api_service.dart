// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/ip_config_provider.dart';
import '../utils/constants.dart';
// Assurez-vous que ces fichiers existent bien dans votre projet
import '../models/common_data_model.dart';
import '../models/etat_stock_article_model.dart';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService _instance = ApiService._privateConstructor();
  factory ApiService() {
    return _instance;
  }

  String? _sessionCookie;

  // --- INFRASTRUCTURE DE BASE ---

  static Future<bool> ping(String ip, String port, String appName) async {
    if (ip.trim().isEmpty) {
      return false;
    }
    final url = Uri.parse('http://$ip:$port/$appName');
    try {
      await http.head(url).timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint("Ping to $url failed: $e");
      return false;
    }
  }

  Future<void> loadSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString(AppConstants.sessionCookieKey);
  }

  Future<void> setSessionCookie(String rawCookie) async {
    if (rawCookie.contains(';')) {
      _sessionCookie = rawCookie.substring(0, rawCookie.indexOf(';'));
    } else {
      _sessionCookie = rawCookie;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.sessionCookieKey, _sessionCookie!);
  }

  Future<void> clearSessionCookie() async {
    _sessionCookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.sessionCookieKey);
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

  Future<Map<String, dynamic>> post(BuildContext context, String endpoint, Map<String, dynamic> body, {VoidCallback? onSessionInvalid}) async {
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    final url = Uri.parse('${ipProvider.activeBaseUrl}$endpoint');
    debugPrint('API POST Request: $url');

    try {
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 20));

      if (endpoint == AppConstants.authEndpoint && response.headers['set-cookie'] != null) {
        await setSessionCookie(response.headers['set-cookie']!);
      }

      return _handleResponse(response, onSessionInvalid);
    } on SocketException {
      throw Exception('Erreur de connexion. Vérifiez le réseau et la configuration IP.');
    } catch (e) {
      throw Exception('Une erreur inconnue est survenue: ${e.toString()}');
    }
  }

  Future<dynamic> get(BuildContext context, String endpoint, {Map<String, String>? queryParams, VoidCallback? onSessionInvalid}) async {
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    var uri = Uri.parse('${ipProvider.activeBaseUrl}$endpoint');

    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }
    debugPrint('API GET Request: $uri');

    try {
      final response = await http.get(uri, headers: _getHeaders()).timeout(const Duration(seconds: 45));
      return _handleResponse(response, onSessionInvalid);
    } on SocketException {
      throw Exception('Erreur de connexion. Vérifiez le réseau et la configuration IP.');
    } catch (e) {
      throw Exception('Une erreur inconnue est survenue: ${e.toString()}');
    }
  }

  Future<dynamic> getV3(BuildContext context, String endpoint, {Map<String, String>? queryParams, VoidCallback? onSessionInvalid}) async {
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    final ip = ipProvider.useLocalIp ? ipProvider.localIp : ipProvider.remoteIp;
    final port = ipProvider.port;
    final appName = ipProvider.appName;
    final baseUrl = 'http://$ip:$port/$appName${AppConstants.apiV3BasePath}';

    var uri = Uri.parse('$baseUrl$endpoint');

    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }
    debugPrint('API GET V3 Request: $uri');

    try {
      final response = await http.get(uri, headers: _getHeaders()).timeout(const Duration(seconds: 45));
      return _handleResponse(response, onSessionInvalid);
    } on SocketException {
      throw Exception('Erreur de connexion. Vérifiez le réseau et la configuration IP.');
    } catch (e) {
      throw Exception('Une erreur inconnue est survenue: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> delete(BuildContext context, String endpoint, {VoidCallback? onSessionInvalid}) async {
    final ipProvider = Provider.of<IpConfigProvider>(context, listen: false);
    final baseUrl = ipProvider.activeBaseUrl;
    final url = Uri.parse('$baseUrl$endpoint');
    debugPrint('API DELETE Request: $url');

    try {
      final response = await http.delete(
        url,
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 45));

      return _handleResponse(response, onSessionInvalid);
    } on SocketException {
      throw Exception('Erreur de connexion. Vérifiez le réseau et la configuration IP.');
    } on TimeoutException {
      throw Exception('Le serveur n\'a pas répondu à temps. Veuillez réessayer.');
    } catch (e) {
      throw Exception('Une erreur inconnue est survenue: ${e.toString()}');
    }
  }

  dynamic _handleResponse(http.Response response, VoidCallback? onSessionInvalid) {
    if (response.statusCode == 401 || (response.body.contains("Veuillez vous connecter") && response.statusCode != 200)) {
      onSessionInvalid?.call();
      throw Exception("Session invalide ou expirée. Veuillez vous reconnecter.");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        // Décodage UTF8 manuel pour éviter les problèmes d'accent
        final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));

        // Vérification spécifique de certains backends qui renvoient 200 OK mais success:false
        if (decodedBody is Map<String, dynamic> &&
            decodedBody['success'] == false &&
            decodedBody.containsKey('message') &&
            decodedBody['message'] == 'Veuillez vous connecter') {
          onSessionInvalid?.call();
          throw Exception("Session invalide ou expirée. Veuillez vous reconnecter.");
        }
        return decodedBody;
      } catch (e) {
        debugPrint("Erreur de décodage JSON: $e");
        throw Exception('Réponse invalide du serveur (JSON incorrect).');
      }
    } else {
      debugPrint("Erreur Serveur ${response.statusCode}: ${response.body}");
      throw Exception('Erreur du serveur (${response.statusCode}).');
    }
  }

  // --- MÉTHODES MÉTIER SPÉCIFIQUES (ETAT DE STOCK) ---

  // Récupérer la liste des rayons (Emplacements)
  Future<List<CommonData>> getRayons(BuildContext context) async {
    try {
      debugPrint("--- [ApiService] APPEL API RAYONS ---");
      final response = await get(
        context,
        '/common/rayons',
        queryParams: {
          'limit': '9999',
          'page': '1',
          'start': '0',
        },
      );

      debugPrint("--- [ApiService] Réponse Rayons brute: $response");

      if (response != null) {
        List<dynamic> listData = [];

        // Gestion robuste des différents formats de réponse possibles
        if (response is List) {
          listData = response;
        } else if (response is Map<String, dynamic>) {
          if (response.containsKey('data') && response['data'] is List) {
            listData = response['data'];
          } else if (response.containsKey('items') && response['items'] is List) {
            listData = response['items'];
          }
        }

        debugPrint("--- [ApiService] Nombre de rayons trouvés: ${listData.length}");
        return listData.map((e) => CommonData.fromJson(e)).toList();
      }
      return [];
    } catch (e, stackTrace) {
      debugPrint('ERREUR CRITIQUE getRayons: $e');
      debugPrint('Stacktrace: $stackTrace');
      return [];
    }
  }

  // Récupérer la liste des grossistes
  Future<List<CommonData>> getGrossistes(BuildContext context) async {
    try {
      final response = await get(
        context,
        '/common/grossiste',
        queryParams: {
          'limit': '9999',
          'page': '1',
          'start': '0',
        },
      );

      if (response != null) {
        List<dynamic> listData = [];
        if (response is List) {
          listData = response;
        } else if (response is Map<String, dynamic>) {
          if (response.containsKey('data') && response['data'] is List) {
            listData = response['data'];
          }
        }
        return listData.map((e) => CommonData.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Erreur getGrossistes: $e');
      return [];
    }
  }

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
      }) async {
    try {
      debugPrint("--- [ApiService] RECHERCHE STOCK --- Query: '$query', Rayon: '$codeRayon', Stock: '$stock', Op: '$filtreStock'");

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

      // On ne loggue pas tout l'objet s'il est énorme, juste un aperçu ou la taille
      if (response != null && response is Map<String, dynamic>) {
        final rawList = response['data'];
        final total = response['total'] ?? 0;

        debugPrint("--- [ApiService] Réponse Stock: Total=$total");

        List<EtatStockArticleModel> data = [];
        if (rawList is List) {
          debugPrint("--- [ApiService] Nombre d'articles dans la page: ${rawList.length}");
          data = rawList.map((e) => EtatStockArticleModel.fromJson(e)).toList();
        } else {
          debugPrint("--- [ApiService] Attention: 'data' n'est pas une liste.");
        }

        return {
          'total': total,
          'data': data,
        };
      } else {
        debugPrint("--- [ApiService] Réponse Stock vide ou format incorrect: $response");
      }

      return {'total': 0, 'data': <EtatStockArticleModel>[]};
    } catch (e, stackTrace) {
      debugPrint('ERREUR CRITIQUE getEtatStockArticles: $e');
      debugPrint('Stacktrace: $stackTrace');
      throw e;
    }
  }
}