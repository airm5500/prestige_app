// lib/screens/marge_produits_vendus_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/marge_produit_vendu_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class MargeProduitsVendusScreen extends StatefulWidget {
  const MargeProduitsVendusScreen({super.key});

  @override
  State<MargeProduitsVendusScreen> createState() => _MargeProduitsVendusScreenState();
}

class _MargeProduitsVendusScreenState extends State<MargeProduitsVendusScreen> with BaseScreenLogic<MargeProduitsVendusScreen> {
  List<MargeProduitVendu> _dataList = [];
  List<MargeProduitVendu> _filteredDataList = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  int? _selectedMonth;
  final TextEditingController _margeController = TextEditingController();
  String _selectedOperator = '=';

  @override
  void initState() {
    super.initState();
    _margeController.addListener(_filterLocally);
  }

  @override
  void dispose() {
    _margeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      'limit': '9999',
    };

    final data = await apiGet(AppConstants.margeProduitsVendusEndpoint, queryParams: queryParams);

    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _dataList = (data['data'] as List).map((item) => MargeProduitVendu.fromJson(item)).toList();
        _filterLocally();
        if (_dataList.isEmpty) {
          errorMessage = "Aucune donnée trouvée pour les critères sélectionnés.";
        }
      });
    }
  }

  void _filterLocally() {
    final int? margeQuery = int.tryParse(_margeController.text);
    setState(() {
      if (margeQuery == null || _margeController.text.isEmpty) {
        _filteredDataList = List.from(_dataList);
      } else {
        _filteredDataList = _dataList.where((item) {
          switch (_selectedOperator) {
            case '>':
              return item.margePourcentage > margeQuery;
            case '<':
              return item.margePourcentage < margeQuery;
            case '>=':
              return item.margePourcentage >= margeQuery;
            case '<=':
              return item.margePourcentage <= margeQuery;
            case '!=':
              return item.margePourcentage != margeQuery;
          // AJOUT: Logique pour le filtre "Environ"
            case '~=':
              return (item.margePourcentage >= margeQuery - 1) && (item.margePourcentage <= margeQuery + 1);
            case '=':
            default:
              return item.margePourcentage == margeQuery;
          }
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Marge Produits Vendus')),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Filtre Marge'),
                        value: _selectedOperator,
                        items: const [
                          DropdownMenuItem(value: '=', child: Text('Égal à')),
                          DropdownMenuItem(value: '>', child: Text('Supérieur à')),
                          DropdownMenuItem(value: '<', child: Text('Inférieur à')),
                          DropdownMenuItem(value: '>=', child: Text('Supérieur ou égal à')),
                          DropdownMenuItem(value: '<=', child: Text('Inférieur ou égal à')),
                          DropdownMenuItem(value: '!=', child: Text('Différent de')),
                          DropdownMenuItem(value: '~=', child: Text('Environ (±1)')), // AJOUT
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedOperator = value;
                            });
                            _filterLocally();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _margeController,
                        decoration: const InputDecoration(labelText: 'Valeur Marge (%)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Rechercher'),
                  onPressed: isLoading ? null : _loadData,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (errorMessage != null)
            Expanded(child: Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))))
          else if (_dataList.isEmpty)
              const Expanded(child: Center(child: Text('Aucune donnée à afficher.')))
            else if (_filteredDataList.isEmpty)
                const Expanded(child: Center(child: Text('Aucun produit ne correspond à ce filtre.')))
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    itemCount: _filteredDataList.length,
                    itemBuilder: (context, index) {
                      final item = _filteredDataList[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.libelle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('CIP: ${item.code}'),
                              const Divider(),
                              _buildDetailRow('Achat:', currencyFormat.format(item.montantAchat)),
                              _buildDetailRow('Vente:', currencyFormat.format(item.montantVente)),
                              _buildDetailRow('Marge:', currencyFormat.format(item.montantMarge)),
                              _buildDetailRow(
                                'Marge (%):',
                                '${item.margePourcentage} %',
                                valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
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

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: valueStyle)],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(
      context: context, initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000), lastDate: DateTime(2101), locale: const Locale('fr', 'FR'),
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
        _selectedMonth = null;
      });
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