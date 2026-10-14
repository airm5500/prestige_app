// Retours du pharmacien sur le lot 4 (3.6.1), écrans de la nouvelle interface contre le faux serveur (client en
// mémoire, horloge simulée, écran très haut pour que toutes les lignes soient construites) :
//  - Fichier Journal : pages de 50 demandées au serveur (start / limit, mêmes filtres), « Afficher plus » → page
//    suivante ; serveur SANS pagination (pas de « total ») : ce qui est reçu est affiché 50 par 50 SANS AUCUNE autre
//    requête, avec l'avertissement « limite du serveur » ; échec de la page suivante = message, liste gardée.
//  - Récap de caisse : « Exporter » → PDF du ticket Z ; chaque ligne affichée (libellé, montant) et chaque chiffre
//    clé se retrouvent à l'identique dans le texte du PDF ; aucune requête pour l'export.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/recap_caisse_pdf.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/fichier_journal_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/recap_caisse_nouveau.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/donnees_lot4.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();
const route = AppConstants.fichierJournalEndpoint;

Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> monter(WidgetTester tester, Widget Function() ecran) async {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 30000 * 2.625);
  addTearDown(tester.view.reset);
  preparerTelephone(serveur, nouvelle: true);
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

int cartes() => find.byType(CarteLigne).evaluate().length;

List<Map<String, String>> pages() => [for (final r in serveur.recues(route)) r.parametres];

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
  });

  group('Fichier Journal : par 50 avec « Afficher plus »', () {
    testWidgets('serveur qui pagine : 50, puis 100 (start=50, mêmes filtres), puis 130 ; plus rien ensuite', (tester) async {
      serveur.route(route, (r) => DonneesLot4.journalPour(r, nombre: 130), methode: 'GET');
      await monter(tester, () => const FichierJournalNouveau());
      expect(pages(), hasLength(1));
      expect(pages().single, containsPair('start', '0'));
      expect(pages().single, containsPair('limit', '50'));
      expect(cartes(), 50);
      expect(find.text('50 lignes affichées sur 130'), findsOneWidget);
      expect(find.text('Afficher plus (80)'), findsOneWidget);
      expect(find.byKey(const Key('journal_limite')), findsNothing);

      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(pages(), hasLength(2));
      expect({...pages()[1]}..remove('start'), {...pages()[0]}..remove('start'), reason: 'mêmes filtres');
      expect(pages()[1]['start'], '50');
      expect(cartes(), 100);
      expect(find.text('Action fictive N51'), findsOneWidget, reason: 'page 2 ajoutée à la suite');

      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(pages()[2]['start'], '100');
      expect(cartes(), 130);
      expect(find.byKey(const Key('bouton_afficher_plus')), findsNothing);
      expect(pages(), hasLength(3), reason: 'aucune requête de trop');

      // Recherche locale sur les actions chargées : aucune requête.
      await tester.enterText(find.byKey(const Key('champ_recherche')), 'N12');
      await pomper(tester, 8);
      expect(cartes(), 11, reason: 'N12, N120 … N129');
      expect(pages(), hasLength(3));
      await demonter(tester);
    });

    testWidgets('serveur SANS pagination (pas de total) : 50 par 50 côté appli, AUCUNE requête de plus, avertissement',
        (tester) async {
      serveur.route(route, (r) => DonneesLot4.journalPour(r, nombre: 200, avecTotal: false), methode: 'GET');
      await monter(tester, () => const FichierJournalNouveau());
      expect(pages(), hasLength(1));
      expect(cartes(), 50);
      expect(find.byKey(const Key('journal_limite')), findsOneWidget, reason: 'avertissement gardé');
      expect(find.text('Limite du serveur atteinte'), findsOneWidget);
      expect(find.text('50 lignes affichées sur 200'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(cartes(), 100);
      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(cartes(), 200);
      expect(find.byKey(const Key('bouton_afficher_plus')), findsNothing);
      expect(pages(), hasLength(1), reason: 'pagination côté appli : aucune requête supplémentaire');
      await demonter(tester);
    });

    testWidgets('page suivante en échec : message, actions déjà chargées gardées, « Afficher plus » de nouveau possible',
        (tester) async {
      serveur.route(
          route,
          (r) => r.parametres['start'] == '50' && serveur.recues(route).length == 2
              ? ReponseFausse.erreurServeur()
              : DonneesLot4.journalPour(r, nombre: 80),
          methode: 'GET');
      await monter(tester, () => const FichierJournalNouveau());
      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(cartes(), 50, reason: 'liste gardée');
      expect(find.byType(SnackBar), findsOneWidget);
      await pomper(tester, 50);
      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(cartes(), 80);
      expect(pages().map((p) => p['start']), ['0', '50', '50']);
      await demonter(tester);
    });
  });

  group('Récap de caisse : PDF du ticket Z', () {
    testWidgets('chaque ligne et chaque chiffre de l\'écran se retrouvent tels quels dans le texte du PDF ; aucune requête',
        (tester) async {
      final sorties = <(ContenuTicketZ, String)>[];
      final avant = RecapCaissePdf.sortie;
      RecapCaissePdf.sortie = (c, nom) async => sorties.add((c, nom));
      addTearDown(() => RecapCaissePdf.sortie = avant);
      await monter(tester, () => const RecapCaisseNouveau());
      final ecran = [for (final e in find.byType(LigneDetail).evaluate()) '${(e.widget as LigneDetail).libelle} : ${(e.widget as LigneDetail).valeur}'];
      final chiffres = [
        for (final e in find.byType(ChiffreCle).evaluate()) ((e.widget as ChiffreCle).libelle, (e.widget as ChiffreCle).valeur),
      ];
      expect(ecran, hasLength(4 + 2 * 4), reason: '4 totaux globaux, 2 caissiers × (2 modes + 2 totaux)');
      final requetes = serveur.requetes.length;

      await toucher(tester, find.byKey(const Key('menu_exports')));
      await toucher(tester, find.text('PDF du ticket Z'));
      expect(serveur.requetes, hasLength(requetes), reason: 'aucune requête pour l\'export');
      final contenu = sorties.single.$1;
      expect(contenu.officine, isNotEmpty, reason: 'nom de l\'officine : vérifié de bout en bout (e2e)');
      expect(contenu.chiffres, chiffres, reason: 'chiffres en tête identiques');
      final texte = contenu.lignes;
      for (final l in ecran) {
        expect(texte, contains(l), reason: 'ligne de l\'écran dans le PDF : $l');
      }
      // Même ordre que l'écran : totaux globaux puis caissiers (modes puis totaux).
      expect([for (final l in texte) if (ecran.contains(l)) l], ecran);
      await demonter(tester);
    });

    testWidgets('rien à exporter pendant le chargement ou sans donnée : message, aucun PDF', (tester) async {
      final sorties = <ContenuTicketZ>[];
      final avant = RecapCaissePdf.sortie;
      RecapCaissePdf.sortie = (c, _) async => sorties.add(c);
      addTearDown(() => RecapCaissePdf.sortie = avant);
      serveur.quand('/caisse/fetch-tickez', ReponseFausse.json({'success': true}), methode: 'POST');
      await monter(tester, () => const RecapCaisseNouveau());
      await toucher(tester, find.byKey(const Key('menu_exports')));
      await toucher(tester, find.text('PDF du ticket Z'));
      expect(sorties, isEmpty);
      expect(find.text('Aucune donnée à exporter'), findsOneWidget);
      await demonter(tester);
    });
  });
}
