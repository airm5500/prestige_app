// lib/screens/retours_fournisseurs_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/fournisseur_model.dart';
import 'package:prestige_app/screens/liste_produits_retour_screen.dart';
import 'package:prestige_app/screens/retour_fournisseur_detail_screen.dart';
import '../models/retour_fournisseur_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class RetoursFournisseursScreen extends StatefulWidget {
  const RetoursFournisseursScreen({super.key});

  @override
  State<RetoursFournisseursScreen> createState() => _RetoursFournisseursScreenState();
}

class _RetoursFournisseursScreenState extends State<RetoursFournisseursScreen> with BaseScreenLogic<RetoursFournisseursScreen> {
  List<RetourFournisseur> _retours = [];
  List<Fournisseur> _fournisseurs = [];
  Fournisseur? _selectedFournisseur;
  String _filtre = 'TOUT'; // MODIFICATION: Valeur par défaut
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGrossistes();
  }

  Future<void> _fetchGrossistes() async {
    final data = await apiGet(AppConstants.grossistesEndpoint);
    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _fournisseurs = (data['data'] as List).map((item) => Fournisseur.fromJson(item)).toList();
      });
    }
  }

  Future<void> _loadRetours() async {
    final queryParams = {
      'query': _searchController.text,
      'fourId': _selectedFournisseur?.fournisseurId ?? '',
      'filtre': _filtre == 'TOUT' ? '' : _filtre, // MODIFICATION: Gère le filtre "TOUT"
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'page': '1',
      'start': '0',
      'limit': '9999',
    };

    final data = await apiGet(AppConstants.retoursFournisseursEndpoint, queryParams: queryParams);

    if (mounted && data is Map && data['results'] is List) {
      setState(() {
        _retours = (data['results'] as List).map((item) => RetourFournisseur.fromJson(item)).toList();
        if (_retours.isEmpty) {
          errorMessage = "Aucun retour fournisseur trouvé pour les critères sélectionnés.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retours Fournisseurs'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDatePicker(context),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Fournisseur>(
                        decoration: const InputDecoration(labelText: 'Fournisseur'),
                        value: _selectedFournisseur,
                        items: [
                          const DropdownMenuItem<Fournisseur>(
                            value: null,
                            child: Text('Tous'),
                          ),
                          ..._fournisseurs.map((fournisseur) {
                            return DropdownMenuItem<Fournisseur>(
                              value: fournisseur,
                              child: Text(fournisseur.fournisseurLibelle),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFournisseur = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Filtre'),
                        value: _filtre,
                        items: const [
                          // MODIFICATION: Ajout de l'option "Tout"
                          DropdownMenuItem(value: 'TOUT', child: Text('Tout')),
                          DropdownMenuItem(value: 'WITH', child: Text('Avec réponse')),
                          DropdownMenuItem(value: 'WITHOUT', child: Text('Sans réponse')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filtre = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Rechercher'),
                        onPressed: isLoading ? null : _loadRetours,
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // AJOUT: Bouton "Liste Produits"
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Liste Produits'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ListeProduitsRetourScreen(
                                startDate: _startDate,
                                endDate: _endDate,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(45),
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
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
          else if (_retours.isEmpty)
              const Expanded(child: Center(child: Text('Aucun retour à afficher.')))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _retours.length,
                  itemBuilder: (context, index) {
                    final retour = _retours[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      child: ListTile(
                        title: Text(retour.strGrossisteLibelle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Réf. Retour: ${retour.strRefRetourFrs}'),
                            // MODIFICATION: Style des détails
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: <TextSpan>[
                                  const TextSpan(text: 'Réf. Livraison: '),
                                  TextSpan(text: retour.strRefLivraison, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: <TextSpan>[
                                  const TextSpan(text: 'Date: '),
                                  TextSpan(
                                    text: retour.dtCreated != null ? DateFormatter.toDisplayFormat(retour.dtCreated!) : 'N/A',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: <TextSpan>[
                                  const TextSpan(text: 'Montant: '),
                                  TextSpan(
                                    text: currencyFormat.format(retour.montantRetour),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          child: const Text('Détails'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RetourFournisseurDetailScreen(retourId: retour.lgRetourFrsId),
                              ),
                            );
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
}