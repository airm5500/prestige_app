// ERGONOMIE — retours du pharmacien pour la 3.16.0 (données fictives) :
//  2. Analyse Article, historique des mouvements : UNE ligne par mouvement, date et quantité sur la même ligne, la
//     quantité (1 à 4 chiffres) jamais coupée ni renvoyée à la ligne, à 320 et 360 dp (texte ×1 et ×1,3 : seul le
//     libellé peut être raccourci par « … », jamais la quantité) ; les autres lignes de détail gardent leur
//     comportement d'origine (deux moitiés, retour à la ligne permis) ;
//  4. indicateur de défilement vertical TOUJOURS visible sur les listes de l'application (MaterialApp.scrollBehavior),
//     rien sur une liste horizontale ni sur une liste courte, aucune erreur de contrôleur partagé (deux listes sous le
//     même Scaffold, onglets) ; dans l'application : Pilotage, onglet « À suivre » compris (toutes les listes).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/analyse_article_model.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/widgets/defilement.dart';

import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

AnalyseArticle article(int qte) => AnalyseArticle.fromJson({
      'produitId': 'PRD-TEST-9', 'codeCip': '9990009', 'libelle': 'ARTICLE FICTIF DE TEST 500MG', 'prixVente': 1200, 'prixAchat': 800,
      'moyenne': 1.5, 'moyenneJour': 0.05, 'quantiteVendue': qte, 'stock': qte, 'quantiteMois': '',
      'dateDerniereVente': '12/11/2026', 'qteDerniereVente': qte,
      'dateDernierAchat': '28/10/2026', 'qteDernierAchat': qte,
      'dateDernierInventaire': '31/12/2025', 'qteDernierInventaire': qte,
    });

/// Le texte [f] a-t-il été coupé (lignes ou « … ») ?
bool coupe(WidgetTester tester, Finder f) => tester.renderObject<RenderParagraph>(find.descendant(of: f, matching: find.byType(RichText)).first).didExceedMaxLines;

Widget liste(int n, {Key? key, Axis axe = Axis.vertical}) =>
    ListView(key: key, scrollDirection: axe, children: [for (var i = 0; i < n; i++) SizedBox(height: 60, width: 120, child: Text('Ligne fictive $i'))]);

Finder indicateurs() => find.byKey(const Key('indicateur_defilement'));
bool visible(WidgetTester tester, Finder f) => indicateurVisible(tester.element(f));

Future<void> monterListes(WidgetTester tester, Widget corps) async {
  await tester.pumpWidget(MaterialApp(scrollBehavior: const DefilementPrestige(), home: Scaffold(body: corps)));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() => brancherEnMemoire(serveur));

  group('2 · Historique des mouvements sur une ligne', () {
    for (final largeur in [320.0, 360.0]) {
      for (final echelle in [1.0, 1.3]) {
        testWidgets('$largeur dp, texte ×$echelle : une ligne par mouvement, quantité de 1 à 4 chiffres entière', (tester) async {
          tester.view.devicePixelRatio = 2.0;
          tester.view.physicalSize = Size(largeur * 2, 2400 * 2);
          tester.platformDispatcher.textScaleFactorTestValue = echelle;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          preparerNouvelle(serveur);
          for (final qte in [7, 42, 315, 2048]) {
            await ouvrirEcran(tester, serveur, DetailAnalyseArticle(article: article(qte)), pret: find.byKey(const Key('mouvement_vente')));
            for (final m in ['vente', 'achat', 'inventaire']) {
              final ligne = find.byKey(Key('mouvement_$m'));
              final w = tester.widget<LigneDetail>(ligne);
              expect(w.valeur, 'Qté $qte');
              final textes = find.descendant(of: ligne, matching: find.byType(Text));
              expect(textes, findsNWidgets(2));
              final libelle = textes.at(0), quantite = textes.at(1);
              // Une seule ligne : libellé et quantité à la même hauteur, chacun sur une ligne.
              final hLibelle = tester.getSize(libelle).height, hQuantite = tester.getSize(quantite).height;
              expect(hQuantite, lessThan(14.5 * echelle * 2), reason: '$m, Qté $qte : quantité sur une ligne');
              expect(hLibelle, lessThan(14 * echelle * 2), reason: '$m : libellé sur une ligne');
              expect(tester.getCenter(libelle).dy, closeTo(tester.getCenter(quantite).dy, 2));
              expect(coupe(tester, quantite), isFalse, reason: '$m : quantité $qte jamais coupée');
              // Quantité entièrement dans la carte (rien ne déborde à droite).
              expect(tester.getRect(quantite).right, lessThanOrEqualTo(largeur));
              if (echelle == 1.0) {
                expect(coupe(tester, libelle), isFalse, reason: '$m à $largeur dp : date entière (« ${w.libelle} »)');
              }
            }
            // Autre ligne de détail (Désignation) : comportement d'origine, retour à la ligne permis.
            final designation = find.byWidgetPredicate((w) => w is LigneDetail && w.libelle == 'Désignation');
            expect(tester.widget<LigneDetail>(designation).uneLigne, isFalse);
            expect(tester.takeException(), isNull);
            await fermerApplication(tester);
          }
        });
      }
    }
  });

  group('4 · Indicateur de défilement', () {
    testWidgets('liste longue : indicateur visible dès l\'ouverture et après défilement (ne s\'efface pas) ; liste courte : rien', (tester) async {
      await monterListes(tester, Column(children: [Expanded(child: liste(100, key: const Key('longue'))), SizedBox(height: 120, child: liste(1))]));
      expect(indicateurs(), findsNWidgets(2));
      final longue = find.descendant(of: find.byKey(const Key('longue')), matching: indicateurs());
      expect(visible(tester, longue), isTrue);
      await tester.drag(find.byKey(const Key('longue')), const Offset(0, -800));
      await tester.pump(const Duration(seconds: 5));
      expect(visible(tester, longue), isTrue, reason: 'toujours visible, même 5 s après le défilement');
      final courte = indicateurs().evaluate().where((e) => !visible(tester, find.byElementPredicate((x) => x == e))).length;
      expect(courte, 1, reason: 'liste plus courte que l\'écran : rien de dessiné');
      expect(tester.takeException(), isNull);
    });

    testWidgets('liste horizontale : aucun indicateur ; ses toucher ne sont pas captés par l\'indicateur', (tester) async {
      var touche = 0;
      await monterListes(
          tester,
          ListView(children: [
            SizedBox(height: 80, child: liste(50, axe: Axis.horizontal)),
            for (var i = 0; i < 60; i++)
              ListTile(key: Key('ligne_$i'), title: Text('Ligne fictive $i'), trailing: const Icon(Icons.chevron_right), onTap: () => touche++),
          ]));
      expect(indicateurs(), findsOneWidget, reason: 'seule la liste verticale');
      // Toucher tout au bord droit (là où le curseur est dessiné) atteint la ligne.
      final r = tester.getRect(find.byKey(const Key('ligne_0')));
      await tester.tapAt(Offset(r.right - 2, r.center.dy));
      expect(touche, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('contrôleur partagé : deux listes sous le même Scaffold (PrimaryScrollController), onglets : aucune erreur', (tester) async {
      await monterListes(
          tester,
          DefaultTabController(
            length: 2,
            child: Column(children: [
              const TabBar(tabs: [Tab(text: 'Synthèse'), Tab(text: 'À suivre')], labelColor: Colors.black),
              Expanded(child: TabBarView(children: [liste(80), liste(80)])),
              Expanded(child: liste(80)),
            ]),
          ));
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(TabBarView), const Offset(0, -500));
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('À suivre'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(TabBarView), const Offset(0, -500));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(indicateurs().evaluate().where((e) => indicateurVisible(e)).length, greaterThanOrEqualTo(2));
    });

    testWidgets('application : comportement de défilement global (nouvelle interface, écran réel)', (tester) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(360 * 2, 640 * 2);
      addTearDown(tester.view.reset);
      preparerNouvelle(serveur);
      await ouvrirEcran(tester, serveur, DetailAnalyseArticle(article: article(12)), pret: find.byKey(const Key('defilement_detail')));
      expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).scrollBehavior, isA<DefilementPrestige>());
      final detail = find.descendant(of: find.byKey(const Key('defilement_detail')), matching: indicateurs());
      expect(detail, findsOneWidget);
      final position = tester.state<ScrollableState>(find.descendant(of: find.byKey(const Key('defilement_detail')), matching: find.byType(Scrollable))).position;
      expect(position.maxScrollExtent, greaterThan(0), reason: 'fiche plus longue que l\'écran');
      expect(visible(tester, detail), isTrue);
      expect(tester.takeException(), isNull);
      await fermerApplication(tester);
    });
  });
}
