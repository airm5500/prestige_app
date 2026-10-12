// Test de fumée : l'application démarre avec TOUS ses providers (comme main.dart) et, sur un appareil
// neuf (aucune configuration), ouvre la Configuration IP.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/main.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/home_settings_provider.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets("Démarrage : appareil non configuré → Configuration IP", (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
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
    // AuthProvider garde l'écran de démarrage au moins 2,5 s.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Configuration IP'), findsOneWidget);
  });
}
