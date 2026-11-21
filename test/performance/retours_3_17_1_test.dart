// 3.17.1 — plafonds de requêtes de l'accueil (tableau de bord, défaut) sur les TROIS serveurs possibles en officine
// (support/donnees_3_17_1.dart), première connexion puis connexion suivante (même appareil).
// La 3.17.0 avait relevé les plafonds (connexion + accueil 10 → 11, cartes 8 → 9) pour l'essai de /tableau-bord/tva
// à CHAQUE session sur l'ancien serveur. 3.17.1 : le 404 est retenu sur l'appareil (24 h), et un serveur qui annonce
// ses routes (tableau-bord/version) sans « tva » n'est jamais essayé → retour à 10 / 8 dès la connexion suivante.
// Première connexion sur un serveur jamais vu : 11 / 9 au plus (essai, ou lecture unique de tableau-bord/version
// après le succès de /tableau-bord/tva sur un serveur récent).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/routes_serveur.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/donnees_3_17_1.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/performance.dart';
import '../support/polices.dart';
import 'requetes_test.dart' show jusquConnexion, seConnecter, telephone;

final serveur = FauxServeurPrestige();

/// Requêtes des cartes (hors connexion, officine, licence).
List<RequeteRecue> cartes(List<RequeteRecue> rs) =>
    rs.where((r) => r.chemin != '/officine' && r.chemin != '/licence/find' && r.chemin != AppConstants.authEndpoint).toList();

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);

  void installer(ServeurOfficine v, {List<String>? routes}) {
    brancherEnMemoire(serveur);
    donneesAccueil(serveur);
    Donnees3171.installer(serveur, v, routesAnnoncees: routes);
  }

  Future<List<RequeteRecue>> connexion(WidgetTester tester) async {
    await jusquConnexion(tester);
    return compter(serveur, () => seConnecter(tester, find.byType(AccueilNouveau)));
  }

  for (final (v, routes, nom, premiere, suivante) in [
    // (serveur, routes annoncées, nom, plafond 1re connexion, plafond connexion suivante) — connexion + accueil
    (ServeurOfficine.ancien, null, 'ancien', 11, 10),
    (ServeurOfficine.initial, null, '67/68 initial', 11, 10),
    (ServeurOfficine.retour, null, '67/68 + retour', 11, 10),
    (ServeurOfficine.retour, ['ca-credit'], 'annonce ses routes sans « tva »', 11, 10),
  ]) {
    testWidgets('connexion + accueil, serveur $nom : 1re connexion ≤ $premiere, suivante ≤ $suivante requêtes', (tester) async {
      telephone(tester);
      preparerNouvelle(serveur, p: Presentation.tableauPrestige, style: null);
      installer(v, routes: routes);
      final rs1 = await connexion(tester);
      mesurer('Requêtes — connexion + accueil, serveur $nom (1re connexion)', rs1.length, seuil: premiere, unite: 'requêtes', detail: detailRequetes(rs1));
      mesurer('Requêtes des cartes, serveur $nom (1re connexion)', cartes(rs1).length, seuil: premiere - 2, unite: 'requêtes', detail: detailRequetes(cartes(rs1)));
      await fermerApplication(tester);

      // Connexion suivante, même appareil (préférences gardées), nouvelle session.
      installer(v, routes: routes);
      final rs2 = await connexion(tester);
      mesurer('Requêtes — connexion + accueil, serveur $nom (connexion suivante)', rs2.length, seuil: suivante, unite: 'requêtes', detail: detailRequetes(rs2));
      mesurer('Requêtes des cartes, serveur $nom (connexion suivante)', cartes(rs2).length, seuil: suivante - 2, unite: 'requêtes', detail: detailRequetes(cartes(rs2)));
      expect(serveur.recues(RoutesServeur.route), isEmpty, reason: 'tableau-bord/version lue une fois au plus par serveur');
      if (v == ServeurOfficine.ancien || routes != null) {
        expect(serveur.recues('/tableau-bord/tva'), isEmpty, reason: 'aucun essai inutile');
        expect(serveur.recues('/tvas'), hasLength(1));
      } else {
        expect(serveur.recues('/tableau-bord/tva'), hasLength(1));
        expect(serveur.recues('/tvas'), isEmpty);
      }
      await fermerApplication(tester);
    });
  }

  // 3.17.2 : tableau-bord/version répond { success: false, msg } (sans session au moment de la lecture) : rien n'est
  // retenu, la lecture est refaite à la connexion suivante, toujours dans le plafond de la 1re connexion (11 / 9),
  // puis 10 / 8 une fois la réponse connue.
  testWidgets('3.17.2 · version sans session à la 1re connexion : ≤ 11, puis ≤ 11 (relue une fois), puis ≤ 10 requêtes', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.tableauPrestige, style: null);
    void sansSession() {
      installer(ServeurOfficine.retour);
      serveur.quand(RoutesServeur.route, ReponseFausse.json({'success': false, 'msg': 'Session fictive terminée'}), methode: 'GET');
    }

    sansSession();
    final rs1 = await connexion(tester);
    mesurer('Requêtes — connexion + accueil, version sans session (1re connexion)', rs1.length, seuil: 11, unite: 'requêtes', detail: detailRequetes(rs1));
    mesurer('Requêtes des cartes, version sans session (1re connexion)', cartes(rs1).length, seuil: 9, unite: 'requêtes', detail: detailRequetes(cartes(rs1)));
    expect(serveur.recues(RoutesServeur.route), hasLength(1));
    await fermerApplication(tester);

    installer(ServeurOfficine.retour);
    final rs2 = await connexion(tester);
    mesurer('Requêtes — connexion + accueil, version relue (connexion suivante)', rs2.length, seuil: 11, unite: 'requêtes', detail: detailRequetes(rs2));
    mesurer('Requêtes des cartes, version relue (connexion suivante)', cartes(rs2).length, seuil: 9, unite: 'requêtes', detail: detailRequetes(cartes(rs2)));
    expect(serveur.recues(RoutesServeur.route), hasLength(1), reason: 'rien n\'était retenu : relue une fois');
    await fermerApplication(tester);

    installer(ServeurOfficine.retour);
    final rs3 = await connexion(tester);
    mesurer('Requêtes — connexion + accueil, version connue (3e connexion)', rs3.length, seuil: 10, unite: 'requêtes', detail: detailRequetes(rs3));
    mesurer('Requêtes des cartes, version connue (3e connexion)', cartes(rs3).length, seuil: 8, unite: 'requêtes', detail: detailRequetes(cartes(rs3)));
    expect(serveur.recues(RoutesServeur.route), isEmpty);
    await fermerApplication(tester);
  });

  testWidgets('serveur qui annonce ses routes sans « tva » (annonce déjà connue) : 10 / 8 dès la 1re connexion', (tester) async {
    telephone(tester);
    preparerNouvelle(serveur, p: Presentation.tableauPrestige, style: null);
    installer(ServeurOfficine.retour, routes: ['ca-credit']);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    await jusquConnexion(tester);
    // Annonce déjà lue (session précédente) pour l'adresse active.
    final racine = Provider.of<IpConfigProvider>(tester.element(find.byType(LoginScreen)), listen: false).racineServeur;
    await tester.runAsync(() => prefs!.setString(RoutesServeur.cle, jsonEncode({
          racine: {'routes': ['ca-credit']}
        })));
    final rs = await compter(serveur, () => seConnecter(tester, find.byType(AccueilNouveau)));
    mesurer('Requêtes — connexion + accueil, routes annoncées sans « tva »', rs.length, seuil: 10, unite: 'requêtes', detail: detailRequetes(rs));
    mesurer('Requêtes des cartes, routes annoncées sans « tva »', cartes(rs).length, seuil: 8, unite: 'requêtes', detail: detailRequetes(cartes(rs)));
    expect(serveur.recues('/tableau-bord/tva'), isEmpty);
    await fermerApplication(tester);
  });
}
