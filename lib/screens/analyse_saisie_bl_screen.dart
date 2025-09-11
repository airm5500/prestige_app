// lib/screens/analyse_saisie_bl_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/bon_livraison_stat_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class AnalyseSaisieBlScreen extends StatefulWidget {
  const AnalyseSaisieBlScreen({super.key});

  @override
  State<AnalyseSaisieBlScreen> createState() => _AnalyseSaisieBlScreenState();
}

class _AnalyseSaisieBlScreenState extends State<AnalyseSaisieBlScreen> with BaseScreenLogic<AnalyseSaisieBlScreen> {
  List<BonLivraisonStat> _dataList = [];
  List<BonLivraisonStat> _filteredDataList = []; // AJOUT: Pour la liste filtrée
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  int? _selectedMonth;
  String _selectedStatus = 'Tous'; // AJOUT: Pour le filtre de statut

  Future<void> _loadData() async {
    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      'limit': '9999',
    };

    final data = await apiGet(AppConstants.analyseSaisieBlEndpoint, queryParams: queryParams);

    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _dataList = (data['data'] as List).map((item) => BonLivraisonStat.fromJson(item)).toList();
        _filterData(); // AJOUT: Appliquer les filtres après le chargement
        if (_dataList.isEmpty) {
          errorMessage = "Aucune donnée trouvée pour les critères sélectionnés.";
        }
      });
    }
  }

  // AJOUT: Nouvelle fonction pour filtrer les données localement
  void _filterData() {
    setState(() {
      if (_selectedStatus == 'Tous') {
        _filteredDataList = List.from(_dataList);
      } else {
        _filteredDataList = _dataList.where((item) => item.status == _selectedStatus).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse des Saisies BL'),
      ),
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
                // AJOUT: Filtre par statut
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Statut'),
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                    DropdownMenuItem(value: 'Bon', child: Text('Bon')),
                    DropdownMenuItem(value: 'Pas bon', child: Text('Pas bon')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedStatus = value;
                      });
                      _filterData(); // Applique le filtre
                    }
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Lancer l\'Analyse'),
                  onPressed: isLoading ? null : _loadData,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Nombre de BL affichés: ${_filteredDataList.length}', // MODIFICATION
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (errorMessage != null)
            Expanded(child: Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))))
          else if (_dataList.isEmpty)
              const Expanded(child: Center(child: Text('Aucune donnée à afficher.')))
            else if (_filteredDataList.isEmpty)
                const Expanded(child: Center(child: Text('Aucun BL ne correspond à ce filtre.')))
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    itemCount: _filteredDataList.length, // MODIFICATION
                    itemBuilder: (context, index) {
                      final item = _filteredDataList[index]; // MODIFICATION
                      final delay = item.delayInDays;
                      final status = item.status;
                      final statusColor = status == 'Bon' ? Colors.green : Colors.red;

                      return Card(
                        child: ListTile(
                          title: Text(item.refLivraison, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item.fournisseur),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                delay != null ? '$delay jour(s)' : 'N/A',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                status,
                                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
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
          _loadData();
        }
      },
    );
  }
}