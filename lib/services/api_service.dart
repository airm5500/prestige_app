// lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:provider/provider.dart'; // To read IpConfigProvider
import 'package:flutter/material.dart'; // For BuildContext
import '../providers/ip_config_provider.dart';

class ApiService {
  final BuildContext context; // Required to access IpConfigProvider

  ApiService(this.context);

  IpConfigProvider get _ipConfigProvider => Provider.of<IpConfigProvider>(context, listen: false);

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final baseUrl = _ipConfigProvider.activeBaseUrl;
    var uri = Uri.parse('$baseUrl$endpoint');

    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }

    if (kDebugMode) {
      print('API GET Request: $uri');
    }

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15)); // Added timeout
      return _handleResponse(response);
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('SocketException: ${e.toString()}');
      }
      throw Exception('Erreur de connexion: Vérifiez votre connexion réseau et la configuration IP/Port.');
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        print('ClientException: ${e.toString()}');
      }
      throw Exception('Erreur Client HTTP: ${e.message}');
    }
    catch (e) {
      if (kDebugMode) {
        print('Generic API Error: ${e.toString()}');
      }
      throw Exception('Une erreur inconnue est survenue: ${e.toString()}');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (kDebugMode) {
      print('API Response Status: ${response.statusCode}');
      // print('API Response Body: ${response.body}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null; // Or an empty list/map depending on expected output
      }
      try {
        return jsonDecode(utf8.decode(response.bodyBytes)); // Handle accents correctly
      } catch (e) {
        if (kDebugMode) {
          print('JSON Decode Error: ${e.toString()}');
          print('Problematic body: ${response.body}');
        }
        throw Exception('Réponse invalide du serveur.');
      }
    } else if (response.statusCode == 400) {
      throw Exception('Requête invalide (400): ${response.body}');
    } else if (response.statusCode == 401) {
      throw Exception('Non autorisé (401).');
    } else if (response.statusCode == 403) {
      throw Exception('Accès refusé (403).');
    } else if (response.statusCode == 404) {
      throw Exception('Ressource non trouvée (404).');
    } else if (response.statusCode >= 500) {
      throw Exception('Erreur serveur (${response.statusCode}): ${response.body}');
    } else {
      throw Exception('Erreur de communication avec le serveur (${response.statusCode}).');
    }
  }
}
