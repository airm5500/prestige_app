// ERGONOMIE — 3.11.2, Détail CA « Jour par jour » : le % d'évolution du Total, placé sous le Total, n'agrandit PAS
// la carte (sur chaque carte réelle de l'écran, la colonne du Total et du % reste moins haute que celle de gauche :
// la hauteur de la carte ne dépend donc pas du %), téléphone et Sunmi, texte ×1 et ×1,3 ; hausse en vert, baisse en rouge, toujours avec flèche et signe ; rien pour le premier jour.
// (L'écran entier passe aussi aux 5 tailles × 2 échelles : cas « 3.11.2 · Détail CA · jour par jour ».)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';

import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

const appareils = <(String, Size, double)>[('téléphone', Size(411, 891), 2.625), ('Sunmi', Size(360, 720), 2.0)];

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    brancherEnMemoire(serveur);
    donneesLot1(serveur);
  });

  for (final (nom, dp, dpr) in appareils) {
    for (final echelle in [1.0, 1.3]) {
      testWidgets('Détail CA jour par jour ($nom, texte ×$echelle) : le % n\'agrandit pas les cartes', (tester) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(dp.width * dpr, dp.height * dpr * 4); // toutes les cartes à l'écran
        tester.platformDispatcher.textScaleFactorTestValue = echelle;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await ouvrirEcran(tester, serveur, const DetailCaNouveau(), pret: find.byKey(const Key('jour_evolution_2')));
        final cartes = find.byType(CarteLigne);
        expect(cartes, findsNWidgets(3));
        // La hauteur d'une carte est celle de sa plus haute colonne : la colonne de droite (Total et %) doit rester
        // moins haute que celle de gauche (date et montants par mode), sinon le % agrandirait la carte.
        for (var i = 0; i < 3; i++) {
          final carte = cartes.at(i);
          final gauche = find.descendant(of: find.descendant(of: carte, matching: find.byType(Expanded)).first, matching: find.byType(Column)).first;
          final valeur = tester.widget<CarteLigne>(carte).valeur!;
          final droite = find.ancestor(of: find.descendant(of: carte, matching: find.text(valeur)), matching: find.byType(Column)).first;
          expect(tester.getSize(droite).height, lessThanOrEqualTo(tester.getSize(gauche).height),
              reason: 'carte $i : colonne du Total ${tester.getSize(droite).height} > colonne de gauche ${tester.getSize(gauche).height}');
        }
        // Premier jour : rien ; 13/10 : +18,0 % vert, flèche montante ; 14/10 : −18,3 % rouge, flèche descendante.
        expect(find.descendant(of: find.byKey(const Key('jour_evolution_0')), matching: find.byType(Text)), findsNothing);
        Text texte(int i) => tester.widget<Text>(find.descendant(of: find.byKey(Key('jour_evolution_$i')), matching: find.byType(Text)));
        expect((texte(1).data, texte(1).style!.color), ('+18,0 %', Charte.vertTexte));
        expect((texte(2).data, texte(2).style!.color), ('−18,3 %', Charte.rougeTexte));
        expect(find.descendant(of: find.byKey(const Key('jour_evolution_1')), matching: find.byIcon(Icons.arrow_upward)), findsOneWidget);
        expect(find.descendant(of: find.byKey(const Key('jour_evolution_2')), matching: find.byIcon(Icons.arrow_downward)), findsOneWidget);
        expect(tester.takeException(), isNull);
        await fermerApplication(tester);
      });
    }
  }
}
