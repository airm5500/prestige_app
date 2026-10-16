// Bout en bout de la 3.11.2 : l'application ENTIÈRE parle en HTTP réel au faux serveur Prestige local.
// Détail CA, « Jour par jour » : sous le Total de chaque jour, son évolution par rapport au jour précédent de la liste
// (flèche, signe, couleur) ; rien pour le premier jour ; aucune requête de plus (calcul sur les lignes déjà lues).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';
import 'parcours_3_11_0_test.dart' show ouvrirMenu, telephone;

final serveur = FauxServeurPrestige();

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
    donneesLot1(serveur);
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
    ProfilAcces.utilisateur.value = null;
    ReglagesAlertes.oublier();
  });

  testWidgets('Détail CA : % d\'évolution du Total sous chaque jour (sauf le premier), sans requête de plus', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact);
    await jusquAccueilNouveau(tester);
    await ouvrirMenu(tester, 'Détail CA');
    final liste = find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first;
    await attendreQue(tester, () => serveur.recues(AppConstants.caComptantEndpoint).isNotEmpty, raison: 'Détail CA lu');
    await tester.scrollUntilVisible(find.byKey(const Key('jour_evolution_2')), 300, scrollable: liste, maxScrolls: 40);
    await stabiliser(tester, tours: 4);
    final lectures = serveur.recues(AppConstants.caComptantEndpoint).length;
    expect(find.descendant(of: find.byKey(const Key('jour_evolution_0')), matching: find.byType(Text)), findsNothing, reason: 'premier jour');
    expect(find.descendant(of: find.byKey(const Key('jour_evolution_1')), matching: find.text('+18,0 %')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('jour_evolution_2')), matching: find.text('−18,3 %')), findsOneWidget);
    expect(serveur.recues(AppConstants.caComptantEndpoint).length, lectures);
    await terminer(tester);
  });
}
