// lib/providers/ip_config_provider.dart

import 'package:flutter/foundation.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

class IpConfigProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();

  String _localIp = AppConstants.defaultLocalIp;
  String _remoteIp = AppConstants.defaultRemoteIp;
  bool _useLocalIp = true;
  String _port = AppConstants.defaultPort;
  int _sessionTimeout = AppConstants.defaultSessionTimeout;
  bool _isAppConfigured = false;
  String _appName = AppConstants.defaultAppName; // AJOUT

  String get localIp => _localIp;
  String get remoteIp => _remoteIp;
  bool get useLocalIp => _useLocalIp;
  String get port => _port;
  int get sessionTimeout => _sessionTimeout;
  bool get isAppConfigured => _isAppConfigured;
  String get appName => _appName; // AJOUT

  // CORRECTION: L'URL est maintenant construite dynamiquement
  String get activeBaseUrl {
    final ip = _useLocalIp ? _localIp : _remoteIp;
    if (ip.isEmpty) {
      return 'http://0.0.0.0:$_port/$_appName${AppConstants.apiBasePath}';
    }
    return 'http://$ip:$_port/$_appName${AppConstants.apiBasePath}';
  }

  IpConfigProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final settings = await _storageService.loadAllSettings();
    _localIp = settings['localIp'] ?? AppConstants.defaultLocalIp;
    _remoteIp = settings['remoteIp'] ?? AppConstants.defaultRemoteIp;
    _useLocalIp = settings['useLocal'] ?? true;
    _port = settings['port'] ?? AppConstants.defaultPort;
    _sessionTimeout = settings['sessionTimeout'] ?? AppConstants.defaultSessionTimeout;
    _isAppConfigured = settings['isConfigured'] ?? false;
    _appName = settings['appName'] ?? AppConstants.defaultAppName; // AJOUT
    notifyListeners();
  }

  Future<void> updateSettings(String newLocalIp, String newRemoteIp, String newPort, int newTimeout, String newAppName) async {
    _localIp = newLocalIp.isNotEmpty ? newLocalIp : AppConstants.defaultLocalIp;
    _remoteIp = newRemoteIp.isNotEmpty ? newRemoteIp : AppConstants.defaultRemoteIp;
    _port = newPort.isNotEmpty ? newPort : AppConstants.defaultPort;
    _sessionTimeout = newTimeout;
    _isAppConfigured = true;
    _appName = newAppName.isNotEmpty ? newAppName : AppConstants.defaultAppName; // AJOUT

    await _storageService.saveAllSettings(
      localIp: _localIp, remoteIp: _remoteIp, port: _port,
      useLocal: _useLocalIp, sessionTimeout: _sessionTimeout, appName: _appName,
    );
    notifyListeners();
  }

  Future<void> toggleIpMode() async {
    _useLocalIp = !_useLocalIp;
    await _storageService.saveUseLocalIp(_useLocalIp);
    notifyListeners();
  }

  void setUseLocalIp(bool value) async {
    if (_useLocalIp != value) {
      _useLocalIp = value;
      await _storageService.saveUseLocalIp(_useLocalIp);
      notifyListeners();
    }
  }
}
