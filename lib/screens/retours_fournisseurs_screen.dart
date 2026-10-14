// lib/screens/retours_fournisseurs_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/fournisseur_model.dart';
import 'package:prestige_app/screens/liste_produits_retour_screen.dart';
import 'package:prestige_app/screens/retour_fournisseur_detail_screen.dart';
import '../models/retour_fournisseur_model.dart';
import '../donnees/retours_fournisseurs_donnees.dart';
import '../utils/date_formatter.dart';
import '../ui_helpers/base_screen_logic.dart';
import '../widgets/erreurs_chargement.dart';
import '../utils/saisie.dart';

class RetoursFournisseursScreen extends StatefulWidget {
  const RetoursFournisseursScreen({super.key});

  @override
  State<RetoursFournisseursScreen> createState() => _RetoursFournisseursScreenState();
}

class _RetoursFournisseursScreenState extends State<RetoursFournisseursScreen> with BaseScreenLogic<RetoursFournisseursScreen> {
  List<RetourFournisseur> _retours = [];
  List<Fournisseur> _fournisseurs = [];
  Fournisseur? _selectedFournisseur;
  String _filtre = 'TOUT';
  DateTime _startDate = DateFormatter.getDefaultStartDate();
  DateTime _endDate = DateFormatter.getDefaultEndDate();
  final TextEditingController _searchController = TextEditingController();
  int? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _fetchGrossistes();
  }

  // Lectures partagées avec la nouvelle interface (lib/donnees/retours_fournisseurs_donnees.dart).
  Future<void> _fetchGrossistes() async {
    reessai = _fetchGrossistes; // « Réessayer » relance ce chargement
    final f = await apiDonnees((deco) => RetoursFournisseurs.fournisseurs(context, onSessionInvalid: deco));
    if (mounted && f != null) {
      setState(() {
        _fournisseurs = f;
      });
    }
  }

  Future<void> _loadRetours() async {
    reessai = _loadRetours; // « Réessayer » relance ce chargement
    setState(() {
      _retours = [];
    });

    final filtre = FiltreReponse.values.firstWhere((f) => f.valeur == (_filtre == 'TOUT' ? '' : _filtre), orElse: () => FiltreReponse.tout);
    final r = await apiDonnees((deco) => RetoursFournisseurs.retours(context,
        recherche: _searchController.text,
        fourId: _selectedFournisseur?.fournisseurId ?? '',
        filtre: filtre,
        debut: _startDate,
        fin: _endDate,
        onSessionInvalid: deco));

    if (mounted && r != null) {
      setState(() {
        _retours = r;
        if (_retours.isEmpty) {
          errorMessage = "Aucun retour fournisseur trouvé pour les critères sélectionnés.";
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) {
      if (mounted) {
        setState(() {
          if (isStartDate) {
            _startDate = picked;
            if (_endDate.isBefore(_startDate)) _endDate = _startDate;
          } else {
            _endDate = picked;
            if (_startDate.isAfter(_endDate)) _startDate = _endDate;
          }
          _selectedMonth = null;
        });
      }
    }
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Date de début:", style: TextStyle(fontSize: 12)),
                  TextButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(DateFormatter.toDisplayFormat(_startDate), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Date de fin:", style: TextStyle(fontSize: 12)),
                  TextButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(DateFormatter.toDisplayFormat(_endDate), style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthPicker() {
    final now = DateTime.now();
    final months = List.generate(now.month, (index) => index + 1);

    return DropdownButtonFormField<int>(
      isExpanded: true, // nom du mois long (« septembre ») : tronqué au lieu de déborder sur téléphone
      decoration: const InputDecoration(labelText: 'Mois'),
      value: _selectedMonth,
      hint: const Text('Choisir...'),
      items: months.map((month) {
        return DropdownMenuItem<int>(
          value: month,
          child: Text(DateFormat.MMMM('fr_FR').format(DateTime(now.year, month))),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedMonth = value;
            final year = now.year;
            _startDate = DateTime(year, value, 1);
            _endDate = DateTime(year, value + 1, 0);
          });
          _loadRetours();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Retours Fournisseurs'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildDatePicker(context)),
                    const SizedBox(width: 16),
                    Expanded(flex: 1, child: _buildMonthPicker()),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Fournisseur>(
                        isExpanded: true, // nom de fournisseur long : tronqué au lieu de déborder
                        decoration: const InputDecoration(labelText: 'Fournisseur'),
                        value: _selectedFournisseur,
                        items: [
                          const DropdownMenuItem<Fournisseur>(
                            value: null,
                            child: Text('Tous'),
                          ),
                          ..._fournisseurs.map((fournisseur) {
                            return DropdownMenuItem<Fournisseur>(
                              value: fournisseur,
                              child: Text(fournisseur.fournisseurLibelle),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedFournisseur = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true, // « Sans réponse » en grande police : tronqué au lieu de déborder
                        decoration: const InputDecoration(labelText: 'Filtre'),
                        value: _filtre,
                        items: const [
                          DropdownMenuItem(value: 'TOUT', child: Text('Tout')),
                          DropdownMenuItem(value: 'WITH', child: Text('Avec réponse')),
                          DropdownMenuItem(value: 'WITHOUT', child: Text('Sans réponse')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filtre = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  inputFormatters: Saisie.rechercheFormatters, // longueur max, sans caractères de contrôle
                  decoration: const InputDecoration(
                    hintText: 'Rechercher...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.search),
                        label: const Text('Rechercher'),
                        onPressed: isLoading ? null : _loadRetours,
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Liste Produits'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ListeProduitsRetourScreen(
                                startDate: _startDate,
                                endDate: _endDate,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(45),
                          backgroundColor: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (loadError != null)
            Expanded(child: LoadErrorView(message: loadError!.message, onRetry: () => reessai?.call()))
          else if (errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              ),
            )
          else if (_retours.isEmpty)
              const Expanded(child: Center(child: Text('Aucun retour à afficher.')))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _retours.length,
                  itemBuilder: (context, index) {
                    final retour = _retours[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      child: ListTile(
                        title: Text(retour.strGrossisteLibelle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Réf. Retour: ${retour.strRefRetourFrs}'),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: <TextSpan>[
                                  const TextSpan(text: 'Réf. Livraison: '),
                                  TextSpan(text: retour.strRefLivraison, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: <TextSpan>[
                                  const TextSpan(text: 'Date: '),
                                  TextSpan(
                                    text: retour.dtCreated != null ? DateFormatter.toDisplayFormat(retour.dtCreated!) : 'N/A',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: <TextSpan>[
                                  const TextSpan(text: 'Montant: '),
                                  TextSpan(
                                    text: currencyFormat.format(retour.montantRetour),
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          child: const Text('Détails'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RetourFournisseurDetailScreen(retourId: retour.lgRetourFrsId),
                              ),
                            );
                          },
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
}