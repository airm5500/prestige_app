// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../providers/ip_config_provider.dart';
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._privateConstructor();
  static final ApiService _instance = ApiService._privateConstructor();
  factory ApiService() {
    return _instance;
  }

  String? _sessionCookie;

  // --- CORRECTION: La fonction ping accepte maintenant le nom de l'application ---
  static Future<bool> ping(String ip, String port, String appName) async {
    if (ip.trim().isEmpty) {
      return false;
    }
    // On construit l'URL de base pour le ping
    final url = Uri.parse('http://$ip:$port/$appName');

    try {
      // http.head est léger car il ne télécharge que les en-têtes.
      await http.head(url).timeout(const Duration(seconds: 5));
      return true; // Si la requête réussit, le serveur est accessible.
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

  // --- AJOUT: Nouvelle méthode pour les requêtes DELETE ---
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
        final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));
        if (decodedBody is Map<String, dynamic> && decodedBody['success'] == false && decodedBody.containsKey('message') && decodedBody['message'] == 'Veuillez vous connecter') {
          onSessionInvalid?.call();
          throw Exception("Session invalide ou expirée. Veuillez vous reconnecter.");
        }
        return decodedBody;
      } catch (e) {
        throw Exception('Réponse invalide du serveur.');
      }
    } else {
      throw Exception('Erreur du serveur (${response.statusCode}).');
    }
  }
}
