// lib/demo/mode_demo.dart
// MODE DÉMONSTRATION (3.18.0) : explorer l'application sans serveur Prestige (examinateurs de Google Play et
// d'Apple, curieux), avec des données FICTIVES servies localement par le serveur de démonstration
// (serveur_demo.dart) : aucune requête réseau, aucune donnée réelle.
//
// Étanchéité avec la vraie session (rien de la démonstration n'est jamais écrit sur le téléphone) :
//  - préférences (SharedPreferences) : magasin EN MÉMOIRE pendant la démonstration (adresse du serveur fictive,
//    réglages d'affichage recopiés) ; le magasin réel n'est ni lu ni modifié, et il est rebranché à la sortie ;
//  - stockage sécurisé (cookie, mot de passe mémorisé, code administrateur) : coffre en mémoire, vidé à la sortie ;
//  - client HTTP : celui de la démonstration (en mémoire) ; le client réel est remis à la sortie ;
//  - caches courts : clés liées à la session et au client (ApiService.empreinteSession), renouvelées ;
//  - écritures vers le serveur (validations, envois, modifications, annulations) et exports : refusées AVANT tout
//    envoi, message « Indisponible en démonstration ».
// Rien n'est conservé si l'application est fermée pendant la démonstration : au lancement suivant, tout est comme avant.
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../donnees/routes_serveur.dart';
import '../interface_version.dart';
import '../nouvelle_interface/alertes_accueil.dart';
import '../nouvelle_interface/apparence_accueil.dart';
import '../nouvelle_interface/presentation.dart';
import '../providers/auth_provider.dart';
import '../providers/home_settings_provider.dart';
import '../providers/ip_config_provider.dart';
import '../services/api_service.dart';
import '../services/stockage_securise.dart';
import '../ui/taille_ecran.dart';
import '../utils/constants.dart';
import 'serveur_demo.dart';

class ModeDemo {
  ModeDemo._();

  /// Vrai pendant la démonstration.
  static final actif = ValueNotifier<bool>(false);

  static bool get estActif => actif.value;

  // Libellés (cités dans la fiche Google Play : ne pas les changer sans mettre la fiche à jour).
  static const libelleBouton = 'Essayer la démonstration';
  static const libelleBandeau = 'Démonstration — données fictives';
  static const libelleQuitter = 'Quitter la démonstration';
  static const messageIndisponible = 'Indisponible en démonstration';

  /// Adresse fictive affichée pendant la démonstration (domaine réservé « .invalid » : ne se résout jamais).
  static const adresse = 'demo.prestige.invalid';

  /// Horloge de la démonstration (fixe dans les tests : données déterministes).
  static DateTime Function() horloge = DateTime.now;

  /// Messager de l'application (message « Indisponible en démonstration » depuis n'importe quel écran).
  static final messager = GlobalKey<ScaffoldMessengerState>();

  /// Serveur de démonstration en cours (null hors démonstration).
  static ServeurDemo? serveur;

  // État réel mis de côté pendant la démonstration.
  static http.Client? _clientReel;
  static http.Client? _clientDemo;
  static SharedPreferencesStorePlatform? _magasinReel;
  static AuthProvider? _auth;
  static IpConfigProvider? _ip;
  static HomeSettingsProvider? _accueil;
  static ({bool nouvelle, Presentation presentation, AffichageMenus affichage, StyleIcones style, TailleEcran taille, TailleEcran tailleActive})?
      _affichage;
  static bool _transition = false;

  /// Réglages d'affichage recopiés dans la démonstration (aucune donnée de l'officine).
  static const clesAffichage = [
    InterfaceVersion.cle,
    PresentationPrefs.cle,
    PresentationPrefs.cleMigration,
    ApparenceAccueilPrefs.cleAffichage,
    ApparenceAccueilPrefs.cleStyle,
    TailleEcranReglage.cle,
    'feature_order_key',
    'disabled_features_key',
  ];

  /// Entre en démonstration (bouton « Essayer la démonstration ») : aucun identifiant, aucune requête réseau.
  static Future<void> entrer(BuildContext context) async {
    if (actif.value || _transition) return;
    _transition = true;
    try {
      _auth = context.read<AuthProvider>();
      _ip = context.read<IpConfigProvider>();
      _accueil = context.read<HomeSettingsProvider>();
      _affichage = (
        nouvelle: InterfaceVersion.useNew.value,
        presentation: PresentationPrefs.choix.value,
        affichage: ApparenceAccueilPrefs.affichage.value,
        style: ApparenceAccueilPrefs.style.value,
        taille: TailleEcranReglage.enregistree,
        tailleActive: TailleEcranReglage.active.value,
      );

      // 1. Préférences : magasin en mémoire (réglages d'affichage recopiés + serveur fictif).
      final reelles = await SharedPreferences.getInstance();
      final graines = <String, Object>{
        for (final c in clesAffichage)
          if (reelles.get(c) != null) 'flutter.$c': reelles.get(c)!,
        'flutter.${AppConstants.localIpKey}': adresse,
        'flutter.${AppConstants.remoteIpKey}': AppConstants.defaultRemoteIp,
        'flutter.${AppConstants.useLocalIpKey}': true,
        'flutter.${AppConstants.portKey}': AppConstants.defaultPort,
        'flutter.${AppConstants.appNameKey}': AppConstants.defaultAppName,
        'flutter.${AppConstants.sessionTimeoutKey}': 0, // jamais de déconnexion pour inactivité
        'flutter.${AppConstants.isConfiguredKey}': true,
      };
      _magasinReel = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = InMemorySharedPreferencesStore.withData(graines);
      await reelles.reload(); // l'instance partagée relit le magasin en mémoire

      // 2. Stockage sécurisé : coffre en mémoire.
      CoffreIdentifiantsSecurise.memoireDemo = <String, String>{};

      // 3. Client HTTP de la démonstration (aucune socket).
      final s = ServeurDemo(horloge: horloge);
      serveur = s;
      _clientReel = ApiService.client;
      _clientDemo = s.client();
      ApiService.client = _clientDemo!;
      ApiService().entrerDemo();
      RoutesServeur.oublierSession();
      AlertesAccueil.instance.oublier();

      // 4. Adresse fictive et utilisateur de démonstration (rien d'enregistré).
      await _ip!.loadSettings();
      _auth!.entrerDemo(ServeurDemo.utilisateur(), ServeurDemo.officineDemo().first);
      actif.value = true;
    } finally {
      _transition = false;
    }
  }

  /// Quitte la démonstration : retour à l'écran de connexion (ou à la configuration d'une installation neuve), avec
  /// la configuration, les identifiants mémorisés et les caches réels intacts.
  static Future<void> quitter() async {
    if (!actif.value || _transition) return;
    _transition = true;
    try {
      _auth?.quitterDemo();
      // Client HTTP réel.
      final demo = _clientDemo;
      if (_clientReel != null && identical(ApiService.client, demo)) ApiService.client = _clientReel!;
      demo?.close();
      _clientDemo = null;
      _clientReel = null;
      serveur = null;
      // Stockages réels.
      CoffreIdentifiantsSecurise.memoireDemo = null;
      if (_magasinReel != null) SharedPreferencesStorePlatform.instance = _magasinReel!;
      _magasinReel = null;
      await (await SharedPreferences.getInstance()).reload();
      await ApiService().quitterDemo();
      RoutesServeur.oublierSession();
      AlertesAccueil.instance.oublier();
      final a = _affichage;
      if (a != null) {
        InterfaceVersion.useNew.value = a.nouvelle;
        PresentationPrefs.choix.value = a.presentation;
        ApparenceAccueilPrefs.affichage.value = a.affichage;
        ApparenceAccueilPrefs.style.value = a.style;
        TailleEcranReglage.enregistree = a.taille;
        TailleEcranReglage.active.value = a.tailleActive;
      }
      await _ip?.loadSettings();
      await _accueil?.loadSettings();
      actif.value = false;
    } finally {
      _transition = false;
    }
  }

  // --- Écritures ---

  /// Lectures envoyées en POST (connexion, déconnexion, ticket Z).
  static const lecturesPost = {AppConstants.authEndpoint, AppConstants.logoutEndpoint, '/caisse/fetch-tickez'};

  /// Écritures envoyées en GET.
  static const ecrituresGet = [
    AppConstants.venteAnnulationEndpoint,
    AppConstants.suggestionSetPendingEndpoint,
    '/licence/save',
    '/surstock/create-inventaire',
  ];

  /// [methode] : GET, POST, PUT, DELETE, ou EXPORT (téléchargement d'un fichier PDF / Excel).
  static bool bloquee(String methode, String endpoint) {
    if (!actif.value) return false;
    final chemin = endpoint.split('?').first;
    return switch (methode) {
      'GET' => ecrituresGet.any(chemin.startsWith),
      'POST' => !lecturesPost.contains(chemin),
      _ => true,
    };
  }

  /// Refus d'une écriture en démonstration : message à l'écran et échec de l'appel (sans rien envoyer).
  static ApiLoadException refuser() {
    final m = messager.currentState;
    if (m != null) {
      m
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          key: Key('demo_indisponible'),
          content: Text(messageIndisponible),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ));
    }
    return const ApiLoadException(messageIndisponible, nature: NatureErreur.refus);
  }
}
