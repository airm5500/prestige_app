// lib/screens/achats_fournisseurs_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/achat_fournisseur_model.dart';
import '../models/fournisseur_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class AchatsFournisseursScreen extends StatefulWidget {
  const AchatsFournisseursScreen({super.key});

  @override
  State<AchatsFournisseursScreen> createState() => _AchatsFournisseursScreenState();
}

class _AchatsFournisseursScreenState extends State<AchatsFournisseursScreen> with BaseScreenLogic<AchatsFournisseursScreen> {

  List<AchatFournisseur> _achats = [];
  List<AchatFournisseur> _filteredAchats = [];
  List<Fournisseur> _fournisseursList = [];
  Fournisseur? _selectedFournisseur;
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  final TextEditingController _searchController = TextEditingController();
  int? _selectedMonth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFournisseursForFilter();
    });
    _searchController.addListener(_filterAchatsLocally);
  }

  @override
  void dispose(){
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFournisseursForFilter() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final data = await apiService.get(
        context,
        AppConstants.fournisseursEndpoint,
        onSessionInvalid: () => authProvider.forceLogout(),
      );
      if (mounted && data is List) {
        setState(() {
          _fournisseursList = data.map((item) => Fournisseur.fromJson(item)).toList();
        });
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
    setState(() {
      _achats = [];
      _filteredAchats = [];
    });

    Map<String, String> queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
    };

    final data = await apiGet(AppConstants.achatsFournisseursEndpoint, queryParams: queryParams);

    if (mounted && data is List) {
      final allAchats = data.map((item) => AchatFournisseur.fromJson(item)).toList();
      setState(() {
        _achats = allAchats;
        _filterAchatsLocally();
      });
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
            if (_endDate.isBefore(_startDate)) _endDate = _startDate;
          } else {
            _endDate = picked;
            if (_startDate.isAfter(_endDate)) _startDate = _endDate;
          }
          _selectedMonth = null;
        });
      }
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
          _loadAchats();
        }
      },
    );
  }

  Widget _buildFournisseurDropdown() {
    if (_fournisseursList.isEmpty && !isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text("Chargement des fournisseurs...", style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }
    return DropdownButtonFormField<Fournisseur>(
      decoration: const InputDecoration(
        labelText: 'Fournisseur',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      value: _selectedFournisseur,
      hint: const Text('Tous'),
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
        }).toList(),
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

  void _showRecapDialog() {
    if (_achats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez d\'abord afficher les achats pour voir le récapitulatif.')),
      );
      return;
    }

    // MODIFICATION: Utilisation d'un formatteur avec point comme séparateur
    final currencyFormatWithDots = NumberFormat.currency(locale: 'de_DE', symbol: 'FCFA', decimalDigits: 0);
    String title;
    Widget content;

    if (_selectedFournisseur != null) {
      title = 'Récapitulatif pour ${_selectedFournisseur!.fournisseurLibelle}';

      double totalHT = 0;
      double totalTVA = 0;
      double totalTTC = 0;

      final supplierPurchases = _achats.where((a) => a.fournisseurId == _selectedFournisseur!.fournisseurId);

      for (var achat in supplierPurchases) {
        totalHT += achat.montantHT;
        totalTVA += achat.montantTVA;
        totalTTC += achat.montantTTC;
      }

      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total HT: ${currencyFormatWithDots.format(totalHT)}'),
          Text('Total TVA: ${currencyFormatWithDots.format(totalTVA)}'),
          Text('Total TTC: ${currencyFormatWithDots.format(totalTTC)}'),
        ],
      );

    } else {
      title = 'Récapitulatif par Fournisseur';
      final Map<String, Map<String, double>> recapMap = {};

      for (var achat in _achats) {
        recapMap.putIfAbsent(achat.fournisseurLibelle, () => {'ht': 0, 'tva': 0, 'ttc': 0});
        recapMap[achat.fournisseurLibelle]!['ht'] = recapMap[achat.fournisseurLibelle]!['ht']! + achat.montantHT;
        recapMap[achat.fournisseurLibelle]!['tva'] = recapMap[achat.fournisseurLibelle]!['tva']! + achat.montantTVA;
        recapMap[achat.fournisseurLibelle]!['ttc'] = recapMap[achat.fournisseurLibelle]!['ttc']! + achat.montantTTC;
      }

      content = SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: recapMap.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total HT: ${currencyFormatWithDots.format(entry.value['ht'])}'),
                          Text('Total TVA: ${currencyFormatWithDots.format(entry.value['tva'])}'),
                          Text('Total TTC: ${currencyFormatWithDots.format(entry.value['ttc'])}'),
                        ],
                      ),
                    ),
                    if(entry.key != recapMap.keys.last) const Divider(),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // MODIFICATION: Définition du nouveau formatteur
    final currencyFormatWithDots = NumberFormat.currency(locale: 'de_DE', symbol: 'FCFA', decimalDigits: 0);

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildDatePicker(context)),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: _buildMonthPicker()),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildFournisseurDropdown(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _showRecapDialog,
                        child: const Text('Récap Achat', textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search_sharp),
                  label: const Text('Afficher les Achats'),
                  onPressed: isLoading ? null : _loadAchats,
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
                child: Text(_achats.isEmpty && !isLoading ? 'Aucun achat trouvé pour la période sélectionnée.' : 'Aucun achat ne correspond à vos filtres.'),
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
                            // MODIFICATION: Utilisation du nouveau formatteur
                            Text('Montant HT: ${currencyFormatWithDots.format(achat.montantHT)}'),
                            Text('Montant TTC: ${currencyFormatWithDots.format(achat.montantTTC)}'),
                            Text('Montant TVA: ${currencyFormatWithDots.format(achat.montantTVA)}'),
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