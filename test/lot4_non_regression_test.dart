// Non-régression des DONNÉES du lot 4 (« le reste ») : pour chaque module refait (Récap de caisse, Achats Fourn.,
// Fichier Journal, Annulation Ventes), l'écran d'ORIGINE et le NOUVEL écran sont montés tour à tour contre le même
// faux serveur (support/donnees_lot4.dart) :
//  - mêmes requêtes (routes, méthode, paramètres, CORPS du ticket Z) à l'ouverture (jour), pour le mois dernier, après
//    un filtre (caissier, opération, utilisateur) ; recherche et filtre des achats LOCAUX sans nouvelle requête ;
//  - mêmes chiffres affichés (montants du ticket Z tels que le serveur les rend, TTC des achats, récapitulatif par
//    fournisseur, actions du journal, ventes trouvées) ;
//  - Annulation : MÊME requête d'annulation (GET /vente/annulation/{id}, entourée des mêmes relectures), et RIEN
//    n'est envoyé tant que la confirmation renforcée n'est pas complète (bouton désactivé, « Ne pas annuler »).
// Horloge simulée, client en mémoire ; écran haut (411 × 5000 dp) pour que toutes les lignes soient construites.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import 'support/application.dart';
import 'support/cas_affichage.dart';
import 'support/catalogue_ecrans.dart';
import 'support/donnees_lot4.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/polices.dart';

final serveur = FauxServeurPrestige();

/// « 118.000 FCFA », « 118 000 F », « 125 000 » → « 118000 ».
String norm(String s) => s.replaceAll(RegExp(r'[\s  .]'), '').replaceAll(RegExp(r'(FCFA|F)$'), '');

String? texteDe(Widget w) => w is Text ? (w.data ?? w.textSpan?.toPlainText()) : (w is RichText ? w.text.toPlainText() : null);

List<Map<String, String>> params(String chemin) => [for (final r in serveur.recues(chemin)) r.parametres];

/// Cartes du nouvel écran (téléphone) : titre → valeur.
List<(String, String)> cartes() => [for (final e in find.byType(CarteLigne).evaluate()) ((e.widget as CarteLigne).titre, (e.widget as CarteLigne).valeur ?? '')];

/// Lignes « libellé … valeur » du nouvel écran.
List<String> lignesDetail() => [for (final e in find.byType(LigneDetail).evaluate()) '${(e.widget as LigneDetail).libelle}|${norm((e.widget as LigneDetail).valeur)}'];

Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> monter(WidgetTester tester, Widget Function() ecran, {required bool nouvelle}) async {
  preparerTelephone(serveur, nouvelle: nouvelle);
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

/// Choisit [option] dans une liste déroulante (écran d'origine ou feuille des filtres).
Future<void> choisirDansListe(WidgetTester tester, Finder liste, String option) async {
  await toucher(tester, liste, 5);
  await tester.tap(find.text(option).hitTestable().last);
  await pomper(tester, 8);
}

/// Feuille des filtres du nouvel écran : [reglages] puis « Appliquer ».
Future<void> filtrer(WidgetTester tester, Future<void> Function() reglages) async {
  await toucher(tester, find.byKey(const Key('bouton_filtres')), 6);
  await reglages();
  await toucher(tester, find.byKey(const Key('filtres_appliquer')));
}

final maintenant = DateTime.now();
final moisDernierPossible = maintenant.month > 1;
String get nomMoisDernier => DateFormat.MMMM('fr_FR').format(DateTime(maintenant.year, maintenant.month - 1));

ModuleLot1 module(String tuile) => modulesLot4.firstWhere((m) => m.tuile == tuile);

String jour(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Compte connecté : « dashboard » (administrateur / pharmacien) ou autre. À appeler APRÈS le démarrage de
/// l'application, qui republie le compte enregistré.
void profil(String type) {
  ProfilAcces.utilisateur.value = AppUser.fromJson({'str_USER_ID': 'USR-TEST', 'str_LOGIN': 'test', 'xtypeuser': type});
  addTearDown(() => ProfilAcces.utilisateur.value = null);
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
    donneesLot4(serveur);
    // Messages courts (toasts) de l'écran d'origine de l'annulation.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('PonnamKarthik/fluttertoast'), (_) async => true);
  });

  void ecranHaut(WidgetTester tester, {double hauteur = 5000}) {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = Size(411 * 2.625, hauteur * 2.625);
    addTearDown(tester.view.reset);
  }

  final duJour = {'dtStart': jour(maintenant), 'dtEnd': jour(maintenant)};
  final duMoisDernier = {
    'dtStart': jour(DateTime(maintenant.year, maintenant.month - 1, 1)),
    'dtEnd': jour(DateTime(maintenant.year, maintenant.month, 0)),
  };

  // -------------------------------------------------------------------------------------------------------------
  // Récap de caisse
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Récap de caisse : même corps POST (jour, caissier) et mêmes montants du ticket Z', (tester) async {
    ecranHaut(tester);
    final m = module('Récap de caisse');
    const route = '/caisse/fetch-tickez';
    List<String> lignesO() => [
          for (final e in find.descendant(of: find.byType(ListView), matching: find.byType(Row)).evaluate())
            () {
              final t = [for (final x in find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text)).evaluate()) texteDe(x.widget) ?? ''];
              return t.length == 2 ? '${t[0]}|${norm(t[1])}' : null;
            }(),
        ].whereType<String>().toList();

    await monter(tester, m.ancien, nouvelle: false);
    expect(serveur.recues(route), isEmpty, reason: 'origine : rien avant « Rechercher »');
    expect(serveur.recues('/common/users').single.parametres, {'limit': '9999'});
    await toucher(tester, find.text('Rechercher'));
    final jourO = [for (final r in serveur.recues(route)) r.json];
    final montantsO = lignesO()..sort();
    serveur.oublierRequetes();
    await choisirDansListe(tester, find.byType(DropdownButtonFormField<String>), DonneesLot4.caissier2);
    await toucher(tester, find.text('Rechercher'));
    final caissierO = [for (final r in serveur.recues(route)) r.json];
    final montantsCaissierO = lignesO()..sort();
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final jourN = [for (final r in serveur.recues(route)) r.json];
    expect(serveur.recues('/common/users').single.parametres, {'limit': '9999'});
    final montantsN = lignesDetail()..sort();
    expect(norm(tester.widget<Text>(find.byKey(const Key('chiffre_especes'))).data!), norm(DonneesLot4.totalEsp));
    expect(norm(tester.widget<Text>(find.byKey(const Key('chiffre_vno_vo'))).data!), norm(DonneesLot4.totalVnoVo));
    expect(tester.widget<Text>(find.byKey(const Key('chiffre_caissiers'))).data, '2');
    serveur.oublierRequetes();
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_caissier')), DonneesLot4.caissier2));
    final caissierN = [for (final r in serveur.recues(route)) r.json];
    final montantsCaissierN = lignesDetail()..sort();
    await demonter(tester);

    expect(serveur.recues(route, methode: 'GET'), isEmpty);
    expect(jourO.single, {
      'description': 'ALL',
      ...duJour,
      'hrStart': '00:00',
      'hrEnd': '23:59',
      'userId': 'ALL',
    });
    expect(jourN, jourO);
    expect(caissierO.single, containsPair('userId', 'USR-C2'));
    expect(caissierN, caissierO);
    expect(montantsO, hasLength(2 * 4 + 4), reason: '2 caissiers × (2 modes + 2 totaux) + 4 totaux globaux');
    expect(montantsN, montantsO);
    expect(montantsCaissierO, hasLength(4 + 2));
    expect(montantsCaissierN, montantsCaissierO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // Achats fournisseurs
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Achats Fourn. : mêmes requêtes (jour, mois dernier), mêmes TTC, même filtre LOCAL, même récapitulatif', (tester) async {
    ecranHaut(tester);
    final m = module('Achats Fourn.');
    const route = AppConstants.achatsFournisseursEndpoint;
    List<String> achatsO() => [
          for (final e in find.byType(ListTile).evaluate())
            '${texteDe((e.widget as ListTile).title!)}|${norm(texteDe(find.descendant(of: find.byWidget(e.widget), matching: find.textContaining('Montant TTC:')).evaluate().single.widget)!.replaceFirst('Montant TTC: ', ''))}',
        ]..sort();
    List<String> achatsN() => [for (final (t, v) in cartes()) '$t|${norm(v)}']..sort();
    List<String> recapO() => [
          for (final e in find.descendant(of: find.byType(AlertDialog), matching: find.byType(Text)).evaluate())
            if ((texteDe(e.widget) ?? '').startsWith('Total ')) norm((texteDe(e.widget)!).replaceFirst(RegExp(r'Total (HT|TVA|TTC): '), '')),
        ];
    List<String> recapN() => [
          for (final e in find.descendant(of: find.byKey(const Key('feuille_detail')), matching: find.byType(LigneDetail)).evaluate())
            norm((e.widget as LigneDetail).valeur),
        ];

    await monter(tester, m.ancien, nouvelle: false);
    expect(serveur.recues(route), isEmpty, reason: 'origine : rien avant « Afficher les Achats »');
    await toucher(tester, find.text('Afficher les Achats'));
    final jourO = params(route);
    final listeO = achatsO();
    await toucher(tester, find.text('Récap Achat'));
    final recapToutO = recapO();
    await toucher(tester, find.text('Fermer'));
    await tester.enterText(find.byType(TextField), 'bl-b');
    await pomper(tester, 3);
    final rechercheO = achatsO();
    await tester.enterText(find.byType(TextField), '');
    await pomper(tester, 3);
    await choisirDansListe(tester, find.text('Tous les fournisseurs').first, DonneesLot4.fournisseurA);
    final fournisseurO = achatsO();
    await toucher(tester, find.text('Récap Achat'));
    final recapFournisseurO = recapO();
    await toucher(tester, find.text('Fermer'));
    final requetesO = serveur.recues(route).length;
    serveur.oublierRequetes();
    if (moisDernierPossible) await choisirDansListe(tester, find.text('Choisir...').first, nomMoisDernier);
    final moisO = params(route);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final jourN = params(route);
    final listeN = achatsN();
    expect(norm(tester.widget<Text>(find.byKey(const Key('chiffre_ttc'))).data!), '${DonneesLot4.totalTtc}');
    await toucher(tester, find.byKey(const Key('achats_recap')));
    final recapToutN = recapN();
    await toucher(tester, find.byKey(const Key('detail_fermer')));
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'bl-b');
    await pomper(tester, 8);
    final rechercheN = achatsN();
    await tester.enterText(find.byKey(const Key('champ_recherche')), '');
    await pomper(tester, 8);
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_fournisseur')), DonneesLot4.fournisseurA));
    final fournisseurN = achatsN();
    await toucher(tester, find.byKey(const Key('achats_recap')));
    final recapFournisseurN = recapN();
    await toucher(tester, find.byKey(const Key('detail_fermer')));
    final requetesN = serveur.recues(route).length;
    serveur.oublierRequetes();
    if (moisDernierPossible) await toucher(tester, find.byKey(const Key('periode_moisDernier')));
    final moisN = params(route);
    await demonter(tester);

    expect(jourO.single, duJour);
    expect(jourN, jourO);
    expect(listeO, hasLength(4));
    expect(listeN, listeO);
    expect(recapToutO, hasLength(2 * 3), reason: 'HT, TVA, TTC par fournisseur');
    expect(recapToutN, recapToutO);
    expect(rechercheO, hasLength(2));
    expect(rechercheN, rechercheO);
    expect(fournisseurO, hasLength(2));
    expect(fournisseurN, fournisseurO);
    expect(recapFournisseurO, ['120000', '18000', '138000']);
    expect(recapFournisseurN, recapFournisseurO);
    expect(requetesO, 1, reason: 'recherche, filtre et récapitulatif locaux');
    expect(requetesN, 1, reason: 'recherche, filtre et récapitulatif locaux : aucune nouvelle requête');
    if (moisDernierPossible) {
      expect(moisO.single, duMoisDernier);
      expect(moisN, moisO);
    }
  });

  // -------------------------------------------------------------------------------------------------------------
  // Fichier Journal
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Fichier Journal : mêmes requêtes (listes, jour, opération, utilisateur) et mêmes actions', (tester) async {
    ecranHaut(tester);
    final m = module('Fichier Journal');
    const route = AppConstants.fichierJournalEndpoint;
    List<String> actionsO() => [for (final e in find.byType(ListTile).evaluate()) texteDe((e.widget as ListTile).title!)!]..sort();
    List<String> actionsN() => [for (final (t, _) in cartes()) t]..sort();

    await monter(tester, m.ancien, nouvelle: false);
    final listesO = [params(AppConstants.logFiltresEndpoint), params(AppConstants.logUsersEndpoint)];
    expect(serveur.recues(route), isEmpty, reason: 'origine : rien avant « Rechercher »');
    await toucher(tester, find.text('Rechercher'));
    final jourO = params(route);
    final listeO = actionsO();
    serveur.oublierRequetes();
    await choisirDansListe(tester, find.byWidgetPredicate((w) => w is DropdownButtonFormField).first, 'Annulations');
    await choisirDansListe(tester, find.text('Tous les utilisateurs').first, DonneesLot4.caissier1);
    await toucher(tester, find.text('Rechercher'));
    final filtreO = params(route);
    final listeFiltreO = actionsO();
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final listesN = [params(AppConstants.logFiltresEndpoint), params(AppConstants.logUsersEndpoint)];
    final jourN = params(route);
    final listeN = actionsN();
    serveur.oublierRequetes();
    await filtrer(tester, () async {
      await choisirDansListe(tester, find.byKey(const Key('filtre_operation')), 'Annulations');
      await choisirDansListe(tester, find.byKey(const Key('filtre_utilisateur')), DonneesLot4.caissier1);
    });
    final filtreN = params(route);
    final listeFiltreN = actionsN();
    // Recherche locale (nouvelle) : aucune requête.
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'N2');
    await pomper(tester, 8);
    expect(actionsN(), ['Action fictive N2']);
    expect(serveur.recues(route), hasLength(1), reason: 'recherche locale');
    await demonter(tester);

    expect(listesO, [[{}], [{}]], reason: 'listes des filtres sans paramètre');
    expect(listesN, listesO);
    // Origine : 200 actions au plus (inchangé). Nouvelle interface (3.6.1) : MÊMES filtres, première page de 50.
    expect(jourO.single, {...duJour, 'criteria': '-1', 'userId': '', 'limit': '200'});
    expect(jourN.single, {...duJour, 'criteria': '-1', 'userId': '', 'start': '0', 'limit': '50'});
    expect(listeO, hasLength(6));
    expect(listeN, listeO);
    expect(filtreO.single, {...duJour, 'criteria': '4', 'userId': 'USR-C1', 'limit': '200'});
    expect(filtreN.single, {...duJour, 'criteria': '4', 'userId': 'USR-C1', 'start': '0', 'limit': '50'});
    Map<String, String> sansPage(Map<String, String> p) => {...p}
      ..remove('start')
      ..remove('limit');
    expect(sansPage(jourN.single), sansPage(jourO.single), reason: 'mêmes filtres');
    expect(sansPage(filtreN.single), sansPage(filtreO.single), reason: 'mêmes filtres');
    expect(listeFiltreO, ['Action fictive N2', 'Action fictive N6']);
    expect(listeFiltreN, listeFiltreO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // Annulation Ventes
  // -------------------------------------------------------------------------------------------------------------

  /// Requêtes de la vente (recherche, détail, annulation), dans l'ordre : méthode, chemin, paramètres.
  List<String> requetesVente() => [
        for (final r in serveur.requetes)
          if (r.chemin.startsWith('/ventestats') || r.chemin.startsWith('/vente/annulation')) '${r.methode} ${r.chemin} ${r.parametres}',
      ];

  testWidgets('Annulation : même recherche, même détail et MÊME requête d\'annulation (relectures comprises)', (tester) async {
    ecranHaut(tester);
    final m = module('Annulation Ventes');
    await monter(tester, m.ancien, nouvelle: false);
    await tester.enterText(find.byType(TextField), '261013');
    await toucher(tester, find.text('Rechercher les Ventes'));
    final rechercheO = requetesVente();
    serveur.oublierRequetes();
    await toucher(tester, find.byTooltip('Voir Détails').first);
    final detailO = requetesVente();
    await toucher(tester, find.text('Fermer'));
    serveur.oublierRequetes();
    await toucher(tester, find.byKey(const Key('annuler_${DonneesLot4.idA}')));
    await toucher(tester, find.text('Oui, Annuler'));
    final annulationO = requetesVente();
    expect(DonneesLot4.annulees, {DonneesLot4.idA});
    await demonter(tester);

    donneesLot4(serveur); // vente A de nouveau non annulée
    await monter(tester, m.nouveau, nouvelle: true);
    expect(requetesVente(), isEmpty, reason: 'rien sans numéro de vente, comme l\'origine');
    await tester.enterText(find.byKey(const Key('champ_recherche')), '261013');
    await pomper(tester, 8);
    final rechercheN = requetesVente();
    expect(tester.widget<Text>(find.byKey(const Key('chiffre_ventes'))).data, '2');
    serveur.oublierRequetes();
    await toucher(tester, find.byKey(const Key('vente_${DonneesLot4.idA}')));
    final detailN = requetesVente();
    expect(find.text(DonneesLot4.clientA), findsOneWidget, reason: 'client affiché dans le détail');
    expect(find.text('PRODUIT FICTIF ANNULATION 1'), findsOneWidget, reason: 'lignes affichées');
    serveur.oublierRequetes();
    profil('dashboard'); // après le démarrage (qui relit le compte enregistré)
    await toucher(tester, find.byKey(const Key('bouton_annuler_vente')));
    await tester.enterText(find.byKey(const Key('confirmation_saisie')), DonneesLot4.refA);
    await pomper(tester, 3);
    await toucher(tester, find.byKey(const Key('confirmation_oui')));
    final annulationN = requetesVente();
    expect(DonneesLot4.annulees, {DonneesLot4.idA});
    expect(find.byKey(const Key('resultat_annulation')), findsOneWidget);
    expect(find.text('Vente annulée avec succès'), findsWidgets);
    await demonter(tester);

    final recherche = {'dtStart': jour(maintenant), 'dtEnd': jour(maintenant), 'query': '261013', 'start': '0', 'limit': '50'};
    expect(rechercheO, ['GET /ventestats $recherche']);
    expect(rechercheN, rechercheO);
    expect(detailO, ['GET /ventestats/find-one/${DonneesLot4.idA} {}']);
    expect(detailN, detailO);
    expect(annulationO, [
      'GET /ventestats $recherche',
      'GET /vente/annulation/${DonneesLot4.idA} {}',
      'GET /ventestats $recherche',
    ], reason: 'relecture avant, envoi unique, relecture après');
    expect(annulationN, annulationO);
  });

  testWidgets('Annulation : rien n\'est envoyé tant que la confirmation n\'est pas complète', (tester) async {
    ecranHaut(tester);
    await monter(tester, module('Annulation Ventes').nouveau, nouvelle: true);
    await tester.enterText(find.byKey(const Key('champ_recherche')), DonneesLot4.refA);
    await pomper(tester, 8);
    await toucher(tester, find.byKey(const Key('vente_${DonneesLot4.idA}')));
    serveur.oublierRequetes();
    profil('dashboard');
    await toucher(tester, find.byKey(const Key('bouton_annuler_vente')));
    expect(find.byKey(const Key('confirmation_annulation')), findsOneWidget);
    expect(find.text(DonneesLot4.clientA), findsWidgets, reason: 'récapitulatif : client');
    ElevatedButton valider() => tester.widget<ElevatedButton>(find.byKey(const Key('confirmation_oui')));
    expect(valider().onPressed, isNull, reason: 'rien de saisi');
    for (final saisie in ['ANNUL', '261013_0000', '261013_00002', 'OUI']) {
      await tester.enterText(find.byKey(const Key('confirmation_saisie')), saisie);
      await pomper(tester, 2);
      expect(valider().onPressed, isNull, reason: 'saisie incomplète ou fausse : « $saisie »');
      await tester.tap(find.byKey(const Key('confirmation_oui')), warnIfMissed: false);
      await pomper(tester, 2);
      expect(find.byKey(const Key('confirmation_annulation')), findsOneWidget);
    }
    await tester.enterText(find.byKey(const Key('confirmation_saisie')), 'annuler');
    await pomper(tester, 2);
    expect(valider().onPressed, isNotNull, reason: '« ANNULER » (casse ignorée)');
    await toucher(tester, find.byKey(const Key('confirmation_non')));
    expect(find.byKey(const Key('confirmation_annulation')), findsNothing);
    expect(find.text('Annulation abandonnée : rien n\'a été envoyé.'), findsOneWidget);
    expect(requetesVente(), isEmpty, reason: '« Ne pas annuler » : aucune requête, pas même une relecture');
    expect(DonneesLot4.annulees, isEmpty);
    await demonter(tester);
  });
}
