// Retours du pharmacien appliqués en 3.9.0, écrans contre le faux serveur (client en mémoire, horloge simulée) :
// PARAMÈTRES TRANSMIS et réponses du serveur.
//  1. Suivi 20/80 (nouvel écran) « Tous » : topN ABSENT, limit 9 999, tous les articles affichés ; retrait = 50 ;
//  3. recherche de produit de l'onglet Analyses : GET /espace-produit/recherche?q= (contient) après l'anti-rebond,
//     rien sous 2 caractères ; au toucher GET /info?search=<CIP> et détail du CIP EXACT ; serveur sans la route (404)
//     → /info (« commence par ») et avertissement ; erreurs (500 de la recherche, 500 du détail, CIP introuvable) ;
//  4. Pointage BL : sans critère, AUCUNE requête et l'explication ; dernier grossiste (ou groupe) repris à
//     l'ouverture suivante (même paramètre envoyé) ; grossiste disparu : oublié sans requête.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_2080_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/recherche_produit_analyses.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();
const route2080 = AppConstants.suivi2080Endpoint;
const routeRecherche = AppConstants.rechercheProduitEndpoint;
const routeInfo = AppConstants.infoEndpoint;

Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> monter(WidgetTester tester, Widget Function() ecran, {Map<String, Object> prefs = const {}}) async {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 6000 * 2.625);
  addTearDown(tester.view.reset);
  preparerTelephone(serveur, nouvelle: true, autres: prefs);
  ApiService.client = serveur.clientMemoire();
  serveur.oublierRequetes();
  await ecranConnecte(ecran)(tester, serveur);
  await pomper(tester);
}

Future<void> demonter(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

Future<void> toucher(WidgetTester tester, Finder f, [int fois = 8]) async {
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(f.first);
  await pomper(tester, fois);
}

Finder cle(String k) => find.byKey(Key(k));

/// Onglet Analyses réduit à sa zone de recherche (les menus sont remplacés par un repère).
Widget ongletRecherche() => const Scaffold(body: RechercheProduitAnalyses(menus: Text('MENUS DE L\'ONGLET', key: Key('menus_onglet'))));

Future<void> saisir(WidgetTester tester, String texte) async {
  await tester.enterText(cle('champ_recherche'), texte);
  await tester.pump(const Duration(milliseconds: 600)); // anti-rebond
  await pomper(tester, 6);
}

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
    donneesLot3(serveur);
  });

  group('1 · Suivi 20/80 « Tous » (nouvel écran)', () {
    String articles() => (find.byKey(const Key('chiffre_articles')).evaluate().single.widget as Text).data!;
    Map<String, String> derniers() => serveur.recues(route2080).last.parametres;

    Future<void> feuille(WidgetTester tester, {required bool tous, String? nombre}) async {
      await toucher(tester, cle('bouton_filtres'), 6);
      final interrupteur = tester.widget<SwitchListTile>(cle('filtre_tous'));
      if (interrupteur.value != tous) await toucher(tester, cle('filtre_tous'), 2);
      if (nombre != null) await tester.enterText(cle('filtre_limite'), nombre);
      await pomper(tester, 2);
      await toucher(tester, cle('filtres_appliquer'));
    }

    testWidgets('Tous : topN absent, limit 9 999, les 120 articles ; étiquette ; retrait = 50 (topN envoyé)', (tester) async {
      await monter(tester, () => const Suivi2080Nouveau());
      expect(derniers()['topN'], '50', reason: 'défaut inchangé');
      await feuille(tester, tous: true);
      expect(derniers().containsKey('topN'), isFalse, reason: 'absent = tous pour le serveur');
      expect(derniers()['limit'], '9999');
      expect(articles(), '${DonneesLot3.articles2080}');
      expect(find.text('Tous les articles'), findsWidgets);
      expect(find.text('Tous demandés'), findsOneWidget);
      // Le champ du nombre est désactivé tant que « Tous » est coché.
      await toucher(tester, cle('bouton_filtres'), 6);
      expect(tester.widget<TextField>(cle('filtre_limite')).enabled, isFalse);
      await toucher(tester, cle('filtres_effacer'), 2);
      expect(tester.widget<SwitchListTile>(cle('filtre_tous')).value, isFalse, reason: '« Effacer » revient à 50');
      await toucher(tester, cle('filtres_appliquer'));
      expect(derniers()['topN'], '50');
      expect(articles(), '50');
      // Tous puis retrait de l'étiquette : 50.
      await feuille(tester, tous: true);
      await toucher(tester, cle('filtres_retirer'));
      expect(derniers()['topN'], '50');
      expect(serveur.recues(route2080), hasLength(5), reason: 'une requête par changement');
      await demonter(tester);
    });

    testWidgets('Tous puis un nombre : topN de nouveau envoyé ; par quantité : Tous garde topN absent + vingtType', (tester) async {
      await monter(tester, () => const Suivi2080Nouveau());
      await feuille(tester, tous: true);
      await toucher(tester, cle('classement_quantite'));
      expect(derniers().containsKey('topN'), isFalse);
      expect(derniers()['vingtType'], 'QTY');
      await feuille(tester, tous: false, nombre: '7');
      expect(derniers()['topN'], '7');
      expect(articles(), '7');
      await demonter(tester);
    });
  });

  group('3 · Recherche de produit « contient » (onglet Analyses)', () {
    testWidgets('vide : menus, aucune requête ; 1 caractère : rien ; « fictif » : /espace-produit/recherche?q=fictif', (tester) async {
      await monter(tester, ongletRecherche);
      expect(cle('menus_onglet'), findsOneWidget);
      expect(serveur.recues(routeRecherche), isEmpty);
      await saisir(tester, 'f');
      expect(serveur.recues(routeRecherche), isEmpty, reason: '2 caractères au moins, comme le serveur');
      expect(find.text('Recherchez un produit'), findsOneWidget);
      await saisir(tester, 'fictif');
      final r = serveur.recues(routeRecherche).single;
      expect(r.parametres, {'q': 'fictif'});
      expect(r.methode, 'GET');
      // « contient » : « FICTIF » au milieu du nom (une recherche « commence par » ne le trouverait pas).
      expect(find.text(DonneesFictives.libelleArticle1), findsOneWidget);
      expect(serveur.recues(routeInfo), isEmpty, reason: 'aucun détail demandé avant le toucher');
      await saisir(tester, '500MG');
      expect(serveur.recues(routeRecherche).last.parametres['q'], '500MG');
      expect(find.text(DonneesFictives.libelleArticle1), findsOneWidget);
      expect(find.text(DonneesFictives.libelleArticle2), findsNothing);
      // Effacer : retour aux menus.
      await toucher(tester, find.byTooltip('Effacer la recherche'));
      expect(cle('menus_onglet'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('toucher un produit : /info?search=<CIP> puis détail du CIP EXACT (même écran qu\'Analyse Article)', (tester) async {
      // /info rend aussi un CIP qui commence pareil : seul le CIP exact est retenu.
      serveur.route(routeInfo, (r) {
        final cip = r.parametres['search'];
        final a = DonneesFictives.articlesAnalyse().first;
        return ReponseFausse.json([
          {...a, 'codeCip': '${cip}9', 'libelle': 'AUTRE ARTICLE FICTIF'},
          {...a, 'codeCip': cip},
        ]);
      }, methode: 'GET');
      await monter(tester, ongletRecherche);
      await saisir(tester, 'cpr');
      await toucher(tester, cle('produit_9990001'));
      expect(serveur.recues(routeInfo).single.parametres, {'search': '9990001'});
      expect(find.byType(DetailAnalyseArticle), findsOneWidget);
      expect(tester.widget<DetailAnalyseArticle>(find.byType(DetailAnalyseArticle)).article.codeCip, '9990001');
      expect(find.text(DonneesFictives.libelleArticle1), findsWidgets);
      await demonter(tester);
    });

    testWidgets('CIP absent de /info : message, pas de détail ; 500 du détail : message ; double appui = une requête', (tester) async {
      serveur.quand(routeInfo, ReponseFausse.json([
        {...DonneesFictives.articlesAnalyse().first, 'codeCip': '99900019'}
      ]), methode: 'GET');
      await monter(tester, ongletRecherche);
      await saisir(tester, 'para');
      await toucher(tester, cle('produit_9990001'));
      expect(find.byType(DetailAnalyseArticle), findsNothing);
      expect(find.text('Analyse introuvable pour le CIP 9990001.'), findsOneWidget);
      serveur.quand(routeInfo, ReponseFausse.erreurServeur().apres(const Duration(milliseconds: 500)), methode: 'GET');
      serveur.oublierRequetes();
      await tester.tap(cle('produit_9990001'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(cle('produit_9990001'));
      await pomper(tester, 10);
      expect(serveur.recues(routeInfo), hasLength(1), reason: 'anti double appui');
      expect(find.textContaining('Erreur du serveur'), findsWidgets);
      expect(find.byType(DetailAnalyseArticle), findsNothing);
      await demonter(tester);
    });

    testWidgets('serveur sans /espace-produit (404) : repli /info (« commence par »), avertissement, détail sans requête', (tester) async {
      serveur.quand(routeRecherche, ReponseFausse.introuvable(), methode: 'GET');
      await monter(tester, ongletRecherche);
      await saisir(tester, 'para');
      expect(serveur.recues(routeRecherche).single.parametres['q'], 'para');
      expect(serveur.recues(routeInfo).single.parametres, {'search': 'para'});
      expect(cle('recherche_produit_commence_par'), findsOneWidget);
      expect(find.text(DonneesFictives.libelleArticle1), findsOneWidget);
      await toucher(tester, cle('produit_9990001'));
      expect(find.byType(DetailAnalyseArticle), findsOneWidget);
      expect(serveur.recues(routeInfo), hasLength(1), reason: 'l\'analyse était déjà lue');
      await demonter(tester);
    });

    testWidgets('500 de la recherche : erreur + Réessayer (même q) ; 50 résultats : « précisez la recherche »', (tester) async {
      serveur.quand(routeRecherche, ReponseFausse.erreurServeur(), methode: 'GET');
      await monter(tester, ongletRecherche);
      await saisir(tester, 'sirop');
      expect(find.byType(EtatErreur), findsOneWidget);
      serveur.route(routeRecherche, (r) {
        final nombreux = [
          for (var i = 0; i < 80; i++)
            {...DonneesFictives.articlesAnalyse().last, 'codeCip': '${7770000 + i}', 'libelle': 'SIROP FICTIF N$i'}
        ];
        return ReponseFausse.json(DonneesFictives.rechercheProduit(r.parametres['q'], articles: nombreux));
      }, methode: 'GET');
      await toucher(tester, find.text('Réessayer'));
      expect(serveur.recues(routeRecherche).last.parametres['q'], 'sirop');
      expect(cle('recherche_produit_limite'), findsOneWidget);
      expect(find.byType(CarteLigne), findsNWidgets(50));
      await demonter(tester);
    });
  });

  group('4 · Pointage BL : grossiste obligatoire, dernier choix repris', () {
    Iterable<RequeteRecue> listes() => serveur.recues(ApiPointage.route);
    setUp(() => listesCommunesVague1(serveur));

    testWidgets('sans critère : aucune requête, explication ; choix d\'un grossiste mémorisé puis repris', (tester) async {
      await monter(tester, () => const PointageBlScreen());
      expect(cle('pointage_pourquoi'), findsOneWidget);
      expect(find.text('Pourquoi ce choix est obligatoire'), findsOneWidget);
      expect(listes(), isEmpty);
      await toucher(tester, cle('pointage_grossiste'));
      await toucher(tester, find.text('GROSSISTE FICTIF').last);
      expect(listes().single.parametres['grossiste'], DonneesVague3.grossiste);
      expect(cle('pointage_pourquoi'), findsNothing);
      expect(cle('pointage_dernier_choix'), findsNothing, reason: 'choisi à la main');
      expect(await DernierCriterePointage.lire(), (DonneesVague3.grossiste, ''));
      await demonter(tester);

      // Ouverture suivante (même appareil) : grossiste repris, requête identique, mention affichée.
      serveur.oublierRequetes();
      await tester.pumpWidget(const SizedBox());
      await ecranConnecte(() => const PointageBlScreen())(tester, serveur);
      await pomper(tester);
      expect(listes().single.parametres, containsPair('grossiste', DonneesVague3.grossiste));
      expect(cle('pointage_dernier_choix'), findsOneWidget);
      expect(cle('pointage_pourquoi'), findsNothing);
      await demonter(tester);
    });

    testWidgets('groupe repris : envoyé dans « groupe », grossiste vide', (tester) async {
      await monter(tester, () => const PointageBlScreen(), prefs: {DernierCriterePointage.cle: 'groupe:${DonneesVague3.groupe}'});
      final p = listes().single.parametres;
      expect(p['groupe'], DonneesVague3.groupe);
      expect(p['grossiste'], '');
      await demonter(tester);
    });

    testWidgets('grossiste repris disparu de la liste : oublié, aucune requête, explication', (tester) async {
      await monter(tester, () => const PointageBlScreen(), prefs: {DernierCriterePointage.cle: 'grossiste:GRO-SUPPRIME'});
      expect(listes(), isEmpty);
      expect(cle('pointage_pourquoi'), findsOneWidget);
      expect(await DernierCriterePointage.lire(), isNull);
      await demonter(tester);
    });
  });
}
