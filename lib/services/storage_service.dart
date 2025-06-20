// lib/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class StorageService {
  Future<void> saveIpSettings(String localIp, String remoteIp, bool useLocal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.localIpKey, localIp);
    await prefs.setString(AppConstants.remoteIpKey, remoteIp);
    await prefs.setBool(AppConstants.useLocalIpKey, useLocal);
  }

  Future<Map<String, dynamic>> loadIpSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String localIp = prefs.getString(AppConstants.localIpKey) ?? AppConstants.defaultLocalIp;
    String remoteIp = prefs.getString(AppConstants.remoteIpKey) ?? AppConstants.defaultRemoteIp;
    bool useLocal = prefs.getBool(AppConstants.useLocalIpKey) ?? true; // Default to local
    return {
      'localIp': localIp,
      'remoteIp': remoteIp,
      'useLocal': useLocal,
    };
  }

  Future<void> saveUseLocalIp(bool useLocal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.useLocalIpKey, useLocal);
  }

  Future<String?> getLocalIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.localIpKey);
  }

  Future<String?> getRemoteIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.remoteIpKey);
  }

  Future<bool> getUseLocalIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.useLocalIpKey) ?? true;
  }
}
