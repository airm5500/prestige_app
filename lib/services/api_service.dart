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
  // Singleton pattern pour s'assurer qu'il n'y a qu'une seule instance de ce service
  ApiService._privateConstructor();
  static final ApiService _instance = ApiService._privateConstructor();
  factory ApiService() {
    return _instance;
  }

  String? _sessionCookie;

  // --- NOUVELLE FONCTION PING STATIQUE ---
  // Peut être appelée de n'importe où, même sans une instance de ApiService.
  static Future<bool> ping(String ip, String port) async {
    if (ip.trim().isEmpty) {
      return false;
    }
    // On essaie juste de voir si le serveur répond à la racine
    final url = Uri.parse('http://$ip:$port');

    try {
      // http.head est léger car il ne télécharge que les en-têtes.
      // On utilise un délai court pour ne pas bloquer l'utilisateur.
      await http.head(url).timeout(const Duration(seconds: 5));
      return true; // Si la requête réussit, le serveur est accessible.
    } catch (e) {
      // Si une exception est levée (Timeout, SocketException, etc.), le serveur est injoignable.
      debugPrint("Ping to $url failed: $e");
      return false;
    }
  }

  Future<void> loadSessionCookie() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString(AppConstants.sessionCookieKey);
  }

  Future<void> setSessionCookie(String rawCookie) async {
    // Extrait uniquement la partie JSESSIONID du cookie
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
      final response = await http.get(uri, headers: _getHeaders()).timeout(const Duration(seconds: 15));
      return _handleResponse(response, onSessionInvalid);
    } on SocketException {
      throw Exception('Erreur de connexion. Vérifiez le réseau et la configuration IP.');
    } catch (e) {
      throw Exception('Une erreur inconnue est survenue: ${e.toString()}');
    }
  }

  dynamic _handleResponse(http.Response response, VoidCallback? onSessionInvalid) {
    // Si l'API renvoie une erreur 401 (Non autorisé), on déconnecte l'utilisateur.
    if (response.statusCode == 401) {
      onSessionInvalid?.call();
      throw Exception("Session invalide ou expirée. Veuillez vous reconnecter.");
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        final decodedBody = jsonDecode(utf8.decode(response.bodyBytes));

        // Gérer le cas où le succès est false dans la réponse, ce qui peut aussi indiquer une session invalide.
        if (decodedBody is Map<String, dynamic> && decodedBody['success'] == false && decodedBody['message'] == 'Veuillez vous connecter') {
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
