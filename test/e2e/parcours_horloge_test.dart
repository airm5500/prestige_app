// Parcours de bout en bout (3.18.1), application ENTIÈRE contre le faux serveur local (vrai réseau HTTP, données
// fictives) : HEURE DU SERVEUR FAUSSE (serveur du 24/11 : toute écriture refusée en HTTP 423, lectures permises).
//  - écran de connexion (deux interfaces) : `GET horloge/public` BLOQUE → bandeau d'information, la connexion reste
//    possible ; ancien serveur (route absente), OK, REGULARISATION → rien ; une seule lecture, aucune relance ;
//  - nouvelle interface, Pointage BL : pointer refusé → « Non enregistré : <message du serveur> », la pièce revient,
//    une seule requête (aucune relance), toujours connecté, aucun « serveur injoignable » ;
//  - interface d'origine, suggestion : quantité refusée → « Quantité non enregistrée sur le serveur : <message> »
//    (jamais « erreur inconnue »).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/horloge_serveur.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/suggestion_detail_screen.dart';
import 'package:prestige_app/utils/constants.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot2.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';
import 'parcours_vague2_test.dart' show telephone, toucher, ouvrirDepuisA;

final serveur = FauxServeurPrestige();

const msg = 'Opération refusée : l\'heure du serveur est fausse. Faites « Mettre à jour » ou appelez '
    'l\'administrateur pour remettre l\'heure dans Windows.';

ReponseFausse refus423() => ReponseFausse.json({'success': false, 'horlogeBloquee': true, 'msg': msg}, statut: 423);

Finder cle(String k) => find.byKey(Key(k));
final bandeau = cle('bandeau_horloge_serveur');

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur
      ..oublierRequetes()
      // Comme le vrai serveur : route de l'horloge publique (sans session).
      ..routesPubliques.add(HorlogeServeur.route);
    utiliserReseauReel();
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
    serveur.routesPubliques.remove(HorlogeServeur.route);
    ProfilAcces.utilisateur.value = null;
    ReglagesAlertes.oublier();
  });

  for (final nouvelle in [true, false]) {
    final nom = nouvelle ? 'nouvelle interface' : 'interface d\'origine';

    testWidgets('$nom — connexion : horloge BLOQUE → bandeau, une lecture, la connexion reste possible', (tester) async {
      telephone(tester);
      nouvelle ? preparerNouvelle(serveur, p: Presentation.compact) : preparerTelephone(serveur);
      serveur.quand(HorlogeServeur.route, ReponseFausse.json({'etat': 'BLOQUE', 'serveur': '24/11/2026 20:52'}), methode: 'GET');
      await lancerApplication(tester);
      await attendreWidget(tester, find.byType(LoginScreen));
      await attendreWidget(tester, bandeau);
      expect(find.textContaining('L\'heure du serveur est fausse (heure du serveur : 24/11/2026 20:52)'), findsOneWidget);
      await stabiliser(tester, tours: 20);
      expect(serveur.recues(HorlogeServeur.route), hasLength(1), reason: 'une seule lecture, aucune relance');
      await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
      await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
      final bouton = cle('connexion_se_connecter');
      await tester.tap(bouton.evaluate().isNotEmpty ? bouton : find.widgetWithText(ElevatedButton, 'Connexion'));
      await attendreQue(tester, () => find.byType(LoginScreen).evaluate().isEmpty, raison: 'connecté');
      expect(serveur.recues(AppConstants.authEndpoint, methode: 'POST'), hasLength(1));
      await terminer(tester);
    });

    testWidgets('$nom — connexion : ancien serveur (route absente), OK, REGULARISATION → aucun bandeau', (tester) async {
      telephone(tester);
      nouvelle ? preparerNouvelle(serveur, p: Presentation.compact) : preparerTelephone(serveur);
      for (final reponse in [
        ReponseFausse.introuvable(),
        ReponseFausse.json({'etat': 'OK', 'serveur': '24/11/2026 20:52'}),
        ReponseFausse.json({'etat': 'REGULARISATION', 'serveur': '24/11/2026 20:52'}),
      ]) {
        serveur.quand(HorlogeServeur.route, reponse, methode: 'GET');
        await lancerApplication(tester);
        await attendreWidget(tester, find.byType(LoginScreen));
        await stabiliser(tester, tours: 20);
        expect(bandeau, findsNothing);
        expect(find.textContaining('heure du serveur'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await stabiliser(tester);
      }
      await terminer(tester);
    });
  }

  testWidgets('nouvelle interface — Pointage BL refusé (423) : « Non enregistré : <message> », la pièce revient, une requête', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.tableauDeBord);
    serveur.quand('/pointage-bl/pointer/BL/BL-TEST-3', refus423(), methode: 'PUT');
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Pointage BL');
    await toucher(tester, cle('pointage_grossiste'), defilement: cle('defilement_pointage'));
    await toucher(tester, find.text('GROSSISTE FICTIF').last);
    await attendreWidget(tester, cle('pointage_total'));
    await toucher(tester, cle('pointer_BL:BL-TEST-3'), defilement: cle('defilement_pointage'));
    await attendreWidget(tester, find.text('Non enregistré : $msg'));
    await stabiliser(tester, tours: 20);
    expect(find.descendant(of: cle('pointer_BL:BL-TEST-3'), matching: find.text('Pointer')), findsOneWidget, reason: 'la pièce revient');
    expect(serveur.recues('/pointage-bl/pointer/BL/BL-TEST-3'), hasLength(1), reason: 'aucune relance');
    expect(find.textContaining('injoignable'), findsNothing);
    expect(find.byType(LoginScreen), findsNothing, reason: 'toujours connecté');
    expect(find.byType(AccueilNouveau), findsNothing);
    await terminer(tester);
  });

  testWidgets('interface d\'origine — suggestion : quantité refusée (423) → « Quantité non enregistrée sur le serveur : <message> »',
      (tester) async {
    telephone(tester);
    preparerTelephone(serveur);
    donneesLot2(serveur);
    serveur
      ..controlerSession = false
      ..quand(AppConstants.suggestionUpdateQteEndpoint, refus423(), methode: 'POST');
    final s = Suggestion.fromJson(Map<String, dynamic>.from((DonneesLot2.suggestions()['data'] as List).first as Map));
    await monterAvecProviders(tester, ecran: SuggestionDetailScreen(suggestion: s));
    await attendreWidget(tester, find.text(DonneesFictives.libelleArticle1));
    final champ = find.byType(TextFormField).first;
    await tester.enterText(champ, '7');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await attendreWidget(tester, find.text('Quantité non enregistrée sur le serveur : $msg'));
    expect(find.textContaining('erreur inconnue'), findsNothing);
    expect(serveur.recues(AppConstants.suggestionUpdateQteEndpoint, methode: 'POST'), hasLength(1));
    await terminer(tester);
  });
}
