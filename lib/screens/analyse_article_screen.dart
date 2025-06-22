// lib/screens/analyse_article_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../models/analyse_article_model.dart';
import '../utils/constants.dart';

class AnalyseArticleScreen extends StatefulWidget {
  const AnalyseArticleScreen({super.key});

  @override
  State<AnalyseArticleScreen> createState() => _AnalyseArticleScreenState();
}

class _AnalyseArticleScreenState extends State<AnalyseArticleScreen> {
  late ApiService _apiService;
  final TextEditingController _searchController = TextEditingController();
  List<AnalyseArticle> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _lastSearchTerm = "";
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(context);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final searchTerm = _searchController.text.trim();
      final isNumeric = int.tryParse(searchTerm) != null;

      final minLength = isNumeric ? 3 : 2;

      if (searchTerm.length >= minLength) {
        if (searchTerm != _lastSearchTerm) {
          _rechercherArticles();
        }
      } else {
        if (mounted) {
          setState(() {
            _results = [];
            _errorMessage = null;
            _lastSearchTerm = "";
          });
        }
      }
    });
  }

  Future<void> _rechercherArticles() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) {
      return;
    }

    _lastSearchTerm = searchTerm;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dynamic response = await _apiService.get(AppConstants.infoEndpoint, queryParams: {'search': searchTerm});
      if (!mounted) return;

      List<dynamic> dataList = [];

      if (response is Map<String, dynamic> && response['data'] is List) {
        dataList = response['data'];
      }

      setState(() {
        var allResults = dataList.map((item) => AnalyseArticle.fromJson(item)).toList();
        _results = allResults.where((article) => article.libelle.isNotEmpty && article.libelle != 'N/A').toList();

        if (_results.isEmpty) {
          _errorMessage = "Aucun article valide trouvé pour '$searchTerm'.";
        }
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _errorMessage = 'Erreur: ${e.toString().replaceFirst("Exception: ", "")}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _afficherDetailsArticle(BuildContext context, AnalyseArticle article) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final chartData = article.getVentesChartData();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          title: Text("Détails de l'Article", style: GoogleFonts.lato(color: theme.primaryColor, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min, // S'adapte à la taille du contenu
              children: [
                // CORRECTION: Nouvelle mise en page pour la bulle
                _buildDetailRow('Code CIP', article.codeCip),
                _buildDetailRow('Désignation', article.libelle),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _buildDetailRow('Prix d\'achat', currencyFormat.format(article.prixAchat)),
                          _buildDetailRow('Prix de vente', currencyFormat.format(article.prixVente)),
                          _buildDetailRow('Grossiste', article.grossiste ?? 'N/A'),
                          _buildDetailRow('Moyenne sur 3 mois', article.moyenne.toStringAsFixed(2)),
                          _buildDetailRow('Emplacement', article.emplacement ?? 'N/A'),
                          _buildDetailRow('Qté totale vendue sur 6mois', article.quantiteVendue.toString()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildStockBubble(context, article.stock), // La bulle est maintenant ici
                  ],
                ),
                // FIN DE LA CORRECTION
                const Divider(height: 24),
                Text('Évolution des ventes mensuelles:', style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor, fontSize: 15)),
                const SizedBox(height: 15),
                if (chartData.isEmpty)
                  const Text('Aucune donnée de vente pour le graphique.')
                else
                  SizedBox(
                    height: 120,
                    child: _VentesEvolutionChart(spots: chartData),
                  )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Fermer', style: TextStyle(fontSize: 16)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStockBubble(BuildContext context, int? stock) {
    final Color bubbleColor = Theme.of(context).primaryColor;

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: bubbleColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: bubbleColor.withAlpha(100),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Stock Actuel", // Libellé ajouté
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
            Text(
              stock?.toString() ?? 'N/A',
              style: GoogleFonts.lato(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.lato(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: GoogleFonts.lato(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: '', decimalDigits: 0);
    const defaultTextStyle = TextStyle(color: Colors.black54, fontSize: 13);
    const boldTextStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse Article'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Code CIP ou libellé...',
                labelText: 'Rechercher un Article',
                suffixIcon: _isLoading
                    ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                    : (_searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                    : null),
              ),
              onSubmitted: (_) => _rechercherArticles(),
            ),
          ),
          if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 16), textAlign: TextAlign.center),
                ),
              ),
            )
          else if (_results.isNotEmpty)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _results.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final article = _results[index];
                  return Card(
                    elevation: 2,
                    shadowColor: Colors.black.withAlpha(26),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      title: Text(article.libelle, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: RichText(
                          text: TextSpan(
                            style: defaultTextStyle,
                            children: [
                              const TextSpan(text: 'Prix: '),
                              TextSpan(text: currencyFormat.format(article.prixVente), style: boldTextStyle),
                              const TextSpan(text: ' FCFA - Stock: '),
                              TextSpan(text: article.stock?.toString() ?? 'N/A', style: boldTextStyle),
                              const TextSpan(text: ' - Moy 3Mois: '),
                              TextSpan(text: article.moyenne.toStringAsFixed(2), style: boldTextStyle),
                            ],
                          ),
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400, size: 18),
                      onTap: () => _afficherDetailsArticle(context, article),
                    ),
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _lastSearchTerm.isEmpty ? 'Entrez un libellé ou un code CIP pour rechercher.' : (_isLoading ? 'Recherche en cours...' : ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VentesEvolutionChart extends StatelessWidget {
  final List<FlSpot> spots;
  const _VentesEvolutionChart({required this.spots});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(color: Colors.black54, fontSize: 10);
                const mois = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                if (value.toInt() >= 1 && value.toInt() <= 12) {
                  return Text(mois[value.toInt() - 1], style: style);
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        minX: 1,
        maxX: DateTime.now().month.toDouble(),
        minY: 0,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.secondary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.secondary.withAlpha(50),
            ),
          ),
        ],
      ),
    );
  }
}
