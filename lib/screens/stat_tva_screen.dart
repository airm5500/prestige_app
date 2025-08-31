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

  Future<void> _loadStats() async {
    // On réinitialise la liste avant chaque appel
    setState(() {
      _stats = [];
    });

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      'typeVente': _typeVente,
    };

    // CORRECTION: Utilisation de la méthode centralisée pour l'API V3
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
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

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
                _buildDatePicker(context),
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
                        const SizedBox(height: 20),
                        ..._buildLegend(currencyFormat),
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

  List<Widget> _buildLegend(NumberFormat currencyFormat) {
    return _stats.map((stat) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              color: _getColorForTaux(stat.taux),
            ),
            const SizedBox(width: 8),
            Text('TVA ${stat.taux}%:'),
            const Spacer(),
            Text(currencyFormat.format(stat.totalTtc), style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }).toList();
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
        });
      }
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
}