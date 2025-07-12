// lib/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class StorageService {

  Future<void> saveAllSettings({
    required String localIp,
    required String remoteIp,
    required String port,
    required bool useLocal,
    required int sessionTimeout,
    required String appName, // AJOUT
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.localIpKey, localIp);
    await prefs.setString(AppConstants.remoteIpKey, remoteIp);
    await prefs.setString(AppConstants.portKey, port);
    await prefs.setBool(AppConstants.useLocalIpKey, useLocal);
    await prefs.setInt(AppConstants.sessionTimeoutKey, sessionTimeout);
    await prefs.setString(AppConstants.appNameKey, appName); // AJOUT
    await prefs.setBool(AppConstants.isConfiguredKey, true);
  }

  Future<Map<String, dynamic>> loadAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'localIp': prefs.getString(AppConstants.localIpKey),
      'remoteIp': prefs.getString(AppConstants.remoteIpKey),
      'port': prefs.getString(AppConstants.portKey),
      'useLocal': prefs.getBool(AppConstants.useLocalIpKey),
      'sessionTimeout': prefs.getInt(AppConstants.sessionTimeoutKey),
      'appName': prefs.getString(AppConstants.appNameKey), // AJOUT
      'isConfigured': prefs.getBool(AppConstants.isConfiguredKey),
    };
  }

  Future<void> saveUseLocalIp(bool useLocal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.useLocalIpKey, useLocal);
  }
}
