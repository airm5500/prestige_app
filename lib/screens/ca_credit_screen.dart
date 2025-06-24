// lib/screens/ca_credit_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ca_credit_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart'; // Importer la logique centralisée

class CaCreditScreen extends StatefulWidget {
  const CaCreditScreen({super.key});

  @override
  State<CaCreditScreen> createState() => _CaCreditScreenState();
}

// On ajoute 'with BaseScreenLogic' pour hériter des fonctionnalités
class _CaCreditScreenState extends State<CaCreditScreen> with BaseScreenLogic<CaCreditScreen> {

  List<CaCredit> _caCreditData = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();

  final TextEditingController _searchController = TextEditingController();
  List<CaCredit> _filteredCaCreditData = [];

  // Les variables 'isLoading' et 'errorMessage' viennent maintenant du mixin.

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterCaCreditLocally);
  }

  @override
  void dispose(){
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCaCredit() async {
    // On réinitialise les listes avant chaque appel
    setState(() {
      _caCreditData = [];
      _filteredCaCreditData = [];
    });

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
    };

    // Utilisation de la méthode centralisée 'apiGet'
    final data = await apiGet(AppConstants.caCreditEndpoint, queryParams: queryParams);

    if (mounted && data is List) {
      setState(() {
        _caCreditData = data.map((item) => CaCredit.fromJson(item)).toList();
        _filterCaCreditLocally();
      });
    }
    // La gestion du chargement et des erreurs est automatique !
  }

  void _filterCaCreditLocally() {
    final query = _searchController.text.toLowerCase();
    if(mounted){
      setState(() {
        _filteredCaCreditData = _caCreditData.where((credit) {
          return query.isEmpty ||
              credit.clientName.toLowerCase().contains(query) ||
              credit.ayantDroitName.toLowerCase().contains(query) ||
              credit.numFacturation.toLowerCase().contains(query) ||
              credit.tiersPayantLibelle.toLowerCase().contains(query);
        }).toList();
      });
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
    if (picked != null) {
      if(mounted){
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventes à Crédit'),
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
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Afficher les Ventes à Crédit'),
                  onPressed: isLoading ? null : _loadCaCredit, // Utilise isLoading du mixin
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher (client, N° fact, tiers payant)...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (errorMessage != null)
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 50),
                        const SizedBox(height: 10),
                        Text(errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 16)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                          onPressed: _loadCaCredit,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: _filteredCaCreditData.isEmpty
                  ? Center(
                child: Text(_caCreditData.isEmpty && !isLoading ? 'Aucune vente à crédit trouvée pour la période.' : 'Aucune vente à crédit ne correspond à vos filtres.'),
              )
                  : RefreshIndicator(
                onRefresh: _loadCaCredit,
                child: ListView.builder(
                  itemCount: _filteredCaCreditData.length,
                  itemBuilder: (context, index) {
                    final credit = _filteredCaCreditData[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        title: Text(credit.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (credit.ayantDroitName.isNotEmpty && credit.ayantDroitName != credit.clientName)
                              Text('Ayant droit: ${credit.ayantDroitName}'),
                            Text('Date: ${credit.mvtDate != null ? DateFormatter.toDisplayFormat(credit.mvtDate!) : 'N/A'}'),
                            Text('N° Facture: ${credit.numFacturation}'),
                            Text('Tiers Payant: ${credit.tiersPayantLibelle}'),
                            Text(
                              'Montant: ${NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(credit.montant)}',
                              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueAccent),
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
}
