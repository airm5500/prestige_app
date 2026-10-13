// Cohérence du thème : les couleurs et polices viennent du thème de l'application (main.dart), pas de valeurs
// redéfinies écran par écran.
//  1. Le thème lui-même (couleurs de marque, police Lato, Material 3, français) : toute modification est voulue.
//  2. Sur chaque écran rendu : barres d'application à la couleur du thème, textes en police du thème (Lato).
//  3. Code source : les couleurs codées en dur (« Color(0x…) ») ne progressent pas ; un nouveau fichier d'écran
//     n'en contient aucune (il utilise Theme.of(context) ou les couleurs de l'application).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

const primaire = Color(0xFF0A2E3E);
const secondaire = Color(0xFF164B62);
const accent = Color(0xFF2EBF91);
const fond = Color(0xFFF5F7FA);

/// Couleurs codées en dur (« Color(0x… ») par fichier, relevées le 13/10/2026 : plafond à ne pas dépasser.
/// Quand un fichier en perd, baisser son plafond ici.
const plafondCouleursEnDur = <String, int>{
  'lib/main.dart': 6, // le thème lui-même
  'lib/presences/fiche_employe_screen.dart': 3,
  'lib/presences/pointage_view.dart': 7,
  'lib/presences/presence_jour_view.dart': 4,
  'lib/presences/presences_screen.dart': 1,
  'lib/presences/presences_widgets.dart': 11, // palette du module Présences
  'lib/presences/tableau_periode_view.dart': 2,
  'lib/screens/ca_comptant_screen.dart': 2,
  'lib/screens/evolution_achats_screen.dart': 2,
  'lib/screens/evolution_comparative_screen.dart': 2,
  'lib/screens/evolution_stock_screen.dart': 2,
  'lib/screens/evolution_ventes_screen.dart': 2,
  'lib/screens/home_screen.dart': 1,
  'lib/screens/serveur_injoignable_screen.dart': 2,
  'lib/widgets/erreurs_chargement.dart': 4,
  'lib/widgets/stock_reserve.dart': 5,
};

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
    preparerTelephone(serveur);
    ApiService.client = serveur.clientMemoire();
  });

  testWidgets('thème de l\'application : couleurs de marque, Lato, Material 3, français', (tester) async {
    late ThemeData theme;
    late Locale langue;
    await lancerApplication(tester, accueil: Builder(builder: (c) {
      theme = Theme.of(c);
      langue = Localizations.localeOf(c);
      return const SizedBox();
    }));
    await tester.pump(const Duration(seconds: 3));

    expect(theme.useMaterial3, isTrue);
    expect(langue, const Locale('fr', 'FR'));
    expect(theme.primaryColor, primaire);
    expect(theme.colorScheme.primary, primaire);
    expect(theme.colorScheme.secondary, secondaire);
    expect(theme.scaffoldBackgroundColor, fond);
    expect(theme.appBarTheme.backgroundColor, primaire);
    expect(theme.appBarTheme.titleTextStyle?.color, Colors.white);
    expect(theme.elevatedButtonTheme.style?.backgroundColor?.resolve({}), accent);
    expect(theme.elevatedButtonTheme.style?.foregroundColor?.resolve({}), Colors.white);
    expect(theme.inputDecorationTheme.filled, isTrue);
    for (final style in [
      theme.textTheme.bodyMedium,
      theme.textTheme.bodyLarge,
      theme.textTheme.titleMedium,
      theme.textTheme.labelLarge,
      theme.appBarTheme.titleTextStyle,
    ]) {
      expect(style?.fontFamily, startsWith('Lato'), reason: 'police du thème : Lato');
    }
    await tester.pumpWidget(const SizedBox());
  });

  group('écrans : barres et textes issus du thème', () {
    for (final cas in casAffichage) {
      testWidgets(cas.nom, (tester) async {
        simulerAppareil(tester, profilsAppareils[1], 1.0);
        await cas.ouvrir(tester, serveur);
        final ecarts = <String>[];

        // Barres d'application : couleur du thème (une barre recolorée écran par écran casse l'unité visuelle).
        for (final barre in find.byType(AppBar).evaluate()) {
          final materiau = find.descendant(of: find.byWidget(barre.widget), matching: find.byType(Material)).evaluate().first.widget as Material;
          if (materiau.color != primaire) ecarts.add('barre « ${_titre(barre.widget as AppBar)} » de couleur ${materiau.color}');
        }

        // Textes : police du thème (Lato ; icônes : police d'icônes Material).
        final familles = <String, String>{}; // famille → exemple de texte
        for (final e in find.byType(RichText).evaluate()) {
          final texte = (e.widget as RichText).text;
          void visiter(InlineSpan s, String? herite) {
            final famille = s.style?.fontFamily ?? herite;
            if (s is TextSpan) {
              if ((s.text ?? '').trim().isNotEmpty) familles.putIfAbsent(famille ?? '(aucune)', () => s.text!.trim());
              for (final enfant in s.children ?? const <InlineSpan>[]) {
                visiter(enfant, famille);
              }
            }
          }

          visiter(texte, null);
        }
        familles.forEach((f, exemple) {
          if (!f.startsWith('Lato') && f != 'MaterialIcons') ecarts.add('texte en police « $f » (thème : Lato), ex. « $exemple »');
        });

        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 2));
        expect(ecarts, isEmpty, reason: '${cas.nom} :\n${ecarts.join('\n')}');
      });
    }
  });

  test('couleurs codées en dur : pas de progression, aucune dans un nouveau fichier d\'écran', () {
    final fichiers = [
      File('lib/main.dart'),
      for (final dossier in ['lib/screens', 'lib/presences', 'lib/widgets'])
        ...Directory(dossier).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
    ];
    final depassements = <String>[];
    for (final f in fichiers) {
      final chemin = f.path.replaceAll('\\', '/');
      final n = RegExp(r'Color\(0x[0-9A-Fa-f]+\)').allMatches(f.readAsStringSync()).length;
      final plafond = plafondCouleursEnDur[chemin] ?? 0;
      if (n > plafond) depassements.add('$chemin : $n couleur(s) codée(s) en dur (plafond $plafond)');
    }
    expect(depassements, isEmpty,
        reason: 'Utiliser Theme.of(context).colorScheme / primaryColor plutôt qu\'une couleur codée en dur :\n${depassements.join('\n')}');
  });
}

String _titre(AppBar barre) {
  final t = barre.title;
  return t is Text ? (t.data ?? '') : '${t.runtimeType}';
}
