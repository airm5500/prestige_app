// Bout en bout des modules refaits du LOT 4 (« le reste », nouvelle interface) : l'application ENTIÈRE parle en HTTP
// réel au faux serveur Prestige local. Pour chaque module : ouverture depuis l'accueil (recherche de menu,
// présentation B), chiffres clés, période, filtres (feuille du bas) ou recherche locale, détail, récapitulatif,
// retour à l'accueil. Ces modules n'avaient AUCUN export : pas de menu « Exporter » (vérifié), sauf le Récap de
// caisse depuis la 3.6.1 (PDF du ticket Z, demande du pharmacien). Fichier Journal (3.6.1) : pages de 50 demandées au
// serveur (start / limit, mêmes filtres), « Afficher plus » : 50 puis 100.
// Annulation de vente (écriture IRRÉVERSIBLE) : « Ne pas annuler » = aucun envoi ; double appui = UN seul envoi ;
// compte ni administrateur ni pharmacien → code administrateur demandé (refusé = aucun envoi, accepté = un envoi) ;
// refus du serveur affiché ; journal sans référence, client ni montant ; session expirée pendant l'annulation.
// Puis : erreur du serveur et « Réessayer », droit manquant (sans Réessayer), serveur injoignable.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/donnees/recap_caisse_pdf.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/fichier_journal_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/services/pin_securise.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/catalogue_ecrans.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

String jour(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
final aujourdhui = DateTime.now();
final hier = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day - 1);

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

Future<void> retourSysteme(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await stabiliser(tester, tours: 4);
}

ModuleLot1 module(String tuile) => modulesLot4.firstWhere((m) => m.tuile == tuile);

/// Ouvre [m] par la recherche de menu de l'accueil B et attend son nouvel écran (menu « Exporter » : Récap de caisse
/// seulement, PDF du ticket Z depuis la 3.6.1).
Future<void> ouvrir(WidgetTester tester, ModuleLot1 m) async {
  await tester.enterText(find.byKey(const Key('recherche_menu')), m.tuile);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.descendant(of: find.byKey(const Key('defilement_menus')), matching: find.text(m.tuile)).first);
  await attendreWidget(tester, find.byType(m.typeNouveau));
  expect(find.widgetWithText(AppBar, m.titreEcran), findsOneWidget);
  if (m.tuile == 'Récap de caisse') {
    expect(find.byKey(const Key('menu_exports')), findsOneWidget, reason: 'PDF du ticket Z (3.6.1)');
  } else {
    expect(find.byKey(const Key('menu_exports')), findsNothing, reason: 'aucun export à l\'origine');
  }
}

Future<void> revenir(WidgetTester tester, ModuleLot1 m) async {
  await retourSysteme(tester);
  await attendreQue(tester, () => find.byType(m.typeNouveau).evaluate().isEmpty, raison: 'retour depuis ${m.tuile}');
  expect(find.byType(AccueilNouveau).hitTestable(), findsOneWidget);
  await tester.enterText(find.byKey(const Key('recherche_menu')), '');
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> toucher(WidgetTester tester, Finder f, {int tours = 6}) async {
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(f.first);
  await stabiliser(tester, tours: tours);
}

Future<void> choisirPeriode(WidgetTester tester, String nom) => toucher(tester, find.byKey(Key('periode_$nom')), tours: 2);

/// Feuille des filtres : [reglages] puis « Appliquer ».
Future<void> filtrer(WidgetTester tester, Future<void> Function() reglages) async {
  await toucher(tester, find.byKey(const Key('bouton_filtres')));
  expect(find.byKey(const Key('feuille_filtres')), findsOneWidget);
  await reglages();
  await toucher(tester, find.byKey(const Key('filtres_appliquer')));
}

Future<void> choisirDansListe(WidgetTester tester, Finder liste, String option) async {
  await toucher(tester, liste, tours: 4);
  await tester.tap(find.text(option).hitTestable().last);
  await stabiliser(tester, tours: 4);
}

String chiffre(WidgetTester tester, String id) => tester.widget<Text>(find.byKey(Key('chiffre_$id'))).data!;

/// Fait défiler la liste [defilement] jusqu'à [f].
Future<void> amener(WidgetTester tester, Finder f, {String defilement = 'defilement_module'}) async {
  final s = find.descendant(of: find.byKey(Key(defilement)), matching: find.byType(Scrollable)).first;
  for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
    await tester.drag(s, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(f, findsWidgets);
}

/// Saisit [texte] dans la recherche contrôlée et attend l'anti-rebond (0,5 s).
Future<void> rechercher(WidgetTester tester, String texte) async {
  await tester.enterText(find.byKey(const Key('champ_recherche')), texte);
  await tester.pump(const Duration(milliseconds: 600));
  await stabiliser(tester, tours: 2);
}

/// Ouvre le détail de [ligne] (feuille du bas) puis le referme.
Future<void> detail(WidgetTester tester, Finder ligne, {List<String> attendus = const []}) async {
  await amener(tester, ligne);
  await toucher(tester, ligne);
  expect(find.byKey(const Key('feuille_detail')), findsOneWidget);
  for (final t in attendus) {
    expect(find.descendant(of: find.byKey(const Key('feuille_detail')), matching: find.text(t)), findsWidgets, reason: t);
  }
  await toucher(tester, find.byKey(const Key('detail_fermer')));
  expect(find.byKey(const Key('feuille_detail')), findsNothing);
}

/// Compte connecté qui n'est ni administrateur ni pharmacien.
void profilEmploye() => ProfilAcces.utilisateur.value =
    AppUser.fromJson({'str_USER_ID': 'USR-TEST-EMPLOYE', 'str_LOGIN': 'employe', 'xtypeuser': 'mainmenumanager'});

String get cheminAnnulationA => '/vente/annulation/${DonneesLot4.idA}';

/// Annulation : recherche de la vente A, ouverture de son détail, bouton « Annuler cette vente ».
Future<void> ouvrirConfirmation(WidgetTester tester) async {
  await rechercher(tester, '261013');
  await attendreWidget(tester, find.byKey(const Key('vente_${DonneesLot4.idA}')));
  await toucher(tester, find.byKey(const Key('vente_${DonneesLot4.idA}')));
  await attendreWidget(tester, find.text(DonneesLot4.clientA));
  expect(find.text('PRODUIT FICTIF ANNULATION 1'), findsOneWidget);
  await amener(tester, find.byKey(const Key('bouton_annuler_vente')), defilement: 'defilement_detail');
  await toucher(tester, find.byKey(const Key('bouton_annuler_vente')));
  expect(find.byKey(const Key('confirmation_annulation')), findsOneWidget);
}

Future<void> saisirConfirmation(WidgetTester tester, String texte) async {
  await tester.enterText(find.byKey(const Key('confirmation_saisie')), texte);
  await stabiliser(tester, tours: 2);
}

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerNouvelle(serveur, p: Presentation.compact);
    donneesAccueil(serveur);
    donneesLot4(serveur);
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true;
  });

  const routeTicket = '/caisse/fetch-tickez';

  testWidgets('Récap de caisse : jour, chiffres, « Hier », filtre caissier (corps POST), retrait, retour', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    final m = module('Récap de caisse');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_caissiers')));
    expect(serveur.recues(routeTicket).single.json,
        {'description': 'ALL', 'dtStart': jour(aujourdhui), 'dtEnd': jour(aujourdhui), 'hrStart': '00:00', 'hrEnd': '23:59', 'userId': 'ALL'});
    expect(chiffre(tester, 'caissiers'), '2');
    expect(chiffre(tester, 'especes'), '${DonneesLot4.totalEsp} F');
    expect(chiffre(tester, 'vno_vo'), '${DonneesLot4.totalVnoVo} F');
    expect(find.byKey(const Key('caissier_${DonneesLot4.caissier1}')), findsOneWidget);
    await choisirPeriode(tester, 'hier');
    await attendreQue(tester, () => serveur.recues(routeTicket).length == 2, raison: 'hier');
    expect(serveur.recues(routeTicket).last.json, containsPair('dtStart', jour(hier)));
    await stabiliser(tester);
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_caissier')), DonneesLot4.caissier2));
    await attendreQue(tester, () => serveur.recues(routeTicket).length == 3, raison: 'caissier');
    expect(serveur.recues(routeTicket).last.json, containsPair('userId', 'USR-C2'));
    await stabiliser(tester);
    expect(chiffre(tester, 'caissiers'), '1');
    expect(find.text('Caissier : ${DonneesLot4.caissier2}'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('filtres_retirer')));
    await attendreQue(tester, () => serveur.recues(routeTicket).length == 4, raison: 'retrait du filtre');
    expect(serveur.recues(routeTicket).last.json, containsPair('userId', 'ALL'));
    await stabiliser(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Achats Fourn. : chiffres, recherche et filtre LOCAUX, détail, récapitulatif, période, retour', (tester) async {
    telephone(tester);
    const route = AppConstants.achatsFournisseursEndpoint;
    await jusquAccueilNouveau(tester);
    final m = module('Achats Fourn.');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_ttc')));
    expect(serveur.recues(route).single.parametres, {'dtStart': jour(aujourdhui), 'dtEnd': jour(aujourdhui)});
    expect(chiffre(tester, 'ttc'), formaterMontant(DonneesLot4.totalTtc));
    expect(chiffre(tester, 'achats'), '4');
    await rechercher(tester, 'cmd-0004');
    expect(chiffre(tester, 'achats'), '1');
    await rechercher(tester, '');
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_fournisseur')), DonneesLot4.fournisseurB));
    expect(chiffre(tester, 'achats'), '2');
    expect(chiffre(tester, 'ttc'), formaterMontant(59000 + 41300));
    await detail(tester, find.text(DonneesLot4.fournisseurB), attendus: ['BL-B-077', formaterMontant(59000)]);
    await toucher(tester, find.byKey(const Key('achats_recap')));
    expect(find.text('Récapitulatif pour ${DonneesLot4.fournisseurB}'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('feuille_detail')), matching: find.text(formaterMontant(100300))), findsOneWidget);
    await toucher(tester, find.byKey(const Key('detail_fermer')));
    expect(serveur.recues(route), hasLength(1), reason: 'recherche, filtre, détail et récapitulatif locaux');
    await choisirPeriode(tester, 'hier');
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: 'hier');
    expect(serveur.recues(route).last.parametres, {'dtStart': jour(hier), 'dtEnd': jour(hier)});
    await stabiliser(tester);
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Fichier Journal : par le menu et par l\'onglet Équipe, filtres envoyés au serveur, recherche locale, détail', (tester) async {
    telephone(tester);
    const route = AppConstants.fichierJournalEndpoint;
    await jusquAccueilNouveau(tester);
    final m = module('Fichier Journal');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_actions')));
    expect(serveur.recues(route).single.parametres,
        {'dtStart': jour(aujourdhui), 'dtEnd': jour(aujourdhui), 'criteria': '-1', 'userId': '', 'start': '0', 'limit': '50'});
    expect(chiffre(tester, 'actions'), '6');
    await filtrer(tester, () async {
      await choisirDansListe(tester, find.byKey(const Key('filtre_operation')), 'Annulations');
      await choisirDansListe(tester, find.byKey(const Key('filtre_utilisateur')), DonneesLot4.caissier1);
    });
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: 'filtres');
    expect(serveur.recues(route).last.parametres, containsPair('criteria', '4'));
    expect(serveur.recues(route).last.parametres, containsPair('userId', 'USR-C1'));
    await stabiliser(tester);
    expect(chiffre(tester, 'actions'), '2');
    await rechercher(tester, 'N6');
    expect(chiffre(tester, 'actions'), '1');
    await detail(tester, find.text('Action fictive N6'), attendus: [DonneesLot4.caissier1, 'Annulation']);
    expect(serveur.recues(route), hasLength(2), reason: 'recherche et détail locaux');
    await revenir(tester, m);

    // Onglet Équipe → « Fichier Journal » ouvre aussi le nouvel écran.
    await ouvrirOnglet(tester, 'Équipe');
    await stabiliser(tester);
    final lien = find.text('Fichier Journal');
    await tester.ensureVisible(lien.last);
    await tester.tap(lien.last);
    await attendreWidget(tester, find.byType(FichierJournalNouveau));
    await retourSysteme(tester);
    await terminer(tester);
  });

  testWidgets('Fichier Journal (3.6.1) : 50 actions, « Afficher plus » → 100 (page suivante du serveur, mêmes filtres)', (tester) async {
    telephone(tester);
    const route = AppConstants.fichierJournalEndpoint;
    serveur.route(route, (r) => DonneesLot4.journalPour(r, nombre: 120), methode: 'GET');
    await jusquAccueilNouveau(tester);
    final m = module('Fichier Journal');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_actions')));
    final du = {'dtStart': jour(aujourdhui), 'dtEnd': jour(aujourdhui), 'criteria': '-1', 'userId': ''};
    expect(serveur.recues(route).single.parametres, {...du, 'start': '0', 'limit': '50'});
    expect(chiffre(tester, 'actions'), '120', reason: 'total annoncé par le serveur');
    expect(find.byKey(const Key('journal_limite')), findsNothing, reason: 'le serveur pagine : aucune limite');
    await amener(tester, find.byKey(const Key('bouton_afficher_plus')));
    expect(find.text('50 lignes affichées sur 120'), findsOneWidget);
    await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
    await attendreQue(tester, () => serveur.recues(route).length == 2, raison: 'page suivante');
    expect(serveur.recues(route).last.parametres, {...du, 'start': '50', 'limit': '50'});
    await amener(tester, find.text('100 lignes affichées sur 120'));
    await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
    await attendreQue(tester, () => serveur.recues(route).length == 3, raison: 'dernière page');
    expect(serveur.recues(route).last.parametres, {...du, 'start': '100', 'limit': '50'});
    await amener(tester, find.text('120 lignes affichées sur 120'));
    expect(find.byKey(const Key('bouton_afficher_plus')), findsNothing, reason: 'tout est chargé');

    // Filtre : nouvelle lecture depuis le début, puis page suivante avec les MÊMES filtres.
    await tester.drag(find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first, const Offset(0, 30000));
    await stabiliser(tester, tours: 2);
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_operation')), 'Annulations'));
    await attendreQue(tester, () => serveur.recues(route).length == 4, raison: 'filtre');
    expect(serveur.recues(route).last.parametres, {...du, 'criteria': '4', 'start': '0', 'limit': '50'});
    await stabiliser(tester);
    expect(chiffre(tester, 'actions'), '60');
    await amener(tester, find.byKey(const Key('bouton_afficher_plus')));
    await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
    await attendreQue(tester, () => serveur.recues(route).length == 5, raison: 'page suivante filtrée');
    expect(serveur.recues(route).last.parametres, {...du, 'criteria': '4', 'start': '50', 'limit': '50'});
    await amener(tester, find.text('60 lignes affichées sur 60'));
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Récap de caisse (3.6.1) : Exporter → PDF du ticket Z, mêmes montants que l\'écran, aucune requête', (tester) async {
    telephone(tester);
    final sorties = <(ContenuTicketZ, String)>[];
    final avant = RecapCaissePdf.sortie;
    RecapCaissePdf.sortie = (c, nom) async => sorties.add((c, nom));
    addTearDown(() => RecapCaissePdf.sortie = avant);
    await jusquAccueilNouveau(tester);
    final m = module('Récap de caisse');
    await ouvrir(tester, m);
    await attendreWidget(tester, find.byKey(const Key('chiffre_caissiers')));
    await stabiliser(tester);
    final ecran = {
      for (final id in ['caissiers', 'especes', 'vno_vo', 'totaux']) id: chiffre(tester, id),
    };
    final requetes = serveur.recues(routeTicket).length;

    await toucher(tester, find.byKey(const Key('menu_exports')));
    expect(find.text('PDF du ticket Z'), findsOneWidget);
    await toucher(tester, find.text('PDF du ticket Z'));
    await attendreQue(tester, () => sorties.isNotEmpty, raison: 'PDF produit');
    final (contenu, nom) = sorties.single;
    expect(nom, 'Ticket_Z_${jour(aujourdhui)}');
    expect(serveur.recues(routeTicket), hasLength(requetes), reason: 'aucune requête : le PDF reprend l\'écran');
    expect(contenu.officine, DonneesFictives.nomOfficine);
    expect(contenu.caissier, 'Tous les utilisateurs');
    expect(contenu.heures, 'de 00:00 à 23:59');
    expect(contenu.periode, startsWith('Aujourd\'hui · '));
    expect(contenu.chiffres, [
      ('Caissiers', ecran['caissiers']),
      ('Espèces', ecran['especes']),
      ('Total (VNO/VO)', ecran['vno_vo']),
      ('Totaux globaux', ecran['totaux']),
    ]);
    expect(contenu.lignes, containsAllInOrder([
      'Espèces : ${DonneesLot4.totalEsp} F',
      'TOTAL ESP : ${DonneesLot4.totalEsp} F',
      'TOTAL DIFFERE : -2 000 F',
      'TOTAL (VNO/VO) : ${DonneesLot4.totalVnoVo} F',
      DonneesLot4.caissier1,
      'Espèces : 125 000 F',
      'Total encaissé : 143 400 F',
      DonneesLot4.caissier2,
      'Total Sortie Vir : -1 500 F',
    ]));
    // Le PDF lui-même se fabrique (A4, en-tête de l'officine).
    final octets = await tester.runAsync(() => RecapCaissePdf.octets(contenu, compresser: false));
    expect(String.fromCharCodes(octets!.take(5)), '%PDF-');

    // Filtre caissier et heures : repris dans le PDF.
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_caissier')), DonneesLot4.caissier2));
    await attendreQue(tester, () => serveur.recues(routeTicket).length == requetes + 1, raison: 'caissier');
    await stabiliser(tester);
    await toucher(tester, find.byKey(const Key('menu_exports')));
    await toucher(tester, find.text('PDF du ticket Z'));
    await attendreQue(tester, () => sorties.length == 2, raison: 'second PDF');
    expect(sorties.last.$1.caissier, DonneesLot4.caissier2);
    expect(sorties.last.$1.caissiers.map((c) => c.nom), [DonneesLot4.caissier2]);
    expect(sorties.last.$1.chiffres.first, ('Caissiers', '1'));
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Annulation : « Ne pas annuler » = aucun envoi ; double appui = UN seul envoi ; vente marquée annulée', (tester) async {
    telephone(tester);
    final journal = <String>[];
    final sortie = JournalApp.sortie;
    JournalApp.actif = true;
    JournalApp.sortie = journal.add;
    addTearDown(() {
      JournalApp.sortie = sortie;
      JournalApp.actif = false;
    });
    await jusquAccueilNouveau(tester);
    final m = module('Annulation Ventes');
    await ouvrir(tester, m);
    expect(serveur.recues('/ventestats'), isEmpty, reason: 'rien sans numéro de vente');
    await ouvrirConfirmation(tester);
    expect(serveur.recues(cheminAnnulationA), isEmpty);

    // 1. « Ne pas annuler » : aucun envoi (ni relecture).
    serveur.oublierRequetes();
    await saisirConfirmation(tester, 'ANNULER');
    await toucher(tester, find.byKey(const Key('confirmation_non')));
    expect(find.byKey(const Key('confirmation_annulation')), findsNothing);
    expect(find.text('Annulation abandonnée : rien n\'a été envoyé.'), findsOneWidget);
    expect(serveur.requetes.where((r) => r.chemin.startsWith('/ventestats') || r.chemin.startsWith('/vente/')), isEmpty);

    // 2. Double appui sur « Annuler la vente », puis appuis pendant l'envoi : UN seul GET d'annulation.
    serveur.route(cheminAnnulationA, (_) {
      DonneesLot4.annulees.add(DonneesLot4.idA);
      return ReponseFausse.json({'success': true}).apres(const Duration(milliseconds: 800));
    }, methode: 'GET');
    await amener(tester, find.byKey(const Key('bouton_annuler_vente')), defilement: 'defilement_detail');
    await toucher(tester, find.byKey(const Key('bouton_annuler_vente')));
    await saisirConfirmation(tester, DonneesLot4.refA);
    await tester.tap(find.byKey(const Key('confirmation_oui')));
    await tester.tap(find.byKey(const Key('confirmation_oui')), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    await attendreWidget(tester, find.byKey(const Key('annulation_en_cours')));
    expect(find.byKey(const Key('bouton_annuler_vente')), findsNothing, reason: 'bouton remplacé par l\'indicateur pendant l\'envoi');
    await tester.binding.handlePopRoute(); // retour refusé pendant l'envoi
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Détail de la vente'), findsOneWidget);
    await attendreWidget(tester, find.byKey(const Key('resultat_annulation')));
    await stabiliser(tester);
    expect(serveur.recues(cheminAnnulationA), hasLength(1), reason: 'double appui : un seul envoi');
    expect(serveur.recues(cheminAnnulationA).single.methode, 'GET', reason: 'même route qu\'aujourd\'hui');
    expect(find.text('Vente annulée avec succès'), findsWidgets);
    expect(find.byKey(const Key('etat_annulee')), findsOneWidget);
    expect(find.byKey(const Key('bouton_annuler_vente')), findsNothing, reason: 'vente annulée : plus aucune action');

    // Retour à la liste : relue, la vente apparaît annulée.
    final avant = serveur.recues('/ventestats').length;
    await retourSysteme(tester);
    await attendreQue(tester, () => serveur.recues('/ventestats').length > avant, raison: 'liste relue');
    await stabiliser(tester);
    expect(chiffre(tester, 'annulees'), '1');
    // Journal : l'issue seulement, sans référence, client ni montant.
    expect(journal, contains('Annulation de vente : annulee'));
    for (final ligne in journal) {
      expect(ligne, isNot(contains(DonneesLot4.refA)));
      expect(ligne, isNot(contains(DonneesLot4.clientA)));
      expect(ligne, isNot(contains('2500')));
      expect(ligne, isNot(contains('261013')), reason: 'numéro recherché retiré des adresses');
    }
    await revenir(tester, m);
    await terminer(tester);
  });

  testWidgets('Annulation : compte non responsable → code administrateur demandé (refusé : aucun envoi ; accepté : un envoi)',
      (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    expect(await tester.runAsync(() => CodeAdmin.instance.definir('5917')), isNull);
    profilEmploye();
    await ouvrir(tester, module('Annulation Ventes'));
    await ouvrirConfirmation(tester);
    await saisirConfirmation(tester, 'ANNULER');
    await toucher(tester, find.byKey(const Key('confirmation_oui')));
    await attendreWidget(tester, find.byKey(const Key('pin_admin_saisie')));
    expect(find.text('Code Administrateur requis :'), findsOneWidget);
    await toucher(tester, find.text('Annuler'));
    expect(find.text('Code administrateur non validé : la vente n\'a pas été annulée.'), findsOneWidget);
    expect(serveur.recues(cheminAnnulationA), isEmpty, reason: 'code refusé : rien n\'est envoyé');

    await amener(tester, find.byKey(const Key('bouton_annuler_vente')), defilement: 'defilement_detail');
    await toucher(tester, find.byKey(const Key('bouton_annuler_vente')));
    await saisirConfirmation(tester, 'ANNULER');
    await toucher(tester, find.byKey(const Key('confirmation_oui')));
    await attendreWidget(tester, find.byKey(const Key('pin_admin_saisie')));
    await tester.enterText(find.byKey(const Key('pin_admin_saisie')), '5917');
    await tester.tap(find.text('Valider'));
    await attendreWidget(tester, find.byKey(const Key('resultat_annulation')));
    await stabiliser(tester);
    expect(serveur.recues(cheminAnnulationA), hasLength(1));
    expect(DonneesLot4.annulees, {DonneesLot4.idA});
    await terminer(tester);
  });

  testWidgets('Annulation : refus du serveur (droit) affiché, vente non annulée ; détail en échec = aucune action possible', (tester) async {
    telephone(tester);
    serveur.quand(cheminAnnulationA, ReponseFausse.json({'success': false, 'msg': 'Vous n\'avez pas l\'autorisation d\'annuler une vente'}),
        methode: 'GET');
    serveur.quand('/ventestats/find-one/${DonneesLot4.idB}', ReponseFausse.erreurServeur(), methode: 'GET');
    await jusquAccueilNouveau(tester);
    await ouvrir(tester, module('Annulation Ventes'));
    await ouvrirConfirmation(tester);
    await saisirConfirmation(tester, 'ANNULER');
    await toucher(tester, find.byKey(const Key('confirmation_oui')));
    await attendreWidget(tester, find.byKey(const Key('resultat_annulation')));
    expect(find.text('Vous n\'avez pas l\'autorisation d\'annuler une vente'), findsWidgets);
    expect(find.byKey(const Key('etat_active')), findsOneWidget, reason: 'vente toujours non annulée');
    expect(serveur.recues(cheminAnnulationA), hasLength(1));
    await retourSysteme(tester);
    await stabiliser(tester);

    // Détail illisible (500) : erreur avec « Réessayer », et aucun bouton d'annulation.
    await amener(tester, find.byKey(const Key('vente_${DonneesLot4.idB}')));
    await toucher(tester, find.byKey(const Key('vente_${DonneesLot4.idB}')));
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.byKey(const Key('erreur_serveur')), findsOneWidget);
    expect(find.byKey(const Key('bouton_annuler_vente')), findsNothing);
    expect(serveur.recues('/vente/annulation/${DonneesLot4.idB}'), isEmpty);
    await terminer(tester);
  });

  testWidgets('erreurs : 500 puis « Réessayer », droit manquant (sans Réessayer), serveur injoignable — ni licence ni déconnexion',
      (tester) async {
    telephone(tester);
    serveur.quand(routeTicket, ReponseFausse.erreurServeur(), methode: 'POST');
    serveur.quand(AppConstants.fichierJournalEndpoint, ReponseFausse.texte('Interdit', statut: 403), methode: 'GET');
    await jusquAccueilNouveau(tester);
    final recap = module('Récap de caisse');
    await ouvrir(tester, recap);
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.byKey(const Key('erreur_serveur')), findsOneWidget);
    expect(find.textContaining('NullPointer'), findsNothing);
    serveur.route(routeTicket, (r) => ReponseFausse.json(DonneesLot4.ticketZ('ALL')), methode: 'POST');
    await toucher(tester, find.byKey(const Key('bouton_reessayer')));
    await attendreWidget(tester, find.byKey(const Key('chiffre_caissiers')));
    await revenir(tester, recap);

    final journal = module('Fichier Journal');
    await ouvrir(tester, journal);
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.text('Droit manquant'), findsOneWidget);
    expect(find.byKey(const Key('bouton_reessayer')), findsNothing, reason: 'réessayer ne changerait rien');
    await revenir(tester, journal);

    await tester.runAsync(serveur.arreter);
    final achats = module('Achats Fourn.');
    await ouvrir(tester, achats);
    await attendreWidget(tester, find.byType(EtatErreur));
    expect(find.byKey(const Key('erreur_reseau')), findsOneWidget);
    expect(find.byKey(const Key('bouton_reessayer')), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    await terminer(tester);
  });

  testWidgets('session expirée pendant l\'annulation → connexion avec message, rien d\'annulé', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrir(tester, module('Annulation Ventes'));
    await ouvrirConfirmation(tester);
    await saisirConfirmation(tester, 'ANNULER');
    serveur.expirerSessions();
    await toucher(tester, find.byKey(const Key('confirmation_oui')));
    await attendreWidget(tester, find.byType(LoginScreen));
    await attendreTexte(tester, AuthProvider.messageSessionExpiree);
    expect(serveur.recues(cheminAnnulationA), isEmpty, reason: 'relecture refusée avant l\'envoi : rien n\'est envoyé');
    expect(DonneesLot4.annulees, isEmpty);
    await tester.tap(find.text('OK'));
    await stabiliser(tester);
    await seConnecterNouvelle(tester);
    await attendreWidget(tester, find.byType(AccueilNouveau));
    await terminer(tester);
  });
}
