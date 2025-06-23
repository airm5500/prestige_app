// lib/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class StorageService {

  // Méthode pour tout sauvegarder d'un coup
  Future<void> saveAllSettings({
    required String localIp,
    required String remoteIp,
    required String port,
    required bool useLocal,
    required int sessionTimeout,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.localIpKey, localIp);
    await prefs.setString(AppConstants.remoteIpKey, remoteIp);
    await prefs.setString(AppConstants.portKey, port);
    await prefs.setBool(AppConstants.useLocalIpKey, useLocal);
    await prefs.setInt(AppConstants.sessionTimeoutKey, sessionTimeout);
  }

  // Méthode pour tout charger d'un coup
  Future<Map<String, dynamic>> loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'localIp': prefs.getString(AppConstants.localIpKey),
      'remoteIp': prefs.getString(AppConstants.remoteIpKey),
      'port': prefs.getString(AppConstants.portKey),
      'useLocal': prefs.getBool(AppConstants.useLocalIpKey),
      'sessionTimeout': prefs.getInt(AppConstants.sessionTimeoutKey),
    };
  }

  // Cette méthode reste utile pour changer rapidement le mode de connexion
  Future<void> saveUseLocalIp(bool useLocal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.useLocalIpKey, useLocal);
  }
}
