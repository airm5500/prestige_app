// lib/nouvelle_interface/vague4/graphiques_vague4.dart
// 3.11.1 (demande du pharmacien) — graphiques de la Balance vente / caisse :
//  - CamembertParts : répartition (modes de paiement ou type de vente) en camembert, la légende portant pour chaque
//    part la couleur, le libellé, le montant et le pourcentage (lisible sans le graphique) ;
//  - BarresEmpilees : évolution par période, une barre par période empilée par mode de paiement, même légende.
// Couleurs : celles de la charte (aucune couleur nouvelle), dans un ordre fixe.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../charte.dart';
import '../composants.dart' show formaterMontant;
import '../modules/commun_lot3.dart' show graduationVisible, montantCourt;
import '../vague2/donnees_vague2.dart' show pourcentTexte;

/// Couleurs des parts, dans l'ordre (au-delà : on reprend au début).
const couleursParts = <Color>[
  Charte.navy,
  Charte.ambre,
  Charte.familleVentes,
  Charte.familleAnalyses,
  Charte.familleEquipe,
  Charte.familleStock,
  Charte.familleCredits,
  Charte.bleu,
  Charte.gris,
];

Color couleurPart(int i) => couleursParts[i % couleursParts.length];

/// Une part : libellé et montant ; la part en % est calculée sur le total des montants positifs.
typedef PartGraphique = ({String libelle, int montant});

/// Parts en % (une part négative ou nulle compte pour 0).
List<double> pourcentages(List<PartGraphique> parts) {
  final total = parts.fold<int>(0, (s, p) => s + (p.montant > 0 ? p.montant : 0));
  return [for (final p in parts) total <= 0 || p.montant <= 0 ? 0 : p.montant * 100 / total];
}

/// Légende : pastille de couleur, libellé, montant et %, une part par ligne.
class LegendeParts extends StatelessWidget {
  final List<PartGraphique> parts;
  final List<double> pourcents;
  final String prefixeCle;
  const LegendeParts({super.key, required this.parts, required this.pourcents, required this.prefixeCle});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < parts.length; i++)
          Padding(
            key: Key('${prefixeCle}_legende_$i'),
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: couleurPart(i), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(parts[i].libelle, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Charte.encre, fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(formaterMontant(parts[i].montant), style: const TextStyle(color: Charte.encre, fontSize: 13.5, fontWeight: FontWeight.w700)),
              SizedBox(
                width: 58,
                child: Text(pourcentTexte(pourcents[i]),
                    textAlign: TextAlign.right, style: const TextStyle(color: Charte.grisTexte, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
      ]);
}

/// Camembert d'une répartition, avec sa légende (montants et %).
class CamembertParts extends StatelessWidget {
  final List<PartGraphique> parts;
  final String titre;
  final String prefixeCle;
  const CamembertParts({super.key, required this.parts, required this.titre, required this.prefixeCle});

  @override
  Widget build(BuildContext context) {
    final p = pourcentages(parts);
    final visibles = [for (var i = 0; i < parts.length; i++) if (parts[i].montant > 0) i];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (visibles.isNotEmpty)
        Semantics(
          label: '$titre : ${[for (final i in visibles) '${parts[i].libelle} ${pourcentTexte(p[i])}'].join(', ')}',
          child: SizedBox(
            key: Key('${prefixeCle}_camembert'),
            height: 170,
            child: PieChart(PieChartData(
              centerSpaceRadius: 0,
              sectionsSpace: 1.5,
              pieTouchData: PieTouchData(enabled: false),
              sections: [
                for (final i in visibles)
                  PieChartSectionData(
                    color: couleurPart(i),
                    value: parts[i].montant.toDouble(),
                    radius: 80,
                    // % écrit dans la part quand elle est assez grande (sinon : légende).
                    title: p[i] >= 8 ? '${p[i].round()} %' : '',
                    titleStyle: TextStyle(
                        color: couleurPart(i) == Charte.ambre ? Charte.surAmbre : Charte.blanc, fontSize: 12.5, fontWeight: FontWeight.w800),
                    titlePositionPercentageOffset: 0.62,
                  ),
              ],
            )),
          ),
        ),
      const SizedBox(height: 8),
      LegendeParts(parts: parts, pourcents: p, prefixeCle: prefixeCle),
    ]);
  }
}

/// Barres empilées : une barre par période ([periodes] : libellés courts), une couleur par série ([series]).
/// [valeurs][periode][serie] = montant.
class BarresEmpilees extends StatelessWidget {
  final List<String> periodes;
  final List<String> series;
  final List<List<int>> valeurs;
  final String titre;
  const BarresEmpilees({super.key, required this.periodes, required this.series, required this.valeurs, required this.titre});

  @override
  Widget build(BuildContext context) {
    double total(int p) => valeurs[p].fold<int>(0, (s, v) => s + (v > 0 ? v : 0)).toDouble();
    final max = [for (var p = 0; p < periodes.length; p++) total(p)].fold<double>(0, (m, v) => v > m ? v : m);
    const style = TextStyle(color: Charte.gris, fontWeight: FontWeight.bold, fontSize: 10);
    final largeur = periodes.length <= 4 ? 28.0 : (periodes.length <= 8 ? 18.0 : 10.0);
    return Semantics(
      label: '$titre : ${[for (var p = 0; p < periodes.length; p++) '${periodes[p]} ${formaterMontant(total(p).round())}'].join(', ')}',
      child: BarChart(BarChartData(
        maxY: max <= 0 ? 1 : max * 1.15,
        minY: 0,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Charte.ligne, strokeWidth: 0.8)),
        borderData: FlBorderData(show: true, border: Border.all(color: Charte.bordure)),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
                showTitles: true, reservedSize: 42, getTitlesWidget: (v, meta) => Text(graduationVisible(v, meta) ? montantCourt(v) : '', style: style)),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                // Beaucoup de périodes : un libellé sur deux (ou trois) pour rester lisible.
                final pas = periodes.length <= 6 ? 1 : (periodes.length <= 12 ? 2 : 3);
                final t = i >= 0 && i < periodes.length && (i % pas == 0 || i == periodes.length - 1) ? periodes[i] : '';
                return SideTitleWidget(axisSide: meta.axisSide, space: 4, child: Text(t, style: style));
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Charte.navy,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (g, _, rod, __) => BarTooltipItem(
              '${periodes[g.x]}\n',
              const TextStyle(color: Charte.enteteGris, fontSize: 11),
              children: [
                for (var s = 0; s < series.length; s++)
                  if (valeurs[g.x][s] > 0)
                    TextSpan(text: '${series[s]} : ${formaterMontant(valeurs[g.x][s])}\n', style: const TextStyle(color: Charte.blanc, fontSize: 11.5)),
                TextSpan(text: 'Total ${formaterMontant(total(g.x).round())}', style: const TextStyle(color: Charte.blanc, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        barGroups: [
          for (var p = 0; p < periodes.length; p++)
            BarChartGroupData(x: p, barRods: [
              BarChartRodData(
                toY: total(p),
                width: largeur,
                color: Colors.transparent,
                borderRadius: BorderRadius.zero,
                rodStackItems: () {
                  final l = <BarChartRodStackItem>[];
                  var bas = 0.0;
                  for (var s = 0; s < series.length; s++) {
                    final v = valeurs[p][s] > 0 ? valeurs[p][s].toDouble() : 0.0;
                    if (v == 0) continue;
                    l.add(BarChartRodStackItem(bas, bas + v, couleurPart(s)));
                    bas += v;
                  }
                  return l;
                }(),
              ),
            ]),
        ],
      )),
    );
  }
}
