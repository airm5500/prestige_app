// lib/utils/constants.dart

class AppConstants {
  // SharedPreferences Keys
  static const String localIpKey = 'local_ip';
  static const String remoteIpKey = 'remote_ip';
  static const String useLocalIpKey = 'use_local_ip';

  // API Base Path (will be prefixed by IP and port)
  static const String apiBasePath = '/laborex/api/v1';

  // API Endpoints
  static const String fournisseursEndpoint = '/fournisseurs';
  static const String achatsFournisseursEndpoint = '/achats-fournisseurs';
  static const String valorisationEndpoint = '/valorisation';
  static const String caCreditEndpoint = '/ca-credit';
  static const String caComptantEndpoint = '/ca-all';
  static const String caAllEndpoint = '/ca-all';
  static const String checkProduitEndpoint = '/checkproduit';
  static const String tableauBordAchatsVentesEndpoint = '/ws/ca-achats-ventes';
  static const String valorisationAllEndpoint = '/valorisation/all';
  static const String officineEndpoint = '/officine'; // AJOUT: Pour les infos utilisateur

  // Default IP addresses (examples, user should configure these)
  static const String defaultLocalIp = '192.168.1.100'; // Example
  static const String defaultRemoteIp = 'your-remote-ip.com'; // Example
  static const String defaultPort = '8080';

  // Norme Ratio pour Tableau de Bord
  static const double ratioNormeVenteAchat = 1.51;
}
