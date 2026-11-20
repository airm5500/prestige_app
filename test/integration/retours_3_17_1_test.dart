// 3.17.1 — retour du serveur du 20/11 sur les demandes 67 et 68 (commit serveur 58db6a4e, intégration 63e9c10c, pas
// encore déployé en officine) et retour du pharmacien sur l'Analyse Article. Écrans contre les TROIS faux serveurs
// (support/donnees_3_17_1.dart : ancien 76aa5fc1, 67/68 initial 8dd9c9be, 67/68 + retour 63e9c10c), client HTTP en
// mémoire, horloge simulée, données fictives.
//  67. CA crédit : repère luLe (page servie par une autre lecture → page 0 relue, jamais de doublon ni d'oubli),
//      tiersPayantsRetenus affiché avec une recherche ; serveur sans ces champs : comportement 3.17.0 ; serveur qui
//      annonce ses routes sans « ca-credit » : requête de la 3.16.0.
//  68. Carte TVA, routes annoncées et 404 retenu sur l'appareil : session 1 / session 2 sur chaque serveur.
//  Analyse Article (« doli ») : fiche de base affichée tout de suite pour chaque produit, même quand les analyses
//  lourdes passent une à une côté serveur ; aucune analyse en double ; retour sur un produit déjà lu immédiat ;
//  fermeture de l'écran : analyses en cours abandonnées, aucune requête orpheline.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/donnees/recherche_produit_donnees.dart';
import 'package:prestige_app/donnees/routes_serveur.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/application.dart';
import '../support/donnees_3_17_0.dart';
import '../support/donnees_3_17_1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/grandes_donnees.dart';
import '../support/polices.dart';
import 'retours_3_10_0_test.dart' show demonter, pomper, serveur;
import 'retours_3_16_0_test.dart' show cle, maintenant, monterEcran;
import 'retours_3_17_0_test.dart' show chiffre, defilerJusquAuBout, detailChiffre, recues, routeCredit, saisirRecherche;

/// Écran affiché par l'arbre monté (changé sans remonter l'application : même session de préférences).
final ecran = ValueNotifier<Widget?>(null);

Future<void> monterHote(WidgetTester tester, {double hauteur = 891}) async {
  ecran.value = null;
  await monterEcran(tester, () => ValueListenableBuilder<Widget?>(
      valueListenable: ecran, builder: (_, w, __) => w ?? const Scaffold(body: Center(child: Text('Autre écran')))), hauteur: hauteur);
}

String racine(WidgetTester tester) => Provider.of<IpConfigProvider>(tester.element(find.byType(Scaffold).first), listen: false).racineServeur;

/// Nouvelle session (comme une reconnexion) : nouveau client HTTP, donc nouvelle source des caches de session.
void nouvelleSession() => ApiService.client = serveur.clientMemoire();

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    serveur.installerRoutesParDefaut();
    CaCreditDonnees.oublierModes();
    RoutesServeur.oublierSession();
    RechercheProduit.cacheAnalyses.vider();
    RechercheProduit.cacheListes.vider();
  });

  group('67 · CA crédit, serveur 67/68 + retour (luLe, tiersPayantsRetenus)', () {
    testWidgets('luLe stable : pages bout à bout comme la 3.17.0 ; période relue entre deux pages : page NON ajoutée, page 0 relue, ni doublon ni oubli', (tester) async {
      final lignes = GrandesDonnees.caCredit(130);
      Donnees3171.installer(serveur, ServeurOfficine.retour, lignes: lignes);
      var relue = false;
      serveur.route(routeCredit, (r) {
        // Le serveur relit la période juste avant de servir la page 50 (plus de 60 s sans page, autre téléphone…).
        if (r.parametres['start'] == '50' && !relue) {
          relue = true;
          Donnees3171.relire();
        }
        return ReponseFausse.json(Donnees3171.caCreditRetour(lignes, r.parametres));
      }, methode: 'GET');
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      final vues = await defilerJusquAuBout(tester);
      expect([for (final p in recues(routeCredit)) p['start']], ['0', '50', '0', '50', '100'],
          reason: 'page 50 d\'une autre lecture écartée, page 0 relue, puis la suite de la MÊME lecture');
      expect(vues, [for (final o in Donnees3170.trier(lignes)) o['numFacturation']], reason: 'ni doublon ni vente oubliée');
      expect(find.text('130 lignes affichées sur 130'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await demonter(tester);
    });

    testWidgets('relectures sans fin côté serveur : deux relectures au plus, puis « Réessayer » (aucune boucle de requêtes)', (tester) async {
      final lignes = GrandesDonnees.caCredit(130);
      Donnees3171.installer(serveur, ServeurOfficine.retour, lignes: lignes);
      serveur.route(routeCredit, (r) {
        if (r.parametres['start'] != '0') Donnees3171.relire();
        return ReponseFausse.json(Donnees3171.caCreditRetour(lignes, r.parametres));
      }, methode: 'GET');
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      await defilerJusquAuBout(tester);
      final n = recues(routeCredit).length;
      expect(n, lessThanOrEqualTo(6), reason: 'bornée : ${[for (final p in recues(routeCredit)) p['start']]}');
      await pomper(tester, 20);
      expect(recues(routeCredit), hasLength(n), reason: 'plus rien sans geste de l\'utilisateur');
      expect(find.textContaining('50 lignes affichées sur 130'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('recherche : « Tiers payants » = tiersPayantsRetenus du serveur, sans « de la période »', (tester) async {
      final lignes = GrandesDonnees.caCredit(130);
      Donnees3171.installer(serveur, ServeurOfficine.retour, lignes: lignes);
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      expect(chiffre(tester, 'tiers'), '9');
      await saisirRecherche(tester, '1');
      await pomper(tester, 6);
      final retenues = Donnees3170.filtrer(lignes, '1', null);
      expect(retenues.length, greaterThan(50), reason: 'plus d\'une page : tout n\'est pas chargé');
      expect(chiffre(tester, 'tiers'), '${{for (final o in retenues) o['tiersPayantLibelle']}.length}');
      expect(detailChiffre(tester, 'tiers'), isNull);
      await demonter(tester);
    });

    testWidgets('serveur 67/68 initial (sans ces champs) : comportement 3.17.0 (« de la période », pages bout à bout)', (tester) async {
      final lignes = GrandesDonnees.caCredit(130);
      Donnees3171.installer(serveur, ServeurOfficine.initial, lignes: lignes);
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      await saisirRecherche(tester, '1');
      await pomper(tester, 6);
      expect(chiffre(tester, 'tiers'), '9');
      expect(detailChiffre(tester, 'tiers'), 'de la période');
      await saisirRecherche(tester, '');
      await pomper(tester, 6);
      serveur.oublierRequetes();
      final vues = await defilerJusquAuBout(tester);
      expect([for (final p in recues(routeCredit)) p['start']], ['50', '100']);
      expect(vues, [for (final o in Donnees3170.trier(lignes)) o['numFacturation']]);
      await demonter(tester);
    });

    testWidgets('serveur qui annonce ses routes SANS « ca-credit » : requête de la 3.16.0 d\'emblée (liste, recherche locale)', (tester) async {
      Donnees3171.installer(serveur, ServeurOfficine.retour, routesAnnoncees: ['tva']);
      await monterHote(tester);
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      await tester.runAsync(() => prefs!.setString(RoutesServeur.cle, jsonEncode({
            racine(tester): {'routes': ['tva']}
          })));
      ecran.value = CaCreditNouveau(maintenant: () => maintenant);
      await pomper(tester, 10);
      expect(recues(routeCredit).single.keys.toSet(), {'dtStart', 'dtEnd'});
      expect(chiffre(tester, 'ventes'), '6');
      await saisirRecherche(tester, 'beta');
      await pomper(tester, 8);
      expect(chiffre(tester, 'ventes'), '2');
      expect(recues(routeCredit), hasLength(1), reason: 'recherche locale');
      await demonter(tester);
    });
  });

  group('68 · Carte TVA : routes annoncées, 404 retenu sur l\'appareil (sessions 1 et 2)', () {
    Future<void> session(WidgetTester tester) async {
      ecran.value = null;
      await pomper(tester, 2);
      nouvelleSession();
      serveur.oublierRequetes();
      ecran.value = Scaffold(body: AccueilTableauPrestige(maintenant: () => maintenant, memoire: MemoireTableauBord()));
      await pomper(tester, 15);
    }

    int n(String chemin) => serveur.recues(chemin).length;

    for (final (v, s1, s2) in [
      // (serveur, requêtes [tva, tvas, version] en session 1, puis en session 2)
      (ServeurOfficine.ancien, [1, 1, 0], [0, 1, 0]),
      (ServeurOfficine.initial, [1, 0, 1], [1, 0, 0]),
      (ServeurOfficine.retour, [1, 0, 1], [1, 0, 0]),
    ]) {
      testWidgets('${v.nom} : session 1 $s1, session 2 $s2 (tva, tvas, version)', (tester) async {
        Donnees3171.installer(serveur, v);
        await monterHote(tester, hauteur: 3000);
        await session(tester);
        expect([n('/tableau-bord/tva'), n('/tvas'), n(RoutesServeur.route)], s1);
        expect(n('/officine'), 0, reason: 'aucune vérification /officine pour une route essayée');
        await session(tester);
        expect([n('/tableau-bord/tva'), n('/tvas'), n(RoutesServeur.route)], s2);
        if (v == ServeurOfficine.ancien) {
          // ⟳ : la route est réessayée (une mise à jour du serveur se voit tout de suite).
          serveur.oublierRequetes();
          await tester.tap(cle('tableau_bord_actualiser'));
          await pomper(tester, 10);
          expect(n('/tableau-bord/tva'), 1);
          expect(n(RoutesServeur.route), 0);
        }
        await demonter(tester);
      });
    }

    testWidgets('mise à jour du serveur (ancien → retour) après un 404 retenu : ⟳ la voit, puis routes annoncées', (tester) async {
      Donnees3171.installer(serveur, ServeurOfficine.ancien);
      await monterHote(tester, hauteur: 3000);
      await session(tester);
      expect(n('/tableau-bord/tva'), 1);
      Donnees3171.installer(serveur, ServeurOfficine.retour);
      await session(tester);
      expect([n('/tableau-bord/tva'), n('/tvas')], [0, 1], reason: '404 retenu (moins de 24 h)');
      serveur.oublierRequetes();
      await tester.tap(cle('tableau_bord_actualiser'));
      await pomper(tester, 10);
      expect([n('/tableau-bord/tva'), n('/tvas'), n(RoutesServeur.route)], [1, 0, 1]);
      await session(tester);
      expect([n('/tableau-bord/tva'), n('/tvas'), n(RoutesServeur.route)], [1, 0, 0]);
      await demonter(tester);
    });

    testWidgets('serveur qui annonce ses routes SANS « tva » : /api/v3/tvas directement, aucune requête d\'essai', (tester) async {
      Donnees3171.installer(serveur, ServeurOfficine.retour, routesAnnoncees: ['ca-credit']);
      await monterHote(tester, hauteur: 3000);
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      await tester.runAsync(() => prefs!.setString(RoutesServeur.cle, jsonEncode({
            racine(tester): {'routes': ['ca-credit']}
          })));
      await session(tester);
      expect([n('/tableau-bord/tva'), n('/tvas'), n(RoutesServeur.route)], [0, 1, 0]);
      await demonter(tester);
    });

    test('lecture de tableau-bord/version : routes, sans routes, forme inattendue', () {
      expect(RoutesServeur.lireRoutes(Donnees3171.version(routes: Donnees3171.routes)), {'tva', 'ca-credit'});
      expect(RoutesServeur.lireRoutes(Donnees3171.version()), isNull);
      expect(RoutesServeur.lireRoutes({'routes': 'tva'}), isNull);
      expect(RoutesServeur.lireRoutes({'routes': ['tva', 3, ' ', 'ca-credit ']}), {'tva', 'ca-credit'});
      expect(RoutesServeur.lireRoutes([]), isNull);
    });
  });

  group('Analyse Article (« doli ») : analyses lourdes, session sérialisée côté serveur', () {
    late ClientSessionSerialisee client;

    Future<void> ouvrirListe(WidgetTester tester, {Duration duree = const Duration(seconds: 8)}) async {
      serveur.quand(AppConstants.rechercheProduitEndpoint, ReponseFausse.json(Donnees3171.rechercheDoli()), methode: 'GET');
      serveur.route(AppConstants.infoEndpoint, (r) => ReponseFausse.json(Donnees3171.infoDoli(r.parametres['search'] ?? '')), methode: 'GET');
      await monterHote(tester);
      client = ClientSessionSerialisee(serveur.clientMemoire(), lourde: (u) => u.path.endsWith('/info'), duree: (_) => duree);
      ApiService.client = client;
      ecran.value = const AnalyseArticleNouveau();
      await pomper(tester, 3);
      await tester.enterText(cle('champ_recherche'), 'doli');
      await pomper(tester, 6);
      expect(find.text(Donnees3171.libellesDoli[3]), findsOneWidget);
    }

    /// Toucher le produit [i] : sa fiche de base (désignation, CIP) doit être là en moins d'une seconde.
    Future<void> ouvrir(WidgetTester tester, int i) async {
      await tester.tap(find.text(Donnees3171.libellesDoli[i]));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byWidgetPredicate((w) => w is Text && w.key == const Key('fiche_base_titre') && w.data == Donnees3171.libellesDoli[i]).evaluate().length +
          find.byType(DetailAnalyseArticle).evaluate().length, greaterThan(0), reason: 'produit ${i + 1} : fiche affichée en moins d\'une seconde');
    }

    Future<void> sortir(WidgetTester tester) async {
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    testWidgets('produits 1, 2, 3, 4 ouverts l\'un après l\'autre : chaque fiche en < 1 s, analyse à son arrivée ; aucune en double', (tester) async {
      await ouvrirListe(tester);
      for (var i = 0; i < 4; i++) {
        await ouvrir(tester, i);
        expect(cle('analyse_ouverture'), findsOneWidget, reason: 'analyse en cours, indiquée');
        await sortir(tester);
      }
      expect(client.envoyees, Donnees3171.cipsDoli, reason: 'une analyse par produit');
      // Le produit 4 rouvert attend son analyse (les autres passent avant lui côté serveur) : la fiche de base est là.
      await ouvrir(tester, 3);
      expect(client.envoyees, hasLength(4), reason: 'analyse en cours reprise, pas relancée');
      await tester.pump(const Duration(seconds: 33));
      await pomper(tester, 3);
      expect(tester.widget<DetailAnalyseArticle>(find.byType(DetailAnalyseArticle)).article.codeCip, Donnees3171.cipsDoli[3]);
      await sortir(tester);
      // Retour sur le produit 1 : déjà lu, fiche complète immédiate, aucune requête.
      await tester.tap(find.text(Donnees3171.libellesDoli[0]));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.widget<DetailAnalyseArticle>(find.byType(DetailAnalyseArticle)).article.codeCip, Donnees3171.cipsDoli[0]);
      expect(client.envoyees, hasLength(4));
      expect(client.enSuspens, 0);
      expect(client.abandonnees, isEmpty);
      await sortir(tester);
      expect(tester.takeException(), isNull);
      await demonter(tester);
    });

    testWidgets('fermeture de l\'écran : analyses en cours ABANDONNÉES (connexion fermée), aucune requête orpheline, aucune erreur affichée', (tester) async {
      await ouvrirListe(tester, duree: const Duration(seconds: 20));
      await ouvrir(tester, 0);
      await sortir(tester);
      await ouvrir(tester, 1);
      await sortir(tester);
      expect(client.envoyees, Donnees3171.cipsDoli.sublist(0, 2));
      ecran.value = null; // l'utilisateur quitte Analyse Article
      await pomper(tester, 3);
      expect(client.abandonnees, Donnees3171.cipsDoli.sublist(0, 2));
      expect(client.enSuspens, 0, reason: 'aucune requête orpheline');
      await tester.pump(const Duration(seconds: 45));
      expect(client.recues, isEmpty);
      expect(find.byKey(const Key('etat_erreur')), findsNothing);
      // Réouverture : rien de gardé d'une analyse abandonnée, une nouvelle lecture.
      ecran.value = const AnalyseArticleNouveau();
      await pomper(tester, 3);
      await tester.enterText(cle('champ_recherche'), 'doli');
      await pomper(tester, 6);
      await ouvrir(tester, 0);
      expect(client.envoyees, hasLength(3));
      await tester.pump(const Duration(seconds: 21));
      await pomper(tester, 3);
      expect(find.byType(DetailAnalyseArticle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await demonter(tester);
    });

    testWidgets('CIP absent de /info : la fiche le dit (pas de détail) ; 500 : erreur et Réessayer dans la fiche', (tester) async {
      await ouvrirListe(tester, duree: const Duration(milliseconds: 200));
      serveur.quand(AppConstants.infoEndpoint, ReponseFausse.json([]), methode: 'GET');
      await ouvrir(tester, 0);
      await pomper(tester, 3);
      expect(find.text('Analyse introuvable pour le CIP ${Donnees3171.cipsDoli[0]}.'), findsOneWidget);
      await sortir(tester);
      serveur.quand(AppConstants.infoEndpoint, ReponseFausse.erreurServeur(), methode: 'GET');
      await ouvrir(tester, 1);
      await pomper(tester, 3);
      expect(cle('etat_erreur'), findsOneWidget);
      serveur.route(AppConstants.infoEndpoint, (r) => ReponseFausse.json(Donnees3171.infoDoli(r.parametres['search'] ?? '')), methode: 'GET');
      await tester.tap(find.text('Réessayer'));
      await pomper(tester, 5);
      expect(tester.widget<DetailAnalyseArticle>(find.byType(DetailAnalyseArticle)).article.codeCip, Donnees3171.cipsDoli[1]);
      await demonter(tester);
    });
  });
}
