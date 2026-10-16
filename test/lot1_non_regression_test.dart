// Non-régression des DONNÉES du lot 1 : pour chaque module refait (Rapport d'Activité, Détail CA, Analyse Article,
// Fiche Article, Suivi Péremption, Suivi Crédit), l'écran d'ORIGINE et le NOUVEL écran sont montés tour à tour
// contre le même faux serveur Prestige (données fictives riches, support/donnees_fictives.dart) :
//  - mêmes requêtes émises (routes et paramètres), pour la période du jour, après un changement de période
//    (« Mois dernier » ↔ mois précédent du menu d'origine), une recherche ou un filtre ;
//  - mêmes chiffres affichés, libellé par libellé (montants normalisés : « 1 245 300 FCFA » = « 1 245 300 F »),
//    et tout montant affiché par l'écran d'origine se retrouve sur le nouvel écran.
// Écran haut (411 × 5000 dp) pour que toutes les sections soient construites, horloge simulée, client en mémoire.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import 'support/application.dart';
import 'support/cas_affichage.dart';
import 'support/catalogue_ecrans.dart';
import 'support/donnees_fictives.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final serveur = FauxServeurPrestige();

/// « 1 245 300 FCFA », « 1 245 300 F », « 4.50 » → « 1245300 », « 4.50 ».
String norm(String s) => s.replaceAll(RegExp(r'[\s\u00a0\u202f]'), '').replaceAll(RegExp(r'(FCFA|F)$'), '');

String? texteDe(Widget w) => w is Text ? (w.data ?? w.textSpan?.toPlainText()) : (w is RichText ? w.text.toPlainText() : null);

/// Tous les textes affichés.
List<String> textes() => [
      for (final e in find.byType(RichText).evaluate()) (e.widget as RichText).text.toPlainText(),
    ];

/// Montants affichés (normalisés) : textes « … FCFA » (origine) ou « … F » (nouvelle interface), aussi au milieu
/// d'une ligne (« Prix: 1 200 FCFA - Stock… »).
Set<String> montants() => {
      for (final t in textes())
        for (final m in RegExp(r'(-?\d[\d\s\u00a0\u202f]*?)[\s\u00a0\u202f]*(FCFA|F)\b').allMatches(t)) norm(m.group(1)!),
    };

/// Valeur affichée à côté de [libelle] dans un écran d'ORIGINE : ligne « libellé … valeur » ou colonne
/// « libellé / valeur » (le texte qui suit le libellé dans son conteneur le plus proche).
String valeurAncienne(String libelle, {Finder? dans}) {
  final f = dans == null ? find.text(libelle) : find.descendant(of: dans, matching: find.text(libelle));
  expect(f, findsWidgets, reason: 'libellé d\'origine « $libelle »');
  final parent = find.ancestor(of: f.first, matching: find.byWidgetPredicate((w) => w is Row || w is Column)).first;
  final t = [for (final e in find.descendant(of: parent, matching: find.byType(Text)).evaluate()) texteDe(e.widget) ?? ''];
  return t[t.indexOf(libelle) + 1];
}

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
  for (final e in find.byType(CarteLigne).evaluate()) {
    final w = e.widget as CarteLigne;
    if (w.titre == libelle && w.valeur != null) return w.valeur!;
  }
  fail('libellé « $libelle » absent du nouvel écran');
}

/// Requêtes reçues sur [chemins] : chemin → liste des paramètres (dans l'ordre).
Map<String, List<Map<String, String>>> requetes(List<String> chemins) => {
      for (final c in chemins) c: [for (final r in serveur.recues(c)) r.parametres],
    };

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
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

/// Puce de période du nouvel écran (amenée à l'écran : les puces défilent horizontalement).
Future<void> choisirPeriode(WidgetTester tester, String nom) async {
  // 3.11.0 : 7 jours, Ce mois et Mois dernier sont dans le sélecteur « Autres périodes ».
  if (const {'septJours', 'ceMois', 'moisDernier'}.contains(nom)) return choisirAutrePeriode(tester, nom);
  await tester.ensureVisible(find.byKey(Key('periode_$nom')));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(Key('periode_$nom')));
}

ModuleLot1 module(String tuile) => modulesLot1.firstWhere((m) => m.tuile == tuile);

/// Choisit le mois précédent dans le menu « Mois » d'un écran d'origine (null en janvier : pas de mois précédent
/// dans ce menu, limité à l'année en cours).
Future<bool> moisPrecedentOrigine(WidgetTester tester) async {
  final now = DateTime.now();
  if (now.month == 1) return false;
  await tester.tap(find.byType(DropdownButtonFormField<int>));
  await pomper(tester, 5);
  await tester.tap(find.text(DateFormat.MMMM('fr_FR').format(DateTime(now.year, now.month - 1))).last);
  await pomper(tester, 15);
  return true;
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
    donneesLot1(serveur);
  });

  void ecranHaut(WidgetTester tester) {
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = const Size(411 * 2.625, 5000 * 2.625);
    addTearDown(tester.view.reset);
  }

  testWidgets('Rapport d\'Activité : mêmes 4 requêtes (jour, mois précédent) et mêmes chiffres', (tester) async {
    ecranHaut(tester);
    const chemins = [
      AppConstants.dashboardRecapEndpoint,
      AppConstants.creditsRecapEndpoint,
      AppConstants.creditTotalsRecapEndpoint,
      AppConstants.reglementsRecapEndpoint,
    ];
    // Libellé d'origine → libellé du nouvel écran.
    const libelles = {
      'Montant Total TTC:': 'Montant Total TTC',
      'Montant Total HT:': 'Montant Total HT',
      'Montant Total TVA:': 'Montant Total TVA',
      'Marge brute:': 'Marge brute',
      'Ratio:': 'Ratio',
      'Montant Crédit:': 'Montant Crédit',
      'Montant Réglé:': 'Montant Réglé',
      'Espèces:': 'Espèces',
      'Mobile Money:': 'Mobile Money',
      'Carte bancaire:': 'Carte bancaire',
      'GROUPE FICTIF A:': 'GROUPE FICTIF A',
      'GROUPE FICTIF B:': 'GROUPE FICTIF B',
      'Fond de caisse:': 'Fond de caisse',
      'Sortie fictive:': 'Sortie fictive',
      'ASSURANCE FICTIVE UNE:': 'ASSURANCE FICTIVE UNE',
      'MUTUELLE IMAGINAIRE:': 'MUTUELLE IMAGINAIRE',
      'SOCIETE FICTIVE SARL:': 'SOCIETE FICTIVE SARL',
      'Nombre total de clients:': 'Nombre total de clients',
      'Nombre total de bons:': 'Nombre total de bons',
      'Montant total des crédits:': 'Montant total des crédits',
      'Règlement ASSURANCE FICTIVE UNE (REG-TEST-1):': 'Règlement ASSURANCE FICTIVE UNE',
      'Règlement SOCIETE FICTIVE SARL (REG-TEST-2):': 'Règlement SOCIETE FICTIVE SARL',
    };

    await monter(tester, module('Rapport d\'Activité').ancien, nouvelle: false);
    await tester.tap(find.text('Générer le Rapport'));
    await pomper(tester);
    final reqOrigine = requetes(chemins);
    final valeursOrigine = {for (final l in libelles.keys) l: norm(valeurAncienne(l))};
    final montantsOrigine = montants();
    serveur.oublierRequetes();
    final moisOk = await moisPrecedentOrigine(tester);
    final reqOrigineMois = requetes(chemins);
    await demonter(tester);

    await monter(tester, module('Rapport d\'Activité').nouveau, nouvelle: true);
    final reqNouvelle = requetes(chemins);
    final valeursNouvelle = {for (final e in libelles.entries) e.key: norm(valeurNouvelle(e.value))};
    final montantsNouvelle = montants();
    serveur.oublierRequetes();
    await choisirPeriode(tester, 'moisDernier');
    await pomper(tester);
    final reqNouvelleMois = requetes(chemins);
    await demonter(tester);

    final jour = DateFormat('yyyy-MM-dd').format(DateTime.now());
    expect(reqOrigine[AppConstants.dashboardRecapEndpoint], [
      {'dtStart': jour, 'dtEnd': jour}
    ]);
    expect(reqNouvelle, reqOrigine, reason: 'mêmes routes, mêmes paramètres (aujourd\'hui)');
    if (moisOk) expect(reqNouvelleMois, reqOrigineMois, reason: 'mêmes paramètres pour le mois précédent');
    expect(valeursNouvelle, valeursOrigine);
    expect(valeursOrigine['Montant Total TTC:'], '2480650');
    expect(montantsOrigine.difference(montantsNouvelle), isEmpty, reason: 'tout montant d\'origine est affiché');
  });

  testWidgets('Détail CA : même requête (jour, mois précédent), mêmes totaux, même répartition', (tester) async {
    ecranHaut(tester);
    const chemins = [AppConstants.caComptantEndpoint];
    await monter(tester, module('Détail CA').ancien, nouvelle: false);
    await tester.tap(find.text('Afficher le Détail CA'));
    await pomper(tester);
    final reqOrigine = requetes(chemins);
    // Tableau « Totaux sur la période » : libellé → valeur.
    final totauxOrigine = <String, String>{};
    for (final ligne in tester.widget<Table>(find.byType(Table)).children) {
      final t = [for (final c in ligne.children) texteDe((c as Padding).child!)!];
      totauxOrigine[t[0].replaceAll(':', '')] = norm(t[1]);
    }
    // Légende du camembert : mode → montant (le pourcentage est recalculé comme l'écran d'origine).
    final legende = <String, double>{};
    for (final mode in ['Espèces', 'Crédit', 'Mobile', 'Carte B.', 'Chèque', 'Virement']) {
      final lignes = find.ancestor(of: find.text(mode), matching: find.byType(Row)).evaluate().where((e) => (e.widget as Row).children.length == 4);
      if (lignes.isEmpty) continue;
      final t = [for (final x in find.descendant(of: find.byWidget(lignes.first.widget), matching: find.byType(Text)).evaluate()) texteDe(x.widget)!];
      legende[mode] = double.parse(norm(t.last));
    }
    final montantsOrigine = montants();
    serveur.oublierRequetes();
    final moisOk = await moisPrecedentOrigine(tester);
    final reqOrigineMois = requetes(chemins);
    await demonter(tester);

    await monter(tester, module('Détail CA').nouveau, nouvelle: true);
    final reqNouvelle = requetes(chemins);
    final totauxNouvelle = {for (final l in totauxOrigine.keys) l: norm(valeurNouvelle(l))};
    final montantsNouvelle = montants();
    final somme = legende.values.fold<double>(0, (s, v) => s + v);
    for (final e in legende.entries) {
      final pourcent = '${(e.value / somme * 100).toStringAsFixed(1)}%';
      final barre = find.ancestor(of: find.text(pourcent), matching: find.byType(Row)).first;
      expect(find.descendant(of: barre, matching: find.text(e.key)), findsOneWidget, reason: '${e.key} : $pourcent comme le camembert d\'origine');
      expect(find.descendant(of: barre, matching: find.text(formaterMontant(e.value))), findsOneWidget);
    }
    serveur.oublierRequetes();
    await choisirPeriode(tester, 'moisDernier');
    await pomper(tester);
    final reqNouvelleMois = requetes(chemins);
    await demonter(tester);

    expect(reqNouvelle, reqOrigine);
    if (moisOk) expect(reqNouvelleMois, reqOrigineMois);
    expect(totauxOrigine, hasLength(9));
    expect(totauxNouvelle, totauxOrigine);
    expect(totauxOrigine['TOTAL BRUT PAIEMENTS'], '2152650');
    expect(legende, hasLength(6));
    expect(montantsOrigine.difference(montantsNouvelle), isEmpty);
  });

  testWidgets('Détail CA : Mobile Money déplié → chiffres de /ca-all inchangés, /ca-all non rappelé', (tester) async {
    ecranHaut(tester);
    await monter(tester, module('Détail CA').nouveau, nouvelle: true);
    Map<String, String> chiffres() => {
          for (final e in find.byType(LigneDetail).evaluate()) (e.widget as LigneDetail).libelle: (e.widget as LigneDetail).valeur,
          for (final e in find.byType(ChiffreCle).evaluate()) 'kpi ${(e.widget as ChiffreCle).libelle}': (e.widget as ChiffreCle).valeur,
        };
    final avant = chiffres();
    final textesAvant = textes().toSet();
    expect(serveur.recues('/stats-recette-caisse/modes'), isEmpty);
    await tester.tap(find.byKey(const Key('deplier_mobile')));
    await pomper(tester);
    expect(find.byKey(const Key('mobile_ligne_Orange')), findsOneWidget);
    expect(chiffres(), avant);
    expect(textesAvant.difference(textes().toSet()), isEmpty, reason: 'rien de ce qui était affiché ne change');
    expect(norm(avant['TOTAL BRUT PAIEMENTS']!), '2152650');
    expect(norm(avant['Total Mobile Money']!), '237750');
    expect(serveur.recues(AppConstants.caComptantEndpoint), hasLength(1));
    await demonter(tester);
  });

  testWidgets('Suivi Crédit : même requête (jour, mois précédent), mêmes lignes et montants, même filtre par tiers payant',
      (tester) async {
    ecranHaut(tester);
    const chemins = [AppConstants.suiviCreditEndpoint];
    const tiers = ['ASSURANCE FICTIVE UNE', 'MUTUELLE IMAGINAIRE', 'SOCIETE FICTIVE SARL'];
    await monter(tester, module('Suivi Crédit').ancien, nouvelle: false);
    await tester.tap(find.text('Afficher les Crédits'));
    await pomper(tester);
    final reqOrigine = requetes(chemins);
    Finder carte(String t) => find.ancestor(of: find.text(t), matching: find.byType(Card)).first;
    final origine = {for (final t in tiers) t: norm(valeurAncienne('Montant:', dans: carte(t)))};
    final bonsOrigine = tiers.fold<int>(0, (s, t) => s + int.parse(valeurAncienne('Nombre de Bons:', dans: carte(t))));
    final clientsOrigine = tiers.fold<int>(0, (s, t) => s + int.parse(valeurAncienne('Nombre de Clients:', dans: carte(t))));
    // Filtre d'origine : champ « Filtrer par tiers payant ».
    await tester.enterText(find.byType(TextField), 'mutuelle');
    await pomper(tester, 3);
    final filtreOrigine = {for (final t in tiers) if (find.text(t).evaluate().isNotEmpty) t};
    await tester.enterText(find.byType(TextField), '');
    await pomper(tester, 3);
    serveur.oublierRequetes();
    final moisOk = await moisPrecedentOrigine(tester);
    final reqOrigineMois = requetes(chemins);
    await demonter(tester);

    await monter(tester, module('Suivi Crédit').nouveau, nouvelle: true);
    final reqNouvelle = requetes(chemins);
    final nouvelle = {for (final t in tiers) t: norm(valeurNouvelle(t))};
    final bonsNouvelle = int.parse(norm(valeurNouvelle('Nombre de bons')));
    final clientsNouvelle = int.parse(norm(valeurNouvelle('Nombre de clients')));
    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await pomper(tester, 5);
    await tester.enterText(find.byKey(const Key('filtre_tiers')), 'mutuelle');
    await tester.tap(find.byKey(const Key('filtres_appliquer')));
    await pomper(tester, 5);
    final filtreNouvelle = {for (final e in find.byType(CarteLigne).evaluate()) (e.widget as CarteLigne).titre};
    expect(serveur.recues(AppConstants.suiviCreditEndpoint), hasLength(1), reason: 'filtre local : aucune nouvelle requête (comme l\'origine)');
    serveur.oublierRequetes();
    await choisirPeriode(tester, 'moisDernier');
    await pomper(tester);
    final reqNouvelleMois = requetes(chemins);
    await demonter(tester);

    expect(reqNouvelle, reqOrigine);
    if (moisOk) expect(reqNouvelleMois, reqOrigineMois);
    expect(nouvelle, origine);
    expect((bonsNouvelle, clientsNouvelle), (bonsOrigine, clientsOrigine));
    expect(filtreOrigine, {'MUTUELLE IMAGINAIRE'});
    expect(filtreNouvelle, filtreOrigine);
  });

  testWidgets('Suivi Péremption : mêmes requêtes (ouverture, recherche, filtre mois) et mêmes chiffres et lots', (tester) async {
    ecranHaut(tester);
    const chemins = [AppConstants.suiviPeremptionEndpoint];
    const resume = ['Qté Totale', 'Val. Achat', 'Val. Vente'];
    final lot = RegExp(r'LOT-TEST-\d');

    await monter(tester, module('Suivi Péremption').ancien, nouvelle: false);
    final reqOuverture = requetes(chemins);
    final resumeOrigine = {for (final l in resume) l: norm(valeurAncienne(l))};
    final lotsOrigine = <String, String>{};
    for (final e in find.byType(ListTile).evaluate()) {
      final t = [for (final x in find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text)).evaluate()) texteDe(x.widget)!];
      final l = lot.firstMatch(t.join(' '))!.group(0)!;
      lotsOrigine[l] = '${t[0]}|${t.firstWhere((x) => x.startsWith('Qté: ')).substring(5)}|${t[2]}';
    }
    serveur.oublierRequetes();
    await tester.enterText(find.widgetWithText(TextField, 'Recherche...'), 'sirop');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pomper(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mois'), '3');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pomper(tester);
    final reqFiltres = requetes(chemins);
    await demonter(tester);

    await monter(tester, module('Suivi Péremption').nouveau, nouvelle: true);
    final reqOuvertureN = requetes(chemins);
    final resumeNouvelle = {for (final l in resume) l: norm(valeurNouvelle(l))};
    final lotsNouvelle = <String, String>{};
    for (final e in find.byType(CarteLigne).evaluate()) {
      final c = e.widget as CarteLigne;
      final statut = (c.etiquette! as Etiquette).texte;
      lotsNouvelle[lot.firstMatch(c.lignes.join(' '))!.group(0)!] = '${c.titre}|${c.valeur}|$statut';
    }
    serveur.oublierRequetes();
    await tester.enterText(find.byKey(const Key('champ_recherche')), 'sirop');
    await pomper(tester, 8); // anti-rebond (500 ms)
    await tester.tap(find.byKey(const Key('bouton_filtres')));
    await pomper(tester, 5);
    await tester.enterText(find.byKey(const Key('filtre_mois')), '3');
    await tester.tap(find.byKey(const Key('filtres_appliquer')));
    await pomper(tester);
    final reqFiltresN = requetes(chemins);
    await demonter(tester);

    expect(reqOuverture[chemins.first], hasLength(1));
    expect(reqOuvertureN, reqOuverture, reason: 'mêmes paramètres à l\'ouverture (page 1, 20 lignes, sans filtre)');
    expect(reqFiltresN, reqFiltres, reason: 'mêmes paramètres après recherche puis filtre « 3 mois »');
    expect(reqFiltres[chemins.first]!.last, containsPair('nbreMois', '3'));
    expect(reqFiltres[chemins.first]!.last, containsPair('query', 'sirop'));
    expect(resumeNouvelle, resumeOrigine);
    expect(lotsOrigine, hasLength(DonneesFictives.lotsPerimes));
    expect(lotsNouvelle, lotsOrigine);
  });

  for (final (tuile, recherche, champ, chemin, parametre, libelles) in [
    (
      'Analyse Article',
      'parafictif',
      'search',
      AppConstants.infoEndpoint,
      'search',
      [
        'Code CIP', 'Désignation', 'Prix d\'achat', 'Prix de vente', 'Grossiste', 'Moyenne sur 3 mois', 'Moyenne par jour',
        'Qté totale vendue', 'Emplacement', 'Stock rayon', 'Stock réserve', 'Seuil réserve', 'Seuil mini rayon', 'Total rayon + réserve',
        'Dernière Vente', 'Dernier Achat', 'Dernier Inventaire',
      ],
    ),
    (
      'Fiche Article',
      'parafictif',
      'nompdt',
      AppConstants.checkProduitEndpoint,
      'nompdt',
      ['Code CIP', 'Désignation', 'Stock', 'Stock réserve', 'Seuil réserve', 'Seuil mini rayon', 'Total rayon + réserve', 'Prix d\'achat',
        'Prix de vente', 'Emplacement'],
    ),
  ]) {
    testWidgets('$tuile : même requête ($champ), mêmes articles, même fiche détaillée', (tester) async {
      ecranHaut(tester);
      await monter(tester, module(tuile).ancien, nouvelle: false);
      await tester.enterText(find.byType(TextField), recherche);
      await pomper(tester, 12);
      final reqOrigine = requetes([chemin]);
      final montantsListe = montants();
      expect(find.text(DonneesFictives.libelleArticle1), findsOneWidget);
      await tester.tap(find.text(DonneesFictives.libelleArticle1));
      await pomper(tester, 5);
      final dialogue = find.byType(AlertDialog);
      final ficheOrigine = {for (final l in libelles) l: norm(valeurAncienne(l, dans: dialogue))};
      await demonter(tester);

      await monter(tester, module(tuile).nouveau, nouvelle: true);
      await tester.enterText(find.byType(TextField), recherche);
      await pomper(tester, 12);
      final reqNouvelle = requetes([chemin]);
      final montantsListeN = montants();
      await tester.tap(find.text(DonneesFictives.libelleArticle1));
      await pomper(tester, 5);
      final ficheNouvelle = {for (final l in libelles) l: norm(valeurNouvelle(l))};
      await demonter(tester);

      expect(reqOrigine[chemin], [
        {parametre: recherche}
      ]);
      expect(reqNouvelle, reqOrigine);
      expect(montantsListe.difference(montantsListeN), isEmpty, reason: 'prix de la liste');
      expect(ficheNouvelle, ficheOrigine);
    });
  }
}
