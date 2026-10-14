// lib/screens/retour_fournisseur_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/retour_fournisseur_detail_model.dart';
import '../donnees/retours_fournisseurs_donnees.dart';
import '../ui_helpers/base_screen_logic.dart';
import '../widgets/erreurs_chargement.dart';

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
    reessai = _loadDetails; // « Réessayer » relance ce chargement
    // Lecture partagée avec la nouvelle interface (lib/donnees/retours_fournisseurs_donnees.dart).
    final d = await apiDonnees((deco) => RetoursFournisseurs.details(context, widget.retourId, onSessionInvalid: deco));

    if (mounted && d != null) {
      setState(() {
        _details = d;
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
          : loadError != null
          ? LoadErrorView(message: loadError!.message, onRetry: () => reessai?.call())
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