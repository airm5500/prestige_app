// lib/screens/ratios_mensuels_screen.dart

export '../donnees/tableau_bord_donnees.dart' show MonthlyRatioData;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../donnees/tableau_bord_donnees.dart';
import '../utils/constants.dart';
import '../ui_helpers/base_screen_logic.dart';
import '../widgets/erreurs_chargement.dart';

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
    reessai = _loadMonthlyData; // « Réessayer » relance ce chargement
    // Lecture et cumul par mois partagés avec la nouvelle interface (lib/donnees/tableau_bord_donnees.dart).
    final (startDate, endDate) = TableauBord.anneeEnCours(DateTime.now());
    final dailyData = await apiDonnees((deco) => TableauBord.charger(context, startDate, endDate, onSessionInvalid: deco));

    if (mounted && dailyData != null) {
      final aggregated = TableauBord.mensuels(dailyData);

      setState(() {
        _monthlyData = aggregated;
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
            : loadError != null
            ? LoadErrorView(message: loadError!.message, onRetry: () => reessai?.call())
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