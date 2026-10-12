// Configuration commune à tous les tests.
// Polices Lato (google_fonts) : l'application les télécharge à l'exécution. Pendant les tests, aucun accès
// réseau : la requête de police reste simplement en attente (pas d'erreur « Failed to load font »), et la
// police de secours est utilisée — comme sur un téléphone hors ligne au premier lancement.
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  google_fonts.httpClient = MockClient((_) => Completer<http.Response>().future);
  await testMain();
}
