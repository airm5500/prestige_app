// 3.15.1 — réponse du serveur à la demande 55 (a30b33d9) : GET /reception/peremptions-courtes renvoie
// « peutChangerStatut » (vrai si la session a P_BL_MOBILE_ACCEPTER_PEREMPTION_COURTE). Écran « Péremptions courtes »
// contre le faux serveur (client en mémoire) :
//  - false : statut en lecture seule dès l'ouverture (aucune feuille de choix, aucun PUT) ;
//  - true : changement proposé, un PUT ;
//  - absent (serveur plus ancien) : comme la 3.15.0 (proposé ; 403 → « Droit manquant », puis plus proposé) ;
//  - 403 malgré true (droit retiré entre la liste et le changement) : test de la 3.15.0 (retours_3_15_0_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/vague4/peremptions_courtes_vague4.dart';

import '../support/donnees_vague1.dart';
import '../support/donnees_vague4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';
import 'retours_3_10_0_test.dart' show demonter, monter, pomper, serveur;

final maintenant = DateTime(2026, 10, 25, 11, 0);

Finder cle(String k) => find.byKey(Key(k));

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
    listesCommunesVague1(serveur);
  });

  Future<void> ecran(WidgetTester tester) async {
    await monter(tester, () => PeremptionsCourtesScreen(maintenant: () => maintenant));
    await pomper(tester);
  }

  int puts() => serveur.requetes.where((r) => r.methode == 'PUT').length;

  testWidgets('peutChangerStatut=false : statut en lecture seule dès l\'ouverture, aucune feuille, aucun PUT', (tester) async {
    DonneesVague4.peutChangerStatutPc = false;
    await ecran(tester);
    expect(cle('pc_statut_lecture_seule'), findsOneWidget);
    expect(find.descendant(of: cle('pc_ligne_0'), matching: find.text('À traiter')), findsOneWidget, reason: 'statut toujours affiché');
    expect(find.descendant(of: cle('pc_statut_ligne_0'), matching: find.byIcon(Icons.arrow_drop_down)), findsNothing);
    await tester.tap(cle('pc_statut_ligne_0'));
    await pomper(tester);
    expect(cle('pc_choix_RECLAME'), findsNothing);
    expect(puts(), 0);
    expect(cle('pc_droit_refuse'), findsNothing, reason: 'pas un refus : le droit est connu d\'emblée');
    await demonter(tester);
  });

  testWidgets('peutChangerStatut=true : changement proposé, un PUT, ligne mise à jour', (tester) async {
    await ecran(tester);
    expect(cle('pc_statut_lecture_seule'), findsNothing);
    await tester.tap(cle('pc_statut_ligne_0'));
    await pomper(tester);
    await tester.tap(cle('pc_choix_AVOIR_RECU'));
    await pomper(tester);
    expect(serveur.recues('/reception/peremptions-courtes/PC-1/statut').single.parametres, {'statut': 'AVOIR_RECU'});
    expect(find.descendant(of: cle('pc_ligne_0'), matching: find.text('Avoir reçu')), findsOneWidget);
    await demonter(tester);
  });

  testWidgets('champ absent (serveur plus ancien) : proposé ; 403 → « Droit manquant », puis plus proposé', (tester) async {
    DonneesVague4.peutChangerStatutPc = null;
    DonneesVague4.statutPcInterdit = true;
    await ecran(tester);
    expect(cle('pc_statut_lecture_seule'), findsNothing);
    await tester.tap(cle('pc_statut_ligne_0'));
    await pomper(tester);
    await tester.tap(cle('pc_choix_RECLAME'));
    await pomper(tester);
    expect(puts(), 1);
    expect(cle('pc_droit_refuse'), findsOneWidget);
    expect(find.descendant(of: cle('pc_ligne_0'), matching: find.text('À traiter')), findsOneWidget);
    await tester.tap(cle('pc_statut_ligne_1'));
    await pomper(tester);
    expect(cle('pc_choix_A_TRAITER'), findsNothing);
    expect(puts(), 1);
    await demonter(tester);
  });

  testWidgets('false puis true après « Actualiser » (droit donné entre-temps) : changement de nouveau proposé', (tester) async {
    DonneesVague4.peutChangerStatutPc = false;
    await ecran(tester);
    expect(cle('pc_statut_lecture_seule'), findsOneWidget);
    DonneesVague4.peutChangerStatutPc = true;
    await tester.tap(cle('pc_actualiser'));
    await pomper(tester);
    expect(cle('pc_statut_lecture_seule'), findsNothing);
    await tester.tap(cle('pc_statut_ligne_0'));
    await pomper(tester);
    expect(cle('pc_choix_RECLAME'), findsOneWidget);
    await demonter(tester);
  });

  testWidgets('peutChangerStatut en texte (« false ») : lu de façon tolérante, lecture seule', (tester) async {
    serveur.route(ApiPeremptionsCourtes.route,
        (r) => ReponseFausse.json({...DonneesVague4.peremptionsCourtes(r.parametres), 'peutChangerStatut': 'false'}), methode: 'GET');
    await ecran(tester);
    expect(cle('pc_statut_lecture_seule'), findsOneWidget);
    await demonter(tester);
  });
}
