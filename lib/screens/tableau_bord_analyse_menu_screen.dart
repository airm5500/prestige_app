// lib/screens/tableau_bord_analyse_menu_screen.dart

import 'package:flutter/material.dart';
import '../models/tableau_bord_achats_ventes_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart'; // Importer la logique centralisée
import 'evolution_comparative_screen.dart';
import 'evolution_achats_screen.dart';
import 'evolution_ventes_screen.dart';

class TableauBordAnalyseMenuScreen extends StatefulWidget {
  const TableauBordAnalyseMenuScreen({super.key});

  @override
  State<TableauBordAnalyseMenuScreen> createState() => _TableauBordAnalyseMenuScreenState();
}

// On ajoute 'with BaseScreenLogic' pour hériter des fonctionnalités
class _TableauBordAnalyseMenuScreenState extends State<TableauBordAnalyseMenuScreen> with BaseScreenLogic<TableauBordAnalyseMenuScreen> {

  List<TableauBordAchatsVentes> _dataList = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  bool _dataLoaded = false;

  // Les variables 'isLoading' et 'errorMessage' sont maintenant gérées par le mixin.

  Future<void> _loadDataForAnalyses() async {
    // On réinitialise l'état avant chaque appel
    setState(() {
      _dataList = [];
      _dataLoaded = false;
    });

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
    };

    // Utilisation de la méthode centralisée 'apiGet'
    final data = await apiGet(AppConstants.tableauBordAchatsVentesEndpoint, queryParams: queryParams);

    if (mounted && data is List) {
      setState(() {
        var tempList = data.map((item) => TableauBordAchatsVentes.fromJson(item)).toList();

        tempList.sort((a, b) {
          if (a.dateMvt == null && b.dateMvt == null) return 0;
          if (a.dateMvt == null) return 1;
          if (b.dateMvt == null) return -1;
          return a.dateMvt!.compareTo(b.dateMvt!);
        });
        _dataList = tempList;

        _dataLoaded = _dataList.isNotEmpty;
        if (!_dataLoaded) {
          errorMessage = "Aucune donnée trouvée pour la période sélectionnée pour l'analyse.";
        }
      });
    }
    // La gestion du chargement et des erreurs est automatique !
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final picked = await showDatePicker(context: context, initialDate: isStartDate ? _startDate : _endDate, firstDate: DateTime(2000), lastDate: DateTime(2101), locale: const Locale('fr', 'FR'));
    if (picked != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate)) _startDate = _endDate;
        }
        _dataLoaded = false;
        _dataList = [];
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tableau: Menu Analyses')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _buildDatePicker(context),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(icon: const Icon(Icons.refresh_outlined), label: const Text('Charger les Données pour Analyse'), onPressed: isLoading ? null : _loadDataForAnalyses, style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading) const Center(child: CircularProgressIndicator())
            else if (errorMessage != null) Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, color: Colors.red[700], size: 40), const SizedBox(height: 8), Text(errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 15))])))
            else if (!_dataLoaded && !isLoading) Padding(padding: const EdgeInsets.all(16.0), child: Center(child: Text('Veuillez charger les données pour la période sélectionnée avant de consulter les analyses.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey[700]))))
              else if (_dataLoaded) ...[
                  Text("Analyses Disponibles:", style: theme.textTheme.titleMedium?.copyWith(color: theme.primaryColorDark)),
                  const SizedBox(height: 10),
                  _buildAnalysisButton(context, title: 'Évolution Comparative Achats vs Ventes', icon: Icons.multiline_chart_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EvolutionComparaisonScreen(dataList: _dataList, startDate: _startDate, endDate: _endDate)))),
                  _buildAnalysisButton(context, title: 'Évolution des Achats', icon: Icons.show_chart_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EvolutionAchatsScreen(dataList: _dataList, startDate: _startDate, endDate: _endDate)))),
                  _buildAnalysisButton(context, title: 'Évolution des Ventes', icon: Icons.stacked_line_chart_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EvolutionVentesScreen(dataList: _dataList, startDate: _startDate, endDate: _endDate)))),
                ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisButton(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor, size: 30),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded),
        onTap: onTap,
      ),
    );
  }
}
