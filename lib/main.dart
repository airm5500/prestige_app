// lib/main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/ip_config_provider.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/constants.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (context) => IpConfigProvider(),
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
        // CORRECTION APPLIQUÉE ICI pour l'avertissement 'background'
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          primary: primaryColor,
          secondary: secondaryColor,
          surface: cardColor, // Utilisation de 'surface' au lieu de 'background'
        //  background: backgroundColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: backgroundColor,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          elevation: 2,
          scrolledUnderElevation: 4,
          shadowColor: Colors.black.withAlpha(26), // ~10% opacité
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
      home: Consumer<IpConfigProvider>(
        builder: (context, ipProvider, child) {
          final bool isDefaultConfig =
              (ipProvider.localIp == AppConstants.defaultLocalIp && ipProvider.remoteIp == AppConstants.defaultRemoteIp) ||
                  ipProvider.localIp.trim().isEmpty;

          if (isDefaultConfig) {
            return const SettingsScreen();
          }
          return const HomeScreen();
        },
      ),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
