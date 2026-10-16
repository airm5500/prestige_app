// PERFORMANCE — NOMBRE DE REQUÊTES envoyées au faux serveur Prestige pour les parcours clés (application entière,
// faux serveur « en mémoire », temps simulé). Chaque parcours a un PLAFOND EXACT : une requête de trop (boucle,
// double chargement, recherche sans anti-rebond, alertes comptées sans appui…) fait échouer le test. Plafonds =
// fonctionnement voulu, sans marge, composition écrite à côté (voir test/README.md).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/catalogue_ecrans.dart';
import '../support/donnees_fictives.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

/// Laisse passer [secondes] secondes simulées (réponses, minuteries, animations).
Future<void> laisser(WidgetTester tester, {int secondes = 3}) async {
  for (var i = 0; i < secondes * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Lancement jusqu'à l'écran de connexion (licence lue).
Future<void> jusquConnexion(WidgetTester tester) async {
  await lancerApplication(tester);
  await pomper(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'écran de connexion', max: 100);
  await laisser(tester, secondes: 1);
}

/// Saisit les identifiants et se connecte ; attend [accueil] puis 3 s.
Future<void> seConnecter(WidgetTester tester, Finder accueil) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
  await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
  final bouton = find.byKey(const Key('connexion_se_connecter'));
  await tester.tap(bouton.evaluate().isNotEmpty ? bouton : find.widgetWithText(ElevatedButton, 'Connexion'));
  await pomper(tester, () => accueil.evaluate().isNotEmpty, raison: 'accueil', max: 100);
  await laisser(tester);
}

/// Ouvre un module par la recherche de menu de l'accueil B ; attend 3 s.
Future<void> ouvrirParRecherche(WidgetTester tester, ModuleLot1 m) async {
  await tester.enterText(find.byKey(const Key('recherche_menu')), m.tuile);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.text(m.tuile)).first);
  await pomper(tester, () => find.byType(m.typeNouveau).evaluate().isNotEmpty, raison: m.tuile);
  await laisser(tester);
}

Future<void> revenir(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await laisser(tester, secondes: 1);
  await tester.enterText(find.byKey(const Key('recherche_menu')), '');
  await tester.pump(const Duration(milliseconds: 300));
}

ModuleLot1 module(String tuile) => modulesLot1.firstWhere((m) => m.tuile == tuile);

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    brancherEnMemoire(serveur);
    donneesAccueil(serveur);
    donneesLot1(serveur);
    donneesAlertes(serveur);
  });

  // Connexion (1 : POST /user/auth) + nom de l'officine relu après connexion (1 : GET /officine), puis l'accueil :
  //  A : chiffres du jour (GET /recap/dashboard) et présence de l'équipe (GET /rh/presence) = 2 ; alertes : AUCUNE
  //  (comptées seulement sur ⟳) ; B et C : aucun chiffre chargé = 0 ; ancienne interface : 0.
  //  3.10.0 : menus en pages (rubrique, 6 tuiles) et icônes illustrées (P4, embarquées) : aucune requête de plus.
  for (final (String nom, Presentation p, int plafond, AffichageMenus affichage, StyleIcones? style) in [
    ('A · Tableau de bord', Presentation.tableauDeBord, 4, AffichageMenus.unePage, StyleIcones.actuel),
    ('B · Compact', Presentation.compact, 2, AffichageMenus.unePage, StyleIcones.actuel),
    ('C · Guidé', Presentation.guide, 2, AffichageMenus.unePage, StyleIcones.actuel),
    ('A · 6 tuiles par page, P4', Presentation.tableauDeBord, 4, AffichageMenus.parSix, StyleIcones.p4),
    ('B · une rubrique par page, P4', Presentation.compact, 2, AffichageMenus.parRubrique, StyleIcones.p4),
    ('A · défaut 3.10.1 (P4 jamais choisi)', Presentation.tableauDeBord, 4, AffichageMenus.unePage, null),
    // 3.11.0 : tableau de bord (défaut) : seules les cartes affichées (ou sur le point de l'être) chargent, une
    // requête chacune ; au plus les 7 cartes + connexion + officine.
    ('Tableau de bord (défaut 3.11.0)', Presentation.tableauPrestige, 9, AffichageMenus.unePage, null),
  ]) {
    testWidgets('connexion + accueil $nom : plafond $plafond requêtes', (tester) async {
      telephone(tester);
      preparerNouvelle(serveur, p: p, affichage: affichage, style: style);
      await jusquConnexion(tester);
      final rs = await compter(serveur, () => seConnecter(tester, find.byType(AccueilNouveau)));
      mesurer('Requêtes — connexion + accueil $nom', rs.length, seuil: plafond, unite: 'requêtes', detail: detailRequetes(rs));
      expect(rs.where((r) => r.chemin.startsWith('/tableau-bord/alertes')), isEmpty, reason: 'alertes jamais comptées sans ⟳');
      expect(serveur.recues(AppConstants.authEndpoint), hasLength(1), reason: 'une seule connexion');
      await fermerApplication(tester);
    });
  }

  // 3.10.2 : connexion pendant un redéploiement (404 de /user/auth) ou Prestige surchargé (503) : UNE requête,
  // message « Serveur indisponible », aucune relance automatique ni lecture de /officine ; temps jusqu'au message.
  for (final (cas, statut) in [('404 (redéploiement)', 404), ('503', 503)]) {
    testWidgets('connexion en $cas : plafond 1 requête, message affiché', (tester) async {
      telephone(tester);
      preparerNouvelle(serveur, p: Presentation.compact);
      await jusquConnexion(tester);
      serveur.quand(AppConstants.authEndpoint, statut == 404 ? ReponseFausse.introuvable() : ReponseFausse.erreurServeur(statut: statut),
          methode: 'POST');
      final sw = Stopwatch();
      final rs = await compter(serveur, () async {
        await tester.enterText(find.widgetWithText(TextFormField, 'Identifiant'), DonneesFictives.identifiant);
        await tester.enterText(find.widgetWithText(TextFormField, 'Mot de passe'), DonneesFictives.motDePasse);
        sw.start();
        await tester.tap(find.byKey(const Key('connexion_se_connecter')));
        await pomper(tester, () => find.text(ApiLoadException.messageServeurIndisponible).evaluate().isNotEmpty, raison: 'message');
        sw.stop();
        await laisser(tester, secondes: 10); // 10 s sans rien toucher : aucune relance
      });
      mesurer('Requêtes — connexion en $cas', rs.length, seuil: 1, unite: 'requêtes', detail: detailRequetes(rs));
      mesurer('Connexion en $cas → message « Serveur indisponible »', sw.elapsedMicroseconds / 1000, seuil: Seuils.accueilMs, unite: 'ms');
      await fermerApplication(tester);
    });
  }

  testWidgets('connexion + accueil d\'origine (ancienne interface) : plafond 2 requêtes', (tester) async {
    telephone(tester);
    preparerTelephone(serveur);
    await jusquConnexion(tester);
    final rs = await compter(serveur, () => seConnecter(tester, find.byType(HomeScreen)));
    mesurer('Requêtes — connexion + accueil d\'origine', rs.length, seuil: 2, unite: 'requêtes', detail: detailRequetes(rs));
    await fermerApplication(tester);
  });

  testWidgets('ouverture de chaque module du lot 1, puis changement de période : plafonds exacts', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact);
    await jusquConnexion(tester);
    await seConnecter(tester, find.byType(AccueilNouveau));
    // Ouverture : Rapport d'Activité = dashboard + crédits + totaux des crédits + règlements (4) ; Détail CA = /ca-all
    // (1, Mobile Money seulement au dépliage) ; Analyse Article = 0 (rien avant une recherche) ; Suivi Péremption =
    // une page (1) ; Suivi Crédit = /recap/credits (1). « Fiche Article » n'est plus dans la nouvelle interface.
    // 3.11.0 : « Suivi Crédit » est l'onglet Synthèse du menu « CA Crédit » (mesuré à la suite).
    const ouverture = {'Rapport d\'Activité': 4, 'Détail CA': 1, 'Analyse Article': 0, 'Suivi Péremption': 1};
    // Changement de période (« Hier ») : les mêmes routes, une fois chacune.
    const periode = {'Rapport d\'Activité': 4, 'Détail CA': 1};
    for (final e in ouverture.entries) {
      final m = module(e.key);
      final rs = await compter(serveur, () => ouvrirParRecherche(tester, m));
      mesurer('Requêtes — ouverture ${m.tuile}', rs.length, seuil: e.value, unite: 'requêtes', detail: detailRequetes(rs));
      expect(rs.length, e.value, reason: '${m.tuile} : nombre exact (${detailRequetes(rs)})');
      final p = periode[m.tuile];
      if (p != null) {
        final rp = await compter(serveur, () async {
          await tester.ensureVisible(find.byKey(const Key('periode_hier')));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.byKey(const Key('periode_hier')));
          await laisser(tester);
        });
        mesurer('Requêtes — ${m.tuile} : changement de période (« Hier »)', rp.length, seuil: p, unite: 'requêtes', detail: detailRequetes(rp));
        expect(rp.length, p);
      }
      final retour = await compter(serveur, () => revenir(tester));
      expect(retour, isEmpty, reason: 'retour à l\'accueil sans requête');
    }
    // Menu réuni « CA Crédit » (3.11.0) : ouverture = le Détail seulement (/ca-credit) ; onglet Synthèse = Suivi
    // Crédit (/recap/credits, une fois) ; revenir au Détail ne relit rien.
    final credits = await compter(serveur, () async {
      await tester.enterText(find.byKey(const Key('recherche_menu')), 'CA Crédit');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.text('CA Crédit')).first);
      await laisser(tester);
    });
    mesurer('Requêtes — ouverture CA Crédit (Détail)', credits.length, seuil: 1, unite: 'requêtes', detail: detailRequetes(credits));
    expect(credits.map((r) => r.chemin), ['/ca-credit']);
    final synthese = await compter(serveur, () async {
      await tester.tap(find.byKey(const Key('onglet_menu_1')));
      await laisser(tester);
    });
    mesurer('Requêtes — CA Crédit : onglet Synthèse (Suivi Crédit)', synthese.length, seuil: 1, unite: 'requêtes', detail: detailRequetes(synthese));
    expect(synthese.map((r) => r.chemin), [AppConstants.suiviCreditEndpoint]);
    final detail = await compter(serveur, () async {
      await tester.tap(find.byKey(const Key('onglet_menu_0')));
      await laisser(tester, secondes: 1);
    });
    expect(detail, isEmpty, reason: 'onglet déjà chargé : rien de relu');
    await fermerApplication(tester);
  });

  testWidgets('recherche tapée vite (10 lettres, 120 ms entre deux) : UNE requête après l\'anti-rebond', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.compact);
    await jusquConnexion(tester);
    await seConnecter(tester, find.byType(AccueilNouveau));
    await ouvrirParRecherche(tester, module('Analyse Article'));
    final rs = await compter(serveur, () async {
      var texte = '';
      for (final c in 'PARAFICTIF'.split('')) {
        texte += c;
        await tester.enterText(find.byKey(const Key('champ_recherche')), texte);
        await tester.pump(const Duration(milliseconds: 120)); // frappe rapide
      }
      await laisser(tester);
    });
    mesurer('Requêtes — recherche tapée vite (Analyse Article, 10 lettres)', rs.length, seuil: 1, unite: 'requêtes', detail: detailRequetes(rs));
    expect(rs.single.chemin, AppConstants.infoEndpoint);
    expect(rs.single.parametres['search'], 'PARAFICTIF', reason: 'le texte complet est cherché');
    await fermerApplication(tester);
  });

  testWidgets('alertes de l\'accueil A : aucun appel automatique (10 min), ⟳ = UNE requête (double appui compris)', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.tableauDeBord);
    await jusquConnexion(tester);
    await seConnecter(tester, find.byType(AccueilNouveau));
    bool alerte(RequeteRecue r) => r.chemin.startsWith('/tableau-bord/alertes');
    final attente = await compter(serveur, () async {
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 10));
      }
    });
    mesurer('Requêtes — accueil A laissé ouvert 10 min (alertes sans ⟳)', attente.where(alerte).length, seuil: 0, unite: 'requêtes',
        detail: detailRequetes(attente));
    final bouton = find.byKey(const Key('alerte_peremption_actualiser'));
    await tester.ensureVisible(bouton);
    await tester.pump(const Duration(milliseconds: 300));
    final rs = await compter(serveur, () async {
      await tester.tap(bouton);
      await tester.tap(bouton, warnIfMissed: false); // double appui
      await laisser(tester);
    });
    mesurer('Requêtes — ⟳ des alertes (double appui)', rs.where(alerte).length, seuil: 1, unite: 'requêtes', detail: detailRequetes(rs));
    expect(rs.where(alerte), hasLength(1));
    expect(rs.length, 1, reason: 'rien d\'autre que le comptage');
    await fermerApplication(tester);
  });
}
