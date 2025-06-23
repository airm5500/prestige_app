// lib/screens/valorisation_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/valorisation_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../utils/color_extensions.dart';
import '../ui_helpers/base_screen_logic.dart'; // Importer la logique centralisée

class ValorisationScreen extends StatefulWidget {
  const ValorisationScreen({super.key});

  @override
  State<ValorisationScreen> createState() => _ValorisationScreenState();
}

// On ajoute 'with BaseScreenLogic' pour hériter des fonctionnalités
class _ValorisationScreenState extends State<ValorisationScreen> with BaseScreenLogic<ValorisationScreen> {

  ValorisationStock? _valorisationData;
  DateTime _selectedDate = DateFormatter.getDefaultEndDate();

  // Les variables 'isLoading' et 'errorMessage' sont maintenant gérées par le mixin.

  Future<void> _loadValorisation() async {
    // On réinitialise les données avant chaque appel
    setState(() {
      _valorisationData = null;
    });

    final queryParams = {'dtJour': DateFormatter.toApiFormat(_selectedDate)};

    // Utilisation de la méthode centralisée 'apiGet'
    final data = await apiGet(AppConstants.valorisationEndpoint, queryParams: queryParams);

    // On traite uniquement le cas où l'appel a réussi et retourne des données
    if (mounted && data is Map<String, dynamic>) {
      setState(() {
        _valorisationData = ValorisationStock.fromJson(data);
      });
    }
    // La gestion du chargement et des erreurs est automatique !
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
                      onPressed: isLoading ? null : _loadValorisation, // Utilise isLoading du mixin
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Padding(
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
                          Colors.orangeAccent,
                        ),
                        const Divider(height: 20, thickness: 1),
                        _buildValorisationRow(
                          'Valeur de Vente:',
                          _valorisationData!.valeurVente,
                          Icons.sell_outlined,
                          Colors.greenAccent,
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
          Icon(icon, size: 28, color: baseIconColor.darker(0.25)),
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
