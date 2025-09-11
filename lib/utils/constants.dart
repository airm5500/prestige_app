// lib/utils/constants.dart

class AppConstants {
  // SharedPreferences Keys
  static const String localIpKey = 'local_ip';
  static const String remoteIpKey = 'remote_ip';
  static const String useLocalIpKey = 'use_local_ip';
  static const String portKey = 'port_key';
  static const String sessionTimeoutKey = 'session_timeout';
  static const String lastPausedTimeKey = 'last_paused_time';
  static const String isConfiguredKey = 'is_app_configured';
  static const String sessionCookieKey = 'session_cookie';
  static const String savedUsernameKey = 'saved_username';
  static const String savedPasswordKey = 'saved_password';
  static const String rememberMeKey = 'remember_me';
  static const String userDataKey = 'user_data';
  static const String appNameKey = 'app_name_key';

  // API Base Path
  static const String apiBasePath = '/api/v1';
  static const String apiV3BasePath = '/api/v3'; // AJOUT

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
  static const String suiviCreditEndpoint = '/recap/credits';
  static const String ventesStatsEndpoint = '/ventestats';
  static const String venteDetailEndpoint = '/ventestats/find-one';
  static const String venteAnnulationEndpoint = '/vente/annulation';
  static const String ajustementEndpoint = '/ajustement';
  static const String ajustementItemsEndpoint = '/ajustement/items';
  static const String typeAjustementsEndpoint = '/common/type-ajustements';
  static const String retoursFournisseursEndpoint = '/produit/retours-data';
  static const String retourFournisseurDetailEndpoint = '/retourfournisseur/retours-items';
  static const String grossistesEndpoint = '/grossiste/all';
  static const String statTvaEndpoint = '/tvas'; // AJOUT
  static const String avoirsFournisseursEndpoint = '/avoirs-fournisseurs';
  static const String suivi2080Endpoint = '/statfamillearticle/vingtQuatreVingt';
  static const String suiviPeremptionEndpoint = '/fichearticle/perimes';

  static const String suggestionListEndpoint = '/suggestion/list';
  static const String suggestionSetPendingEndpoint = '/suggestion/set-pending';
  static const String suggestionListItemsEndpoint = '/suggestion/list/items';
  static const String suggestionAmountEndpoint = '/suggestion/amount';
  static const String suggestionUpdateQteEndpoint = '/suggestion/item/update-qte-cmde';
  static const String suggestionDeleteItemEndpoint = '/suggestion/item';
  static const String suggestionDeleteEndpoint = '/suggestion/suggestion';
  static const String dashboardRecapEndpoint = '/recap/dashboard';
  static const String creditsRecapEndpoint = '/recap/credits';
  static const String creditTotalsRecapEndpoint = '/recap/credits/totaux';
  static const String reglementsRecapEndpoint = '/recap/reglements';
  static const String etatControleAchatEndpoint = '/etat-control-bon/list-annuelle'; // AJOUT
  static const String groupeGrossisteEndpoint = '/groupegrossiste';
  static const String analyseSaisieBlEndpoint = '/etat-control-bon/list';

  static const String fichierJournalEndpoint = '/common/logs'; // AJOUT
  static const String logFiltresEndpoint = '/common/log-filtres'; // AJOUT
  static const String logUsersEndpoint = '/common/users'; // AJOUT
  static const String margeProduitsVendusEndpoint = '/datareporting/margeproduitsvendus';

  // Default Values
  static const String defaultLocalIp = '';
  static const String defaultRemoteIp = '';
  static const String defaultPort = '8080';
  static const String defaultAppName = 'laborex';
  static const int defaultSessionTimeout = 30; // 30 minutes

  // Norme Ratio
  static const double ratioNormeVenteAchat = 1.51;
}