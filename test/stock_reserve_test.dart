// Stock réserve (serveur 2e4615e) : GET /info (Analyse Article) et GET /checkproduit (Fiche Article) renvoient
// `stockReserve`, `seuilReserve`, `seuilMiniRayon` (null si le produit n'est pas géré en réserve, absents d'un
// serveur ancien). Lecture tolérante, affichage « Stock rayon / Stock réserve / seuils / Total rayon + réserve »,
// « — » sans réserve, pastille « À réapprovisionner », 360 px sans débordement, thème sombre.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/models/analyse_article_model.dart';
import 'package:prestige_app/models/produit_model.dart';
import 'package:prestige_app/models/stock_reserve.dart';
import 'package:prestige_app/screens/analyse_article_screen.dart';
import 'package:prestige_app/screens/fiche_article_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/widgets/stock_reserve.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';

final _info = [
  {
    'produitId': 'P1', 'codeCip': '1234567', 'libelle': 'DOLIPRANE 1000MG', 'prixVente': 1500, 'prixAchat': 1000,
    'moyenne': 4.5, 'quantiteVendue': 30, 'stock': 3, 'quantiteMois': '5:1',
    'stockReserve': 20, 'seuilReserve': 10, 'seuilMiniRayon': 5,
  },
  {
    'produitId': 'P2', 'codeCip': '7654321', 'libelle': 'EFFERALGAN 500MG', 'prixVente': 900, 'prixAchat': 600,
    'moyenne': 1.0, 'quantiteVendue': 3, 'stock': 12, 'quantiteMois': '',
    'stockReserve': null, 'seuilReserve': null, 'seuilMiniRayon': null,
  },
];

final _check = [
  {'familleId': 'P1', 'familleCip': '1234567', 'familleLibelle': 'DOLIPRANE 1000MG', 'pachat': 1000, 'pvente': 1500, 'stock': 8,
   'stockReserve': '4', 'seuilReserve': '5', 'seuilMiniRayon': 2},
  {'familleId': 'P2', 'familleCip': '7654321', 'familleLibelle': 'EFFERALGAN 500MG', 'pachat': 600, 'pvente': 900, 'stock': 12},
];

Future<http.Response> _repondre(http.Request req) async {
  final p = req.url.path;
  Object corps = const {'data': [], 'total': 0};
  if (p.endsWith('/info')) corps = _info;
  if (p.endsWith('/checkproduit')) corps = _check;
  return http.Response(jsonEncode(corps), 200, headers: {'content-type': 'application/json; charset=utf-8'});
}

Future<void> _ecran360(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _chercher(WidgetTester tester, String texte) async {
  await tester.enterText(find.byType(TextField), texte);
  await tester.pump(const Duration(milliseconds: 600));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('Lecture tolérante', () {
    test('entierTolerant : nombre, décimal, texte, vide, absent, autre', () {
      expect(entierTolerant(7), 7);
      expect(entierTolerant(7.9), 7);
      expect(entierTolerant('12'), 12);
      expect(entierTolerant(' 12.0 '), 12);
      expect(entierTolerant('3,5'), 3);
      expect(entierTolerant(''), isNull);
      expect(entierTolerant('abc'), isNull);
      expect(entierTolerant(null), isNull);
      expect(entierTolerant(true), isNull);
      expect(entierTolerant(double.nan), isNull);
    });

    test('AnalyseArticle (/info) : champs présents, null, absents, texte, décimal', () {
      final present = AnalyseArticle.fromJson({'libelle': 'A', 'stock': 3, 'stockReserve': 20, 'seuilReserve': 10, 'seuilMiniRayon': 5});
      expect([present.stockReserve, present.seuilReserve, present.seuilMiniRayon], [20, 10, 5]);
      expect(present.reserve.total(3), 23);

      final nuls = AnalyseArticle.fromJson({'libelle': 'A', 'stock': 3, 'stockReserve': null, 'seuilReserve': null, 'seuilMiniRayon': null});
      expect(nuls.reserve.geree, isFalse);
      expect(nuls.reserve.total(3), isNull);

      final ancien = AnalyseArticle.fromJson({'libelle': 'A', 'stock': 3});
      expect([ancien.stockReserve, ancien.seuilReserve, ancien.seuilMiniRayon], [null, null, null]);
      expect(ancien.stock, 3, reason: 'le reste de la lecture est inchangé');

      final texte = AnalyseArticle.fromJson({'libelle': 'A', 'stockReserve': '15', 'seuilReserve': '4.0', 'seuilMiniRayon': 2.6});
      expect([texte.stockReserve, texte.seuilReserve, texte.seuilMiniRayon], [15, 4, 2]);

      final zero = AnalyseArticle.fromJson({'libelle': 'A', 'stockReserve': 0});
      expect(zero.reserve.geree, isTrue, reason: 'géré en réserve, rien en réserve');
    });

    test('Produit (/checkproduit) : champs présents, absents, texte, décimal', () {
      final p = Produit.fromJson({'familleCip': '1', 'stock': 8, 'stockReserve': '4', 'seuilReserve': 5.0, 'seuilMiniRayon': '2'});
      expect([p.stockReserve, p.seuilReserve, p.seuilMiniRayon], [4, 5, 2]);
      final ancien = Produit.fromJson({'familleCip': '1', 'stock': 8});
      expect(ancien.reserve.geree, isFalse);
      expect(ancien.stock, 8);
    });
  });

  group('Règles d\'affichage', () {
    test('lignes : avec réserve, seuils et total ; sans réserve « — » sans total', () {
      const r = StockReserve(stockReserve: 20, seuilReserve: 10, seuilMiniRayon: 5);
      expect(stockReserveInfos(3, r), [
        ('Stock rayon', '3'),
        ('Stock réserve', '20'),
        ('Seuil réserve', '10'),
        ('Seuil mini rayon', '5'),
        ('Total rayon + réserve', '23'),
      ]);
      expect(stockReserveInfos(12, StockReserve.aucun), [('Stock rayon', '12'), ('Stock réserve', '—')]);
      expect(stockReserveInfos(12, StockReserve.aucun, avecRayon: false), [('Stock réserve', '—')]);
      // Seuils à 0 : non renseignés (ni affichés, ni alerte).
      expect(stockReserveInfos(0, const StockReserve(stockReserve: 0, seuilReserve: 0, seuilMiniRayon: 0)),
          [('Stock rayon', '0'), ('Stock réserve', '0'), ('Total rayon + réserve', '0')]);
    });

    test('alerte : rayon ≤ seuil mini ou réserve ≤ seuil réserve', () {
      const r = StockReserve(stockReserve: 20, seuilReserve: 10, seuilMiniRayon: 5);
      expect(r.aReapprovisionner(5), isTrue);
      expect(r.aReapprovisionner(6), isFalse);
      expect(const StockReserve(stockReserve: 10, seuilReserve: 10).aReapprovisionner(50), isTrue);
      expect(StockReserve.aucun.aReapprovisionner(0), isFalse, reason: 'non géré en réserve : pas d\'alerte');
      expect(const StockReserve(stockReserve: 0, seuilReserve: 0, seuilMiniRayon: 0).aReapprovisionner(0), isFalse);
    });

    testWidgets('pastille lisible en thème sombre', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(
          body: StockReserveResume(reserve: StockReserve(stockReserve: 2, seuilReserve: 5), rayon: 1),
        ),
      ));
      expect(find.text('Réserve : 2 · Total : 3'), findsOneWidget);
      expect(find.text('À réapprovisionner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Écrans', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true});
      FlutterSecureStorage.setMockInitialValues({});
      ApiService.client = MockClient(_repondre);
      JournalApp.actif = false;
    });
    tearDown(() => ApiService.client = http.Client());

    testWidgets('Analyse Article (360 px) : liste et détails avec réserve, seuils, total, alerte', (tester) async {
      await _ecran360(tester);
      await monterAvecProviders(tester, ecran: const AnalyseArticleScreen());
      await _chercher(tester, 'doli');
      expect(find.text('DOLIPRANE 1000MG'), findsOneWidget);
      expect(find.text('Réserve : 20 · Total : 23'), findsOneWidget);
      expect(find.text('À réapprovisionner'), findsOneWidget, reason: 'rayon 3 ≤ seuil mini 5');
      expect(find.textContaining('Réserve :'), findsOneWidget, reason: 'rien pour le produit non géré en réserve');
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('DOLIPRANE 1000MG'));
      await tester.pumpAndSettle();
      final bloc = find.byKey(const ValueKey('analyse-stock-reserve'));
      for (final t in ['Stock rayon', '3', 'Stock réserve', '20', 'Seuil réserve', '10', 'Seuil mini rayon', '5', 'Total rayon + réserve', '23']) {
        expect(find.descendant(of: bloc, matching: find.text(t)), findsOneWidget, reason: t);
      }
      expect(find.descendant(of: bloc, matching: find.byKey(const ValueKey('pastille-reappro'))), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Analyse Article : sans réserve « — », ni total ni alerte', (tester) async {
      await _ecran360(tester);
      await monterAvecProviders(tester, ecran: const AnalyseArticleScreen());
      await _chercher(tester, 'effe');
      await tester.tap(find.text('EFFERALGAN 500MG'));
      await tester.pumpAndSettle();
      final bloc = find.byKey(const ValueKey('analyse-stock-reserve'));
      expect(find.descendant(of: bloc, matching: find.text('Stock réserve')), findsOneWidget);
      expect(find.descendant(of: bloc, matching: find.text('—')), findsOneWidget);
      expect(find.descendant(of: bloc, matching: find.text('Total rayon + réserve')), findsNothing);
      expect(find.descendant(of: bloc, matching: find.text('Seuil réserve')), findsNothing);
      expect(find.descendant(of: bloc, matching: find.byKey(const ValueKey('pastille-reappro'))), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Fiche Article (/checkproduit, 360 px) : réserve en texte, total, alerte ; serveur ancien « — »', (tester) async {
      await _ecran360(tester);
      await monterAvecProviders(tester, ecran: const FicheArticleScreen());
      await _chercher(tester, 'doli');
      expect(find.text('Réserve : 4 · Total : 12'), findsOneWidget);
      expect(find.text('À réapprovisionner'), findsOneWidget, reason: 'réserve 4 ≤ seuil 5');
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('DOLIPRANE 1000MG'));
      await tester.pumpAndSettle();
      expect(find.text('Stock réserve'), findsOneWidget);
      expect(find.text('Total rayon + réserve'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Seuil mini rayon'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Fermer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('EFFERALGAN 500MG'));
      await tester.pumpAndSettle();
      expect(find.text('Stock réserve'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('Total rayon + réserve'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
