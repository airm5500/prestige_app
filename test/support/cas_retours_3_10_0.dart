// États des écrans modifiés en 3.10.0, rendus par les tests d'ergonomie et de cohérence de la nouvelle interface
// (5 tailles, dont les Sunmi 720×1440 et 1080×1920 px, × texte 1,0 et 1,3, aucun écart toléré) :
//  - P4 « icônes illustrées » sur l'accueil A, l'accueil B, l'onglet Analyses (liste et barre du bas), « Tous les
//    menus » (C) ;
//  - « 6 tuiles par page » : accueil A (page « À surveiller » puis une page de 6), accueil B (6 lignes) ;
//  - Pointage BL par groupe : montant du groupe sans détail (serveur actuel), avec le détail par grossiste ;
//  - serveur récent : Visualisation BL (feuille avec « Utilisateur », avertissement « non appliqué »), détail d'un
//    avis avec « Actualiser », Prévisions « commandes en cours à jour », CA Global par opérateur ;
//  - Réglages : trois dispositions des menus (verrouillé avec explication), style P4 ;
//  - 3.10.1 : défaut (style jamais choisi → P4, tout sur une page) sur A, B et C ; style des icônes verrouillé.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_global_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/visualisation_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/reglages_nouveaux.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/previsions_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague3/avis_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';
import 'package:prestige_app/utils/constants.dart';

import 'cas_affichage.dart';
import 'cas_affichage_nouvelle.dart';
import 'donnees_fictives.dart';
import 'donnees_lot2.dart';
import 'donnees_lot3.dart';
import 'donnees_vague1.dart';
import 'donnees_vague2.dart';
import 'donnees_vague3.dart';
import 'faux_serveur_prestige.dart';

Future<void> _pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Ouvre l'écran comme sur un serveur RÉCENT (rôle reçu à la connexion) ; le compte est oublié à la fin du test.
Future<void> Function(WidgetTester, FauxServeurPrestige) surServeurRecent(Future<void> Function(WidgetTester, FauxServeurPrestige) ouvrir) =>
    (tester, serveur) async {
      ProfilAcces.utilisateur.value =
          AppUser.fromJson({...DonneesFictives.utilisateur(), 'role': {'code': 'PHARMACIEN', 'libelle': 'Pharmacien'}});
      addTearDown(() => ProfilAcces.utilisateur.value = null);
      await ouvrir(tester, serveur);
    };

/// Page suivante des menus (tablette : les menus restent sur une page, rien à faire).
Future<void> Function(WidgetTester) _pageSuivante(int fois) => (tester) async {
      if (find.byKey(const Key('page_menus_suivante')).evaluate().isEmpty) return;
      for (var i = 0; i < fois; i++) {
        await tester.tap(find.byKey(const Key('page_menus_suivante')));
        await _pomper(tester, 4);
      }
    };

/// Pointage BL : réponse d'un serveur qui donne le montant par grossiste du groupe.
void _pointageParGrossiste(FauxServeurPrestige s) {
  listesCommunesVague1(s);
  s.route(ApiPointage.route, (r) {
    final pieces = [
      {...DonneesVague3.piece('BL', 'BL-G1', 'BLF-2001', 200000), 'grossisteId': 'G1', 'grossiste': 'GROSSISTE FICTIF UN'},
      {...DonneesVague3.piece('BL', 'BL-G2', 'BLF-2002', 100000), 'grossisteId': 'G2', 'grossiste': 'GROSSISTE FICTIF DEUX AU NOM TRÈS LONG'},
    ];
    return ReponseFausse.json({
      'success': true, 'data': pieces, 'total': 2, 'totalBl': 300000, 'totalAvoirs': 0, 'net': 300000, 'pointes': 0, 'nonPointes': 2,
      'parGrossiste': [
        {'grossisteId': 'G1', 'libelle': 'GROSSISTE FICTIF UN', 'totalBl': 200000, 'totalAvoirs': 0, 'pieces': 1},
        {'grossisteId': 'G2', 'libelle': 'GROSSISTE FICTIF DEUX AU NOM TRÈS LONG', 'totalBl': 100000, 'totalAvoirs': 0, 'pieces': 1},
      ],
    });
  }, methode: 'GET');
}

Future<void> _filtresBl(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('bouton_filtres')));
  await _pomper(tester, 6);
}

/// Bons d'un autre utilisateur que celui choisi : le serveur n'a pas appliqué le filtre.
Future<void> _utilisateurIgnore(WidgetTester tester) async {
  await _filtresBl(tester);
  await tester.tap(find.byKey(const Key('filtre_utilisateur')));
  await _pomper(tester, 4);
  await tester.tap(find.text('EMPLOYE Fictif Deux').last);
  await _pomper(tester, 4);
  await tester.tap(find.byKey(const Key('filtres_appliquer')));
  await _pomper(tester);
  expect(find.byKey(const Key('filtre_utilisateur_non_applique')), findsOneWidget);
}

final casRetours3100 = <CasAffichage>[
  // P4 « icônes illustrées ».
  CasAffichage('3.10.0 · Accueil A · style p4', enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, style: StyleIcones.p4)),
  CasAffichage('3.10.0 · Accueil B · style p4', enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.compact, style: StyleIcones.p4)),
  CasAffichage('3.10.0 · Onglet Analyses · style p4',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, style: StyleIcones.p4, ensuite: onglet('Analyses'))),
  CasAffichage('3.10.0 · Tous les menus (C) · style p4', enNouvelle(ecranConnecte(() => const TousLesMenusScreen()), style: StyleIcones.p4)),
  // 6 tuiles par page.
  CasAffichage('3.10.0 · Accueil A · 6 tuiles par page',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, affichage: AffichageMenus.parSix)),
  CasAffichage(
      '3.10.0 · Accueil A · 6 tuiles par page · page de tuiles (P4)',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()),
          p: Presentation.tableauDeBord, affichage: AffichageMenus.parSix, style: StyleIcones.p4, ensuite: _pageSuivante(2))),
  CasAffichage('3.10.0 · Accueil B · 6 tuiles par page',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.compact, affichage: AffichageMenus.parSix)),
  CasAffichage(
      '3.10.0 · Accueil B · 6 tuiles par page · page suivante (P3)',
      enNouvelle(ecranConnecte(() => const AccueilNouveau()),
          p: Presentation.compact, affichage: AffichageMenus.parSix, style: StyleIcones.p3, ensuite: _pageSuivante(1))),
  // Pointage BL par groupe.
  CasAffichage(
      '3.10.0 · Pointage BL · par groupe (montant du groupe)',
      enNouvelle(ecranConnecte(() => const PointageBlScreen()),
          donnees: listesCommunesVague1, prefs: {DernierCriterePointage.cle: 'groupe:${DonneesVague3.groupe}'})),
  CasAffichage(
      '3.10.0 · Pointage BL · par groupe, montant de chaque grossiste',
      enNouvelle(ecranConnecte(() => const PointageBlScreen()),
          donnees: _pointageParGrossiste, prefs: {DernierCriterePointage.cle: 'groupe:${DonneesVague3.groupe}'})),
  CasAffichage(
      '3.10.0 · Pointage BL · choix « Par groupe » sans groupe',
      enNouvelle(ecranConnecte(() => const PointageBlScreen()), donnees: listesCommunesVague1, ensuite: (tester) async {
        await tester.tap(find.byKey(const Key('pointage_mode_groupe')));
        await _pomper(tester, 4);
      })),
  // Serveur récent.
  CasAffichage('3.10.0 · Visualisation BL · filtre « Utilisateur » (serveur récent)',
      enNouvelle(surServeurRecent(ecranConnecte(() => const VisualisationBlNouveau())), donnees: donneesLot2, ensuite: _filtresBl)),
  CasAffichage('3.10.0 · Visualisation BL · filtre « Utilisateur » non appliqué',
      enNouvelle(surServeurRecent(ecranConnecte(() => const VisualisationBlNouveau())), donnees: donneesLot2, ensuite: _utilisateurIgnore)),
  CasAffichage(
      '3.10.0 · Avis · détail avec « Actualiser » (serveur récent)',
      enNouvelle(surServeurRecent(ecranConnecte(() => const AvisDetailScreen(id: 'AVIS-TEST-1', droits: DroitsAvis(repondre: true)))))),
  CasAffichage(
      '3.10.0 · Prévisions · commandes en cours à jour',
      enNouvelle(ecranConnecte(() => const PrevisionsScreen()),
          donnees: (s) => s.quand(ApiPrevisions.routeTableau, ReponseFausse.json({...DonneesVague2.tableau(), 'enCoursAJour': '15/10/2026 08:12'}), methode: 'GET'))),
  CasAffichage(
      '3.10.0 · CA Global · Mobile Money par opérateur',
      enNouvelle(ecranConnecte(() => const CaGlobalNouveau()), donnees: (s) {
        donneesLot3(s);
        s.quand(AppConstants.caAllEndpoint, ReponseFausse.json(DonneesFictives.caParJourAvecDetail()), methode: 'GET');
      })),
  // Réglages.
  CasAffichage(
      '3.10.0 · Réglages · trois dispositions des menus (verrouillé) et style P4',
      enNouvelle(ecranConnecte(() => Scaffold(
            appBar: AppBar(title: const Text('Réglages')),
            body: ListView(children: const [
              ChoixAffichageMenus(choix: AffichageMenus.parSix, verrouille: true),
              ChoixStyleIcones(choix: StyleIcones.p4),
            ]),
          )))),
  // 3.10.1 : P4 par défaut (style jamais choisi), style des icônes visible et verrouillé pour un compte simple.
  CasAffichage('3.10.1 · Accueil A · défaut (P4, tout sur une page)', enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.tableauDeBord, style: null)),
  CasAffichage('3.10.1 · Accueil B · défaut (P4)', enNouvelle(ecranConnecte(() => const AccueilNouveau()), p: Presentation.compact, style: null)),
  CasAffichage('3.10.1 · Tous les menus (C) · défaut (P4)', enNouvelle(ecranConnecte(() => const TousLesMenusScreen()), style: null)),
  CasAffichage(
      '3.10.1 · Réglages · style des icônes verrouillé (compte simple)',
      enNouvelle(ecranConnecte(() => Scaffold(
            appBar: AppBar(title: const Text('Réglages')),
            body: ListView(children: const [
              ChoixAffichageMenus(choix: AffichageMenus.unePage, verrouille: true),
              ChoixStyleIcones(choix: StyleIcones.p4, verrouille: true),
            ]),
          )))),
];
