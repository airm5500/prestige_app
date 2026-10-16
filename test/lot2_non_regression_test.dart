// Non-régression des DONNÉES du lot 2 (achats et stock) : pour chaque module refait (Suggestions, État de Stock,
// Visualisation BL, État Contrôle Achat, Retours fournisseurs, Évolution stock, Analyse Saisies BL, Suivi
// Ajustements), l'écran d'ORIGINE et le NOUVEL écran sont montés tour à tour contre le même faux serveur
// (support/donnees_lot2.dart) :
//  - mêmes requêtes (routes, paramètres et, pour les ÉCRITURES des Suggestions, mêmes corps de requête : quantité,
//    suppressions, passage « en cours »), à l'ouverture, après une recherche, un filtre, une page suivante ;
//  - mêmes chiffres affichés (montants normalisés : « 23 600 FCFA » = « 23 600 F »), mêmes lignes.
// Horloge simulée, client en mémoire ; écran haut (411 × 5000 dp) pour que toutes les lignes soient construites,
// écran de téléphone pour les pages suivantes (chargées au défilement par les écrans d'origine).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import 'support/application.dart';
import 'support/cas_affichage.dart';
import 'support/catalogue_ecrans.dart';
import 'support/donnees_fictives.dart';
import 'support/donnees_lot2.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/polices.dart';

final serveur = FauxServeurPrestige();

/// « 23 600 FCFA », « 23 600 F » → « 23600 ».
String norm(String s) => s.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(RegExp(r'(FCFA|F)$'), '');

String? texteDe(Widget w) => w is Text ? (w.data ?? w.textSpan?.toPlainText()) : (w is RichText ? w.text.toPlainText() : null);

List<String> textes() => [for (final e in find.byType(RichText).evaluate()) (e.widget as RichText).text.toPlainText()];

/// Montants affichés (normalisés), aussi au milieu d'une ligne.
Set<String> montants() => {
      for (final t in textes())
        for (final m in RegExp(r'(-?\d[\d\s  ]*?)[\s  ]*(FCFA|F)\b').allMatches(t)) norm(m.group(1)!),
    };

/// Valeur affichée pour [libelle] dans un NOUVEL écran : ligne de détail, chiffre clé ou carte de liste.
String valeurNouvelle(String libelle) {
  for (final e in find.byType(LigneDetail).evaluate()) {
    final w = e.widget as LigneDetail;
    if (w.libelle == libelle) return w.valeur;
  }
  for (final e in find.byType(ChiffreCle).evaluate()) {
    final w = e.widget as ChiffreCle;
    if (w.libelle == libelle) return w.valeur;
  }
  fail('libellé « $libelle » absent du nouvel écran');
}

/// Valeur qui suit [libelle] dans son conteneur (écran d'origine).
String valeurAncienne(String libelle, {Finder? dans}) {
  final f = dans == null ? find.text(libelle) : find.descendant(of: dans, matching: find.text(libelle));
  expect(f, findsWidgets, reason: 'libellé d\'origine « $libelle »');
  final parent = find.ancestor(of: f.first, matching: find.byWidgetPredicate((w) => w is Row || w is Column)).first;
  final t = [for (final e in find.descendant(of: parent, matching: find.byType(Text)).evaluate()) texteDe(e.widget) ?? ''];
  return t[t.indexOf(libelle) + 1];
}

/// Requêtes reçues (hors connexion), décrites par méthode, chemin, paramètres et corps JSON.
List<String> journal(bool Function(RequeteRecue r) garder) => [
      for (final r in serveur.requetes)
        if (garder(r)) '${r.methode} ${r.chemin} ${r.parametres}${r.corps.isEmpty ? '' : ' ${r.json}'}',
    ];

List<Map<String, String>> params(String chemin) => [for (final r in serveur.recues(chemin)) r.parametres];

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

/// Fait défiler la liste du nouvel écran jusqu'à [f] (liste paresseuse : « Afficher plus » est en bas).
Future<void> amener(WidgetTester tester, Finder f) async {
  final s = find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first;
  for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
    await tester.drag(s, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> toucher(WidgetTester tester, Finder f, [int fois = 8]) async {
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(f.first);
  await pomper(tester, fois);
}

/// Choisit [option] dans une liste déroulante (écran d'origine ou feuille des filtres).
Future<void> choisirDansListe(WidgetTester tester, Finder liste, String option) async {
  // Le texte d'une liste déroulante d'origine existe en double (élément affiché et réserve de mesure).
  await toucher(tester, liste.hitTestable().evaluate().isNotEmpty ? liste.hitTestable() : liste, 5);
  // Seule l'option du menu ouvert est touchable (les cartes de la liste sont sous le menu).
  await tester.tap(find.text(option).hitTestable().last);
  await pomper(tester, 8);
}

/// Feuille des filtres du nouvel écran : [reglages] puis « Appliquer » (ou le libellé du bouton).
Future<void> filtrer(WidgetTester tester, Future<void> Function() reglages) async {
  await toucher(tester, find.byKey(const Key('bouton_filtres')), 6);
  await reglages();
  await toucher(tester, find.byKey(const Key('filtres_appliquer')));
}

ModuleLot1 module(String tuile) => modulesLot2.firstWhere((m) => m.tuile == tuile);

String jour(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

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
    donneesLot2(serveur);
  });

  void ecranHaut(WidgetTester tester) {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(411 * 2.625, 5000 * 2.625);
    addTearDown(tester.view.reset);
  }

  void telephone(WidgetTester tester) {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
    addTearDown(tester.view.reset);
  }

  bool suggestion(RequeteRecue r) => r.chemin.startsWith('/suggestion');

  // -------------------------------------------------------------------------------------------------------------
  // Suggestions (écritures)
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Suggestions : mêmes lectures, MÊMES ÉCRITURES (corps compris) et mêmes montants', (tester) async {
    ecranHaut(tester);
    final m = module('Suggestions');

    // --- Origine ---
    await monter(tester, m.ancien, nouvelle: false);
    final ouvertureO = journal(suggestion);
    expect(find.text(DonneesLot2.grossisteA), findsOneWidget);
    serveur.oublierRequetes();
    await toucher(tester, find.byTooltip('Ouvrir la suggestion'));
    final detailO = journal(suggestion);
    final montantsO = montants();
    // Quantité refusée (vide) : rien n'est envoyé.
    serveur.oublierRequetes();
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pomper(tester, 5);
    final refusO = journal(suggestion);
    expect(find.text('Quantité invalide (0 à 99999) : non enregistrée.'), findsOneWidget);
    await pomper(tester, 50);
    // Quantité 24 sur la première ligne.
    serveur.oublierRequetes();
    await tester.enterText(find.byType(TextFormField).first, '24');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pomper(tester);
    final quantiteO = journal(suggestion);
    // Suppression d'une ligne : « Non » puis « Oui ».
    serveur.oublierRequetes();
    await toucher(tester, find.byIcon(Icons.delete).at(1), 5);
    await toucher(tester, find.text('Non'), 5);
    final annuleO = journal(suggestion);
    await toucher(tester, find.byIcon(Icons.delete).at(1), 5);
    await toucher(tester, find.text('Oui, Supprimer'));
    final ligneO = journal(suggestion);
    // Retour à la liste, suppression de la suggestion.
    await tester.binding.handlePopRoute();
    await pomper(tester);
    serveur.oublierRequetes();
    await toucher(tester, find.byTooltip('Supprimer'), 5);
    await toucher(tester, find.text('Oui, Supprimer'));
    final suppressionO = journal(suggestion);
    await demonter(tester);

    // --- Nouvelle interface ---
    await monter(tester, m.nouveau, nouvelle: true);
    final ouvertureN = journal(suggestion);
    serveur.oublierRequetes();
    await toucher(tester, find.text(DonneesLot2.grossisteA));
    final detailN = journal(suggestion);
    final montantsN = montants();
    final achatN = norm(valeurNouvelle('Montant Achat'));
    serveur.oublierRequetes();
    await tester.enterText(find.byKey(const Key('qte_${DonneesLot2.article1}')), '');
    await toucher(tester, find.byKey(const Key('qte_enregistrer_${DonneesLot2.article1}')), 5);
    final refusN = journal(suggestion);
    expect(find.text('Quantité invalide (0 à 99999) : non enregistrée.'), findsOneWidget);
    await pomper(tester, 50);
    serveur.oublierRequetes();
    await tester.enterText(find.byKey(const Key('qte_${DonneesLot2.article1}')), '24');
    await toucher(tester, find.byKey(const Key('qte_enregistrer_${DonneesLot2.article1}')));
    final quantiteN = journal(suggestion);
    serveur.oublierRequetes();
    await toucher(tester, find.byKey(const Key('ligne_supprimer_${DonneesLot2.article2}')), 5);
    await toucher(tester, find.byKey(const Key('confirmer_non')), 5);
    final annuleN = journal(suggestion);
    await toucher(tester, find.byKey(const Key('ligne_supprimer_${DonneesLot2.article2}')), 5);
    await toucher(tester, find.byKey(const Key('confirmer_oui')));
    final ligneN = journal(suggestion);
    await tester.binding.handlePopRoute();
    await pomper(tester);
    serveur.oublierRequetes();
    await toucher(tester, find.byKey(const Key('suggestion_menu_${DonneesLot2.suggestion1}')), 5);
    await toucher(tester, find.byKey(const Key('suggestion_supprimer')), 5);
    await toucher(tester, find.byKey(const Key('confirmer_oui')));
    final suppressionN = journal(suggestion);
    await demonter(tester);

    expect(ouvertureO, ['GET /suggestion/list {limit: 50}']);
    expect(ouvertureN, ouvertureO);
    expect(detailO, [
      'GET /suggestion/set-pending/${DonneesLot2.suggestion1} {}',
      'GET /suggestion/list/items {orderId: ${DonneesLot2.suggestion1}, limit: 9999}',
      'GET /suggestion/amount/${DonneesLot2.suggestion1} {}',
    ]);
    expect(detailN, detailO, reason: 'ouverture d\'une suggestion : même écriture (set-pending) puis mêmes lectures');
    expect(refusO, isEmpty);
    expect(refusN, isEmpty, reason: 'quantité refusée : rien n\'est envoyé');
    expect(quantiteO, [
      'POST /suggestion/item/update-qte-cmde {} {itemId: ${DonneesLot2.article1}, qte: 24}',
      'GET /suggestion/amount/${DonneesLot2.suggestion1} {}',
    ]);
    expect(quantiteN, quantiteO, reason: 'même corps {itemId, qte} (qte entier), puis relecture des montants');
    expect(serveur.requetes.where((r) => r.methode == 'POST' && r.chemin == AppConstants.suggestionUpdateQteEndpoint), isEmpty);
    expect(annuleO, isEmpty);
    expect(annuleN, isEmpty, reason: '« Non » : aucune suppression');
    expect(ligneO, [
      'DELETE /suggestion/item/${DonneesLot2.article2} {}',
      'GET /suggestion/list/items {orderId: ${DonneesLot2.suggestion1}, limit: 9999}',
      'GET /suggestion/amount/${DonneesLot2.suggestion1} {}',
    ]);
    expect(ligneN, ligneO);
    expect(suppressionO, ['DELETE /suggestion/suggestion/${DonneesLot2.suggestion1} {}', 'GET /suggestion/list {limit: 50}']);
    expect(suppressionN, suppressionO);
    expect(achatN, '${DonneesLot2.montantAchat}');
    expect(montantsO, contains('${DonneesLot2.montantAchat}'));
    expect(montantsO.difference(montantsN), isEmpty, reason: 'tout montant d\'origine (prix, montant d\'achat) est affiché');
  });

  // -------------------------------------------------------------------------------------------------------------
  // État de Stock
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('État de Stock : mêmes requêtes (listes, recherche, emplacement, filtre de stock) et mêmes stocks', (tester) async {
    ecranHaut(tester);
    final m = module('Etat de Stock');
    const route = '/fichearticle/comparaison';
    Map<String, String> stocksO = {}, stocksN = {};

    await monter(tester, m.ancien, nouvelle: false);
    final listesO = journal((r) => r.chemin.startsWith('/common'));
    await tester.enterText(find.byType(TextField).first, 'fictif');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pomper(tester);
    for (final e in find.byType(ListTile).evaluate()) {
      final t = [for (final x in find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text)).evaluate()) texteDe(x.widget)!];
      stocksO[t.first] = t.last;
    }
    await choisirDansListe(tester, find.text('Emplacement'), 'RAYON A');
    await choisirDansListe(tester, find.text('Stock...'), 'Inférieur (<)');
    // Filtre de stock sans quantité : refusé, rien n'est envoyé.
    final avant = serveur.recues(route).length;
    await toucher(tester, find.text('APPLIQUER FILTRES'));
    expect(serveur.recues(route).length, avant);
    await tester.enterText(find.widgetWithText(TextField, 'Qté'), '30');
    await toucher(tester, find.text('APPLIQUER FILTRES'));
    final reqO = params(route);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final listesN = journal((r) => r.chemin.startsWith('/common'));
    expect(serveur.recues(route), isEmpty, reason: 'rien n\'est cherché avant une recherche (comme l\'origine)');
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'fictif');
    await pomper(tester, 12);
    for (final e in find.byType(CarteLigne).evaluate()) {
      final c = e.widget as CarteLigne;
      stocksN[c.titre] = c.valeur!;
    }
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_emplacement')), 'RAYON A'));
    await filtrer(tester, () async {
      await toucher(tester, find.byKey(const Key('filtre_stock_LESS')), 3);
      final avant = serveur.recues(route).length;
      await toucher(tester, find.byKey(const Key('filtres_appliquer')), 3);
      expect(serveur.recues(route).length, avant, reason: 'quantité manquante : refusée');
      expect(find.byKey(const Key('feuille_filtres')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('filtre_quantite')), '30');
      await tester.pump();
    });
    final reqN = params(route);
    await demonter(tester);

    expect(listesO, ['GET /common/rayons {limit: 9999, page: 1, start: 0}', 'GET /common/grossiste {limit: 9999, page: 1, start: 0}']);
    expect(listesN, listesO);
    expect(reqO, hasLength(3));
    expect(reqN, reqO, reason: 'recherche, puis emplacement, puis « stock < 30 » : mêmes paramètres');
    expect(reqO.last, containsPair('filtreStock', 'LESS'));
    expect(reqO.last, containsPair('stock', '30'));
    expect(reqO.last, containsPair('codeRayon', 'RAY-A'));
    expect(stocksO, hasLength(15));
    expect(stocksN, stocksO);
  });

  testWidgets('État de Stock : page suivante (défilement d\'origine = « Afficher plus ») avec les mêmes paramètres', (tester) async {
    telephone(tester);
    final m = module('Etat de Stock');
    const route = '/fichearticle/comparaison';
    await monter(tester, m.ancien, nouvelle: false);
    await tester.enterText(find.byType(TextField).first, 'fictif');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pomper(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await pomper(tester);
    final reqO = params(route);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'fictif');
    await pomper(tester, 12);
    await amener(tester, find.byKey(const Key('bouton_afficher_plus')));
    await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
    final reqN = params(route);
    await amener(tester, find.text('19 lignes affichées sur 19'));
    expect(find.text('19 lignes affichées sur 19'), findsOneWidget);
    await demonter(tester);

    expect(reqO, hasLength(2));
    expect(reqO.last, containsPair('page', '2'));
    expect(reqO.last, containsPair('start', '15'));
    expect(reqN, reqO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // Visualisation BL
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Visualisation BL : mêmes requêtes (ouverture, statut, grossiste) et mêmes totaux', (tester) async {
    ecranHaut(tester);
    final m = module('Visualisation BL');
    const route = '/etat-control-bon/list';
    await monter(tester, m.ancien, nouvelle: false);
    final listesO = journal((r) => r.chemin != route);
    final ouvertureO = params(route);
    final totauxO = {for (final l in ['Total BL', 'HT', 'TVA', 'TTC']) l: norm(valeurAncienne('$l: '))};
    await choisirDansListe(tester, find.text('Statut'), 'Terminé');
    // Menu d'origine : libellés de plus de 15 caractères tronqués (« GROSSISTE FICTI... ») ; le dernier est B.
    await choisirDansListe(tester, find.text('Grossiste'), 'GROSSISTE FICTI...');
    final filtresO = params(route);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final listesN = journal((r) => r.chemin != route);
    final ouvertureN = params(route);
    final totauxN = {for (final l in ['Total BL', 'HT', 'TVA', 'TTC']) l: norm(valeurNouvelle(l))};
    await filtrer(tester, () => toucher(tester, find.byKey(const Key('filtre_statut_CONTROLE')), 3));
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_grossiste')), DonneesLot2.grossisteB));
    final filtresN = params(route);
    await demonter(tester);

    expect(listesN, listesO, reason: 'grossistes, groupes, utilisateurs : mêmes appels, même ordre');
    expect(ouvertureO, hasLength(1));
    expect(ouvertureO.single, containsPair('dtStart', jour(DateTime.now())));
    expect(ouvertureN, ouvertureO, reason: 'aujourd\'hui, page 1, 20 lignes, tri : mêmes paramètres');
    expect(totauxO['Total BL'], '${DonneesLot2.bonsLivraison}');
    expect(totauxN, totauxO);
    expect(filtresO.last, containsPair('checked', 'TERMINE'));
    expect(filtresO.last, containsPair('grossisteId', 'GRO-B'));
    // 3.8.0 (A1, décision du pharmacien) : la nouvelle interface envoie le statut dans « statutControle » (lu par le
    // serveur : CONTROLE = contrôle terminé = « TERMINE » d'origine) au lieu de « checked » (ignoré par le serveur).
    // Seule différence admise : checked vide + statutControle ; tous les autres paramètres restent identiques.
    expect(filtresN, [
      for (final p in filtresO) {...p, 'checked': '', if (p['checked']!.isNotEmpty) 'statutControle': 'CONTROLE'},
    ]);
  });

  testWidgets('Visualisation BL : page suivante (défilement d\'origine = « Afficher plus ») avec les mêmes paramètres', (tester) async {
    telephone(tester);
    final m = module('Visualisation BL');
    const route = '/etat-control-bon/list';
    await monter(tester, m.ancien, nouvelle: false);
    for (var i = 0; i < 6 && serveur.recues(route).length < 2; i++) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await pomper(tester, 5);
    }
    final reqO = params(route);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    await amener(tester, find.byKey(const Key('bouton_afficher_plus')));
    await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
    final reqN = params(route);
    await amener(tester, find.text('${DonneesLot2.bonsLivraison} lignes affichées sur ${DonneesLot2.bonsLivraison}'));
    expect(find.text('${DonneesLot2.bonsLivraison} lignes affichées sur ${DonneesLot2.bonsLivraison}'), findsOneWidget);
    await demonter(tester);

    expect(reqO, hasLength(2));
    expect(reqO.last, containsPair('start', '20'));
    expect(reqN, reqO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // État Contrôle Achat
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('État Contrôle Achat : mêmes requêtes (jour, groupe) et mêmes totaux et montants', (tester) async {
    ecranHaut(tester);
    final m = module('Etat Contrôle Achat');
    const route = AppConstants.etatControleAchatEndpoint;
    const totaux = ['Total Bons', 'Total Achats HT', 'Total TVA', 'Total Achats TTC', 'Total Ventes TTC', 'Total Marge'];
    await monter(tester, m.ancien, nouvelle: false);
    final groupesO = params('/groupegrossiste');
    await toucher(tester, find.text('Rechercher'));
    final jourO = params(route);
    final totauxO = {for (final t in totaux) t: norm(valeurAncienne('$t:'))};
    final montantsO = montants();
    serveur.oublierRequetes();
    await choisirDansListe(tester, find.text('Tous les groupes').first, 'GROUPE FICTIF A');
    await toucher(tester, find.text('Rechercher'));
    final groupeO = params(route);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final groupesN = params('/groupegrossiste');
    final jourN = params(route);
    final totauxN = {for (final t in totaux) t: norm(valeurNouvelle(t))};
    final montantsN = montants();
    serveur.oublierRequetes();
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_groupe')), 'GROUPE FICTIF A'));
    final groupeN = params(route);
    await demonter(tester);

    expect(groupesN, groupesO);
    expect(jourO.single, {'dtStart': jour(DateTime.now()), 'dtEnd': jour(DateTime.now()), 'groupeId': '', 'groupBy': 'GROUP', 'limit': '9999'});
    expect(jourN, jourO);
    expect(groupeO.single, containsPair('groupeId', '1'));
    expect(groupeN, groupeO);
    expect(totauxO['Total Bons'], '${DonneesFictives.bonsControles}');
    expect(totauxN, totauxO);
    expect(montantsO.difference(montantsN), isEmpty, reason: 'montants des groupes et totaux');
  });

  // -------------------------------------------------------------------------------------------------------------
  // Retours fournisseurs
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Retours fournisseurs : mêmes requêtes (jour, filtres, détail, produits) et mêmes montants', (tester) async {
    ecranHaut(tester);
    final m = module('Retours Fournisseurs');
    const route = AppConstants.retoursFournisseursEndpoint;
    await monter(tester, m.ancien, nouvelle: false);
    final fournisseursO = params(AppConstants.grossistesEndpoint);
    await toucher(tester, find.text('Rechercher'));
    final jourO = params(route);
    final montantsO = montants();
    await toucher(tester, find.text('Détails').first);
    final detailO = params(AppConstants.retourFournisseurDetailEndpoint);
    await tester.binding.handlePopRoute();
    await pomper(tester);
    await toucher(tester, find.text('Liste Produits'));
    final produitsO = params(AppConstants.avoirsFournisseursEndpoint);
    await tester.binding.handlePopRoute();
    await pomper(tester);
    serveur.oublierRequetes();
    await choisirDansListe(tester, find.text('Tous'), DonneesLot2.grossisteB);
    await choisirDansListe(tester, find.text('Tout'), 'Sans réponse');
    await tester.enterText(find.widgetWithText(TextField, 'Rechercher...'), 'rf-test');
    await toucher(tester, find.text('Rechercher'));
    final filtresO = params(route);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final fournisseursN = params(AppConstants.grossistesEndpoint);
    final jourN = params(route);
    final montantsN = montants();
    expect(norm(valeurNouvelle('Montant des retours')), '${42500 + 18000}');
    await toucher(tester, find.text(DonneesLot2.grossisteA));
    final detailN = params(AppConstants.retourFournisseurDetailEndpoint);
    await tester.binding.handlePopRoute();
    await pomper(tester);
    await toucher(tester, find.byKey(const Key('retours_produits')));
    final produitsN = params(AppConstants.avoirsFournisseursEndpoint);
    await tester.binding.handlePopRoute();
    await pomper(tester);
    serveur.oublierRequetes();
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'rf-test');
    await pomper(tester, 8);
    await filtrer(tester, () async {
      await choisirDansListe(tester, find.byKey(const Key('filtre_fournisseur')), DonneesLot2.grossisteB);
      await toucher(tester, find.byKey(const Key('filtre_reponse_sans')), 3);
    });
    final filtresN = params(route);
    await demonter(tester);

    expect(fournisseursN, fournisseursO);
    expect(jourO.single, {
      'query': '', 'fourId': '', 'filtre': '', 'dtEnd': jour(DateTime.now()), 'dtStart': jour(DateTime.now()), 'page': '1', 'start': '0', 'limit': '9999',
    });
    expect(jourN, jourO);
    expect(detailN, detailO);
    expect(detailO.single, containsPair('retourId', DonneesLot2.retour1));
    expect(produitsN, produitsO);
    expect(filtresO.last, containsPair('fourId', 'FOU-B'));
    expect(filtresO.last, containsPair('filtre', 'WITHOUT'));
    expect(filtresO.last, containsPair('query', 'rf-test'));
    expect(filtresN.last, filtresO.last, reason: 'même requête une fois recherche et filtres appliqués');
    expect(montantsO.difference(montantsN), isEmpty);
  });

  // -------------------------------------------------------------------------------------------------------------
  // Évolution du stock
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Évolution stock : même requête (jour) et mêmes points de la courbe', (tester) async {
    ecranHaut(tester);
    final m = module('Evolution Stock');
    const route = AppConstants.valorisationAllEndpoint;
    List<FlSpot> points() => tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.first.spots;
    await monter(tester, m.ancien, nouvelle: false);
    await toucher(tester, find.text('Afficher l\'Évolution'));
    final reqO = params(route);
    final pointsO = points();
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final ouvertureN = params(route);
    serveur.oublierRequetes();
    await choisirAutrePeriode(tester, 'aujourdhui'); // 3.11.1 : dans le menu du premier bouton
    await pomper(tester, 8);
    final reqN = params(route);
    final pointsN = points();
    expect(norm(valeurNouvelle('Valeur d\'achat à la fin')), '${DonneesLot2.valeurInitiale}');
    await demonter(tester);

    final j = DateTime.now();
    // 3.8.0 (A4) : seule attente adaptée, la période d'ouverture du nouvel écran (« Ce mois », choix du pharmacien,
    // au lieu de « 7 jours ») ; pour la même période (« Aujourd'hui »), même requête et mêmes points qu'à l'origine.
    expect(ouvertureN.single, {'dtStart': jour(DateTime(j.year, j.month, 1)), 'dtEnd': jour(j)});
    expect(reqO.single, {'dtStart': jour(j), 'dtEnd': jour(j)});
    expect(reqN, reqO);
    expect(pointsN, pointsO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // Analyse Saisies BL
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Analyse Saisies BL : même requête, mêmes délais et statuts, même filtre local', (tester) async {
    ecranHaut(tester);
    final m = module('Analyse Saisies BL');
    const route = AppConstants.analyseSaisieBlEndpoint;
    Map<String, String> lignesO = {}, lignesN = {};
    await monter(tester, m.ancien, nouvelle: false);
    await toucher(tester, find.text('Lancer l\'Analyse'));
    final reqO = params(route);
    for (final e in find.byType(ListTile).evaluate()) {
      final t = [for (final x in find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text)).evaluate()) texteDe(x.widget)!];
      lignesO[t[0]] = '${t[2]}|${t[3]}';
    }
    final nombreO = find.text('Nombre de BL affichés: ${DonneesLot2.bonsLivraison}');
    expect(nombreO, findsOneWidget);
    await choisirDansListe(tester, find.text('Tous'), 'Pas bon');
    final filtreO = {for (final e in find.byType(ListTile).evaluate()) texteDe(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text)).evaluate().first.widget)!};
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final reqN = params(route);
    for (final e in find.byType(CarteLigne).evaluate()) {
      final c = e.widget as CarteLigne;
      lignesN[c.titre] = '${c.valeur}|${(c.etiquette as dynamic).texte}';
    }
    expect(valeurNouvelle('Nombre de BL affichés'), '${DonneesLot2.bonsLivraison}');
    await filtrer(tester, () => toucher(tester, find.byKey(const Key('filtre_statut_Pas_bon')), 3));
    final filtreN = {for (final e in find.byType(CarteLigne).evaluate()) (e.widget as CarteLigne).titre};
    expect(serveur.recues(route), hasLength(1), reason: 'filtre local : aucune nouvelle requête');
    await demonter(tester);

    expect(reqO.single, {'dtStart': jour(DateTime.now()), 'dtEnd': jour(DateTime.now()), 'limit': '9999'});
    expect(reqN, reqO);
    expect(lignesO, hasLength(DonneesLot2.bonsLivraison));
    expect(lignesN, lignesO);
    expect(filtreO, isNotEmpty);
    expect(filtreN, filtreO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // Suivi Ajustements
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Suivi Ajustements : mêmes requêtes (jour, motif, détail) et même analyse', (tester) async {
    ecranHaut(tester);
    final m = module('Suivi Ajustements');
    const route = AppConstants.ajustementEndpoint;
    await monter(tester, m.ancien, nouvelle: false);
    final typesO = params(AppConstants.typeAjustementsEndpoint);
    await toucher(tester, find.text('Rechercher'));
    final jourO = params(route);
    await toucher(tester, find.text('Détail').first);
    final detailO = params(AppConstants.ajustementItemsEndpoint);
    final analyseO = {
      for (final l in ['Valeur Ajoutée (Positif):', 'Valeur Retirée (Négatif):']) l: norm(valeurAncienne(l)),
    };
    final pctO = [for (final t in textes()) if (RegExp(r'^\(\d+\.\d%\)$').hasMatch(t)) t.replaceAll(RegExp(r'[()%]'), '')];
    await tester.binding.handlePopRoute();
    await pomper(tester);
    serveur.oublierRequetes();
    await choisirDansListe(tester, find.text('Tous les motifs').first, 'CASSE');
    await toucher(tester, find.text('Rechercher'));
    final motifO = params(route);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final typesN = params(AppConstants.typeAjustementsEndpoint);
    final jourN = params(route);
    await toucher(tester, find.text('AJUSTEMENT FICTIF CASSE'));
    final detailN = params(AppConstants.ajustementItemsEndpoint);
    final analyseN = {
      'Valeur Ajoutée (Positif):': norm(valeurNouvelle('Valeur Ajoutée (Positif)')),
      'Valeur Retirée (Négatif):': norm(valeurNouvelle('Valeur Retirée (Négatif)')),
    };
    final pctN = [
      for (final e in find.byType(ChiffreCle).evaluate()) (e.widget as ChiffreCle).detail!.replaceAll(RegExp(r'[\s %]'), '').replaceAll(',', '.'),
    ];
    await tester.binding.handlePopRoute();
    await pomper(tester);
    serveur.oublierRequetes();
    await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_motif')), 'CASSE'));
    final motifN = params(route);
    await demonter(tester);

    expect(typesN, typesO);
    expect(jourO.single, {'dtStart': jour(DateTime.now()), 'dtEnd': jour(DateTime.now()), 'typeFiltre': '', 'page': '1', 'start': '0', 'limit': '100'});
    expect(jourN, jourO);
    expect(detailO.single, {'ajustementId': DonneesLot2.ajustement1, 'page': '1', 'start': '0', 'limit': '100'});
    expect(detailN, detailO);
    expect(analyseO, {'Valeur Ajoutée (Positif):': '5400', 'Valeur Retirée (Négatif):': '-1700'});
    expect(analyseN, analyseO);
    expect(pctN, pctO);
    expect(motifO.single, containsPair('typeFiltre', 'TYP-CASSE'));
    expect(motifN, motifO);
  });
}
