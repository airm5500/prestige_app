// Intégration de la vague 1 (lib/nouvelle_interface/vague1/donnees_vague1.dart et alertes_vague1.dart) contre le
// faux serveur Prestige joint en HTTP RÉEL, avec la session de la connexion :
//  - routes et paramètres exacts (valorisation du jour / date passée / regroupement, alertes et listes, journaux
//    paginés « results ») ;
//  - succès, liste vide, refus success:false et interdit:true → « Droit manquant » SANS déconnexion, 401 → retour à
//    la connexion (mécanisme existant), 500, délai dépassé ;
//  - alertes : AUCUN appel tant qu'on n'a pas touché ⟳ (écran ouvert, accueil), un appui = une requête, résultat
//    mémorisé (serveur + compte) et relu sans appel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/alertes_accueil.dart';
import 'package:prestige_app/nouvelle_interface/vague1/alertes_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/date_formatter.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';

final serveur = FauxServeurPrestige();

typedef App = ({BuildContext ctx, AuthProvider auth});

Future<App> connecte(WidgetTester tester) async {
  final auth = AuthProvider();
  final ctx = await monterAvecProviders(tester, auth: auth, licence: LicenceProvider());
  await tester.runAsync(() => auth.login(ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false));
  await tester.pump();
  expect(auth.isLoggedIn, isTrue);
  return (ctx: ctx, auth: auth);
}

/// Exécute [appel] en temps réel ; renvoie le résultat ou l'échec.
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

String jour(DateTime d) => DateFormatter.toApiFormat(d);

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
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..reponseSansSession = ((_) => ReponseFausse.sessionExpiree())
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
  });

  group('Valorisation', () {
    testWidgets('aujourd\'hui : GET /tableau-bord/valorisation?frais=0 avec la session ; ⟳ → frais=1', (tester) async {
      final app = await connecte(tester);
      final (v, e) = await essayer(tester, () => ApiValorisation.charger(app.ctx, mode: ModeValorisation.simple, date: DateTime.now()));
      expect(e, isNull);
      final r = serveur.recues(ApiValorisation.routeTableauDeBord).single;
      expect(r.parametres, {'frais': '0'});
      expect(r.sessionEnvoyee, serveur.derniereSession);
      expect(v!.reserve.achat, DonneesVague1.reserveAchat);
      expect(v.total.vente, DonneesVague1.rayonVente + DonneesVague1.reserveVente);
      expect(serveur.recues(ApiValorisation.routeProduit), isEmpty);
      await essayer(tester, () => ApiValorisation.charger(app.ctx, mode: ModeValorisation.simple, date: DateTime.now(), frais: true));
      expect(serveur.recues(ApiValorisation.routeTableauDeBord).last.parametres, {'frais': '1'});
    });

    testWidgets('date passée : GET /produit/valorisation?mode=0&dtStart= (relevé)', (tester) async {
      final app = await connecte(tester);
      final hier = DateTime.now().subtract(const Duration(days: 1));
      final (v, _) = await essayer(tester, () => ApiValorisation.charger(app.ctx, mode: ModeValorisation.simple, date: hier));
      expect(serveur.recues(ApiValorisation.routeProduit).single.parametres, {'mode': '0', 'dtStart': jour(hier)});
      expect(v!.source, SourceValorisation.releve);
      expect(v.rayon.achat, DonneesVague1.passeRayonAchat);
      expect(serveur.recues(ApiValorisation.routeTableauDeBord), isEmpty);
    });

    testWidgets('regroupement Famille aujourd\'hui : /produit/valorisation mode=1 avec les familles choisies', (tester) async {
      final app = await connecte(tester);
      final (o, _) = await essayer(tester, () => ApiValorisation.options(app.ctx, ModeValorisation.famille));
      expect(o!.map((x) => x.id), ['FAM-TEST-1', 'FAM-TEST-2'], reason: 'entrée « Tous » retirée');
      expect(serveur.recues('/common/famillearticles'), hasLength(1));
      final (v, _) = await essayer(
          tester, () => ApiValorisation.charger(app.ctx, mode: ModeValorisation.famille, date: DateTime.now(), ids: ['FAM-TEST-1', 'FAM-TEST-2']));
      expect(serveur.recues(ApiValorisation.routeProduit).single.parametres,
          {'mode': '1', 'dtStart': jour(DateTime.now()), 'lgFAMILLEARTICLEID': 'FAM-TEST-1,FAM-TEST-2'});
      expect(v!.source, SourceValorisation.calculDuJour);
      // Listes des autres regroupements : /common/rayons et /common/grossiste.
      await essayer(tester, () => ApiValorisation.options(app.ctx, ModeValorisation.emplacement));
      await essayer(tester, () => ApiValorisation.options(app.ctx, ModeValorisation.grossiste));
      expect(serveur.recues('/common/rayons'), hasLength(1));
      expect(serveur.recues('/common/grossiste'), hasLength(1));
    });

    testWidgets('relevé indisponible (releveDisponible:false) transmis tel quel', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiValorisation.routeProduit, ReponseFausse.json(DonneesVague1.valorisationProduit(releve: false)));
      final (v, _) = await essayer(
          tester, () => ApiValorisation.charger(app.ctx, mode: ModeValorisation.simple, date: DateTime.now().subtract(const Duration(days: 30))));
      expect(v!.releveDisponible, isFalse);
    });

    testWidgets('date future : refusée par l\'application, aucune requête', (tester) async {
      final app = await connecte(tester);
      final (_, e) = await essayer(
          tester, () => ApiValorisation.charger(app.ctx, mode: ModeValorisation.simple, date: DateTime.now().add(const Duration(days: 1))));
      expect(e, nature(NatureErreur.refus));
      expect(serveur.recues(ApiValorisation.routeProduit), isEmpty);
      expect(serveur.recues(ApiValorisation.routeTableauDeBord), isEmpty);
    });

    testWidgets('500 : erreur du serveur ; calcul en échec côté serveur (success:false, erreur:true) : idem', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiValorisation.routeTableauDeBord, ReponseFausse.erreurServeur());
      final (_, e) = await essayer(tester, () => ApiValorisation.charger(app.ctx, mode: ModeValorisation.simple, date: DateTime.now()));
      expect(e, nature(NatureErreur.serveur));
      serveur.quand(ApiValorisation.routeTableauDeBord, ReponseFausse.json({'success': false, 'erreur': true}));
      final (_, e2) = await essayer(tester, () => ApiValorisation.charger(app.ctx, mode: ModeValorisation.simple, date: DateTime.now()));
      expect(e2, nature(NatureErreur.serveur));
      expect(app.auth.isLoggedIn, isTrue);
    });
  });

  group('Refus, session, délai (communs aux 4 menus)', () {
    testWidgets('success:false → « Droit manquant : … » sans déconnexion', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiJournaux.routeSuppressions, ReponseFausse.json({'success': false, 'msg': 'Accès refusé à ce menu.'}));
      final (_, e) = await essayer(tester, () => ApiJournaux.suppressions(app.ctx, FiltresJournal(debut: DateTime.now(), fin: DateTime.now())));
      expect(e, nature(NatureErreur.droit));
      expect('$e', startsWith('Droit manquant : consulter les retraits et abandons.'));
      expect('$e', contains('Accès refusé à ce menu.'));
      expect(app.auth.isLoggedIn, isTrue);
    });

    testWidgets('interdit:true → « Droit manquant » ; 403 → « Droit manquant » ; jamais de déconnexion', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiJournaux.routeModifiees, ReponseFausse.json({'success': false, 'interdit': true}));
      final (_, e) = await essayer(tester, () => ApiJournaux.modifiees(app.ctx, FiltresJournal(debut: DateTime.now(), fin: DateTime.now())));
      expect('$e', startsWith('Droit manquant : consulter les ventes modifiées.'));
      serveur.quand(ApiAlertes.routeComptage, ReponseFausse.json({'success': false}, statut: 403));
      final (_, e2) = await essayer(tester, () => ApiAlertes.compter(app.ctx));
      expect(e2, nature(NatureErreur.droit));
      expect('$e2', startsWith('Droit manquant : consulter les alertes.'));
      expect(app.auth.isLoggedIn, isTrue);
    });

    testWidgets('401 : session expirée → retour à la connexion par le mécanisme existant', (tester) async {
      final app = await connecte(tester);
      final messages = <String>[];
      final abo = app.auth.events.listen(messages.add);
      serveur.expirerSessions();
      final (_, e) = await essayer(tester, () => ApiJournaux.suppressions(app.ctx, FiltresJournal(debut: DateTime.now(), fin: DateTime.now())));
      expect(e, nature(NatureErreur.session));
      expect(app.auth.isLoggedIn, isFalse);
      expect(messages, [AuthProvider.messageSessionExpiree]);
      abo.cancel();
    });

    testWidgets('« Veuillez vous connecter » en 200 (tableau de bord) : session expirée aussi', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiValorisation.routeTableauDeBord, ReponseFausse.json({'success': false, 'msg': 'Veuillez vous connecter'}));
      final (_, e) = await essayer(tester, () => ApiValorisation.charger(app.ctx, mode: ModeValorisation.simple, date: DateTime.now()));
      expect(e, nature(NatureErreur.session));
      expect(app.auth.isLoggedIn, isFalse);
    });

    testWidgets('serveur qui ne répond pas : délai dépassé (${ApiService.delaiGet.inSeconds} s), message distinct', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiJournaux.routeModifiees, ReponseFausse.sansReponse());
      Object? erreur;
      () async {
        try {
          await ApiJournaux.modifiees(app.ctx, FiltresJournal(debut: DateTime.now(), fin: DateTime.now()));
        } catch (e) {
          erreur = e;
        }
      }();
      await stabiliser(tester, tours: 4); // la requête part
      expect(erreur, isNull);
      await tester.pump(ApiService.delaiGet + const Duration(seconds: 1));
      await tester.pump();
      expect(erreur, nature(NatureErreur.delai));
      expect(app.auth.isLoggedIn, isTrue);
    });
  });

  group('Alertes du tableau de bord', () {
    testWidgets('un appui = UN appel /tableau-bord/alertes?per=6&rup=7&ren=7&sug=2&nv=30 ; double appui ignoré ; mémoire',
        (tester) async {
      final app = await connecte(tester);
      final store = AlertesTableauBord.instance;
      expect(store.etat.dernier, isNull);
      serveur.quand(ApiAlertes.routeComptage, ReponseFausse.json(DonneesVague1.alertes()).apres(const Duration(milliseconds: 300)));
      await tester.runAsync(() => Future.wait([store.actualiser(app.ctx), store.actualiser(app.ctx)]));
      await tester.pump();
      final r = serveur.recues(ApiAlertes.routeComptage).single;
      expect(r.parametres, {'per': '6', 'rup': '7', 'ren': '7', 'sug': '2', 'nv': '30'});
      expect(r.sessionEnvoyee, serveur.derniereSession);
      expect(store.etat.dernier!.ruptures, DonneesVague1.ruptures);
      expect(store.etat.le, isNotNull);
      // L'alerte péremption de l'accueil A lit le même résultat, sans autre appel.
      expect(AlertesAccueil.instance.etat(AlerteAccueil.peremption).dernier!.nombre, DonneesFictives.lotsPerimes);
      // Relance de l'application : relu depuis la mémoire, sans appel.
      store.oublier();
      serveur.oublierRequetes();
      store.preparer(AlertesTableauBord.cleDe(app.ctx));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(store.etat.dernier?.negatifs, DonneesVague1.negatifs);
      expect(serveur.requetes, isEmpty);
      // Autre compte : rien.
      store.oublier();
      store.preparer('http://autre/prestige/api/v1|autre.compte');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(store.etat.dernier, isNull);
    });

    testWidgets('échecs : 500 (dernier résultat conservé), refus (droit), serveur arrêté, délai borné à ${AlertesAccueil.delaiParDefaut.inSeconds} s',
        (tester) async {
      final app = await connecte(tester);
      final store = AlertesTableauBord.instance;
      await tester.runAsync(() => store.actualiser(app.ctx));
      serveur.quand(ApiAlertes.routeComptage, ReponseFausse.erreurServeur());
      await tester.runAsync(() => store.actualiser(app.ctx));
      expect(store.etat.echec!.cause, CauseEchec.serveur);
      expect(store.etat.dernier!.ruptures, DonneesVague1.ruptures, reason: 'dernier résultat conservé');
      serveur.quand(ApiAlertes.routeComptage, ReponseFausse.json({'success': false, 'interdit': true}));
      await tester.runAsync(() => store.actualiser(app.ctx));
      expect(store.etat.echec!.cause, CauseEchec.droit);
      expect(store.etat.echec!.message, startsWith('Droit manquant'));
      expect(app.auth.isLoggedIn, isTrue);
      serveur.quand(ApiAlertes.routeComptage, ReponseFausse.sansReponse());
      store.actualiser(app.ctx);
      await stabiliser(tester, tours: 4);
      expect(store.etat.enCours, isTrue);
      await tester.pump(AlertesAccueil.delaiParDefaut + const Duration(seconds: 1));
      await tester.pump();
      expect(store.etat.enCours, isFalse);
      expect(store.etat.echec!.cause, CauseEchec.delai);
      await tester.pump(ApiService.delaiGet);
      await tester.runAsync(serveur.arreter);
      await tester.runAsync(() => store.actualiser(app.ctx));
      expect(store.etat.echec!.cause, CauseEchec.injoignable);
    });

    testWidgets('listes : type, mêmes réglages, limite=500 ; types non listables : aucun appel', (tester) async {
      final app = await connecte(tester);
      for (final t in TypeAlerte.values) {
        final (l, e) = await essayer(tester, () => ApiAlertes.liste(app.ctx, t));
        expect(e, isNull, reason: t.name);
        if (!t.listable) expect(l, isEmpty);
      }
      final recues = serveur.recues(ApiAlertes.routeListe).toList();
      expect(recues.map((r) => r.parametres['type']), ['ruptures', 'peremptions', 'negatifs', 'nonvendus', 'rayon']);
      for (final r in recues) {
        expect(r.parametres['limite'], '500');
        expect(r.parametres['per'], '6');
        expect(r.parametres['nv'], '30');
      }
      final (p, _) = await essayer(tester, () => ApiAlertes.liste(app.ctx, TypeAlerte.peremptions));
      expect(p, hasLength(DonneesFictives.lotsPerimes));
      serveur.quand(ApiAlertes.routeListe, ReponseFausse.json({'type': 'ruptures', 'data': 'x'}));
      final (_, e) = await essayer(tester, () => ApiAlertes.liste(app.ctx, TypeAlerte.ruptures));
      expect(e, nature(NatureErreur.reponse));
    });

    testWidgets('écran Alertes ouvert : AUCUN appel avant ⟳ ; « Compter les alertes » → un appel, cartes affichées', (tester) async {
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
      addTearDown(tester.view.reset);
      final auth = AuthProvider();
      final ctx = await monterAvecProviders(tester, auth: auth, licence: LicenceProvider());
      await tester.runAsync(() => auth.login(ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false));
      serveur.oublierRequetes();
      Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const AlertesScreen()));
      await stabiliser(tester, tours: 20);
      await tester.pump(const Duration(minutes: 2));
      await stabiliser(tester);
      expect(find.byKey(const Key('alertes_invite')), findsOneWidget);
      expect(serveur.recues(ApiAlertes.routeComptage), isEmpty);
      expect(serveur.requetes.where((r) => r.chemin.startsWith('/tableau-bord')), isEmpty);
      await tester.tap(find.byKey(const Key('alertes_compter')));
      await attendreWidget(tester, find.byKey(const Key('carte_alerte_ruptures')));
      expect(serveur.recues(ApiAlertes.routeComptage), hasLength(1));
      expect(find.byKey(const Key('alertes_moment')), findsOneWidget);
      await terminer(tester);
    });
  });

  group('Retraits et abandons, ventes modifiées', () {
    testWidgets('retraits : paramètres exacts, « results » lus, total ; page suivante start=50', (tester) async {
      final app = await connecte(tester);
      final f = FiltresJournal(debut: DateTime(2026, 10, 1), fin: DateTime(2026, 10, 14), type: 'VENTE', utilisateurId: DonneesVague1.utilisateur2Id);
      final (p, _) = await essayer(tester, () => ApiJournaux.suppressions(app.ctx, f));
      final r = serveur.recues(ApiJournaux.routeSuppressions).single;
      expect(r.parametres, {
        'start': '0', 'limit': '50', 'dtStart': '2026-10-01', 'dtEnd': '2026-10-14', 'userId': DonneesVague1.utilisateur2Id, 'query': '', 'type': 'VENTE',
      });
      expect(r.sessionEnvoyee, serveur.derniereSession);
      expect(p!.lignes, hasLength(2));
      expect(p.total, 2);
      expect(p.lignes.every((s) => s.venteAbandonnee), isTrue);
      await essayer(tester, () => ApiJournaux.suppressions(app.ctx, f, start: 50));
      expect(serveur.recues(ApiJournaux.routeSuppressions).last.parametres['start'], '50');
    });

    testWidgets('retraits : liste vide (≠ erreur) ; recherche transmise', (tester) async {
      final app = await connecte(tester);
      final f = FiltresJournal(debut: DateTime.now(), fin: DateTime.now(), recherche: 'introuvable');
      final (p, e) = await essayer(tester, () => ApiJournaux.suppressions(app.ctx, f));
      expect(e, isNull);
      expect(p!.lignes, isEmpty);
      expect(p.total, 0);
      expect(serveur.recues(ApiJournaux.routeSuppressions).single.parametres['query'], 'introuvable');
    });

    testWidgets('ventes modifiées : type, lignes avant / après', (tester) async {
      final app = await connecte(tester);
      final (p, _) = await essayer(tester, () => ApiJournaux.modifiees(app.ctx, FiltresJournal(debut: DateTime.now(), fin: DateTime.now(), type: 'PRODUITS')));
      expect(serveur.recues(ApiJournaux.routeModifiees).single.parametres['type'], 'PRODUITS');
      expect(p!.lignes.single.lignes, hasLength(2));
      expect(p.lignes.single.lignes.first.actionLibelle, 'Produit retiré');
    });

    testWidgets('utilisateurs du filtre : GET /common/users (lgUSERID, fullName)', (tester) async {
      final app = await connecte(tester);
      final (u, _) = await essayer(tester, () => ApiJournaux.utilisateurs(app.ctx));
      expect(u!.map((o) => o.libelle), [DonneesVague1.utilisateur1, DonneesVague1.utilisateur2]);
    });

    testWidgets('500 : erreur du serveur (page technique jamais affichée)', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiJournaux.routeModifiees, ReponseFausse.erreurServeur());
      final (_, e) = await essayer(tester, () => ApiJournaux.modifiees(app.ctx, FiltresJournal(debut: DateTime.now(), fin: DateTime.now())));
      expect(e, nature(NatureErreur.serveur));
      expect('$e', isNot(contains('NullPointer')));
    });
  });
}
