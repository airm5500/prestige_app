import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:prestige_app/models/bon_livraison_model.dart';
import 'package:prestige_app/models/common_data_model.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

class VisualisationBlScreen extends StatefulWidget {
  const VisualisationBlScreen({Key? key}) : super(key: key);

  @override
  _VisualisationBlScreenState createState() => _VisualisationBlScreenState();
}

class _VisualisationBlScreenState extends State<VisualisationBlScreen> {
  // Contrôleurs
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _dateStartController = TextEditingController();
  final TextEditingController _dateEndController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Formatteur
  final NumberFormat _currencyFormat = NumberFormat.decimalPattern('fr');

  // Données Listes
  List<CommonData> _grossistes = [];
  List<CommonData> _groupes = [];
  List<CommonData> _users = [];

  // Filtres
  CommonData? _selectedGrossiste;
  CommonData? _selectedGroupe;
  CommonData? _selectedUser;
  String? _selectedStatut;

  final Map<String, String> _statuts = {
    'TERMINE': 'Terminé',
    'NON_TRAITE': 'Non Traité',
    'EN_COURS': 'En Cours',
  };

  // Résultats
  List<BonLivraisonModel> _bls = [];
  int _totalBl = 0;
  bool _isLoading = false;

  // Pagination
  int _currentPage = 1;
  final int _limit = 20;
  final ScrollController _scrollController = ScrollController();

  // Totaux
  double _totalHT = 0;
  double _totalTVA = 0;
  double _totalTTC = 0;

  @override
  void initState() {
    super.initState();
    // 1. Initialisation des dates au jour actuel par défaut
    final now = DateTime.now();
    _dateStartController.text = DateFormat('yyyy-MM-dd').format(now);
    _dateEndController.text = DateFormat('yyyy-MM-dd').format(now);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFilters();
      // Le _fetchData utilisera les dates initialisées juste au-dessus
      _fetchData();
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoading && _bls.length < _totalBl) {
          _fetchData(loadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateStartController.dispose();
    _dateEndController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final g = await api.getGrossistes(context);
      final gr = await api.getGroupeGrossistes(context);
      final u = await api.getUsers(context);

      if (mounted) {
        setState(() {
          _grossistes = g;
          _groupes = gr;
          _users = u;
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement filtres: $e");
    }
  }

  Future<void> _fetchData({bool loadMore = false}) async {
    final api = Provider.of<ApiService>(context, listen: false);

    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _totalHT = 0;
        _totalTVA = 0;
        _totalTTC = 0;
      });
      _currentPage = 1;
    } else {
      _currentPage++;
    }

    try {
      final result = await api.getBonLivraisons(
        context,
        search: _searchController.text,
        grossisteId: _selectedGrossiste?.id ?? '',
        groupeId: _selectedGroupe?.id ?? '',
        userId: _selectedUser?.id ?? '',
        statut: _selectedStatut ?? '',
        dtStart: _dateStartController.text,
        dtEnd: _dateEndController.text,
        page: _currentPage,
        limit: _limit,
      );

      if (mounted) {
        setState(() {
          final newData = result['data'] as List<BonLivraisonModel>;
          _totalBl = result['total'];

          if (loadMore) {
            _bls.addAll(newData);
          } else {
            _bls = newData;
          }

          _recalculateTotals();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _recalculateTotals() {
    _totalHT = _bls.fold(0, (sum, item) => sum + item.montantHT);
    _totalTVA = _bls.fold(0, (sum, item) => sum + item.montantTVA);
    _totalTTC = _bls.fold(0, (sum, item) => sum + item.montantTTC);
  }

  // Action pour vider UNIQUEMENT le champ de recherche
  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).requestFocus(_searchFocusNode);
    _fetchData(); // Optionnel : relancer la recherche vide ou attendre
  }

  // Action pour tout réinitialiser (Bouton Balai)
  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedGrossiste = null;
      _selectedGroupe = null;
      _selectedUser = null;
      _selectedStatut = null;
      final now = DateTime.now();
      _dateStartController.text = DateFormat('yyyy-MM-dd').format(now);
      _dateEndController.text = DateFormat('yyyy-MM-dd').format(now);
    });
    FocusScope.of(context).requestFocus(_searchFocusNode);
    _fetchData();
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
      _fetchData();
    }
  }

  void _showDetailPopup(BonLivraisonModel bl) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Détail BL N° ${bl.refLivraison}"),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(bl.fournisseurLibelle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Livré le: ${bl.dateLivraison} | Statut: ${bl.statut}"),
                  trailing: Text("${_currencyFormat.format(bl.montantTTC.toInt())} F", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ),
                const Divider(),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: bl.details.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = bl.details[index];
                      final hasEcart = item.ecart != 0;

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.designation, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("CIP: ${item.cip} | PV: ${_currencyFormat.format(item.prixVente.toInt())}"),
                            const SizedBox(height: 2),

                            // Ligne 1: Informations principales regroupées
                            RichText(
                              text: TextSpan(
                                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                                  children: [
                                    const TextSpan(text: "Cmd: "),
                                    TextSpan(text: "${item.qteCmde}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const TextSpan(text: " | Recu: "),
                                    TextSpan(text: "${item.qteRecue}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const TextSpan(text: " | Ctrl: "),
                                    TextSpan(text: "${item.qteControle}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const TextSpan(text: " | Ecart: "),
                                    TextSpan(
                                        text: "${item.ecart}",
                                        style: TextStyle(fontWeight: FontWeight.bold, color: hasEcart ? Colors.red : Colors.green)
                                    ),
                                  ]
                              ),
                            ),

                            const SizedBox(height: 2),

                            // Ligne 2: Stock Théorique (Simplifié, sans fond blanc)
                            Text(
                              "Stock Théo: ${item.stockTheorique}",
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("PA: ${_currencyFormat.format(item.prixAchat.toInt())}", style: const TextStyle(fontSize: 12)),
                            if (item.qteGratuite > 0)
                              Text("UG: ${item.qteGratuite}", style: const TextStyle(fontSize: 10, color: Colors.blue)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer"))
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visualisation BL"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchData(),
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Zone Recherche & Dates & Bouton Reset
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: "Rech (CIP, Nom...)",
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      // 2. Croix d'effacement DANS le champ
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: _clearSearch, // Efface juste le texte et garde le focus
                      )
                          : null,
                    ),
                    onChanged: (val) {
                      // Pour mettre à jour l'affichage de la croix
                      setState(() {});
                    },
                    onSubmitted: (_) {
                      _fetchData();
                      // 2. Garder le focus après validation
                      FocusScope.of(context).requestFocus(_searchFocusNode);
                    },
                  ),
                ),

                // Bouton Reset Global (Balai)
                IconButton(
                  icon: const Icon(Icons.cleaning_services_outlined, color: Colors.red),
                  onPressed: _resetAllFilters,
                  tooltip: "Tout réinitialiser",
                ),

                // Dates
                _buildDateSelector(_dateStartController, "Début"),
                const SizedBox(width: 5),
                _buildDateSelector(_dateEndController, "Fin"),
              ],
            ),
          ),

          // 2. Filtres Avancés
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                _buildDropdown("Grossiste", _selectedGrossiste, _grossistes, (val) {
                  setState(() => _selectedGrossiste = val);
                  _fetchData();
                }),
                const SizedBox(width: 8),
                _buildDropdown("Groupe", _selectedGroupe, _groupes, (val) {
                  setState(() => _selectedGroupe = val);
                  _fetchData();
                }),
                const SizedBox(width: 8),
                _buildDropdown("Utilisateur", _selectedUser, _users, (val) {
                  setState(() => _selectedUser = val);
                  _fetchData();
                }),
                const SizedBox(width: 8),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      hint: const Text("Statut", style: TextStyle(fontSize: 12)),
                      value: _selectedStatut,
                      items: _statuts.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) {
                        setState(() => _selectedStatut = val);
                        _fetchData();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // 3. Totaux
          Container(
            color: Colors.blue.withOpacity(0.05),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTotalItem("Total BL", "$_totalBl"),
                  _buildSeparator(),
                  _buildTotalItem("HT", _currencyFormat.format(_totalHT.toInt())),
                  _buildSeparator(),
                  _buildTotalItem("TVA", _currencyFormat.format(_totalTVA.toInt())),
                  _buildSeparator(),
                  _buildTotalItem("TTC", _currencyFormat.format(_totalTTC.toInt()), isBold: true, color: Colors.blue[800]),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // 4. Liste
          Expanded(
            child: _isLoading && _bls.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _bls.isEmpty
                ? const Center(child: Text("Aucun Bon de Livraison trouvé"))
                : ListView.builder(
              controller: _scrollController,
              itemCount: _bls.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _bls.length) return const Center(child: LinearProgressIndicator());

                final bl = _bls[index];
                Color statusColor = Colors.grey;
                if (bl.statut == 'TERMINE') statusColor = Colors.green;
                if (bl.statut == 'EN_COURS') statusColor = Colors.orange;

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    onTap: () => _showDetailPopup(bl),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            bl.fournisseurLibelle,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(bl.refLivraison, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(bl.dateLivraison, style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 10),
                            const Icon(Icons.person, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                bl.userFullName,
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(bl.statut, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            Text(
                                "${_currencyFormat.format(bl.montantTTC.toInt())} F",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)
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
        ],
      ),
    );
  }

  Widget _buildDateSelector(TextEditingController controller, String label) {
    return InkWell(
      onTap: () => _selectDate(controller),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
        child: Text(
            controller.text.isEmpty ? label : controller.text,
            style: const TextStyle(fontSize: 12)
        ),
      ),
    );
  }

  Widget _buildTotalItem(String label, String value, {bool isBold = false, Color? color}) {
    return Row(
      children: [
        Text("$label: ", style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        Text(
            value,
            style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: color ?? Colors.black87,
                fontSize: 13
            )
        ),
      ],
    );
  }

  Widget _buildSeparator() {
    return Container(
      height: 15,
      width: 1,
      color: Colors.grey,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );
  }

  Widget _buildDropdown(String hint, CommonData? selected, List<CommonData> items, Function(CommonData?) onChanged) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CommonData>(
          hint: Text(hint, style: const TextStyle(fontSize: 12)),
          value: selected,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.libelle.length > 15 ? '${e.libelle.substring(0,15)}...' : e.libelle, style: const TextStyle(fontSize: 12)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}