// lib/screens/personalize_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_settings_provider.dart';

class PersonalizeHomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allItems;

  const PersonalizeHomeScreen({super.key, required this.allItems});

  @override
  State<PersonalizeHomeScreen> createState() => _PersonalizeHomeScreenState();
}

class _PersonalizeHomeScreenState extends State<PersonalizeHomeScreen> {
  late List<Map<String, dynamic>> _orderedItems;

  @override
  void initState() {
    super.initState();
    // CORRECTION: On trie la liste complète dès l'initialisation
    final homeSettings = Provider.of<HomeSettingsProvider>(context, listen: false);
    _orderedItems = List.from(widget.allItems);

    if (homeSettings.featureOrder.isNotEmpty) {
      final orderMap = { for (var i = 0; i < homeSettings.featureOrder.length; i++) homeSettings.featureOrder[i] : i };
      _orderedItems.sort((a, b) {
        final indexA = orderMap[a['title']] ?? widget.allItems.length;
        final indexB = orderMap[b['title']] ?? widget.allItems.length;
        return indexA.compareTo(indexB);
      });
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _orderedItems.removeAt(oldIndex);
      _orderedItems.insert(newIndex, item);
    });
  }

  Future<void> _saveOrder() async {
    final newOrderIds = _orderedItems.map((item) => item['title'] as String).toList();
    await Provider.of<HomeSettingsProvider>(context, listen: false).saveFeatureOrder(newOrderIds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration sauvegardée !'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeSettings = Provider.of<HomeSettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personnaliser l\'accueil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Enregistrer',
            onPressed: _saveOrder,
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _orderedItems.length,
        itemBuilder: (context, index) {
          final item = _orderedItems[index];
          final title = item['title'] as String;
          final isEnabled = !homeSettings.disabledFeatures.contains(title);

          return Card(
            key: ValueKey(title),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: Icon(item['icon'], color: item['color']),
              title: Text(title),
              trailing: Switch(
                value: isEnabled,
                onChanged: (bool value) {
                  homeSettings.toggleFeature(title, value);
                },
              ),
            ),
          );
        },
        onReorder: _onReorder,
      ),
    );
  }
}