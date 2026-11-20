// lib/widgets/defilement.dart
// 3.16.0 (retour du pharmacien : « on ne voit pas qu'une liste continue », ex. Pilotage, onglet « À suivre ») —
// indicateur de défilement VERTICAL toujours visible, posé sur TOUTES les listes de l'application par le
// comportement de défilement global (MaterialApp.scrollBehavior, lib/main.dart), dans les deux interfaces.
//
// Choix : un indicateur dessiné à partir des notifications de défilement de SA liste (profondeur 0), sans
// ScrollController. Un Scrollbar Flutter « thumbVisibility: true » exige un contrôleur attaché à une seule liste :
// avec le PrimaryScrollController partagé (plusieurs ListView verticales sous un même Scaffold, onglets) il lève
// « ScrollController attached to multiple scroll views » / « no ScrollPosition attached ». Ici rien de tel : chaque
// liste verticale a son propre indicateur, nourri par ses seules notifications.
//  - Listes horizontales : rien (inchangées).
//  - Liste plus courte que l'écran : rien n'est dessiné.
//  - L'indicateur ne capte aucun toucher (les taps près du bord droit atteignent la ligne en dessous) et il est dessiné
//    SOUS le contenu (dans la marge droite et sur le fond) : il ne cache ni n'assombrit jamais un texte.
//  - Couleur : celle du thème (colorScheme.onSurface à 28 %), dans les deux interfaces : visible sur le fond, plus
//    claire que les textes foncés et les pastilles (jamais prise pour le fond d'un texte coupé au bord de l'écran).
//  - Le défilement lui-même (physique, étirement Android, rebond iOS) reste celui de Material.
import 'package:flutter/material.dart';

/// Comportement de défilement de l'application : Material + indicateur vertical toujours visible.
class DefilementPrestige extends MaterialScrollBehavior {
  const DefilementPrestige();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (axisDirectionToAxis(details.direction) != Axis.vertical) return child;
    return IndicateurDefilement(child: child);
  }
}

/// Indicateur vertical toujours visible de la liste [child] (voir l'en-tête du fichier).
class IndicateurDefilement extends StatefulWidget {
  final Widget child;
  const IndicateurDefilement({super.key, required this.child});

  /// Épaisseur du curseur (dp).
  static const epaisseur = 4.0;

  /// Tests de contraste seulement : curseurs non dessinés pendant la photo de l'écran (on mesure un texte contre SON
  /// fond, pas contre l'indicateur posé dans la marge).
  static final masquePourMesure = ValueNotifier<bool>(false);

  @override
  State<IndicateurDefilement> createState() => _IndicateurDefilementState();
}

class _IndicateurDefilementState extends State<IndicateurDefilement> {
  late final _PeintreIndicateur _peintre = _PeintreIndicateur(
    color: Colors.grey, // remplacée par la couleur du thème (didChangeDependencies)
    fadeoutOpacityAnimation: const AlwaysStoppedAnimation<double>(1),
    thickness: IndicateurDefilement.epaisseur,
    radius: const Radius.circular(IndicateurDefilement.epaisseur / 2),
    crossAxisMargin: 2,
    mainAxisMargin: 2,
    minLength: 24,
    ignorePointer: true,
  );

  @override
  void initState() {
    super.initState();
    IndicateurDefilement.masquePourMesure.addListener(_peintre.redessiner);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _peintre
      ..textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr
      ..color = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.28);
  }

  @override
  void dispose() {
    IndicateurDefilement.masquePourMesure.removeListener(_peintre.redessiner);
    _peintre.dispose();
    super.dispose();
  }

  bool _surMesures(ScrollMetricsNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) _peintre.update(n.metrics, n.metrics.axisDirection);
    return false;
  }

  bool _surDefilement(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) _peintre.update(n.metrics, n.metrics.axisDirection);
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollMetricsNotification>(
        onNotification: _surMesures,
        child: NotificationListener<ScrollNotification>(
          onNotification: _surDefilement,
          child: RepaintBoundary(
            child: CustomPaint(
              key: const Key('indicateur_defilement'),
              // Dessiné SOUS le contenu : jamais par-dessus un texte (contraste intact) ; visible dans la marge et sur
              // le fond de l'écran.
              painter: _peintre,
              child: RepaintBoundary(child: widget.child),
            ),
          ),
        ),
      );
}

/// Peintre du curseur de Flutter, sans zone de toucher (indicateur seulement).
class _PeintreIndicateur extends ScrollbarPainter {
  _PeintreIndicateur({
    required super.color,
    required super.fadeoutOpacityAnimation,
    super.thickness,
    super.radius,
    super.crossAxisMargin,
    super.mainAxisMargin,
    super.minLength,
    super.ignorePointer,
  });

  /// Le curseur est-il dessiné (liste plus longue que l'écran) ? Lu par les tests.
  bool get visible => lastMetrics != null && lastMetrics!.maxScrollExtent > lastMetrics!.minScrollExtent;

  ScrollMetrics? lastMetrics;

  @override
  void update(ScrollMetrics metrics, AxisDirection axisDirection) {
    lastMetrics = metrics;
    super.update(metrics, axisDirection);
  }

  @override
  bool? hitTest(Offset? position) => false;

  void redessiner() => notifyListeners();

  @override
  void paint(Canvas canvas, Size size) {
    if (IndicateurDefilement.masquePourMesure.value) return;
    super.paint(canvas, size);
  }
}

/// Pour les tests : le curseur de la liste dont l'indicateur est [element] est-il dessiné ?
bool indicateurVisible(Element element) {
  final w = element.widget;
  if (w is! CustomPaint || w.painter is! _PeintreIndicateur) return false;
  return (w.painter! as _PeintreIndicateur).visible;
}
