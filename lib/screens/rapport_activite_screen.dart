// lib/screens/rapport_activite_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:prestige_app/models/achat_recap_model.dart';
import 'package:prestige_app/models/credit_recap_model.dart';
import 'package:prestige_app/models/dashboard_recap_model.dart';
import 'package:prestige_app/models/reglement_recap_model.dart';
import 'package:prestige_app/models/reglement_type_recap_model.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class RapportActiviteScreen extends StatefulWidget {
  const RapportActiviteScreen({super.key});

  @override
  State<RapportActiviteScreen> createState() => _RapportActiviteScreenState();
}

class _RapportActiviteScreenState extends State<RapportActiviteScreen> with BaseScreenLogic<RapportActiviteScreen> {
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  int? _selectedMonth; // AJOUT

  DashboardRecap? _dashboardData;
  List<CreditRecap> _credits = [];
  CreditTotalsRecap? _creditTotals;
  List<ReglementRecap> _reglements = [];

  Future<void> _loadRapport() async {
    setState(() {
      isLoading = true;
      _dashboardData = null;
      _credits = [];
      _creditTotals = null;
      _reglements = [];
      errorMessage = null;
    });

    try {
      final queryParams = {
        'dtStart': DateFormatter.toApiFormat(_startDate),
        'dtEnd': DateFormatter.toApiFormat(_endDate),
      };
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final results = await Future.wait([
        apiService.get(context, AppConstants.dashboardRecapEndpoint, queryParams: queryParams, onSessionInvalid: authProvider.forceLogout),
        apiService.get(context, AppConstants.creditsRecapEndpoint, queryParams: queryParams, onSessionInvalid: authProvider.forceLogout),
        apiService.get(context, AppConstants.creditTotalsRecapEndpoint, queryParams: queryParams, onSessionInvalid: authProvider.forceLogout),
        apiService.get(context, AppConstants.reglementsRecapEndpoint, queryParams: queryParams, onSessionInvalid: authProvider.forceLogout),
      ]);

      if (mounted) {
        setState(() {
          if (results[0] is Map && results[0]['data'] is Map) {
            _dashboardData = DashboardRecap.fromJson(results[0]['data']);
          }
          if (results[1] is Map && results[1]['data'] is List) {
            _credits = (results[1]['data'] as List).map((item) => CreditRecap.fromJson(item)).toList();
          }
          if (results[2] is Map) {
            _creditTotals = CreditTotalsRecap.fromJson(results[2] as Map<String, dynamic>);
          }
          if (results[3] is Map && results[3]['data'] is List) {
            _reglements = (results[3]['data'] as List).map((item) => ReglementRecap.fromJson(item)).toList();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString().replaceFirst("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rapport d'Activité")),
      body: Column(
        children: [
          Padding(
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
                ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Générer le Rapport'),
                  onPressed: isLoading ? null : _loadRapport,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (errorMessage != null)
            Expanded(child: Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))))
          else if (_dashboardData == null && _credits.isEmpty && _reglements.isEmpty)
              const Expanded(child: Center(child: Text('Aucune donnée à afficher. Lancez la génération du rapport.')))
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Column(
                    children: [
                      if (_dashboardData != null) _buildDashboardSection(_dashboardData!),
                      if (_credits.isNotEmpty) _buildCreditsSection(_credits, _creditTotals),
                      if (_reglements.isNotEmpty) _buildReglementsSection(_reglements),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildDashboardSection(DashboardRecap data) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    return _buildSectionCard(
      title: "Vue d'ensemble de la journée",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow("Montant Total TTC:", currencyFormat.format(data.montantTtc)),
          _buildDetailRow("Montant Total HT:", currencyFormat.format(data.montantHt)),
          _buildDetailRow("Montant Total TVA:", currencyFormat.format(data.montantTVA)),
          _buildDetailRow("Marge brute:", currencyFormat.format(data.marge)),
          _buildDetailRow("Ratio:", data.ratio.toStringAsFixed(2)),
          _buildDetailRow("Montant Crédit:", currencyFormat.format(data.montantCredit)),
          _buildDetailRow("Montant Réglé:", currencyFormat.format(data.montantRegle)),

          const Divider(),
          const Text("Détail des Règlements", style: TextStyle(fontWeight: FontWeight.bold)),
          ...data.reglements.map((r) => _buildDetailRow("${r.libelle}:", currencyFormat.format(r.montant))).toList(),

          const Divider(),
          const Text("Achats du jour", style: TextStyle(fontWeight: FontWeight.bold)),
          ...data.achats.map((a) => _buildDetailRow("${a.libelleGroupeGrossiste}:", currencyFormat.format(a.montantTTC))).toList(),

          const Divider(),
          const Text("Mouvements de caisse", style: TextStyle(fontWeight: FontWeight.bold)),
          ...data.mvtsCaisse.map((mvt) => _buildDetailRow("${mvt['libelle']}:", currencyFormat.format(mvt['montant']))).toList(),

        ],
      ),
    );
  }

  Widget _buildCreditsSection(List<CreditRecap> credits, CreditTotalsRecap? totals) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    return _buildSectionCard(
      title: "Crédits Accordés",
      child: Column(
        children: [
          ...credits.map((c) => _buildDetailRow('${c.tiersPayant}:', currencyFormat.format(c.montant))).toList(),
          if (totals != null) ...[
            const Divider(),
            _buildDetailRow("Nombre total de clients:", totals.totalClients.toString()),
            _buildDetailRow("Nombre total de bons:", totals.totalBons.toString()),
            _buildDetailRow("Montant total des crédits:", currencyFormat.format(totals.totalMontant), isBold: true),
          ]
        ],
      ),
    );
  }

  Widget _buildReglementsSection(List<ReglementRecap> reglements) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    return _buildSectionCard(
      title: "Détail des Règlements Reçus",
      child: Column(
        children: reglements
            .map((r) => _buildDetailRow('${r.description} (${r.reference}):', currencyFormat.format(r.montant)))
            .toList(),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
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
          children: [
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
          _loadRapport();
        }
      },
    );
  }
}