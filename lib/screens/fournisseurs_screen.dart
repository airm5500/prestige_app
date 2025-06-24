// lib/screens/fournisseurs_screen.dart

import 'package:flutter/material.dart';
import '../models/fournisseur_model.dart';
import '../utils/constants.dart';
import '../ui_helpers/base_screen_logic.dart'; // Importer la logique centralisée

class FournisseursScreen extends StatefulWidget {
  const FournisseursScreen({super.key});

  @override
  State<FournisseursScreen> createState() => _FournisseursScreenState();
}

// On ajoute 'with BaseScreenLogic' pour hériter des fonctionnalités
class _FournisseursScreenState extends State<FournisseursScreen> with BaseScreenLogic<FournisseursScreen> {
  Future<List<Fournisseur>>? _fournisseursFuture;
  List<Fournisseur> _fournisseurs = [];
  List<Fournisseur> _filteredFournisseurs = [];
  final TextEditingController _searchController = TextEditingController();

  // Les variables 'isLoading', 'errorMessage' et 'apiService' sont maintenant gérées par le mixin.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _fournisseursFuture = _fetchFournisseurs();
        });
      }
    });
    _searchController.addListener(_filterFournisseurs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Fournisseur>> _fetchFournisseurs() async {
    // La gestion du loading et des erreurs est maintenant gérée par 'safeApiCall' dans le mixin,
    // mais pour un FutureBuilder, il est mieux de laisser l'erreur se propager.
    try {
      final data = await apiGet(AppConstants.fournisseursEndpoint);
      if (data is List) {
        final fournisseurs = data.map((item) => Fournisseur.fromJson(item)).toList();
        if (mounted) {
          setState(() {
            _fournisseurs = fournisseurs;
            _filteredFournisseurs = fournisseurs;
          });
        }
        return fournisseurs;
      } else {
        throw Exception('Format de données incorrect reçu du serveur.');
      }
    } catch (e) {
      // On relance l'erreur pour que le FutureBuilder puisse la capturer et afficher l'UI d'erreur.
      rethrow;
    }
  }

  void _filterFournisseurs() {
    final query = _searchController.text.toLowerCase();
    if (mounted) {
      setState(() {
        _filteredFournisseurs = _fournisseurs.where((fournisseur) {
          return fournisseur.fournisseurLibelle.toLowerCase().contains(query) ||
              (fournisseur.adresse?.toLowerCase().contains(query) ?? false) ||
              (fournisseur.telephone?.toLowerCase().contains(query) ?? false);
        }).toList();
      });
    }
  }

  Future<void> _refreshData() async {
    if (mounted) {
      setState(() {
        _fournisseursFuture = _fetchFournisseurs();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Fournisseurs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
            onPressed: _refreshData,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, adresse, téléphone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Fournisseur>>(
              future: _fournisseursFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[700], size: 50),
                          const SizedBox(height: 10),
                          Text(
                            'Erreur: ${snapshot.error.toString().replaceFirst("Exception: ", "")}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red[700], fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                            onPressed: _refreshData,
                          )
                        ],
                      ),
                    ),
                  );
                } else if (snapshot.hasData) {
                  if (_filteredFournisseurs.isEmpty && _searchController.text.isNotEmpty) {
                    return const Center(child: Text('Aucun fournisseur ne correspond à votre recherche.'));
                  } else if (_fournisseurs.isEmpty) {
                    return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 50, color: Colors.grey),
                            const SizedBox(height: 10),
                            const Text('Aucun fournisseur trouvé.'),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Rafraîchir'),
                              onPressed: _refreshData,
                            )
                          ],
                        )
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _refreshData,
                    child: ListView.builder(
                      itemCount: _filteredFournisseurs.length,
                      itemBuilder: (context, index) {
                        final fournisseur = _filteredFournisseurs[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          elevation: 2.5,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(50),
                              child: Text(
                                fournisseur.fournisseurLibelle.isNotEmpty ? fournisseur.fournisseurLibelle[0].toUpperCase() : 'F',
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(fournisseur.fournisseurLibelle, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (fournisseur.adresse != null && fournisseur.adresse!.isNotEmpty)
                                  Text('Adresse: ${fournisseur.adresse}'),
                                if (fournisseur.telephone != null && fournisseur.telephone!.isNotEmpty)
                                  Text('Tél: ${fournisseur.telephone}'),
                                if (fournisseur.groupeLibelle != null && fournisseur.groupeLibelle!.isNotEmpty)
                                  Text('Groupe: ${fournisseur.groupeLibelle}'),
                              ],
                            ),
                            isThreeLine: (fournisseur.adresse?.isNotEmpty ?? false) || (fournisseur.telephone?.isNotEmpty ?? false) || (fournisseur.groupeLibelle?.isNotEmpty ?? false),
                          ),
                        );
                      },
                    ),
                  );
                } else {
                  return const Center(child: Text('Chargement des fournisseurs...'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
