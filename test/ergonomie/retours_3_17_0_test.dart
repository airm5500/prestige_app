// ERGONOMIE — réponse du serveur aux demandes 67 et 68 (3.17.0), serveur À JOUR (données fictives) :
//  67. CA crédit paginé, à 320 et 360 dp (texte ×1 et ×1,3) et sur tablette (1280 × 800 dp) : « Lecture de la
//      période… » lisible pendant la première page lente (rien ne déborde), chiffres clés du serveur entiers, cartes
//      (téléphone) ou tableau (tablette) qui s'allongent d'une page au défilement, pied « n lignes affichées sur N » ;
//  68. carte TVA de l'accueil lue par /tableau-bord/tva : une ligne par taux, montants entiers, rien ne déborde.
// Le rendu complet (contraste, cibles tactiles, toutes tailles) est vérifié par affichage_nouvelle_interface_test.dart
// (cas « 3.17.0 », support/cas_retours_3_17_0.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart' show formaterMontant;
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';

import '../support/donnees_3_17_0.dart';
import '../support/donnees_lot3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/grandes_donnees.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

Finder cle(String k) => find.byKey(Key(k));

void taille(WidgetTester tester, double largeur, double hauteur, double echelle) {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = Size(largeur * 2, hauteur * 2);
  tester.platformDispatcher.textScaleFactorTestValue = echelle;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Le texte [f] tient-il entièrement dans l'écran de [largeur] dp ?
void dansLEcran(WidgetTester tester, Finder f, double largeur, String quoi) {
  final r = tester.getRect(f);
  expect(r.left, greaterThanOrEqualTo(0), reason: quoi);
  expect(r.right, lessThanOrEqualTo(largeur), reason: quoi);
}

Future<void> defiler(WidgetTester tester, {int fois = 12}) async {
  for (var i = 0; i < fois; i++) {
    await tester.drag(cle('defilement_module'), const Offset(0, -1500));
    await tester.pump(const Duration(milliseconds: 100));
  }
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    brancherEnMemoire(serveur);
    CaCreditDonnees.oublierModes();
  });

  group('67 · CA crédit paginé sur téléphone', () {
    for (final largeur in [320.0, 360.0]) {
      for (final echelle in [1.0, 1.3]) {
        testWidgets('$largeur dp, texte ×$echelle : lecture lente lisible, chiffres clés entiers, page suivante au défilement', (tester) async {
          taille(tester, largeur, 640, echelle);
          preparerNouvelle(serveur);
          final lignes = GrandesDonnees.caCredit(130);
          Donnees3170.installerCaCredit(serveur, lignes, delai: (p) => Donnees3170.premiere(p) ? const Duration(seconds: 15) : null);
          await ouvrirEcran(tester, serveur, const CaCreditNouveau(), pret: find.textContaining('Lecture de la période…'));
          final attente = find.textContaining('Lecture de la période…');
          dansLEcran(tester, attente, largeur, 'texte d\'attente entier');
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 16; i++) {
            await tester.pump(const Duration(seconds: 1));
          }
          await tester.pump(const Duration(milliseconds: 500));
          expect(cle('chiffre_ventes'), findsOneWidget);
          final montant = formaterMontant(lignes.fold<num>(0, (s, o) => s + (o['montant'] as num)));
          for (final (id, valeur) in [('montant', montant), ('ventes', '130')]) {
            final f = find.descendant(of: find.byWidgetPredicate((w) => w is ChiffreCle && w.id == id), matching: find.text(valeur));
            expect(f, findsOneWidget, reason: '$id : $valeur');
            dansLEcran(tester, f, largeur, '$id entier');
          }
          await defiler(tester);
          expect([for (final r in serveur.recues('/ca-credit')) r.parametres['start']], containsAllInOrder(['0', '50']));
          expect(tester.takeException(), isNull);
          await fermerApplication(tester);
        });
      }
    }
  });

  testWidgets('67 · tablette 1280 × 800 dp : tableau de 50 lignes, puis 100 au défilement, pied « lignes affichées »', (tester) async {
    taille(tester, 1280, 800, 1.0);
    preparerNouvelle(serveur);
    Donnees3170.installerCaCredit(serveur, GrandesDonnees.caCredit(130));
    await ouvrirEcran(tester, serveur, const CaCreditNouveau(), pret: cle('chiffre_ventes'));
    int lignesTableau() => tester.widget<TableauDense>(find.byType(TableauDense, skipOffstage: false)).lignes.length;
    expect(lignesTableau(), 50);
    expect(find.byType(CarteLigne), findsNothing, reason: 'tablette : tableau, pas de cartes');
    await defiler(tester, fois: 3);
    await pomper(tester, () => lignesTableau() >= 100, raison: 'page suivante ajoutée au tableau', pas: const Duration(milliseconds: 200), max: 30);
    for (var i = 0; i < 6 && lignesTableau() < 130; i++) {
      await defiler(tester, fois: 3);
    }
    expect(lignesTableau(), 130);
    expect(find.text('130 lignes affichées sur 130'), findsOneWidget);
    // Tout est chargé : ligne de total du tableau (montant du serveur).
    expect(tester.widget<TableauDense>(find.byType(TableauDense)).total, isNotNull);
    expect(tester.takeException(), isNull);
    await fermerApplication(tester);
  });

  group('68 · Carte TVA (/tableau-bord/tva)', () {
    for (final largeur in [320.0, 360.0]) {
      for (final echelle in [1.0, 1.3]) {
        testWidgets('$largeur dp, texte ×$echelle : une ligne par taux, montants entiers', (tester) async {
          taille(tester, largeur, 2400, echelle);
          preparerNouvelle(serveur);
          donneesLot3(serveur);
          serveur.route('/tableau-bord/tva', (r) => ReponseFausse.json(Donnees3170.tva()), methode: 'GET');
          await ouvrirEcran(tester, serveur, Scaffold(body: AccueilTableauPrestige(maintenant: () => DateTime(2026, 10, 21, 11))),
              pret: cle('defilement_tableau_bord'));
          final liste = find.descendant(of: cle('defilement_tableau_bord'), matching: find.byType(Scrollable)).first;
          await tester.scrollUntilVisible(cle('carte_tableau_bord_tva'), 300, scrollable: liste, maxScrolls: 60);
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
          // Les cartes au-dessus ont pu grandir à l'arrivée de leurs réponses : la carte est ramenée à l'écran.
          await tester.scrollUntilVisible(cle('carte_tableau_bord_tva'), 300, scrollable: liste, maxScrolls: 60);
          await Scrollable.ensureVisible(tester.element(find.byKey(const Key('carte_tableau_bord_tva'), skipOffstage: false)));
          await tester.pump(const Duration(milliseconds: 250));
          final lignes = find.descendant(of: cle('carte_tableau_bord_tva'), matching: find.byType(LigneDetail));
          expect(lignes, findsNWidgets(4), reason: '3 taux + total TTC');
          for (final m in ['1 050 000', '109 000', '590 000', '1 749 000']) {
            final f = find.descendant(of: cle('carte_tableau_bord_tva'), matching: find.textContaining(m.replaceAll(' ', ' ')));
            expect(f, findsOneWidget, reason: 'montant $m');
            dansLEcran(tester, f, largeur, 'montant $m entier');
          }
          expect(serveur.recues('/tvas'), isEmpty);
          expect(tester.takeException(), isNull);
          await fermerApplication(tester);
        });
      }
    }
  });
}
