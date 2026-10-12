// Outils communs aux tests : un contexte avec les providers de l'application, pour appeler ApiService.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
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
    ],
    child: MaterialApp(
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
