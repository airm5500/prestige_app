// lib/utils/constants.dart

class AppConstants {
  // SharedPreferences Keys
  static const String localIpKey = 'local_ip';
  static const String remoteIpKey = 'remote_ip';
  static const String useLocalIpKey = 'use_local_ip';
  static const String portKey = 'port_key';
  static const String sessionTimeoutKey = 'session_timeout';
  static const String lastPausedTimeKey = 'last_paused_time';
  static const String sessionCookieKey = 'session_cookie';
  static const String savedUsernameKey = 'saved_username';
  static const String savedPasswordKey = 'saved_password';
  static const String rememberMeKey = 'remember_me';
  static const String userDataKey = 'user_data';

  // API Base Path
  static const String apiBasePath = '/laborex/api/v1';

  // API Endpoints
  static const String authEndpoint = '/user/auth';
  static const String logoutEndpoint = '/user/logout';
  static const String fournisseursEndpoint = '/fournisseurs';
  static const String achatsFournisseursEndpoint = '/achats-fournisseurs';
  static const String valorisationEndpoint = '/valorisation';
  static const String caCreditEndpoint = '/ca-credit';
  static const String caComptantEndpoint = '/ca-all';
  static const String caAllEndpoint = '/ca-all';
  static const String checkProduitEndpoint = '/checkproduit';
  static const String infoEndpoint = '/info';
  static const String tableauBordAchatsVentesEndpoint = '/ws/ca-achats-ventes';
  static const String valorisationAllEndpoint = '/valorisation/all';
  static const String officineEndpoint = '/officine';

  // Default IP, Port, and Timeout
  static const String defaultLocalIp = 'adresse ip locale';
  static const String defaultRemoteIp = 'adresse ip publique';
  static const String defaultPort = '8080';
  static const int defaultSessionTimeout = 30;

  // Norme Ratio
  static const double ratioNormeVenteAchat = 1.51;
}
