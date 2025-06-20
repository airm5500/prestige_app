// lib/screens/fiche_article_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Import pour la police
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../models/produit_model.dart';
import '../utils/constants.dart';

class FicheArticleScreen extends StatefulWidget {
  const FicheArticleScreen({super.key});

  @override
  State<FicheArticleScreen> createState() => _FicheArticleScreenState();
}

class _FicheArticleScreenState extends State<FicheArticleScreen> {
  late ApiService _apiService;
  final TextEditingController _searchController = TextEditingController();
  List<Produit> _produitsTrouves = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _lastSearchTerm = "";
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context);
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
      if (searchTerm.length >= 3) {
        if (searchTerm != _lastSearchTerm) {
          _rechercherProduits();
        }
      } else {
        if (mounted) {
          setState(() {
            _produitsTrouves = [];
            _errorMessage = null;
            _lastSearchTerm = "";
          });
        }
      }
    });
  }

  Future<void> _rechercherProduits() async {
    final nomPdt = _searchController.text.trim();

    if (nomPdt.isEmpty) {
      if (mounted) {
        setState(() {
          _produitsTrouves = [];
          _lastSearchTerm = "";
          _errorMessage = "Veuillez entrer un nom de produit.";
        });
      }
      return;
    }

    _lastSearchTerm = nomPdt;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _apiService.get(
        AppConstants.checkProduitEndpoint,
        queryParams: {'nompdt': nomPdt},
      );

      if (!mounted) return;

      if (data is List) {
        setState(() {
          _produitsTrouves = data.map((item) => Produit.fromJson(item)).toList();
          if (_produitsTrouves.isEmpty) {
            _errorMessage = "Aucun produit trouvé pour '$nomPdt'.";
          }
        });
      } else {
        throw Exception('Format de données incorrect reçu du serveur.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _produitsTrouves = [];
          _errorMessage = 'Erreur: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _afficherDetailsProduit(BuildContext context, Produit produit) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
          actionsPadding: const EdgeInsets.fromLTRB(0, 10, 24, 16),
          title: Text(
            produit.designation.toUpperCase(),
            style: GoogleFonts.lato(
              color: theme.colorScheme.secondary, // Utilise la couleur secondaire du thème
              fontWeight: FontWeight.w900, // Très gras pour le titre
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Divider(),
                _buildDetailRow('Code CIP:', produit.familleCip),
                _buildDetailRow('Désignation:', produit.familleLibelle),
                _buildDetailRow('Stock:', produit.stockActuel.toString()),
                _buildDetailRow('Prix d\'achat:', currencyFormat.format(produit.pachat)),
                _buildDetailRow('Prix de vente:', currencyFormat.format(produit.pvente)),
                _buildDetailRow('Emplacement:', produit.emplacement ?? 'N/A'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Fermer', style: TextStyle(fontSize: 16)),
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
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.lato(fontSize: 15, color: Colors.black87),
          children: <TextSpan>[
            TextSpan(
                text: '$label ',
                // Couleur rouge/orangé comme sur la maquette
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
   // final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche Article'),
        // Le thème global dans main.dart devrait déjà styliser l'app bar
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un produit...',
                      labelText: 'Rechercher Produit',
                      // Le style vient du thème dans main.dart
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                          : null,
                    ),
                    onSubmitted: (_) => _rechercherProduits(),
                  ),
                ),
                const SizedBox(width: 12),
                // Le bouton utilise maintenant le thème global défini dans main.dart
                ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text('Chercher'),
                  onPressed: _isLoading ? null : _rechercherProduits,
                ),
              ],
            ),
          ),
          // Affichage des résultats
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.red.shade700),
                  ),
                ),
              ),
            )
          else if (_produitsTrouves.isNotEmpty)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _produitsTrouves.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 0), // Pas de séparation visible
                  itemBuilder: (context, index) {
                    final produit = _produitsTrouves[index];
                    return Card(
                      // Le style de la carte vient du thème (main.dart)
                      elevation: 1, // Légère élévation pour chaque carte
                      child: ListTile(
                        title: Text(produit.designation, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Prix: ${NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0).format(produit.prixVente)} FCFA - Stock: ${produit.stockActuel}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 18),
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
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'Entrez au moins 3 caractères pour rechercher un produit.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
