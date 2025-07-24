// lib/ui_helpers/base_screen_logic.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

// Un mixin qui fournit des fonctionnalités de base pour les écrans, Gestion commune des elements communs aux ecrans
mixin BaseScreenLogic<T extends StatefulWidget> on State<T> {
  final ApiService apiService = ApiService();
  bool isLoading = false;
  String? errorMessage;

  // Méthode générique pour exécuter des appels API en toute sécurité
  Future<dynamic> safeApiCall(Future<dynamic> Function() apiCall, {String? customErrorMessage}) async {
    if (!mounted) return null;

    // Démarre le chargement et efface les anciennes erreurs
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Exécute l'appel API fourni
      final data = await apiCall();
      return data;
    } catch (e) {
      if (mounted) {
        setState(() {
          // Affiche un message d'erreur personnalisé ou le message d'erreur de l'API
          errorMessage = customErrorMessage ?? 'Erreur: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
      return null; // Retourne null en cas d'erreur
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Un raccourci spécifique pour les appels GET qui inclut la gestion de session
  Future<dynamic> apiGet(String endpoint, {Map<String, String>? queryParams}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Utilise la méthode générique 'safeApiCall' pour envelopper l'appel 'get'
    return safeApiCall(
            () => apiService.get(
          context,
          endpoint,
          queryParams: queryParams,
          onSessionInvalid: () => authProvider.forceLogout(),
        )
    );
  }

  // --- AJOUT: Raccourci pour les appels DELETE ---
  Future<dynamic> apiDelete(String endpoint) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return safeApiCall(
            () => apiService.delete(
          context,
          endpoint,
          onSessionInvalid: () => authProvider.forceLogout(),
        )
    );
  }

// Vous pouvez ajouter des raccourcis similaires pour POST, PUT, etc. si nécessaire
// Future<dynamic> apiPost(String endpoint, Map<String, dynamic> body) { ... }
}
