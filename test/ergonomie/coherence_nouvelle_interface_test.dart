// Cohérence de la NOUVELLE interface (charte de prestige_vente_app : bleu nuit #003366, ambre #F59E0B) :
//  1. le thème (couleurs, contraste des boutons principaux ≥ 4,5:1, Lato, Material 3, français, aucune teinte de
//     surface « lavande » de Material 3) ;
//  2. sur CHAQUE écran de la nouvelle interface (démarrage, connexion, accueil A / B / C, onglets, chaque module) :
//     barres d'application bleu nuit, textes en Lato, et AUCUNE zone à l'ancien style : ni couleur de l'ancienne
//     charte (#0A2E3E, #164B62, vert #2EBF91, fond #F5F7FA), ni teinte lavande / violette de Material par défaut ;
//  3. dialogues et sélecteurs (code administrateur, date) aux couleurs de la charte.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/screens/ca_global_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/cas_affichage_nouvelle.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

/// Couleurs de l'ancienne charte : interdites dans la nouvelle interface.
const ancienneCharte = <int, String>{
  0xFF0A2E3E: 'bleu d\'origine #0A2E3E',
  0xFF164B62: 'bleu secondaire d\'origine #164B62',
  0xFF2EBF91: 'vert d\'accent d\'origine #2EBF91',
  0xFFF5F7FA: 'fond d\'origine #F5F7FA',
};

double contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// Teinte lavande / violette (surfaces par défaut de Material 3, ColorScheme par défaut #6750A4…).
bool estLavande(Color c) {
  if (c.a < 0.05) return false;
  final hsl = HSLColor.fromColor(c.withValues(alpha: 1));
  return hsl.hue >= 250 && hsl.hue <= 330 && hsl.saturation >= 0.2 && hsl.lightness > 0.08 && hsl.lightness < 0.985;
}

String hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Couleurs effectivement utilisées par les widgets affichés (fonds, décors, textes, icônes).
Map<Color, String> couleursAffichees(WidgetTester tester) {
  final vues = <Color, String>{};
  void noter(Color? c, String ou) {
    if (c != null) vues.putIfAbsent(c, () => ou);
  }

  for (final e in find.byType(Material).evaluate()) {
    noter((e.widget as Material).color, 'Material');
    noter((e.widget as Material).surfaceTintColor, 'teinte de surface');
  }
  for (final e in find.byType(Container).evaluate()) {
    final c = e.widget as Container;
    noter(c.color, 'Container');
    final d = c.decoration;
    if (d is BoxDecoration) noter(d.color, 'Container (décor)');
  }
  for (final e in find.byType(DecoratedBox).evaluate()) {
    final d = (e.widget as DecoratedBox).decoration;
    if (d is BoxDecoration) {
      noter(d.color, 'DecoratedBox');
      final b = d.border;
      if (b is Border) noter(b.top.color, 'bordure');
    }
  }
  for (final e in find.byType(RichText).evaluate()) {
    void visiter(InlineSpan s) {
      noter(s.style?.color, 'texte « ${s.toPlainText().trim()} »');
      if (s is TextSpan) s.children?.forEach(visiter);
    }

    visiter((e.widget as RichText).text);
  }
  for (final e in find.byType(Icon).evaluate()) {
    noter((e.widget as Icon).color, 'icône');
  }
  for (final e in find.byType(IconTheme).evaluate()) {
    noter((e.widget as IconTheme).data.color, 'icône (thème)');
  }
  return vues;
}

List<String> ecartsAncienStyle(WidgetTester tester) => [
      for (final e in couleursAffichees(tester).entries)
        if (ancienneCharte.containsKey(e.key.toARGB32()))
          '${e.value} : ${ancienneCharte[e.key.toARGB32()]}'
        else if (estLavande(e.key))
          '${e.value} : teinte lavande ${hex(e.key)}',
    ];

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

  Future<void> fermer(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  testWidgets('thème de la nouvelle interface : charte bleu nuit / ambre, contrastes, Lato, Material 3, français', (tester) async {
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
    expect(theme.colorScheme.primary, const Color(0xFF003366));
    expect(theme.colorScheme.secondary, const Color(0xFFF59E0B));
    expect(theme.primaryColor, Charte.navy);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF2F4F8));
    expect(theme.appBarTheme.backgroundColor, Charte.navy);
    expect(theme.appBarTheme.shape, isA<RoundedRectangleBorder>(), reason: 'en-têtes arrondis (NavyHeader)');
    expect(theme.appBarTheme.titleTextStyle?.color, Colors.white);

    // Boutons principaux : contraste ≥ 4,5:1 (le blanc sur le vert d'origine ne fait que 2,3:1).
    final eleve = theme.elevatedButtonTheme.style!;
    final fondPrincipal = eleve.backgroundColor!.resolve({})!, textePrincipal = eleve.foregroundColor!.resolve({})!;
    expect(fondPrincipal, Charte.ambre);
    expect(contraste(fondPrincipal, textePrincipal), greaterThanOrEqualTo(4.5));
    expect(contraste(const Color(0xFFFFFFFF), const Color(0xFF2EBF91)), lessThan(4.5), reason: 'référence : ancien bouton');
    final plein = theme.filledButtonTheme.style!;
    expect(contraste(plein.backgroundColor!.resolve({})!, plein.foregroundColor!.resolve({})!), greaterThanOrEqualTo(4.5));
    expect(contraste(Charte.blanc, theme.textButtonTheme.style!.foregroundColor!.resolve({})!), greaterThanOrEqualTo(4.5));
    expect(contraste(Charte.blanc, Charte.gris), greaterThanOrEqualTo(4.5));
    expect(contraste(Charte.page, Charte.gris), greaterThanOrEqualTo(4.5));
    expect(contraste(Charte.navy, Charte.enteteGris), greaterThanOrEqualTo(4.5));

    // Aucune couleur du schéma n'est lavande ; aucune teinte de surface (sinon les dialogues virent au mauve).
    final s = theme.colorScheme;
    for (final c in [s.primary, s.secondary, s.tertiary, s.surface, s.surfaceContainerLowest, s.surfaceContainerLow, s.surfaceContainer,
      s.surfaceContainerHigh, s.surfaceContainerHighest, s.primaryContainer, s.secondaryContainer, s.tertiaryContainer, s.inverseSurface]) {
      expect(estLavande(c), isFalse, reason: 'couleur ${hex(c)} du schéma');
    }
    expect(s.surfaceTint, Colors.transparent);
    expect(theme.dialogTheme.backgroundColor, Charte.blanc);
    expect(theme.bottomSheetTheme.backgroundColor, Charte.blanc);
    expect(theme.navigationBarTheme.backgroundColor, Charte.blanc);
    expect(theme.datePickerTheme.headerBackgroundColor, Charte.navy);
    for (final style in [theme.textTheme.bodyMedium, theme.textTheme.bodyLarge, theme.textTheme.titleMedium, theme.textTheme.labelLarge, theme.appBarTheme.titleTextStyle]) {
      expect(style?.fontFamily, startsWith('Lato'), reason: 'police du thème : Lato');
    }
    await tester.pumpWidget(const SizedBox());
  });

  group('nouvelle interface : barres, polices et aucune zone à l\'ancien style', () {
    for (final cas in casAffichageNouvelle) {
      testWidgets(cas.nom, (tester) async {
        simulerAppareil(tester, profilsAppareils[1], 1.0);
        await cas.ouvrir(tester, serveur);
        final ecarts = <String>[];
        for (final barre in find.byType(AppBar).evaluate()) {
          final materiau = find.descendant(of: find.byWidget(barre.widget), matching: find.byType(Material)).evaluate().first.widget as Material;
          if (materiau.color != Charte.navy) ecarts.add('barre de couleur ${materiau.color} (attendu bleu nuit #003366)');
        }
        final familles = <String, String>{};
        for (final e in find.byType(RichText).evaluate()) {
          void visiter(InlineSpan s, String? herite) {
            final famille = s.style?.fontFamily ?? herite;
            if (s is TextSpan) {
              if ((s.text ?? '').trim().isNotEmpty) familles.putIfAbsent(famille ?? '(aucune)', () => s.text!.trim());
              for (final enfant in s.children ?? const <InlineSpan>[]) {
                visiter(enfant, famille);
              }
            }
          }

          visiter((e.widget as RichText).text, null);
        }
        familles.forEach((f, exemple) {
          if (!f.startsWith('Lato') && f != 'MaterialIcons') ecarts.add('texte en police « $f » (thème : Lato), ex. « $exemple »');
        });
        ecarts.addAll(ecartsAncienStyle(tester));
        await fermer(tester);
        expect(ecarts.toSet(), isEmpty, reason: '${cas.nom} :\n${ecarts.toSet().join('\n')}');
      });
    }
  });

  testWidgets('dialogue du code administrateur (depuis la connexion) aux couleurs de la charte', (tester) async {
    simulerAppareil(tester, profilsAppareils[1], 1.0);
    await parcoursDemarrage(LoginScreen)(tester, serveur);
    await tester.tap(find.byTooltip('Configuration IP'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(AlertDialog), findsOneWidget);
    final ecarts = ecartsAncienStyle(tester);
    final fond = tester.widget<Material>(find.descendant(of: find.byType(AlertDialog), matching: find.byType(Material)).first);
    expect(fond.color, Charte.blanc);
    expect(fond.surfaceTintColor, anyOf(isNull, Colors.transparent));
    await tester.tap(find.text('Annuler'));
    await fermer(tester);
    expect(ecarts, isEmpty, reason: ecarts.join('\n'));
  });

  testWidgets('sélecteur de date d\'un module aux couleurs de la charte (en-tête bleu nuit, pas de lavande)', (tester) async {
    simulerAppareil(tester, profilsAppareils[1], 1.0);
    await ecranConnecte(() => const CaGlobalScreen())(tester, serveur);
    await tester.tap(find.byType(TextButton).first);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(DatePickerDialog), findsOneWidget);
    final ecarts = ecartsAncienStyle(tester);
    await tester.tap(find.text('Annuler'));
    await fermer(tester);
    expect(ecarts, isEmpty, reason: ecarts.join('\n'));
  });

  testWidgets('le contrôle « ancien style » repère bien l\'interface d\'origine (témoin)', (tester) async {
    simulerAppareil(tester, profilsAppareils[1], 1.0);
    preparerTelephone(serveur); // interface d'origine
    await parcoursDemarrage(LoginScreen)(tester, serveur);
    final ecarts = ecartsAncienStyle(tester);
    await fermer(tester);
    expect(ecarts.join('\n'), contains('#0A2E3E'));
    expect(estLavande(const Color(0xFF6750A4)), isTrue, reason: 'violet par défaut de Material 3');
    expect(estLavande(const Color(0xFFE8DEF8)), isTrue, reason: 'lavande des surfaces par défaut');
    expect(estLavande(Charte.navy), isFalse);
  });
}
