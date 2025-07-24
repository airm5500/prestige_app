// lib/screens/annulation_vente_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Importer pour les polices
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/vente_stat_model.dart';
import '../models/vente_detail_model.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';

class AnnulationVenteScreen extends StatefulWidget {
  const AnnulationVenteScreen({super.key});

  @override
  State<AnnulationVenteScreen> createState() => _AnnulationVenteScreenState();
}

class _AnnulationVenteScreenState extends State<AnnulationVenteScreen> with BaseScreenLogic<AnnulationVenteScreen> {
  List<VenteStat> _ventes = [];
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  final TextEditingController _searchController = TextEditingController();

  Future<void> _loadVentes() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      Fluttertoast.showToast(msg: "Veuillez entrer un numéro de vente à rechercher.");
      return;
    }

    final queryParams = {
      'dtStart': DateFormatter.toApiFormat(_startDate),
      'dtEnd': DateFormatter.toApiFormat(_endDate),
      'query': query,
      'start': '0',
      'limit': '50',
    };

    final data = await apiGet(AppConstants.ventesStatsEndpoint, queryParams: queryParams);

    if (mounted && data is Map<String, dynamic> && data['data'] is List) {
      setState(() {
        _ventes = (data['data'] as List).map((item) => VenteStat.fromJson(item)).toList();
        if (_ventes.isEmpty) {
          errorMessage = "Aucune vente trouvée pour ce numéro sur la période.";
        }
      });
    }
  }

  Future<void> _showDetails(VenteStat vente) async {
    final detailData = await apiGet('${AppConstants.venteDetailEndpoint}/${vente.lgPREENREGISTREMENTID}');

    if (mounted && detailData is Map<String, dynamic> && detailData['data'] is Map) {
      final detail = VenteDetail.fromJson(detailData['data']);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Détails de la Vente", style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(detail.strREF, style: GoogleFonts.lato(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("Vendeur", detail.vendeur),
                _buildDetailRow("Type Vente", detail.typeVente),
                const Divider(height: 24),
                Text("Articles :", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...detail.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text("• ${item.intQUANTITY} x ${item.strDESCRIPTION}", style: GoogleFonts.lato(fontSize: 14)),
                ))
              ],
            ),
          ),
          actions: [TextButton(child: const Text('Fermer'), onPressed: () => Navigator.of(ctx).pop())],
        ),
      );
    }
  }

  Future<void> _annulerVente(VenteStat vente) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmation"),
        content: Text("Voulez-vous vraiment annuler la vente N° ${vente.strREF} ?"),
        actions: [
          TextButton(child: const Text('Non'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(child: const Text('Oui, Annuler'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );

    if (confirm == true) {
      final result = await apiGet('${AppConstants.venteAnnulationEndpoint}/${vente.lgPREENREGISTREMENTID}');

      if (mounted && result?['success'] == true) {
        Fluttertoast.showToast(msg: "Vente annulée avec succès", backgroundColor: Colors.green);
        _loadVentes();
      } else {
        final detailedError = errorMessage ?? result?['msg'] ?? "Erreur d'annulation de la vente";
        Fluttertoast.showToast(msg: detailedError, backgroundColor: Colors.red, toastLength: Toast.LENGTH_LONG);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(title: const Text('Annulation de Ventes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                _buildDatePicker(context),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Numéro de vente...',
                    labelText: 'Rechercher une Vente',
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search_sharp),
                  label: const Text('Rechercher les Ventes'),
                  onPressed: isLoading ? null : _loadVentes,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
              ],
            ),
          ),
          if (isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (errorMessage != null) Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center))))
          else if (_ventes.isEmpty) const Expanded(child: Center(child: Text('Veuillez lancer une recherche.')))
            else Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  itemCount: _ventes.length,
                  itemBuilder: (context, index) {
                    final vente = _ventes[index];
                    return Card(
                      child: ListTile(
                        title: Text("Vente N° ${vente.strREF}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${vente.dtCREATED} à ${vente.HEUREVENTE} - ${currencyFormat.format(vente.intPRICE)}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.visibility), tooltip: 'Voir Détails', onPressed: () => _showDetails(vente)),
                            IconButton(icon: Icon(Icons.cancel, color: vente.cancel ? Colors.grey : Colors.red.shade400), tooltip: 'Annuler', onPressed: vente.cancel ? null : () => _annulerVente(vente)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: isStartDate ? _startDate : _endDate, firstDate: DateTime(2000), lastDate: DateTime(2101), locale: const Locale('fr', 'FR'));
    if (picked != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate)) _startDate = _endDate;
        }
      });
    }
  }

  Widget _buildDatePicker(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Date de début:", style: TextStyle(fontSize: 12)),
          TextButton(onPressed: () => _selectDate(context, true), child: Text(DateFormatter.toDisplayFormat(_startDate), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
        ])),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Date de fin:", style: TextStyle(fontSize: 12)),
          TextButton(onPressed: () => _selectDate(context, false), child: Text(DateFormatter.toDisplayFormat(_endDate), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold))),
        ])),
      ],
    );
  }

  // CORRECTION: Nouveau widget de détail plus compact et lisible
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.lato(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
