// Ergonomie et cohérence d'affichage : chaque écran principal est rendu, avec le vrai thème de l'application et
// des polices réelles, sur les appareils du pharmacien (téléphones 360×640 dp et 411×891 dp, terminaux Sunmi
// 720×1440 px et 1080×1920 px, tablette 1920×1200 px) et aux échelles de texte 1,0 et 1,3.
// Échec si : débordement (« RenderFlex overflowed »), exception de rendu, cible tactile < 48 dp, cible tactile
// sans libellé, contraste de texte insuffisant — sauf écarts connus listés dans [ecartsConnus] (à résorber ;
// la liste ne doit que diminuer).
//
// Données : faux serveur Prestige « en mémoire » (mêmes routes que le serveur réseau, sans socket).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/ecarts_connus.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

bool _toleree(String ecran, String ecart) =>
    ecartsConnusCommuns.keys.any(ecart.contains) || (ecartsConnus[ecran] ?? const []).any(ecart.startsWith);

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
    preparerTelephone(serveur);
    ApiService.client = serveur.clientMemoire();
  });

  for (final cas in casAffichage) {
    group(cas.nom, () {
      for (final profil in profilsAppareils) {
        for (final echelle in echellesTexte) {
          testWidgets('$profil · texte ×$echelle', (tester) async {
            simulerAppareil(tester, profil, echelle);
            final semantique = tester.ensureSemantics();
            final ecarts = <String>[];
            ecarts.addAll(await releverErreurs(() => cas.ouvrir(tester, serveur)));
            ecarts.addAll(await evaluerAccessibilite(tester));
            semantique.dispose();
            // Fermeture de l'écran : une erreur ici (dispose) est aussi un défaut. AuthProvider garde son
            // démarrage au moins 2,5 s (créé à la première utilisation) : on le laisse finir avant.
            ecarts.addAll(await releverErreurs(() async {
              await tester.pump(const Duration(seconds: 3));
              await tester.pumpWidget(const SizedBox());
              await tester.pump(const Duration(minutes: 2));
            }));
            final nouveaux = ecarts.toSet().where((e) => !_toleree(cas.nom, e)).toList();
            expect(nouveaux, isEmpty, reason: '${cas.nom} · $profil · texte ×$echelle :\n${nouveaux.join('\n')}');
          });
        }
      }
    });
  }
}
