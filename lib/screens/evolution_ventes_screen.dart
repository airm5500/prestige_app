// lib/screens/evolution_ventes_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/tableau_bord_achats_ventes_model.dart';
import '../utils/date_formatter.dart';

// Extension pour manipuler les couleurs
extension ColorExtensionOnColorForVentesEvolution on Color {
  Color darker([double amount = .2]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  Color lighter([double amount = .2]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }
}

class EvolutionVentesScreen extends StatelessWidget {
  final List<TableauBordAchatsVentes> dataList;
  final DateTime startDate;
  final DateTime endDate;

  const EvolutionVentesScreen({
    super.key,
    required this.dataList,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spotsVentes = [];
    double maxY = 0;

    for (int i = 0; i < dataList.length; i++) {
      final item = dataList[i];
      double xValue = i.toDouble();
      spotsVentes.add(FlSpot(xValue, item.montantVente));
      if (item.montantVente > maxY) {
        maxY = item.montantVente;
      }
    }

    if (dataList.length == 1) {
      final item = dataList.first;
      spotsVentes.add(FlSpot(1, item.montantVente));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Évolution des Ventes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20.0),
          child: Text(
            'Période: ${DateFormatter.toDisplayFormat(startDate)} au ${DateFormatter.toDisplayFormat(endDate)}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 16.0),
        child: dataList.isEmpty
            ? const Center(child: Text('Aucune donnée de vente à afficher.'))
            : Column(
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5), getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5)),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: dataList.length > 5 ? (dataList.length/5).roundToDouble().clamp(1,double.infinity) : 1, getTitlesWidget: (value, meta) => _bottomTitleWidgets(value, meta, dataList))),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 70, getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, maxY), interval: maxY > 0 ? (maxY / 5).clamp(1, double.infinity) : 1)),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade400)),
                  minX: 0,
                  maxX: (dataList.length == 1 ? 1 : (dataList.length -1)).toDouble().clamp(0, double.infinity),
                  minY: 0,
                  maxY: maxY == 0 ? 10 : maxY * 1.1,
                  lineBarsData: [
                    _lineChartBarData(spotsVentes, Colors.teal.shade600, 'Ventes'),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => Colors.blueGrey.withAlpha(230),
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final flSpot = barSpot;
                          return LineTooltipItem(
                            'Ventes\n',
                            TextStyle(color: Colors.teal.shade600.darker(0.2), fontWeight: FontWeight.bold, fontSize: 12),
                            children: [
                              TextSpan(
                                text: NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA ', decimalDigits: 0).format(flSpot.y),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: 11),
                              ),
                              TextSpan(
                                text: '\n${dataList.isNotEmpty && flSpot.x.toInt() >= 0 && flSpot.x.toInt() < dataList.length && dataList[flSpot.x.toInt()].dateMvt != null ? DateFormatter.toDisplayFormat(dataList[flSpot.x.toInt()].dateMvt!) : ''}',
                                style: const TextStyle(color: Colors.white70, fontSize: 9),
                              ),
                            ],
                            textAlign: TextAlign.left,
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _legendItem(Colors.teal.shade600, "Ventes"),
          ],
        ),
      ),
    );
  }

  LineChartBarData _lineChartBarData(List<FlSpot> spots, Color color, String name) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      gradient: LinearGradient(colors: [color.lighter(0.1), color.darker(0.1)]),
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: spots.length < 20 || spots.length == 1),
      belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [color.withAlpha(77), color.withAlpha(0)])),
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta, List<TableauBordAchatsVentes> data) {
    const style = TextStyle(color: Color(0xff68737d), fontWeight: FontWeight.bold, fontSize: 10);
    Widget text;
    int index = value.toInt();
    if (index >= 0 && index < data.length && data[index].dateMvt != null) {
      text = Text(DateFormat('dd/MM', 'fr_FR').format(data[index].dateMvt!), style: style, overflow: TextOverflow.ellipsis);
    } else {
      text = const Text('', style: style);
    }
    return SideTitleWidget(axisSide: meta.axisSide, space: 8.0, child: text);
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta, double chartMaxY) {
    const style = TextStyle(color: Color(0xff67727d), fontWeight: FontWeight.bold, fontSize: 10);
    String text;
    if (value == 0 && chartMaxY == 0) {
      text = '0';
    } else if (value >= 1000000) {
      text = '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      text = '${(value / 1000).toStringAsFixed(0)}K';
    } else {
      text = value.toStringAsFixed(0);
    }
    return Text(text, style: style, textAlign: TextAlign.left);
  }

  Widget _legendItem(Color color, String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(name, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
