// Outils des tests d'ergonomie et de cohérence d'affichage (test/ergonomie/) : tailles d'écran réelles,
// échelles de texte, contrôles d'accessibilité de flutter_test (cibles tactiles, libellés, contraste).
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/ui/taille_ecran.dart';

import 'contraste_interface.dart';

/// Appareil simulé : taille en pixels physiques et densité (pixels par dp).
class ProfilAppareil {
  final String nom;
  final Size pixels;
  final double densite;
  const ProfilAppareil(this.nom, this.pixels, this.densite);

  Size get dp => pixels / densite;
  bool get tablette => dp.shortestSide >= 600;

  @override
  String toString() => '$nom (${dp.width.round()}×${dp.height.round()} dp)';
}

/// Appareils du pharmacien et de l'officine.
const profilsAppareils = <ProfilAppareil>[
  // Petit téléphone Android (le plus contraint en largeur).
  ProfilAppareil('Téléphone 360×640 dp', Size(720, 1280), 2.0),
  // Téléphone récent courant (Pixel, Galaxy A).
  ProfilAppareil('Téléphone 411×891 dp', Size(1078.875, 2338.875), 2.625),
  // Terminal Sunmi 720×1440 px (5,99", xhdpi 320 dpi) → 360×720 dp.
  ProfilAppareil('Sunmi 720×1440 px', Size(720, 1440), 2.0),
  // Terminal Sunmi 1080×1920 px (420 dpi) → 411×731 dp.
  ProfilAppareil('Sunmi 1080×1920 px', Size(1080, 1920), 2.625),
  // Tablette 10" 1920×1200 px en paysage (hdpi 240 dpi) → 1280×800 dp.
  ProfilAppareil('Tablette 1920×1200 px', Size(1920, 1200), 1.5),
];

/// Échelles de texte testées : réglage par défaut et « grande police » d'Android.
const echellesTexte = <double>[1.0, 1.3];

/// Applique l'appareil et l'échelle de texte pour la durée du test.
void simulerAppareil(WidgetTester tester, ProfilAppareil profil, double echelle) {
  tester.view.devicePixelRatio = profil.densite;
  tester.view.physicalSize = profil.pixels;
  tester.platformDispatcher.textScaleFactorTestValue = echelle;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Contrôles d'accessibilité appliqués à chaque écran.
/// - cibles tactiles ≥ 48 × 48 dp (Android) ;
/// - toute cible tactile a un libellé (lecteur d'écran, info-bulle) ;
/// - contraste du texte (WCAG : 4,5:1, 3:1 pour les grands textes).
const guidesAccessibilite = <String, AccessibilityGuideline>{
  'cible tactile < 48 dp': androidTapTargetGuideline,
  'cible tactile sans libellé': labeledTapTargetGuideline,
  'contraste du texte insuffisant': textContrastGuideline,
};

/// Facteur de la taille de l'écran réellement appliqué à l'appareil simulé (3.7.0, docs/TAILLE_ECRAN.md) :
/// en Automatique, Compact (0,9) sur un petit écran — Sunmi 720×1440 px (360 × 720 dp), Sunmi 1080×1920 px
/// (411 × 731 dp) et téléphone 360 × 640 dp —, 1,0 ailleurs.
double facteurEcran(WidgetTester tester) => TailleEcranReglage.effective(
        TailleEcranReglage.active.value, tester.view.physicalSize / tester.view.devicePixelRatio)
    .facteur;

/// Cibles tactiles : 48 dp DE L'INTERFACE. Interface réduite (petit écran, Compact / Très compact) : 48 × facteur
/// dp réels (43,2 / 38,4 dp), réduction voulue (docs/TAILLE_ECRAN.md) ; règle Android inchangée ailleurs.
AccessibilityGuideline ciblesTactiles(double facteur) => facteur == 1.0
    ? androidTapTargetGuideline
    : MinimumTapTargetGuideline(size: Size.square(48 * facteur), link: 'https://support.google.com/accessibility/android/answer/7101858');

/// Évalue les guides d'accessibilité ; renvoie les écarts, un par élément fautif, en clair :
/// « cible tactile < 48 dp : « Retour » 40×40 dp », « cible tactile sans libellé : bouton à (206, 4) »,
/// « contraste du texte insuffisant : « Connexion » 2.34:1 (attendu 4.5:1, 16 px) #FFFFFF / #2EBF91 ».
Future<List<String>> evaluerAccessibilite(WidgetTester tester, {Set<String> guides = const {}}) async {
  final ecarts = <String>[];
  final facteur = facteurEcran(tester);
  for (final e in guidesAccessibilite.entries) {
    if (guides.isNotEmpty && !guides.contains(e.key)) continue;
    // Interface réduite (taille de l'écran) : cibles de 48 dp de l'interface, contraste mesuré à la résolution de
    // l'interface (support/contraste_interface.dart). Taille normale : règles de Flutter telles quelles.
    final guide = e.value == androidTapTargetGuideline
        ? ciblesTactiles(facteur)
        : e.value == textContrastGuideline && facteur != 1.0
            ? ContrasteInterface(facteur)
            : e.value;
    final r = await guide.evaluate(tester);
    if (r.passed) continue;
    final entrees = (r.reason ?? '').split(RegExp(r'(?=SemanticsNode#)')).where((t) => t.trim().isNotEmpty);
    for (final t in entrees) {
      ecarts.add('${e.key} : ${_decrire(t)}');
    }
  }
  return ecarts;
}

String _decrire(String entree) {
  final label = RegExp(r'label: "([^"]*)"').firstMatch(entree)?.group(1);
  final rect = RegExp(r'Rect\.fromLTRB\(([\d.-]+), ([\d.-]+), ([\d.-]+), ([\d.-]+)\)').firstMatch(entree);
  String nombre(String? v) => double.parse(v!).round().toString();
  final position = rect == null ? '' : ' à (${nombre(rect.group(1))}, ${nombre(rect.group(2))})';
  final flags = RegExp(r'flags: \[([^\]]*)\]').firstMatch(entree)?.group(1) ?? '';
  final nature = flags.contains('isTextField')
      ? 'champ'
      : flags.contains('hasToggledState')
          ? 'interrupteur'
          : flags.contains('hasCheckedState')
              ? 'case à cocher'
              : flags.contains('isButton')
                  ? 'bouton'
                  : 'élément';
  final quoi = label == null || label.isEmpty ? '$nature$position' : '« ${label.split('\n').first} »';

  final taille = RegExp(r'but found Size\((\d+(?:\.\d+)?), (\d+(?:\.\d+)?)\)').firstMatch(entree);
  if (taille != null) return '$quoi ${nombre(taille.group(1))}×${nombre(taille.group(2))} dp';

  final contraste = RegExp(r'at least (\d+(?:\.\d+)?) but found (\d+(?:\.\d+)?) for a font size of (\d+(?:\.\d+)?)').firstMatch(entree);
  if (contraste != null) {
    final couleurs = RegExp(r'red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+)')
        .allMatches(entree)
        .map((m) => '#${[1, 2, 3].map((i) => (double.parse(m.group(i)!) * 255).round().toRadixString(16).padLeft(2, '0')).join().toUpperCase()}')
        .join(' / ');
    return '$quoi ${contraste.group(2)}:1 (attendu ${contraste.group(1)}:1, ${nombre(contraste.group(3))} px) $couleurs';
  }
  return quoi;
}
