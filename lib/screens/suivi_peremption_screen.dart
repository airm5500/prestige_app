// lib/screens/suivi_peremption_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/suivi_peremption_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class SuiviPeremptionScreen extends StatefulWidget {
  const SuiviPeremptionScreen({super.key});

  @override
  State<SuiviPeremptionScreen> createState() => _SuiviPeremptionScreenState();
}

class _SuiviPeremptionScreenState extends State<SuiviPeremptionScreen> with BaseScreenLogic<SuiviPeremptionScreen> {
  List<SuiviPeremption> _dataList = [];
  final TextEditingController _moisController = TextEditingController();

  @override
  void dispose() {
    _moisController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_moisController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer un nombre de mois.'), backgroundColor: Colors.orange),
      );
      return;
    }

    final queryParams = {
      'nbreMois': _moisController.text.trim(),
      'limit': '99999',
    };

    final data = await apiGet(AppConstants.suiviPeremptionEndpoint, queryParams: queryParams);

    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _dataList = (data['data'] as List).map((item) => SuiviPeremption.fromJson(item)).toList();
        if (_dataList.isEmpty) {
          errorMessage = "Aucun produit en voie de péremption trouvé pour ce critère.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivi Péremption'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextFormField(
                  controller: _moisController,
                  decoration: const InputDecoration(
                    labelText: 'Périmé dans combien de mois ?',
                    hintText: 'Ex: 5',
                  ),
                  keyboardType: TextInputType.number,
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
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              ),
            )
          else if (_dataList.isEmpty)
              const Expanded(child: Center(child: Text('Aucune donnée à afficher. Lancez une recherche.')))
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
                            Text('CIP: ${item.cip}'),
                            Text('Grossiste: ${item.grossiste}'),
                            Text('Stock Actuel: ${item.stockActuel}'),
                            Text('Prix de Vente: ${currencyFormat.format(item.prixVente)}'),
                            Text('Emplacement: ${item.emplacement}'),
                            Text('Date Péremption: ${item.datePeremption != null ? DateFormatter.toDisplayFormat(item.datePeremption!) : 'N/A'}'),
                            Text(
                              'Statut: ${item.statut}',
                              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
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
}