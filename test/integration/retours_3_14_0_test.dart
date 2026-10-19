// Intégration de la réponse du serveur du 19/10/2026 (décision 38 du pharmacien), contre le faux serveur Prestige
// « en mémoire » :
//  - Rappels traitement : « Racheté » marqué à la main (POST /rappels-habitude/marquer?statut=ACHETE {ids}),
//    confirmation, UN envoi, ligne mise à jour (elle quitte « À préparer ») et compteur relu ; serveur plus ancien
//    (« Statut inconnu. ») : message clair, rien de modifié ; « Actualiser la liste » (déjà là depuis la 3.8.0) ;
//  - Suivi des ajustements : page suivante demandée d'elle-même en arrivant en bas de la liste (start = déjà chargés,
//    mêmes filtres, « total » du serveur) ; après un échec, pas de relance en boucle, « Afficher plus » relance.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/modules/ajustements_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/rappels_vague3.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/donnees_lot2.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';
import 'retours_3_8_0_test.dart' show ajustementsPour, cartes, demonter, monter, params, pomper, serveur, toucher;

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
    donneesLot3(serveur);
  });

  group('Rappels traitement : « Racheté » à la main', () {
    testWidgets('confirmation, UN envoi statut=ACHETE, ligne retirée de « À préparer », compteur relu', (tester) async {
      await monter(tester, () => const RappelsScreen());
      expect(find.text('25 rappels à préparer au total'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('choisir_RAP-TEST-1')));
      expect(find.byKey(const Key('marquer_ACHETE')), findsOneWidget);
      // « Non » : rien.
      await toucher(tester, find.byKey(const Key('marquer_ACHETE')));
      expect(find.textContaining('« Racheté »'), findsWidgets);
      await toucher(tester, find.byKey(const Key('confirmer_non')));
      expect(serveur.recues(ApiRappels.routeMarquer), isEmpty);
      // « Oui » : un POST.
      await toucher(tester, find.byKey(const Key('marquer_ACHETE')));
      await toucher(tester, find.byKey(const Key('confirmer_oui')));
      final r = serveur.recues(ApiRappels.routeMarquer).single;
      expect(r.parametres, {'statut': 'ACHETE'});
      expect((r.json as Map)['ids'], ['RAP-TEST-1']);
      expect(find.text('1 rappel marqué « Racheté ».'), findsOneWidget);
      expect(etatVague3.rappels.firstWhere((x) => x['id'] == 'RAP-TEST-1')['statut'], 'ACHETE');
      expect(find.byKey(const Key('rappel_RAP-TEST-1')), findsNothing, reason: 'liste relue : plus « À préparer »');
      expect(find.text('24 rappels à préparer au total'), findsOneWidget);
      expect(requetesInterditesVague3(serveur), isEmpty, reason: 'aucun message envoyé au client');
      await demonter(tester);
    });

    testWidgets('serveur antérieur au 19/10/2026 : « Racheté » refusé → message clair, rien de modifié', (tester) async {
      await monter(tester, () => const RappelsScreen());
      etatVague3.serveurAncienRappels = true;
      await toucher(tester, find.byKey(const Key('choisir_RAP-TEST-1')));
      await toucher(tester, find.byKey(const Key('marquer_ACHETE')));
      await toucher(tester, find.byKey(const Key('confirmer_oui')));
      expect(find.text('Rappels non marqués : ${StatutRappel.messageServeurAncien}'), findsOneWidget);
      expect(etatVague3.rappels.firstWhere((x) => x['id'] == 'RAP-TEST-1')['statut'], 'A_PREPARER');
      expect(find.byKey(const Key('rappel_RAP-TEST-1')), findsOneWidget);
      // Les autres statuts marchent toujours.
      await pomper(tester, 50);
      await toucher(tester, find.byKey(const Key('marquer_PREPARE')));
      await toucher(tester, find.byKey(const Key('confirmer_oui')));
      expect(find.text('1 rappel marqué « Préparé ».'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('« Actualiser la liste » toujours présent (3.8.0)', (tester) async {
      await monter(tester, () => const RappelsScreen());
      expect(find.byKey(const Key('rappels_recalculer')), findsOneWidget);
      await demonter(tester);
    });
  });

  group('Suivi des ajustements : pages suivantes au défilement', () {
    const route = AppConstants.ajustementEndpoint;

    Future<void> enBas(WidgetTester tester) async {
      final s = find.descendant(of: find.byKey(const Key('defilement_module')), matching: find.byType(Scrollable)).first;
      final p = tester.state<ScrollableState>(s).position;
      p.jumpTo(p.maxScrollExtent);
      await pomper(tester, 8);
    }

    testWidgets('en bas de la liste : page suivante (start=100, mêmes filtres), puis la dernière ; rien de plus', (tester) async {
      serveur.route(route, (r) => ajustementsPour(r, nombre: 230), methode: 'GET');
      await monter(tester, () => const AjustementsNouveau(), hauteur: 891);
      expect(params(route), hasLength(1));
      await enBas(tester);
      expect(params(route), hasLength(2));
      expect(params(route)[1], {...params(route)[0], 'page': '2', 'start': '100'});
      expect(cartes(), greaterThan(100));
      await enBas(tester);
      expect(params(route).last, containsPair('start', '200'));
      await enBas(tester);
      expect(params(route), hasLength(3), reason: '230 chargés sur 230 : aucune requête de trop');
      expect(find.text('230 lignes affichées sur 230'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('page suivante en échec : pas de relance en boucle au défilement ; « Afficher plus » relance', (tester) async {
      serveur.route(
          route,
          (r) => r.parametres['start'] == '100' && serveur.recues(route).length == 2
              ? ReponseFausse.erreurServeur()
              : ajustementsPour(r, nombre: 130),
          methode: 'GET');
      await monter(tester, () => const AjustementsNouveau(), hauteur: 891);
      await enBas(tester);
      expect(params(route), hasLength(2));
      await pomper(tester, 50);
      await enBas(tester);
      await enBas(tester);
      expect(params(route), hasLength(2), reason: 'aucune relance automatique après un échec');
      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(params(route), hasLength(3));
      await enBas(tester);
      expect(find.text('130 lignes affichées sur 130'), findsOneWidget);
      expect(params(route), hasLength(3));
      await demonter(tester);
    });
  });
}
