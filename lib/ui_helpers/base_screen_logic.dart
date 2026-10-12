// lib/ui_helpers/base_screen_logic.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

export '../services/api_service.dart' show ApiLoadException, NatureErreur;

// Un mixin qui fournit des fonctionnalités de base pour les écrans, Gestion commune des elements communs aux ecrans
mixin BaseScreenLogic<T extends StatefulWidget> on State<T> {
  final ApiService apiService = ApiService();
  bool isLoading = false;
  String? errorMessage;

  /// Échec du dernier appel au serveur (réseau, délai, erreur serveur, session, droit…) : les écrans
  /// l'affichent avec « Réessayer » (LoadErrorView), à distinguer d'une vraie liste vide.
  ApiLoadException? loadError;

  /// Chargement relancé par « Réessayer » (chaque fonction de chargement de l'écran s'y inscrit).
  VoidCallback? reessai;

  // Méthode générique pour exécuter des appels API en toute sécurité
  Future<dynamic> safeApiCall(Future<dynamic> Function() apiCall, {String? customErrorMessage}) async {
    if (!mounted) return null;

    // Démarre le chargement et efface les anciennes erreurs
    setState(() {
      isLoading = true;
      errorMessage = null;
      loadError = null;
    });

    try {
      // Exécute l'appel API fourni
      final data = await apiCall();
      return data;
    } catch (e) {
      if (mounted) {
        setState(() {
          // Affiche un message d'erreur personnalisé ou le message d'erreur de l'API
          loadError = e is ApiLoadException ? e : null;
          errorMessage = customErrorMessage ?? (e is ApiLoadException ? e.message : 'Erreur: ${e.toString().replaceFirst("Exception: ", "")}');
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

  // AJOUT: Raccourci pour les appels GET V3
  Future<dynamic> apiGetV3(String endpoint, {Map<String, String>? queryParams}) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return safeApiCall(
            () => apiService.getV3(
          context,
          endpoint,
          queryParams: queryParams,
          onSessionInvalid: () => authProvider.forceLogout(),
        )
    );
  }

  Future<dynamic> apiPost(String endpoint, Map<String, dynamic> body) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return safeApiCall(
            () => apiService.post(
          context,
          endpoint,
          body,
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