// Bout en bout de la vague 1 des nouveaux menus : l'application ENTIÈRE (main.dart) parle en HTTP réel au faux
// serveur Prestige local, dans la nouvelle interface.
//  - administrateur / pharmacien (xtypeuser « dashboard ») : chaque nouveau menu s'ouvre depuis l'accueil A, se
//    filtre, et l'on revient ; les mêmes menus s'ouvrent et se referment dans les présentations B, C et sur
//    tablette ; les alertes ne sont comptées qu'à la demande et partagées avec l'accueil ;
//  - refus du serveur → « Droit manquant » sans déconnexion ; session expirée → connexion ;
//  - autre profil (xtypeuser « mainmenumanager ») : les nouveaux menus sont absents partout.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/screens/login_screen.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

/// Menus de la vague 1 (titre du menu, titre de la barre de l'écran).
const menusVague1 = <(String, String)>[
  ('Valorisation', 'Valorisation du Stock'),
  ('Alertes', 'Alertes'),
  ('Retraits et abandons', 'Retraits et abandons'),
  ('Ventes modifiées', 'Ventes modifiées'),
];

const nouveauxMenus = ['Alertes', 'Retraits et abandons', 'Ventes modifiées'];

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

void tablette(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.5;
  tester.view.physicalSize = const Size(1920, 1200);
  addTearDown(tester.view.reset);
}

Future<void> retourSysteme(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await stabiliser(tester, tours: 4);
}

/// Fait défiler jusqu'à rendre [cible] touchable.
Future<void> amenerEnVue(WidgetTester tester, Finder cible, Finder defilement) async {
  final scrollable = find.descendant(of: defilement, matching: find.byType(Scrollable)).first;
  if (cible.evaluate().isEmpty) {
    // Cible non construite : retour en haut de la liste, puis descente jusqu'à elle.
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, 3000));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.scrollUntilVisible(cible, 250, scrollable: scrollable, maxScrolls: 80);
  }
  if (cible.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(cible.first);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> toucher(WidgetTester tester, Finder cible, {Finder? defilement}) async {
  if (defilement != null) await amenerEnVue(tester, cible, defilement);
  await tester.tap(cible.hitTestable().first);
  await stabiliser(tester, tours: 6);
}

/// Ouvre le menu [titre] depuis l'accueil A (tuile).
Future<void> ouvrirDepuisA(WidgetTester tester, String titre) =>
    toucher(tester, find.descendant(of: find.byType(AccueilNouveau), matching: find.text(titre)), defilement: find.byKey(const Key('defilement_accueil')));

Future<void> revenirALAccueil(WidgetTester tester) async {
  for (var i = 0; i < 4 && find.byType(AccueilNouveau).hitTestable().evaluate().isEmpty; i++) {
    await retourSysteme(tester);
  }
  expect(find.byType(AccueilNouveau).hitTestable(), findsOneWidget, reason: 'retour à l\'accueil');
}

/// Saisie dans la recherche (anti-rebond) puis attente de la requête.
Future<void> rechercher(WidgetTester tester, String texte) async {
  await tester.enterText(find.byKey(const Key('recherche_vague1')), texte);
  await tester.pump(const Duration(milliseconds: 500));
  await stabiliser(tester, tours: 8);
}

/// Attend le nombre de lignes annoncé en tête de journal (« 5 lignes · le 14/10/2026 »).
Future<void> attendreTotal(WidgetTester tester, int n) => attendreQue(tester, () {
      final t = find.byKey(const Key('journal_total'));
      if (t.evaluate().isEmpty) return false;
      return tester.widget<Text>(t).data!.startsWith('$n ${n > 1 ? 'lignes' : 'ligne'} · ');
    }, raison: '$n ligne(s) annoncée(s)');

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerNouvelle(serveur, p: Presentation.tableauDeBord);
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
    ProfilAcces.utilisateur.value = null;
  });

  testWidgets('Valorisation : aujourd\'hui chargé à l\'ouverture, onglets Rayon / Réserve / Total, regroupement Famille, retour',
      (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    expect(ProfilAcces.responsable, isTrue, reason: 'profil « dashboard » reçu à la connexion');
    await ouvrirDepuisA(tester, 'Valorisation');
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Valorisation du Stock'));
    await attendreTexte(tester, formaterMontant(DonneesVague1.rayonAchat));
    final r = serveur.recues(ApiValorisation.routeTableauDeBord).single;
    expect(r.parametres, {'frais': '0'});
    expect(r.sessionEnvoyee, serveur.derniereSession);

    await tester.tap(find.text('Réserve'));
    await stabiliser(tester);
    expect(find.text(formaterMontant(DonneesVague1.reserveAchat)), findsOneWidget);
    await tester.tap(find.text('Total'));
    await stabiliser(tester);
    expect(find.text(formaterMontant(DonneesVague1.rayonAchat + DonneesVague1.reserveAchat)), findsOneWidget);
    expect(find.text(formaterMontant(DonneesVague1.rayonVente + DonneesVague1.reserveVente - DonneesVague1.rayonAchat - DonneesVague1.reserveAchat)),
        findsOneWidget, reason: 'écart du total');

    // ⟳ : relire la base (frais=1).
    await tester.tap(find.byKey(const Key('valorisation_actualiser')));
    await attendreQue(tester, () => serveur.recues(ApiValorisation.routeTableauDeBord).length == 2, raison: 'frais=1');
    expect(serveur.recues(ApiValorisation.routeTableauDeBord).last.parametres, {'frais': '1'});

    // Regroupement Famille : liste chargée à la demande, cases à cocher, « Calculer » → /produit/valorisation.
    await toucher(tester, find.byKey(const Key('mode_Famille')));
    await attendreWidget(tester, find.byKey(const Key('valorisation_choix')));
    expect(serveur.recues('/common/famillearticles'), hasLength(1));
    expect(find.byKey(const Key('valorisation_perimee')), findsOneWidget, reason: 'montants affichés ≠ choix courants');
    await toucher(tester, find.byKey(const Key('valorisation_choix')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('ANTALGIQUES FICTIFS'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('choix_valider')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 famille choisie'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('valorisation_calculer')), defilement: find.byKey(const Key('defilement_valorisation')));
    await attendreQue(tester, () => serveur.recues(ApiValorisation.routeProduit).isNotEmpty, raison: 'calcul par famille');
    expect(serveur.recues(ApiValorisation.routeProduit).single.parametres['lgFAMILLEARTICLEID'], 'FAM-TEST-1');
    expect(serveur.recues(ApiValorisation.routeProduit).single.parametres['mode'], '1');
    await attendreWidget(tester, find.byKey(const Key('valorisation_source')));
    expect(find.byKey(const Key('valorisation_perimee')), findsNothing);
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('Alertes : aucun appel avant ⟳ ; un comptage partagé avec l\'accueil ; liste filtrée ; retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await stabiliser(tester, tours: 20);
    expect(find.byKey(const Key('alerte_toutes')), findsOneWidget);
    expect(serveur.recues(ApiAlertes.routeComptage), isEmpty, reason: 'aucun comptage automatique sur l\'accueil');

    await toucher(tester, find.byKey(const Key('alerte_toutes')), defilement: find.byKey(const Key('defilement_accueil')));
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Alertes'));
    await tester.pump(const Duration(minutes: 2));
    await stabiliser(tester);
    expect(find.byKey(const Key('alertes_invite')), findsOneWidget);
    expect(serveur.recues(ApiAlertes.routeComptage), isEmpty, reason: 'aucun comptage à l\'ouverture de l\'écran');

    await tester.tap(find.byKey(const Key('alertes_compter')));
    await attendreWidget(tester, find.byKey(const Key('carte_alerte_ruptures')));
    expect(serveur.recues(ApiAlertes.routeComptage), hasLength(1));
    expect(serveur.recues(ApiAlertes.routeComptage).single.parametres, ReglagesAlertes.parametresComptage);
    expect(find.text('12 produits'), findsOneWidget);

    // Alerte listable → liste ; filtre local avec anti-rebond.
    await toucher(tester, find.byKey(const Key('carte_alerte_ruptures')), defilement: find.byKey(const Key('defilement_alertes')));
    await attendreWidget(tester, find.byKey(const Key('liste_alerte_total')));
    expect(find.text('${DonneesVague1.ruptures} lignes'), findsOneWidget);
    expect(serveur.recues(ApiAlertes.routeListe).single.parametres['type'], 'ruptures');
    await rechercher(tester, 'fictif 1');
    expect(find.textContaining('PRODUIT EN RUPTURE FICTIF 1'), findsWidgets);
    expect(find.text('PRODUIT EN RUPTURE FICTIF 2'), findsNothing);
    expect(serveur.recues(ApiAlertes.routeListe), hasLength(1), reason: 'filtre local, pas de nouvel appel');
    await retourSysteme(tester);

    // Alerte non listable avec module mobile : Suggestions de commande.
    await toucher(tester, find.byKey(const Key('carte_alerte_suggestionsCommande')), defilement: find.byKey(const Key('defilement_alertes')));
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Suggestions de Commande'));
    await retourSysteme(tester);
    // Nombre seul (aucune liste ni module) : la carte n'est pas touchable.
    expect(tester.widget<CarteBande>(find.byKey(const Key('carte_alerte_renouvellements'))).onTap, isNull);

    await revenirALAccueil(tester);
    // L'accueil A affiche le même comptage sans nouvel appel : péremption et résumé.
    await amenerEnVue(tester, find.byKey(const Key('alerte_peremption_nombre')), find.byKey(const Key('defilement_accueil')));
    expect(tester.widget<Text>(find.byKey(const Key('alerte_peremption_nombre'))).textSpan!.toPlainText(), startsWith('3 lots · '));
    expect(tester.widget<Text>(find.byKey(const Key('alerte_toutes_resume'))).data, startsWith('8 alertes à surveiller · '));
    expect(serveur.recues(ApiAlertes.routeComptage), hasLength(1));
    await terminer(tester);
  });

  testWidgets('Retraits et abandons : jour par défaut, filtres type / utilisateur / recherche, retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Retraits et abandons');
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Retraits et abandons'));
    await attendreTotal(tester, 5);
    final premiere = serveur.recues(ApiJournaux.routeSuppressions).single.parametres;
    final aujourdhui = DateTime.now().toIso8601String().substring(0, 10);
    expect(premiere['dtStart'], aujourdhui, reason: 'période courte par défaut : aujourd\'hui');
    expect(premiere['dtEnd'], aujourdhui);
    expect(premiere['type'], '');
    expect(serveur.recues('/common/users'), hasLength(1));

    await toucher(tester, find.byKey(const Key('type_Vente abandonnée')));
    await attendreTotal(tester, 3);
    expect(serveur.recues(ApiJournaux.routeSuppressions).last.parametres['type'], 'VENTE');

    await tester.tap(find.byKey(const Key('filtre_utilisateur')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(DonneesVague1.utilisateur2).last);
    await stabiliser(tester, tours: 8);
    await attendreTotal(tester, 2);
    expect(serveur.recues(ApiJournaux.routeSuppressions).last.parametres['userId'], DonneesVague1.utilisateur2Id);

    await rechercher(tester, 'POMMADE');
    await attendreTotal(tester, 1);
    expect(serveur.recues(ApiJournaux.routeSuppressions).last.parametres['query'], 'POMMADE');
    expect(find.text('POMMADE FICTIVE 30G'), findsOneWidget);

    await rechercher(tester, 'introuvable');
    await attendreWidget(tester, find.byKey(const Key('etat_vide')));
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('Ventes modifiées : liste, détail des lignes avant / après, filtre Date, retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Ventes modifiées');
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Ventes modifiées'));
    await attendreTotal(tester, 3);
    await toucher(tester, find.byKey(const Key('vente_modifiee_MOD-TEST-1')), defilement: find.byKey(const Key('defilement_journal')));
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Vente modifiée'));
    expect(find.text('Produit retiré'), findsOneWidget);
    expect(find.text('Quantité modifiée'), findsOneWidget);
    expect(find.text('1 → 0'), findsOneWidget, reason: 'quantité avant → après');
    await retourSysteme(tester);
    await toucher(tester, find.byKey(const Key('type_Date')), defilement: find.byKey(const Key('defilement_journal')));
    await attendreTotal(tester, 1);
    expect(serveur.recues(ApiJournaux.routeModifiees).last.parametres['type'], 'DATE');
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('refus du serveur : « Droit manquant » affiché, pas de déconnexion ; session expirée → connexion', (tester) async {
    telephone(tester);
    serveur.quand(ApiJournaux.routeSuppressions, ReponseFausse.json({'success': false, 'msg': 'Accès refusé.'}));
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Retraits et abandons');
    await attendreWidget(tester, find.byKey(const Key('erreur_titre')));
    expect(find.text('Droit manquant'), findsOneWidget);
    expect(find.textContaining('Droit manquant : consulter les retraits et abandons.'), findsOneWidget);
    expect(find.byKey(const Key('bouton_reessayer')), findsNothing, reason: 'réessayer ne changerait rien');
    expect(find.byType(LoginScreen), findsNothing);
    await revenirALAccueil(tester);

    await ouvrirDepuisA(tester, 'Ventes modifiées');
    await attendreTotal(tester, 3);
    serveur.expirerSessions();
    await tester.tap(find.byKey(const Key('journal_actualiser')));
    await attendreWidget(tester, find.byType(LoginScreen));
    await terminer(tester);
  });

  for (final (lettre, p) in [('B', Presentation.compact), ('C', Presentation.guide)]) {
    testWidgets('présentation $lettre (téléphone) : chaque menu de la vague 1 s\'ouvre et se referme', (tester) async {
      telephone(tester);
      preparerNouvelle(serveur, p: p);
      await jusquAccueilNouveau(tester);
      final problemes = <String>[];
      for (final (titre, barre) in menusVague1) {
        final erreurs = await releverErreurs(() async {
          if (p == Presentation.guide) {
            final q = menusModules.firstWhere((m) => m.titre == titre).question;
            await toucher(tester, find.descendant(of: find.byType(AccueilNouveau), matching: find.text(q.titre)),
                defilement: find.byKey(const Key('defilement_accueil')));
            await toucher(tester, find.descendant(of: find.byType(QuestionScreen), matching: find.text(titre)),
                defilement: find.byKey(const Key('defilement_question')));
          } else {
            await toucher(tester, find.descendant(of: find.byType(AccueilNouveau), matching: find.text(titre)),
                defilement: find.byKey(const Key('defilement_menus')));
          }
          await stabiliser(tester, tours: 20);
        });
        problemes.addAll(erreurs.map((e) => '$titre : $e'));
        if (find.widgetWithText(AppBar, barre).evaluate().isEmpty) problemes.add('$titre : barre « $barre » absente');
        if (find.byKey(const Key('erreur_titre')).evaluate().isNotEmpty) problemes.add('$titre : erreur affichée');
        await revenirALAccueil(tester);
      }
      expect(problemes, isEmpty, reason: problemes.join('\n'));
      await terminer(tester);
    });
  }

  testWidgets('tablette (B, menu latéral) : chaque menu de la vague 1 s\'ouvre (tableaux) et se referme', (tester) async {
    tablette(tester);
    preparerNouvelle(serveur);
    await jusquAccueilNouveau(tester);
    for (final (titre, barre) in menusVague1) {
      final erreurs = await releverErreurs(() async {
        await toucher(tester, find.descendant(of: find.byType(AccueilNouveau), matching: find.text(titre)),
            defilement: find.byKey(const Key('defilement_menus')));
        await stabiliser(tester, tours: 20);
      });
      expect(erreurs, isEmpty, reason: '$titre : ${erreurs.join('\n')}');
      expect(find.widgetWithText(AppBar, barre), findsOneWidget);
      if (titre == 'Retraits et abandons') {
        await attendreTexte(tester, 'Vente ouverte par'); // en-tête du tableau
      }
      await revenirALAccueil(tester);
    }
    await terminer(tester);
  });

  testWidgets('autre profil (mainmenumanager) : nouveaux menus absents dans A, B et C ; Valorisation conservée', (tester) async {
    telephone(tester);
    serveur.controlerSession = false;
    serveur.quand(
        '/user/auth',
        ReponseFausse.json({...DonneesFictives.utilisateur(), 'xtypeuser': 'mainmenumanager'},
            entetes: {'set-cookie': 'JSESSIONID=fictif-autre; Path=/prestige; HttpOnly'}),
        methode: 'POST');
    await jusquAccueilNouveau(tester);
    expect(ProfilAcces.responsable, isFalse);
    final defilement = find.byKey(const Key('defilement_accueil'));
    await amenerEnVue(tester, find.descendant(of: find.byType(AccueilNouveau), matching: find.text('Valorisation')), defilement);
    expect(find.descendant(of: find.byType(AccueilNouveau), matching: find.text('Valorisation')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Présences').last, 300, scrollable: find.descendant(of: defilement, matching: find.byType(Scrollable)).first);
    for (final t in nouveauxMenus) {
      expect(find.descendant(of: find.byType(AccueilNouveau), matching: find.text(t)), findsNothing, reason: 'A : $t');
    }
    expect(find.byKey(const Key('alerte_toutes')), findsNothing);
    expect(find.byKey(const Key('alerte_peremption')), findsOneWidget, reason: 'alertes existantes de l\'accueil conservées');

    // B : liste complète et recherche.
    await PresentationPrefs.enregistrer(Presentation.compact);
    await stabiliser(tester);
    for (final t in nouveauxMenus) {
      await tester.enterText(find.byKey(const Key('recherche_menu')), t);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.widgetWithText(LigneMenu, t), findsNothing, reason: 'B : $t');
    }
    await tester.enterText(find.byKey(const Key('recherche_menu')), '');
    await tester.pump(const Duration(milliseconds: 300));

    // C : « Voir tous les menus ».
    await PresentationPrefs.enregistrer(Presentation.guide);
    await stabiliser(tester);
    Navigator.of(tester.element(find.byType(AccueilNouveau))).push(MaterialPageRoute(builder: (_) => const TousLesMenusScreen()));
    await stabiliser(tester);
    final tous = find.byType(TousLesMenusScreen);
    await tester.scrollUntilVisible(find.descendant(of: tous, matching: find.text('Présences')), 300,
        scrollable: find.descendant(of: tous, matching: find.byType(Scrollable)).first);
    for (final t in nouveauxMenus) {
      expect(find.descendant(of: tous, matching: find.text(t)), findsNothing, reason: 'C : $t');
    }
    await retourSysteme(tester);
    await terminer(tester);
  });
}
