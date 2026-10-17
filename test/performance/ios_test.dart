// PERFORMANCE iOS (3.12.0), faux serveur « en mémoire », plateforme iOS (défilement d'iOS, avec rebond) :
// tableau de bord sur iPhone 430×932 et iPad 1024×1366 : ouverture, défilement complet, pire image, et MÊMES requêtes
// qu'Android (7 cartes, une requête chacune).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/donnees_lot3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final (nom, dp, dpr) in const [('iPhone 430×932', Size(430, 932), 3.0), ('iPad 1024×1366', Size(1024, 1366), 2.0)]) {
    testWidgets('tableau de bord ($nom, iOS) : ouverture, défilement complet, 7 requêtes', (tester) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(dp.width * dpr, dp.height * dpr);
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        preparerNouvelle(serveur, p: Presentation.tableauPrestige, style: null);
        brancherEnMemoire(serveur);
        donneesAccueil(serveur);
        donneesLot3(serveur);
        final rs = await compter(serveur, () async {
          final ms = await ouvrirEcran(tester, serveur, const AccueilNouveau(), pret: find.byKey(const Key('chiffre_tb_ca')));
          mesurer('Tableau de bord ($nom, iOS) — ouverture', ms, seuil: Seuils.ouvertureListeMs, unite: 'ms');
          await deuxPassages(tester, 'Tableau de bord ($nom, iOS)', minPas: 2, cle: 'defilement_tableau_bord');
        });
        final cartes = rs.where((r) => r.chemin != '/officine' && r.chemin != '/licence/find' && r.chemin != AppConstants.authEndpoint).toList();
        mesurer('Tableau de bord ($nom, iOS) — requêtes des cartes', cartes.length, seuil: 7, unite: 'requêtes', detail: detailRequetes(cartes));
        await fermerApplication(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
