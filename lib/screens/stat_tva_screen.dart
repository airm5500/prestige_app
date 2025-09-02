// lib/screens/stat_tva_screen.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/stat_tva_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class StatTvaScreen extends StatefulWidget {
  const StatTvaScreen({super.key});

  @override
  State<StatTvaScreen> createState() => _StatTvaScreenState();
}

class _StatTvaScreenState extends State<StatTvaScreen> with BaseScreenLogic<StatTvaScreen> {
  List<StatTva> _stats = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  String _typeVente = 'TOUT';
  int? _selectedMonth;

  Future<void> _loadStats() async {
    setState(() {
      _stats = [];
    });

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      'typeVente': _typeVente,
    };

    final data = await apiGetV3(AppConstants.statTvaEndpoint, queryParams: queryParams);

    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _stats = (data['data'] as List).map((item) => StatTva.fromJson(item)).toList();
        if (_stats.isEmpty) {
          errorMessage = "Aucune statistique de TVA trouvée pour les critères sélectionnés.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques TVA'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                // MODIFICATION: Réorganisation des filtres
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildDatePicker(context)),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: _buildMonthPicker()),
                  ],
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Type de Vente'),
                  value: _typeVente,
                  items: const [
                    DropdownMenuItem(value: 'TOUT', child: Text('Tout')),
                    DropdownMenuItem(value: 'VNO', child: Text('Vente Non-Ordonnancée')),
                    DropdownMenuItem(value: 'VO', child: Text('Vente Ordonnancée')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _typeVente = value!;
                    });
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.pie_chart),
                  label: const Text('Afficher les Statistiques'),
                  onPressed: isLoading ? null : _loadStats,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              ),
            )
          else if (_stats.isEmpty)
              const Expanded(child: Center(child: Text('Aucune statistique à afficher.')))
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 250,
                          child: PieChart(
                            PieChartData(
                              sections: _buildPieChartSections(),
                              centerSpaceRadius: 40,
                              sectionsSpace: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSummaryTable(),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieChartSections() {
    final totalTtc = _stats.fold<double>(0, (prev, stat) => prev + stat.totalTtc);
    if (totalTtc == 0) return [];

    return _stats.map((stat) {
      final percentage = (stat.totalTtc / totalTtc) * 100;
      return PieChartSectionData(
        color: _getColorForTaux(stat.taux),
        value: stat.totalTtc,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 100,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildSummaryTable() {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0);
    final totalHt = _stats.fold<double>(0, (prev, stat) => prev + stat.totalHt);
    final totalTva = _stats.fold<double>(0, (prev, stat) => prev + stat.totalTva);
    final totalTtc = _stats.fold<double>(0, (prev, stat) => prev + stat.totalTtc);

    const cellStyle = TextStyle(fontSize: 13.0);
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0);
    const totalStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13.0);

    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: FlexColumnWidth(),
      },
      border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300, width: 1)),
      children: [
        const TableRow(
          children: [
            Padding(padding: EdgeInsets.all(8.0), child: Text('Taux', style: headerStyle)),
            Padding(padding: EdgeInsets.all(8.0), child: Text('HT', style: headerStyle, textAlign: TextAlign.right)),
            Padding(padding: EdgeInsets.all(8.0), child: Text('TVA', style: headerStyle, textAlign: TextAlign.right)),
            Padding(padding: const EdgeInsets.all(8.0), child: Text('TTC', style: headerStyle, textAlign: TextAlign.right)),
          ],
        ),
        ..._stats.map((stat) => TableRow(
          children: [
            Padding(padding: const EdgeInsets.all(8.0), child: Text('${stat.taux} %', style: cellStyle)),
            Padding(padding: const EdgeInsets.all(8.0), child: Text(currencyFormat.format(stat.totalHt), textAlign: TextAlign.right, style: cellStyle)),
            Padding(padding: const EdgeInsets.all(8.0), child: Text(currencyFormat.format(stat.totalTva), textAlign: TextAlign.right, style: cellStyle)),
            Padding(padding: const EdgeInsets.all(8.0), child: Text(currencyFormat.format(stat.totalTtc), textAlign: TextAlign.right, style: cellStyle)),
          ],
        )),
        TableRow(
          children: [
            const Padding(padding: EdgeInsets.all(8.0), child: Text('TOTAL:', style: totalStyle)),
            Padding(padding: const EdgeInsets.all(8.0), child: Text(currencyFormat.format(totalHt), style: totalStyle, textAlign: TextAlign.right)),
            Padding(padding: const EdgeInsets.all(8.0), child: Text(currencyFormat.format(totalTva), style: totalStyle, textAlign: TextAlign.right)),
            Padding(padding: const EdgeInsets.all(8.0), child: Text(currencyFormat.format(totalTtc), style: totalStyle, textAlign: TextAlign.right)),
          ],
        ),
      ],
    );
  }

  Color _getColorForTaux(int taux) {
    switch (taux) {
      case 0:
        return Colors.blue;
      case 9:
        return Colors.green;
      case 18:
        return Colors.orange;
      default:
        return Colors.grey;
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
      if (mounted) {
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
      decoration: const InputDecoration(labelText: 'Mois'), // Libellé simplifié
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
          _loadStats(); // Recherche automatique
        }
      },
    );
  }
}