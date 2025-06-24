// lib/screens/analyse_article_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/analyse_article_model.dart';
import '../utils/constants.dart';
import '../ui_helpers/base_screen_logic.dart';

class AnalyseArticleScreen extends StatefulWidget {
  const AnalyseArticleScreen({super.key});

  @override
  State<AnalyseArticleScreen> createState() => _AnalyseArticleScreenState();
}

class _AnalyseArticleScreenState extends State<AnalyseArticleScreen> with BaseScreenLogic<AnalyseArticleScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AnalyseArticle> _results = [];
  String _lastSearchTerm = "";
  Timer? _debounce;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
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
            errorMessage = null;
            _lastSearchTerm = "";
          });
        }
      }
    });
  }

  Future<void> _rechercherArticles() async {
    final searchTerm = _searchController.text.trim();
    if (searchTerm.isEmpty) return;

    _lastSearchTerm = searchTerm;

    final data = await apiGet(
        AppConstants.infoEndpoint,
        queryParams: {'search': searchTerm}
    );

    if (mounted && data != null) {
      List<dynamic> dataList = [];
      if (data is Map<String, dynamic> && data['data'] is List) {
        dataList = data['data'];
      } else if (data is List) {
        dataList = data;
      }

      setState(() {
        var allResults = dataList.map((item) => AnalyseArticle.fromJson(item)).toList();
        _results = allResults.where((article) => article.libelle.isNotEmpty && article.libelle != 'N/A').toList();

        if (_results.isEmpty) {
          errorMessage = "Aucun article valide trouvé pour '$searchTerm'.";
        }
      });
    }
  }

  Future<void> _afficherDetailsArticle(BuildContext context, AnalyseArticle article) async {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final chartData = article.getVentesChartData();

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          title: Text("Détails de l'Article", style: GoogleFonts.lato(color: theme.primaryColor, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                          _buildDetailRow('Qté totale vendue', article.quantiteVendue.toString()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildStockBubble(context, article.stock),
                  ],
                ),
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
    _searchFocusNode.requestFocus();
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
              "Stock Actuel",
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
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Code CIP ou libellé...',
                labelText: 'Rechercher un Article',
                suffixIcon: isLoading
                    ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                    : (_searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                    : null),
              ),
              onSubmitted: (_) => _rechercherArticles(),
            ),
          ),
          if (errorMessage != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(errorMessage!, style: TextStyle(color: Colors.red.shade700, fontSize: 16), textAlign: TextAlign.center),
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
                    isLoading ? 'Recherche en cours...' : 'Entrez un libellé (2+ car.) ou un code CIP (3+ car.) pour rechercher.',
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
