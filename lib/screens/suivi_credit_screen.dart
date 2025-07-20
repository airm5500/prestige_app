// lib/screens/suivi_credit_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/suivi_credit_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class SuiviCreditScreen extends StatefulWidget {
  const SuiviCreditScreen({super.key});

  @override
  State<SuiviCreditScreen> createState() => _SuiviCreditScreenState();
}

class _SuiviCreditScreenState extends State<SuiviCreditScreen> with BaseScreenLogic<SuiviCreditScreen> {

  List<SuiviCredit> _dataList = [];
  List<SuiviCredit> _filteredDataList = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterLocally);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _dataList = [];
      _filteredDataList = [];
    });

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      // Le filtre par 'query' est maintenant géré localement pour plus de souplesse
    };

    //final data = await apiGet(AppConstants.suiviCreditEndpoint, queryParams: queryParams, apiContext: ApiContext.prestige);
    final data = await apiGet(AppConstants.suiviCreditEndpoint, queryParams: queryParams);
    if (mounted && data is Map<String, dynamic> && data['data'] is List) {
      setState(() {
        _dataList = (data['data'] as List).map((item) => SuiviCredit.fromJson(item)).toList();
        _filterLocally(); // Appliquer le filtre initial
      });
    }
  }

  void _filterLocally() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDataList = _dataList.where((item) {
        return item.libelleTiersPayant.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && mounted) {
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

  Widget _buildDatePicker(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Date de début:", style: TextStyle(fontSize: 12)),
              TextButton(onPressed: () => _selectDate(context, true), child: Text(DateFormatter.toDisplayFormat(_startDate), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Date de fin:", style: TextStyle(fontSize: 12)),
              TextButton(onPressed: () => _selectDate(context, false), child: Text(DateFormatter.toDisplayFormat(_endDate), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi des Crédits'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDatePicker(context),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Filtrer par tiers payant...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search_sharp),
                  label: const Text('Afficher les Crédits'),
                  onPressed: isLoading ? null : _loadData,
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 50),
                      const SizedBox(height: 10),
                      Text(errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Réessayer'), onPressed: _loadData)
                    ],
                  ),
                ),
              ),
            )
          else if (_filteredDataList.isEmpty)
              Expanded(child: Center(child: Text(_dataList.isNotEmpty ? 'Aucun résultat pour votre filtre.' : 'Aucune donnée à afficher.')))
            else
            // CORRECTION: Remplacement du DataTable par une ListView de Cards
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    itemCount: _filteredDataList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredDataList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.libelleTiersPayant,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const Divider(height: 16),
                              _buildDetailRow('Type:', item.libelleTypeTiersPayant),
                              _buildDetailRow('Nombre de Bons:', item.nbreBons.toString()),
                              _buildDetailRow('Nombre de Clients:', item.nbreClient.toString()),
                              _buildDetailRow(
                                'Montant:',
                                currencyFormat.format(item.montant),
                                highlight: true,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // Widget helper pour afficher une ligne de détail
  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              fontSize: highlight ? 15 : 14,
              color: highlight ? Theme.of(context).primaryColor : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
