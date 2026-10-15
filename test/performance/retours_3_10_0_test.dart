// PERFORMANCE — nouveautés 3.10.0 (téléphone 411 dp ; Sunmi 360 dp pour les pages), contre le faux serveur Prestige
// « en mémoire » :
//  - icônes illustrées (P4) : DÉCODAGE RÉEL des 38 images embarquées à la taille affichée (temps, mémoire décodée) ;
//  - accueil A en « 6 tuiles par page » et P4 : passage de toutes les pages (pire image), AUCUNE requête ;
//  - accueil B en « 6 tuiles par page » sur Sunmi 720 × 1440 : passage des pages (pire image), aucune requête ;
//  - Pointage BL par groupe : requêtes exactes (listes à l'ouverture ; changement de mode : 0 ; choix du groupe : 1).
// Seuils : test/support/performance.dart et test/README.md (« Seuils de performance »).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/icones_illustrees.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';

import '../support/donnees_vague1.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void appareil(WidgetTester tester, {double dpr = 2.625, Size dp = const Size(411, 891)}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(dp.width * dpr, dp.height * dpr);
  addTearDown(tester.view.reset);
}

/// Touche « page suivante » jusqu'à la dernière page ; chaque passage est chronométré image par image.
Future<(ChronoImages, int)> toutesLesPages(WidgetTester tester) async {
  final chrono = ChronoImages();
  var pages = 1;
  final suivante = find.byKey(const Key('page_menus_suivante'));
  while (tester.widget<IconButton>(suivante).onPressed != null && pages < 40) {
    await tester.tap(suivante);
    for (var i = 0; i < 20; i++) {
      await chrono.pump(tester, const Duration(milliseconds: 16)); // animation de 250 ms, image par image
    }
    pages++;
  }
  return (chrono, pages);
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() => brancherEnMemoire(serveur));

  testWidgets('icônes illustrées : décodage réel des 38 images à la taille affichée (temps, mémoire)', (tester) async {
    appareil(tester);
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    final chemins = {...illustrationsMenus.values, ...illustrationsOnglets.values}.map(iconeIllustree).toList();
    // Taille la plus grande affichée : tuile 36 dp (barre du bas 26 dp, lignes 34 dp), × 2,625.
    final cote = (36 * 2.625).ceil();
    final ms = await tester.runAsync(() async {
      final sw = Stopwatch()..start();
      for (final c in chemins) {
        await precacheImage(ResizeImage(AssetImage(c), width: cote, height: cote), ctx);
      }
      return sw.elapsedMicroseconds / 1000;
    });
    final octets = chemins.length * cote * cote * 4;
    mesurer('Icônes illustrées — décodage des ${chemins.length} images (${cote}px)', ms!, seuil: Seuils.iconesDecodageMs, unite: 'ms');
    mesurer('Icônes illustrées — mémoire décodée', octets / 1024, seuil: Seuils.iconesMemoireKo, unite: 'Ko',
        detail: '${chemins.length} × $cote × $cote × 4 octets (décodées à la taille affichée, pas en 144 px)');
  });

  testWidgets('accueil A « 6 tuiles par page » en P4 : toutes les pages, pire image, aucune requête', (tester) async {
    appareil(tester);
    preparerNouvelle(serveur, p: Presentation.tableauDeBord, affichage: AffichageMenus.parSix, style: StyleIcones.p4);
    donneesAccueil(serveur);
    await connecterEnMemoire(tester);
    await pomperJusqua(tester, () => find.byKey(const Key('pages_menus')).evaluate().isNotEmpty, raison: 'menus par pages');
    final rs = await compter(serveur, () async {
      final (chrono, pages) = await toutesLesPages(tester);
      expect(pages, greaterThan(2));
      mesurer('Accueil A (6 par page, P4) — passage des $pages pages, pire image', chrono.max, seuil: Seuils.imageFroideMs, unite: 'ms',
          detail: chrono.resume);
      mesurer('Accueil A (6 par page, P4) — image courante (p90)', chrono.p90, seuil: Seuils.imageCouranteMs, unite: 'ms');
    });
    mesurer('Requêtes — pages de menus de l\'accueil A', rs.length, seuil: 0, unite: 'requêtes', detail: detailRequetes(rs));
    expect(find.byType(AccueilNouveau), findsOneWidget);
    await fermerApplication(tester);
  });

  testWidgets('accueil B « 6 tuiles par page » sur Sunmi 720 × 1440 : toutes les pages, aucune requête', (tester) async {
    appareil(tester, dpr: 2.0, dp: const Size(360, 720));
    preparerNouvelle(serveur, p: Presentation.compact, affichage: AffichageMenus.parSix, style: StyleIcones.p4);
    await connecterEnMemoire(tester);
    final rs = await compter(serveur, () async {
      final (chrono, pages) = await toutesLesPages(tester);
      expect(pages, greaterThan(2));
      mesurer('Accueil B Sunmi (6 par page, P4) — passage des $pages pages, pire image', chrono.max, seuil: Seuils.imageFroideMs, unite: 'ms',
          detail: chrono.resume);
    });
    mesurer('Requêtes — pages de menus de l\'accueil B', rs.length, seuil: 0, unite: 'requêtes', detail: detailRequetes(rs));
    await fermerApplication(tester);
  });

  testWidgets('Pointage BL par groupe : listes à l\'ouverture (2), changement de mode (0), choix du groupe (1)', (tester) async {
    appareil(tester);
    preparerNouvelle(serveur);
    listesCommunesVague1(serveur);
    final ouverture = await compter(serveur, () async {
      await ouvrirEcran(tester, serveur, const PointageBlScreen(), pret: find.byKey(const Key('pointage_pourquoi')));
    });
    // GET /common/grossiste + GET /common/groupefournisseurs ; aucune liste de pièces sans choix.
    mesurer('Requêtes — Pointage BL ouvert sans choix', ouverture.length, seuil: 2, unite: 'requêtes', detail: detailRequetes(ouverture));
    expect(ouverture.where((r) => r.chemin == ApiPointage.route), isEmpty);
    final mode = await compter(serveur, () async {
      await tester.tap(find.byKey(const Key('pointage_mode_groupe')));
      await tester.pump(const Duration(milliseconds: 300));
    });
    mesurer('Requêtes — Pointage BL, passage « Par groupe »', mode.length, seuil: 0, unite: 'requêtes', detail: detailRequetes(mode));
    final choix = await compter(serveur, () async {
      await tester.tap(find.byKey(const Key('pointage_groupe')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('GROUPE FICTIF').last);
      await pomper(tester, () => find.byKey(const Key('pointage_montant')).evaluate().isNotEmpty, raison: 'montant du groupe');
    });
    mesurer('Requêtes — Pointage BL, choix d\'un groupe', choix.length, seuil: 1, unite: 'requêtes', detail: detailRequetes(choix));
    expect(choix.single.parametres['groupe'], DonneesVague3.groupe);
    await fermerApplication(tester);
  });
}

