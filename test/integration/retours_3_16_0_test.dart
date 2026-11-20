// Retours du pharmacien pour la 3.16.0, écrans contre le faux serveur (client HTTP en mémoire, horloge simulée,
// données fictives) :
//  2. Analyse Article : recherche LÉGÈRE (/espace-produit/recherche) avec anti-rebond 300 ms, réponse d'une saisie
//     remplacée ignorée, aucune lecture de /info pendant la saisie ; au toucher : /info?search=<CIP exact> une fois,
//     puis cache court (réouverture sans requête) ; replis 404 / 403 → /vente/search ;
//  3. État de stock : 1 ou 2 caractères → aucune requête ; 3 → une ; réponse remplacée jamais affichée ;
//  5. CA crédit : grosse réponse décodée hors du fil de l'interface, liste construite à la demande, recherche
//     calculée une fois par changement (pas à chaque image) ;
//  6. Accueil (tableau de bord) : toutes les cartes demandées EN MÊME TEMPS dès l'ouverture, chacune affichée dès sa
//     réponse (une carte lente ne bloque pas les autres) ; retour sur l'accueil : mémoire, aucune requête ; route
//     absente retenue (repli direct, sans 404 ni /officine) ; carte indisponible non relue avant ⟳.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:provider/provider.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun_lot3.dart' show AffichageParTranches;
import 'package:prestige_app/nouvelle_interface/modules/etat_stock_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot2.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/grandes_donnees.dart';
import '../support/polices.dart';
import 'retours_3_10_0_test.dart' show demonter, pomper, serveur, utilisateurMemorise;

const routeRecherche = AppConstants.rechercheProduitEndpoint;
const routeInfo = AppConstants.infoEndpoint;
const routeVente = '/vente/search';
const routeStock = '/fichearticle/comparaison';

/// Mercredi 21/10/2026.
final maintenant = DateTime(2026, 10, 21, 11, 0);

Finder cle(String k) => find.byKey(Key(k));

/// Écran connecté rendu seul, sur un téléphone de [hauteur] dp (411 dp de large).
Future<void> monterEcran(WidgetTester tester, Widget Function() ecran, {double hauteur = 891}) async {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = Size(411 * 2.625, hauteur * 2.625);
  addTearDown(tester.view.reset);
  preparerTelephone(serveur, nouvelle: true, autres: utilisateurMemorise(recent: true));
  ApiService.client = serveur.clientMemoire();
  serveur.oublierRequetes();
  ProfilAcces.utilisateur.value = AppUser.fromJson(jsonDecode(utilisateurMemorise(recent: true)[AppConstants.userDataKey] as String));
  await ecranConnecte(ecran)(tester, serveur);
  // Réglages (adresse du serveur) relus, comme dans l'application avant la connexion : les clés des caches courts
  // commencent par l'adresse du serveur.
  final ip = Provider.of<IpConfigProvider>(tester.element(find.byType(Scaffold).first), listen: false);
  await tester.runAsync(ip.loadSettings);
  expect(ip.isAppConfigured, isTrue);
  await pomper(tester);
}

Future<void> saisir(WidgetTester tester, String texte, {Duration apres = const Duration(milliseconds: 100)}) async {
  await tester.enterText(cle('champ_recherche'), texte);
  await tester.pump(apres);
}

/// Requêtes reçues sur [chemin] (paramètres).
List<Map<String, String>> recues(String chemin) => [for (final r in serveur.recues(chemin)) r.parametres];

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

  group('2 · Analyse Article', () {
    testWidgets('saisie rapide : UNE recherche légère après 300 ms, aucune /info ; réponse d\'une saisie remplacée ignorée', (tester) async {
      // « par » répond lentement (2 s) avec un produit qui ne doit JAMAIS s'afficher ; « parafictif » répond tout de suite.
      serveur.route(routeRecherche, (r) {
        final q = r.parametres['q'] ?? '';
        if (q == 'par') {
          return ReponseFausse.json({
            'total': 1,
            'data': [
              {'cip': '9990099', 'designation': 'PRODUIT PERIME FICTIF', 'prixVente': 1, 'stockTotal': 1}
            ]
          }).apres(const Duration(seconds: 2));
        }
        return ReponseFausse.json(DonneesFictives.rechercheProduit(q));
      }, methode: 'GET');
      await monterEcran(tester, () => const AnalyseArticleNouveau());
      await saisir(tester, 'p');
      await saisir(tester, 'pa');
      await saisir(tester, 'par', apres: const Duration(milliseconds: 250));
      expect(recues(routeRecherche), isEmpty, reason: 'anti-rebond : rien avant 300 ms');
      await tester.pump(const Duration(milliseconds: 100));
      expect(recues(routeRecherche), [
        {'q': 'par'}
      ], reason: 'une seule requête, pour le dernier texte');
      await saisir(tester, 'parafictif', apres: const Duration(milliseconds: 350));
      await pomper(tester, 5);
      expect(find.text(DonneesFictives.libelleArticle1), findsOneWidget);
      await pomper(tester, 25); // la réponse lente de « par » arrive
      expect(find.text('PRODUIT PERIME FICTIF'), findsNothing, reason: 'réponse d\'une saisie remplacée : ignorée');
      expect(find.text(DonneesFictives.libelleArticle1), findsOneWidget);
      expect(recues(routeInfo), isEmpty, reason: 'aucune analyse complète pendant la saisie');
      expect(tester.takeException(), isNull);
      await demonter(tester);
    });

    testWidgets('toucher : /info?search=<CIP exact> une fois, fiche ; même produit rouvert : cache court, aucune requête', (tester) async {
      await monterEcran(tester, () => const AnalyseArticleNouveau());
      await saisir(tester, 'fictif', apres: const Duration(milliseconds: 350));
      await pomper(tester, 5);
      expect(find.text(DonneesFictives.libelleArticle1), findsOneWidget);
      await tester.tap(find.text(DonneesFictives.libelleArticle1));
      await pomper(tester, 5);
      expect(find.byType(DetailAnalyseArticle), findsOneWidget);
      expect(recues(routeInfo), [
        {'search': '9990001'}
      ]);
      expect(tester.widget<DetailAnalyseArticle>(find.byType(DetailAnalyseArticle)).article.codeCip, '9990001', reason: 'la ligne au CIP exact');
      Navigator.of(tester.element(find.byType(DetailAnalyseArticle))).pop();
      await pomper(tester, 5);
      await tester.tap(find.text(DonneesFictives.libelleArticle1));
      await pomper(tester, 5);
      expect(find.byType(DetailAnalyseArticle), findsOneWidget);
      expect(recues(routeInfo), hasLength(1), reason: 'réouverture : cache court');
      Navigator.of(tester.element(find.byType(DetailAnalyseArticle))).pop();
      await pomper(tester, 3);
      // Même saisie retapée : la liste vient du cache court.
      final avant = recues(routeRecherche).length;
      await saisir(tester, 'fictif2', apres: const Duration(milliseconds: 350));
      await saisir(tester, 'fictif', apres: const Duration(milliseconds: 350));
      await pomper(tester, 3);
      expect(recues(routeRecherche), hasLength(avant + 1), reason: '« fictif2 » seulement ; « fictif » déjà lu');
      await demonter(tester);
    });

    for (final (cas, reponse) in [('404', ReponseFausse.introuvable()), ('403', ReponseFausse.json({'success': false}, statut: 403))]) {
      testWidgets('/espace-produit/recherche en $cas : repli /vente/search (start 0, limit 30), sans /info ; toucher → /info au CIP', (tester) async {
        serveur.quand(routeRecherche, reponse, methode: 'GET');
        serveur.route(routeVente, (r) {
          final q = (r.parametres['query'] ?? '').toLowerCase();
          return ReponseFausse.json({
            'total': 2,
            'data': [
              for (final a in DonneesFictives.articlesAnalyse())
                if ('${a['libelle']}'.toLowerCase().contains(q))
                  {'lgFAMILLEID': a['produitId'], 'intCIP': a['codeCip'], 'strNAME': a['libelle'], 'strLIBELLEE': 'RAYON A', 'intPRICE': a['prixVente'], 'intNUMBERAVAILABLE': a['stock']},
            ]
          });
        }, methode: 'GET');
        await monterEcran(tester, () => const AnalyseArticleNouveau());
        await saisir(tester, 'parafictif', apres: const Duration(milliseconds: 350));
        await pomper(tester, 10);
        expect(recues(routeVente), [
          {'query': 'parafictif', 'start': '0', 'limit': '30'}
        ]);
        expect(recues(routeInfo), isEmpty);
        expect(find.text(DonneesFictives.libelleArticle1), findsOneWidget);
        await tester.tap(find.text(DonneesFictives.libelleArticle1));
        await pomper(tester, 5);
        expect(recues(routeInfo), [
          {'search': '9990001'}
        ]);
        expect(find.byType(DetailAnalyseArticle), findsOneWidget);
        await demonter(tester);
      });
    }
  });

  group('3 · État de stock', () {
    testWidgets('1 ou 2 caractères : aucune requête, message ; 3 : une requête après 300 ms ; réponse remplacée jamais affichée', (tester) async {
      donneesLot2(serveur);
      await monterEcran(tester, () => const EtatStockNouveau());
      serveur.oublierRequetes();
      await saisir(tester, 'a', apres: const Duration(milliseconds: 400));
      await saisir(tester, 'ar', apres: const Duration(milliseconds: 400));
      await pomper(tester, 3);
      expect(recues(routeStock), isEmpty, reason: '1 ou 2 caractères : rien n\'est envoyé');
      expect(cle('etat_stock_trop_court'), findsOneWidget);
      // « art » répond lentement avec un article qui ne doit jamais s'afficher ; « artic » répond tout de suite.
      serveur.route(routeStock, (r) {
        if (r.parametres['query'] == 'art') {
          return ReponseFausse.json({
            'total': 1,
            'data': [
              {'id': 'X', 'code': '3400000099999', 'libelle': 'ARTICLE PERIME FICTIF', 'stock': 1, 'prixAchat': 1, 'prixVente': 2}
            ]
          }).apres(const Duration(seconds: 2));
        }
        return DonneesLot2.comparaison(r);
      }, methode: 'GET');
      await saisir(tester, 'art', apres: const Duration(milliseconds: 250));
      expect(recues(routeStock), isEmpty, reason: 'anti-rebond 300 ms');
      await tester.pump(const Duration(milliseconds: 100));
      expect(recues(routeStock).single['query'], 'art');
      await saisir(tester, 'artic', apres: const Duration(milliseconds: 350));
      await pomper(tester, 30);
      expect(recues(routeStock).map((p) => p['query']), ['art', 'artic']);
      expect(find.text('ARTICLE PERIME FICTIF'), findsNothing, reason: 'réponse d\'une recherche remplacée : ignorée');
      expect(find.textContaining('ARTICLE FICTIF'), findsWidgets);
      // Retour à 2 caractères : la recherche affichée disparaît, rien n'est envoyé.
      await saisir(tester, 'ar', apres: const Duration(milliseconds: 400));
      await pomper(tester, 3);
      expect(recues(routeStock), hasLength(2));
      expect(cle('etat_stock_trop_court'), findsOneWidget);
      await demonter(tester);
    });
  });

  group('5 · CA crédit', () {
    testWidgets('1 500 ventes (> 256 Ko) : décodées hors du fil de l\'interface, affichées ; cartes construites à la demande ; '
        'recherche calculée une fois par changement', (tester) async {
      donneesLot3(serveur);
      final ventes = GrandesDonnees.caCredit(1500);
      expect(utf8.encode(jsonEncode(ventes)).length, greaterThan(ApiService.seuilDecodageIsole), reason: 'réponse assez grosse pour l\'isolat');
      serveur.quand('/ca-credit', ReponseFausse.json(ventes), methode: 'GET');
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      expect(recues('/ca-credit'), hasLength(1));
      final ventesAffichees = tester.widget<ChiffreCle>(find.byWidgetPredicate((w) => w is ChiffreCle && w.id == 'ventes'));
      expect(ventesAffichees.valeur.replaceAll(RegExp(r'\D'), ''), '1500');
      final construites = find.byType(CarteLigne, skipOffstage: false).evaluate().length;
      expect(construites, lessThan(AffichageParTranches.tranche), reason: 'liste construite à la demande ($construites cartes construites)');
      // Défilement et images : la recherche n'est pas refaite.
      final calculs = VueCaCredit.calculs;
      await tester.drag(cle('defilement_module'), const Offset(0, -1500));
      await pomper(tester, 3);
      expect(VueCaCredit.calculs, calculs, reason: 'aucun recalcul au défilement');
      // Une recherche : un seul calcul (après l'anti-rebond).
      await tester.drag(cle('defilement_module'), const Offset(0, 3000));
      await pomper(tester, 2);
      await tester.enterText(cle('champ_recherche'), 'FAC-P-1499');
      await tester.pump(const Duration(milliseconds: 600));
      await pomper(tester, 3);
      expect(VueCaCredit.calculs, calculs + 1);
      expect(find.text('CLIENT FICTIF ${1499 % 120}'), findsWidgets);
      expect(recues('/ca-credit'), hasLength(1), reason: 'recherche locale : aucune requête');
      expect(tester.takeException(), isNull);
      await demonter(tester);
    });
  });

  group('6 · Accueil (tableau de bord)', () {
    const routesCartes = {
      '/tableau-bord/tuiles', '/ws/ca-achats-ventes', '/pilotage/suivi/frequentation', '/tableau-bord/affluence', '/tableau-bord/valorisation',
      '/tableau-bord/encaissements', '/tableau-bord/emplacements', '/tvas',
    };
    Set<String> cheminsCartes() => {for (final r in serveur.requetes) if (routesCartes.contains(r.chemin)) r.chemin};
    int requetesCartes() => serveur.requetes.where((r) => routesCartes.contains(r.chemin) || r.chemin == '/recap/dashboard/daily').length;

    /// Accueil affiché / masqué (comme un changement d'onglet) avec la même mémoire. Masqué au lancement : il
    /// s'affiche une fois l'application prête (adresse du serveur relue), comme après la connexion.
    Widget accueil(ValueNotifier<bool> visible, MemoireTableauBord memoire) => ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, v, __) =>
              Scaffold(body: v ? AccueilTableauPrestige(maintenant: () => maintenant, memoire: memoire) : const Center(child: Text('Autre onglet'))),
        );

    testWidgets('ouverture : les 8 cartes demandées EN MÊME TEMPS (même celles sous l\'écran) ; une carte lente ne bloque pas les autres', (tester) async {
      donneesLot3(serveur);
      // Chiffres du jour : 1 s ; TVA : 10 s (calcul lent du serveur).
      serveur
        ..quand('/tableau-bord/tuiles', ReponseFausse.json(DonneesVague4.tuiles()).apres(const Duration(seconds: 1)), methode: 'GET')
        ..route('/tvas', (r) => ReponseFausse.json(DonneesLot3.statTva(r.parametres['typeVente'] ?? 'TOUT')).apres(const Duration(seconds: 10)), methode: 'GET');
      final memoire = MemoireTableauBord();
      final visible = ValueNotifier(false);
      await monterEcran(tester, () => accueil(visible, memoire));
      serveur.oublierRequetes();
      visible.value = true;
      await tester.pump();
      await tester.pump();
      // Sans défiler, dès la première image : toutes les cartes sont parties (même celles sous l'écran), une fois chacune.
      expect(cheminsCartes(), routesCartes, reason: 'lectures en parallèle dès l\'ouverture');
      expect(requetesCartes(), 8, reason: 'une requête par carte, aucune en double');
      expect(cle('chiffre_tb_ca'), findsNothing, reason: 'squelette : chiffres pas encore arrivés');
      await pomper(tester, 15);
      expect(cle('chiffre_tb_ca'), findsOneWidget, reason: 'chiffres affichés pendant que la TVA calcule encore');
      final liste = find.descendant(of: cle('defilement_tableau_bord'), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(cle('carte_tableau_bord_tva'), 300, scrollable: liste, maxScrolls: 40);
      await tester.pump();
      expect(find.descendant(of: cle('carte_tableau_bord_tva'), matching: find.byType(LinearProgressIndicator)), findsOneWidget,
          reason: 'TVA encore en calcul');
      await pomper(tester, 100);
      // La carte TVA attendait la réponse déjà en route : aucune nouvelle requête.
      expect(find.descendant(of: cle('carte_tableau_bord_tva'), matching: find.byType(LinearProgressIndicator)), findsNothing);
      expect(requetesCartes(), 8);
      expect(tester.takeException(), isNull);
      await demonter(tester);
    });

    testWidgets('retour sur l\'accueil (mémoire, < 2 min) : tout affiché sans requête ; ⟳ : tout relu', (tester) async {
      donneesLot3(serveur);
      final memoire = MemoireTableauBord();
      final visible = ValueNotifier(false);
      await monterEcran(tester, () => accueil(visible, memoire), hauteur: 3000);
      serveur.oublierRequetes();
      visible.value = true;
      await pomper(tester, 10);
      expect(requetesCartes(), 8);
      visible.value = false;
      await pomper(tester, 3);
      serveur.oublierRequetes();
      visible.value = true;
      await tester.pump();
      await tester.pump();
      expect(cle('chiffre_tb_ca'), findsOneWidget, reason: 'affiché tout de suite');
      await pomper(tester, 10);
      expect(requetesCartes(), 0, reason: 'retour sur l\'accueil : mémoire');
      await tester.tap(cle('tableau_bord_actualiser'));
      await pomper(tester, 10);
      expect(requetesCartes(), 8, reason: '⟳ : une relecture par carte');
      expect(serveur.recues('/tableau-bord/affluence').single.parametres['frais'], '1');
      await demonter(tester);
    });

    testWidgets('route absente retenue : tuiles 404 → /recap/dashboard/daily, puis repli direct (ni 404 ni /officine) ; carte indisponible non relue',
        (tester) async {
      donneesLot3(serveur);
      serveur
        ..quand('/tableau-bord/tuiles', ReponseFausse.introuvable(), methode: 'GET')
        ..quand('/pilotage/suivi/frequentation', ReponseFausse.json({'success': false}, statut: 403), methode: 'GET')
        ..quand('/tableau-bord/encaissements', ReponseFausse.introuvable(), methode: 'GET');
      var t = DateTime(2026, 10, 21, 11);
      final memoire = MemoireTableauBord(horloge: () => t);
      final visible = ValueNotifier(false);
      await monterEcran(tester, () => accueil(visible, memoire), hauteur: 3000);
      serveur.oublierRequetes();
      visible.value = true;
      await pomper(tester, 15);
      expect(serveur.recues('/tableau-bord/tuiles'), hasLength(1));
      expect(serveur.recues('/recap/dashboard/daily'), hasLength(1));
      expect(serveur.recues('/tableau-bord/frequentation'), hasLength(1), reason: '403 du pilotage → fréquentation du tableau de bord');
      expect(find.descendant(of: cle('carte_tableau_bord_encaissements'), matching: cle('carte_indisponible')), findsOneWidget);
      expect(cle('chiffre_tb_ca'), findsOneWidget);
      // Plus de 2 minutes plus tard : la mémoire des cartes a expiré, celle des routes non.
      visible.value = false;
      await pomper(tester, 2);
      t = t.add(const Duration(minutes: 3));
      serveur.oublierRequetes();
      visible.value = true;
      await pomper(tester, 15);
      expect(serveur.recues('/tableau-bord/tuiles'), isEmpty, reason: 'route absente retenue');
      expect(serveur.recues('/officine'), isEmpty, reason: 'aucune vérification après un 404');
      expect(serveur.recues('/recap/dashboard/daily'), hasLength(1));
      expect(serveur.recues('/pilotage/suivi/frequentation'), isEmpty);
      expect(serveur.recues('/tableau-bord/frequentation'), hasLength(1));
      expect(serveur.recues('/tableau-bord/encaissements'), isEmpty, reason: 'carte indisponible : pas relue avant ⟳');
      expect(find.descendant(of: cle('carte_tableau_bord_encaissements'), matching: cle('carte_indisponible')), findsOneWidget);
      expect(cle('chiffre_tb_ca'), findsOneWidget);
      await demonter(tester);
    });
  });
}
