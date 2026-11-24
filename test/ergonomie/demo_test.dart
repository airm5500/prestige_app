// 3.18.0 — mode démonstration : ergonomie (polices réelles) sur petits téléphones (320 et 360 dp), téléphone
// courant, Sunmi et tablette, texte normal et ×1,3 :
//  - premier écran d'une installation neuve : « Essayer la démonstration » visible et touchable SANS défiler ;
//  - écran de connexion (téléphone configuré) : le bouton est présent et atteignable ;
//  - accueil de la démonstration : bandeau « Démonstration — données fictives » et « Quitter la démonstration »
//    visibles et touchables (≥ 40 dp de haut), aucun débordement ; la sortie ramène au premier écran.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/demo/mode_demo.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/screens/serveur_injoignable_screen.dart';
import 'package:prestige_app/screens/settings_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/demo.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';

const appareilsDemo = <ProfilAppareil>[
  ProfilAppareil('Petit téléphone 320×640 dp', Size(640, 1280), 2.0),
  ...profilsAppareils,
];

void main() {
  setUpAll(chargerPolicesReelles);
  tearDown(() async {
    if (ModeDemo.estActif) await ModeDemo.quitter();
    ModeDemo.horloge = DateTime.now;
  });

  for (final profil in appareilsDemo) {
    for (final echelle in echellesTexte) {
      testWidgets('démonstration · $profil · texte ×$echelle', (tester) async {
        simulerAppareil(tester, profil, echelle);
        await preparerInstallation();
        final erreurs = await releverErreurs(() async {
          await lancerApplication(tester);
          await pomper(tester, fois: 10);
          expect(find.byType(SettingsScreen), findsOneWidget);
          final bouton = find.byKey(const Key('essayer_demonstration'));
          final taille = tester.getSize(bouton);
          expect(taille.height, greaterThanOrEqualTo(48 * facteurEcran(tester) - 0.5));
          final bas = tester.getBottomLeft(bouton).dy;
          expect(bas, lessThanOrEqualTo(profil.dp.height), reason: 'bouton visible sans défiler');
          await toucherDemo(tester);
          expect(find.byType(AccueilNouveau), findsOneWidget);
          expect(find.text(ModeDemo.libelleBandeau).hitTestable(), findsOneWidget);
          final quitter = find.byKey(const Key('quitter_demonstration'));
          expect(quitter.hitTestable(), findsOneWidget);
          expect(tester.getSize(quitter).height, greaterThanOrEqualTo(40 * facteurEcran(tester) - 0.5));
          final bandeau = tester.getSize(find.byKey(const Key('bandeau_demonstration')));
          expect(bandeau.height, lessThanOrEqualTo(echelle > 1 ? 110 : 90), reason: 'bandeau discret');
          await quitterDemo(tester);
          expect(find.byType(SettingsScreen), findsOneWidget);
        });
        expect(erreurs, isEmpty, reason: erreurs.join('\n'));
        await finDemo(tester);
      });
    }
  }

  testWidgets('serveur injoignable · 320 dp · texte ×1,3 : démonstration proposée et atteignable', (tester) async {
    simulerAppareil(tester, appareilsDemo.first, 1.3);
    await preparerInstallation(prefs: {
      AppConstants.localIpKey: '192.168.1.50',
      AppConstants.isConfiguredKey: true,
    });
    final erreurs = await releverErreurs(() async {
      // Licence lue par le client interdit : serveur injoignable → écran « serveur injoignable ».
      await lancerApplication(tester);
      await pomper(tester, fois: 40);
      expect(find.byType(ServeurInjoignableScreen), findsOneWidget);
      final bouton = find.byKey(const Key('essayer_demonstration'));
      await tester.ensureVisible(bouton);
      await pomper(tester, fois: 3);
      await toucherDemo(tester);
      expect(ModeDemo.estActif, isTrue);
      await quitterDemo(tester);
      expect(find.byType(ServeurInjoignableScreen), findsOneWidget);
    });
    expect(erreurs, isEmpty, reason: erreurs.join('\n'));
    await finDemo(tester);
  });

  group('écran de connexion', () {
    final serveur = FauxServeurPrestige();
    setUp(serveur.demarrer);
    tearDown(serveur.arreter);
    for (final profil in [appareilsDemo.first, appareilsDemo.last]) {
      testWidgets('$profil · texte ×1,3 : bouton présent et atteignable, sortie vers la connexion', (tester) async {
        simulerAppareil(tester, profil, 1.3);
        preparerTelephone(serveur, nouvelle: true);
        ApiService.client = serveur.clientMemoire();
        final erreurs = await releverErreurs(() async {
          await lancerApplication(tester);
          await pomperJusqua(tester, () => find.byType(LoginScreen).evaluate().isNotEmpty, raison: 'connexion');
          await pomper(tester, fois: 10);
          final bouton = find.byKey(const Key('essayer_demonstration'));
          await tester.ensureVisible(bouton);
          await pomper(tester, fois: 3);
          expect(tester.getSize(bouton).height, greaterThanOrEqualTo(48 * facteurEcran(tester) - 0.5));
          await toucherDemo(tester);
          await quitterDemo(tester);
          expect(find.byType(LoginScreen), findsOneWidget);
        });
        expect(erreurs, isEmpty, reason: erreurs.join('\n'));
        await finDemo(tester);
      });
    }
  });
}
