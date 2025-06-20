// lib/screens/achats_fournisseurs_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For DateFormat
import '../services/api_service.dart';
import '../models/achat_fournisseur_model.dart';
import '../models/fournisseur_model.dart'; // For the filter
import '../utils/constants.dart';
import '../utils/date_formatter.dart'; // For date formatting

class AchatsFournisseursScreen extends StatefulWidget {
  const AchatsFournisseursScreen({super.key});

  @override
  State<AchatsFournisseursScreen> createState() => _AchatsFournisseursScreenState();
}

class _AchatsFournisseursScreenState extends State<AchatsFournisseursScreen> {
  late ApiService _apiService;
  // Future<List<AchatFournisseur>>? _achatsFuture; // Not using FutureBuilder directly for main list
  List<AchatFournisseur> _achats = [];
  List<AchatFournisseur> _filteredAchats = [];

  List<Fournisseur> _fournisseursList = [];
  Fournisseur? _selectedFournisseur;

  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context); // Initialize ApiService
    _fetchFournisseursForFilter(); // Fetch fournisseurs for the dropdown
    // Initial fetch is done after dates are confirmed or on button press
    _searchController.addListener(_filterAchatsLocally);
  }

  @override
  void dispose(){
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFournisseursForFilter() async {
    try {
      final data = await _apiService.get(AppConstants.fournisseursEndpoint);
      if (data is List) {
        if(mounted){
          setState(() {
            _fournisseursList = data.map((item) => Fournisseur.fromJson(item)).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement liste fournisseurs: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
      }
    }
  }

  Future<void> _loadAchats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _achats = []; // Clear previous data
      _filteredAchats = [];
    });

    Map<String, String> queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
    };

    // Note: API for achats-fournisseurs does not seem to take fournisseurId as per spec.
    // Filtering by fournisseur will be done locally.

    try {
      final data = await _apiService.get(AppConstants.achatsFournisseursEndpoint, queryParams: queryParams);
      if (data is List) {
        final allAchats = data.map((item) => AchatFournisseur.fromJson(item)).toList();
        if(mounted){
          setState(() {
            _achats = allAchats;
            _filterAchatsLocally();
          });
        }
      } else {
        throw Exception('Format de données incorrect.');
      }
    } catch (e) {
      if(mounted){
        setState(() {
          _errorMessage = 'Erreur: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    } finally {
      if(mounted){
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterAchatsLocally() {
    final query = _searchController.text.toLowerCase();
    if(mounted){
      setState(() {
        _filteredAchats = _achats.where((achat) {
          final matchesSearch = query.isEmpty ||
              achat.fournisseurLibelle.toLowerCase().contains(query) ||
              achat.numeroBL.toLowerCase().contains(query) ||
              achat.numeroCommade.toLowerCase().contains(query);

          final matchesFournisseur = _selectedFournisseur == null || achat.fournisseurId == _selectedFournisseur!.fournisseurId;

          return matchesSearch && matchesFournisseur;
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
            if (_endDate.isBefore(_startDate)) {
              _endDate = _startDate;
            }
          } else {
            _endDate = picked;
            if (_startDate.isAfter(_endDate)) {
              _startDate = _endDate;
            }
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

  Widget _buildFournisseurDropdown() {
    if (_fournisseursList.isEmpty && !_isLoading) { // Check isLoading to avoid showing this during initial load
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text("Chargement des fournisseurs pour le filtre...", style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }
    return DropdownButtonFormField<Fournisseur>(
      decoration: InputDecoration(
        labelText: 'Filtrer par Fournisseur (Optionnel)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      value: _selectedFournisseur,
      hint: const Text('Tous les fournisseurs'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<Fournisseur>(
          value: null,
          child: Text('Tous les fournisseurs'),
        ),
        ..._fournisseursList.map<DropdownMenuItem<Fournisseur>>((Fournisseur fournisseur) {
          return DropdownMenuItem<Fournisseur>(
            value: fournisseur,
            child: Text(fournisseur.fournisseurLibelle, overflow: TextOverflow.ellipsis),
          );
        }),
      ],
      onChanged: (Fournisseur? newValue) {
        if(mounted){
          setState(() {
            _selectedFournisseur = newValue;
            _filterAchatsLocally();
          });
        }
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achats Fournisseurs'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDatePicker(context),
                const SizedBox(height: 10),
                _buildFournisseurDropdown(),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search_sharp),
                  label: const Text('Afficher les Achats'),
                  onPressed: _isLoading ? null : _loadAchats,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher (par nom fourn., BL, commande)...',
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
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Expanded( // Make error message scrollable if it's long
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700], size: 50),
                        const SizedBox(height: 10),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.red[700], fontSize: 16)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                          onPressed: _loadAchats,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: _filteredAchats.isEmpty
                  ? Center(
                child: Text(_achats.isEmpty && !_isLoading ? 'Aucun achat trouvé pour la période sélectionnée.' : 'Aucun achat ne correspond à vos filtres.'),
              )
                  : RefreshIndicator(
                onRefresh: _loadAchats,
                child: ListView.builder(
                  itemCount: _filteredAchats.length,
                  itemBuilder: (context, index) {
                    final achat = _filteredAchats[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      elevation: 2.0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        title: Text(achat.fournisseurLibelle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date: ${achat.mvtDate != null ? DateFormatter.toDisplayFormat(achat.mvtDate!) : 'N/A'}'),
                            Text('N° BL: ${achat.numeroBL}'),
                            Text('N° Commande: ${achat.numeroCommade}'),
                            Text('Montant HT: ${NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(achat.montantHT)}'),
                            Text('Montant TTC: ${NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(achat.montantTTC)}'),
                            Text('Montant TVA: ${NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(achat.montantTVA)}'),
                          ],
                        ),
                        isThreeLine: true,
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
