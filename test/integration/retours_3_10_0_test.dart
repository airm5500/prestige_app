// Décisions du pharmacien et réponse du serveur appliquées en 3.10.0, écrans contre le faux serveur (client en
// mémoire, horloge simulée) : PARAMÈTRES TRANSMIS, réponses d'un serveur RÉCENT (branche du 15/10/2026) et REPLI sur
// un serveur plus ancien (sans régression).
//  1. Pointage BL par grossiste ou par groupe : « Par groupe de grossistes » → `groupe=<id>` et `grossiste` vide ;
//     changement de mode sans requête ; montant du grossiste / du groupe ; détail par grossiste : du serveur, calculé
//     sur les pièces, ou mention « pas encore fourni » (serveur actuel) ; jamais de requête « tous les grossistes » ;
//  2. Visualisation BL : filtre « Utilisateur » → `userId` (serveur récent) ; serveur ancien : filtre absent, userId
//     vide (comme la 3.8.0) ; serveur récent qui ignorerait le filtre → avertissement ;
//  3. Avis : « Actualiser » du détail → `marquerLu=false` (serveur récent), l'avis remis en « Nouveau » le reste ;
//     serveur ancien : pas de bouton (le paramètre serait ignoré et l'avis marqué « lu ») ;
//  4. Prévisions : « Commandes en cours à jour le … » si `enCoursAJour`, rien sinon ;
//  5. CA Global : opérateurs Mobile Money si `detailMobile` (aucun appel en plus), rien sinon.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/detail_ca_donnees.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart' show formaterMontant;
import 'package:prestige_app/nouvelle_interface/modules/ca_global_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/visualisation_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/previsions_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague3/avis_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot2.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague2.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

/// Utilisateur mémorisé (relu au lancement) : serveur récent = rôle reçu à la connexion.
Map<String, Object> utilisateurMemorise({required bool recent}) => {
      AppConstants.userDataKey: jsonEncode({
        ...DonneesFictives.utilisateur(),
        if (recent) 'role': {'code': 'PHARMACIEN', 'libelle': 'Pharmacien'},
      }),
    };

Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> monter(WidgetTester tester, Widget Function() ecran, {bool recent = false, Map<String, Object> prefs = const {}}) async {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 6000 * 2.625);
  addTearDown(tester.view.reset);
  preparerTelephone(serveur, nouvelle: true, autres: {...utilisateurMemorise(recent: recent), ...prefs});
  ApiService.client = serveur.clientMemoire();
  serveur.oublierRequetes();
  // Compte connecté (comme après POST /user/auth) : rôle présent = serveur récent.
  ProfilAcces.utilisateur.value = AppUser.fromJson(jsonDecode(utilisateurMemorise(recent: recent)[AppConstants.userDataKey] as String));
  await ecranConnecte(ecran)(tester, serveur);
  await pomper(tester);
  expect(ProfilAcces.serveurRecent, recent, reason: 'serveur ${recent ? 'récent' : 'ancien'} simulé');
}

Future<void> demonter(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
  ProfilAcces.utilisateur.value = null;
}

Future<void> toucher(WidgetTester tester, Finder f, [int fois = 8]) async {
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(f.first);
  await pomper(tester, fois);
}

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
  });

  group('1 · Pointage BL : par grossiste ou par groupe de grossistes', () {
    Iterable<RequeteRecue> listes() => serveur.recues(ApiPointage.route);
    setUp(() => listesCommunesVague1(serveur));

    testWidgets('« Par groupe » : groupe envoyé, grossiste vide ; changement de mode sans requête ; mention du détail absent',
        (tester) async {
      await monter(tester, () => const PointageBlScreen());
      expect(cle('pointage_grossiste'), findsOneWidget, reason: 'par défaut : par grossiste');
      expect(cle('pointage_groupe'), findsNothing);
      await toucher(tester, cle('pointage_mode_groupe'));
      expect(listes(), isEmpty, reason: 'changer de mode ne demande rien');
      expect(cle('pointage_grossiste'), findsNothing);
      await toucher(tester, cle('pointage_groupe'));
      await toucher(tester, find.text('GROUPE FICTIF').last);
      final p = listes().single.parametres;
      expect(p['groupe'], DonneesVague3.groupe);
      expect(p['grossiste'], '');
      expect(cle('pointage_montant'), findsOneWidget);
      expect(find.text('Montant du groupe'), findsOneWidget);
      expect(tester.widget<Text>(cle('pointage_montant_libelle')).data, 'GROUPE FICTIF');
      // Serveur actuel : pièces sans grossiste → pas de détail inventé, mention.
      expect(cle('pointage_detail_groupe_absent'), findsOneWidget);
      expect(await DernierCriterePointage.lire(), ('', DonneesVague3.groupe));
      // Retour au mode grossiste : choix effacé, aucune requête, explication.
      serveur.oublierRequetes();
      await toucher(tester, cle('pointage_mode_grossiste'));
      expect(listes(), isEmpty);
      expect(cle('pointage_pourquoi'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('groupe repris : mode « groupe » affiché, montant du groupe ; aucune requête « ALL » ni sans critère', (tester) async {
      await monter(tester, () => const PointageBlScreen(), prefs: {DernierCriterePointage.cle: 'groupe:${DonneesVague3.groupe}'});
      expect(cle('pointage_groupe'), findsOneWidget);
      expect(cle('pointage_dernier_choix'), findsOneWidget);
      expect(listes().single.parametres['groupe'], DonneesVague3.groupe);
      for (final r in listes()) {
        expect('${r.parametres['grossiste']}${r.parametres['groupe']}', isNotEmpty);
        expect(r.parametres.values.map((v) => v.toUpperCase()), isNot(contains('ALL')));
      }
      await demonter(tester);
    });

    testWidgets('serveur qui donne « parGrossiste » : montant de chaque grossiste du groupe', (tester) async {
      serveur.route(ApiPointage.route, (r) {
        return ReponseFausse.json({
          'success': true, 'data': <Object>[], 'total': 0, 'totalBl': 300000, 'totalAvoirs': -20000, 'net': 280000, 'pointes': 0, 'nonPointes': 0,
          'parGrossiste': [
            {'grossisteId': 'G1', 'libelle': 'GROSSISTE UN', 'totalBl': 200000, 'totalAvoirs': -20000, 'net': 180000, 'pieces': 2},
            {'grossisteId': 'G2', 'libelle': 'GROSSISTE DEUX', 'totalBl': 100000, 'totalAvoirs': 0, 'net': 100000, 'pieces': 1},
          ],
        });
      }, methode: 'GET');
      await monter(tester, () => const PointageBlScreen(), prefs: {DernierCriterePointage.cle: 'groupe:${DonneesVague3.groupe}'});
      expect(cle('pointage_grossiste_du_groupe_G1'), findsOneWidget);
      expect(cle('pointage_grossiste_du_groupe_G2'), findsOneWidget);
      expect(cle('pointage_detail_groupe_absent'), findsNothing);
      expect(tester.widget<Text>(cle('pointage_montant_net')).data, formaterMontant(280000));
      await demonter(tester);
    });

    testWidgets('pièces qui portent leur grossiste (état « Toutes ») : détail calculé ; un grossiste seul : pas de détail', (tester) async {
      serveur.route(ApiPointage.route, (r) {
        final pieces = [
          {...DonneesVague3.piece('BL', 'BL-G1', 'BLF-1', 100000), 'grossisteId': 'G1', 'grossiste': 'GROSSISTE UN'},
          {...DonneesVague3.piece('BL', 'BL-G2', 'BLF-2', 50000), 'grossisteId': 'G2', 'grossiste': 'GROSSISTE DEUX'},
        ];
        return ReponseFausse.json({'success': true, 'data': pieces, 'total': 2, 'totalBl': 150000, 'totalAvoirs': 0, 'net': 150000, 'pointes': 0, 'nonPointes': 2});
      }, methode: 'GET');
      await monter(tester, () => const PointageBlScreen(), prefs: {DernierCriterePointage.cle: 'groupe:${DonneesVague3.groupe}'});
      expect(cle('pointage_grossiste_du_groupe_G1'), findsOneWidget);
      expect(cle('pointage_grossiste_du_groupe_G2'), findsOneWidget);
      await demonter(tester);

      await monter(tester, () => const PointageBlScreen(), prefs: {DernierCriterePointage.cle: 'grossiste:${DonneesVague3.grossiste}'});
      expect(find.text('Montant du grossiste'), findsOneWidget);
      expect(cle('pointage_grossiste_du_groupe_G1'), findsNothing);
      expect(cle('pointage_detail_groupe_absent'), findsNothing);
      await demonter(tester);
    });
  });

  group('2 · Visualisation BL : filtre « Utilisateur » (demande 26)', () {
    setUp(() => donneesLot2(serveur));
    Map<String, String> derniere() => serveur.recues('/etat-control-bon/list').last.parametres;

    Future<void> choisirUtilisateur(WidgetTester tester, String nom) async {
      await toucher(tester, cle('bouton_filtres'), 6);
      expect(cle('filtre_utilisateur'), findsOneWidget);
      await toucher(tester, cle('filtre_utilisateur'), 4);
      await toucher(tester, find.text(nom).last, 4);
      await toucher(tester, cle('filtres_appliquer'));
    }

    testWidgets('serveur ancien : filtre absent (mention), userId vide — comme la 3.8.0', (tester) async {
      await monter(tester, () => const VisualisationBlNouveau());
      expect(derniere()['userId'], '');
      await toucher(tester, cle('bouton_filtres'), 6);
      expect(cle('filtre_utilisateur'), findsNothing);
      expect(cle('filtre_utilisateur_a_venir'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('serveur récent : filtre proposé, userId envoyé, liste filtrée par le serveur, étiquette ; retrait', (tester) async {
      serveur.route('/etat-control-bon/list', (r) {
        final u = r.parametres['userId'] ?? '';
        final bons = [
          for (final b in DonneesLot2.bons())
            if (u.isEmpty || (u == 'USR-2') == ((b['user'] as Map)['fullName'] == 'EMPLOYE Fictif Deux')) b
        ];
        return ReponseFausse.json({'total': bons.length, 'data': bons.take(20).toList()});
      }, methode: 'GET');
      await monter(tester, () => const VisualisationBlNouveau(), recent: true);
      await choisirUtilisateur(tester, 'EMPLOYE Fictif Deux');
      expect(derniere()['userId'], 'USR-2');
      expect(find.text('Utilisateur : EMPLOYE Fictif Deux'), findsOneWidget);
      expect(cle('filtre_utilisateur_non_applique'), findsNothing);
      await demonter(tester);
    });

    testWidgets('serveur récent qui IGNORE le filtre : avertissement « non appliqué »', (tester) async {
      await monter(tester, () => const VisualisationBlNouveau(), recent: true);
      await choisirUtilisateur(tester, 'EMPLOYE Fictif Deux');
      expect(derniere()['userId'], 'USR-2');
      expect(cle('filtre_utilisateur_non_applique'), findsOneWidget);
      await demonter(tester);
    });
  });

  group('3 · Avis : relecture sans marquer « lu » (demande 22)', () {
    Iterable<RequeteRecue> details() => serveur.recues('/avis-clients/avis/AVIS-TEST-1');

    testWidgets('serveur récent : ouverture marque « lu » (comme le web) ; « Actualiser » → marquerLu=false, reste « Nouveau »',
        (tester) async {
      // Serveur récent : respecte marquerLu.
      serveur.route('/avis-clients/avis/AVIS-TEST-1', (r) {
        final a = etatVague3.avis.firstWhere((x) => x['id'] == 'AVIS-TEST-1');
        if (r.parametres['marquerLu'] != 'false' && a['statut'] == 'NOUVEAU') a['statut'] = 'LU';
        return ReponseFausse.json({'success': true, 'data': {...a}});
      }, methode: 'GET');
      await monter(tester, () => const AvisDetailScreen(id: 'AVIS-TEST-1', droits: DroitsAvis(repondre: true)), recent: true);
      expect(details().single.parametres.containsKey('marquerLu'), isFalse, reason: 'ouverture : comportement du web');
      await toucher(tester, cle('avis_remettre_nouveau'), 4);
      await toucher(tester, cle('confirmer_oui'));
      expect(etatVague3.avis.firstWhere((x) => x['id'] == 'AVIS-TEST-1')['statut'], 'NOUVEAU');
      await toucher(tester, cle('avis_detail_actualiser'));
      expect(details().last.parametres, {'marquerLu': 'false'});
      expect(etatVague3.avis.firstWhere((x) => x['id'] == 'AVIS-TEST-1')['statut'], 'NOUVEAU', reason: 'pas remis « lu »');
      expect(find.text('Nouveau'), findsWidgets);
      await demonter(tester);
    });

    testWidgets('serveur ancien : pas de bouton « Actualiser » (le paramètre serait ignoré) ; une seule lecture', (tester) async {
      await monter(tester, () => const AvisDetailScreen(id: 'AVIS-TEST-1', droits: DroitsAvis(repondre: true)));
      expect(cle('avis_detail_actualiser'), findsNothing);
      expect(details(), hasLength(1));
      await demonter(tester);
    });
  });

  group('4 · Prévisions : commandes en cours à jour (demande 23)', () {
    testWidgets('« enCoursAJour » affiché ; absent → aucune ligne', (tester) async {
      serveur.quand(ApiPrevisions.routeTableau, ReponseFausse.json({...DonneesVague2.tableau(), 'enCoursAJour': '15/10/2026 08:12'}), methode: 'GET');
      await monter(tester, () => const PrevisionsScreen());
      expect(find.text('Commandes en cours à jour le 15/10/2026 08:12'), findsOneWidget);
      await demonter(tester);
      serveur.quand(ApiPrevisions.routeTableau, ReponseFausse.json(DonneesVague2.tableau()), methode: 'GET');
      await monter(tester, () => const PrevisionsScreen());
      expect(cle('previsions_dernier_calcul'), findsOneWidget);
      expect(cle('previsions_en_cours_a_jour'), findsNothing);
      await demonter(tester);
    });
  });

  group('5 · CA Global : Mobile Money par opérateur (demande 25)', () {
    testWidgets('« detailMobile » présent : opérateurs sous le total, aucun appel en plus ; absent : rien', (tester) async {
      donneesLot3(serveur);
      serveur.quand(AppConstants.caAllEndpoint, ReponseFausse.json(DonneesFictives.caParJourAvecDetail()), methode: 'GET');
      await monter(tester, () => const CaGlobalNouveau());
      expect(cle('ca_global_mobile_detail'), findsOneWidget);
      expect(find.text('dont Orange'), findsOneWidget);
      expect(find.text('dont Wave'), findsOneWidget);
      expect(find.text('dont MTN'), findsOneWidget);
      expect(serveur.recues(DetailCa.routeModes), isEmpty, reason: 'aucun appel complémentaire');
      expect(serveur.recues(AppConstants.caAllEndpoint), hasLength(1));
      await demonter(tester);

      donneesLot3(serveur);
      await monter(tester, () => const CaGlobalNouveau());
      expect(cle('ca_global_mobile_detail'), findsNothing);
      expect(serveur.recues(DetailCa.routeModes), isEmpty);
      await demonter(tester);
    });
  });
}
