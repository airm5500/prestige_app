// lib/screens/ajustement_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/ajustement_detail_model.dart';
import '../utils/constants.dart';
import '../ui_helpers/base_screen_logic.dart';

class AjustementDetailScreen extends StatefulWidget {
  final String ajustementId;
  final String description;
  const AjustementDetailScreen({super.key, required this.ajustementId, required this.description});

  @override
  State<AjustementDetailScreen> createState() => _AjustementDetailScreenState();
}

class _AjustementDetailScreenState extends State<AjustementDetailScreen> with BaseScreenLogic<AjustementDetailScreen> {
  List<AjustementDetail> _details = [];
  double _totalPositif = 0;
  double _totalNegatif = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetails());
  }

  Future<void> _loadDetails() async {
    // CORRECTION: Ajout des paramètres de pagination
    final queryParams = {
      'ajustementId': widget.ajustementId,
      'page': '1',
      'start': '0',
      'limit': '100' // On charge jusqu'à 100 articles pour les détails
    };

    final data = await apiGet(
      AppConstants.ajustementItemsEndpoint,
      queryParams: queryParams,
    );

    if (mounted && data is Map<String, dynamic> && data['data'] is List) {
      final items = (data['data'] as List).map((item) => AjustementDetail.fromJson(item)).toList();
      double totalPos = 0;
      double totalNeg = 0;
      for (var item in items) {
        if (item.isPositive) {
          totalPos += item.valeurAjustement;
        } else {
          totalNeg += item.valeurAjustement;
        }
      }
      setState(() {
        _details = items;
        _totalPositif = totalPos;
        _totalNegatif = totalNeg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final totalAbsolu = _totalPositif + _totalNegatif.abs();
    final double pctPositif = totalAbsolu != 0 ? (_totalPositif / totalAbsolu) * 100 : 0;
    final double pctNegatif = totalAbsolu != 0 ? (_totalNegatif.abs() / totalAbsolu) * 100 : 0;

    return Scaffold(
      appBar: AppBar(title: Text(widget.description, overflow: TextOverflow.ellipsis, maxLines: 1)),
      body: RefreshIndicator(
        onRefresh: _loadDetails,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(errorMessage!, style: const TextStyle(color: Colors.red))))
            : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                          "Analyse de l'Ajustement",
                          style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)
                      ),
                      const Divider(height: 20),
                      _buildAnalyseRow("Valeur Ajoutée (Positif):", currencyFormat.format(_totalPositif), "(${pctPositif.toStringAsFixed(1)}%)", Colors.green.shade700),
                      const SizedBox(height: 8),
                      _buildAnalyseRow("Valeur Retirée (Négatif):", currencyFormat.format(_totalNegatif), "(${pctNegatif.toStringAsFixed(1)}%)", Colors.red.shade700),
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text("Produits Ajustés", style: Theme.of(context).textTheme.titleMedium),
            ),

            Expanded(
              child: _details.isEmpty
                  ? const Center(child: Text("Aucun produit détaillé pour cet ajustement."))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _details.length,
                itemBuilder: (context, index) {
                  final item = _details[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.strNAME, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Motif: ${item.motifAjustement}"),
                          Text("Valeur: ${currencyFormat.format(item.valeurAjustement)}"),
                        ],
                      ),
                      trailing: Text(
                        "${item.intNUMBER > 0 ? '+' : ''}${item.intNUMBER}",
                        style: TextStyle(
                            color: item.isPositive ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 18
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyseRow(String label, String value, String percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 8),
              Text(percentage, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
