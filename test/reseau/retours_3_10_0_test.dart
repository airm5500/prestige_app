// RÉSEAU — nouveautés 3.10.0, faux serveur « en mémoire » (temps simulé) :
//  - Pointage BL par groupe : serveur lent (2, 5, 8 s) → attente visible, aucune erreur avant le délai, une seule
//    requête même si le groupe est rechoisi pendant l'attente, puis montant du groupe ; JSON partiel → message et
//    « Réessayer », jamais « aucun BL » ni un montant à 0 ; serveur coupé puis revenu → reprise ;
//  - Avis : « Actualiser » (serveur récent) pendant une coupure → message, l'avis n'est PAS modifié ; reprise ;
//  - CA Global : `/ca-all` partiel → message, pas de détail Mobile Money inventé ;
//  - icônes illustrées : affichées sans aucun réseau (embarquées, jamais téléchargées), y compris par défaut (3.10.1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart' show formaterMontant;
import 'package:prestige_app/nouvelle_interface/icones_illustrees.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_global_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague3/avis_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/cas_affichage.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';
import '../support/reseau.dart';

final serveur = FauxServeurPrestige();

const delais = [Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 8)];

void telephone(WidgetTester tester) {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = const Size(411 * 2.625, 891 * 2.625);
  addTearDown(tester.view.reset);
}

Finder cle(String k) => find.byKey(Key(k));

Future<void> pomperN(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Réponse du pointage d'un groupe (montants non nuls).
Map<String, Object?> pointageGroupe() => {
      'success': true,
      'data': [DonneesVague3.piece('BL', 'BL-G1', 'BLF-3001', 120000)],
      'total': 1,
      'totalBl': 120000,
      'totalAvoirs': 0,
      'net': 120000,
      'pointes': 0,
      'nonPointes': 1,
    };

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    brancherEnMemoire(serveur);
    preparerNouvelle(serveur, prefs: {DernierCriterePointage.cle: 'groupe:${DonneesVague3.groupe}'});
    listesCommunesVague1(serveur);
  });
  tearDown(() => ProfilAcces.utilisateur.value = null);

  for (final d in delais) {
    testWidgets('Pointage BL par groupe, serveur lent (${d.inSeconds} s) : attente, aucune erreur, une requête, montant', (tester) async {
      telephone(tester);
      serveur.route(ApiPointage.route, (_) => ReponseFausse.json(pointageGroupe()).apres(d), methode: 'GET');
      await ouvrirDepuisAccueil(tester, serveur, const PointageBlScreen());
      await pomperN(tester, 3);
      await attendreServeurLent(tester, d, 'Pointage BL (groupe)', deja: const Duration(milliseconds: 600), pendant: () async {
        // Actualiser pendant l'attente : désactivé, rien n'est renvoyé.
        await tester.tap(cle('pointage_actualiser'), warnIfMissed: false);
        await tester.pump();
      });
      expect(serveur.recues(ApiPointage.route), hasLength(1));
      expect(serveur.recues(ApiPointage.route).single.parametres['groupe'], DonneesVague3.groupe);
      expect(tester.widget<Text>(cle('pointage_montant_net')).data, formaterMontant(120000));
      await retourTelephone(tester);
      await fermerApplication(tester);
    });
  }

  testWidgets('Pointage BL par groupe : JSON partiel → message et « Réessayer », jamais « aucun BL » ; puis montant', (tester) async {
    telephone(tester);
    serveur.quand(
        ApiPointage.route, ReponseFausse.texte('{"success":true,"data":[{"type":"BL","id":"1","montantHt":12', type: 'application/json'),
        methode: 'GET');
    await ouvrirDepuisAccueil(tester, serveur, const PointageBlScreen());
    await pomperN(tester, 15);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(cle('pointage_montant'), findsNothing, reason: 'aucun montant inventé');
    expect(find.text('Aucun BL ni avoir sur la période'), findsNothing);
    serveur.quand(ApiPointage.route, ReponseFausse.json(pointageGroupe()), methode: 'GET');
    await tester.tap(find.text('Réessayer'));
    await pomperN(tester, 15);
    expect(cle('pointage_montant'), findsOneWidget);
    await fermerApplication(tester);
  });

  testWidgets('Pointage BL par groupe : serveur coupé → « Réessayer » ; revenu → montant (une requête par essai)', (tester) async {
    telephone(tester);
    serveur.quand(ApiPointage.route, ReponseFausse.json(pointageGroupe()), methode: 'GET');
    serveur.coupe = true;
    await ouvrirDepuisAccueil(tester, serveur, const PointageBlScreen());
    await pomperN(tester, 15);
    expect(cle('pointage_montant'), findsNothing);
    serveur.coupe = false;
    // Listes non chargées pendant la coupure : on les recharge, le choix repris relance la recherche.
    if (cle('pointage_listes_reessayer').evaluate().isNotEmpty) {
      await tester.tap(cle('pointage_listes_reessayer'));
      await pomperN(tester, 15);
    }
    if (cle('pointage_montant').evaluate().isEmpty && find.text('Réessayer').evaluate().isNotEmpty) {
      await tester.tap(find.text('Réessayer').first);
      await pomperN(tester, 15);
    }
    expect(cle('pointage_montant'), findsOneWidget);
    expect(serveur.recues(ApiPointage.route).where((r) => r.parametres['groupe'] != DonneesVague3.groupe), isEmpty);
    await fermerApplication(tester);
  });

  testWidgets('Avis (serveur récent) : « Actualiser » pendant une coupure → message, avis inchangé ; reprise', (tester) async {
    telephone(tester);
    ProfilAcces.utilisateur.value = AppUser.fromJson({
      ...DonneesFictives.utilisateur(),
      'role': {'code': 'PHARMACIEN', 'libelle': 'Pharmacien'}
    });
    await ouvrirDepuisAccueil(tester, serveur, const AvisDetailScreen(id: 'AVIS-TEST-2', droits: DroitsAvis(repondre: true)));
    await pomperN(tester, 15);
    final statut = etatVague3.avis.firstWhere((a) => a['id'] == 'AVIS-TEST-2')['statut'];
    serveur.coupe = true;
    await tester.tap(cle('avis_detail_actualiser'));
    await pomperN(tester, 15);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(etatVague3.avis.firstWhere((a) => a['id'] == 'AVIS-TEST-2')['statut'], statut);
    serveur.coupe = false;
    await tester.tap(find.text('Réessayer'));
    await pomperN(tester, 15);
    expect(cle('avis_detail_actualiser'), findsOneWidget);
    await fermerApplication(tester);
  });

  testWidgets('CA Global : /ca-all partiel → message, aucun détail Mobile Money ; reprise avec le détail', (tester) async {
    telephone(tester);
    donneesLot3(serveur);
    serveur.quand(
        AppConstants.caAllEndpoint,
        ReponseFausse.texte('[{"mvtDate":"20261013","totMobile":98200,"detailMobile":[{"modeId":"7","libelle":"Ora',
            type: 'application/json'),
        methode: 'GET');
    await ouvrirDepuisAccueil(tester, serveur, const CaGlobalNouveau());
    await pomperN(tester, 15);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(cle('ca_global_mobile_detail'), findsNothing);
    serveur.quand(AppConstants.caAllEndpoint, ReponseFausse.json(DonneesFictives.caParJourAvecDetail()), methode: 'GET');
    await tester.tap(find.text('Réessayer'));
    await pomperN(tester, 15);
    expect(cle('ca_global_mobile_detail'), findsOneWidget);
    await fermerApplication(tester);
  });

  for (final (nom, style) in [('P4 choisi', StyleIcones.p4), ('défaut 3.10.1, jamais choisi', null)]) {
    testWidgets('icônes illustrées ($nom) : affichées SANS réseau (serveur coupé), jamais téléchargées', (tester) async {
      telephone(tester);
      preparerNouvelle(serveur, p: Presentation.compact, style: style);
      serveur.coupe = true;
      await ecranConnecte(() => const AccueilNouveau())(tester, serveur);
      await pomperN(tester, 10);
      expect(find.byType(IconeIllustree), findsWidgets);
      // Images bien lues dans l'application (bundle), pas une icône de repli.
      final image = tester.widget<Image>(find.descendant(of: find.byType(IconeIllustree).first, matching: find.byType(Image)));
      final fournisseur = image.image;
      expect(fournisseur, isA<ResizeImage>());
      expect((fournisseur as ResizeImage).imageProvider, isA<AssetImage>());
      expect(serveur.requetes.where((r) => r.chemin.contains('icones') || r.chemin.endsWith('.png')), isEmpty);
      serveur.coupe = false;
      await fermerApplication(tester);
    });
  }
}
