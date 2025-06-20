// lib/screens/valorisation_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For NumberFormat
import '../services/api_service.dart';
import '../models/valorisation_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../utils/color_extensions.dart'; // Import the color extension

class ValorisationScreen extends StatefulWidget {
  const ValorisationScreen({super.key});

  @override
  State<ValorisationScreen> createState() => _ValorisationScreenState();
}

class _ValorisationScreenState extends State<ValorisationScreen> {
  late ApiService _apiService;
  ValorisationStock? _valorisationData;
  DateTime _selectedDate = DateFormatter.getDefaultEndDate(); // dtJour is a single date

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context);
  }

  Future<void> _loadValorisation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _valorisationData = null;
    });

    final queryParams = {
      'dtJour': DateFormatter.toApiFormat(_selectedDate),
    };

    try {
      final data = await _apiService.get(AppConstants.valorisationEndpoint, queryParams: queryParams);
      if (data is Map<String, dynamic>) {
        if(mounted){
          setState(() {
            _valorisationData = ValorisationStock.fromJson(data);
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && picked != _selectedDate) {
      if(mounted){
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Valorisation du Stock'),
      ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Date de valorisation:', style: TextStyle(fontSize: 16)),
                        TextButton(
                          onPressed: () => _selectDate(context),
                          child: Text(
                            DateFormatter.toDisplayFormat(_selectedDate),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.primaryColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.calculate_outlined),
                      label: const Text('Afficher la Valorisation'),
                      onPressed: _isLoading ? null : _loadValorisation,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Padding(
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
                        onPressed: _loadValorisation,
                      )
                    ],
                  ),
                ),
              )
            else if (_valorisationData != null)
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Valorisation au ${DateFormatter.toDisplayFormat(_selectedDate)}',
                          style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColorDark),
                        ),
                        const SizedBox(height: 15),
                        _buildValorisationRow(
                          'Valeur d\'Achat:',
                          _valorisationData!.valeurAchat,
                          Icons.shopping_basket_outlined,
                          Colors.orangeAccent, // Base color
                        ),
                        const Divider(height: 20, thickness: 1),
                        _buildValorisationRow(
                          'Valeur de Vente:',
                          _valorisationData!.valeurVente,
                          Icons.sell_outlined,
                          Colors.greenAccent, // Base color
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Center(child: Padding(
                  padding: EdgeInsets.only(top: 30.0),
                  child: Text('Veuillez sélectionner une date et afficher la valorisation.', textAlign: TextAlign.center,),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildValorisationRow(String label, double value, IconData icon, Color baseIconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          // Using the .darker() extension method
          Icon(icon, size: 28, color: baseIconColor.darker(0.25)), // Adjusted amount for visibility
          const SizedBox(width: 15),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          ),
          Text(
            NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(value),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
