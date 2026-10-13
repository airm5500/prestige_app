// Captures PNG RÉELLES des écrans « Présences » (rendu de l'application, pas des maquettes), pour la note de version.
// Lancées seulement à la demande (sinon sautées, pour ne pas dépendre des polices de la machine) :
//   CAPTURES_PRESENCES=1 flutter test test/presences_captures_test.dart --update-goldens
// Fichiers produits : docs/maquettes/apercus/app_presences_*.png. Police Roboto du SDK Flutter (Lato, la police de
// l'application, est téléchargée à l'exécution). Données : réponses réelles du serveur de test, complétées pour la
// capture « jour » par quelques employés fictifs.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prestige_app/presences/fiche_employe_screen.dart';
import 'package:prestige_app/presences/presences_modeles.dart';
import 'package:prestige_app/presences/presences_reglages.dart';
import 'package:prestige_app/presences/presences_screen.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';
import 'outils/serveur_presences.dart';

final _actif = Platform.environment['CAPTURES_PRESENCES'] == '1';

Future<void> _chargerPolices() async {
  final racine = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path; // …/bin/cache/artifacts/engine/linux-x64
  final dossier = '$racine/bin/cache/artifacts/material_fonts';
  ByteData lire(String f) => ByteData.view(File('$dossier/$f').readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(Future.value(lire(f)));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(Future.value(lire('MaterialIcons-Regular.otf')))).load();
  // Flèches ↑ ↓ des pointages (absentes de Roboto ; sur le téléphone, la police système les fournit).
  const dejaVu = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';
  if (File(dejaVu).existsSync()) {
    await (FontLoader('DejaVuSans')..addFont(Future.value(ByteData.view(File(dejaVu).readAsBytesSync().buffer)))).load();
  }
}

/// Thème proche de celui de l'application (main.dart), police Roboto.
final _theme = ThemeData(
  fontFamily: 'Roboto',
  fontFamilyFallback: const ['DejaVuSans'],
  primaryColor: const Color(0xFF0A2E3E),
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A2E3E), primary: const Color(0xFF0A2E3E), secondary: const Color(0xFF164B62)),
  scaffoldBackgroundColor: const Color(0xFFF5F7FA),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF0A2E3E),
    titleTextStyle: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    iconTheme: IconThemeData(color: Colors.white),
    actionsIconTheme: IconThemeData(color: Colors.white),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    filled: true,
    fillColor: Colors.white,
  ),
  useMaterial3: true,
);

String _ligne(String id, String nom, String mat, String prevu, String entree, String sortie, int retard, String anomalies, String pointages,
        {int presence = 0, int depart = 0, String absence = ''}) =>
    '{"employeId":"$id","employe":"$nom","matricule":"$mat","jour":"2026-10-13","prevu":"$prevu","entree":"$entree","sortie":"$sortie",'
    '"minutesPrevues":480,"minutesPresence":$presence,"retard":$retard,"departAnticipe":$depart,"heuresSup":0,"absence":"$absence",'
    '"anomalies":"$anomalies","pointages":"$pointages"}';

void main() {
  late ServeurPresences serveur;

  setUpAll(() async {
    if (_actif) await _chargerPolices();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true});
    FlutterSecureStorage.setMockInitialValues({});
    serveur = ServeurPresences();
    ApiService.client = MockClient(serveur.repondre);
    JournalApp.actif = false;
    HorlogePresences.maintenant = () => DateTime(2026, 10, 13, 8, 46);
    ReglagesPresences.seuil.value = 60;
  });

  tearDown(() {
    ApiService.client = http.Client();
    HorlogePresences.maintenant = DateTime.now;
  });

  Future<void> capture(WidgetTester tester, Widget ecran, String nom, Size taille, {Future<void> Function()? actions, double dpr = 2}) async {
    tester.view.physicalSize = taille * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await monterAvecProviders(tester, ecran: Theme(key: UniqueKey(), data: _theme, child: ecran), sansBandeauDebug: true);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (actions != null) await actions();
    await expectLater(find.byType(Theme).first, matchesGoldenFile('../docs/maquettes/apercus/app_presences_$nom.png'));
  }

  const telephone = Size(400, 860);
  const tablette = Size(1280, 800);

  testWidgets('captures', (tester) async {
    // Ombres réelles (le banc de test les remplace sinon par des traits noirs) ; rétabli en fin de test.
    debugDisableShadows = false;
    // Aujourd'hui : réponse réelle + employés fictifs pour illustrer les statuts.
    serveur.reponses['/rh/presence'] = (req) {
      if (req.url.queryParameters['jour'] != '2026-10-13') return http.Response.bytes(fixtureOctets('presence_hier.json'), 200, headers: ServeurPresences.json);
      final lignes = [
        _ligne('d1', 'TRAORE Mariam', 'D-01', '07:30-15:30', '', '', 0, 'ABSENT', ''),
        _ligne('d2', 'KOUASSI Jean', 'D-02', '07:00-15:00', '08:14', '', 74, 'ENTREE_SANS_SORTIE', '08:14↑'),
        _ligne('d3', 'DIALLO Seydou', 'D-03', '07:30-15:30', '07:24', '', 0, 'ENTREE_SANS_SORTIE', '07:24↑'),
        _ligne('d4', 'COULIBALY Fatou', 'D-04', '08:00-16:00', '', '', 0, '', '', absence: 'CONGE'),
        _ligne('d5', 'BAMBA Ali', 'D-05', '07:00-15:00', '07:02', '', 0, 'DOUBLON,ENTREE_SANS_SORTIE', '07:02↑'),
      ].join(',');
      final reel = fixture('presence_aujourdhui.json');
      final corps = reel.replaceFirst('"data":[', '"data":[$lignes,');
      return http.Response.bytes(utf8.encode(corps), 200, headers: ServeurPresences.json);
    };
    await capture(tester, const PresencesScreen(), 'jour_telephone', telephone);
    await capture(tester, const PresencesScreen(), 'hier_telephone', telephone, actions: () async {
      await tester.tap(find.text('Hier'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    });
    await capture(tester, const PresencesScreen(onglet: 1), 'periode_telephone', telephone);
    await capture(
      tester,
      FicheEmployeScreen(
        employeId: '21d795df-92f9-4016-a0b5-3baeed9dc8bd',
        employe: 'BROU Yao Test',
        matricule: 'TEST-0043',
        jour: DateTime(2026, 10, 12),
        ligne: const PresenceJour(
          employeId: '21d795df-92f9-4016-a0b5-3baeed9dc8bd',
          jour: '2026-10-12',
          prevu: '08:00-16:00',
          entree: '08:02',
          minutesPrevues: 420,
          anomalies: ['DOUBLON', 'ENTREE_SANS_SORTIE'],
          pointages: '08:02↑',
        ),
        pointages: const [
          PointageJour(id: 'a', employeId: 'y', horodatage: '2026-10-12 08:02', sens: 'ENTREE', source: 'MANUEL', motif: 'Essai app pharmacien'),
          PointageJour(id: 'b', employeId: 'y', horodatage: '2026-10-12 08:03', sens: 'ENTREE', source: 'POINTEUSE'),
        ],
      ),
      'fiche_telephone',
      telephone,
    );
    await capture(tester, const PresencesScreen(), 'jour_tablette', tablette, dpr: 1.5);
    await capture(tester, const PresencesScreen(onglet: 2), 'pointage_tablette', tablette, dpr: 1.5);
    debugDisableShadows = true;
  }, skip: !_actif);
}
