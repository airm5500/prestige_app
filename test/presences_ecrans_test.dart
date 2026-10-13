// Module Présences : écrans, sur un serveur simulé qui renvoie les VRAIES réponses enregistrées.
// Aujourd'hui / Hier, sélecteur de date, compteurs, tri, recherche, actualisation, fiche employé, tableau et
// exports (téléchargement puis partage), QR rafraîchi, retirer / réactiver avec confirmation, réglage du seuil,
// erreurs (≠ liste vide), téléphone 360 px et tablette (deux colonnes), menu ajouté à l'accueil.
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/presences/export_fichier.dart';
import 'package:prestige_app/presences/fiche_employe_screen.dart';
import 'package:prestige_app/presences/pointage_view.dart';
import 'package:prestige_app/presences/presences_modeles.dart';
import 'package:prestige_app/presences/presences_reglages.dart';
import 'package:prestige_app/presences/presences_screen.dart';
import 'package:prestige_app/presences/presences_widgets.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/widgets/erreurs_chargement.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';
import 'outils/serveur_presences.dart';

late ServeurPresences serveur;
const awa = '57d09b7a-00a2-4a7d-a5b1-820c047c959c';
const yao = '21d795df-92f9-4016-a0b5-3baeed9dc8bd';

Future<void> attendre(WidgetTester tester, [int fois = 6]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void taille(WidgetTester tester, double largeur, double hauteur) {
  tester.view.physicalSize = Size(largeur, hauteur);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> ouvrir(WidgetTester tester, {int onglet = 0, Map<String, Object> prefs = const {}}) async {
  // Par défaut, un téléphone (la surface de test par défaut, 800 × 600, serait une tablette).
  if (tester.view.physicalSize == const Size(2400, 1800)) taille(tester, 400, 900);
  SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true, ...prefs});
  await monterAvecProviders(tester, ecran: PresencesScreen(onglet: onglet));
  await attendre(tester);
}

double haut(WidgetTester tester, String cle) => tester.getTopLeft(find.byKey(Key(cle))).dy;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true});
    FlutterSecureStorage.setMockInitialValues({});
    serveur = ServeurPresences();
    ApiService.client = MockClient(serveur.repondre);
    JournalApp.actif = false;
    HorlogePresences.maintenant = () => DateTime(2026, 10, 13, 8, 46);
    ReglagesPresences.seuil.value = ReglagesPresences.seuilParDefaut;
  });

  tearDown(() {
    ApiService.client = http.Client();
    HorlogePresences.maintenant = DateTime.now;
  });

  group('Présence du jour', () {
    testWidgets('aujourd\'hui par défaut : compteurs, absent en tête, retard de 22 min sous le seuil de 60 min', (tester) async {
      taille(tester, 360, 800);
      await ouvrir(tester);
      expect(serveur.appels, contains('GET /rh/presence?jour=2026-10-13'));
      expect(find.text('Présence du jour'), findsOneWidget);
      expect(find.textContaining('Mardi 13 octobre 2026'), findsOneWidget);
      expect(find.textContaining('retard au-delà de 1 h'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget); // présents / prévus
      expect(haut(tester, 'presence_$yao'), lessThan(haut(tester, 'presence_$awa')));
      expect(find.descendant(of: find.byKey(const Key('presence_$yao')), matching: find.text('Absent')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('presence_$awa')), matching: find.text('Présent')), findsOneWidget);
      expect(find.text('00:52↑'), findsOneWidget);
      // Aujourd'hui, « Arrivée sans départ » n'est pas signalée (journée en cours).
      expect(find.text('Arrivée sans départ'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('autre seuil (15 min, réglé dans les préférences) : Awa « En retard +22 min »', (tester) async {
      await ouvrir(tester, prefs: {ReglagesPresences.cleSeuil: 15});
      expect(find.text('En retard +22 min'), findsOneWidget);
      expect(find.textContaining('retard au-delà de 15 min'), findsOneWidget);
    });

    testWidgets('Hier : retard de 1 h 15 en tête, anomalies en phrases', (tester) async {
      await ouvrir(tester);
      await tester.tap(find.text('Hier'));
      await attendre(tester);
      expect(serveur.appels.last, 'GET /rh/presence?jour=2026-10-12');
      expect(find.textContaining('Lundi 12 octobre 2026'), findsOneWidget);
      expect(find.text('En retard +1 h 15'), findsOneWidget);
      expect(haut(tester, 'presence_$awa'), lessThan(haut(tester, 'presence_$yao')));
      expect(find.text('Pointage en double'), findsOneWidget);
      expect(find.text('Arrivée sans départ'), findsOneWidget);
      expect(find.text('Départ anticipé de 40 min'), findsOneWidget);
      expect(find.text('09:15↑ 15:20↓'), findsOneWidget);
      // Retour à aujourd'hui.
      await tester.tap(find.text('Aujourd\'hui'));
      await attendre(tester);
      expect(serveur.appels.last, 'GET /rh/presence?jour=2026-10-13');
    });

    testWidgets('sélecteur de date : un autre jour (vraie liste vide → message, pas une erreur)', (tester) async {
      await ouvrir(tester);
      await tester.tap(find.byKey(const Key('presences_choisir_date')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(DatePickerDialog), matching: find.text('1')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(serveur.appels.last, 'GET /rh/presence?jour=2026-10-01');
      expect(find.byKey(const Key('presences_vide')), findsOneWidget);
      expect(find.text('Chargement impossible'), findsNothing);
    });

    testWidgets('recherche par nom (bornée), actualisation par bouton et en tirant la liste', (tester) async {
      await ouvrir(tester);
      await tester.enterText(find.byKey(const Key('presences_recherche')), 'koné');
      await tester.pump();
      expect(find.byKey(const Key('presence_$awa')), findsOneWidget);
      expect(find.byKey(const Key('presence_$yao')), findsNothing);
      await tester.enterText(find.byKey(const Key('presences_recherche')), 'x' * 200);
      await tester.pump();
      final champ = tester.widget<TextField>(find.byKey(const Key('presences_recherche')));
      expect(champ.controller!.text.length, lessThanOrEqualTo(60));
      expect(find.textContaining('Aucun employé ne correspond'), findsOneWidget);
      await tester.tap(find.byTooltip('Effacer'));
      await tester.pump();

      final avant = serveur.appels.where((a) => a.startsWith('GET /rh/presence')).length;
      await tester.tap(find.byKey(const Key('presences_actualiser')));
      await attendre(tester);
      expect(serveur.appels.where((a) => a.startsWith('GET /rh/presence')).length, avant + 1);
      await tester.fling(find.byKey(const Key('presences_jour_liste')), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(serveur.appels.where((a) => a.startsWith('GET /rh/presence')).length, avant + 2);
    });

    for (final (panne, attendu) in [
      (PanneRh.reseau, 'Serveur injoignable'),
      (PanneRh.serveur500, 'code 500'),
      (PanneRh.droit, 'P_SM_RH'),
      (PanneRh.absente404, 'non disponible sur cette version du serveur'),
    ]) {
      testWidgets('erreur ${panne.name} : « Chargement impossible » + message ($attendu), jamais « Aucun employé »', (tester) async {
        serveur.panne = panne;
        await ouvrir(tester);
        expect(find.text('Chargement impossible'), findsOneWidget);
        expect(find.textContaining(attendu), findsOneWidget);
        expect(find.byKey(const Key('presences_vide')), findsNothing);
        serveur.panne = PanneRh.aucune;
        await tester.tap(find.text('Réessayer'));
        await attendre(tester);
        expect(find.text('Chargement impossible'), findsNothing);
        expect(find.byKey(const Key('presence_$awa')), findsOneWidget);
      });
    }

    testWidgets('échec en actualisant : les données restent, bandeau d\'erreur', (tester) async {
      await ouvrir(tester);
      serveur.panne = PanneRh.reseau;
      await tester.tap(find.byKey(const Key('presences_actualiser')));
      await attendre(tester);
      expect(find.byType(LoadErrorBanner), findsOneWidget);
      expect(find.byKey(const Key('presence_$awa')), findsOneWidget);
    });
  });

  group('Fiche employé', () {
    testWidgets('pointages du jour avec leur source, anomalies, synthèse sur la période', (tester) async {
      await ouvrir(tester);
      await tester.tap(find.text('Hier'));
      await attendre(tester);
      await tester.tap(find.byKey(const Key('presence_$yao')));
      await tester.pumpAndSettle();
      expect(find.byType(FicheEmployeScreen), findsOneWidget);
      expect(find.text('Matricule TEST-0043'), findsOneWidget);
      expect(find.text('08:02  Arrivée'), findsOneWidget);
      expect(find.text('Saisie manuelle · Essai app pharmacien'), findsOneWidget);
      expect(find.text('08:03  Arrivée'), findsOneWidget);
      expect(find.text('Pointeuse'), findsOneWidget);
      expect(find.text('Pointage en double'), findsOneWidget);
      expect(serveur.appels.last, 'GET /rh/tableau?du=2026-10-01&au=2026-10-12&employeId=$yao');
      await tester.scrollUntilVisible(find.byKey(const Key('fiche_synthese')), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text('1 / 2'), findsOneWidget); // jours présents / prévus
      expect(find.text('Absences non justifiées'), findsOneWidget);
    });

    testWidgets('changement de période (Mois dernier) et période sans données', (tester) async {
      serveur.reponses['/rh/tableau'] = (_) => http.Response('{"du":"2026-09-01","au":"2026-09-30","data":[],"success":true}', 200);
      await ouvrir(tester);
      await tester.tap(find.byKey(const Key('presence_$awa')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('periode_Mois dernier')), 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.byKey(const Key('periode_Mois dernier')));
      await attendre(tester);
      expect(serveur.appels.last, 'GET /rh/tableau?du=2026-09-01&au=2026-09-30&employeId=$awa');
      expect(find.byKey(const Key('fiche_synthese_vide')), findsOneWidget);
    });
  });

  group('Tableau sur une période et exports', () {
    setUp(() {
      ExportFichier.enregistrer = (f) async => '/tmp/presences/${f.nom}';
    });

    testWidgets('tableau du mois, toucher une ligne ouvre la fiche', (tester) async {
      await ouvrir(tester, onglet: 1);
      expect(serveur.appels.last, 'GET /rh/tableau?du=2026-10-01&au=2026-10-13');
      expect(find.textContaining('01/10/2026 → 13/10/2026 · 13 j · 2 employés'), findsOneWidget);
      expect(find.text('2 · 1 h 37'), findsOneWidget);
      await tester.tap(find.byKey(const Key('periode_Semaine')));
      await attendre(tester);
      expect(serveur.appels.last, 'GET /rh/tableau?du=2026-10-12&au=2026-10-13');
      await tester.tap(find.byKey(const Key('tableau_$awa')));
      await tester.pumpAndSettle();
      expect(find.byType(FicheEmployeScreen), findsOneWidget);
      expect(serveur.appels.last, 'GET /rh/tableau?du=2026-10-12&au=2026-10-13&employeId=$awa');
    });

    testWidgets('Excel : téléchargement puis Partager / Ouvrir', (tester) async {
      String? partage, ouvert;
      ExportFichier.partager = (chemin, type, sujet) async => partage = '$chemin|$type';
      ExportFichier.ouvrir = (chemin, type) async {
        ouvert = chemin;
        return null;
      };
      await ouvrir(tester, onglet: 1);
      await tester.tap(find.byKey(const Key('export_excel')));
      await tester.pumpAndSettle();
      expect(serveur.appels.last, 'GET /rh/tableau/excel?du=2026-10-01&au=2026-10-13');
      expect(find.text('tableau_presences_2026-10-01_2026-10-13.xlsx'), findsOneWidget);
      await tester.tap(find.byKey(const Key('presences_export_partager')));
      await tester.pumpAndSettle();
      expect(partage, '/tmp/presences/tableau_presences_2026-10-01_2026-10-13.xlsx|application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

      await tester.tap(find.byKey(const Key('export_pdf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('presences_export_ouvrir')));
      await tester.pumpAndSettle();
      expect(ouvert, '/tmp/presences/tableau_presences_2026-10-01_2026-10-13.pdf');

      await tester.tap(find.byKey(const Key('export_excelDetaille')));
      await tester.pumpAndSettle();
      expect(serveur.appels.last, 'GET /rh/tableau/excel?du=2026-10-01&au=2026-10-13&detail=true');
      expect(find.text('presences_detail_2026-10-01_2026-10-13.xlsx'), findsOneWidget);
    });

    testWidgets('export impossible : message, rien n\'est partagé', (tester) async {
      var partages = 0;
      ExportFichier.partager = (a, b, c) async => partages++;
      serveur.reponses['/rh/tableau/pdf'] =
          (_) => http.Response('<html>L\'édition n\'a pas pu être générée.</html>', 200, headers: {'content-type': 'text/html'});
      await ouvrir(tester, onglet: 1);
      await tester.tap(find.byKey(const Key('export_pdf')));
      await tester.pumpAndSettle();
      expect(find.textContaining('PDF : Le serveur n\'a pas pu produire le fichier'), findsOneWidget);
      expect(find.byKey(const Key('presences_export_partager')), findsNothing);
      expect(partages, 0);
    });

    testWidgets('tableau : erreur ≠ vide', (tester) async {
      serveur.panne = PanneRh.reseau;
      await ouvrir(tester, onglet: 1);
      expect(find.text('Chargement impossible'), findsOneWidget);
      serveur.panne = PanneRh.aucune;
      serveur.reponses['/rh/tableau'] = (_) => http.Response('{"du":"2026-10-01","au":"2026-10-13","data":[],"success":true}', 200);
      await tester.tap(find.text('Réessayer'));
      await attendre(tester);
      expect(find.byKey(const Key('tableau_vide')), findsOneWidget);
    });
  });

  group('Pointage : QR du moment et téléphones', () {
    testWidgets('QR affiché puis rafraîchi automatiquement à la fin du compte à rebours', (tester) async {
      taille(tester, 400, 1400);
      await ouvrir(tester, onglet: 2);
      expect(find.byType(QrCodeDessin), findsOneWidget);
      expect(find.text('WPY X5V'), findsOneWidget);
      expect(find.text('Change dans 3 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Change dans 2 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await attendre(tester);
      expect(serveur.codesServis, 2);
      expect(find.text('K7M N2Q'), findsOneWidget);
      expect(find.text('Change dans 60 s'), findsOneWidget);

      // Échec au rafraîchissement suivant : dernier code barré « périmé », nouvel essai 10 s plus tard.
      serveur.panne = PanneRh.reseau;
      serveur.routePanne = '/rh/mobile/code';
      await tester.pump(const Duration(seconds: 60));
      await attendre(tester);
      expect(find.textContaining('Code périmé'), findsOneWidget);
      serveur.panne = PanneRh.aucune;
      await tester.pump(QrPointage.attenteApresEchec);
      await attendre(tester);
      expect(find.text('ZZ3 4AB'), findsOneWidget);
      expect(find.textContaining('Code périmé'), findsNothing);
    });

    testWidgets('plein écran (tablette au comptoir) puis retour', (tester) async {
      taille(tester, 400, 1400);
      await ouvrir(tester, onglet: 2);
      await tester.tap(find.byKey(const Key('qr_plein_ecran')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byType(QrPleinEcranScreen), findsOneWidget);
      expect(find.textContaining('Scannez avec Prestige Vente'), findsOneWidget);
      await tester.tap(find.byKey(const Key('qr_quitter_plein_ecran')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.byType(QrPleinEcranScreen), findsNothing);
    });

    testWidgets('retirer : confirmation demandée ; Annuler n\'envoie rien ; Retirer → POST puis liste rechargée', (tester) async {
      taille(tester, 400, 1400);
      await ouvrir(tester, onglet: 2);
      expect(find.text('Téléphones enregistrés (2)'), findsOneWidget);
      final action = find.byKey(const Key('terminal_action_test-term-1'));
      expect(find.descendant(of: action, matching: find.text('Retirer')), findsOneWidget);

      await tester.tap(action);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Retirer ce téléphone ?'), findsOneWidget);
      expect(find.textContaining('sera déconnecté immédiatement'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(serveur.appels.where((a) => a.startsWith('POST')), isEmpty);

      await tester.tap(action);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('terminal_confirmer')));
      await attendre(tester);
      expect(serveur.appels.where((a) => a.startsWith('POST')), ['POST /rh/mobile/terminaux/test-term-1/retirer']);
      expect(find.text('Téléphone retiré : il est déconnecté.'), findsOneWidget);
      expect(find.descendant(of: action, matching: find.text('Réactiver')), findsOneWidget);
    });

    testWidgets('réactiver : confirmation puis POST reactiver', (tester) async {
      taille(tester, 400, 1400);
      await ouvrir(tester, onglet: 2);
      await tester.tap(find.byKey(const Key('terminal_action_test-term-2')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Réactiver ce téléphone ?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('terminal_confirmer')));
      await attendre(tester);
      expect(serveur.appels.last, 'GET /rh/mobile/terminaux');
      expect(serveur.appels, contains('POST /rh/mobile/terminaux/test-term-2/reactiver'));
      expect(find.text('Téléphone réactivé.'), findsOneWidget);
    });

    testWidgets('droit manquant sur la page Pointage : message clair', (tester) async {
      taille(tester, 400, 1400);
      serveur.panne = PanneRh.droit;
      await ouvrir(tester, onglet: 2);
      expect(find.textContaining('P_SM_RH'), findsWidgets);
    });
  });

  group('Réglages', () {
    testWidgets('seuil de retard : contrôle 0–480, enregistré et appliqué à la liste', (tester) async {
      await ouvrir(tester);
      await tester.tap(find.byKey(const Key('presences_reglages')));
      await tester.pumpAndSettle();
      final champ = find.byKey(const Key('reglage_seuil'));
      expect(find.descendant(of: champ, matching: find.text('60')), findsOneWidget);
      await tester.enterText(champ, '500');
      await tester.tap(find.byKey(const Key('reglage_enregistrer')));
      await tester.pumpAndSettle();
      expect(find.text('Valeur invalide (0 à 480 minutes).'), findsOneWidget);
      await tester.enterText(champ, 'abc');
      await tester.pump();
      expect(tester.widget<EditableText>(find.descendant(of: champ, matching: find.byType(EditableText))).controller.text, isNot('abc'));
      await tester.enterText(champ, '15');
      await tester.tap(find.byKey(const Key('reglage_enregistrer')));
      await tester.pumpAndSettle();
      expect(ReglagesPresences.seuil.value, 15);
      expect((await SharedPreferences.getInstance()).getInt(ReglagesPresences.cleSeuil), 15);
      expect(find.text('En retard +22 min'), findsOneWidget);
    });
  });

  group('Mise en page', () {
    testWidgets('téléphone 360 px : aucun débordement sur les trois onglets', (tester) async {
      taille(tester, 360, 740);
      await ouvrir(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('Hier'));
      await attendre(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Période'));
      await attendre(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Pointage'));
      await attendre(tester);
      expect(tester.takeException(), isNull);
      // Une seule colonne : cartes l'une sous l'autre.
      await tester.tap(find.text('Jour'));
      await attendre(tester);
      expect(tester.getTopLeft(find.byKey(const Key('presence_$awa'))).dx, tester.getTopLeft(find.byKey(const Key('presence_$yao'))).dx);
    });

    testWidgets('tablette : rail latéral, deux colonnes (jour) et QR + téléphones côte à côte', (tester) async {
      taille(tester, 1280, 800);
      await ouvrir(tester);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(haut(tester, 'presence_$awa'), haut(tester, 'presence_$yao'));
      expect(tester.getTopLeft(find.byKey(const Key('presence_$awa'))).dx,
          greaterThan(tester.getTopLeft(find.byKey(const Key('presence_$yao'))).dx));
      await tester.tap(find.text('Pointage'));
      await attendre(tester);
      expect(tester.getCenter(find.byType(QrCodeDessin)).dx, lessThan(tester.getTopLeft(find.byKey(const Key('terminaux_titre'))).dx));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Période'));
      await attendre(tester);
      expect(find.text('Sup.'), findsOneWidget); // colonnes supplémentaires sur tablette
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('accueil : menu « Présences » ajouté après les menus existants (ordre inchangé)', (tester) async {
    // Assez large pour le bandeau de licence existant (police de test plus large que Lato).
    taille(tester, 700, 1000);
    await monterAvecProviders(tester, ecran: const HomeScreen());
    await tester.pump();
    expect(find.text('Détail CA'), findsOneWidget); // première page inchangée
    for (var i = 0; i < 4; i++) {
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 2000);
      await tester.pumpAndSettle();
    }
    expect(find.text('Visualisation BL'), findsOneWidget);
    expect(find.text('Présences'), findsOneWidget);
    await tester.tap(find.text('Présences'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byType(PresencesScreen), findsOneWidget);
    await attendre(tester);
    expect(find.byKey(const Key('presence_$awa')), findsOneWidget);
  });
}
