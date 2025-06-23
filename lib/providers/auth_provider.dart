// lib/providers/auth_provider.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  AppUser? _user;
  bool _isLoggedIn = false;
  bool _isLoading = true; // True au démarrage pour afficher le splash screen
  String? _errorMessage;

  AppUser? get user => _user;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _prepareApp();
  }

  // Prépare l'application au démarrage
  Future<void> _prepareApp() async {
    final startTime = DateTime.now();

    // Tâches de fond (chargement du cookie, etc.)
    await _apiService.loadSessionCookie();
    await _loadUserData(); // Charger les données utilisateur si elles existent

    // Calcul du temps écoulé pour garantir une durée minimale au splash screen
    const minDuration = Duration(milliseconds: 2500);
    final elapsedTime = DateTime.now().difference(startTime);

    if (elapsedTime < minDuration) {
      await Future.delayed(minDuration - elapsedTime);
    }

    // Termine l'écran de chargement. L'app ne se connecte pas automatiquement.
    _isLoading = false;
    notifyListeners();
  }

  // Gère la déconnexion après une période d'inactivité
  Future<void> checkSessionTimeout(BuildContext context, int timeoutInMinutes) async {
    if (!_isLoggedIn) return;

    final prefs = await SharedPreferences.getInstance();
    final lastPausedTimestamp = prefs.getInt(AppConstants.lastPausedTimeKey);

    if (lastPausedTimestamp == null) return;

    final lastPausedTime = DateTime.fromMillisecondsSinceEpoch(lastPausedTimestamp);
    final now = DateTime.now();
    final inactiveDuration = now.difference(lastPausedTime);

    if (inactiveDuration.inMinutes >= timeoutInMinutes) {
      final userName = _user?.fullName ?? 'Utilisateur';
      final formattedDuration = DateFormatter.formatDuration(inactiveDuration);

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Session Expirée"),
            content: Text(
                "Veuillez vous reconnecter Dr $userName, vous avez fait $formattedDuration sans venir me consulter 😢"
            ),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  forceLogout();
                },
              ),
            ],
          ),
        );
      }
    }
  }

  // Méthode de connexion
  Future<String?> login(BuildContext context, String username, String password, bool rememberMe) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(context, AppConstants.authEndpoint, {
        "login": username,
        "password": password,
      }, onSessionInvalid: forceLogout);

      if (response['success'] == true) {
        _user = AppUser.fromJson(response);
        _isLoggedIn = true;
        await _saveUserData(_user!);
        await _saveCredentials(username, password, rememberMe);
        _isLoading = false;
        notifyListeners();
        return null;
      } else {
        throw Exception(response['message'] ?? "Identifiants incorrects.");
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst("Exception: ", "");
      notifyListeners();
      return _errorMessage;
    }
  }

  // Déconnexion forcée (session invalide)
  void forceLogout() {
    if (!_isLoggedIn) return;

    debugPrint("Forcing logout due to invalid session.");
    _user = null;
    _isLoggedIn = false;
    _apiService.clearSessionCookie();
    _clearUserData();
    notifyListeners();
  }

  // Déconnexion manuelle
  Future<void> logout(BuildContext context) async {
    try {
      await _apiService.post(context, AppConstants.logoutEndpoint, {});
    } catch (e) {
      debugPrint("Logout API call failed, but logging out locally anyway: $e");
    }
    forceLogout();
  }

  // --- Méthodes de gestion des données sauvegardées ---

  Future<void> _saveUserData(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = {
      'str_USER_ID': user.userId,
      'str_FIRST_NAME': user.firstName,
      'str_LAST_NAME': user.lastName,
      'str_LOGIN': user.login,
      'OFFICINE': user.officineName,
      'str_PIC': user.profilePicUrl,
    };
    await prefs.setString(AppConstants.userDataKey, jsonEncode(userData));
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(AppConstants.userDataKey);
    if (userDataString != null) {
      _user = AppUser.fromJson(jsonDecode(userDataString));
    }
  }

  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userDataKey);
  }

  Future<void> _saveCredentials(String username, String password, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.rememberMeKey, rememberMe);
    if (rememberMe) {
      await prefs.setString(AppConstants.savedUsernameKey, username);
      await prefs.setString(AppConstants.savedPasswordKey, password);
    } else {
      await prefs.remove(AppConstants.savedUsernameKey);
      await prefs.remove(AppConstants.savedPasswordKey);
    }
  }
}
