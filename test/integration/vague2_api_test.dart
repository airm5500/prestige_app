// Intégration de la vague 2 (lib/nouvelle_interface/vague2/) contre le faux serveur Prestige joint en HTTP RÉEL,
// avec la session de la connexion :
//  - routes et paramètres exacts des quatre menus (Prévisions, Pilotage, Analyse de garde, CA emplacement / famille) ;
//  - succès, liste vide, success:false (droit / calcul en échec / refus métier), interdit:true, 403, 401 (retour à la
//    connexion par le mécanisme existant), 500, délai borné (45 s ; 2 min pour les calculs longs demandés) ;
//  - AUCUNE route interdite (écritures, recalculs, créations) jamais appelée ; /pilotage/controler appelé SEULEMENT
//    après confirmation du bouton « Contrôler les chiffres », une fois par appui.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/pilotage_vague2.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/services/api_service.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague2.dart';
import '../support/faux_serveur_prestige.dart';

final serveur = FauxServeurPrestige();

typedef App = ({BuildContext ctx, AuthProvider auth});

Future<App> connecte(WidgetTester tester) async {
  final auth = AuthProvider();
  final ctx = await monterAvecProviders(tester, auth: auth, licence: LicenceProvider());
  await tester.runAsync(() => auth.login(ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false));
  await tester.pump();
  expect(auth.isLoggedIn, isTrue);
  serveur.oublierRequetes();
  return (ctx: ctx, auth: auth);
}

Future<(T?, Object?)> essayer<T>(WidgetTester tester, Future<T> Function() appel) async {
  T? r;
  Object? e;
  await tester.runAsync(() async {
    try {
      r = await appel();
    } catch (x) {
      e = x;
    }
  });
  await tester.pump();
  return (r, e);
}

Matcher nature(NatureErreur n) => isA<ApiLoadException>().having((e) => e.nature, 'nature', n);

void main() {
  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerTelephone(serveur, nouvelle: true);
    listesCommunesVague1(serveur);
    await ApiService().clearSessionCookie();
  });

  tearDown(() async {
    expect(requetesInterdites(serveur), isEmpty, reason: 'aucune route interdite ne doit être appelée');
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..reponseSansSession = ((_) => ReponseFausse.sessionExpiree())
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
  });

  group('Prévisions', () {
    testWidgets('tableau puis prévisions (page 1, filtre, recherche) puis page 2 start=25, avec la session', (tester) async {
      final app = await connecte(tester);
      final (t, _) = await essayer(tester, () => ApiPrevisions.tableau(app.ctx));
      expect(t!.aCommander, 42);
      expect(serveur.recues(ApiPrevisions.routeTableau).single.sessionEnvoyee, serveur.derniereSession);
      final (p, _) = await essayer(tester, () => ApiPrevisions.previsions(app.ctx, const FiltresPrevisions()));
      expect(p!.lignes, hasLength(25));
      expect(p.total, DonneesVague2.nombrePrevisions);
      expect(serveur.recues(ApiPrevisions.routePrevisions).single.parametres,
          {'filtre': '', 'query': '', 'methode': '', 'stock': '', 'start': '0', 'limit': '25'});
      final (p2, _) = await essayer(tester, () => ApiPrevisions.previsions(app.ctx, const FiltresPrevisions(), start: 25));
      expect(p2!.lignes, hasLength(5));
      expect(serveur.recues(ApiPrevisions.routePrevisions).last.parametres['start'], '25');
      final (f, _) = await essayer(
          tester, () => ApiPrevisions.previsions(app.ctx, const FiltresPrevisions(filtre: FiltrePrevision.aCommander, stock: StockPrevision.enStock, recherche: 'fictif 1')));
      expect(serveur.recues(ApiPrevisions.routePrevisions).last.parametres,
          {'filtre': 'ACOMMANDER', 'query': 'fictif 1', 'methode': '', 'stock': 'EN_STOCK', 'start': '0', 'limit': '25'});
      expect(f!.lignes.every((l) => l.recommande > 0), isTrue);
    });

    testWidgets('détail produit et équivalents ; suggestion à analyser puis analyse type / id', (tester) async {
      final app = await connecte(tester);
      final (d, _) = await essayer(tester, () => ApiPrevisions.produit(app.ctx, 'PRD-PREV-2'));
      expect(d!.historique, hasLength(6));
      expect(serveur.recues('/analyse-commande/produit/PRD-PREV-2'), hasLength(1));
      final (e, _) = await essayer(tester, () => ApiPrevisions.equivalents(app.ctx, 'PRD-PREV-2'));
      expect(e!.lignes.first.direct, isTrue);
      final (l, _) = await essayer(tester, () => ApiPrevisions.aAnalyser(app.ctx));
      expect(l!.map((x) => x.type), ['SUGGESTION', 'COMMANDE']);
      final (a, _) = await essayer(tester, () => ApiPrevisions.analyse(app.ctx, l[1]));
      expect(serveur.recues(ApiPrevisions.routeAnalyse).single.parametres, {'type': 'COMMANDE', 'id': 'CMD-TEST-1'});
      expect(a!.lignesAlerte, 2);
    });

    testWidgets('produit inexistant (success:false « Pas de prévision… ») : demande refusée avec le message, pas un droit', (tester) async {
      final app = await connecte(tester);
      serveur.quand('/analyse-commande/produit/X',
          ReponseFausse.json({'success': false, 'message': 'Pas de prévision pour ce produit (jamais vendu ni en stock, ou calcul pas encore fait).'}));
      final (_, e) = await essayer(tester, () => ApiPrevisions.produit(app.ctx, 'X'));
      expect(e, nature(NatureErreur.refus));
      expect('$e', isNot(contains('Droit manquant')));
    });

    testWidgets('demande : mois=12 par défaut, rayon et recherche transmis ; 36 mois attend jusqu\'à 2 min (borné)', (tester) async {
      final app = await connecte(tester);
      final (d, _) = await essayer(tester, () => ApiPrevisions.demande(app.ctx, mois: 12, rayonId: 'ZONE-TEST-1', recherche: 'sirop'));
      expect(serveur.recues(ApiPrevisions.routeDemande).single.parametres, {'mois': '12', 'query': 'sirop', 'rayonId': 'ZONE-TEST-1'});
      expect(d!.pic, 12);
      serveur.quand(ApiPrevisions.routeDemande, ReponseFausse.sansReponse());
      Object? erreur;
      () async {
        try {
          await ApiPrevisions.demande(app.ctx, mois: 36);
        } catch (e) {
          erreur = e;
        }
      }();
      await stabiliser(tester, tours: 4);
      await tester.pump(ApiService.delaiGet + const Duration(seconds: 5));
      await tester.pump();
      expect(erreur, isNull, reason: 'calcul long : pas d\'échec à 45 s');
      await tester.pump(ApiVague2.delaiLong);
      await tester.pump();
      expect(erreur, nature(NatureErreur.delai));
      expect(app.auth.isLoggedIn, isTrue);
    });

    testWidgets('refus du serveur (« Vous n\'avez pas accès… ») → Droit manquant, sans déconnexion', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiPrevisions.routeTableau, ReponseFausse.json({'success': false, 'msg': 'Vous n\'avez pas accès à l\'analyse des commandes.'}));
      final (_, e) = await essayer(tester, () => ApiPrevisions.tableau(app.ctx));
      expect(e, nature(NatureErreur.droit));
      expect('$e', startsWith('Droit manquant : consulter les prévisions.'));
      expect(app.auth.isLoggedIn, isTrue);
    });
  });

  group('Pilotage', () {
    testWidgets('axes, synthèse (axe=MOIS), à suivre ; période personnalisée avec dates', (tester) async {
      final app = await connecte(tester);
      final (axes, _) = await essayer(tester, () => ApiPilotage.axes(app.ctx));
      expect(axes!.map((a) => a.code), ['MOIS', 'VS_M1', 'VS_N1', 'YTD', 'G12', 'PERSO']);
      final (s, _) = await essayer(tester, () => ApiPilotage.onglet(app.ctx, OngletPilotage.synthese, ChoixAxe(axes.first)));
      expect(serveur.recues('/pilotage/onglet/synthese').single.parametres, {'axe': 'MOIS'});
      expect(s!.tuiles.first.valeur, DonneesVague2.caPilotage);
      final (v, _) = await essayer(tester, () => ApiPilotage.onglet(app.ctx, OngletPilotage.aSuivre, ChoixAxe(axes[1])));
      expect(serveur.recues('/pilotage/onglet/asuivre').single.parametres, {'axe': 'VS_M1'});
      expect(v!.alertes, hasLength(2));
      final perso = ChoixAxe(axes.last, debut: DateTime(2026, 9, 1), fin: DateTime(2026, 9, 30));
      await essayer(tester, () => ApiPilotage.onglet(app.ctx, OngletPilotage.synthese, perso, maintenant: DateTime(2026, 10, 14)));
      expect(serveur.recues('/pilotage/onglet/synthese').last.parametres, {'axe': 'PERSO', 'dtStart': '2026-09-01', 'dtEnd': '2026-09-30'});
      // Période personnalisée incorrecte : refusée par l'application, aucune requête.
      final avant = serveur.requetes.length;
      final (_, e) = await essayer(tester,
          () => ApiPilotage.onglet(app.ctx, OngletPilotage.synthese, ChoixAxe(axes.last, debut: DateTime(2026, 9, 30), fin: DateTime(2026, 9, 1))));
      expect(e, nature(NatureErreur.refus));
      expect(serveur.requetes.length, avant);
      expect(serveur.recues(ApiPilotage.routeControler), isEmpty, reason: 'lire les chiffres ne contrôle rien');
    });

    testWidgets('droit P_SM_PILOTAGE refusé → Droit manquant ; calcul en échec → erreur du serveur', (tester) async {
      final app = await connecte(tester);
      serveur.quand('/pilotage/onglet/synthese',
          ReponseFausse.json({'success': false, 'total': 0, 'message': 'Votre profil ne donne pas accès au pilotage de l\'officine.'}));
      final (_, e) = await essayer(tester, () => ApiPilotage.onglet(app.ctx, OngletPilotage.synthese, const ChoixAxe(AxePilotage('MOIS', ''))));
      expect(e, nature(NatureErreur.droit));
      serveur.quand('/pilotage/onglet/synthese', ReponseFausse.json({'success': false, 'message': 'Les chiffres n\'ont pas pu être rassemblés.'}));
      final (_, e2) = await essayer(tester, () => ApiPilotage.onglet(app.ctx, OngletPilotage.synthese, const ChoixAxe(AxePilotage('MOIS', ''))));
      expect(e2, nature(NatureErreur.serveur));
      expect(app.auth.isLoggedIn, isTrue);
    });

    testWidgets('onglet Pilotage : AUCUN contrôle à l\'ouverture ; « Contrôler » → confirmation ; Annuler → rien ; Contrôler → UN appel',
        (tester) async {
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
      addTearDown(tester.view.reset);
      final app = await connecte(tester);
      serveur.quand(ApiPilotage.routeControler, ReponseFausse.json({'success': true, 'repris': 2}).apres(const Duration(milliseconds: 400)));
      Navigator.of(app.ctx).push(MaterialPageRoute(builder: (_) => const Scaffold(body: OngletPilotageAccueil())));
      await attendreWidget(tester, find.byKey(const Key('tuile_caTTC')));
      expect(serveur.recues('/pilotage/onglet/synthese'), hasLength(1));
      expect(serveur.recues('/pilotage/axes'), hasLength(1));
      expect(serveur.recues(ApiPilotage.routeControler), isEmpty, reason: 'jamais à l\'ouverture (le web, lui, le fait)');

      // Annuler : aucun appel.
      await tester.ensureVisible(find.byKey(const Key('pilotage_controler')));
      await tester.tap(find.byKey(const Key('pilotage_controler')));
      await stabiliser(tester, tours: 6);
      expect(find.text('Contrôler les chiffres'), findsWidgets);
      expect(find.textContaining('peut prendre du temps'), findsOneWidget);
      await tester.tap(find.byKey(const Key('controle_annuler')));
      await stabiliser(tester, tours: 6);
      expect(serveur.recues(ApiPilotage.routeControler), isEmpty);

      // Confirmer : un appel ; un second appui pendant le contrôle est ignoré (bouton désactivé).
      await tester.tap(find.byKey(const Key('pilotage_controler')));
      await stabiliser(tester, tours: 6);
      await tester.tap(find.byKey(const Key('controle_confirmer')));
      await stabiliser(tester, tours: 3);
      await tester.tap(find.byKey(const Key('pilotage_controler')), warnIfMissed: false);
      await stabiliser(tester, tours: 3);
      expect(find.byKey(const Key('controle_confirmer')), findsNothing, reason: 'pas de seconde confirmation pendant le contrôle');
      await attendreWidget(tester, find.byKey(const Key('controle_resultat')));
      expect(find.text('2 mois recalculés : chiffres mis à jour.'), findsOneWidget);
      final c = serveur.recues(ApiPilotage.routeControler).single;
      expect(c.parametres, {'axe': 'MOIS'});
      expect(c.methode, 'GET');
      await attendreQue(tester, () => serveur.recues('/pilotage/onglet/synthese').length == 2, raison: 'chiffres relus après le contrôle');
      await terminer(tester);
    });

    testWidgets('contrôle : délai long borné (2 min) ; échec affiché sans déconnexion', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiPilotage.routeControler, ReponseFausse.sansReponse());
      Object? erreur;
      () async {
        try {
          await ApiPilotage.controler(app.ctx, const ChoixAxe(AxePilotage('MOIS', '')));
        } catch (e) {
          erreur = e;
        }
      }();
      await stabiliser(tester, tours: 4);
      await tester.pump(ApiService.delaiGet + const Duration(seconds: 1));
      expect(erreur, isNull);
      await tester.pump(ApiVague2.delaiLong);
      await tester.pump();
      expect(erreur, nature(NatureErreur.delai));
      expect(app.auth.isLoggedIn, isTrue);
    });
  });

  group('Analyse de garde', () {
    testWidgets('années, gardes de l\'année, rapport (heures, tri, classe, page), vendeurs', (tester) async {
      final app = await connecte(tester);
      final (a, _) = await essayer(tester, () => ApiGardes.annees(app.ctx));
      expect(a, [2026, 2025]);
      final (g, _) = await essayer(tester, () => ApiGardes.gardes(app.ctx, 2026));
      expect(serveur.recues(ApiGardes.routeGardes).single.parametres, {'annee': '2026'});
      expect(g!.first.id, 'GARDE-TEST-1');
      final (r, _) = await essayer(tester, () => ApiGardes.rapport(app.ctx, 'GARDE-TEST-1'));
      expect(serveur.recues('/gardes/GARDE-TEST-1/rapport').single.parametres,
          {'heures': '2', 'tri': 'montant', 'classe': '', 'start': '0', 'limit': '${ApiGardes.taillePage}'});
      expect(ApiGardes.taillePage, 100, reason: 'pages de 100 : moins de recalculs du serveur');
      expect(r!.abc, hasLength(100));
      final (r2, _) = await essayer(tester, () => ApiGardes.rapport(app.ctx, 'GARDE-TEST-1', heures: 1, tri: TriGarde.quantite, classe: 'A', start: 0));
      expect(serveur.recues('/gardes/GARDE-TEST-1/rapport').last.parametres['classe'], 'A');
      expect(r2!.abc.every((p) => p.classe == 'A'), isTrue);
      final (v, _) = await essayer(tester, () => ApiGardes.vendeurs(app.ctx, 'GARDE-TEST-1'));
      expect(v!.first.part, 63.4);
      final (_, e) = await essayer(tester, () => ApiGardes.gardes(app.ctx, 1999));
      expect(e, nature(NatureErreur.refus), reason: 'année contrôlée, aucune requête');
    });

    testWidgets('garde supprimée entre-temps (success:false) : message du serveur ; liste vide ≠ erreur', (tester) async {
      final app = await connecte(tester);
      serveur.quand('/gardes/GARDE-TEST-2/rapport', ReponseFausse.json({'success': false, 'msg': 'Cette garde n\'existe plus.'}));
      final (_, e) = await essayer(tester, () => ApiGardes.rapport(app.ctx, 'GARDE-TEST-2'));
      expect(e, nature(NatureErreur.refus));
      expect('$e', 'Cette garde n\'existe plus.');
      serveur.quand(ApiGardes.routeGardes, ReponseFausse.json({'success': true, 'total': 0, 'data': <Object>[]}));
      final (g, e2) = await essayer(tester, () => ApiGardes.gardes(app.ctx, 2026));
      expect(e2, isNull);
      expect(g, isEmpty);
    });
  });

  group('CA emplacement / famille', () {
    testWidgets('comparatif : paramètres exacts, colonnes dynamiques ; détail d\'une ligne', (tester) async {
      final app = await connecte(tester);
      const f = FiltresCa(regroupement: RegroupementCa.zone, grossistes: ['GRO-TEST-1']);
      final (c, _) = await essayer(tester, () => ApiCaZone.comparatif(app.ctx, f));
      expect(serveur.recues(ApiCaZone.route).single.parametres,
          {'typePeriode': 'TROIS_SEMAINES', 'regroupement': 'ZONE', 'zoneId': '', 'familleId': '', 'grossisteId': 'GRO-TEST-1'});
      expect(c!.tranches, hasLength(4));
      expect(c.lignes.first.de('2026-W42').montant, 130000);
      final (d, _) = await essayer(tester, () => ApiCaZone.detail(app.ctx, f, c.lignes.first));
      expect(serveur.recues(ApiCaZone.routeDetail).single.parametres['ligneZoneId'], 'ZONE-TEST-1');
      expect(d!.montant, 90000);
    });

    testWidgets('3 ans : choix normal, délai long (2 min) borné ; période libre incorrecte refusée sans requête', (tester) async {
      final app = await connecte(tester);
      final (c, _) = await essayer(tester, () => ApiCaZone.comparatif(app.ctx, const FiltresCa(type: TypePeriodeCa.troisAns)));
      expect(serveur.recues(ApiCaZone.route).single.parametres['typePeriode'], 'TROIS_ANS');
      expect(c!.tranches.map((t) => t.cle), ['2023', '2024', '2025', '2026']);
      final avant = serveur.requetes.length;
      final (_, e) = await essayer(tester,
          () => ApiCaZone.comparatif(app.ctx, FiltresCa(type: TypePeriodeCa.libre, debut: DateTime.now(), fin: DateTime.now().add(const Duration(days: 2)))));
      expect(e, nature(NatureErreur.refus));
      expect(serveur.requetes.length, avant);
      serveur.quand(ApiCaZone.route, ReponseFausse.sansReponse());
      Object? erreur;
      () async {
        try {
          await ApiCaZone.comparatif(app.ctx, const FiltresCa(type: TypePeriodeCa.troisAns));
        } catch (x) {
          erreur = x;
        }
      }();
      await stabiliser(tester, tours: 4);
      await tester.pump(ApiService.delaiGet + const Duration(seconds: 1));
      expect(erreur, isNull);
      await tester.pump(ApiVague2.delaiLong);
      await tester.pump();
      expect(erreur, nature(NatureErreur.delai));
    });

    testWidgets('calcul en échec (« … a échoué ») → erreur du serveur ; 3 semaines : délai normal (45 s)', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiCaZone.route, ReponseFausse.json({'success': false, 'msg': 'Le calcul du chiffre d\'affaires a échoué', 'data': <Object>[]}));
      final (_, e) = await essayer(tester, () => ApiCaZone.comparatif(app.ctx, const FiltresCa()));
      expect(e, nature(NatureErreur.serveur));
      serveur.quand(ApiCaZone.route, ReponseFausse.sansReponse());
      Object? erreur;
      () async {
        try {
          await ApiCaZone.comparatif(app.ctx, const FiltresCa());
        } catch (x) {
          erreur = x;
        }
      }();
      await stabiliser(tester, tours: 4);
      await tester.pump(ApiService.delaiGet + const Duration(seconds: 1));
      await tester.pump();
      expect(erreur, nature(NatureErreur.delai));
    });
  });

  group('Communs aux 4 menus', () {
    testWidgets('401 : session expirée → retour à la connexion ; 500 : erreur du serveur ; 403 et interdit:true : Droit manquant', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiGardes.routeAnnees, ReponseFausse.erreurServeur());
      final (_, e500) = await essayer(tester, () => ApiGardes.annees(app.ctx));
      expect(e500, nature(NatureErreur.serveur));
      expect('$e500', isNot(contains('NullPointer')));
      serveur.quand(ApiPilotage.routeAxes, ReponseFausse.json({'success': false}, statut: 403));
      final (_, e403) = await essayer(tester, () => ApiPilotage.axes(app.ctx));
      expect(e403, nature(NatureErreur.droit));
      expect('$e403', startsWith('Droit manquant : consulter le pilotage.'));
      serveur.quand(ApiCaZone.route, ReponseFausse.json({'interdit': true}));
      final (_, ei) = await essayer(tester, () => ApiCaZone.comparatif(app.ctx, const FiltresCa()));
      expect(ei, nature(NatureErreur.droit));
      expect(app.auth.isLoggedIn, isTrue);
      final messages = <String>[];
      final abo = app.auth.events.listen(messages.add);
      serveur.expirerSessions();
      final (_, e401) = await essayer(tester, () => ApiPrevisions.tableau(app.ctx));
      expect(e401, nature(NatureErreur.session));
      expect(app.auth.isLoggedIn, isFalse);
      expect(messages, [AuthProvider.messageSessionExpiree]);
      abo.cancel();
    });

    testWidgets('serveur arrêté : serveur injoignable (distinct du délai)', (tester) async {
      final app = await connecte(tester);
      await tester.runAsync(serveur.arreter);
      final (_, e) = await essayer(tester, () => ApiGardes.annees(app.ctx));
      expect(e, nature(NatureErreur.reseau));
    });

    testWidgets('route interdite : refusée par l\'application, AUCUNE requête envoyée', (tester) async {
      final app = await connecte(tester);
      for (final r in routesInterditesTestees) {
        final (_, e) = await essayer(tester, () => ApiVague2.get(app.ctx, r, const {}, 'x'));
        expect(e, nature(NatureErreur.refus), reason: r);
      }
      expect(serveur.requetes, isEmpty);
    });
  });
}
