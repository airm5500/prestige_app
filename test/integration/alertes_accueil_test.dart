// Intégration : comptage à la demande des alertes de l'accueil A (AlertesAccueil) contre le faux serveur Prestige
// joint en HTTP RÉEL. Péremption : appel unique des alertes du tableau de bord (vague 1, mêmes paramètres que l'écran
// Alertes) ; contrôle des BL : mêmes route et paramètres que le module à son ouverture ; session de la connexion ;
// succès, mémoire (même serveur et même compte), 401 (retour à la connexion par le mécanisme existant), 500,
// serveur arrêté, délai borné, anti double appui ; et, dans l'application entière, AUCUN appel tant qu'on n'a pas
// touché ⟳ (ni au démarrage, ni à l'actualisation des chiffres du jour, ni en changeant d'onglet).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/alertes_accueil.dart';
import 'package:prestige_app/nouvelle_interface/vague1/alertes_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:prestige_app/utils/date_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';

final serveur = FauxServeurPrestige();
const routePeremption = ApiAlertes.routeComptage;
const routeControle = AppConstants.etatControleAchatEndpoint;

/// Paramètres de l'appel unique des alertes du tableau de bord (comme l'écran Alertes et le tableau de bord web).
const parametresPeremption = {'per': '6', 'rup': '7', 'ren': '7', 'sug': '2', 'nv': '30'};

/// Paramètres de l'écran Etat Contrôle Achat avec ses filtres par défaut (période du jour, tous les groupes).
Map<String, String> parametresControle() {
  final jour = DateFormatter.toApiFormat(DateTime.now());
  return {'dtStart': jour, 'dtEnd': jour, 'groupeId': '', 'groupBy': 'GROUP', 'limit': '9999'};
}

typedef App = ({BuildContext ctx, AuthProvider auth});

Future<App> connecte(WidgetTester tester) async {
  final auth = AuthProvider();
  final ctx = await monterAvecProviders(tester, auth: auth, licence: LicenceProvider());
  await tester.runAsync(() => auth.login(ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false));
  await tester.pump();
  expect(auth.isLoggedIn, isTrue);
  return (ctx: ctx, auth: auth);
}

Future<void> compter(WidgetTester tester, App app, AlerteAccueil a) async {
  await tester.runAsync(() => AlertesAccueil.instance.compter(app.ctx, a));
  await tester.pump();
}

EtatAlerte etat(AlerteAccueil a) => AlertesAccueil.instance.etat(a);

void main() {
  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerTelephone(serveur);
    donneesAlertes(serveur);
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

  group('Succès : mêmes routes et paramètres que les modules', () {
    testWidgets('Péremption : GET /tableau-bord/alertes (appel unique), session envoyée → 3 lots', (tester) async {
      final app = await connecte(tester);
      expect(etat(AlerteAccueil.peremption).dernier, isNull);
      await compter(tester, app, AlerteAccueil.peremption);
      final r = serveur.recues(routePeremption).single;
      expect(r.methode, 'GET');
      expect(r.parametres, parametresPeremption);
      expect(r.sessionEnvoyee, serveur.derniereSession);
      final e = etat(AlerteAccueil.peremption);
      expect(e.dernier!.nombre, DonneesFictives.lotsPerimes);
      expect(e.enCours, isFalse);
      expect(e.echec, isNull);
      expect(serveur.recues(routeControle), isEmpty, reason: 'une alerte ne compte que la sienne');
    });

    testWidgets('Etat Contrôle Achat : GET /etat-control-bon/list-annuelle, filtres par défaut de l\'écran → 7 bons', (tester) async {
      final app = await connecte(tester);
      await compter(tester, app, AlerteAccueil.controleAchat);
      final r = serveur.recues(routeControle).single;
      expect(r.parametres, parametresControle());
      expect(r.sessionEnvoyee, serveur.derniereSession);
      expect(etat(AlerteAccueil.controleAchat).dernier!.nombre, DonneesFictives.bonsControles);
      expect(serveur.recues('/groupegrossiste'), isEmpty, reason: 'la liste des groupes n\'est pas utile au comptage');
    });

    testWidgets('réponse vide ou liste vide : 0 (jamais une erreur)', (tester) async {
      final app = await connecte(tester);
      serveur.quand(routePeremption, ReponseFausse.vide());
      serveur.quand(routeControle, ReponseFausse.json(DonneesFictives.listeVide()));
      await compter(tester, app, AlerteAccueil.peremption);
      await compter(tester, app, AlerteAccueil.controleAchat);
      expect(etat(AlerteAccueil.peremption).dernier!.nombre, 0);
      expect(etat(AlerteAccueil.controleAchat).dernier!.nombre, 0);
    });

    testWidgets('résultat et heure mémorisés pour ce serveur et ce compte (relus sans appel au serveur)', (tester) async {
      final app = await connecte(tester);
      await compter(tester, app, AlerteAccueil.peremption);
      final heure = etat(AlerteAccueil.peremption).dernier!.le;
      // Application relancée : état en mémoire perdu, préférences conservées.
      AlertesAccueil.instance.oublier();
      serveur.oublierRequetes();
      AlertesAccueil.instance.preparer(AlertesAccueil.cleDe(app.ctx));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(etat(AlerteAccueil.peremption).dernier?.nombre, DonneesFictives.lotsPerimes);
      expect(etat(AlerteAccueil.peremption).dernier?.le.millisecondsSinceEpoch, heure.millisecondsSinceEpoch);
      expect(etat(AlerteAccueil.controleAchat).dernier, isNull);
      expect(serveur.requetes, isEmpty, reason: 'relire la mémoire n\'appelle pas le serveur');
      // Autre compte ou autre serveur : rien.
      AlertesAccueil.instance.oublier();
      AlertesAccueil.instance.preparer('http://autre-serveur/prestige/api/v1|autre.compte');
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      expect(etat(AlerteAccueil.peremption).dernier, isNull);
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      expect(prefs!.getString(AlertesTableauBord.clePreferences), contains('"peremptions"'));
      expect(prefs.getString(AlertesTableauBord.clePreferences), contains(AlertesAccueil.cleDe(app.ctx)));
    });

    testWidgets('anti double appui : deux appuis rapprochés = une seule requête', (tester) async {
      final app = await connecte(tester);
      serveur.quand(routePeremption, ReponseFausse.json(DonneesVague1.alertes()).apres(const Duration(milliseconds: 300)));
      await tester.runAsync(() => Future.wait([
            AlertesAccueil.instance.compter(app.ctx, AlerteAccueil.peremption),
            AlertesAccueil.instance.compter(app.ctx, AlerteAccueil.peremption),
          ]));
      expect(serveur.recues(routePeremption), hasLength(1));
      expect(etat(AlerteAccueil.peremption).dernier!.nombre, 3);
    });
  });

  group('Échecs distincts', () {
    testWidgets('401 : « Session expirée », retour à la connexion par le mécanisme existant (AuthProvider)', (tester) async {
      final app = await connecte(tester);
      final messages = <String>[];
      final abo = app.auth.events.listen(messages.add);
      serveur.expirerSessions();
      await compter(tester, app, AlerteAccueil.controleAchat);
      final e = etat(AlerteAccueil.controleAchat);
      expect(e.echec!.cause, CauseEchec.session);
      expect(e.enCours, isFalse);
      expect(app.auth.isLoggedIn, isFalse);
      expect(messages, [AuthProvider.messageSessionExpiree]);
      abo.cancel();
    });

    testWidgets('500 : « Erreur du serveur (code 500) », page technique jamais affichée, dernier nombre conservé', (tester) async {
      final app = await connecte(tester);
      await compter(tester, app, AlerteAccueil.peremption);
      serveur.quand(routePeremption, ReponseFausse.erreurServeur());
      await compter(tester, app, AlerteAccueil.peremption);
      final e = etat(AlerteAccueil.peremption);
      expect(e.echec!.cause, CauseEchec.serveur);
      expect(e.echec!.message, 'Erreur du serveur (code 500).');
      expect(e.dernier!.nombre, 3, reason: 'le dernier nombre obtenu reste affiché, avec son heure');
      expect(app.auth.isLoggedIn, isTrue);
    });

    testWidgets('serveur arrêté : « Serveur injoignable »', (tester) async {
      final app = await connecte(tester);
      await tester.runAsync(serveur.arreter);
      await compter(tester, app, AlerteAccueil.controleAchat);
      expect(etat(AlerteAccueil.controleAchat).echec!.cause, CauseEchec.injoignable);
      expect(app.auth.isLoggedIn, isTrue, reason: 'serveur injoignable ≠ session expirée');
    });

    testWidgets('serveur qui ne répond pas : délai borné (${AlertesAccueil.delaiParDefaut.inSeconds} s, bien avant les 45 s d\'ApiService)',
        (tester) async {
      final app = await connecte(tester);
      serveur.quand(routePeremption, ReponseFausse.sansReponse());
      AlertesAccueil.instance.compter(app.ctx, AlerteAccueil.peremption);
      await stabiliser(tester, tours: 4); // la requête part
      expect(etat(AlerteAccueil.peremption).enCours, isTrue);
      await tester.pump(AlertesAccueil.delaiParDefaut - const Duration(seconds: 1));
      expect(etat(AlerteAccueil.peremption).enCours, isTrue);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final e = etat(AlerteAccueil.peremption);
      expect(e.enCours, isFalse);
      expect(e.echec!.cause, CauseEchec.delai);
      await tester.pump(ApiService.delaiGet); // minuterie d'ApiService épuisée
    });
  });

  group('Application entière', () {
    testWidgets('aucun appel aux deux routes tant qu\'on n\'a pas touché ⟳ ; un appui = une requête', (tester) async {
      tester.view.devicePixelRatio = 2.625;
      tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
      addTearDown(tester.view.reset);
      preparerNouvelle(serveur);
      donneesAccueil(serveur);
      donneesAlertes(serveur);
      await jusquAccueilNouveau(tester);
      await attendreTexte(tester, '3 / 4'); // chiffres du jour chargés automatiquement
      await stabiliser(tester, tours: 20);
      expect(find.byKey(const Key('alerte_peremption_invite')), findsOneWidget);
      expect(find.byKey(const Key('alerte_controle_invite')), findsOneWidget);

      // Actualisation des chiffres du jour, onglets : toujours aucun comptage.
      await tester.tap(find.byTooltip('Actualiser les chiffres'));
      await stabiliser(tester, tours: 20);
      await ouvrirOnglet(tester, 'Analyses');
      await ouvrirOnglet(tester, 'Accueil');
      await stabiliser(tester, tours: 20);
      await tester.pump(const Duration(minutes: 3));
      await stabiliser(tester);
      expect(serveur.recues('/recap/dashboard').length, greaterThanOrEqualTo(2));
      expect(serveur.recues(routePeremption), isEmpty);
      expect(serveur.recues(routeControle), isEmpty);

      await tester.tap(find.byKey(const Key('alerte_peremption_actualiser')));
      await attendreWidget(tester, find.byKey(const Key('alerte_peremption_nombre')));
      expect(serveur.recues(routePeremption), hasLength(1));
      expect(serveur.recues(routeControle), isEmpty);
      expect(find.byType(LoginScreen), findsNothing);
      await terminer(tester);
    });
  });
}
