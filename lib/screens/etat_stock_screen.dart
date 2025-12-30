import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prestige_app/models/common_data_model.dart';
import 'package:prestige_app/models/etat_stock_article_model.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

class EtatStockScreen extends StatefulWidget {
  const EtatStockScreen({Key? key}) : super(key: key);

  @override
  _EtatStockScreenState createState() => _EtatStockScreenState();
}

class _EtatStockScreenState extends State<EtatStockScreen> {
  // Contrôleurs
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _stockValueController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _stockFocusNode = FocusNode();

  // Données
  List<CommonData> _rayons = [];
  Map<String, String> _grossistesMap = {};

  // Sélection
  CommonData? _selectedRayon;
  String? _selectedStockFilter;

  // Résultats
  List<EtatStockArticleModel> _articles = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  // Pagination
  int _currentPage = 1;
  int _totalArticles = 0;
  final ScrollController _scrollController = ScrollController();

  final Map<String, String> _stockFilters = {
    'EQUAL': 'Egal (=)',
    'LESS': 'Inférieur (<)',
    'GREATER': 'Supérieur (>)',
    'GREATER_EQUAL': 'Sup. ou Egal (>=)',
    'LESS_EQUAL': 'Inf. ou Egal (<=)',
    'NOT': 'Différent (!=)',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (_articles.length < _totalArticles && !_isLoading) {
          _searchArticles(loadMore: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _stockValueController.dispose();
    _searchFocusNode.dispose();
    _stockFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final rayons = await apiService.getRayons(context);
      final grossistes = await apiService.getGrossistes(context);

      if (mounted) {
        setState(() {
          _rayons = rayons;
          _grossistesMap = {for (var g in grossistes) g.id: g.libelle};
        });
      }
    } catch (e) {
      debugPrint("Erreur chargement init: $e");
    }
  }

  Future<void> _searchArticles({bool loadMore = false}) async {
    if (_selectedStockFilter != null && _stockValueController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez une quantité pour le filtre stock')),
      );
      _stockFocusNode.requestFocus();
      return;
    }

    final apiService = Provider.of<ApiService>(context, listen: false);

    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _hasSearched = true;
        _currentPage = 1;
        _articles.clear();
      });
    } else {
      setState(() {
        _currentPage++;
      });
    }

    try {
      final result = await apiService.getEtatStockArticles(
        context,
        query: _searchController.text,
        codeRayon: _selectedRayon?.id ?? '',
        stock: _stockValueController.text,
        filtreStock: _selectedStockFilter ?? '',
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          _totalArticles = result['total'];
          if (loadMore) {
            _articles.addAll(result['data']);
          } else {
            _articles = result['data'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _stockValueController.clear();
      _selectedRayon = null;
      _selectedStockFilter = null;
      _articles.clear();
      _hasSearched = false;
      _totalArticles = 0;
    });
    FocusScope.of(context).requestFocus(_searchFocusNode);
  }

  void _showDetailPopup(EtatStockArticleModel article) {
    showDialog(
      context: context,
      builder: (context) {
        String nomGrossiste = _grossistesMap[article.grossisteId] ?? "Inconnu";

        return AlertDialog(
          title: Text(article.libelle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow("Code", article.code),
                _detailRow("EAN", article.codeEan ?? "-"),
                const Divider(),
                _detailRow("Stock", "${article.stock.toInt()}", isBold: true, color: Colors.blue),
                _detailRow("Prix Vente", "${article.prixVente.toInt()} FCFA"),
                _detailRow("Prix Achat", "${article.prixAchat.toInt()} FCFA"),
                const Divider(),
                _detailRow("Rayon", article.rayonLibelle),
                _detailRow("Inventaire", article.dateInventaire ?? "-"),
                _detailRow("Dernière Entrée", article.dateEntree ?? "-"),
                const Divider(),
                _detailRow("Qté Réappro", "${article.qteReappro?.toInt() ?? 0}"),
                _detailRow("Grossiste", nomGrossiste),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer"),
            )
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
          Text("$label :", style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("État de Stock"),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearFilters,
            tooltip: "Vider/Rafraîchir",
          )
        ],
      ),
      body: Column(
        children: [
          // 1. Zone de Recherche Rapide (Toujours en haut)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                labelText: "Recherche (Nom, Code, Scan)",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearFilters)
                    : null,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _searchArticles(),
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
            ),
          ),

          // 2. Zone de Filtres Avancés (Stable sur 2 lignes)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                // Ligne 1: Les sélecteurs (Emplacement & Type de Stock)
                Row(
                  children: [
                    // Emplacement (Prend 60% de la largeur)
                    Expanded(
                      flex: 6,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CommonData>(
                            isExpanded: true,
                            hint: const Text("Emplacement", style: TextStyle(fontSize: 14)),
                            value: _selectedRayon,
                            items: _rayons.map((rayon) {
                              return DropdownMenuItem(
                                value: rayon,
                                child: Text(
                                  rayon.libelle,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedRayon = val);
                              _searchArticles();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Type de Stock (Prend 40% de la largeur)
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text("Stock...", style: TextStyle(fontSize: 14)),
                            value: _selectedStockFilter,
                            items: _stockFilters.entries.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value, style: const TextStyle(fontSize: 13))
                            )).toList(),
                            onChanged: (val) {
                              setState(() => _selectedStockFilter = val);
                              if (val != null) {
                                Future.delayed(Duration.zero, () => _stockFocusNode.requestFocus());
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Ligne 2: Valeur Stock (si besoin) + Bouton Action
                Row(
                  children: [
                    if (_selectedStockFilter != null) ...[
                      SizedBox(
                        width: 100,
                        height: 50,
                        child: TextField(
                          controller: _stockValueController,
                          focusNode: _stockFocusNode,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Qté",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          ),
                          onSubmitted: (_) => _searchArticles(),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Bouton Filtrer (Prend tout le reste de la place)
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _searchArticles(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          ),
                          icon: const Icon(Icons.filter_list),
                          label: const Text("APPLIQUER FILTRES"),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(),

          // 3. Liste des résultats
          Expanded(
            child: _isLoading && _articles.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.touch_app_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Utilisez la recherche ou les filtres ci-dessus", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : _articles.isEmpty
                ? const Center(child: Text("Aucun résultat trouvé"))
                : ListView.separated(
              controller: _scrollController,
              itemCount: _articles.length + (_isLoading ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == _articles.length) return const Center(child: LinearProgressIndicator());
                final item = _articles[index];
                return ListTile(
                  title: Text(item.libelle, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Code: ${item.code} | ${item.rayonLibelle}\nPA: ${item.prixAchat.toInt()} | PV: ${item.prixVente.toInt()}"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.stock <= 0 ? Colors.red[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: item.stock <= 0 ? Colors.red : Colors.green),
                    ),
                    child: Text(
                        "${item.stock.toInt()}",
                        style: TextStyle(color: item.stock <= 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)
                    ),
                  ),
                  onTap: () => _showDetailPopup(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}