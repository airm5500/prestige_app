// lib/screens/annulation_vente_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Importer pour les polices
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/vente_stat_model.dart';
import '../donnees/annulation_vente_donnees.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';
import '../widgets/erreurs_chargement.dart';
import '../utils/saisie.dart';

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
    reessai = _loadVentes; // « Réessayer » relance ce chargement
    final query = Saisie.recherche(_searchController.text);
    if (query.isEmpty) {
      Fluttertoast.showToast(msg: "Veuillez entrer un numéro de vente à rechercher.");
      return;
    }

    // Lecture partagée avec la nouvelle interface (lib/donnees/annulation_vente_donnees.dart) : mêmes paramètres.
    final ventes = await apiDonnees(
        (deco) => AnnulationVente.rechercher(context, debut: _startDate, fin: _endDate, recherche: query, onSessionInvalid: deco));

    if (mounted && ventes != null) {
      setState(() {
        _ventes = ventes;
        if (_ventes.isEmpty) {
          errorMessage = "Aucune vente trouvée pour ce numéro sur la période.";
        }
      });
    }
  }

  Future<void> _showDetails(VenteStat vente) async {
    final detail = await apiDonnees((deco) => AnnulationVente.detail(context, vente.lgPREENREGISTREMENTID, onSessionInvalid: deco));

    if (mounted && detail != null) {
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

  // --- ANNULATION : protégée contre le double envoi ---
  // La route serveur reste GET /vente/annulation/{id} (inchangée). Côté application :
  // - une seule annulation en vol à la fois (boutons « Annuler » bloqués, indicateur sur la ligne) ;
  // - confirmation explicite (montant, date ; fenêtre non fermable par erreur) ;
  // - relecture de la vente AVANT l'envoi (déjà annulée → aucun envoi) et APRÈS (résultat vérifié) ;
  // - sans réponse du serveur (délai, réseau), la demande n'est JAMAIS renvoyée automatiquement : l'état
  //   réel de la vente est relu et affiché.

  /// Identifiant de la vente dont l'annulation est en cours (une seule à la fois).
  String? _annulationEnCours;

  bool get annulationEnCours => _annulationEnCours != null;

  void _message(String texte, {bool erreur = false, bool succes = false}) {
    Fluttertoast.showToast(
      msg: texte,
      backgroundColor: succes ? Colors.green : (erreur ? Colors.red : Colors.orange.shade800),
      toastLength: erreur ? Toast.LENGTH_LONG : Toast.LENGTH_SHORT,
    );
  }

  /// Relit l'état de la vente sur le serveur (même recherche que la liste). Échec : ApiLoadException.
  Future<VenteStat?> _relireVente(VenteStat vente) async {
    final data = await apiService.get(
      context,
      AppConstants.ventesStatsEndpoint,
      queryParams: AnnulationVente.parametres(debut: _startDate, fin: _endDate, recherche: _searchController.text),
    );
    final ventes = AnnulationVente.lireVentes(data);
    if (ventes == null) return null;
    if (mounted) setState(() => _ventes = ventes);
    for (final v in ventes) {
      if (v.lgPREENREGISTREMENTID == vente.lgPREENREGISTREMENTID) return v;
    }
    return null;
  }

  Future<void> _annulerVente(VenteStat vente) async {
    if (_annulationEnCours != null) return; // une seule requête en vol
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmation"),
        content: Text(
          "Voulez-vous vraiment annuler la vente N° ${vente.strREF} ?\n\n"
          "${vente.dtCREATED} à ${vente.HEUREVENTE} — ${currencyFormat.format(vente.intPRICE)}\n\n"
          "Cette annulation est définitive.",
        ),
        actions: [
          TextButton(child: const Text('Non'), onPressed: () => Navigator.of(ctx).pop(false)),
          TextButton(child: const Text('Oui, Annuler'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (confirm != true || !mounted || _annulationEnCours != null) return;

    setState(() => _annulationEnCours = vente.lgPREENREGISTREMENTID);
    try {
      // Relecture avant, envoi unique, relecture après : déroulé partagé avec la nouvelle interface.
      final r = await AnnulationVente.executer(context, vente, relire: () => _relireVente(vente));
      if (r == null || !mounted) return;
      _message(r.message, erreur: r.ton == TonResultat.erreur, succes: r.ton == TonResultat.succes);
    } finally {
      if (mounted) setState(() => _annulationEnCours = null);
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
                  inputFormatters: Saisie.rechercheFormatters, // longueur max, sans caractères de contrôle
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
                  onPressed: isLoading || annulationEnCours ? null : _loadVentes,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                ),
              ],
            ),
          ),
          if (isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (loadError != null)
            Expanded(child: LoadErrorView(message: loadError!.message, onRetry: () => reessai?.call()))
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
                            if (_annulationEnCours == vente.lgPREENREGISTREMENTID)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
                              )
                            else
                              IconButton(
                                key: Key('annuler_${vente.lgPREENREGISTREMENTID}'),
                                icon: Icon(Icons.cancel, color: vente.cancel || annulationEnCours ? Colors.grey : Colors.red.shade400),
                                tooltip: vente.cancel ? 'Vente déjà annulée' : 'Annuler',
                                // Bloqué pendant une annulation en cours (une seule requête à la fois).
                                onPressed: vente.cancel || annulationEnCours ? null : () => _annulerVente(vente),
                              ),
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
