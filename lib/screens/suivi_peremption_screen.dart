import 'package:flutter/material.dart';

import 'package:prestige_app/models/suivi_peremption_model.dart';
import 'package:prestige_app/services/api_service.dart';
import '../donnees/peremption_donnees.dart';
import '../services/journal_app.dart';
import '../widgets/erreurs_chargement.dart';
import '../utils/saisie.dart';

class SuiviPeremptionScreen extends StatefulWidget {
  const SuiviPeremptionScreen({Key? key}) : super(key: key);

  /// Lignes demandées par page (mêmes paramètres que le comptage à la demande de l'accueil A).
  static const taillePage = SuiviPeremption.taillePage;

  @override
  _SuiviPeremptionScreenState createState() => _SuiviPeremptionScreenState();
}

class _SuiviPeremptionScreenState extends State<SuiviPeremptionScreen> {
  // Contrôleurs
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _moisController = TextEditingController(); // Pour filtrer par échéance (ex: 3 mois)

  // Données
  SuiviPeremptionResponse? _dataResponse;
  bool _isLoading = false;

  /// Échec de chargement (≠ « Aucun produit périmé… ») : affiché avec « Réessayer ».
  String? _erreur;

  // Pagination
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _dataResponse != null && _dataResponse!.data.length < _dataResponse!.total) {
          _fetchData(loadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _moisController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool loadMore = false}) async {
    if (!SuiviPeremption.moisValide(_moisController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre de mois invalide (0 à ${Saisie.maxMois}).')));
      return;
    }

    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _erreur = null;
      });
      _currentPage = 1;
    } else {
      _currentPage++;
    }

    try {
      // Mêmes paramètres et même fusion que le nouvel écran (lib/donnees/peremption_donnees.dart).
      final result = await SuiviPeremption.page(context, recherche: _searchController.text, mois: _moisController.text, page: _currentPage);

      if (mounted) {
        setState(() {
          if (loadMore) {
            _dataResponse = SuiviPeremption.fusionner(_dataResponse, result);
          } else {
            _dataResponse = result;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      JournalApp.debug('Suivi péremption : ${e.runtimeType}');
      if (mounted) {
        final message = e is ApiLoadException ? e.message : 'Erreur: $e';
        setState(() {
          _isLoading = false;
          if (loadMore) {
            _currentPage--; // la page n'a pas été chargée : elle sera redemandée
          } else {
            _dataResponse = null;
            _erreur = message;
          }
        });
        if (loadMore) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  // --- GENERATION PDF ---
  Future<void> _generatePdf() async {
    if (_dataResponse == null || _dataResponse!.data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune donnée à imprimer")));
      return;
    }

    await SuiviPeremption.imprimerPdf(_dataResponse!);
  }

  // --- POPUP DETAIL ---
  void _showDetailPopup(PeremptionItem item) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.libelle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow("Code CIP", item.codeCip),
                _detailRow("Lot", item.numLot),
                _detailRow("Date Péremption", item.datePerement, isBold: true, color: Colors.red),
                const Divider(),
                _detailRow("Quantité", "${item.quantiteLot.toInt()}", isBold: true),
                _detailRow("Statut", item.statut, color: Colors.orange[800]),
                const Divider(),
                _detailRow("Prix Achat", "${item.valeurAchat.toInt()}"),
                _detailRow("Prix Vente", "${item.valeurVente.toInt()}"),
                const Divider(),
                _detailRow("Rayon", item.libelleRayon),
                _detailRow("Famille", item.libelleFamille),
                _detailRow("Grossiste", item.libelleGrossiste),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer"),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("$label :", style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meta = _dataResponse?.metaData;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Suivi Péremption"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Imprimer PDF",
            onPressed: _generatePdf,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Zone de Filtres
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    inputFormatters: Saisie.rechercheFormatters, // longueur max, sans caractères de contrôle
                    decoration: const InputDecoration(
                      labelText: "Recherche...",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onSubmitted: (_) => _fetchData(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _moisController,
                    keyboardType: TextInputType.number,
                    inputFormatters: Saisie.entierFormatters(3), // 0 à 120 mois
                    decoration: const InputDecoration(
                      labelText: "Mois",
                      suffixText: "mois",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onSubmitted: (_) => _fetchData(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  tooltip: 'Actualiser',
                  onPressed: () => _fetchData(),
                )
              ],
            ),
          ),

          // 2. Résumé (MetaData)
          if (meta != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem("Qté Totale", "${meta.totalQuantiteLot.toInt()}"),
                  _buildSummaryItem("Val. Achat", "${meta.totalValeurAchat.toInt()}"),
                  _buildSummaryItem("Val. Vente", "${meta.totalValeurVente.toInt()}"),
                ],
              ),
            ),

          // 3. Liste
          Expanded(
            child: _isLoading && _dataResponse == null
                ? const Center(child: CircularProgressIndicator())
                : _erreur != null
                ? LoadErrorView(message: _erreur!, onRetry: () => _fetchData())
                : _dataResponse?.data.isEmpty ?? true
                ? const Center(child: Text("Aucun produit périmé ou proche péremption trouvé."))
                : ListView.separated(
              controller: _scrollController,
              itemCount: (_dataResponse?.data.length ?? 0) + (_isLoading ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == _dataResponse!.data.length) {
                  return const Center(child: LinearProgressIndicator());
                }

                final item = _dataResponse!.data[index];
                final isPerime = item.statut.toLowerCase().contains("périmé");

                return ListTile(
                  onTap: () => _showDetailPopup(item),
                  title: Text(item.libelle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Lot: ${item.numLot} | Date: ${item.datePerement}"),
                      Text(
                        item.statut,
                        style: TextStyle(
                            color: isPerime ? Colors.red : Colors.orange[800],
                            fontStyle: FontStyle.italic,
                            fontSize: 12
                        ),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Qté: ${item.quantiteLot.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("${item.codeCip}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
      ],
    );
  }
}