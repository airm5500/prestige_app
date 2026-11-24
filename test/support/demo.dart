// Outils des tests du MODE DÉMONSTRATION (3.18.0, lib/demo/) : installation neuve, client HTTP « interdit » qui
// relève tout appel (la démonstration ne doit faire AUCUNE requête réseau), instantanés des stockages réels.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:prestige_app/demo/mode_demo.dart';
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/alertes_accueil.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/services/pin_securise.dart';
import 'package:prestige_app/ui/taille_ecran.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Horloge fixe de la démonstration dans les tests (mardi 24 novembre 2026, 10 h 30).
final horlogeDemo = DateTime(2026, 11, 24, 10, 30);

/// Client HTTP qui ÉCHOUE et relève chaque appel : branché comme client « réel » de l'application, il prouve
/// qu'aucune requête ne part pendant la démonstration.
class ClientInterdit extends http.BaseClient {
  final appels = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    appels.add('${request.method} ${request.url.path}');
    throw const SocketException('Requête réseau interdite (test du mode démonstration)');
  }
}

/// Toute création de client HTTP de dart:io (sockets) est relevée et refusée.
class ReseauInterdit extends HttpOverrides {
  final tentatives = <String>[];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    tentatives.add('HttpClient');
    throw const SocketException('Réseau interdit (test du mode démonstration)');
  }
}

/// Téléphone d'une installation NEUVE (rien de configuré) : comme main(), réglages d'affichage chargés au lancement.
/// [prefs] : préférences déjà présentes (téléphone configuré). Renvoie le client « réel » interdit.
Future<ClientInterdit> preparerInstallation({Map<String, Object> prefs = const {}, Map<String, String> coffre = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  FlutterSecureStorage.setMockInitialValues(coffre);
  TailleEcranReglage.reinitialiser();
  ApparenceAccueilPrefs.reinitialiser();
  AlertesAccueil.instance.oublier();
  CodeAdmin.instance = CodeAdmin(iterations: 1000);
  JournalApp.actif = false;
  await InterfaceVersion.load();
  await TailleEcranReglage.charger();
  ModeDemo.horloge = () => horlogeDemo;
  final client = ClientInterdit();
  ApiService.client = client;
  return client;
}

/// Toutes les préférences réelles (magasin du téléphone), pour comparer avant / après la démonstration.
Future<Map<String, Object?>> instantanePreferences() async {
  final p = await SharedPreferences.getInstance();
  return {for (final k in p.getKeys()) k: p.get(k)};
}

/// Contenu du stockage sécurisé réel.
Future<Map<String, String>> instantaneCoffre() => const FlutterSecureStorage().readAll();

/// Pompe l'horloge simulée [fois] × 100 ms.
Future<void> pomper(WidgetTester tester, {int fois = 10}) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Touche « Essayer la démonstration » et attend l'accueil de la démonstration.
Future<void> toucherDemo(WidgetTester tester) async {
  final bouton = find.byKey(const Key('essayer_demonstration'));
  expect(bouton.hitTestable(), findsOneWidget, reason: 'bouton « Essayer la démonstration » visible et touchable');
  await tester.tap(bouton.hitTestable());
  await pomper(tester, fois: 5);
  for (var i = 0; i < 60 && find.byType(AccueilNouveau).evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await pomper(tester, fois: 20);
}

/// Touche « Quitter la démonstration » (bandeau).
Future<void> quitterDemo(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('quitter_demonstration')));
  await pomper(tester, fois: 20);
}

/// Fin de test : application démontée, démonstration fermée, minuteries épuisées.
Future<void> finDemo(WidgetTester tester) async {
  if (ModeDemo.estActif) await ModeDemo.quitter();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
  ModeDemo.horloge = DateTime.now;
}
