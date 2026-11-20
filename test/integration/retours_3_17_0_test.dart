// Réponse du serveur aux demandes 67 et 68 (3.17.0), écrans contre le faux serveur (client HTTP en mémoire, horloge
// simulée, données fictives). Le serveur à jour (support/donnees_3_17_0.dart) n'est pas encore déployé en officine :
// chaque écran est joué contre le serveur à jour ET contre le serveur ancien (comportement 3.16.0 inchangé).
//  67. CA crédit :
//    - réponse OBJET détectée : chiffres clés du serveur (toutes les lignes, pas la page), pages de 50 demandées au
//      défilement, bout à bout, dernière page, rien au-delà du total ; page vide inattendue → arrêt ;
//    - recherche (300 ms) et tiers payant envoyés au serveur ; réponse périmée jamais affichée ;
//    - tirer pour rafraîchir : page 0 sans filtre ; PDF : toutes les ventes filtrées en une requête ;
//    - première page lente : « Lecture de la période… » dès le départ, jamais deux fois la même lecture (⟳, recherche
//      pendant la lecture), 50 s acceptées ;
//    - réponse LISTE (serveur ancien) : recherche et filtre locaux comme la 3.16.0 ; mode retenu pour la session
//      (requêtes suivantes : celles de la 3.16.0) ;
//  68. Carte TVA de l'accueil : /tableau-bord/tva?date=&frais=0, mêmes montants affichés qu'avec /api/v3/tvas ; ⟳ →
//      frais=1 ; 404 / 403 → repli /api/v3/tvas, route retenue ; forme inattendue → repli, route non retenue.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_pdf.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart' show formaterMontant;
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/utils/date_formatter.dart';

import '../support/application.dart';
import '../support/donnees_3_17_0.dart';
import '../support/donnees_lot3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/grandes_donnees.dart';
import '../support/polices.dart';
import 'retours_3_10_0_test.dart' show demonter, pomper, serveur;
import 'retours_3_16_0_test.dart' show cle, maintenant, monterEcran;

const routeCredit = '/ca-credit';

List<Map<String, String>> recues(String chemin) => [for (final r in serveur.recues(chemin)) r.parametres];

String chiffre(WidgetTester tester, String id) =>
    tester.widget<ChiffreCle>(find.byWidgetPredicate((w) => w is ChiffreCle && w.id == id, skipOffstage: false)).valeur;

String? detailChiffre(WidgetTester tester, String id) =>
    tester.widget<ChiffreCle>(find.byWidgetPredicate((w) => w is ChiffreCle && w.id == id, skipOffstage: false)).detail;

/// Factures des cartes construites (ordre d'affichage).
List<String> facturesConstruites(WidgetTester tester) => [
      for (final e in find.byType(CarteLigne, skipOffstage: false).evaluate())
        for (final l in (e.widget as CarteLigne).lignes)
          if (l.contains('Facture ')) l.split('Facture ').last,
    ];

/// Défile jusqu'au bas de la liste, page après page, en relevant les factures affichées dans l'ordre (les cartes
/// sont construites à la demande : celles qui sortent de l'écran disparaissent).
Future<List<String>> defilerJusquAuBout(WidgetTester tester) async {
  final vues = <String>{...facturesConstruites(tester)};
  var stables = 0;
  for (var i = 0; i < 300 && stables < 6; i++) {
    await tester.drag(cle('defilement_module'), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    final n = vues.length;
    vues.addAll(facturesConstruites(tester));
    stables = vues.length == n ? stables + 1 : 0;
  }
  await pomper(tester, 3);
  return vues.toList();
}

Future<void> saisirRecherche(WidgetTester tester, String texte) async {
  await tester.enterText(cle('champ_recherche'), texte);
  await tester.pump(const Duration(milliseconds: 50));
}

final debutJour = DateFormatter.toApiFormat(maintenant);

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    serveur.installerRoutesParDefaut();
    CaCreditDonnees.oublierModes();
  });

  group('67 · CA crédit, serveur à jour (réponse objet)', () {
    testWidgets('objet détecté : chiffres clés du serveur, pages de 50 au défilement, bout à bout, dernière page, rien au-delà', (tester) async {
      donneesLot3(serveur);
      final lignes = GrandesDonnees.caCredit(130);
      Donnees3170.installerCaCredit(serveur, lignes);
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      final premiere = recues(routeCredit).single;
      expect(premiere['start'], '0');
      expect(premiere['limit'], '50');
      expect(premiere['dtStart'], debutJour);
      expect(premiere.containsKey('query'), isFalse);
      expect(premiere.containsKey('tiersPayant'), isFalse);
      // Chiffres clés : toutes les ventes de la période (130), pas seulement la page (50).
      final montant = lignes.fold<num>(0, (s, o) => s + (o['montant'] as num));
      expect(chiffre(tester, 'ventes'), formaterNombre(130));
      expect(chiffre(tester, 'montant'), formaterMontant(montant));
      expect(chiffre(tester, 'clients'), formaterNombre(130));
      expect(chiffre(tester, 'tiers'), formaterNombre(9));
      expect(facturesConstruites(tester).length, lessThanOrEqualTo(50));
      final vues = await defilerJusquAuBout(tester);
      final starts = [for (final p in recues(routeCredit)) p['start']];
      expect(starts, ['0', '50', '100'], reason: 'une requête par page, aucune au-delà du total');
      expect(vues, [for (final o in Donnees3170.trier(lignes)) o['numFacturation']],
          reason: 'pages bout à bout dans l\'ordre du serveur, sans doublon ni trou');
      expect(find.text('130 lignes affichées sur 130'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await demonter(tester);
    });

    testWidgets('page vide avant le total annoncé (période relue entre deux pages) : arrêt, aucune boucle', (tester) async {
      donneesLot3(serveur);
      final lignes = GrandesDonnees.caCredit(80);
      serveur.route(routeCredit, (r) {
        final rep = Donnees3170.caCredit(lignes, r.parametres) as Map<String, Object?>;
        // Le serveur annonce 200 ventes mais n'en a que 80.
        return ReponseFausse.json({...rep, 'total': 200});
      }, methode: 'GET');
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      final vues = await defilerJusquAuBout(tester);
      expect([for (final p in recues(routeCredit)) p['start']], ['0', '50', '80']);
      expect(vues, hasLength(80));
      expect(find.text('80 lignes affichées sur 80'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('recherche : UNE requête 300 ms après la saisie, query envoyée, chiffres du serveur ; effacer → sans filtre', (tester) async {
      donneesLot3(serveur);
      final lignes = GrandesDonnees.caCredit(130);
      Donnees3170.installerCaCredit(serveur, lignes);
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      serveur.oublierRequetes();
      for (final t in ['F', 'FA', 'FAC', 'FAC-P-12']) {
        await saisirRecherche(tester, t);
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(recues(routeCredit), isEmpty, reason: 'anti-rebond : rien avant 300 ms');
      await pomper(tester, 3);
      final p = recues(routeCredit).single;
      expect(p['query'], 'FAC-P-12');
      expect(p['start'], '0');
      final attendues = Donnees3170.filtrer(lignes, 'FAC-P-12', null);
      expect(chiffre(tester, 'ventes'), formaterNombre(attendues.length));
      expect(detailChiffre(tester, 'ventes'), 'sur ${formaterNombre(130)}');
      expect(chiffre(tester, 'montant'), formaterMontant(attendues.fold<num>(0, (s, o) => s + (o['montant'] as num))));
      expect(await defilerJusquAuBout(tester), [for (final o in Donnees3170.trier(attendues)) o['numFacturation']]);
      await tester.drag(cle('defilement_module'), const Offset(0, 20000));
      await pomper(tester, 3);
      serveur.oublierRequetes();
      await saisirRecherche(tester, '');
      await pomper(tester, 5);
      expect(recues(routeCredit).single.containsKey('query'), isFalse);
      expect(chiffre(tester, 'ventes'), formaterNombre(130));
      await demonter(tester);
    });

    testWidgets('réponse périmée : la recherche précédente (lente) n\'est jamais affichée ; une seule nouvelle lecture', (tester) async {
      donneesLot3(serveur);
      final lignes = GrandesDonnees.caCredit(130);
      Donnees3170.installerCaCredit(serveur, lignes,
          delai: (p) => p['query'] == 'FAC-P-1' ? const Duration(seconds: 2) : (p['query'] != null ? const Duration(milliseconds: 500) : null));
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      serveur.oublierRequetes();
      await saisirRecherche(tester, 'FAC-P-1');
      await tester.pump(const Duration(milliseconds: 400));
      expect([for (final p in recues(routeCredit)) p['query']], ['FAC-P-1']);
      await saisirRecherche(tester, 'FAC-P-12');
      await tester.pump(const Duration(milliseconds: 400));
      expect(recues(routeCredit), hasLength(1), reason: 'la lecture en cours est attendue (période gardée par le serveur ensuite)');
      final ancienne = formaterNombre(Donnees3170.filtrer(lignes, 'FAC-P-1', null).length);
      final nouvelle = formaterNombre(Donnees3170.filtrer(lignes, 'FAC-P-12', null).length);
      // La réponse de « FAC-P-1 » arrive : périmée, jamais affichée.
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final f = find.byWidgetPredicate((w) => w is ChiffreCle && w.id == 'ventes');
        if (f.evaluate().isNotEmpty) expect(chiffre(tester, 'ventes'), isNot(ancienne), reason: 'réponse périmée affichée');
      }
      await pomper(tester, 8);
      expect([for (final p in recues(routeCredit)) p['query']], ['FAC-P-1', 'FAC-P-12']);
      expect(chiffre(tester, 'ventes'), nouvelle);
      await demonter(tester);
    });

    testWidgets('tiers payant : liste du serveur (libellé sans espace autour), envoyé tel quel, chiffres du serveur', (tester) async {
      donneesLot3(serveur);
      final lignes = Donnees3170.ventesAvecEspace();
      Donnees3170.installerCaCredit(serveur, lignes);
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      expect(chiffre(tester, 'tiers'), '3');
      serveur.oublierRequetes();
      await tester.tap(cle('bouton_filtres'));
      await pomper(tester, 5);
      await tester.tap(cle('filtre_tiers'));
      await pomper(tester, 5);
      final libelle = Donnees3170.tiersEspace.trim();
      await tester.tap(find.text(libelle).hitTestable().last);
      await pomper(tester, 5);
      await tester.tap(cle('filtres_appliquer'));
      await pomper(tester, 8);
      final p = recues(routeCredit).single;
      expect(p['tiersPayant'], Donnees3170.tiersEspace);
      expect(chiffre(tester, 'ventes'), '1');
      expect(detailChiffre(tester, 'ventes'), 'sur 7');
      expect(chiffre(tester, 'montant'), formaterMontant(7000));
      expect(chiffre(tester, 'tiers'), '1');
      expect(find.text('Tiers payant : $libelle'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('tirer pour rafraîchir : page 0 SANS filtre (recherche effacée), le serveur relit la base', (tester) async {
      donneesLot3(serveur);
      final lignes = GrandesDonnees.caCredit(130);
      Donnees3170.installerCaCredit(serveur, lignes);
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      await saisirRecherche(tester, 'FAC-P-12');
      await pomper(tester, 5);
      expect(recues(routeCredit).last['query'], 'FAC-P-12');
      serveur.oublierRequetes();
      await tester.runAsync(() async {});
      final f = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
      await pomper(tester, 5);
      await f;
      final p = recues(routeCredit).single;
      expect(Donnees3170.premiere(p), isTrue, reason: 'start 0, ni query ni tiersPayant');
      expect(chiffre(tester, 'ventes'), formaterNombre(130));
      expect(find.descendant(of: cle('champ_recherche'), matching: find.text('FAC-P-12')), findsNothing);
      // La recherche repart normalement après la remise à zéro.
      serveur.oublierRequetes();
      await saisirRecherche(tester, 'FAC-P-12');
      await pomper(tester, 5);
      expect(recues(routeCredit).single['query'], 'FAC-P-12');
      await demonter(tester);
    });

    testWidgets('PDF : toutes les ventes filtrées en UNE requête (limit = total), mêmes chiffres', (tester) async {
      donneesLot3(serveur);
      final lignes = GrandesDonnees.caCredit(130);
      Donnees3170.installerCaCredit(serveur, lignes);
      final sorties = <(ContenuAnalysePdf, String)>[];
      final avant = AnalysesPdf.sortie;
      AnalysesPdf.sortie = (c, nom) async => sorties.add((c, nom));
      addTearDown(() => AnalysesPdf.sortie = avant);
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      await saisirRecherche(tester, '1');
      await pomper(tester, 5);
      serveur.oublierRequetes();
      await tester.tap(cle('menu_exports'));
      await pomper(tester, 5);
      await tester.tap(find.text('PDF des ventes à crédit').last);
      await pomper(tester, 8);
      final attendues = Donnees3170.trier(Donnees3170.filtrer(lignes, '1', null));
      expect(attendues.length, allOf(greaterThan(50), lessThan(130)), reason: 'plus d\'une page, filtrée');
      final p = recues(routeCredit).single;
      expect(p['limit'], '${attendues.length}');
      expect(p['query'], '1');
      final (contenu, _) = sorties.single;
      expect(contenu.lignes.map((l) => l[3]), [for (final o in attendues) o['numFacturation']]);
      expect(contenu.filtres, [('Recherche', '1')]);
      expect(contenu.chiffres.firstWhere((c) => c.$1 == 'Ventes de la période (sans filtre)').$2, formaterNombre(130));
      await demonter(tester);
    });
  });

  group('67 · Première page lente (12 à 16 s : le serveur lit toute la période)', () {
    testWidgets('« Lecture de la période… » dès le départ ; ⟳ et recherche pendant la lecture : aucune lecture en double', (tester) async {
      donneesLot3(serveur);
      final lignes = GrandesDonnees.caCredit(130);
      Donnees3170.installerCaCredit(serveur, lignes, delai: (p) => Donnees3170.premiere(p) ? const Duration(seconds: 15) : null);
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Lecture de la période…'), findsOneWidget, reason: 'indicateur clair dès le départ');
      expect(cle('etat_chargement'), findsOneWidget);
      expect(recues(routeCredit), hasLength(1));
      // ⟳ pendant la lecture : la lecture en cours est reprise.
      final f = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
      await tester.pump(const Duration(seconds: 1));
      expect(recues(routeCredit), hasLength(1), reason: '⟳ : pas de seconde lecture de la période');
      // Recherche pendant la lecture : attendue, puis UNE requête filtrée (rapide : période gardée par le serveur).
      await saisirRecherche(tester, 'FAC-P-12');
      await tester.pump(const Duration(seconds: 2));
      expect(recues(routeCredit), hasLength(1), reason: 'recherche pendant la lecture : aucune requête de plus');
      expect(find.textContaining('Lecture de la période…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 12));
      await pomper(tester, 5);
      await f;
      expect([for (final p in recues(routeCredit)) p['query']], [null, 'FAC-P-12']);
      expect(chiffre(tester, 'ventes'), formaterNombre(Donnees3170.filtrer(lignes, 'FAC-P-12', null).length));
      expect(tester.takeException(), isNull);
      await demonter(tester);
    });

    testWidgets('50 s : la page arrive (délai propre à la route, au-delà des 45 s des autres routes)', (tester) async {
      donneesLot3(serveur);
      Donnees3170.installerCaCredit(serveur, GrandesDonnees.caCredit(60), delai: (p) => const Duration(seconds: 50));
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      for (var i = 0; i < 52; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await pomper(tester, 3);
      expect(cle('etat_erreur'), findsNothing);
      expect(chiffre(tester, 'ventes'), '60');
      expect(recues(routeCredit), hasLength(1));
      await demonter(tester);
    });

    testWidgets('changer de période pendant la lecture : la nouvelle période est lue tout de suite, l\'ancienne réponse ignorée', (tester) async {
      donneesLot3(serveur);
      Donnees3170.installerCaCredit(serveur, GrandesDonnees.caCredit(60),
          delai: (p) => p['dtStart'] == debutJour ? const Duration(seconds: 15) : const Duration(seconds: 1));
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Hier').first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(recues(routeCredit), hasLength(2));
      await tester.pump(const Duration(seconds: 2));
      await pomper(tester, 3);
      expect(chiffre(tester, 'ventes'), '60');
      await tester.pump(const Duration(seconds: 15));
      await pomper(tester, 3);
      expect(recues(routeCredit), hasLength(2));
      expect(recues(routeCredit).last['dtStart'], isNot(debutJour));
      await demonter(tester);
    });
  });

  group('67 · Serveur ancien (réponse liste) : comportement 3.16.0', () {
    testWidgets('liste : recherche et tiers payant LOCAUX (aucune requête), mêmes chiffres ; mode retenu : requêtes de la 3.16.0', (tester) async {
      donneesLot3(serveur); // /ca-credit → liste, paramètres ignorés (serveur ancien)
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      expect(recues(routeCredit).single['limit'], '50', reason: 'première lecture : paramètres ignorés par un serveur ancien');
      expect(chiffre(tester, 'ventes'), '6');
      expect(chiffre(tester, 'montant'), formaterMontant(DonneesLot3.totalCredit));
      expect(chiffre(tester, 'clients'), '3');
      await saisirRecherche(tester, 'beta');
      await pomper(tester, 8);
      expect(chiffre(tester, 'ventes'), '2');
      expect(detailChiffre(tester, 'ventes'), 'sur 6');
      expect(recues(routeCredit), hasLength(1), reason: 'recherche locale');
      await saisirRecherche(tester, '');
      await pomper(tester, 8);
      // Page suivante : jamais demandée (toutes les ventes sont là) ; « Afficher plus » local comme avant.
      await tester.drag(cle('defilement_module'), const Offset(0, -3000));
      await pomper(tester, 3);
      expect(recues(routeCredit), hasLength(1));
      // Changement de période : mode liste retenu → la requête de la 3.16.0 (dtStart, dtEnd seulement).
      await tester.drag(cle('defilement_module'), const Offset(0, 3000));
      await pomper(tester, 2);
      await tester.tap(find.text('Hier').first);
      await pomper(tester, 8);
      final p = recues(routeCredit).last;
      expect(p.keys.toSet(), {'dtStart', 'dtEnd'});
      expect(tester.takeException(), isNull);
      await demonter(tester);
    });

    testWidgets('liste de plus de 50 ventes : « Afficher plus » local (aucune requête), comme la 3.16.0', (tester) async {
      donneesLot3(serveur);
      serveur.quand(routeCredit, ReponseFausse.json(GrandesDonnees.caCredit(120)), methode: 'GET');
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await attendreWidget(tester, cle('chiffre_ventes'));
      expect(chiffre(tester, 'ventes'), '120');
      await tester.scrollUntilVisible(cle('bouton_afficher_plus'), 500, scrollable: find.descendant(of: cle('defilement_module'), matching: find.byType(Scrollable)).first);
      expect(find.text('50 lignes affichées sur 120'), findsOneWidget);
      await tester.tap(cle('bouton_afficher_plus'));
      await pomper(tester, 3);
      await tester.scrollUntilVisible(cle('bouton_afficher_plus'), 500, scrollable: find.descendant(of: cle('defilement_module'), matching: find.byType(Scrollable)).first);
      expect(find.text('100 lignes affichées sur 120'), findsOneWidget);
      expect(recues(routeCredit), hasLength(1));
      await demonter(tester);
    });

    testWidgets('forme inattendue : aucune vente (comme la 3.16.0), pas de mode retenu', (tester) async {
      donneesLot3(serveur);
      serveur.quand(routeCredit, ReponseFausse.json({'success': true, 'inattendu': 1}), methode: 'GET');
      await monterEcran(tester, () => CaCreditNouveau(maintenant: () => maintenant));
      await pomper(tester, 5);
      expect(find.text('Aucune vente à crédit'), findsOneWidget);
      expect(recues(routeCredit).single['limit'], '50');
      await demonter(tester);
    });
  });

  group('68 · Carte TVA de l\'accueil', () {
    /// Accueil affiché / masqué (comme un changement d'onglet), même mémoire et même session.
    Widget accueil(ValueNotifier<bool> visible, MemoireTableauBord memoire) => ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, v, __) =>
              Scaffold(body: v ? AccueilTableauPrestige(maintenant: () => maintenant, memoire: memoire) : const Center(child: Text('Autre onglet'))),
        );

    /// Lignes affichées par la carte TVA.
    List<String> lignesTva(WidgetTester tester) => [
          for (final e in find.descendant(of: cle('carte_tableau_bord_tva'), matching: find.byType(LigneDetail)).evaluate())
            '${(e.widget as LigneDetail).libelle}=${(e.widget as LigneDetail).valeur}',
        ];

    Future<List<String>> afficher(WidgetTester tester, ValueNotifier<bool> visible) async {
      visible.value = true;
      await pomper(tester, 10);
      final liste = find.descendant(of: cle('defilement_tableau_bord'), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(cle('carte_tableau_bord_tva'), 300, scrollable: liste, maxScrolls: 40);
      await pomper(tester, 5);
      return lignesTva(tester);
    }

    Future<void> masquer(WidgetTester tester, ValueNotifier<bool> visible) async {
      visible.value = false;
      await pomper(tester, 2);
      serveur.oublierRequetes();
    }

    Future<ValueNotifier<bool>> monter(WidgetTester tester, MemoireTableauBord memoire) async {
      final visible = ValueNotifier(false);
      await monterEcran(tester, () => accueil(visible, memoire), hauteur: 3000);
      serveur.oublierRequetes();
      return visible;
    }

    testWidgets('serveur à jour : /tableau-bord/tva?date=<jour>&frais=0, pas de /tvas ; mêmes montants affichés qu\'avant ; ⟳ → frais=1', (tester) async {
      donneesLot3(serveur);
      var visible = await monter(tester, MemoireTableauBord());
      final avant = await afficher(tester, visible);
      expect(serveur.recues('/tvas'), isNotEmpty, reason: 'serveur ancien : /api/v3/tvas');
      await demonter(tester);

      serveur.installerRoutesParDefaut();
      donneesLot3(serveur);
      serveur.route('/tableau-bord/tva', (r) => ReponseFausse.json(Donnees3170.tva()), methode: 'GET');
      visible = await monter(tester, MemoireTableauBord());
      final apres = await afficher(tester, visible);
      final p = serveur.recues('/tableau-bord/tva').single.parametres;
      expect(p, {'date': debutJour, 'frais': '0'});
      expect(serveur.recues('/tvas'), isEmpty);
      expect(apres, isNotEmpty);
      expect(apres, avant, reason: 'mêmes taux, mêmes parts, mêmes montants TTC, même total');
      serveur.oublierRequetes();
      await tester.drag(find.descendant(of: cle('defilement_tableau_bord'), matching: find.byType(Scrollable)).first, const Offset(0, 20000));
      await pomper(tester, 2);
      await tester.tap(cle('tableau_bord_actualiser'));
      await pomper(tester, 10);
      expect(serveur.recues('/tableau-bord/tva').single.parametres['frais'], '1');
      expect(serveur.recues('/tvas'), isEmpty);
      await demonter(tester);
    });

    for (final (cas, reponse) in [
      ('404 (serveur ancien)', ReponseFausse.introuvable()),
      ('403 (droit refusé)', ReponseFausse.json({'success': false}, statut: 403)),
    ]) {
      testWidgets('$cas : repli /api/v3/tvas, mêmes lignes ; route retenue (plus demandée avant ⟳)', (tester) async {
        donneesLot3(serveur);
        serveur.quand('/tableau-bord/tva', reponse, methode: 'GET');
        var t = DateTime(2026, 10, 21, 11);
        final memoire = MemoireTableauBord(horloge: () => t);
        final visible = await monter(tester, memoire);
        final l = await afficher(tester, visible);
        expect(serveur.recues('/tableau-bord/tva'), hasLength(1));
        expect(serveur.recues('/tvas'), hasLength(1));
        expect(serveur.recues('/tvas').single.parametres['typeVente'], 'TOUT');
        expect(serveur.recues('/officine'), isEmpty, reason: 'route essayée : son 404 ne déclenche pas la vérification /officine');
        expect(l, isNotEmpty);
        expect(find.descendant(of: cle('carte_tableau_bord_tva'), matching: cle('carte_indisponible')), findsNothing);
        // Plus tard (mémoire des cartes expirée), même session : repli direct.
        await masquer(tester, visible);
        t = t.add(const Duration(minutes: 3));
        expect(await afficher(tester, visible), l);
        expect(serveur.recues('/tableau-bord/tva'), isEmpty, reason: 'route absente / refusée retenue');
        expect(serveur.recues('/tvas'), hasLength(1));
        // ⟳ : tout est oublié, la route est essayée de nouveau (une mise à jour du serveur se voit).
        serveur.oublierRequetes();
        await tester.drag(find.descendant(of: cle('defilement_tableau_bord'), matching: find.byType(Scrollable)).first, const Offset(0, 20000));
        await pomper(tester, 2);
        await tester.tap(cle('tableau_bord_actualiser'));
        await pomper(tester, 10);
        expect(serveur.recues('/tableau-bord/tva'), hasLength(1));
        await demonter(tester);
      });
    }

    testWidgets('forme inattendue : repli /api/v3/tvas pour cette lecture, route NON retenue', (tester) async {
      donneesLot3(serveur);
      serveur.quand('/tableau-bord/tva', ReponseFausse.json({'success': true, 'data': 'inattendu'}), methode: 'GET');
      var t = DateTime(2026, 10, 21, 11);
      final memoire = MemoireTableauBord(horloge: () => t);
      final visible = await monter(tester, memoire);
      final l = await afficher(tester, visible);
      expect(serveur.recues('/tvas'), hasLength(1));
      expect(l, isNotEmpty);
      await masquer(tester, visible);
      t = t.add(const Duration(minutes: 3));
      serveur.route('/tableau-bord/tva', (r) => ReponseFausse.json(Donnees3170.tva()), methode: 'GET');
      expect(await afficher(tester, visible), l);
      expect(serveur.recues('/tableau-bord/tva'), hasLength(1));
      expect(serveur.recues('/tvas'), isEmpty);
      await demonter(tester);
    });

    testWidgets('aucune vente ce mois-ci (data vide) : message de la carte, pas de repli', (tester) async {
      donneesLot3(serveur);
      serveur.quand('/tableau-bord/tva', ReponseFausse.json({'success': true, 'data': []}), methode: 'GET');
      final visible = await monter(tester, MemoireTableauBord());
      await afficher(tester, visible);
      expect(find.descendant(of: cle('carte_tableau_bord_tva'), matching: find.text('Aucune vente ce mois-ci.')), findsOneWidget);
      expect(serveur.recues('/tvas'), isEmpty);
      await demonter(tester);
    });
  });
}
