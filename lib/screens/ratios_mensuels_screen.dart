// lib/screens/ratios_mensuels_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/tableau_bord_achats_ventes_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class MonthlyRatioData {
  final int month;
  double totalAchats;
  double totalVentes;

  MonthlyRatioData({required this.month, this.totalAchats = 0.0, this.totalVentes = 0.0});

  double get ratio => totalAchats == 0 ? 0.0 : totalVentes / totalAchats;
  String get monthName => DateFormat.MMMM('fr_FR').format(DateTime(0, month));
}

class RatiosMensuelsScreen extends StatefulWidget {
  const RatiosMensuelsScreen({super.key});

  @override
  State<RatiosMensuelsScreen> createState() => _RatiosMensuelsScreenState();
}

class _RatiosMensuelsScreenState extends State<RatiosMensuelsScreen> with BaseScreenLogic<RatiosMensuelsScreen> {
  List<MonthlyRatioData> _monthlyData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonthlyData();
    });
  }

  Future<void> _loadMonthlyData() async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, 1, 1);
    final endDate = now;

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(startDate),
      'dtEnd': DateFormatter.toApiFormat(endDate),
    };

    final data = await apiGet(AppConstants.tableauBordAchatsVentesEndpoint, queryParams: queryParams);

    if (mounted && data is List) {
      final dailyData = data.map((item) => TableauBordAchatsVentes.fromJson(item)).toList();

      final Map<int, MonthlyRatioData> aggregatedData = {};

      for (var item in dailyData) {
        if (item.dateMvt != null) {
          final month = item.dateMvt!.month;
          aggregatedData.putIfAbsent(month, () => MonthlyRatioData(month: month));
          aggregatedData[month]!.totalAchats += item.montantAchat;
          aggregatedData[month]!.totalVentes += item.montantVente;
        }
      }

      setState(() {
        _monthlyData = aggregatedData.values.toList()..sort((a, b) => a.month.compareTo(b.month));
        if (_monthlyData.isEmpty) {
          errorMessage = "Aucune donnée trouvée pour l'année en cours.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ratios Mensuels ${DateTime.now().year}'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMonthlyData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)))
            : _monthlyData.isEmpty
            ? const Center(child: Text("Aucune donnée disponible pour l'année en cours."))
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _monthlyData.length,
          itemBuilder: (context, index) {
            final item = _monthlyData[index];
            final ratio = item.ratio;
            final Color ratioColor = ratio == 0 ? Colors.grey : (ratio >= AppConstants.ratioNormeVenteAchat ? Colors.green.shade700 : Colors.red.shade700);

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.monthName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Divider(height: 20),
                    _buildDetailRow("Total Achats:", currencyFormat.format(item.totalAchats)),
                    _buildDetailRow("Total Ventes:", currencyFormat.format(item.totalVentes)),
                    _buildDetailRow(
                      "Ratio Ventes/Achats:",
                      ratio.toStringAsFixed(2),
                      valueColor: ratioColor,
                      isBold: true,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: valueColor,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}