// Étape 1f : annulation de vente (GET /vente/annulation/{id}, route serveur INCHANGÉE) protégée contre le
// double envoi : confirmation, boutons bloqués, une seule requête en vol, relecture avant et après,
// jamais de renvoi automatique quand le serveur ne répond pas.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/screens/annulation_vente_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';

const idA = 'b097fac5-bac9-47c8-9221-79d0bc92d885';
const idB = '838b80ed-5e68-4ccc-81ef-9c21b4749516';

bool annuleeA = false;
final annulations = <http.Request>[];
final toasts = <String>[];

/// Comportement de la route d'annulation.
Future<http.Response> Function() routeAnnulation = () async {
  annuleeA = true;
  return http.Response('{"success":true}', 200);
};

Map<String, dynamic> vente(String id, String ref, bool cancel) => {
      'strREFTICKET': '5240513328',
      'cancel': cancel,
      'lgPREENREGISTREMENTID': id,
      'strTYPEVENTE': 'VNO',
      'strSTATUT': 'is_Closed',
      'avoir': false,
      'intPRICE': 2500,
      'HEUREVENTE': '14:52',
      'userVendeurName': 'KONAN',
      'dtCREATED': '19/08/2026',
      'strREF': ref,
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true});
    FlutterSecureStorage.setMockInitialValues({});
    JournalApp.actif = false;
    annuleeA = false;
    annulations.clear();
    toasts.clear();
    routeAnnulation = () async {
      annuleeA = true;
      return http.Response('{"success":true}', 200);
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async {
        if (call.method == 'showToast') toasts.add('${(call.arguments as Map)['msg']}');
        return true;
      },
    );
    ApiService.client = MockClient((req) async {
      if (req.url.path.contains('/vente/annulation/')) {
        annulations.add(req);
        return routeAnnulation();
      }
      if (req.url.path.endsWith('/ventestats')) {
        return http.Response(jsonEncode({'total': 2, 'data': [vente(idA, '260819_00001', annuleeA), vente(idB, '260819_00002', false)]}), 200);
      }
      return http.Response('{}', 200);
    });
  });

  tearDown(() => ApiService.client = http.Client());

  Future<void> attendre(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  Future<void> ouvrirEtRechercher(WidgetTester tester) async {
    await monterAvecProviders(tester, ecran: const AnnulationVenteScreen());
    await tester.enterText(find.byType(TextField), '260819');
    await tester.tap(find.text('Rechercher les Ventes'));
    await attendre(tester);
    expect(find.text('Vente N° 260819_00001'), findsOneWidget);
  }

  Future<void> demanderAnnulation(WidgetTester tester, {bool confirmer = true}) async {
    await tester.tap(find.byKey(const Key('annuler_$idA')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cette annulation est définitive.'), findsOneWidget);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(RegExp(r'2.500.FCFA'))), findsOneWidget);
    await tester.tap(find.text(confirmer ? 'Oui, Annuler' : 'Non'));
    await tester.pump();
  }

  testWidgets('une seule requête en vol : boutons bloqués pendant l\'envoi, route GET inchangée', (tester) async {
    final reponse = Completer<http.Response>();
    routeAnnulation = () => reponse.future;
    await ouvrirEtRechercher(tester);
    await demanderAnnulation(tester);
    await attendre(tester);
    expect(annulations, hasLength(1));
    expect(annulations.single.method, 'GET');
    expect(annulations.single.url.path, '/prestige/api/v1/vente/annulation/$idA');

    // Pendant l'envoi : indicateur sur la ligne, autres « Annuler » et la recherche bloqués.
    expect(find.byKey(const Key('annuler_$idA')), findsNothing);
    final autre = tester.widget<IconButton>(find.byKey(const Key('annuler_$idB')));
    expect(autre.onPressed, isNull);
    await tester.tap(find.byKey(const Key('annuler_$idB')), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Oui, Annuler'), findsNothing);

    annuleeA = true;
    reponse.complete(http.Response('{"success":true}', 200));
    await attendre(tester);
    expect(annulations, hasLength(1));
    expect(toasts.last, 'Vente annulée avec succès');
    // Résultat relu : la vente apparaît annulée, son bouton est désactivé.
    expect(tester.widget<IconButton>(find.byKey(const Key('annuler_$idA'))).onPressed, isNull);
    expect(tester.widget<IconButton>(find.byKey(const Key('annuler_$idB'))).onPressed, isNotNull);
  });

  testWidgets('« Non » : rien n\'est envoyé', (tester) async {
    await ouvrirEtRechercher(tester);
    await demanderAnnulation(tester, confirmer: false);
    await attendre(tester);
    expect(annulations, isEmpty);
  });

  testWidgets('déjà annulée (relecture avant envoi) : aucun envoi', (tester) async {
    await ouvrirEtRechercher(tester);
    annuleeA = true; // annulée entre-temps (autre poste)
    await demanderAnnulation(tester);
    await attendre(tester);
    expect(annulations, isEmpty);
    expect(toasts.last, contains('déjà annulée'));
  });

  testWidgets('pas de réponse mais annulation faite : pas de renvoi, état vérifié', (tester) async {
    routeAnnulation = () async {
      annuleeA = true; // le serveur a traité la demande…
      throw const SocketException('Connection reset'); // …mais la réponse est perdue
    };
    await ouvrirEtRechercher(tester);
    await demanderAnnulation(tester);
    await attendre(tester);
    expect(annulations, hasLength(1));
    expect(toasts.last, contains('est bien annulée (vérifié)'));
  });

  testWidgets('délai dépassé sans annulation : pas de renvoi, l\'utilisateur peut réessayer', (tester) async {
    routeAnnulation = () => Completer<http.Response>().future;
    await ouvrirEtRechercher(tester);
    await demanderAnnulation(tester);
    await tester.pump(const Duration(seconds: 46));
    await attendre(tester);
    expect(annulations, hasLength(1));
    expect(toasts.last, contains('n\'est pas annulée. Vous pouvez réessayer.'));
    expect(tester.widget<IconButton>(find.byKey(const Key('annuler_$idA'))).onPressed, isNotNull);
  });

  testWidgets('refus du serveur : message du serveur', (tester) async {
    routeAnnulation = () async => http.Response('{"msg":"L\'opération a échoué","success":false}', 200, headers: {'content-type': 'application/json; charset=utf-8'});
    await ouvrirEtRechercher(tester);
    await demanderAnnulation(tester);
    await attendre(tester);
    expect(annulations, hasLength(1));
    expect(toasts.last, "L'opération a échoué");
  });
}
