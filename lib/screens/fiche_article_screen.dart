// lib/screens/fiche_article_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/produit_model.dart'; // Utilise le modèle Produit
import '../utils/constants.dart';
import '../ui_helpers/base_screen_logic.dart'; // Importer la logique centralisée

class FicheArticleScreen extends StatefulWidget {
  const FicheArticleScreen({super.key});

  @override
  State<FicheArticleScreen> createState() => _FicheArticleScreenState();
}

class _FicheArticleScreenState extends State<FicheArticleScreen> with BaseScreenLogic<FicheArticleScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Produit> _results = [];
  String _lastSearchTerm = "";
  Timer? _debounce;

  // Les variables 'isLoading' et 'errorMessage' sont maintenant gérées par le mixin.

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final searchTerm = _searchController.text.trim();
      // Pour cet écran, la recherche se déclenche à partir de 3 caractères
      if (searchTerm.length >= 3) {
        if (searchTerm != _lastSearchTerm) {
          _rechercherProduits();
        }
      } else {
        if (mounted) {
          setState(() {
            _results = [];
            errorMessage = null;
            _lastSearchTerm = "";
          });
        }
      }
    });
  }

  Future<void> _rechercherProduits() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) return;

    _lastSearchTerm = searchTerm;

    // Utilisation de la méthode centralisée 'apiGet' du mixin
    final data = await apiGet(
        AppConstants.checkProduitEndpoint, // Utilise le bon endpoint
        queryParams: {'nompdt': searchTerm}
    );

    if (mounted && data is List) {
      setState(() {
        _results = data.map((item) => Produit.fromJson(item)).toList();
        if (_results.isEmpty) {
          errorMessage = "Aucun produit trouvé pour '$searchTerm'.";
        }
      });
    }
  }

  void _afficherDetailsProduit(BuildContext context, Produit produit) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Text("Détails de l'Article", style: GoogleFonts.lato(color: theme.primaryColor, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow('Code CIP', produit.familleCip),
                _buildDetailRow('Désignation', produit.familleLibelle),
                _buildDetailRow('Stock', produit.stock.toString()),
                _buildDetailRow('Prix d\'achat', currencyFormat.format(produit.pachat)),
                _buildDetailRow('Prix de vente', currencyFormat.format(produit.pvente)),
                _buildDetailRow('Emplacement', produit.emplacement ?? 'N/A'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Fermer'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.lato(fontSize: 15, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche Article'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                labelText: 'Rechercher Produit',
                suffixIcon: isLoading
                    ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                    : (_searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                    : null),
              ),
              onSubmitted: (_) => _rechercherProduits(),
            ),
          ),
          if (errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 16), textAlign: TextAlign.center),
                ),
              ),
            )
          else if (_results.isNotEmpty)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _results.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final produit = _results[index];
                  return Card(
                    elevation: 2,
                    shadowColor: Colors.black.withAlpha(26),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      title: Text(produit.designation, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Prix: ${currencyFormat.format(produit.prixVente)} - Stock: ${produit.stockActuel}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, color: theme.primaryColor.withAlpha(150), size: 18),
                      onTap: () => _afficherDetailsProduit(context, produit),
                    ),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    isLoading ? 'Recherche en cours...' : 'Entrez au moins 3 caractères pour rechercher.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
