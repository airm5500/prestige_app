// ERGONOMIE — retours de la 3.11.1, mesures précises (les écrans entiers sont aussi passés aux 5 tailles × 2 échelles
// par affichage_nouvelle_interface_test.dart, cas de support/cas_retours_3_11_1.dart) :
//  - CA par emplacement, jour par jour : le % d'évolution n'agrandit PAS la ligne (même hauteur qu'une ligne sans
//    évolution), téléphone et Sunmi, texte ×1 et ×1,3 ; hausse en vert, baisse en rouge, toujours avec la flèche et le
//    signe ;
//  - fréquentation horaire : écart avec la veille en vert / rouge / gris, avec flèche et signe ; part du CA écrite ;
//    aucun débordement en 1 h ou en 2 h.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/vague2/ca_zone_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';

import '../support/faux_serveur_prestige.dart';
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
  setUp(() => brancherEnMemoire(serveur));

  for (final (nom, dp, dpr) in appareils) {
    for (final echelle in [1.0, 1.3]) {
      testWidgets('CA par emplacement jour par jour ($nom, texte ×$echelle) : le % ne change pas la hauteur des lignes', (tester) async {
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = Size(dp.width * dpr, dp.height * dpr);
        tester.platformDispatcher.textScaleFactorTestValue = echelle;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await ouvrirEcran(tester, serveur,
            CaZoneScreen(filtresInitiaux: FiltresCa(type: TypePeriodeCa.libre, debut: DateTime(2026, 10, 8), fin: DateTime(2026, 10, 14))),
            pret: find.byKey(const Key('ca_totaux_tranches')));
        Finder ligne(String jour) => find.descendant(of: find.byKey(const Key('ca_totaux_tranches')), matching: find.byKey(Key('tranche_2026-10-$jour')));
        final sans = tester.getSize(ligne('08')).height; // premier jour : pas d'évolution
        final hausse = tester.getSize(ligne('09')).height; // +20 %
        final baisse = tester.getSize(ligne('10')).height; // −25 %
        final apresFermeture = tester.getSize(ligne('12')).height; // lendemain du dimanche fermé : pas d'évolution
        expect([hausse, baisse, apresFermeture], everyElement(moreOrLessEquals(sans, epsilon: 0.01)), reason: 'hauteur d\'une ligne sans évolution : $sans');
        // Couleur ET flèche ET signe.
        Text texte(String jour, String t) => tester.widget<Text>(find.descendant(of: ligne(jour), matching: find.text(t)));
        expect(texte('09', '+20,0 %').style!.color, Charte.vertTexte);
        expect(texte('10', '−25,0 %').style!.color, Charte.rougeTexte);
        expect(find.descendant(of: ligne('09'), matching: find.byIcon(Icons.arrow_upward)), findsOneWidget);
        expect(find.descendant(of: ligne('10'), matching: find.byIcon(Icons.arrow_downward)), findsOneWidget);
        expect(find.byKey(const Key('ca_legende_evolution')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await fermerApplication(tester);
      });
    }
  }

  testWidgets('fréquentation : écart avec la veille en vert (hausse), rouge (baisse), gris (égal), avec flèche et signe', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(720, 1440);
    addTearDown(tester.view.reset);
    const f = FrequentationJour(
      ventes: [0, 0, 0, 0, 0, 0, 0, 0, 10, 4, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      ca: [0, 0, 0, 0, 0, 0, 0, 0, 100, 40, 60, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      reference: [0, 0, 0, 0, 0, 0, 0, 0, 7, 9, 6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
      libelle: 'comparé à la veille',
      semaine: false,
    );
    final t = f.tranches();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ListView(children: [for (final x in t) LigneHoraire(key: Key('h${x.debut}'), tranche: x, max: 10)])),
    ));
    Color couleur(int h) => tester
        .widget<Text>(find.descendant(of: find.byKey(Key('frequentation_ecart_$h')), matching: find.byWidgetPredicate((w) => w is Text && w.data!.endsWith(')'))))
        .style!
        .color!;
    expect(find.descendant(of: find.byKey(const Key('frequentation_ecart_8')), matching: find.text('+3)')), findsOneWidget);
    expect(couleur(8), Charte.vertTexte);
    expect(find.descendant(of: find.byKey(const Key('frequentation_ecart_8')), matching: find.byIcon(Icons.arrow_upward)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('frequentation_ecart_9')), matching: find.text('−5)')), findsOneWidget);
    expect(couleur(9), Charte.rougeTexte);
    expect(find.descendant(of: find.byKey(const Key('frequentation_ecart_9')), matching: find.byIcon(Icons.arrow_downward)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('frequentation_ecart_10')), matching: find.text('0)')), findsOneWidget);
    expect(couleur(10), Charte.grisTexte);
    expect(find.text('50,0 % du CA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
