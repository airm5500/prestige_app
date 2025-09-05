// lib/screens/etat_controle_achat_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/common_data_model.dart';
import 'package:prestige_app/models/etat_controle_achat_meta_model.dart';
// CORRECTION: Le chemin d'importation a été corrigé ici
import '../models/etat_controle_achat_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class EtatControleAchatScreen extends StatefulWidget {
  const EtatControleAchatScreen({super.key});

  @override
  State<EtatControleAchatScreen> createState() => _EtatControleAchatScreenState();
}

class _EtatControleAchatScreenState extends State<EtatControleAchatScreen> with BaseScreenLogic<EtatControleAchatScreen> {
  List<EtatControleAchat> _dataList = [];
  EtatControleAchatMeta? _metaData;
  List<CommonData> _groupesGrossistes = [];
  CommonData? _selectedGroupe;
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();

  @override
  void initState() {
    super.initState();
    _fetchGroupesGrossistes();
  }

  Future<void> _fetchGroupesGrossistes() async {
    final data = await apiGet(AppConstants.groupeGrossisteEndpoint);
    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _groupesGrossistes = (data['data'] as List).map((item) => CommonData.fromJson(item)).toList();
      });
    }
  }

  Future<void> _loadData() async {
    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      'groupeId': _selectedGroupe?.id ?? '',
      'groupBy': 'GROUP', // Comme spécifié dans l'URL d'exemple
      'limit': '9999',
    };

    final data = await apiGet(AppConstants.etatControleAchatEndpoint, queryParams: queryParams);

    if (mounted && data is Map) {
      setState(() {
        if (data['data'] is List) {
          _dataList = (data['data'] as List).map((item) => EtatControleAchat.fromJson(item)).toList();
        }
        if (data['metaData'] is Map) {
          _metaData = EtatControleAchatMeta.fromJson(data['metaData']);
        }
        if (_dataList.isEmpty) {
          errorMessage = "Aucune donnée trouvée pour les critères sélectionnés.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etat de Contrôle des Achats'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDatePicker(context),
                DropdownButtonFormField<CommonData>(
                  decoration: const InputDecoration(labelText: 'Groupe Grossiste'),
                  value: _selectedGroupe,
                  hint: const Text('Tous les groupes'),
                  items: [
                    const DropdownMenuItem<CommonData>(value: null, child: Text('Tous les groupes')),
                    ..._groupesGrossistes.map((groupe) {
                      return DropdownMenuItem<CommonData>(value: groupe, child: Text(groupe.libelle));
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGroupe = value;
                    });
                  },
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
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildResultsTable(),
                      if (_metaData != null) _buildTotalsSection(_metaData!, currencyFormat),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildResultsTable() {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Groupe', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Nb Bons', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Montant HT', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Montant TTC', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
          DataColumn(label: Text('Marge', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
        ],
        rows: _dataList.map((item) {
          return DataRow(cells: [
            DataCell(Text(item.groupByLibelle)),
            DataCell(Text(item.nbreBon.toString())),
            DataCell(Text(currencyFormat.format(item.montantHtaxe))),
            DataCell(Text(currencyFormat.format(item.montantTtc))),
            DataCell(Text(currencyFormat.format(item.montantMarge))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildTotalsSection(EtatControleAchatMeta totals, NumberFormat format) {
    const boldBlueStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.blue);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow("Total Bons:", totals.totalNbreBon.toString(), valueStyle: boldBlueStyle),
          _buildDetailRow("Total Achats HT:", format.format(totals.totaltHtaxe), valueStyle: boldBlueStyle),
          _buildDetailRow("Total TVA:", format.format(totals.totalTaxe), valueStyle: boldBlueStyle),
          _buildDetailRow("Total Achats TTC:", format.format(totals.totalTtc), valueStyle: boldBlueStyle),
          _buildDetailRow("Total Ventes TTC:", format.format(totals.totalVenteTtc), valueStyle: boldBlueStyle),
          _buildDetailRow("Total Marge:", format.format(totals.totalMarge), valueStyle: boldBlueStyle),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: valueStyle ?? const TextStyle()),
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
    );
  }
}