// Décisions du pharmacien pour la 3.15.0, écrans contre le faux serveur (client en mémoire), formats réels du serveur
// (branche claude/new-session-xm8ptu, tête df7ba097) :
//  1. Tableau de bord, carte « Affluence (jour × heure) » : GET /tableau-bord/affluence?date=&frais= (af41d77d,
//     TableauBordServiceImpl.affluence : {debut, fin, cases [{jour 1 = lundi, heure, ventes, ca}]}) ; semaine choisie
//     avec ◀ ▶ (pas de semaine future), « Revenir à cette semaine » ; ⟳ → frais=1 ; grille lisible (chiffre blanc ou
//     encre selon la case, contraste ≥ 4,5) ; serveur sans la route → « Indisponible sur ce serveur » ;
//  2. « Péremptions courtes » (99a13f57, ReceptionMobileRessource) : liste filtrée (période : ce mois par défaut,
//     grossiste, statut), total et valeur du serveur, exports Excel / PDF (mêmes filtres), statut changé par PUT
//     …/{id}/statut?statut= (une requête), refus du serveur (403, droit manquant) → statut inchangé, plus proposé ;
//     serveur ancien (404) → « Indisponible sur ce serveur ».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart' show formaterMontant;
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/vague4/peremptions_courtes_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/presences/export_fichier.dart';

import '../support/donnees_vague1.dart';
import '../support/donnees_vague4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';
import 'retours_3_10_0_test.dart' show demonter, monter, pomper, serveur;

/// Mercredi 21/10/2026 : semaine du lundi 19 au dimanche 25.
final maintenant = DateTime(2026, 10, 21, 11, 0);

Finder cle(String k) => find.byKey(Key(k));
Finder dansAffluence(Finder f) => find.descendant(of: cle('carte_tableau_bord_affluence'), matching: f);

double contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

Future<void> toucher(WidgetTester tester, String k) async {
  await tester.ensureVisible(cle(k));
  await tester.tap(cle(k));
  await pomper(tester);
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
    listesCommunesVague1(serveur);
  });

  group('Affluence (jour × heure)', () {
    Future<void> tableau(WidgetTester tester) async {
      await monter(tester, () => Scaffold(body: AccueilTableauPrestige(maintenant: () => maintenant)));
      await pomper(tester, 20);
    }

    testWidgets('semaine du jour : une requête date=lundi, frais=0 ; grille, résumé, légende ; pas de semaine future', (tester) async {
      await tableau(tester);
      final r = serveur.recues(ApiTableauBord.routeAffluence);
      expect(r, hasLength(1));
      expect(r.single.parametres, {'date': '2026-10-19', 'frais': '0'});
      expect(tester.widget<Text>(cle('affluence_semaine')).data, 'Semaine du 19/10 au 25/10');
      expect(tester.widget<Text>(cle('affluence_resume')).data, contains('plus forte affluence : samedi 10 h – 11 h (42)'));
      // Samedi 10 h : la case la plus foncée, chiffre blanc ; une case claire : chiffre encre ; sans vente : vide.
      final pic = find.descendant(of: cle('affluence_case_6_10'), matching: find.byType(Text));
      expect(tester.widget<Text>(pic).data, '42');
      expect(tester.widget<Text>(pic).style!.color, Charte.blanc);
      final clair = find.descendant(of: cle('affluence_case_7_8'), matching: find.byType(Text));
      expect(tester.widget<Text>(clair).style!.color, Charte.encre);
      expect(find.descendant(of: cle('affluence_case_7_15'), matching: find.byType(Text)), findsNothing, reason: 'dimanche après-midi : aucune vente');
      expect(cle('affluence_case_1_7'), findsNothing, reason: 'colonnes de la première à la dernière heure avec une vente (8 h → 20 h)');
      expect(cle('affluence_case_1_20'), findsOneWidget);
      expect(find.descendant(of: cle('affluence_jour_7'), matching: find.text('10')), findsOneWidget, reason: 'dimanche : 5 heures × 2 ventes');
      expect(cle('affluence_legende'), findsOneWidget);
      expect(tester.widget<IconButton>(cle('affluence_suivante')).onPressed, isNull, reason: 'pas de semaine future');
      expect(cle('affluence_cette_semaine'), findsNothing);
      expect(tester.takeException(), isNull);
      await demonter(tester);
    });

    testWidgets('◀ : semaine précédente (date=12/10, cache du serveur) ; ▶ et « Revenir à cette semaine » ; ⟳ → frais=1', (tester) async {
      await tableau(tester);
      serveur.oublierRequetes();
      await toucher(tester, 'affluence_precedente');
      expect(serveur.recues(ApiTableauBord.routeAffluence).single.parametres, {'date': '2026-10-12', 'frais': '0'});
      expect(tester.widget<Text>(cle('affluence_semaine')).data, 'Semaine du 12/10 au 18/10');
      expect(tester.widget<IconButton>(cle('affluence_suivante')).onPressed, isNotNull);
      await toucher(tester, 'affluence_precedente');
      expect(serveur.recues(ApiTableauBord.routeAffluence).last.parametres['date'], '2026-10-05');
      await toucher(tester, 'affluence_suivante');
      expect(serveur.recues(ApiTableauBord.routeAffluence).last.parametres['date'], '2026-10-12');
      await toucher(tester, 'affluence_cette_semaine');
      expect(serveur.recues(ApiTableauBord.routeAffluence).last.parametres, {'date': '2026-10-19', 'frais': '0'});
      expect(cle('affluence_cette_semaine'), findsNothing);
      serveur.oublierRequetes();
      await tester.tap(cle('tableau_bord_actualiser'));
      await pomper(tester, 20);
      expect(serveur.recues(ApiTableauBord.routeAffluence).single.parametres, {'date': '2026-10-19', 'frais': '1'}, reason: '⟳ : recalcul');
      serveur.oublierRequetes();
      await toucher(tester, 'affluence_precedente');
      expect(serveur.recues(ApiTableauBord.routeAffluence).single.parametres['frais'], '0', reason: 'changer de semaine lit le cache');
      await demonter(tester);
    });

    testWidgets('serveur sans la route (404) : « Indisponible sur ce serveur », les autres cartes s\'affichent', (tester) async {
      serveur.quand(ApiTableauBord.routeAffluence, ReponseFausse.introuvable());
      await tableau(tester);
      expect(dansAffluence(cle('carte_indisponible')), findsOneWidget);
      expect(cle('chiffre_tb_ca'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('semaine sans vente : « Aucune vente cette semaine. » ; erreur du serveur : message et Réessayer', (tester) async {
      serveur.quand(ApiTableauBord.routeAffluence, ReponseFausse.json({'debut': '2026-10-19', 'fin': '2026-10-25', 'cases': <Object>[], 'success': true}));
      await tableau(tester);
      expect(dansAffluence(cle('affluence_vide')), findsOneWidget);
      await demonter(tester);
      serveur.quand(ApiTableauBord.routeAffluence, ReponseFausse.json({'erreur': true, 'success': false}));
      await tableau(tester);
      expect(dansAffluence(find.text('Réessayer')), findsOneWidget);
      expect(dansAffluence(find.textContaining('n\'a pas pu calculer l\'affluence')), findsOneWidget);
      await demonter(tester);
    });

    for (final (nom, largeur) in const [('téléphone', 411.0), ('Sunmi', 360.0)]) {
      testWidgets('$nom : grille sans débordement ; 24 heures (garde) → défilement horizontal, jours toujours visibles', (tester) async {
        serveur.quand(
            ApiTableauBord.routeAffluence,
            ReponseFausse.json({
              'debut': '2026-10-19', 'fin': '2026-10-25', 'success': true,
              'cases': [for (var h = 0; h < 24; h++) {'jour': 3, 'heure': h, 'ventes': 1 + h * 5, 'ca': 1000}],
            }));
        await tableau(tester);
        tester.view.physicalSize = Size(largeur * tester.view.devicePixelRatio, 6000 * tester.view.devicePixelRatio);
        await pomper(tester);
        expect(tester.takeException(), isNull);
        expect(cle('affluence_defilement'), findsOneWidget);
        expect(tester.getSize(cle('affluence_case_3_0')).width, greaterThanOrEqualTo(21));
        expect(tester.getRect(cle('affluence_jour_7')).left, greaterThanOrEqualTo(0));
        await demonter(tester);
      });
    }
  });

  group('Affluence : lecture et couleurs', () {
    test('lecture du format du serveur : cases hors bornes ou sans vente ignorées ; pic = le premier (lundi → dimanche)', () {
      final a = AffluenceSemaine.depuis({
        'debut': '2026-10-19',
        'fin': '2026-10-25',
        'cases': [
          {'jour': 2, 'heure': 9, 'ventes': 7, 'ca': 70000},
          {'jour': 1, 'heure': 18, 'ventes': 7, 'ca': 50000},
          {'jour': 8, 'heure': 9, 'ventes': 99},
          {'jour': 3, 'heure': 24, 'ventes': 99},
          {'jour': 4, 'heure': 12, 'ventes': 0},
          'illisible',
        ],
      }, DateTime(2026, 10, 21));
      expect((a.debut, a.fin), (DateTime(2026, 10, 19), DateTime(2026, 10, 25)));
      expect((a.total, a.max, a.heures), (14, 7, (9, 18)));
      expect((a.pic!.jour, a.pic!.heure), (1, 18), reason: 'à égalité, le lundi passe avant le mardi');
      expect(a.de(2, 9)!.ca, 70000);
      // Serveur sans bornes : semaine calculée (lundi du jour demandé).
      final b = AffluenceSemaine.depuis({'cases': <Object>[]}, DateTime(2026, 10, 25));
      expect((b.debut, b.fin, b.pic, b.heures), (DateTime(2026, 10, 19), DateTime(2026, 10, 25), null, null));
    });

    test('chiffre de chaque case lisible : contraste ≥ 4,5 sur toute l\'échelle', () {
      for (var v = 1; v <= 100; v++) {
        final f = fondAffluence(v, 100);
        expect(contraste(f, texteAffluence(f)), greaterThanOrEqualTo(4.5), reason: '$v / 100');
      }
      expect(fondAffluence(0, 10), Charte.grisClair);
    });
  });

  group('Péremptions courtes', () {
    setUp(() {
      ExportFichier.enregistrer = (f) async => '/tmp/peremptions/${f.nom}';
    });

    Future<void> ecran(WidgetTester tester) async {
      await monter(tester, () => PeremptionsCourtesScreen(maintenant: () => maintenant));
      await pomper(tester);
    }

    testWidgets('ce mois par défaut : du=01/10 au=21/10, sans grossiste ni statut ; lignes, total et valeur du serveur', (tester) async {
      await ecran(tester);
      expect(serveur.recues(ApiPeremptionsCourtes.route).single.parametres, {'du': '2026-10-01', 'au': '2026-10-21'});
      expect(find.text(formaterMontant(63000)), findsOneWidget, reason: 'valeur du serveur (quantité × PAF)');
      expect(tester.widget<Text>(cle('chiffre_pc_total')).data, '4');
      final l0 = cle('pc_ligne_0');
      expect(find.descendant(of: l0, matching: find.text('PRODUIT COURT FICTIF A')), findsOneWidget);
      expect(find.descendant(of: l0, matching: find.text('Accepté')), findsOneWidget);
      expect(find.descendant(of: l0, matching: find.text('À traiter')), findsOneWidget);
      expect(find.descendant(of: l0, matching: find.text('Lot L-A1 · péremption 15/01/2027 · 92 jours restants à la réception')), findsOneWidget);
      expect(find.descendant(of: l0, matching: find.text('Saisi le 15/10/2026 à 09:30 par Agent Fictif')), findsOneWidget);
      expect(find.descendant(of: l0, matching: find.text(formaterMontant(25000))), findsOneWidget);
      expect(find.descendant(of: cle('pc_ligne_1'), matching: find.text('Refusé')), findsOneWidget);
      expect(find.descendant(of: cle('pc_ligne_1'), matching: find.textContaining('Motif')), findsNothing, reason: 'motif absent');
      await demonter(tester);
    });

    testWidgets('filtres : statut (puces) et grossiste (feuille) envoyés au serveur ; « Retirer » le grossiste', (tester) async {
      await ecran(tester);
      await toucher(tester, 'pc_statut_RECLAME');
      expect(serveur.recues(ApiPeremptionsCourtes.route).last.parametres, {'du': '2026-10-01', 'au': '2026-10-21', 'statut': 'RECLAME'});
      expect(cle('pc_ligne_0'), findsOneWidget);
      expect(cle('pc_ligne_1'), findsNothing);
      await toucher(tester, 'pc_statut_TOUS');
      await toucher(tester, 'bouton_filtres');
      await tester.tap(cle('pc_filtre_grossiste'));
      await pomper(tester);
      await tester.tap(find.text('GROSSISTE IMAGINAIRE').last);
      await pomper(tester);
      await tester.tap(cle('filtres_appliquer'));
      await pomper(tester);
      expect(serveur.recues(ApiPeremptionsCourtes.route).last.parametres, {'du': '2026-10-01', 'au': '2026-10-21', 'grossiste': 'GRO-TEST-2'});
      expect(tester.widget<Text>(cle('pc_grossiste_choisi')).data, 'Grossiste : GROSSISTE IMAGINAIRE');
      expect(find.text('PRODUIT COURT FICTIF B'), findsOneWidget);
      expect(find.text('PRODUIT COURT FICTIF A'), findsNothing);
      await toucher(tester, 'pc_retirer_grossiste');
      expect(serveur.recues(ApiPeremptionsCourtes.route).last.parametres, {'du': '2026-10-01', 'au': '2026-10-21'});
      await demonter(tester);
    });

    testWidgets('statut changé : UN PUT …/PC-1/statut?statut=RECLAME, ligne mise à jour, message', (tester) async {
      await ecran(tester);
      await toucher(tester, 'pc_statut_ligne_0');
      await tester.tap(cle('pc_choix_RECLAME'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await pomper(tester);
      final put = serveur.recues('/reception/peremptions-courtes/PC-1/statut');
      expect(put, hasLength(1));
      expect(put.single.methode, 'PUT');
      expect(put.single.parametres, {'statut': 'RECLAME'});
      expect(find.descendant(of: cle('pc_ligne_0'), matching: find.text('Réclamé')), findsOneWidget);
      expect(find.text('Statut enregistré : Réclamé.'), findsOneWidget);
      // Même statut choisi : rien n'est envoyé.
      await toucher(tester, 'pc_statut_ligne_0');
      await tester.tap(cle('pc_choix_RECLAME'));
      await pomper(tester);
      expect(serveur.recues('/reception/peremptions-courtes/PC-1/statut'), hasLength(1));
      await demonter(tester);
    });

    testWidgets('droit manquant (403) : statut inchangé, message, changement plus proposé (aucun autre PUT)', (tester) async {
      DonneesVague4.statutPcInterdit = true;
      await ecran(tester);
      await toucher(tester, 'pc_statut_ligne_0');
      await tester.tap(cle('pc_choix_AVOIR_RECU'));
      await pomper(tester);
      expect(serveur.recues('/reception/peremptions-courtes/PC-1/statut'), hasLength(1));
      expect(find.descendant(of: cle('pc_ligne_0'), matching: find.text('À traiter')), findsOneWidget);
      expect(find.textContaining('Droit manquant'), findsWidgets);
      expect(cle('pc_droit_refuse'), findsOneWidget);
      await tester.tap(cle('pc_statut_ligne_1'));
      await pomper(tester);
      expect(cle('pc_choix_A_TRAITER'), findsNothing, reason: 'plus proposé');
      expect(serveur.recues('/reception/peremptions-courtes/PC-2/statut'), isEmpty);
      await demonter(tester);
    });

    testWidgets('exports Excel et PDF : mêmes filtres que la liste ; serveur sans export → « Export indisponible »', (tester) async {
      await ecran(tester);
      await toucher(tester, 'pc_statut_A_TRAITER');
      await tester.tap(cle('menu_exports'));
      await pomper(tester);
      await tester.tap(cle('export_0'));
      await pomper(tester);
      expect(serveur.recues(ApiPeremptionsCourtes.routeExcel).single.parametres, {'du': '2026-10-01', 'au': '2026-10-21', 'statut': 'A_TRAITER'});
      expect(find.text('peremptions_courtes.xlsx'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await pomper(tester);
      await tester.tap(cle('menu_exports'));
      await pomper(tester);
      await tester.tap(cle('export_1'));
      await pomper(tester);
      expect(serveur.recues(ApiPeremptionsCourtes.routePdf).single.parametres['statut'], 'A_TRAITER');
      expect(find.text('peremptions_courtes.pdf'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await pomper(tester);
      serveur.quand(ApiPeremptionsCourtes.routePdf, ReponseFausse.introuvable());
      await tester.tap(cle('menu_exports'));
      await pomper(tester);
      await tester.tap(cle('export_1'));
      await pomper(tester);
      expect(find.text('Export indisponible sur ce serveur (mise à jour de Prestige nécessaire).'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('serveur ancien (404) : « Indisponible sur ce serveur », aucun export proposé ; liste vide : message', (tester) async {
      serveur.quand(ApiPeremptionsCourtes.route, ReponseFausse.introuvable());
      await ecran(tester);
      expect(find.text('Indisponible sur ce serveur'), findsOneWidget);
      expect(cle('menu_exports'), findsNothing);
      await demonter(tester);
      serveur.quand(ApiPeremptionsCourtes.route, ReponseFausse.json({'success': true, 'total': 0, 'valeur': 0, 'data': <Object>[]}));
      await ecran(tester);
      expect(find.text('Aucune péremption courte'), findsOneWidget);
      expect(cle('menu_exports'), findsNothing);
      await demonter(tester);
    });

    test('menu « Péremptions courtes » : Fournisseurs & achats, réservé à l\'administrateur et au pharmacien', () {
      final m = menusModules.singleWhere((m) => m.titre == 'Péremptions courtes');
      expect((m.famille, m.question, m.responsables), (Famille.fournisseurs, Question.fournisseurs, true));
      final f = FiltresPeremptionsCourtes.defaut(maintenant).copie(grossiste: 'G', statut: StatutPeremptionCourte.avoirRecu);
      expect(f.parametres, {'du': '2026-10-01', 'au': '2026-10-21', 'grossiste': 'G', 'statut': 'AVOIR_RECU'});
      expect(f.copie(sansStatut: true).parametres.containsKey('statut'), isFalse);
      expect(StatutPeremptionCourte.depuis('reclame'), StatutPeremptionCourte.reclame);
      expect(StatutPeremptionCourte.depuis('AUTRE'), isNull);
    });
  });
}
