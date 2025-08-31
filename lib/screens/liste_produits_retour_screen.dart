// lib/screens/liste_produits_retour_screen.dart

import 'package:flutter/material.dart'; // CORRECTION: Le point a été remplacé par deux-points
import 'package:intl/intl.dart';
import 'package:prestige_app/models/avoir_fournisseur_produit_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class ListeProduitsRetourScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;

  const ListeProduitsRetourScreen({super.key, required this.startDate, required this.endDate});

  @override
  State<ListeProduitsRetourScreen> createState() => _ListeProduitsRetourScreenState();
}

class _ListeProduitsRetourScreenState extends State<ListeProduitsRetourScreen> with BaseScreenLogic<ListeProduitsRetourScreen> {
  List<AvoirFournisseurProduit> _produits = [];

  @override
  void initState() {
    super.initState();
    _loadProduits();
  }

  Future<void> _loadProduits() async {
    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(widget.startDate),
      'dtEnd': DateFormatter.toApiFormat(widget.endDate),
    };

    final data = await apiGet(AppConstants.avoirsFournisseursEndpoint, queryParams: queryParams);

    if (mounted && data is List) {
      setState(() {
        _produits = data.map((item) => AvoirFournisseurProduit.fromJson(item)).toList();
        if (_produits.isEmpty) {
          errorMessage = "Aucun produit trouvé pour la période sélectionnée.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produits Retournés'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
          : _produits.isEmpty
          ? const Center(child: Text('Aucun produit retourné sur cette période.'))
          : ListView.builder(
        itemCount: _produits.length,
        itemBuilder: (context, index) {
          final produit = _produits[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(produit.libelle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('CIP: ${produit.cip}'),
                  Text('Quantité: ${produit.quantite}'),
                  Text('Prix d\'achat: ${currencyFormat.format(produit.prixAchatHt)}'),
                  Text('Motif: ${produit.natureReclamation}'),
                  Text('N° BL: ${produit.numeroBl}'),
                  Text('Date Avoir: ${produit.dateAvoir != null ? DateFormat('dd/MM/yyyy HH:mm').format(produit.dateAvoir!) : 'N/A'}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}