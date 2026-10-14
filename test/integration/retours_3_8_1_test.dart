// Décision du pharmacien appliquée en 3.8.1 : Suivi 20/80, « Nombre d'articles » vraiment appliqué (correction).
// Le serveur lit « topN » (FamilleArticleRessource.vingtQuatreVingt ; absent ou ≤ 0 = tous) et ignore « limit ».
// Écran d'ORIGINE et NOUVEL écran contre le faux serveur (client en mémoire, horloge simulée, écran très haut pour
// que toutes les lignes soient construites) :
//  - paramètres transmis : topN = nombre choisi (50 par défaut, 80 saisi), limit gardé ;
//  - nombre de lignes affichées = nombre demandé (serveur qui applique topN) ;
//  - serveur plus ancien qui ignorerait topN (renvoie tout) : l'application ne garde que les N premiers ;
//  - non-régression « tous » : nombre demandé ≥ articles disponibles (9 999) = tous les articles, comme avant ;
//  - par quantité avec un serveur qui ignore topN : les N premiers par quantité.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_2080_nouveau.dart';
import 'package:prestige_app/screens/suivi_20_80_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();
const route = AppConstants.suivi2080Endpoint;

Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> monter(WidgetTester tester, Widget Function() ecran, {required bool nouvelle}) async {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 40000 * 2.625);
  addTearDown(tester.view.reset);
  preparerTelephone(serveur, nouvelle: nouvelle);
  ApiService.client = serveur.clientMemoire();
  serveur.oublierRequetes();
  await ecranConnecte(ecran)(tester, serveur);
  await pomper(tester);
}

Future<void> demonter(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

Future<void> toucher(WidgetTester tester, Finder f, [int fois = 8]) async {
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(f.first);
  await pomper(tester, fois);
}

Map<String, String> derniers() => serveur.recues(route).last.parametres;

/// Écran d'origine : saisit [nombre] (vide = défaut) puis « Afficher le Suivi » ; rend le nombre de cartes affichées.
Future<int> afficherOrigine(WidgetTester tester, String? nombre) async {
  if (nombre != null) await tester.enterText(find.byType(TextFormField), nombre);
  await toucher(tester, find.text('Afficher le Suivi'));
  return find.byType(Card).evaluate().length;
}

/// Nouvel écran : nombre d'articles (chiffre clé) après la feuille des filtres réglée sur [nombre].
Future<String> filtrerNouveau(WidgetTester tester, String nombre) async {
  await toucher(tester, find.byKey(const Key('bouton_filtres')), 6);
  await tester.enterText(find.byKey(const Key('filtre_limite')), nombre);
  await pomper(tester, 2);
  await toucher(tester, find.byKey(const Key('filtres_appliquer')));
  return articles();
}

String articles() => (find.byKey(const Key('chiffre_articles')).evaluate().single.widget as Text).data!;

/// Serveur plus ancien : ignore topN (et limit), renvoie les 120 articles.
void serveurSansTopN() =>
    serveur.route(route, (r) => ReponseFausse.json(DonneesLot3.suivi2080(DonneesLot3.articles2080)), methode: 'GET');

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);

  setUp(() {
    serveur
      ..installerRoutesParDefaut()
      ..coupe = false;
    donneesLot3(serveur);
  });

  group('Écran d\'origine', () {
    testWidgets('topN transmis (50 par défaut, 80 saisi, vide = 50), limit gardé ; lignes = nombre demandé', (tester) async {
      await monter(tester, () => const Suivi2080Screen(), nouvelle: false);
      expect(await afficherOrigine(tester, null), 50);
      expect(derniers(), allOf(containsPair('topN', '50'), containsPair('limit', '50')));
      expect(await afficherOrigine(tester, '80'), 80);
      expect(derniers(), allOf(containsPair('topN', '80'), containsPair('limit', '80')));
      expect(await afficherOrigine(tester, '7'), 7);
      expect(derniers()['topN'], '7');
      expect(await afficherOrigine(tester, ''), 50, reason: 'champ vide : 50, comme avant');
      expect(derniers()['topN'], '50');
      expect(serveur.recues(route), hasLength(4), reason: 'une requête par appui');
      await demonter(tester);
    });

    testWidgets('serveur qui ignore topN (renvoie tout) : seulement les N premiers affichés', (tester) async {
      serveurSansTopN();
      await monter(tester, () => const Suivi2080Screen(), nouvelle: false);
      expect(await afficherOrigine(tester, '30'), 30);
      expect(find.text(DonneesFictives.libelleArticle1), findsOneWidget, reason: 'les premiers, dans l\'ordre du serveur');
      expect(find.text('PRODUIT FICTIF 20-80 N30'), findsOneWidget);
      expect(find.text('PRODUIT FICTIF 20-80 N31'), findsNothing);
      await demonter(tester);
    });

    testWidgets('non-régression « tous » : 9 999 demandés = les 120 articles, comme avant', (tester) async {
      await monter(tester, () => const Suivi2080Screen(), nouvelle: false);
      expect(await afficherOrigine(tester, '9999'), DonneesLot3.articles2080);
      expect(derniers()['topN'], '9999');
      await demonter(tester);
    });
  });

  group('Nouvel écran', () {
    testWidgets('topN transmis (50 à l\'ouverture, 80 filtré, retrait = 50), limit gardé ; articles = nombre demandé',
        (tester) async {
      await monter(tester, () => const Suivi2080Nouveau(), nouvelle: true);
      expect(derniers(), allOf(containsPair('topN', '50'), containsPair('limit', '50')));
      expect(articles(), '50');
      expect(await filtrerNouveau(tester, '80'), '80');
      expect(derniers(), allOf(containsPair('topN', '80'), containsPair('limit', '80')));
      expect(await filtrerNouveau(tester, '12'), '12');
      expect(derniers()['topN'], '12');
      expect(find.byType(CarteLigne).evaluate().length, 12);
      await toucher(tester, find.byKey(const Key('filtres_retirer')));
      expect(derniers()['topN'], '50');
      expect(articles(), '50');
      // Par quantité : topN garde la même valeur, vingtType=QTY en plus.
      await toucher(tester, find.byKey(const Key('classement_quantite')));
      expect(derniers(), allOf(containsPair('topN', '50'), containsPair('vingtType', 'QTY')));
      expect(serveur.recues(route), hasLength(5));
      await demonter(tester);
    });

    testWidgets('serveur qui ignore topN : seulement les N premiers (par quantité : les N premiers par quantité)',
        (tester) async {
      serveurSansTopN();
      await monter(tester, () => const Suivi2080Nouveau(), nouvelle: true);
      expect(articles(), '50', reason: '120 reçus, 50 gardés');
      expect(await filtrerNouveau(tester, '5'), '5');
      expect(find.byType(CarteLigne).evaluate().length, 5);
      // Données du faux serveur : la quantité décroît avec le rang, l'ordre par quantité est donc le même.
      await toucher(tester, find.byKey(const Key('classement_quantite')));
      expect(articles(), '5');
      expect([for (final e in find.byType(CarteLigne).evaluate()) (e.widget as CarteLigne).titre].last,
          '5. PRODUIT FICTIF 20-80 N5');
      await demonter(tester);
    });

    testWidgets('non-régression « tous » : 9 999 demandés = les 120 articles, comme avant', (tester) async {
      await monter(tester, () => const Suivi2080Nouveau(), nouvelle: true);
      expect(await filtrerNouveau(tester, '9999'), '120');
      expect(derniers()['topN'], '9999');
      await demonter(tester);
    });
  });
}
