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
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'utils/constants.dart';
import 'services/api_service.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/screens/licence_registration_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IpConfigProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeSettingsProvider()),
        Provider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => LicenceProvider()),
      ],
      child: const PrestigeApp(),
    ),
  );
}

class PrestigeApp extends StatelessWidget {
  const PrestigeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0A2E3E);
    const secondaryColor = Color(0xFF164B62);
    const accentColor = Color(0xFF2EBF91);
    const backgroundColor = Color(0xFFF5F7FA);
    const cardColor = Colors.white;

    final textTheme = GoogleFonts.latoTextTheme(Theme.of(context).textTheme).apply(
      bodyColor: const Color(0xFF333333),
      displayColor: const Color(0xFF1a1a1a),
    );

    return MaterialApp(
      title: 'Prestige App',
      theme: ThemeData(
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
      ),
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
      home: const AppLifecycleObserver(child: AuthWrapper()),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
        debugPrint("App resumed");
        // 1. Vérif session
        await authProvider.checkSessionTimeout(ipConfigProvider.sessionTimeout);
        // 2. Vérif licence (si la date a changé pendant que l'app était en pause)
        licenceProvider.revalidateLocalStatus();
        break;

      case AppLifecycleState.paused:
        debugPrint("App paused");
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

            // Si licence invalide -> Ecran d'enregistrement
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
                  return const HomeScreen();
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