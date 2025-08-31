// lib/providers/auth_provider.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/officine_model.dart'; // AJOUT
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  AppUser? _user;
  Officine? _officine; // AJOUT
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String? _errorMessage;

  final StreamController<String> _eventController = StreamController<String>.broadcast();
  Stream<String> get events => _eventController.stream;

  AppUser? get user => _user;
  Officine? get officine => _officine; // AJOUT
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _prepareApp();
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }

  Future<void> _prepareApp() async {
    final startTime = DateTime.now();
    await _apiService.loadSessionCookie();
    await _loadUserData();
    const minDuration = Duration(milliseconds: 2500);
    final elapsedTime = DateTime.now().difference(startTime);
    if (elapsedTime < minDuration) {
      await Future.delayed(minDuration - elapsedTime);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkSessionTimeout(int timeoutInMinutes) async {
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

      final message = "Veuillez vous reconnecter Dr $userName, vous avez fait $formattedDuration sans venir me consulter 😢";
      _eventController.add(message);

      forceLogout();
    }
  }

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

        // Après une connexion réussie, on met à jour les infos de l'officine
        await fetchAndStoreOfficineInfo(context);

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

  // AJOUT: Récupère et stocke les infos de l'officine
  Future<void> fetchAndStoreOfficineInfo(BuildContext context) async {
    try {
      final data = await _apiService.get(context, AppConstants.officineEndpoint, onSessionInvalid: forceLogout);
      if (data is List && data.isNotEmpty) {
        _officine = Officine.fromJson(data[0]);
        final prefs = await SharedPreferences.getInstance();
        // On stocke le nom complet pour l'afficher sur l'écran de connexion
        await prefs.setString('officine_name', _officine!.nomComplet);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Could not fetch officine info: $e");
    }
  }

  void forceLogout() {
    if (!_isLoggedIn) return;
    debugPrint("Forcing logout due to invalid session.");
    _user = null;
    _isLoggedIn = false;
    _apiService.clearSessionCookie();
    _clearUserData();
    notifyListeners();
  }

  Future<void> logout(BuildContext context) async {
    try {
      await _apiService.post(context, AppConstants.logoutEndpoint, {});
    } catch (e) {
      debugPrint("Logout API call failed, but logging out locally anyway: $e");
    }
    forceLogout();
  }

  Future<void> _saveUserData(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = {
      'str_USER_ID': user.userId, 'str_FIRST_NAME': user.firstName, 'str_LAST_NAME': user.lastName,
      'str_LOGIN': user.login, 'OFFICINE': user.officineName, 'str_PIC': user.profilePicUrl,
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

  Future<String?> getLastKnownOfficineName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('officine_name');
  }

  Future<void> _clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    // On ne supprime pas le nom de l'officine pour le garder sur l'écran de connexion
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