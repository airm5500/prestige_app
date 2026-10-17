// ERGONOMIE iOS (3.12.0) : la nouvelle interface rendue comme sur iPhone et iPad (plateforme iOS : défilement,
// transitions et capacités d'iOS — réglage « Taille de l'écran » masqué, aucune réduction automatique), aux tailles
// iPhone SE 375×667, iPhone 15 Pro Max 430×932, iPad 768×1024 (portrait) et iPad Pro 12,9″ 1366×1024 (paysage), texte
// ×1,0 et ×1,3 ; MÊMES écrans et MÊMES règles que les téléphones Android (affichage_nouvelle_interface_test.dart :
// débordement, exception de rendu, cible tactile < 48 dp — plus exigeant que les 44 pt d'Apple —, cible sans libellé,
// contraste insuffisant ; seuls les écarts connus des modules d'origine sont tolérés).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/application.dart';
import '../support/cas_affichage_nouvelle.dart';
import '../support/ecarts_connus.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

/// iPhone et iPad (points iOS = dp).
const profilsIos = <ProfilAppareil>[
  ProfilAppareil('iPhone SE 375×667', Size(750, 1334), 2.0),
  ProfilAppareil('iPhone 430×932', Size(1290, 2796), 3.0),
  ProfilAppareil('iPad 768×1024', Size(1536, 2048), 2.0),
  ProfilAppareil('iPad Pro 1366×1024', Size(2732, 2048), 2.0),
];

final _communsNouvelle = ecartsConnusCommuns.keys.where((k) => !k.contains('2EBF91')).toList();

bool _toleree(String ecran, String ecart) =>
    _communsNouvelle.any(ecart.contains) || (ecartsConnus[ecran] ?? const []).any(ecart.startsWith);

void main() {
  final serveur = FauxServeurPrestige();

  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
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
    final propre = !modulesOuEtats.contains(cas.nom);
    group('iOS · ${cas.nom}', () {
      for (final profil in profilsIos) {
        for (final echelle in echellesTexte) {
          testWidgets('$profil · texte ×$echelle', (tester) async {
            simulerAppareil(tester, profil, echelle);
            debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
            final ecarts = <String>[];
            try {
              final semantique = tester.ensureSemantics();
              ecarts.addAll(await releverErreurs(() => cas.ouvrir(tester, serveur)));
              ecarts.addAll(await evaluerAccessibilite(tester));
              semantique.dispose();
              ecarts.addAll(await releverErreurs(() async {
                await tester.pump(const Duration(seconds: 3));
                await tester.pumpWidget(const SizedBox());
                await tester.pump(const Duration(minutes: 2));
              }));
            } finally {
              debugDefaultTargetPlatformOverride = null;
            }
            final nouveaux = ecarts.toSet().where((e) => propre || !_toleree(cas.nom, e)).toList();
            expect(nouveaux, isEmpty, reason: 'iOS · ${cas.nom} · $profil · texte ×$echelle :\n${nouveaux.join('\n')}');
          });
        }
      }
    });
  }
}
