// lib/screens/evolution_stock_screen.dart

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart'; // Importer pour debugPrint
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/api_service.dart';
import '../models/valorisation_model.dart';
import '../models/evolution_stock_point_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

extension ColorExtensionOnColorForEvolutionStock on Color {
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


class EvolutionStockScreen extends StatefulWidget {
  const EvolutionStockScreen({super.key});

  @override
  State<EvolutionStockScreen> createState() => _EvolutionStockScreenState();
}

class _EvolutionStockScreenState extends State<EvolutionStockScreen> {
  late ApiService _apiService;
  List<EvolutionStockPoint> _dataPoints = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();

  final GlobalKey _chartKey = GlobalKey();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context);
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _dataPoints = [];
    });

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
    };

    try {
      final data = await _apiService.get(AppConstants.valorisationAllEndpoint, queryParams: queryParams);
      if (!mounted) return;
      if (data is List) {

        List<EvolutionStockPoint> tempList = [];
        int dayDifference = _endDate.difference(_startDate).inDays;

        // CORRECTION: Remplacement de 'print' par 'debugPrint'
        if (data.length != dayDifference + 1) {
          debugPrint('Warning: Mismatch between date range and data points received.');
        }

        for (int i = 0; i < data.length; i++) {
          final valorisationData = ValorisationStock.fromJson(data[i]);
          final dateForPoint = _startDate.add(Duration(days: i));
          tempList.add(EvolutionStockPoint(date: dateForPoint, data: valorisationData));
        }

        tempList.sort((a, b) => a.date.compareTo(b.date));

        setState(() {
          _dataPoints = tempList;
        });

      } else {
        throw Exception('Format de données incorrect.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _printChart() async {
    try {
      RenderRepaintBoundary boundary = _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Évolution de la Valeur d\'Achat du Stock', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Période du ${DateFormatter.toDisplayFormat(_startDate)} au ${DateFormatter.toDisplayFormat(_endDate)}'),
              pw.SizedBox(height: 20),
              pw.Image(pw.MemoryImage(pngBytes)),
              pw.SizedBox(height: 20),
              pw.Text('Généré par Prestige App', style: pw.TextStyle(font: pw.Font.helveticaOblique())),
            ],
          );
        },
      ));

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      // CORRECTION: Utilisation de `debugPrint` et vérification de `mounted`
      debugPrint("Erreur lors de la génération du PDF: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la préparation de l\'impression.')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: isStartDate ? _startDate : _endDate, firstDate: DateTime(2000), lastDate: DateTime(2101), locale: const Locale('fr', 'FR'),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) { _endDate = _startDate; }
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate)) { _startDate = _endDate; }
        }
      });
    }
  }

  Widget _buildDatePicker(BuildContext context) {
    return Row(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Évolution du Stock'),
        actions: [
          if (_dataPoints.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Imprimer le graphique',
              onPressed: _printChart,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDatePicker(context),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.ssid_chart_outlined),
                  label: const Text('Afficher l\'Évolution'),
                  onPressed: _isLoading ? null : _loadData,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Expanded(child: Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))))
          else if (_dataPoints.isEmpty)
              const Expanded(child: Center(child: Text('Aucune donnée à afficher. Veuillez sélectionner une période.')))
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _EvolutionChart(
                    chartKey: _chartKey,
                    dataPoints: _dataPoints,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _EvolutionChart extends StatelessWidget {
  final GlobalKey chartKey;
  final List<EvolutionStockPoint> dataPoints;

  const _EvolutionChart({required this.chartKey, required this.dataPoints});

  @override
  Widget build(BuildContext context) {
    List<FlSpot> spots = [];
    double maxY = 0;

    for (int i = 0; i < dataPoints.length; i++) {
      final point = dataPoints[i];
      spots.add(FlSpot(i.toDouble(), point.data.valeurAchat));
      if (point.data.valeurAchat > maxY) {
        maxY = point.data.valeurAchat;
      }
    }

    if (dataPoints.length == 1) {
      spots.add(FlSpot(1, dataPoints.first.data.valeurAchat));
    }

    return RepaintBoundary(
      key: chartKey,
      child: Container(
        color: Theme.of(context).cardColor,
        padding: const EdgeInsets.only(right: 18.0, top: 24, bottom: 12, left: 6),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: true, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5), getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade300, strokeWidth: 0.5)),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, interval: dataPoints.length > 5 ? (dataPoints.length/5).roundToDouble().clamp(1, double.infinity) : 1, getTitlesWidget: (value, meta) => _bottomTitleWidgets(value, meta, dataPoints))),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 80, getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, maxY), interval: maxY > 0 ? (maxY / 5).clamp(1, double.infinity) : 1)),
            ),
            borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade400)),
            minX: 0,
            maxX: (dataPoints.length == 1 ? 1 : (dataPoints.length - 1)).toDouble().clamp(0, double.infinity),
            minY: 0,
            maxY: maxY == 0 ? 10 : maxY * 1.1,
            lineBarsData: [_lineChartBarData(spots, Colors.brown, 'Valeur Achat')],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => Colors.blueGrey.withAlpha(230),
                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                  return touchedBarSpots.map((barSpot) {
                    final flSpot = barSpot;
                    final pointIndex = flSpot.x.toInt();
                    if(pointIndex >= dataPoints.length) { return null; }

                    final point = dataPoints[pointIndex];
                    return LineTooltipItem(
                      'Valeur Achat\n',
                      TextStyle(color: Colors.brown.darker(0.2), fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA ', decimalDigits: 0).format(flSpot.y),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
                        ),
                        TextSpan(
                          text: '\n${DateFormatter.toDisplayFormat(point.date)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
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
    );
  }

  LineChartBarData _lineChartBarData(List<FlSpot> spots, Color color, String name) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: spots.length < 20 || spots.length == 1),
      belowBarData: BarAreaData(show: true, color: color.withAlpha(51)), // ~20% opacité
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta, List<EvolutionStockPoint> data) {
    const style = TextStyle(color: Color(0xff68737d), fontWeight: FontWeight.bold, fontSize: 10);
    Widget text;
    int index = value.toInt();
    if (index >= 0 && index < data.length) {
      text = Text(DateFormat('dd/MM', 'fr_FR').format(data[index].date), style: style, overflow: TextOverflow.ellipsis);
    } else {
      text = const Text('', style: style);
    }
    return SideTitleWidget(axisSide: meta.axisSide, space: 8.0, child: text);
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta, double chartMaxY) {
    const style = TextStyle(color: Color(0xff67727d), fontWeight: FontWeight.bold, fontSize: 10);
    String text;
    // CORRECTION: Ajout des accolades pour le 'if'
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
}
