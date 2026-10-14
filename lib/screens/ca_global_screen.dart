// lib/screens/ca_global_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ca_global_model.dart';
import '../donnees/analyses_ventes_donnees.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';
import '../widgets/erreurs_chargement.dart';

class CaGlobalScreen extends StatefulWidget {
  const CaGlobalScreen({super.key});

  @override
  State<CaGlobalScreen> createState() => _CaGlobalScreenState();
}

class _CaGlobalScreenState extends State<CaGlobalScreen> with BaseScreenLogic<CaGlobalScreen> {

  List<CaGlobal> _caGlobalDataList = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  int? _selectedMonth;

  Future<void> _loadCaGlobal() async {
    reessai = _loadCaGlobal; // « Réessayer » relance ce chargement
    setState(() {
      _caGlobalDataList = [];
    });

    // Lecture (triée par date) partagée avec la nouvelle interface (lib/donnees/analyses_ventes_donnees.dart).
    final lignes = await apiDonnees((deco) => CaGlobalDonnees.charger(context, _startDate, _endDate, onSessionInvalid: deco));

    if (mounted && lignes != null) {
      setState(() {
        _caGlobalDataList = lignes;
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
      isExpanded: true, // nom du mois long (« septembre ») : tronqué au lieu de déborder sur téléphone
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
          _loadCaGlobal();
        }
      },
    );
  }

  CaGlobal get _aggregatedGlobalData => CaGlobalDonnees.cumul(_caGlobalDataList); // cumul partagé (même calcul)

  Widget _buildGlobalTotalsTable() {
    final data = _aggregatedGlobalData;
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chiffre d\'Affaires Global (Période)',
              style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColorDark),
            ),
            const SizedBox(height: 15),
            _buildDataRow("Total Espèces:", currencyFormat.format(data.totEsp)),
            _buildDataRow("Total Crédit:", currencyFormat.format(data.montantCredit)),
            _buildDataRow("Total Mobile Money:", currencyFormat.format(data.totMobile)),
            _buildDataRow("Total Carte Bancaire:", currencyFormat.format(data.totCB)),
            _buildDataRow("Total Chèque:", currencyFormat.format(data.totChq)),
            _buildDataRow("Total Virement:", currencyFormat.format(data.totVirement)),
            const Divider(height: 20, thickness: 1),
            _buildDataRow("TOTAL CA BRUT:", currencyFormat.format(data.totalCa), isTotal: true),
            const Divider(height: 20, thickness: 1),
            _buildDataRow("Remise sur CA:", currencyFormat.format(data.remiseSurCA)),
            _buildDataRow("Total TVA:", currencyFormat.format(data.totTVA)),
            const SizedBox(height:10),
            _buildDataRow("TOTAL CA NET:", currencyFormat.format(CaGlobalDonnees.net(data)), isTotal: true, isNet: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {bool isTotal = false, bool isNet = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isNet ? Colors.green.shade700 : (isTotal ? Theme.of(context).primaryColorDark : Colors.black87),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isNet ? Colors.green.shade700 : (isTotal ? Theme.of(context).primaryColorDark : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CA Global'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCaGlobal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                      ElevatedButton.icon(
                        icon: const Icon(Icons.assessment_outlined),
                        label: const Text('Afficher le CA Global'),
                        onPressed: isLoading ? null : _loadCaGlobal,
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                      ),
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
              else if (loadError != null)
                LoadErrorView(message: loadError!.message, onRetry: () => reessai?.call())
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
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                          onPressed: _loadCaGlobal,
                        )
                      ],
                    ),
                  ),
                )
              else if (_caGlobalDataList.isNotEmpty)
                  _buildGlobalTotalsTable()
                else
                  const Center(child: Padding(
                    padding: EdgeInsets.only(top:30.0),
                    child: Text('Aucune donnée à afficher pour la période sélectionnée.', textAlign: TextAlign.center),
                  )),

              if (_caGlobalDataList.isNotEmpty && _caGlobalDataList.length > 1 && _startDate != _endDate)
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Détail par jour:", style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _caGlobalDataList.length,
                            itemBuilder: (context, index) {
                              final item = _caGlobalDataList[index];
                              return ListTile(
                                dense: true,
                                title: Text("Date: ${item.mvtDate != null ? DateFormatter.toDisplayFormat(item.mvtDate!) : 'N/A'}"),
                                trailing: Text("Total CA: ${NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(item.totalCa)}"),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}