// Bout en bout des retours de la 3.11.1 : l'application ENTIÈRE (main.dart) parle en HTTP réel au faux serveur
// Prestige local.
//  - tableau de bord : chiffres d'hier (une requête tuiles?date=hier), retour à aujourd'hui ; fréquentation : part du
//    CA et écart avec la veille, « Par 2 h », plage « De 7 h à 22 h » — AUCUNE requête, choix mémorisé ;
//  - CA par emplacement : période libre courte = jour par jour, évolution par rapport au jour précédent ;
//  - Balance vente / caisse : camembert par mode de paiement puis par type de vente, barres de l'évolution par mode.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague4/balance_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/donnees_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/perimes_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';
import 'parcours_3_11_0_test.dart' show ouvrirMenu, retourSysteme, telephone, toucher;

final serveur = FauxServeurPrestige();

String jour(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
    ComptageSaisiesPerimes.oublier();
    CartesTableauBordPrefs.cartes.value = CartesTableauBordPrefs.defaut;
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

  testWidgets('tableau de bord : chiffres d\'hier puis d\'aujourd\'hui ; fréquentation par 2 h de 7 h à 22 h sans requête, mémorisée', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.tableauPrestige);
    await tester.runAsync(InterfaceVersion.load);
    await jusquAccueilNouveau(tester);
    await attendreWidget(tester, find.byKey(const Key('chiffre_tb_ca')));
    expect(serveur.recues('/tableau-bord/tuiles').single.parametres['date'], jour(DateTime.now()));

    // Chiffres d'hier : une requête de plus, avec la date d'hier ; l'évolution vs la veille reste affichée.
    await toucher(tester, find.byKey(const Key('chiffres_hier')));
    final hier = DateTime.now().subtract(const Duration(days: 1));
    await attendreQue(tester, () => serveur.recues('/tableau-bord/tuiles').length == 2, raison: 'chiffres d\'hier');
    expect(serveur.recues('/tableau-bord/tuiles').last.parametres['date'], jour(hier));
    await attendreWidget(tester, find.byKey(const Key('chiffre_tb_ca')));
    expect(find.byKey(const Key('tb_evolution_veille')), findsOneWidget);
    expect(find.text('Achats'), findsOneWidget, reason: '« Achats du jour » seulement pour aujourd\'hui');
    await toucher(tester, find.byKey(const Key('chiffres_aujourdhui')));
    await attendreQue(tester, () => serveur.recues('/tableau-bord/tuiles').length == 3, raison: 'retour à aujourd\'hui');

    // Fréquentation : part du CA et écart avec la veille, puis 2 h et 7 h – 22 h sans aucune requête.
    final defilement = find.descendant(of: find.byKey(const Key('defilement_tableau_bord')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('frequentation_largeur_2')), 300, scrollable: defilement, maxScrolls: 30);
    await attendreWidget(tester, find.byKey(const Key('frequentation_resume')));
    expect(find.byKey(const Key('frequentation_part_8')), findsOneWidget);
    expect(find.byKey(const Key('frequentation_ecart_8')), findsOneWidget);
    final avant = serveur.recues('/pilotage/suivi/frequentation').length;
    await toucher(tester, find.byKey(const Key('frequentation_largeur_2')));
    await toucher(tester, find.byKey(const Key('frequentation_plage')));
    await toucher(tester, find.byKey(const Key('frequentation_plage_septVingtDeux')).last);
    expect(find.byKey(const Key('frequentation_tranche_7')), findsOneWidget);
    expect(find.byKey(const Key('frequentation_tranche_8')), findsNothing, reason: 'tranches de 2 h : 07-09, 09-11…');
    expect(find.byKey(const Key('frequentation_tranche_21')), findsOneWidget);
    expect(serveur.recues('/pilotage/suivi/frequentation').length, avant, reason: 'changer l\'affichage ne relit rien');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AffichageFrequentationPrefs.cle), '2:septVingtDeux');
    await terminer(tester);
  });

  testWidgets('CA par emplacement : période libre d\'une semaine = jour par jour, % par rapport au jour précédent', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact);
    await jusquAccueilNouveau(tester);
    await ouvrirMenu(tester, 'CA emplacement / famille');
    await attendreWidget(tester, find.byKey(const Key('ca_totaux_tranches')));
    // Période libre (calendrier : période proposée, « Valider ») ; le faux serveur répond jour par jour.
    await toucher(tester, find.text('Période libre'));
    await toucher(tester, find.text('Valider'));
    await attendreQue(tester, () => serveur.recues('/ca-zone-geo').any((r) => r.parametres['typePeriode'] == 'LIBRE'), raison: 'période libre');
    await attendreWidget(tester, find.byKey(const Key('ca_legende_evolution')));
    expect(find.text('Flèche et % : évolution par rapport au jour précédent (vert : hausse, rouge : baisse).'), findsOneWidget);
    final totaux = find.byKey(const Key('ca_totaux_tranches'));
    expect(find.descendant(of: totaux, matching: find.text('+20,0 %')), findsOneWidget);
    expect(find.descendant(of: totaux, matching: find.text('−25,0 %')), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('Balance : camembert par mode puis par type de vente (aucune requête), barres de l\'évolution par mode', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact);
    await jusquAccueilNouveau(tester);
    await ouvrirMenu(tester, 'Balance vente / caisse');
    await attendreWidget(tester, find.byKey(const Key('chiffre_balance_net')));
    final liste = find.descendant(of: find.byKey(const Key('defilement_balance')), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const Key('repartition_modes_paiement')), 300, scrollable: liste, maxScrolls: 30);
    expect(find.byKey(const Key('repartition_modes_camembert')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('repartition_modes_legende_0')), matching: find.text('Espèces')), findsOneWidget);
    final requetes = serveur.recues(ApiBalance.route).length;
    await toucher(tester, find.byKey(const Key('repartition_type')));
    expect(find.byKey(const Key('repartition_type_vente')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('repartition_type_legende_0')), matching: find.text('COMPTANT')), findsOneWidget);
    expect(serveur.recues(ApiBalance.route).length, requetes);

    await toucher(tester, find.byKey(const Key('balance_onglet_modes')));
    await attendreWidget(tester, find.byKey(const Key('modes_graphique')));
    expect(find.byKey(const Key('modes_legende_0')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('modes_legende_0')), matching: find.text('66,7 %')), findsOneWidget);
    expect(find.byType(BalanceCaisseScreen), findsOneWidget);
    await retourSysteme(tester);
    await terminer(tester);
  });
}

