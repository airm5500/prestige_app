// lib/screens/suggestion_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import '../models/suggestion_item_model.dart';
import '../models/suggestion_amount_model.dart';
import '../utils/constants.dart';
import '../ui_helpers/base_screen_logic.dart';

class SuggestionDetailScreen extends StatefulWidget {
  final Suggestion suggestion;
  const SuggestionDetailScreen({super.key, required this.suggestion});

  @override
  State<SuggestionDetailScreen> createState() => _SuggestionDetailScreenState();
}

class _SuggestionDetailScreenState extends State<SuggestionDetailScreen> with BaseScreenLogic<SuggestionDetailScreen> {
  List<SuggestionItem> _items = [];
  SuggestionAmount? _amount;
  bool _isPageLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isPageLoading = true);
    await _loadItems();
    await _loadAmount();
    if (mounted) {
      setState(() => _isPageLoading = false);
    }
  }

  Future<void> _loadItems() async {
    final data = await apiGet(AppConstants.suggestionListItemsEndpoint, queryParams: {'orderId': widget.suggestion.id, 'limit': '9999'});
    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _items = (data['data'] as List).map((item) => SuggestionItem.fromJson(item)).toList();
      });
    }
  }

  Future<void> _loadAmount() async {
    final data = await apiGet('${AppConstants.suggestionAmountEndpoint}/${widget.suggestion.id}');
    if (mounted && data is Map) {
      setState(() {
        _amount = SuggestionAmount.fromJson(data as Map<String, dynamic>);
      });
    }
  }

  Future<void> _updateQuantity(String itemId, String newQuantity) async {
    final int? qte = int.tryParse(newQuantity);
    if (qte == null) return;

    await apiPost(AppConstants.suggestionUpdateQteEndpoint, {'itemId': itemId, 'qte': qte});
    await _loadAmount();
  }

  Future<void> _deleteItem(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Voulez-vous vraiment supprimer cet article de la suggestion ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Oui, Supprimer')),
        ],
      ),
    );

    if (confirm == true) {
      await apiDelete('${AppConstants.suggestionDeleteItemEndpoint}/$itemId');
      await _loadDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: Text(widget.suggestion.grossiste)),
      body: _isPageLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('CIP: ${item.cip} | PA: ${currencyFormat.format(item.prixAchat)} | PV: ${currencyFormat.format(item.prixVente)}'),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: <TextSpan>[
                              // CORRECTION: Retrait du 'const'
                              TextSpan(text: 'Conso (M/M-1/M-2/M-3): ${item.consoM0}/${item.consoM1}/${item.consoM2}/${item.consoM3} | '),
                              const TextSpan(text: 'Moy: '),
                              TextSpan(
                                text: item.averageConsumption.toStringAsFixed(2),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: <TextSpan>[
                                  const TextSpan(text: 'Stock: '),
                                  TextSpan(
                                    text: '${item.stock}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 100,
                              child: TextFormField(
                                initialValue: item.quantiteSuggeree.toString(),
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onFieldSubmitted: (value) => _updateQuantity(item.itemId, value),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(item.itemId),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_amount != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
                  children: <TextSpan>[
                    const TextSpan(text: 'Montant Achat: '),
                    TextSpan(
                      text: NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0).format(_amount!.montantAchat),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}