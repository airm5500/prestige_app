// lib/screens/suggestion_list_screen.dart

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // Nécessaire pour les permissions
import 'package:device_info_plus/device_info_plus.dart';     // Nécessaire pour la version Android
import 'package:prestige_app/models/suggestion_item_model.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import 'package:prestige_app/screens/suggestion_detail_screen.dart';
// import 'package:share_plus/share_plus.dart'; // Plus besoin de share_plus ici
import '../utils/constants.dart';
import '../ui_helpers/base_screen_logic.dart';
import '../utils/date_formatter.dart';

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
    final data = await apiGet(AppConstants.suggestionListEndpoint, queryParams: {'limit': '50'});
    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _suggestions = (data['data'] as List).map((item) => Suggestion.fromJson(item)).toList();
        if (_suggestions.isEmpty) {
          errorMessage = "Aucune suggestion de commande disponible.";
        }
      });
    }
  }

  Future<void> _openSuggestion(Suggestion suggestion) async {
    await apiGet('${AppConstants.suggestionSetPendingEndpoint}/${suggestion.id}');
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
      await apiDelete('${AppConstants.suggestionDeleteEndpoint}/$suggestionId');
      await _loadSuggestions();
    }
  }

  // MODIFICATION : Ajout du timestamp pour garantir un fichier unique à chaque export
  Future<void> _exportSuggestion(Suggestion suggestion) async {
    // 1. Récupération des données API
    final itemsData = await apiGet(AppConstants.suggestionListItemsEndpoint, queryParams: {'orderId': suggestion.id, 'limit': '9999'});

    if (mounted && itemsData is Map && itemsData['data'] is List) {
      final items = (itemsData['data'] as List).map((item) => SuggestionItem.fromJson(item)).toList();

      // 2. Création du CSV
      List<List<dynamic>> rows = [];
      rows.add(['cip', 'qte']);
      for (var item in items) {
        rows.add([item.cip, item.quantiteSuggeree]);
      }

      String csv = const ListToCsvConverter(fieldDelimiter: ';').convert(rows);

      // 3. Gestion des Permissions
      bool hasPermission = false;
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          hasPermission = true;
        } else {
          var status = await Permission.storage.request();
          hasPermission = status.isGranted;
        }
      } else {
        hasPermission = true;
      }

      if (hasPermission) {
        try {
          Directory? directory;
          if (Platform.isAndroid) {
            directory = Directory('/storage/emulated/0/Download');
            if (!await directory.exists()) {
              directory = await getExternalStorageDirectory();
            }
          } else {
            directory = await getApplicationDocumentsDirectory();
          }

          if (directory != null) {
            // Nettoyage du nom
            final safeName = suggestion.name.replaceAll(RegExp(r'[^\w\s\.-]'), '');

            // --- AJOUT CLÉ : On ajoute l'heure exacte au nom du fichier ---
            // Cela empêche l'écrasement et force l'apparition du fichier
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final fileName = 'suggestion_${safeName}_$timestamp.csv';
            // Exemple de résultat : suggestion_Commande1_1704895623.csv
            // -------------------------------------------------------------

            final path = '${directory.path}/$fileName';

            final file = File(path);
            // On force l'écriture immédiate sur le disque avec flush: true
            await file.writeAsString(csv, flush: true);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Fichier enregistré : $fileName'), // On affiche juste le nom pour que ce soit lisible
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission refusée'), backgroundColor: Colors.orange),
          );
        }
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
            onPressed: isLoading ? null : _loadSuggestions,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
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