// lib/screens/fichier_journal_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/fichier_journal_model.dart';
import 'package:prestige_app/models/log_filtre_model.dart';
import 'package:prestige_app/models/log_user_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class FichierJournalScreen extends StatefulWidget {
  const FichierJournalScreen({super.key});

  @override
  State<FichierJournalScreen> createState() => _FichierJournalScreenState();
}

class _FichierJournalScreenState extends State<FichierJournalScreen> with BaseScreenLogic<FichierJournalScreen> {
  List<FichierJournal> _logs = [];
  List<LogFiltre> _filtres = [];
  List<LogUser> _users = [];

  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  LogFiltre? _selectedFiltre;
  LogUser? _selectedUser;

  @override
  void initState() {
    super.initState();
    _fetchFilters();
  }

  Future<void> _fetchFilters() async {
    final results = await Future.wait([
      apiGet(AppConstants.logFiltresEndpoint),
      apiGet(AppConstants.logUsersEndpoint),
    ]);
    if (mounted) {
      setState(() {
        if (results[0] is Map && results[0]['data'] is List) {
          _filtres = (results[0]['data'] as List).map((item) => LogFiltre.fromJson(item)).toList();
        }
        if (results[1] is Map && results[1]['data'] is List) {
          _users = (results[1]['data'] as List).map((item) => LogUser.fromJson(item)).toList();
        }
      });
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _logs = [];
    });

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      'criteria': _selectedFiltre?.order.toString() ?? '-1',
      'userId': _selectedUser?.lgUserID ?? '',
      'limit': '200',
    };

    final data = await apiGet(AppConstants.fichierJournalEndpoint, queryParams: queryParams);

    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _logs = (data['data'] as List).map((item) => FichierJournal.fromJson(item)).toList();
        if (_logs.isEmpty) {
          errorMessage = "Aucun log trouvé pour les critères sélectionnés.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fichier Journal')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDatePicker(context),
                DropdownButtonFormField<LogFiltre>(
                  decoration: const InputDecoration(labelText: 'Filtrer par Opération'),
                  value: _selectedFiltre,
                  items: _filtres.map((filtre) {
                    return DropdownMenuItem<LogFiltre>(value: filtre, child: Text(filtre.description));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedFiltre = value),
                ),
                const SizedBox(height: 10), // AJOUT DE L'ESPACEMENT
                DropdownButtonFormField<LogUser>(
                  decoration: const InputDecoration(labelText: 'Filtrer par Utilisateur'),
                  value: _selectedUser,
                  items: [
                    const DropdownMenuItem<LogUser>(value: null, child: Text('Tous les utilisateurs')),
                    ..._users.map((user) {
                      return DropdownMenuItem<LogUser>(value: user, child: Text(user.fullName));
                    }),
                  ],
                  onChanged: (value) => setState(() => _selectedUser = value),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Rechercher'),
                  onPressed: isLoading ? null : _loadLogs,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (errorMessage != null)
            Expanded(child: Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))))
          else if (_logs.isEmpty)
              const Expanded(child: Center(child: Text('Aucun log à afficher.')))
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    return Card(
                      child: ListTile(
                        title: Text(log.description),
                        subtitle: Text(
                          '${log.typeLog} - ${log.userFullName}\nLe ${log.operationDate != null ? DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(log.operationDate!) : 'Date N/A'}',
                        ),
                        isThreeLine: true,
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
      });
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