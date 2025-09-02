// lib/screens/ca_comptant_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/ca_comptant_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart'; // Importer la logique centralisée

extension ColorExtensionOnColorForCaComptantScreen on Color {
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

class CaComptantScreen extends StatefulWidget {
  const CaComptantScreen({super.key});

  @override
  State<CaComptantScreen> createState() => _CaComptantScreenState();
}

class _CaComptantScreenState extends State<CaComptantScreen> with BaseScreenLogic<CaComptantScreen> {
  List<CaComptant> _caComptantDataList = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  int? _selectedMonth;
  final List<Color> _pieColors = [
    Colors.blue.shade400, Colors.green.shade400, Colors.orange.shade400, Colors.purple.shade400, Colors.red.shade400, Colors.teal.shade400, Colors.pink.shade300
  ];

  Future<void> _loadCaComptant() async {
    setState(() => _caComptantDataList = []);

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
    };

    final data = await apiGet(AppConstants.caComptantEndpoint, queryParams: queryParams);

    if (mounted && data is List) {
      setState(() {
        var tempList = data.map((item) => CaComptant.fromJson(item)).toList();
        tempList.sort((a, b) {
          if (a.mvtDate == null || b.mvtDate == null) return 0;
          return a.mvtDate!.compareTo(b.mvtDate!);
        });
        _caComptantDataList = tempList;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      if(mounted){
        setState(() {
          if (isStartDate) {
            _startDate = picked;
            if (_endDate.isBefore(_startDate)) _endDate = _startDate;
          } else {
            _endDate = picked;
            if (_startDate.isAfter(_endDate)) _startDate = _endDate;
          }
          _selectedMonth = null;
        });
      }
    }
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Date de début:", style: TextStyle(fontSize: 12)),
                  TextButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(DateFormatter.toDisplayFormat(_startDate), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Date de fin:", style: TextStyle(fontSize: 12)),
                  TextButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(DateFormatter.toDisplayFormat(_endDate), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthPicker() {
    final now = DateTime.now();
    final months = List.generate(now.month, (index) => index + 1);

    return DropdownButtonFormField<int>(
      decoration: const InputDecoration(labelText: 'Mois'),
      value: _selectedMonth,
      hint: const Text('Choisir...'),
      items: months.map((month) {
        return DropdownMenuItem<int>(
          value: month,
          child: Text(DateFormat.MMMM('fr_FR').format(DateTime(now.year, month))),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedMonth = value;
            final year = now.year;
            _startDate = DateTime(year, value, 1);
            _endDate = DateTime(year, value + 1, 0);
          });
          _loadCaComptant();
        }
      },
    );
  }

  CaComptant get _aggregatedData {
    if (_caComptantDataList.isEmpty) {
      return CaComptant(montantCredit: 0, remiseSurCA: 0, totCB: 0, totChq: 0, totEsp: 0, totMobile: 0, totTVA: 0, totVirement: 0);
    }
    return _caComptantDataList.reduce((acc, current) {
      return CaComptant(
        montantCredit: acc.montantCredit + current.montantCredit,
        mvtDate: null,
        remiseSurCA: acc.remiseSurCA + current.remiseSurCA,
        totCB: acc.totCB + current.totCB,
        totChq: acc.totChq + current.totChq,
        totEsp: acc.totEsp + current.totEsp,
        totMobile: acc.totMobile + current.totMobile,
        totTVA: acc.totTVA + current.totTVA,
        totVirement: acc.totVirement + current.totVirement,
      );
    });
  }

  Widget _buildPieChartSection() {
    final data = _aggregatedData;
    List<PieChartSectionData> sections = [];
    double totalForPie = 0;

    Map<String, double> pieDataMap = {
      'Espèces': data.totEsp,
      'Crédit': data.montantCredit,
      'Mobile': data.totMobile,
      'Carte B.': data.totCB,
      'Chèque': data.totChq,
      'Virement': data.totVirement,
    };

    pieDataMap.forEach((key, value) {
      if (value > 0) { totalForPie += value;}
    });

    if (totalForPie == 0) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Text("Aucune donnée pour le camembert.", style: TextStyle(fontSize: 16)),
      ));
    }

    int colorIndex = 0;
    pieDataMap.forEach((label, value) {
      if (value > 0) {
        final percentage = (value / totalForPie) * 100;
        sections.add(
          PieChartSectionData(
            color: _pieColors[colorIndex % _pieColors.length],
            value: value,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 100,
            titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 2)]),
          ),
        );
        colorIndex++;
      }
    });

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildStructuredPieChartLegend(pieDataMap),
      ],
    );
  }

  Widget _buildStructuredPieChartLegend(Map<String, double> pieDataMap) {
    List<Widget> legendItems = [];
    int colorIndex = 0;

    pieDataMap.forEach((label, value) {
      if (value > 0) {
        legendItems.add(
            _buildLegendRow(
                _pieColors[colorIndex % _pieColors.length],
                label,
                value
            )
        );
        colorIndex++;
      }
    });

    return Column(children: legendItems);
  }

  Widget _buildLegendRow(Color color, String label, double value) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          Text(
              currencyFormat.format(value),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsTable() {
    final data = _aggregatedData;
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(2),
        },
        border: TableBorder.all(color: Colors.grey.shade300, width: 1, borderRadius: BorderRadius.circular(5)),
        children: [
          _buildTableRow('Total Espèces:', currencyFormat.format(data.totEsp)),
          _buildTableRow('Total Crédit:', currencyFormat.format(data.montantCredit)),
          _buildTableRow('Total Mobile Money:', currencyFormat.format(data.totMobile)),
          _buildTableRow('Total Carte Bancaire:', currencyFormat.format(data.totCB)),
          _buildTableRow('Total Chèque:', currencyFormat.format(data.totChq)),
          _buildTableRow('Total Virement:', currencyFormat.format(data.totVirement)),
          _buildTableRow('TOTAL BRUT PAIEMENTS:', currencyFormat.format(data.totalPaiements), isHeader: true),
          _buildTableRow('Remise sur CA:', currencyFormat.format(data.remiseSurCA)),
          _buildTableRow('Total TVA:', currencyFormat.format(data.totTVA)),
        ],
      ),
    );
  }

  TableRow _buildTableRow(String label, String value, {bool isHeader = false}) {
    return TableRow(
      decoration: BoxDecoration(color: isHeader ? Theme.of(context).primaryColorLight.withAlpha(77) : null),
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label, style: TextStyle(fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: isHeader ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildEvolutionChart() {
    if (_caComptantDataList.isEmpty || (_caComptantDataList.length < 2 && _startDate == _endDate)) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text("Pas assez de données ou période trop courte pour afficher l'évolution.", textAlign: TextAlign.center,),
      ));
    }

    List<FlSpot> spotsEsp = [];
    List<FlSpot> spotsCredit = [];
    List<FlSpot> spotsMobile = [];
    List<FlSpot> spotsCB = [];
    double maxY = 0;

    for (int i = 0; i < _caComptantDataList.length; i++) {
      final item = _caComptantDataList[i];
      double xValue = i.toDouble();
      spotsEsp.add(FlSpot(xValue, item.totEsp));
      spotsCredit.add(FlSpot(xValue, item.montantCredit));
      spotsMobile.add(FlSpot(xValue, item.totMobile));
      spotsCB.add(FlSpot(xValue, item.totCB));
      maxY = [maxY, item.totEsp, item.montantCredit, item.totMobile, item.totCB].reduce((currMax, val) => val > currMax ? val : currMax);
    }

    if (_caComptantDataList.length == 1) {
      final item = _caComptantDataList.first;
      spotsEsp.add(FlSpot(1, item.totEsp));
      spotsCredit.add(FlSpot(1, item.montantCredit));
      spotsMobile.add(FlSpot(1, item.totMobile));
      spotsCB.add(FlSpot(1, item.totCB));
      if (_caComptantDataList.length -1 < 1) {
        maxY = maxY * 1.2;
      }
    }

    return AspectRatio(
      aspectRatio: 1.7,
      child: Padding(
        padding: const EdgeInsets.only(right: 18.0, top: 24, bottom: 12, left: 6),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (LineBarSpot spot) => Colors.blueGrey.withAlpha(230),
                  getTooltipItems: (touchedBarSpots) => touchedBarSpots.map((barSpot) {
                    final flSpot = barSpot;
                    String seriesName = '';
                    Color seriesColor = Colors.white;
                    if (barSpot.barIndex == 0) {seriesName = 'Espèces'; seriesColor = _pieColors[0];}
                    else if (barSpot.barIndex == 1) {seriesName = 'Crédit'; seriesColor = _pieColors[1];}
                    else if (barSpot.barIndex == 2) {seriesName = 'Mobile'; seriesColor = _pieColors[2];}
                    else if (barSpot.barIndex == 3) {seriesName = 'Carte B.'; seriesColor = _pieColors[3];}
                    return LineTooltipItem('$seriesName\n', TextStyle(color: seriesColor.darker(0.2), fontWeight: FontWeight.bold, fontSize: 12),
                        children: [
                          TextSpan(text: NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA ', decimalDigits: 0).format(flSpot.y), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal, fontSize: 11)),
                          TextSpan(text: '\n${_caComptantDataList.isNotEmpty && flSpot.x.toInt() >= 0 && flSpot.x.toInt() < _caComptantDataList.length && _caComptantDataList[flSpot.x.toInt()].mvtDate != null ? DateFormatter.toDisplayFormat(_caComptantDataList[flSpot.x.toInt()].mvtDate!) : ''}', style: const TextStyle(color: Colors.white70, fontSize: 9)),
                        ],
                        textAlign: TextAlign.left
                    );
                  }).toList()
              ),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5), getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5)),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: _caComptantDataList.length > 5 ? (_caComptantDataList.length/5).roundToDouble().clamp(1,double.infinity) : 1, getTitlesWidget: bottomTitleWidgets)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60, getTitlesWidget: leftTitleWidgets, interval: maxY > 0 ? (maxY / 5).clamp(1, double.infinity) : 1)),
            ),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade400)),
            minX: 0,
            maxX: (_caComptantDataList.length == 1 ? 1 : (_caComptantDataList.length -1)).toDouble().clamp(0, double.infinity),
            minY: 0,
            maxY: maxY == 0 ? 10 : maxY * 1.1,
            lineBarsData: [
              _lineChartBarData(spotsEsp, _pieColors[0], 'Espèces'),
              _lineChartBarData(spotsCredit, _pieColors[1], 'Crédit'),
              _lineChartBarData(spotsMobile, _pieColors[2], 'Mobile'),
              _lineChartBarData(spotsCB, _pieColors[3], 'Carte B.'),
            ],
          ),
        ),
      ),
    );
  }

  LineChartBarData _lineChartBarData(List<FlSpot> spots, Color color, String name) {
    return LineChartBarData(spots: spots, isCurved: true, gradient: LinearGradient(colors: [color.lighter(0.1), color.darker(0.1)]), barWidth: 3, isStrokeCapRound: true, dotData: FlDotData(show: spots.length < 15 || spots.length ==1), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [color.withAlpha(77), color.withAlpha(0)])));
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(color: Color(0xff68737d), fontWeight: FontWeight.bold, fontSize: 10);
    Widget text;
    int index = value.toInt();
    if (index >= 0 && index < _caComptantDataList.length && _caComptantDataList[index].mvtDate != null) {
      text = Text(DateFormat('dd/MM', 'fr_FR').format(_caComptantDataList[index].mvtDate!), style: style);
    } else {
      text = const Text('', style: style);
    }
    return SideTitleWidget(axisSide: meta.axisSide, space: 8.0, child: text);
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(color: Color(0xff67727d), fontWeight: FontWeight.bold, fontSize: 10);
    String text;
    if (value >= 1000000) {text = '${(value / 1000000).toStringAsFixed(1)}M';}
    else if (value >= 1000) {text = '${(value / 1000).toStringAsFixed(0)}K';}
    else {text = value.toStringAsFixed(0);}
    return Text(text, style: style, textAlign: TextAlign.left);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Détail CA')),
      body: RefreshIndicator(
        onRefresh: _loadCaComptant,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildDatePicker(context)),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: _buildMonthPicker()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(icon: const Icon(Icons.bar_chart_outlined), label: const Text('Afficher le Détail CA'), onPressed: isLoading ? null : _loadCaComptant, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 50),
                        const SizedBox(height: 10),
                        Text(errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 16)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Réessayer'), onPressed: _loadCaComptant)
                      ],
                    ),
                  ),
                )
              else if (_caComptantDataList.isNotEmpty)
                  Column(
                    children: [
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Text('Répartition du CA (Période)', style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColorDark)),
                              const SizedBox(height: 16),
                              _buildPieChartSection(),
                              const SizedBox(height: 24),
                              Text('Totaux sur la période', style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColorDark)),
                              const SizedBox(height: 8),
                              _buildTotalsTable(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Évolution sur la période', style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColorDark)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildEvolutionChart(),
                              const SizedBox(height: 10),
                              _buildEvolutionChartLegend(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  const Center(child: Padding(
                    padding: EdgeInsets.only(top:30.0),
                    child: Text('Aucun CA trouvé pour la période sélectionnée.', textAlign: TextAlign.center),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvolutionChartLegend() {
    return Wrap(
      spacing: 10.0,
      runSpacing: 5.0,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _legendItem(_pieColors[0], "Espèces"),
        _legendItem(_pieColors[1], "Crédit"),
        _legendItem(_pieColors[2], "Mobile"),
        _legendItem(_pieColors[3], "Carte B."),
      ],
    );
  }

  Widget _legendItem(Color color, String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(2)
          ),
        ),
        const SizedBox(width: 4),
        Text(name, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}