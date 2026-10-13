// Ergonomie de la NOUVELLE interface : chaque écran (démarrage, connexion A et B, accueil A / B / C, onglets,
// écrans de la présentation C, chaque module et ses états supplémentaires) est rendu avec le thème de la nouvelle
// interface et des polices réelles, aux MÊMES tailles que l'ancienne (téléphones 360×640 et 411×891 dp, Sunmi
// 720×1440 et 1080×1920 px, tablette 1920×1200 px) et aux échelles de texte 1,0 et 1,3.
// Échec si : débordement, exception de rendu, cible tactile < 48 dp, cible sans libellé, contraste insuffisant.
// Tolérés : seulement les écarts déjà connus de l'écran d'un MODULE d'origine (support/ecarts_connus.dart) et les
// deux libellés du sélecteur de période commun. Aucun écart toléré sur les écrans propres à la nouvelle interface,
// ni le contraste du bouton vert d'origine (la nouvelle charte utilise l'ambre, texte foncé, 8,6:1).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/application.dart';
import '../support/cas_affichage_nouvelle.dart';
import '../support/ecarts_connus.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

/// Écarts communs tolérés dans la nouvelle interface (libellés gris du sélecteur de période commun des modules).
final _communsNouvelle = ecartsConnusCommuns.keys.where((k) => !k.contains('2EBF91')).toList();

bool _toleree(String ecran, String ecart) =>
    _communsNouvelle.any(ecart.contains) || (ecartsConnus[ecran] ?? const []).any(ecart.startsWith);

void main() {
  final serveur = FauxServeurPrestige();

  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer(); // seulement pour connaître un port ; les requêtes passent « en mémoire »
  });
  tearDownAll(serveur.arreter);

  setUp(() {
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..coupe = false;
    preparerTelephone(serveur, nouvelle: true);
    ApiService.client = serveur.clientMemoire();
  });


  for (final cas in casAffichageNouvelle) {
    // Écrans de démarrage : écrans refondus, aucun écart toléré (même s'ils en avaient dans l'ancienne interface).
    final propre = !modulesOuEtats.contains(cas.nom);
    group('Nouvelle interface · ${cas.nom}', () {
      for (final profil in profilsAppareils) {
        for (final echelle in echellesTexte) {
          testWidgets('$profil · texte ×$echelle', (tester) async {
            simulerAppareil(tester, profil, echelle);
            final semantique = tester.ensureSemantics();
            final ecarts = <String>[];
            ecarts.addAll(await releverErreurs(() => cas.ouvrir(tester, serveur)));
            ecarts.addAll(await evaluerAccessibilite(tester));
            semantique.dispose();
            ecarts.addAll(await releverErreurs(() async {
              await tester.pump(const Duration(seconds: 3));
              await tester.pumpWidget(const SizedBox());
              await tester.pump(const Duration(minutes: 2));
            }));
            final nouveaux = ecarts.toSet().where((e) => propre || !_toleree(cas.nom, e)).toList();
            expect(nouveaux, isEmpty, reason: 'Nouvelle interface · ${cas.nom} · $profil · texte ×$echelle :\n${nouveaux.join('\n')}');
          });
        }
      }
    });
  }
}
