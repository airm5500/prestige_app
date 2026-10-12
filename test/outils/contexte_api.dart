// Outils communs aux tests : un contexte avec les providers de l'application, pour appeler ApiService.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/home_settings_provider.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:provider/provider.dart';

/// Monte [ecran] (ou un écran vide) avec IpConfigProvider / AuthProvider / LicenceProvider
/// et renvoie le contexte de l'écran. Préférences et stockage sûr doivent être simulés avant l'appel.
Future<BuildContext> monterAvecProviders(WidgetTester tester, {Widget? ecran, IpConfigProvider? ip, AuthProvider? auth, LicenceProvider? licence}) async {
  late BuildContext ctx;
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: ip ?? IpConfigProvider()),
      ChangeNotifierProvider.value(value: auth ?? AuthProvider()),
      ChangeNotifierProvider.value(value: licence ?? LicenceProvider()),
      ChangeNotifierProvider(create: (_) => HomeSettingsProvider()),
      Provider(create: (_) => ApiService()),
    ],
    child: MaterialApp(
      // Comme main.dart : français (formats de dates et de montants).
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      locale: const Locale('fr', 'FR'),
      home: ecran ??
          Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          }),
    ),
  ));
  // AuthProvider garde l'écran de démarrage au moins 2,5 s ; préférences chargées.
  await tester.pump(const Duration(seconds: 3));
  if (ecran != null) ctx = tester.element(find.byWidget(ecran));
  return ctx;
}
