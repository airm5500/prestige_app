// lib/nouvelle_interface/modules/commun_lot3.dart
// Briques communes aux modules refaits du lot 3 (analyses), en plus de commun.dart, commun_lot2.dart et
// periode.dart : montants abrégés des axes de graphique, ratio à la française, étiquette de position par rapport à
// la norme (texte ET couleur), légende de graphique (trait plein / pointillé, marqueur), feuille de détail,
// affichage local par tranches (« Afficher plus » sans nouvelle requête).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../donnees/tableau_bord_donnees.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';

/// Montant abrégé pour un axe : « 850 », « 12 k », « 1,2 M ».
String montantCourt(double v) {
  final a = v.abs();
  final s = v < 0 ? '-' : '';
  if (a >= 1000000) return '$s${(a / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  if (a >= 1000) return '$s${(a / 1000).toStringAsFixed(0)} k';
  return '$s${a.toStringAsFixed(0)}';
}

/// Ratio à deux décimales et virgule : « 1,51 ».
String formaterRatio(double r) => r.toStringAsFixed(2).replaceAll('.', ',');

/// Pourcentage à une décimale : « 62,3 % ».
String formaterPourcent(double p) => '${p.toStringAsFixed(1).replaceAll('.', ',')} %';

/// Libellé et ton de la position d'un ratio par rapport à la norme (1,51).
(String, Ton) libelleNorme(PositionNorme p) => switch (p) {
      PositionNorme.sansAchat => ('Sans achat', Ton.gris),
      PositionNorme.conforme => ('≥ norme', Ton.vert),
      PositionNorme.sousLaNorme => ('< norme', Ton.rouge),
    };

/// Étiquette « ≥ norme » (vert) / « < norme » (rouge) / « Sans achat » (gris) : le sens est écrit, pas seulement coloré.
class EtiquetteNorme extends StatelessWidget {
  final double ratio;
  const EtiquetteNorme(this.ratio, {super.key});

  @override
  Widget build(BuildContext context) {
    final (texte, ton) = libelleNorme(TableauBord.position(ratio));
    return Etiquette(texte, ton: ton);
  }
}

/// Une série d'un graphique : couleur, trait (plein ou pointillé) et marqueur (rond ou carré).
class SerieGraphique {
  final String libelle;
  final Color couleur;
  final bool pointilles;
  final bool carre;

  /// Marqueur dans la légende (faux pour une ligne de référence, ex. la norme).
  final bool marqueur;
  const SerieGraphique(this.libelle, this.couleur, {this.pointilles = false, this.carre = false, this.marqueur = true});

  /// Motif du trait (fl_chart : dashArray).
  List<int>? get motif => pointilles ? const [7, 4] : null;
}

/// Légende : un échantillon (trait plein ou pointillé + marqueur) et un libellé par série.
class LegendeGraphique extends StatelessWidget {
  final List<SerieGraphique> series;
  const LegendeGraphique(this.series, {super.key});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 16, runSpacing: 4, children: [
        for (final s in series)
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 30, height: 14, child: CustomPaint(painter: _Echantillon(s))),
            const SizedBox(width: 6),
            Text(s.libelle, style: const TextStyle(color: Charte.encre, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
      ]);
}

class _Echantillon extends CustomPainter {
  final SerieGraphique s;
  _Echantillon(this.s);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = s.couleur
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (s.pointilles) {
      for (double x = 0; x < size.width; x += 11) {
        canvas.drawLine(Offset(x, y), Offset((x + 7).clamp(0, size.width), y), p);
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    if (!s.marqueur) return;
    final c = Offset(size.width / 2, y);
    final f = Paint()..color = s.couleur;
    if (s.carre) {
      canvas.drawRect(Rect.fromCenter(center: c, width: 8, height: 8), f);
    } else {
      canvas.drawCircle(c, 4.5, f);
    }
  }

  @override
  bool shouldRepaint(_Echantillon old) => old.s != s;
}

/// Graduation d'axe : rien pour la borne haute quand elle ne tombe pas sur un pas (évite deux libellés collés).
bool graduationVisible(double v, TitleMeta meta) => v < meta.max || (meta.appliedInterval > 0 && (v / meta.appliedInterval - (v / meta.appliedInterval).round()).abs() < 1e-6);

/// Cadre blanc d'un graphique (même aspect que la courbe de l'Évolution du stock).
class CadreGraphique extends StatelessWidget {
  final double hauteur;
  final Widget child;
  const CadreGraphique({super.key, this.hauteur = 260, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        height: hauteur,
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(6, 18, 18, 8),
        child: child,
      );
}

/// Feuille du bas de détail (une ligne touchée) : titre, sous-titre, lignes.
Future<void> ouvrirFeuilleDetail(BuildContext context, {required String titre, String? sousTitre, required List<Widget> lignes}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SingleChildScrollView(
        key: const Key('feuille_detail'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(titre, style: const TextStyle(color: Charte.navy, fontSize: 18, fontWeight: FontWeight.bold)),
          if (sousTitre != null) ...[
            const SizedBox(height: 2),
            Text(sousTitre, style: const TextStyle(color: Charte.gris, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          ...lignes,
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('detail_fermer'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ]),
      ),
    );

/// Affichage local par tranches : les listes longues (jusqu'à 9 999 lignes) sont construites [tranche] par
/// [tranche] ; « Afficher plus » n'envoie AUCUNE requête (toutes les lignes sont déjà chargées).
mixin AffichageParTranches<W extends StatefulWidget> on State<W> {
  static const tranche = 50;
  int affichees = tranche;

  void reinitialiserTranches() => affichees = tranche;

  /// Pied « N lignes affichées sur M » et « Afficher plus » quand il en reste.
  Widget piedTranches(int total) => total <= tranche
      ? const SizedBox.shrink()
      : PiedPagination(
          affichees: affichees.clamp(0, total),
          total: total,
          enCours: false,
          onPlus: () => setState(() => affichees += tranche),
        );
}

/// 3.11.0 : courbes de montants par jour (fl_chart), une série par élément de [series] (mêmes valeurs que
/// [jours], dans le même ordre). Dates abrégées en abscisse (au plus ~6 libellés), montants abrégés en ordonnée,
/// valeurs au toucher. Sert à la répartition du Détail CA (une courbe par mode de paiement) et aux courbes rapides
/// des 7 derniers jours du Pilotage.
class GraphiqueCourbes extends StatelessWidget {
  final List<DateTime?> jours;
  final List<(SerieGraphique, List<double>)> series;

  /// Format d'une valeur au toucher (montant par défaut ; nombre pour un nombre de ventes).
  final String Function(double) valeurTexte;
  final String libelle;
  const GraphiqueCourbes({super.key, required this.jours, required this.series, required this.libelle, this.valeurTexte = formaterMontantDouble});

  static String formaterMontantDouble(double v) => formaterMontant(v);

  @override
  Widget build(BuildContext context) {
    final n = jours.length;
    List<FlSpot> points(List<double> v) {
      final s = [for (var i = 0; i < n && i < v.length; i++) FlSpot(i.toDouble(), v[i])];
      if (s.length == 1) s.add(FlSpot(1, s.first.y));
      return s;
    }

    var maxY = 0.0;
    for (final (_, v) in series) {
      for (final y in v) {
        if (y > maxY) maxY = y;
      }
    }
    final pas = n > 6 ? (n / 6).ceilToDouble() : 1.0;
    const style = TextStyle(color: Charte.gris, fontWeight: FontWeight.bold, fontSize: 10);
    return Semantics(
      label: libelle,
      child: LineChart(LineChartData(
        minX: 0,
        maxX: (n <= 1 ? 1 : n - 1).toDouble(),
        minY: 0,
        maxY: maxY == 0 ? 10 : maxY * 1.1,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) => const FlLine(color: Charte.ligne, strokeWidth: 0.8),
          getDrawingVerticalLine: (_) => const FlLine(color: Charte.ligne, strokeWidth: 0.8),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Charte.bordure)),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: pas,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                final d = i >= 0 && i < n ? jours[i] : null;
                return SideTitleWidget(axisSide: meta.axisSide, space: 6, child: Text(d == null ? '' : DateFormat('dd/MM').format(d), style: style));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: maxY > 0 ? (maxY / 4).clamp(1, double.infinity) : 1,
              getTitlesWidget: (v, meta) => Text(graduationVisible(v, meta) ? montantCourt(v) : '', style: style),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Charte.navy,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touches) => [
              for (var k = 0; k < touches.length; k++)
                () {
                  final t = touches[k];
                  final i = t.x.toInt();
                  final s = series[t.barIndex].$1;
                  final d = i < n ? jours[i] : null;
                  return LineTooltipItem(
                    k == 0 && d != null ? '${DateFormat('dd/MM/yyyy').format(d)}\n' : '',
                    const TextStyle(color: Charte.enteteGris, fontSize: 11),
                    children: [TextSpan(text: '${s.libelle} : ${valeurTexte(t.y)}', style: const TextStyle(color: Charte.blanc, fontWeight: FontWeight.bold))],
                  );
                }(),
            ],
          ),
        ),
        lineBarsData: [
          for (final (s, v) in series)
            LineChartBarData(
              spots: points(v),
              isCurved: true,
              preventCurveOverShooting: true,
              color: s.couleur,
              barWidth: 3,
              dashArray: s.motif,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: n < 32,
                getDotPainter: (spot, _, __, ___) => s.carre
                    ? FlDotSquarePainter(size: 7, color: s.couleur, strokeWidth: 0)
                    : FlDotCirclePainter(radius: 3.5, color: s.couleur, strokeWidth: 0),
              ),
            ),
        ],
      )),
    );
  }
}
