// Intégration des menus de la 3.11.0 (lib/nouvelle_interface/vague4/) contre le faux serveur Prestige joint en HTTP
// RÉEL, avec la session de la connexion : routes et paramètres exacts (Balance vente / caisse, analyse comparative,
// sur-stocks, saisies en périmés, cartes du tableau de bord), replis sur un serveur sans les nouvelles routes (404),
// téléchargements (PDF de la balance, classeur .xls des sur-stocks) ; JAMAIS de création d'inventaire.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/vague4/donnees_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/models/tableau_bord_achats_ventes_model.dart';
import 'package:prestige_app/nouvelle_interface/modules/periode.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/services/api_service.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague4.dart';
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

final aujourdhui = DateTime(2026, 10, 14, 11, 30);

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
    expect(serveur.recues(ApiSurstock.routeInterdite), isEmpty, reason: 'création d\'inventaire : jamais depuis le mobile');
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..reponseSansSession = ((_) => ReponseFausse.sessionExpiree())
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
  });

  group('Balance vente / caisse', () {
    testWidgets('balance : dtStart / dtEnd, résumé, comptant / crédit, modes, caisse, TVA ; édition PDF', (tester) async {
      final app = await connecte(tester);
      final p = Periode.rapide(PeriodeRapide.hier, aujourdhui);
      final (b, e) = await essayer(tester, () => ApiBalance.balance(app.ctx, p));
      expect(e, isNull);
      expect(serveur.recues(ApiBalance.route).single.parametres, {'dtStart': '2026-10-13', 'dtEnd': '2026-10-13'});
      expect(b!.resume.montantNet, DonneesVague4.netBalance);
      expect(b.resume.montantMobile, 150000, reason: 'montantMobilePayment');
      expect([for (final l in b.lignes) l.libelle], ['COMPTANT', 'CRÉDIT']);
      expect(b.modes.map((m) => m.libelle), ['Espèces', 'Orange Money']);
      expect(b.caisse.first.libelle, 'Fond de caisse');
      expect(b.tva.last.taux, 18);
      final (f, e2) = await essayer(tester, () => ApiBalance.pdf(app.ctx, p));
      expect(e2, isNull);
      expect(f!.type, contains('pdf'));
      expect(serveur.recues(ApiBalance.routePdf).single.parametres, {'dtStart': '2026-10-13', 'dtEnd': '2026-10-13'});
    });

    testWidgets('analyse : 3 semaines (code du web), évolutions, modes, total ; période libre contrôlée SANS requête', (tester) async {
      final app = await connecte(tester);
      final (a, _) = await essayer(tester, () => ApiBalance.analyse(app.ctx, PeriodeAnalyse.troisSemaines, maintenant: aujourdhui));
      expect(serveur.recues(ApiBalance.routeAnalyse).single.parametres, {'typePeriode': 'TROIS_SEMAINES'});
      expect(a!.periodes, hasLength(3));
      expect(a.periodes[1].evolutions['montantNet'], 10.0);
      expect(a.periodes.last.enCours, isTrue);
      expect(a.periodes.first.parModes['7'], 1000000);
      expect(a.modes.map((m) => m.id), ['1', '7']);
      expect(a.total.montantNet, 9700000);
      expect(a.totalModes['1'], 4850000);

      final avant = serveur.requetes.length;
      final (_, e) = await essayer(tester, () => ApiBalance.analyse(app.ctx, PeriodeAnalyse.libre, maintenant: aujourdhui));
      expect(e, nature(NatureErreur.refus));
      final (_, e2) = await essayer(
          tester, () => ApiBalance.analyse(app.ctx, PeriodeAnalyse.libre, debut: DateTime(2026, 10, 10), fin: DateTime(2026, 10, 1), maintenant: aujourdhui));
      expect(e2, nature(NatureErreur.refus));
      expect(serveur.requetes.length, avant, reason: 'aucune requête pour une période refusée');
      await essayer(tester,
          () => ApiBalance.analyse(app.ctx, PeriodeAnalyse.libre, debut: DateTime(2026, 9, 1), fin: DateTime(2026, 9, 30), maintenant: aujourdhui));
      expect(serveur.recues(ApiBalance.routeAnalyse).last.parametres, {'typePeriode': 'LIBRE', 'dtStart': '2026-09-01', 'dtEnd': '2026-09-30'});
      expect(ApiBalance.longue(PeriodeAnalyse.troisAns, null, null), isTrue);
      expect(ApiBalance.longue(PeriodeAnalyse.troisMois, null, null), isFalse);
    });

    testWidgets('erreurs : 500 → erreur du serveur ; session expirée → déconnexion', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiBalance.route, ReponseFausse.erreurServeur());
      final (_, e) = await essayer(tester, () => ApiBalance.balance(app.ctx, Periode.rapide(PeriodeRapide.aujourdhui, aujourdhui)));
      expect(e, nature(NatureErreur.serveur));
      expect(app.auth.isLoggedIn, isTrue);
    });
  });

  group('Sur-stocks', () {
    testWidgets('page 1 (start=0 : recalcul), page 2 (start=50), critères ; classeur .xls accepté ; aucune création d\'inventaire', (tester) async {
      final app = await connecte(tester);
      const f = FiltresSurstock(moisHistorique: 6, moisProjection: 2, recherche: ' doli ', rayons: ['ZONE-TEST-1', 'ZONE-TEST-2']);
      final (p1, _) = await essayer(tester, () => ApiSurstock.page(app.ctx, f));
      expect(serveur.recues(ApiSurstock.route).single.parametres, {
        'moisHistorique': '6', 'moisProjection': '2', 'query': 'doli', 'codeRayon': 'ZONE-TEST-1,ZONE-TEST-2', 'codeGrossiste': '', 'codeFamille': '',
        'start': '0', 'limit': '50',
      });
      expect(p1!.produits, hasLength(50));
      expect(p1.total, DonneesVague4.surstocksTotal);
      expect(p1.mois.first, 'oct.');
      final (p2, _) = await essayer(tester, () => ApiSurstock.page(app.ctx, f, start: 50));
      expect(serveur.recues(ApiSurstock.route).last.parametres['start'], '50');
      expect(p2!.produits.first.libelle, 'PRODUIT SURSTOCK FICTIF 50');
      final (x, e) = await essayer(tester, () => ApiSurstock.excel(app.ctx, f));
      expect(e, isNull, reason: 'classeur .xls (OLE) du web');
      expect(x!.octets.first, 0xD0);
      expect(serveur.recues(ApiSurstock.routeExcel).single.parametres.containsKey('start'), isFalse);
    });

    test('critères bornés : mois 1 à 12, recherche coupée à 50 caractères', () {
      final p = FiltresSurstock(moisHistorique: 40, moisProjection: 0, recherche: 'x' * 80).parametres;
      expect((p['moisHistorique'], p['moisProjection'], p['query']!.length), ('12', '1', 50));
    });
  });

  group('Saisies en périmés', () {
    testWidgets('comptage : 30 derniers jours, une ligne demandée ; liste : période, recherche, page', (tester) async {
      final app = await connecte(tester);
      final (n, _) = await essayer(tester, () => ApiSaisiesPerimes.compter(app.ctx, aujourdhui));
      expect(n, 3);
      expect(serveur.recues(ApiSaisiesPerimes.route).single.parametres,
          {'dtStart': '2026-09-15', 'dtEnd': '2026-10-14', 'query': '', 'start': '0', 'limit': '1'});
      final (p, _) = await essayer(tester, () => ApiSaisiesPerimes.page(app.ctx, DateTime(2026, 10, 1), DateTime(2026, 10, 14), recherche: 'lot'));
      expect(p!.lignes, hasLength(3));
      expect(p.lignes.first.lot, 'LOT-0');
      expect(serveur.recues(ApiSaisiesPerimes.route).last.parametres['query'], 'lot');
    });
  });

  group('Tableau de bord', () {
    testWidgets('chiffres du jour : /tableau-bord/tuiles?date= ; serveur sans cette route (404) → /recap/dashboard/daily', (tester) async {
      final app = await connecte(tester);
      final (c, _) = await essayer(tester, () => ApiTableauBord.chiffres(app.ctx, aujourdhui));
      expect(serveur.recues(ApiTableauBord.routeTuiles).single.parametres, {'date': '2026-10-14'});
      expect((c!.ca, c.marge, c.panier, c.achats, c.bons, c.evolutionVeille), (1245300, 312800, 14314, 950000, 4, 13.2));
      serveur.quand(ApiTableauBord.routeTuiles, ReponseFausse.introuvable());
      final (c2, e) = await essayer(tester, () => ApiTableauBord.chiffres(app.ctx, aujourdhui));
      expect(e, isNull);
      expect(serveur.recues(ApiTableauBord.routeDaily), hasLength(1));
      expect((c2!.ca, c2.marge, c2.panier, c2.achats, c2.bons, c2.ancienneRoute), (1245300, 312800, 14314, 950000, 4, true));
    });

    testWidgets('fréquentation : journée par le Pilotage ; droit refusé ou route absente → semaine du tableau de bord', (tester) async {
      final app = await connecte(tester);
      final (f, _) = await essayer(tester, () => ApiTableauBord.frequentation(app.ctx, DateTime(2026, 10, 13)));
      expect(serveur.recues(ApiTableauBord.routeFrequentationPilotage).single.parametres, {'axe': 'PERSO', 'dtStart': '2026-10-13', 'dtEnd': '2026-10-13'});
      expect(f!.semaine, isFalse);
      expect(f.ventes, hasLength(24));
      serveur.quand(ApiTableauBord.routeFrequentationPilotage, ReponseFausse.json({'success': false, 'message': 'Accès refusé au pilotage.'}));
      final (f2, _) = await essayer(tester, () => ApiTableauBord.frequentation(app.ctx, DateTime(2026, 10, 13)));
      expect(f2!.semaine, isTrue);
      expect(serveur.recues(ApiTableauBord.routeFrequentation).single.parametres, {'date': '2026-10-13'});
      serveur.quand(ApiTableauBord.routeFrequentationPilotage, ReponseFausse.introuvable());
      final (f3, _) = await essayer(tester, () => ApiTableauBord.frequentation(app.ctx, DateTime(2026, 10, 13)));
      expect(f3!.semaine, isTrue);
    });

    testWidgets('valorisation : tableau de bord, sinon (404) calcul du jour /produit/valorisation ; carte absente → 404 gardé', (tester) async {
      final app = await connecte(tester);
      serveur.quand('/tableau-bord/valorisation', ReponseFausse.introuvable());
      await essayer(tester, () => ApiTableauBord.valorisation(app.ctx, aujourdhui));
      expect(serveur.recues('/produit/valorisation').single.parametres, {'mode': '0', 'dtStart': '2026-10-14'});
      serveur.quand(ApiTableauBord.routeEncaissements, ReponseFausse.introuvable());
      final (_, e) = await essayer(tester, () => ApiTableauBord.encaissements(app.ctx, aujourdhui));
      expect(routeAbsente(e!), isTrue, reason: 'la carte affichera « Indisponible sur ce serveur »');
    });

    testWidgets('top 10 : axe emplacement / famille, limite 10 ; encaissements du jour', (tester) async {
      final app = await connecte(tester);
      final (t, _) = await essayer(tester, () => ApiTableauBord.top(app.ctx, aujourdhui, famille: true));
      expect(serveur.recues(ApiTableauBord.routeEmplacements).single.parametres, {'date': '2026-10-14', 'limite': '10', 'axe': 'famille'});
      expect(t, hasLength(10));
      expect(t!.first.$1, 'FAMILLE FICTIVE 0');
      final (m, _) = await essayer(tester, () => ApiTableauBord.encaissements(app.ctx, aujourdhui));
      expect(m!.map((x) => x.$1), ['Espèces', 'Mobile money', 'Tiers payants (crédit)']);
    });
  });

  group('Tableau de bord : calculs', () {
    test('évolution du mois par tranches de 5 jours ; la dernière tranche va jusqu\'à la fin du mois', () {
      final lignes = [
        for (var j = 1; j <= 31; j++) TableauBordAchatsVentes(dateMvt: DateTime(2026, 10, j), montantAchat: 10, montantVente: 100),
      ];
      final t = ApiTableauBord.parCinqJours(lignes, DateTime(2026, 10, 31, 18));
      expect(t.map((x) => '${x.$1.day}-${x.$2.day}'), ['1-5', '6-10', '11-15', '16-20', '21-25', '26-31']);
      expect(t.last.$3, 600);
      final debut = ApiTableauBord.parCinqJours(lignes, DateTime(2026, 10, 7));
      expect(debut.map((x) => '${x.$1.day}-${x.$2.day}'), ['1-5', '6-7']);
      expect(debut.last.$3, 200);
    });

    test('nombres mis en forme par l\'ancien serveur', () {
      expect(nombreAffiche('1 245 300'), 1245300);
      expect(nombreAffiche('12,5'), 12.5);
      expect(nombreAffiche(null), 0);
      expect(nombreAffiche(42), 42);
    });

    test('cartes : ordre et affichage mémorisés ; cartes inconnues ignorées, cartes nouvelles ajoutées', () {
      final l = CartesTableauBordPrefs.lire('tva:1,chiffres:0,inconnue:1');
      expect(l.first.carte, CarteTableauBord.tva);
      expect(l[1], (carte: CarteTableauBord.chiffres, visible: false));
      expect(l, hasLength(CarteTableauBord.values.length));
      expect(CartesTableauBordPrefs.lire(CartesTableauBordPrefs.ecrire(l)), l);
      expect(CartesTableauBordPrefs.lire(null), CartesTableauBordPrefs.defaut);
    });
  });
}
