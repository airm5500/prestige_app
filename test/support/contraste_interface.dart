// Contraste du texte dans l'interface RÉDUITE (taille de l'écran Compact / Très compact, ou Compact appliqué d'office
// en Automatique sur un petit écran : docs/TAILLE_ECRAN.md).
//
// La règle de Flutter (textContrastGuideline) photographie l'écran à UN échantillon par dp réel puis prend la
// couleur foncée la plus fréquente sous chaque texte. Quand l'interface est réduite (×0,9 / ×0,8), un texte de 13 dp
// n'occupe plus que 11,7 / 10,4 échantillons de haut : l'anticrénelage éclaircit presque tous ses pixels et la règle
// mesure alors la couleur d'un BORD de lettre (ex. 1,15:1 pour un gris #5F6368 sur blanc), pas celle du texte. Sur
// l'appareil, rien de tel : le Sunmi V2s a 2 pixels par dp (densité 2), soit 21 pixels pour ce même texte.
//
// [ContrasteInterface] applique EXACTEMENT le même calcul (mêmes seuils WCAG 4,5:1 et 3:1, même couleur claire et
// foncée la plus fréquente, mêmes textes contrôlés, mêmes messages), mais sur une photo prise à un échantillon par dp
// DE L'INTERFACE (pixelRatio divisé par le facteur) : le contraste mesuré est celui des couleurs choisies, comme à la
// taille normale. Facteur 1,0 : la règle de Flutter telle quelle.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class ContrasteInterface extends MinimumTextContrastGuideline {
  /// Facteur de réduction de l'interface (0,9 ou 0,8).
  final double facteur;
  const ContrasteInterface(this.facteur);

  static const double _tolerance = -0.01;

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    var result = const Evaluation.pass();
    for (final renderView in tester.binding.renderViews) {
      final layer = renderView.debugLayer! as OffsetLayer;
      final root = renderView.owner!.semanticsOwner!.rootSemanticsNode!;
      var largeur = 0, hauteur = 0;
      final octets = await tester.binding.runAsync<ByteData?>(() async {
        // Un échantillon par dp de l'interface (au lieu d'un par dp réel).
        final ratio = 1 / (renderView.flutterView.devicePixelRatio * facteur);
        final image = await layer.toImage(renderView.paintBounds, pixelRatio: ratio);
        largeur = image.width;
        hauteur = image.height;
        final data = await image.toByteData();
        image.dispose();
        return data;
      });
      result += _noeud(root, tester, octets!, largeur, hauteur, renderView);
    }
    return result;
  }

  Evaluation _noeud(SemanticsNode node, WidgetTester tester, ByteData octets, int largeur, int hauteur, RenderView renderView) {
    var result = const Evaluation.pass();
    final inactif = node.hasFlag(ui.SemanticsFlag.hasEnabledState) && !node.hasFlag(ui.SemanticsFlag.isEnabled);
    if (node.isInvisible || node.isMergedIntoParent || node.hasFlag(ui.SemanticsFlag.isHidden) || inactif) return result;
    final data = node.getSemanticsData();
    final enfants = <SemanticsNode>[];
    node.visitChildren((c) {
      enfants.add(c);
      return true;
    });
    for (final c in enfants) {
      result += _noeud(c, tester, octets, largeur, hauteur, renderView);
    }
    if (shouldSkipNode(data)) return result;
    final texte = data.label.isEmpty ? data.value : data.label;
    for (final element in find.text(texte).hitTestable().evaluate()) {
      result += _element(node, element, octets, largeur, hauteur, renderView);
    }
    return result;
  }

  Evaluation _element(SemanticsNode node, Element element, ByteData octets, int largeur, int hauteur, RenderView renderView) {
    final renderBox = element.renderObject;
    if (renderBox is! RenderBox) throw StateError('Unexpected renderObject type: $renderBox');

    final globalTransform = renderBox.getTransformTo(null);
    final bornes = MatrixUtils.transformRect(globalTransform, renderBox.paintBounds.inflate(4.0));
    // dp réels → échantillons de la photo (un par dp de l'interface).
    final dansImage = Rect.fromLTRB(bornes.left / facteur, bornes.top / facteur, bornes.right / facteur, bornes.bottom / facteur);

    final rootTransform = Matrix4.identity();
    renderView.applyPaintTransform(renderView.child!, rootTransform);
    rootTransform.multiply(globalTransform);
    final screenBounds = MatrixUtils.transformRect(rootTransform, renderBox.paintBounds);
    var nodeBounds = node.rect;
    SemanticsNode? current = node;
    while (current != null) {
      final transform = current.transform;
      if (transform != null) nodeBounds = MatrixUtils.transformRect(transform, nodeBounds);
      current = current.parent;
    }
    final intersection = nodeBounds.intersect(screenBounds);
    if (intersection.width <= 0 || intersection.height <= 0) return const Evaluation.pass();

    final widget = element.widget;
    final defaut = DefaultTextStyle.of(element);
    late final bool gras;
    late final double? taille;
    if (widget is Text) {
      final style = widget.style;
      final effectif = style == null || style.inherit ? defaut.style.merge(widget.style) : style;
      gras = effectif.fontWeight == FontWeight.bold;
      taille = effectif.fontSize;
    } else if (widget is EditableText) {
      gras = widget.style.fontWeight == FontWeight.bold;
      taille = widget.style.fontSize;
    } else {
      throw StateError('Unexpected widget type: ${widget.runtimeType}');
    }

    if (dansImage.top < -50 || dansImage.left < -50 || dansImage.bottom > hauteur + 50 || dansImage.right > largeur + 50) {
      return const Evaluation.pass();
    }
    // Texte coupé par le bord de l'écran (liste arrêtée au milieu d'une ligne) : la photo n'en montre qu'une partie,
    // la couleur mesurée serait celle d'un morceau de lettre. Il est mesuré quand il est entièrement à l'écran (autres
    // tailles, autres cas d'affichage).
    final texteSeul = MatrixUtils.transformRect(globalTransform, renderBox.paintBounds);
    final ecran = Rect.fromLTWH(0, 0, largeur * facteur, hauteur * facteur);
    if (texteSeul.top < ecran.top - 0.5 || texteSeul.bottom > ecran.bottom + 0.5) return const Evaluation.pass();
    // Même chose au bord de sa LISTE (3.11.0) : un titre arrêté à moitié sous la barre du bas est coupé par la liste
    // qui défile ; la photo prendrait la couleur de la barre pour celle du fond du texte.
    for (RenderObject? o = renderBox.parent; o != null; o = o.parent) {
      if (o is RenderViewportBase) {
        final liste = MatrixUtils.transformRect(o.getTransformTo(null), Offset.zero & o.size);
        if (texteSeul.top < liste.top - 0.5 || texteSeul.bottom > liste.bottom + 0.5) return const Evaluation.pass();
        break;
      }
    }
    final histogramme = _couleurs(octets, dansImage, largeur, hauteur);
    if (histogramme.isEmpty) return const Evaluation.pass();
    final (clair, fonce) = _clairEtFonce(histogramme);
    final ratio = (clair.computeLuminance() + 0.05) / (fonce.computeLuminance() + 0.05);
    final cible = targetContrastRatio(taille, bold: gras);
    if (ratio - cible >= _tolerance) return const Evaluation.pass();
    // Même message que la règle de Flutter (lu par support/ergonomie.dart).
    return Evaluation.fail(
      '$node:\n'
      'Expected contrast ratio of at least $cible '
      'but found ${ratio.toStringAsFixed(2)} '
      'for a font size of $taille.\n'
      'The computed colors was:\n'
      'light - $clair, dark - $fonce\n'
      'See also: '
      'https://www.w3.org/TR/UNDERSTANDING-WCAG20/visual-audio-contrast-contrast.html',
    );
  }

  /// Couleur claire et couleur foncée les plus fréquentes (partage par la luminosité moyenne), comme Flutter.
  static (Color, Color) _clairEtFonce(Map<Color, int> histogramme) {
    var total = 0.0;
    var nombre = 0;
    for (final e in histogramme.entries) {
      total += HSLColor.fromColor(e.key).lightness * e.value;
      nombre += e.value;
    }
    final moyenne = total / nombre;
    MapEntry<Color, int>? clair, fonce;
    for (final e in histogramme.entries) {
      if (HSLColor.fromColor(e.key).lightness <= moyenne) {
        if (e.value > (fonce?.value ?? 0)) fonce = e;
      } else if (e.value > (clair?.value ?? 0)) {
        clair = e;
      }
    }
    return (clair?.key ?? fonce!.key, fonce?.key ?? clair!.key);
  }

  static Map<Color, int> _couleurs(ByteData data, Rect bornes, int largeur, int hauteur) {
    final r = bornes.intersect(Rect.fromLTWH(0, 0, largeur.toDouble(), hauteur.toDouble()));
    final compte = <int, int>{};
    for (var x = r.left.floor(); x < r.right.ceil(); x++) {
      for (var y = r.top.floor(); y < r.bottom.ceil(); y++) {
        compte.update(data.getUint32((y * largeur + x) * 4), (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return compte.map((rgba, n) => MapEntry(Color((rgba << 24) | (rgba >> 8) & 0xFFFFFFFF), n));
  }
}
