// lib/screens/suivi_ajustement_screen.dart

import 'package:flutter/material.dart';
import 'package:prestige_app/screens/ajustement_detail_screen.dart';
import '../models/ajustement_model.dart';
import '../models/common_data_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class SuiviAjustementScreen extends StatefulWidget {
  const SuiviAjustementScreen({super.key});

  @override
  State<SuiviAjustementScreen> createState() => _SuiviAjustementScreenState();
}

class _SuiviAjustementScreenState extends State<SuiviAjustementScreen> with BaseScreenLogic<SuiviAjustementScreen> {
  List<Ajustement> _dataList = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  final TextEditingController _motifController = TextEditingController();

  List<CommonData> _typesAjustement = [];
  CommonData? _selectedType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTypesAjustement();
    });
  }

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _fetchTypesAjustement() async {
    final data = await apiGet(AppConstants.typeAjustementsEndpoint);
    if (mounted && data is Map<String, dynamic> && data['data'] is List) {
      setState(() {
        _typesAjustement = (data['data'] as List).map((item) => CommonData.fromJson(item)).toList();
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _dataList = []);

    // CORRECTION: Ajout des paramètres de pagination
    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      'typeFiltre': _selectedType?.id ?? '',
      'page': '1',
      'start': '0',
      'limit': '100', // On charge 100 résultats par défaut
    };

    // CORRECTION: Retrait du paramètre 'apiContext'
    final data = await apiGet(AppConstants.ajustementEndpoint, queryParams: queryParams);

    if (mounted && data is Map<String, dynamic> && data['data'] is List) {
      setState(() {
        _dataList = (data['data'] as List).map((item) => Ajustement.fromJson(item)).toList();
        if (_dataList.isEmpty) {
          errorMessage = "Aucun ajustement trouvé pour cette période.";
        }
      });
    }
  }

  void _setPeriod(int months) {
    final now = DateTime.now();
    setState(() {
      _endDate = now;
      _startDate = DateTime(now.year, now.month - months, now.day);
    });
    _loadData();
  }

  void _setFirstSemester() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = DateTime(now.year, 6, 30);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suivi des Ajustements')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDatePicker(context),
                Wrap(
                  spacing: 8.0,
                  children: [
                    ActionChip(label: const Text('3 Derniers Mois'), onPressed: () => _setPeriod(3)),
                    if (DateTime.now().month > 6)
                      ActionChip(label: const Text('1er Semestre'), onPressed: _setFirstSemester),
                  ],
                ),
                DropdownButtonFormField<CommonData>(
                  decoration: const InputDecoration(labelText: 'Filtrer par motif'),
                  value: _selectedType,
                  hint: const Text('Tous les motifs'),
                  items: [
                    const DropdownMenuItem<CommonData>(
                      value: null,
                      child: Text('Tous les motifs'),
                    ),
                    ..._typesAjustement.map((type) {
                      return DropdownMenuItem<CommonData>(
                        value: type,
                        child: Text(type.libelle),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedType = value;
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
          if (isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (errorMessage != null) Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)))))
          else if (_dataList.isEmpty) const Expanded(child: Center(child: Text('Aucune donnée à afficher.')))
            else Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _dataList.length,
                  itemBuilder: (context, index) {
                    final item = _dataList[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item.description),
                        subtitle: Text("Par: ${item.userFullName} le ${item.dtUPDATED} à ${item.heure}"),
                        trailing: ElevatedButton(
                          child: const Text('Détail'),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(
                                builder: (_) => AjustementDetailScreen(ajustementId: item.lgAJUSTEMENTID, description: item.description)
                            ));
                          },
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
    final DateTime? picked = await showDatePicker(context: context, initialDate: isStartDate ? _startDate : _endDate, firstDate: DateTime(2000), lastDate: DateTime(2101), locale: const Locale('fr', 'FR'));
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
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Date de début:", style: TextStyle(fontSize: 12)),
          TextButton(onPressed: () => _selectDate(context, true), child: Text(DateFormatter.toDisplayFormat(_startDate), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
        ])),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Date de fin:", style: TextStyle(fontSize: 12)),
          TextButton(onPressed: () => _selectDate(context, false), child: Text(DateFormatter.toDisplayFormat(_endDate), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
        ])),
      ],
    );
  }
}
