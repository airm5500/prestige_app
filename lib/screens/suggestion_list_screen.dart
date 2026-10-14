// lib/screens/suggestion_list_screen.dart

import 'package:flutter/material.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import 'package:prestige_app/screens/suggestion_detail_screen.dart';
import '../donnees/suggestions_donnees.dart';
import '../ui_helpers/base_screen_logic.dart';
import '../utils/date_formatter.dart';
import '../widgets/erreurs_chargement.dart';

class SuggestionListScreen extends StatefulWidget {
  const SuggestionListScreen({super.key});

  @override
  State<SuggestionListScreen> createState() => _SuggestionListScreenState();
}

class _SuggestionListScreenState extends State<SuggestionListScreen> with BaseScreenLogic<SuggestionListScreen> {
  List<Suggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    reessai = _loadSuggestions; // « Réessayer » relance ce chargement
    // Lecture partagée avec la nouvelle interface (lib/donnees/suggestions_donnees.dart).
    final liste = await apiDonnees((deco) => Suggestions.liste(context, onSessionInvalid: deco));
    if (mounted && liste != null) {
      setState(() {
        _suggestions = liste;
        if (_suggestions.isEmpty) {
          errorMessage = "Aucune suggestion de commande disponible.";
        }
      });
    }
  }

  Future<void> _openSuggestion(Suggestion suggestion) async {
    await apiDonnees((deco) => Suggestions.ouvrir(context, suggestion.id, onSessionInvalid: deco));
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => SuggestionDetailScreen(suggestion: suggestion)),
      ).then((_) => _loadSuggestions());
    }
  }

  Future<void> _deleteSuggestion(String suggestionId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Voulez-vous vraiment supprimer cette suggestion ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Oui, Supprimer')),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final r = await apiDonnees((deco) => Suggestions.supprimer(context, suggestionId, onSessionInvalid: deco));
      if (!mounted) return;
      if (r == null) {
        // Échec : la suggestion n'est PAS supprimée, on le dit (au lieu de recharger en silence).
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Suggestion non supprimée : ${errorMessage ?? 'erreur inconnue'}'),
        ));
        return;
      }
      await _loadSuggestions();
    }
  }

  // Ajout du timestamp pour garantir un fichier unique à chaque export (lib/donnees/suggestions_donnees.dart).
  Future<void> _exportSuggestion(Suggestion suggestion) async {
    // 1. Récupération des données API
    final items = await apiDonnees((deco) => Suggestions.lignes(context, suggestion.id, onSessionInvalid: deco));
    if (!mounted || items == null) return;
    try {
      // 2. Création du CSV, 3. permissions et écriture
      final fileName = await Suggestions.enregistrerCsv(Suggestions.nomFichier(suggestion), Suggestions.csv(items));
      if (!mounted) return;
      if (fileName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission refusée'), backgroundColor: Colors.orange),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fichier enregistré : $fileName'), // On affiche juste le nom pour que ce soit lisible
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggestions de Commande'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: isLoading ? null : _loadSuggestions,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
          ? LoadErrorView(message: loadError!.message, onRetry: () => reessai?.call())
          : errorMessage != null
          ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          final isPending = suggestion.status == 'pending';
          return Card(
            color: isPending ? Colors.green.shade50 : null,
            child: ListTile(
              title: Text(suggestion.grossiste, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${suggestion.name} - ${suggestion.dtCreated != null ? DateFormatter.toDisplayFormat(suggestion.dtCreated!) : ''}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.folder_open_outlined),
                    color: Theme.of(context).primaryColor,
                    tooltip: 'Ouvrir la suggestion',
                    onPressed: () => _openSuggestion(suggestion),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined),
                    tooltip: 'Télécharger en CSV', // Tooltip mis à jour
                    onPressed: () => _exportSuggestion(suggestion),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                    tooltip: 'Supprimer',
                    onPressed: () => _deleteSuggestion(suggestion.id),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}