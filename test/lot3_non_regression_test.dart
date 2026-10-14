// Non-régression des DONNÉES du lot 3 (analyses) : pour chaque module refait (Tableau : Analyses et ses trois
// graphiques, Tableau : Ratios et Ratios mensuels, Suivi 20/80, Stat TVA, Marge Produits Vendus, CA Crédit,
// CA Global), l'écran d'ORIGINE et le NOUVEL écran sont montés tour à tour contre le même faux serveur
// (support/donnees_lot3.dart) :
//  - mêmes requêtes (routes, version de l'API, paramètres) à l'ouverture (jour), pour le mois dernier, après un
//    filtre (nombre d'articles, type de vente) ; filtres et recherches LOCAUX sans nouvelle requête ;
//  - mêmes chiffres affichés : points des courbes, ratios (norme 1,51), achat / vente normés, totaux, parts du TTC,
//    montants, lignes retenues par les filtres (montants normalisés : « 23 600 FCFA » = « 23 600 F », « 1.51 » =
//    « 1,51 »).
// Horloge simulée, client en mémoire ; écran haut (411 × 5000 dp) pour que toutes les lignes soient construites.
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
import 'support/donnees_lot3.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/polices.dart';

final serveur = FauxServeurPrestige();

/// « 23 600 FCFA », « 23 600 F » → « 23600 » ; « 1.51 » / « 1,51 » → « 1.51 ».
String norm(String s) => s.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(RegExp(r'(FCFA|F)$'), '').replaceAll(',', '.');

String? texteDe(Widget w) => w is Text ? (w.data ?? w.textSpan?.toPlainText()) : (w is RichText ? w.text.toPlainText() : null);

List<String> textes() => [for (final e in find.byType(RichText).evaluate()) (e.widget as RichText).text.toPlainText()];

/// Montants affichés (normalisés), aussi au milieu d'une ligne.
Set<String> montants() => {
      for (final t in textes())
        for (final m in RegExp(r'(-?\d[\d\s  ]*?)[\s  ]*(FCFA|F)\b').allMatches(t)) norm(m.group(1)!),
    };

/// Valeur affichée pour [libelle] dans un NOUVEL écran : ligne de détail ou chiffre clé.
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
String valeurAncienne(String libelle) {
  final f = find.text(libelle);
  expect(f, findsWidgets, reason: 'libellé d\'origine « $libelle »');
  final parent = find.ancestor(of: f.first, matching: find.byWidgetPredicate((w) => w is Row || w is Column)).first;
  final t = [for (final e in find.descendant(of: parent, matching: find.byType(Text)).evaluate()) texteDe(e.widget) ?? ''];
  return t[t.indexOf(libelle) + 1];
}

List<Map<String, String>> params(String chemin) => [for (final r in serveur.recues(chemin)) r.parametres];

/// Cartes du nouvel écran (téléphone) : titre → valeur.
List<(String, String)> cartes() => [for (final e in find.byType(CarteLigne).evaluate()) ((e.widget as CarteLigne).titre, (e.widget as CarteLigne).valeur ?? '')];

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

Future<void> retour(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await pomper(tester);
}

/// Choisit [option] dans une liste déroulante (écran d'origine ou feuille des filtres).
Future<void> choisirDansListe(WidgetTester tester, Finder liste, String option) async {
  await toucher(tester, liste.hitTestable().evaluate().isNotEmpty ? liste.hitTestable() : liste, 5);
  await tester.tap(find.text(option).hitTestable().last);
  await pomper(tester, 8);
}

/// Feuille des filtres du nouvel écran : [reglages] puis « Appliquer ».
Future<void> filtrer(WidgetTester tester, Future<void> Function() reglages) async {
  await toucher(tester, find.byKey(const Key('bouton_filtres')), 6);
  await reglages();
  await toucher(tester, find.byKey(const Key('filtres_appliquer')));
}

/// Mois précédent dans le choix de mois d'origine (seulement l'année en cours : pas en janvier).
final maintenant = DateTime.now();
final moisDernierPossible = maintenant.month > 1;
String get nomMoisDernier => DateFormat.MMMM('fr_FR').format(DateTime(maintenant.year, maintenant.month - 1));

/// Choisit le mois dernier : liste « Mois » d'origine ou puce « Mois dernier » du nouvel écran.
Future<void> moisDernier(WidgetTester tester, {required bool nouvelle}) async {
  if (nouvelle) {
    await toucher(tester, find.byKey(const Key('periode_moisDernier')));
  } else {
    await choisirDansListe(tester, find.text('Choisir...').first, nomMoisDernier);
  }
}

ModuleLot1 module(String tuile) => modulesLot3.firstWhere((m) => m.tuile == tuile);

String jour(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

List<List<FlSpot>> courbes(WidgetTester tester) => [for (final b in tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData) b.spots];

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
  const routeTableau = AppConstants.tableauBordAchatsVentesEndpoint;

  // -------------------------------------------------------------------------------------------------------------
  // Tableau : Analyses
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Tableau : Analyses : mêmes requêtes (jour, mois dernier) et mêmes points des trois graphiques', (tester) async {
    ecranHaut(tester);
    final m = module('Tableau: Analyses');
    final graphiquesO = <String, List<List<FlSpot>>>{};
    await monter(tester, m.ancien, nouvelle: false);
    expect(serveur.recues(routeTableau), isEmpty, reason: 'origine : rien avant « Charger »');
    await toucher(tester, find.text('Charger les Données pour Analyse'));
    final jourO = params(routeTableau);
    for (final (nom, titre) in [
      ('comparee', 'Évolution Comparative Achats vs Ventes'),
      ('achats', 'Évolution des Achats'),
      ('ventes', 'Évolution des Ventes'),
    ]) {
      await toucher(tester, find.text(titre));
      graphiquesO[nom] = courbes(tester);
      await retour(tester);
    }
    serveur.oublierRequetes();
    if (moisDernierPossible) await moisDernier(tester, nouvelle: false);
    final moisO = params(routeTableau);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    // 3.8.0 (B1) : ouverture sur « Ce mois » (choix du pharmacien) ; pour la même période (« Aujourd'hui »), même
    // requête que l'origine.
    final ouvertureN = params(routeTableau);
    serveur.oublierRequetes();
    await tester.ensureVisible(find.byKey(const Key('periode_aujourdhui')));
    await toucher(tester, find.byKey(const Key('periode_aujourdhui')));
    final jourN = params(routeTableau);
    final graphiquesN = <String, List<List<FlSpot>>>{};
    for (final nom in ['comparee', 'achats', 'ventes']) {
      await toucher(tester, find.byKey(Key('graphique_$nom')), 3);
      graphiquesN[nom] = courbes(tester);
    }
    expect(norm(valeurNouvelle('Ventes')), '${DonneesLot3.totalVentes}');
    expect(norm(valeurNouvelle('Achats')), '${DonneesLot3.totalAchats}');
    // Jour par jour : dans l'ordre des dates (tri d'origine).
    final dates = [for (final (t, _) in cartes()) t];
    expect(dates.first, '02/08/2026');
    expect(dates.last, '07/10/2026');
    serveur.oublierRequetes();
    if (moisDernierPossible) await moisDernier(tester, nouvelle: true);
    final moisN = params(routeTableau);
    await demonter(tester);

    expect(jourO.single, duJour);
    final j = DateTime.now();
    expect(ouvertureN.single, {'dtStart': jour(DateTime(j.year, j.month, 1)), 'dtEnd': jour(j)});
    expect(jourN, jourO);
    if (moisDernierPossible) {
      expect(moisO.single, duMoisDernier);
      expect(moisN, moisO);
    }
    expect(graphiquesO['comparee'], hasLength(2), reason: 'achats puis ventes');
    expect(graphiquesO['comparee']!.first, hasLength(DonneesLot3.jours.length));
    expect(graphiquesN, graphiquesO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // Tableau : Ratios et Ratios mensuels
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Tableau : Ratios : même requête, mêmes ratios (norme 1,51), même calcul normé, mêmes ratios mensuels', (tester) async {
    ecranHaut(tester);
    final m = module('Tableau: Ratios');
    await monter(tester, m.ancien, nouvelle: false);
    await toucher(tester, find.text('Afficher les Données'));
    final jourO = params(routeTableau);
    final table = tester.widget<DataTable>(find.byType(DataTable));
    final ratiosO = [
      for (final r in table.rows)
        '${texteDe(r.cells[0].child)!.replaceAll('-', '/')}|${norm(texteDe(r.cells[1].child)!)}|${norm(texteDe(r.cells[2].child)!)}|${texteDe(r.cells[3].child)}',
    ];
    final couleursO = [for (final r in table.rows) (r.cells[3].child as Text).style!.color];
    expect(find.text('Norme Ratio Vente/Achat Cible: 1.51'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Si Vente (FCFA)'), '151000');
    await pomper(tester, 3);
    final achatNormeO = norm(valeurAncienne('Achat Normé (FCFA):'));
    await tester.enterText(find.widgetWithText(TextField, 'Si Achat (FCFA)'), '100000');
    await pomper(tester, 3);
    final venteNormeeO = norm(valeurAncienne('Vente Normée (FCFA):'));
    serveur.oublierRequetes();
    await toucher(tester, find.text('Voir les Ratios Mensuels de l\'Année'));
    final mensuelsReqO = params(routeTableau);
    final mensuelsO = [for (final t in textes()) if (RegExp(r'^\d+\.\d\d$').hasMatch(t)) t];
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final jourN = params(routeTableau);
    final ratiosN = [
      for (final e in find.byType(CarteLigne).evaluate())
        () {
          final c = e.widget as CarteLigne;
          final achat = norm(c.lignes[0].replaceFirst('Achats ', '')), vente = norm(c.lignes[1].replaceFirst('Ventes ', ''));
          return '${c.titre}|$achat|$vente|${norm(c.valeur!)}';
        }(),
    ];
    final etiquettesN = [for (final e in find.byType(CarteLigne).evaluate()) ((e.widget as CarteLigne).etiquette as dynamic).ratio as double];
    await tester.enterText(find.byKey(const Key('norme_vente')), '151000');
    await pomper(tester, 3);
    final achatNormeN = norm(tester.widget<Text>(find.byKey(const Key('norme_achat_resultat'))).data!);
    await tester.tap(find.byKey(const Key('norme_achat')));
    await tester.enterText(find.byKey(const Key('norme_achat')), '100000');
    await pomper(tester, 3);
    final venteNormeeN = norm(tester.widget<Text>(find.byKey(const Key('norme_vente_resultat'))).data!);
    expect(tester.widget<Text>(find.byKey(const Key('norme_achat_resultat'))).data, '—', reason: 'un seul champ à la fois, comme l\'origine');
    serveur.oublierRequetes();
    await toucher(tester, find.byKey(const Key('ratios_mensuels')));
    final mensuelsReqN = params(routeTableau);
    final mensuelsN = [for (final (_, v) in cartes()) norm(v)];
    await demonter(tester);

    expect(jourO.single, duJour);
    expect(jourN, jourO);
    // Ordre du serveur, mêmes montants et ratios (1,51 pile = norme atteinte, 0 sans achat).
    expect(ratiosO, hasLength(DonneesLot3.jours.length));
    expect(ratiosN, [for (final r in ratiosO) r.replaceAll(',', '.')]);
    expect(ratiosO[3], endsWith('|1.51'));
    // Même règle de couleur que l'origine (gris : sans achat, vert : ≥ norme, rouge : sinon), désormais écrite.
    for (var i = 0; i < couleursO.length; i++) {
      final attendu = etiquettesN[i] == 0 ? Colors.grey : (etiquettesN[i] >= 1.51 ? Colors.green.shade700 : Colors.red.shade700);
      expect(couleursO[i], attendu, reason: 'ligne $i');
    }
    expect(achatNormeO, '100000');
    expect(achatNormeN, achatNormeO);
    expect(venteNormeeO, '151000');
    expect(venteNormeeN, venteNormeeO);
    expect(mensuelsReqO.single, {'dtStart': jour(DateTime(maintenant.year, 1, 1)), 'dtEnd': jour(maintenant)});
    // 3.8.0 (B2, choix du pharmacien) : seule attente adaptée, la période des Ratios mensuels du nouvel écran (12
    // derniers mois glissants au lieu de l'année en cours) ; les mois présents dans les deux périodes ont les mêmes
    // ratios (même cumul, même norme 1,51).
    expect(mensuelsReqN.single, {'dtStart': jour(DateTime(maintenant.year, maintenant.month - 11, 1)), 'dtEnd': jour(maintenant)});
    expect(mensuelsO, ['1.53', '1.45', '1.80'], reason: 'août, septembre, octobre');
    expect(mensuelsN, mensuelsO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // Suivi 20/80
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Suivi 20/80 : mêmes requêtes (jour, nombre d\'articles, mois dernier) et mêmes montants', (tester) async {
    ecranHaut(tester, hauteur: 12000); // 50 articles construits
    final m = module('Suivi 20/80');
    const route = AppConstants.suivi2080Endpoint;
    await monter(tester, m.ancien, nouvelle: false);
    await toucher(tester, find.text('Afficher le Suivi'));
    final jourO = params(route);
    final montantsO = montants();
    serveur.oublierRequetes();
    await tester.enterText(find.byType(TextFormField), '80');
    await toucher(tester, find.text('Afficher le Suivi'));
    final limiteO = params(route);
    serveur.oublierRequetes();
    await tester.enterText(find.byType(TextFormField), '');
    if (moisDernierPossible) await moisDernier(tester, nouvelle: false);
    final moisO = params(route);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final jourN = params(route);
    final montantsN = montants();
    expect(norm(valeurNouvelle('Montant')), '${DonneesLot3.montant2080(50)}');
    serveur.oublierRequetes();
    await filtrer(tester, () async {
      await tester.enterText(find.byKey(const Key('filtre_limite')), '80');
      await pomper(tester, 2);
    });
    final limiteN = params(route);
    expect(valeurNouvelle('Articles'), '80');
    await toucher(tester, find.byKey(const Key('filtres_retirer')));
    serveur.oublierRequetes();
    if (moisDernierPossible) await moisDernier(tester, nouvelle: true);
    final moisN = params(route);
    await demonter(tester);

    final base = {'codeFamile': '', 'codeRayon': '', 'codeGrossiste': '', 'qtyOrCa': 'false', 'page': '1', 'start': '0'};
    expect(jourO.single, {...duJour, 'limit': '50', ...base});
    expect(jourN, jourO);
    expect(limiteO.single, containsPair('limit', '80'));
    expect(limiteN, limiteO);
    if (moisDernierPossible) {
      expect(moisO.single, {...duMoisDernier, 'limit': '50', ...base});
      expect(moisN, moisO);
    }
    expect(montantsO, hasLength(50));
    expect(montantsO.difference(montantsN), isEmpty);
  });

  // -------------------------------------------------------------------------------------------------------------
  // Stat TVA
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Stat TVA : mêmes requêtes (API v3, jour, type de vente) et mêmes totaux et parts du TTC', (tester) async {
    ecranHaut(tester);
    final m = module('Stat TVA');
    const route = AppConstants.statTvaEndpoint;
    List<String> parts() => [for (final s in tester.widget<PieChart>(find.byType(PieChart)).data.sections) '${s.value}'];
    await monter(tester, m.ancien, nouvelle: false);
    await toucher(tester, find.text('Afficher les Statistiques'));
    final jourO = params(route);
    final versionO = [for (final r in serveur.recues(route)) r.versionApi];
    final sectionsO = parts();
    final pctO = [for (final s in tester.widget<PieChart>(find.byType(PieChart)).data.sections) s.title.replaceAll('%', '')];
    final totauxO = [
      for (final e in find.descendant(of: find.ancestor(of: find.text('TOTAL:'), matching: find.byType(Table)), matching: find.byType(Text)).evaluate())
        texteDe(e.widget)!,
    ];
    serveur.oublierRequetes();
    await choisirDansListe(tester, find.text('Tout').first, 'Vente Ordonnancée');
    await toucher(tester, find.text('Afficher les Statistiques'));
    final typeO = params(route);
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final jourN = params(route);
    final versionN = [for (final r in serveur.recues(route)) r.versionApi];
    final sectionsN = parts();
    final pctN = [
      for (final e in find.byType(Text).evaluate())
        if (RegExp(r'^\d+ % · ').hasMatch(texteDe(e.widget) ?? '')) texteDe(e.widget)!.split(' · ').last.replaceAll(' %', '').replaceAll(',', '.'),
    ];
    final totauxN = [norm(valeurNouvelle('Total HT')), norm(valeurNouvelle('Total TVA')), norm(valeurNouvelle('Total TTC'))];
    serveur.oublierRequetes();
    await filtrer(tester, () => toucher(tester, find.byKey(const Key('filtre_type_vo')), 3));
    final typeN = params(route);
    expect(valeurNouvelle('Taux de TVA'), '1');
    await demonter(tester);

    expect(jourO.single, {...duJour, 'typeVente': 'TOUT'});
    expect(versionO, ['v3']);
    expect(jourN, jourO);
    expect(versionN, versionO);
    expect(sectionsN, sectionsO);
    expect(pctO, ['60.0', '6.2', '33.7']);
    expect(pctN, pctO);
    expect([for (final t in totauxO.sublist(totauxO.length - 3)) norm(t)], totauxN, reason: 'ligne TOTAL : HT, TVA, TTC');
    expect(typeO.single, containsPair('typeVente', 'VO'));
    expect(typeN, typeO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // Marge Produits Vendus
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('Marge Produits Vendus : même requête, même filtre LOCAL (sans requête), mêmes produits retenus', (tester) async {
    ecranHaut(tester);
    final m = module('Marge Produits Vendus');
    const route = AppConstants.margeProduitsVendusEndpoint;
    Set<String> produitsO() => {
          for (final e in find.byType(Card).evaluate())
            texteDe(find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text)).evaluate().first.widget)!,
        };
    Set<String> produitsN() => {for (final (t, _) in cartes()) t};
    final retenusO = <String, Set<String>>{}, retenusN = <String, Set<String>>{};
    await monter(tester, m.ancien, nouvelle: false);
    await toucher(tester, find.text('Rechercher'));
    final jourO = params(route);
    for (final (op, libelle, valeur) in [('>', 'Supérieur à', '40'), ('~=', 'Environ (±1)', '10'), ('<=', 'Inférieur ou égal à', '-3')]) {
      await choisirDansListe(tester, find.byType(DropdownButtonFormField<String>), libelle);
      await tester.enterText(find.widgetWithText(TextFormField, 'Valeur Marge (%)'), valeur);
      await pomper(tester, 3);
      retenusO[op] = produitsO();
    }
    final requetesO = serveur.recues(route).length;
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final jourN = params(route);
    expect(valeurNouvelle('Produits'), '${DonneesLot3.produitsMarge}');
    for (final (op, cle, valeur) in [('>', 'superieur', '40'), ('~=', 'environ', '10'), ('<=', 'inferieurEgal', '-3')]) {
      await filtrer(tester, () async {
        await toucher(tester, find.byKey(Key('filtre_operateur_$cle')), 3);
        await tester.enterText(find.byKey(const Key('filtre_marge')), valeur);
        await pomper(tester, 2);
      });
      retenusN[op] = produitsN();
    }
    final requetesN = serveur.recues(route).length;
    await demonter(tester);

    expect(jourO.single, {...duJour, 'limit': '9999'});
    expect(jourN, jourO);
    expect(requetesO, 1, reason: 'filtre local d\'origine');
    expect(requetesN, 1, reason: 'filtre local : aucune nouvelle requête');
    expect(retenusO['>'], hasLength(DonneesLot3.produitsMarge - 46));
    expect(retenusO['~='], hasLength(3));
    expect(retenusO['<='], hasLength(3));
    expect(retenusN, retenusO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // CA Crédit
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('CA Crédit : même requête, même recherche LOCALE (client, facture, tiers payant), mêmes montants', (tester) async {
    ecranHaut(tester);
    final m = module('CA Crédit');
    const route = AppConstants.caCreditEndpoint;
    final retenusO = <String, List<String>>{}, retenusN = <String, List<String>>{};
    List<String> lignesO() => [
          for (final e in find.byType(ListTile).evaluate())
            '${texteDe((e.widget as ListTile).title!)}|${norm(texteDe(find.descendant(of: find.byWidget(e.widget), matching: find.textContaining('Montant:')).evaluate().single.widget)!.replaceFirst('Montant: ', ''))}',
        ];
    List<String> lignesN() => [for (final (t, v) in cartes()) '$t|${norm(v)}'];
    await monter(tester, m.ancien, nouvelle: false);
    await toucher(tester, find.text('Afficher les Ventes à Crédit'));
    final jourO = params(route);
    retenusO[''] = lignesO();
    for (final q in ['beta', 'fac-t-00', 'mutuelle', 'ENFANT']) {
      await tester.enterText(find.byType(TextField), q);
      await pomper(tester, 3);
      retenusO[q] = lignesO();
    }
    final requetesO = serveur.recues(route).length;
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final jourN = params(route);
    retenusN[''] = lignesN();
    expect(norm(valeurNouvelle('Montant à crédit')), '${DonneesLot3.totalCredit}');
    for (final q in ['beta', 'fac-t-00', 'mutuelle', 'ENFANT']) {
      await tester.enterText(find.byKey(const Key('champ_recherche')), q);
      await pomper(tester, 8);
      retenusN[q] = lignesN();
    }
    final requetesN = serveur.recues(route).length;
    await demonter(tester);

    expect(jourO.single, duJour);
    expect(jourN, jourO);
    expect(requetesO, 1, reason: 'recherche locale d\'origine');
    expect(requetesN, 1, reason: 'recherche locale : aucune nouvelle requête');
    expect(retenusO[''], hasLength(6));
    expect(retenusO['beta'], hasLength(2));
    expect(retenusO['ENFANT'], hasLength(1));
    expect(retenusN, retenusO);
  });

  // -------------------------------------------------------------------------------------------------------------
  // CA Global
  // -------------------------------------------------------------------------------------------------------------

  testWidgets('CA Global : mêmes requêtes (jour, mois dernier) et mêmes totaux (brut, net, modes de paiement)', (tester) async {
    ecranHaut(tester);
    final m = module('CA Global');
    const route = AppConstants.caAllEndpoint;
    const lignes = ['Total Espèces', 'Total Crédit', 'Total Mobile Money', 'Total Carte Bancaire', 'Total Chèque', 'Total Virement', 'TOTAL CA BRUT',
      'Remise sur CA', 'Total TVA', 'TOTAL CA NET'];
    await monter(tester, m.ancien, nouvelle: false);
    await toucher(tester, find.text('Afficher le CA Global'));
    final jourO = params(route);
    final totauxO = {for (final l in lignes) l: norm(valeurAncienne('$l:'))};
    serveur.oublierRequetes();
    if (moisDernierPossible) await moisDernier(tester, nouvelle: false);
    final moisO = params(route);
    final joursO = [for (final e in find.byType(ListTile).evaluate()) norm(texteDe((e.widget as ListTile).trailing!)!.replaceFirst('Total CA: ', ''))];
    await demonter(tester);

    await monter(tester, m.nouveau, nouvelle: true);
    final jourN = params(route);
    final totauxN = {for (final l in lignes) l: norm(valeurNouvelle(l))};
    expect(norm(valeurNouvelle('CA brut')), totauxN['TOTAL CA BRUT']);
    expect(norm(valeurNouvelle('CA net')), totauxN['TOTAL CA NET']);
    serveur.oublierRequetes();
    if (moisDernierPossible) await moisDernier(tester, nouvelle: true);
    final moisN = params(route);
    final joursN = [for (final (_, v) in cartes()) norm(v)];
    await demonter(tester);

    expect(jourO.single, duJour);
    expect(jourN, jourO);
    expect(totauxO['TOTAL CA BRUT'], '${DonneesFictives.totalBrutCa}');
    expect(totauxN, totauxO);
    if (moisDernierPossible) {
      expect(moisO.single, duMoisDernier);
      expect(moisN, moisO);
      expect(joursO, hasLength(3), reason: 'détail par jour, triés par date');
      expect(joursN, joursO);
    }
  });
}
