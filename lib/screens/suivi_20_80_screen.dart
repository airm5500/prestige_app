// lib/screens/suivi_20_80_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/suivi_20_80_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class Suivi2080Screen extends StatefulWidget {
  const Suivi2080Screen({super.key});

  @override
  State<Suivi2080Screen> createState() => _Suivi2080ScreenState();
}

class _Suivi2080ScreenState extends State<Suivi2080Screen> with BaseScreenLogic<Suivi2080Screen> {
  List<Suivi2080> _dataList = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  final TextEditingController _limitController = TextEditingController(text: '50');

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      'limit': _limitController.text.trim().isEmpty ? '50' : _limitController.text.trim(),
      'codeFamile': '',
      'codeRayon': '',
      'codeGrossiste': '',
      'qtyOrCa': 'false',
      'page': '1',
      'start': '0',
    };

    final data = await apiGet(AppConstants.suivi2080Endpoint, queryParams: queryParams);

    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _dataList = (data['data'] as List).map((item) => Suivi2080.fromJson(item)).toList();
        if (_dataList.isEmpty) {
          errorMessage = "Aucune donnée trouvée pour les critères sélectionnés.";
        }
      });
    }
  }

  // AJOUT: Widget d'aide pour construire les lignes de détail
  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 15),
          children: <TextSpan>[
            TextSpan(text: '$label: '),
            TextSpan(text: value, style: valueStyle),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi 20/80'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDatePicker(context),
                TextFormField(
                  controller: _limitController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre d\'articles à afficher',
                    hintText: 'Par défaut: 50',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.analytics),
                  label: const Text('Afficher le Suivi'),
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
                  child: Text(errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              ),
            )
          else if (_dataList.isEmpty)
              const Expanded(child: Center(child: Text('Aucune donnée à afficher.')))
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: _dataList.length,
                  itemBuilder: (context, index) {
                    final item = _dataList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.libelle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            _buildDetailRow('CIP', item.cip),
                            // MODIFICATION: Application des styles demandés
                            _buildDetailRow(
                              'Quantité Vendue',
                              '${item.quantiteVendue}',
                              valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            _buildDetailRow(
                              'Stock Actuel',
                              '${item.stock}',
                              valueStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            _buildDetailRow(
                              'Montant',
                              currencyFormat.format(item.montant),
                              valueStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
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