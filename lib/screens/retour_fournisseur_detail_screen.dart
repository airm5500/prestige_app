// lib/screens/retour_fournisseur_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/retour_fournisseur_detail_model.dart';
import '../utils/constants.dart';
import '../ui_helpers/base_screen_logic.dart';

class RetourFournisseurDetailScreen extends StatefulWidget {
  final String retourId;

  const RetourFournisseurDetailScreen({super.key, required this.retourId});

  @override
  State<RetourFournisseurDetailScreen> createState() => _RetourFournisseurDetailScreenState();
}

class _RetourFournisseurDetailScreenState extends State<RetourFournisseurDetailScreen> with BaseScreenLogic<RetourFournisseurDetailScreen> {
  List<RetourFournisseurDetail> _details = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final queryParams = {
      'retourId': widget.retourId,
      'page': '1',
      'start': '0',
      'limit': '9999',
    };

    final data = await apiGet(AppConstants.retourFournisseurDetailEndpoint, queryParams: queryParams);

    if (mounted && data is Map && data['data'] is List) {
      setState(() {
        _details = (data['data'] as List).map((item) => RetourFournisseurDetail.fromJson(item)).toList();
        if (_details.isEmpty) {
          errorMessage = "Aucun détail trouvé pour ce retour.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Retour'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red)))
          : _details.isEmpty
          ? const Center(child: Text('Aucun détail à afficher.'))
          : ListView.builder(
        itemCount: _details.length,
        itemBuilder: (context, index) {
          final detail = _details[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detail.strNAME, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('CIP: ${detail.intCIP}'),
                  Text('Quantité retournée: ${detail.intNUMBERRETURN}'),
                  Text('Quantité répondue: ${detail.intNUMBERANSWER}'),
                  Text('Prix d\'achat: ${currencyFormat.format(detail.prixPaf)}'),
                  Text('Motif: ${detail.motif}'),
                  Text('Opérateur: ${detail.operateur}'),
                  Text('Date Opération: ${detail.dtCreated != null ? DateFormat('dd/MM/yyyy HH:mm').format(detail.dtCreated!) : 'N/A'}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}