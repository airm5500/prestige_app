// lib/screens/tableau_bord_ratio_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/tableau_bord_achats_ventes_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class TableauBordRatioScreen extends StatefulWidget {
  const TableauBordRatioScreen({super.key});

  @override
  State<TableauBordRatioScreen> createState() => _TableauBordRatioScreenState();
}

class _TableauBordRatioScreenState extends State<TableauBordRatioScreen> {
  late ApiService _apiService;
  List<TableauBordAchatsVentes> _dataList = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();

  bool _isLoading = false;
  String? _errorMessage;

  final TextEditingController _inputVenteNormeeController = TextEditingController();
  final TextEditingController _inputAchatNormeController = TextEditingController();
  String _resultAchatNorme = "";
  String _resultVenteNormee = "";
  final FocusNode _venteFocusNode = FocusNode();
  final FocusNode _achatFocusNode = FocusNode();


  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context);
    _venteFocusNode.addListener(() {
      if (_venteFocusNode.hasFocus) {
        _inputAchatNormeController.clear();
        setState(() => _resultVenteNormee = "");
      }
    });
    _achatFocusNode.addListener(() {
      if (_achatFocusNode.hasFocus) {
        _inputVenteNormeeController.clear();
        setState(() => _resultAchatNorme = "");
      }
    });
  }

  @override
  void dispose() {
    _inputVenteNormeeController.dispose();
    _inputAchatNormeController.dispose();
    _venteFocusNode.dispose();
    _achatFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _dataList = [];
    });

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
    };

    try {
      final data = await _apiService.get(AppConstants.tableauBordAchatsVentesEndpoint, queryParams: queryParams);
      if (!mounted) return;
      if (data is List) {
        setState(() {
          _dataList = data.map((item) => TableauBordAchatsVentes.fromJson(item)).toList();
        });
      } else {
        throw Exception('Format de données incorrect.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _calculerAchatNorme() {
    final double? montantVente = double.tryParse(_inputVenteNormeeController.text);
    if (montantVente != null && montantVente > 0) {
      final double achatNorme = montantVente / AppConstants.ratioNormeVenteAchat;
      setState(() {
        _resultAchatNorme = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(achatNorme);
      });
    } else {
      setState(() => _resultAchatNorme = "");
    }
  }

  void _calculerVenteNormee() {
    final double? montantAchat = double.tryParse(_inputAchatNormeController.text);
    if (montantAchat != null && montantAchat > 0) {
      final double venteNormee = montantAchat * AppConstants.ratioNormeVenteAchat;
      setState(() {
        _resultVenteNormee = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(venteNormee);
      });
    } else {
      setState(() => _resultVenteNormee = "");
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau: Ratios Ventes/Achats'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDatePicker(context),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('Afficher les Données'),
                  onPressed: _isLoading ? null : _loadData,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Norme Ratio Vente/Achat Cible: ${AppConstants.ratioNormeVenteAchat.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.primaryColorDark),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 50),
                      const SizedBox(height: 10),
                      Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Réessayer'), onPressed: _loadData)
                    ],
                  ),
                ),
              ),
            )
          else if (_dataList.isEmpty)
              const Expanded(child: Center(child: Text('Aucune donnée à afficher pour la période sélectionnée.')))
            else
              Expanded(
                child: SingleChildScrollView( // Main scroll for table and calculation section
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: DataTable(
                          columnSpacing: 10,
                          headingRowHeight: 40,
                          dataRowMinHeight: 35,
                          dataRowMaxHeight: 45,
                          columns: const [
                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Achats', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                            DataColumn(label: Text('Ventes', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                            DataColumn(label: Text('Ratio', style: TextStyle(fontWeight: FontWeight.bold)), numeric: true),
                          ],
                          rows: _dataList.map((item) {
                            final ratio = item.ratio;
                            final Color ratioColor = ratio == 0 ? Colors.grey : (ratio >= AppConstants.ratioNormeVenteAchat ? Colors.green.shade700 : Colors.red.shade700);
                            return DataRow(cells: [
                              DataCell(Text(item.dateMvt != null ? DateFormatter.toDisplayFormat(item.dateMvt!) : 'N/A')),
                              DataCell(Text(currencyFormat.format(item.montantAchat))),
                              DataCell(Text(currencyFormat.format(item.montantVente))),
                              DataCell(Text(ratio.toStringAsFixed(2), style: TextStyle(color: ratioColor, fontWeight: FontWeight.bold))),
                            ]);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildNormeCalculationSection(theme, currencyFormat),
                      const SizedBox(height: 20), // Spacing at the bottom
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildNormeCalculationSection(ThemeData theme, NumberFormat currencyFormat) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Calcul Basé sur la Norme (${AppConstants.ratioNormeVenteAchat.toStringAsFixed(2)})', style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColorDark)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputVenteNormeeController,
                    focusNode: _venteFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Si Vente (FCFA)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.trending_up),
                    ),
                    onChanged: (value) => _calculerAchatNorme(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Achat Normé (FCFA):', style: TextStyle(fontSize: 12)),
                      Text(_resultAchatNorme, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputAchatNormeController,
                    focusNode: _achatFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Si Achat (FCFA)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.trending_down),
                    ),
                    onChanged: (value) => _calculerVenteNormee(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vente Normée (FCFA):', style: TextStyle(fontSize: 12)),
                      Text(_resultVenteNormee, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text("Saisir une valeur dans l'un des champs pour calculer l'autre.", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
