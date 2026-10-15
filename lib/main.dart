// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'providers/ip_config_provider.dart';
import 'providers/home_settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/serveur_injoignable_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';
import 'services/api_service.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/screens/licence_registration_screen.dart';
import 'interface_version.dart';
import 'nouvelle_interface/charte.dart';
import 'nouvelle_interface/icones_illustrees.dart';
import 'ui/taille_ecran.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Licence MIT des icônes illustrées (P4) dans les licences de l'application (lue seulement si la page s'ouvre).
  enregistrerLicenceIcones();
  await InterfaceVersion.load();
  // Taille de l'écran (3.7.0, docs/TAILLE_ECRAN.md) : lue une fois, appliquée par RacineTailleEcran.
  await TailleEcranReglage.charger();
  runApp(applicationPrestige());
}

/// Arbre complet de l'application : providers + [PrestigeApp]. Utilisé par [main] et par les tests de bout en
/// bout (test/e2e/), qui montent ainsi exactement la même application. [accueil] : voir [PrestigeApp.accueil].
Widget applicationPrestige({Widget? accueil}) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IpConfigProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeSettingsProvider()),
        Provider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => LicenceProvider()),
      ],
      child: PrestigeApp(accueil: accueil),
    );

class PrestigeApp extends StatelessWidget {
  /// Écran affiché à la place du parcours de démarrage (Configuration → licence → connexion → accueil).
  /// Réservé aux tests d'ergonomie (un écran rendu avec le vrai thème) ; null en production.
  final Widget? accueil;

  const PrestigeApp({super.key, this.accueil});

  /// Thème de l'ANCIENNE interface (inchangé).
  static ThemeData themeAncienneInterface(BuildContext context) {
    const primaryColor = Color(0xFF0A2E3E);
    const secondaryColor = Color(0xFF164B62);
    const accentColor = Color(0xFF2EBF91);
    const backgroundColor = Color(0xFFF5F7FA);
    const cardColor = Colors.white;

    final textTheme = GoogleFonts.latoTextTheme(Theme.of(context).textTheme).apply(
      bodyColor: const Color(0xFF333333),
      displayColor: const Color(0xFF1a1a1a),
    );

    return ThemeData(
        primaryColor: primaryColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          surface: cardColor,
          background: backgroundColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: backgroundColor,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          elevation: 2,
          scrolledUnderElevation: 4,
          shadowColor: Colors.black.withAlpha(26),
          titleTextStyle: GoogleFonts.lato(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: cardColor,
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
          labelStyle: const TextStyle(color: primaryColor),
          filled: true,
          fillColor: Colors.white,
        ),
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      );
  }

  @override
  Widget build(BuildContext context) {
    // Taille de l'écran (Automatique / Compact / Très compact ; Compact d'office en Automatique sur un petit
    // écran) : au-dessus de la SEULE MaterialApp, sous les providers (session gardée à « Relancer maintenant »).
    // Nouvelle ou ancienne interface (réglage mémorisé, effet immédiat) : thème et écrans d'accueil.
    return RacineTailleEcran(
      child: ValueListenableBuilder<bool>(
      valueListenable: InterfaceVersion.useNew,
      // Clé liée à la version : changer d'interface reconstruit l'application (pas d'animation entre deux thèmes
      // incompatibles) et ramène à l'accueil de la version choisie ; la connexion (providers) est conservée.
      builder: (context, nouvelle, _) => MaterialApp(
      key: ValueKey<bool>(nouvelle),
      title: 'Prestige App',
      theme: nouvelle ? themeNouvelleInterface(context) : themeAncienneInterface(context),
      builder: (context, child) => InterfaceScope(nouvelle: nouvelle, child: child ?? const SizedBox()),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('fr', 'FR'),
      home: accueil ?? const AppLifecycleObserver(child: AuthWrapper()),
    ),
      ),
    );
  }
}

class AppLifecycleObserver extends StatefulWidget {
  final Widget child;
  const AppLifecycleObserver({super.key, required this.child});

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver> with WidgetsBindingObserver {
  StreamSubscription? _eventSubscription;
  AuthProvider? _auth;
  bool _etaitConnecte = false;

  /// Déconnexion (session expirée, délai d'inactivité, bouton) : les écrans ouverts par-dessus l'accueil
  /// sont fermés pour revenir à l'écran de connexion.
  void _surChangementConnexion() {
    final connecte = _auth?.isLoggedIn ?? false;
    if (_etaitConnecte && !connecte && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _etaitConnecte = connecte;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = Provider.of<AuthProvider>(context, listen: false)..addListener(_surChangementConnexion);
    _etaitConnecte = _auth!.isLoggedIn;
    _eventSubscription = Provider.of<AuthProvider>(context, listen: false).events.listen((message) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Session Expirée"),
            content: Text(message),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth?.removeListener(_surChangementConnexion);
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final ipConfigProvider = Provider.of<IpConfigProvider>(context, listen: false);
    // On récupère le provider de licence pour vérifier au réveil de l'app
    final licenceProvider = Provider.of<LicenceProvider>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        // 1. Vérif session
        await authProvider.checkSessionTimeout(ipConfigProvider.sessionTimeout);
        // 2. Vérif licence (si la date a changé pendant que l'app était en pause)
        licenceProvider.revalidateLocalStatus();
        break;

      case AppLifecycleState.paused:
        if (authProvider.isLoggedIn) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(AppConstants.lastPausedTimeKey, DateTime.now().millisecondsSinceEpoch);
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // C'est ICI qu'on surveille le statut global de la licence.
    // Si la licence expire pendant l'utilisation (ou au réveil), on remplace l'écran actuel par l'écran de blocage.
    return Consumer<LicenceProvider>(
      builder: (context, licenceProvider, child) {
        if (licenceProvider.status == LicenceStatus.expired) {
          return const LicenceRegistrationScreen();
        }
        // Sinon on affiche l'écran normal (AuthWrapper)
        return widget.child;
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Cette partie gère le flux de démarrage initial (IP -> Licence -> Auth)
    return Consumer<IpConfigProvider>(
      builder: (context, ipProvider, child) {
        // 1. Vérif IP
        if (!ipProvider.isAppConfigured) {
          return const SettingsScreen();
        }

        // 2. Vérif Licence
        return Consumer<LicenceProvider>(
          builder: (context, licenceProvider, child) {

            // Premier lancement : on lance la vérif
            if (licenceProvider.status == LicenceStatus.unknown) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                licenceProvider.checkLicence(context);
              });
              return const SplashScreen();
            }

            if (licenceProvider.status == LicenceStatus.checking) {
              return const SplashScreen();
            }

            // Serveur injoignable (ou erreur du serveur) : la licence n'est PAS en cause.
            // Message + « Réessayer » + réessai automatique toutes les 10 s.
            if (licenceProvider.status == LicenceStatus.error) {
              return const ServeurInjoignableScreen();
            }

            // Licence réellement absente ou expirée (le serveur a répondu) -> Ecran d'enregistrement
            if (licenceProvider.status == LicenceStatus.notFound ||
                licenceProvider.status == LicenceStatus.expired) {
              return const LicenceRegistrationScreen();
            }

            // 3. Vérif Auth (si licence OK)
            return Consumer<AuthProvider>(
              builder: (context, auth, child) {
                if (auth.isLoading) {
                  return const SplashScreen();
                }
                if (auth.isLoggedIn) {
                  return InterfaceVersion.home(nouvelle: InterfaceVersion.nouvelle(context));
                } else {
                  return const LoginScreen();
                }
              },
            );
          },
        );
      },
    );
  }
}