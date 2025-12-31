import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:prestige_app/models/suivi_peremption_model.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

class SuiviPeremptionScreen extends StatefulWidget {
  const SuiviPeremptionScreen({Key? key}) : super(key: key);

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

  // Pagination
  int _currentPage = 1;
  final int _limit = 20;
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
    final api = Provider.of<ApiService>(context, listen: false);

    if (!loadMore) {
      setState(() => _isLoading = true);
      _currentPage = 1;
    } else {
      _currentPage++;
    }

    try {
      final result = await api.getSuiviPeremption(
        context,
        query: _searchController.text,
        nbreMois: _moisController.text,
        page: _currentPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          if (loadMore && _dataResponse != null && result != null) {
            // Fusionner les listes
            _dataResponse = SuiviPeremptionResponse(
              metaData: result.metaData, // On prend les métadonnées les plus récentes
              data: [..._dataResponse!.data, ...result.data],
              total: result.total,
            );
          } else {
            _dataResponse = result;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Erreur fetch: $e");
    }
  }

  // --- GENERATION PDF ---
  Future<void> _generatePdf() async {
    if (_dataResponse == null || _dataResponse!.data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune donnée à imprimer")));
      return;
    }

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final items = _dataResponse!.data;
    final meta = _dataResponse!.metaData;
    final dateImpression = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            // En-tête PDF
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Suivi Péremption", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Imprimé le: $dateImpression", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Résumé des totaux
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfSummaryItem("Qté Totale", "${meta.totalQuantiteLot.toInt()}"),
                  _buildPdfSummaryItem("Val. Achat", "${meta.totalValeurAchat.toInt()}"),
                  _buildPdfSummaryItem("Val. Vente", "${meta.totalValeurVente.toInt()}"),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Tableau
            pw.Table.fromTextArray(
              headers: ['Code', 'Libellé', 'Lot', 'Date Pér.', 'Qté', 'Statut'],
              data: items.map((item) => [
                item.codeCip,
                item.libelle,
                item.numLot,
                item.datePerement,
                item.quantiteLot.toInt().toString(),
                item.statut
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellHeight: 25,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerLeft,
              },
              border: null,
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Suivi_Peremption_$dateImpression',
    );
  }

  pw.Widget _buildPdfSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      ],
    );
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