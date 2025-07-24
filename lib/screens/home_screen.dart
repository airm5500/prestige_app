// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ip_config_provider.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'settings_screen.dart';

// Import de tous les écrans de fonctionnalités
import 'fournisseurs_screen.dart';
import 'achats_fournisseurs_screen.dart';
import 'valorisation_screen.dart';
import 'ca_credit_screen.dart';
import 'ca_comptant_screen.dart';
import 'ca_global_screen.dart';
import 'fiche_article_screen.dart';
import 'tableau_bord_ratio_screen.dart';
import 'tableau_bord_analyse_menu_screen.dart';
import 'evolution_stock_screen.dart';
import 'analyse_article_screen.dart';
import 'suivi_credit_screen.dart';
//import 'mes_articles_screen.dart';
import 'annulation_vente_screen.dart';
import 'suivi_ajustement_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final ipProvider = Provider.of<IpConfigProvider>(context);

    final AppUser? currentUser = authProvider.user;
    final String userName = currentUser?.fullName ?? 'Utilisateur';
    final String officineName = currentUser?.officineName ?? 'Prestige App';

    // --- CORRECTION: Organisation des fonctionnalités en pages ---
    final List<Map<String, dynamic>> page1Items = [
      {'title': 'CA Comptant', 'icon': Icons.payments_outlined, 'color': Colors.green, 'screen': const CaComptantScreen()},
      {'title': 'CA Crédit', 'icon': Icons.credit_card_outlined, 'color': Colors.blue, 'screen': const CaCreditScreen()},
      {'title': 'CA Global', 'icon': Icons.receipt_long_outlined, 'color': Colors.amber.shade700, 'screen': const CaGlobalScreen()},
      {'title': 'Suivi Crédit', 'icon': Icons.request_quote_outlined, 'color': Colors.redAccent, 'screen': const SuiviCreditScreen()},
      {'title': 'Tableau: Analyses', 'icon': Icons.analytics_outlined, 'color': Colors.pinkAccent, 'screen': const TableauBordAnalyseMenuScreen()},
      {'title': 'Tableau: Ratios', 'icon': Icons.compare_arrows_outlined, 'color': Colors.lime.shade700, 'screen': const TableauBordRatioScreen()},
    ];

    final List<Map<String, dynamic>> page2Items = [
      {'title': 'Analyse Article', 'icon': Icons.pie_chart_outline_rounded, 'color': Colors.indigo, 'screen': const AnalyseArticleScreen()},
      {'title': 'Fiche Article', 'icon': Icons.article_outlined, 'color': Colors.cyan, 'screen': const FicheArticleScreen()},
      //{'title': 'Mes Articles', 'icon': Icons.inventory, 'color': Colors.blueGrey, 'screen': const MesArticlesScreen()},
      {'title': 'Evolution Stock', 'icon': Icons.ssid_chart_outlined, 'color': Colors.brown, 'screen': const EvolutionStockScreen()},
      {'title': 'Valorisation', 'icon': Icons.inventory_2_outlined, 'color': Colors.purple, 'screen': const ValorisationScreen()},
      {'title': 'Suivi Ajustements', 'icon': Icons.rule_folder_outlined, 'color': Colors.deepPurple, 'screen': const SuiviAjustementScreen()},
    ];

    final List<Map<String, dynamic>> page3Items = [
      {'title': 'Fournisseurs', 'icon': Icons.people_alt_outlined, 'color': Colors.teal, 'screen': const FournisseursScreen()},
      {'title': 'Achats Fourn.', 'icon': Icons.shopping_cart_checkout_outlined, 'color': Colors.deepOrange, 'screen': const AchatsFournisseursScreen()},
      {'title': 'Annulation Ventes', 'icon': Icons.cancel_presentation_outlined, 'color': Colors.red.shade700, 'screen': const AnnulationVenteScreen()},
    ];

    final List<List<Map<String, dynamic>>> allPages = [page1Items, page2Items, page3Items];

    return Scaffold(
      appBar: AppBar(
        title: Text(officineName),
        actions: [
          Tooltip(
            message: ipProvider.useLocalIp ? 'Passer en mode Distant' : 'Passer en mode Local',
            child: Switch(
              value: ipProvider.useLocalIp,
              onChanged: (value) {
                if (!value && (ipProvider.remoteIp.isEmpty || ipProvider.remoteIp == AppConstants.defaultRemoteIp)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L\'adresse IP distante n\'est pas configurée.'), backgroundColor: Colors.orange));
                  return;
                }
                ipProvider.setUseLocalIp(value);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_applications_outlined),
            tooltip: 'Configuration IP',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildWelcomeCard(context, ipProvider, userName),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Text(
              'Fonctionnalités',
              style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: allPages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildFeatureGrid(allPages[index]);
              },
            ),
          ),
          // Indicateurs de page (points)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(allPages.length, (index) => _buildPageIndicator(index == _currentPage)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Widget pour la grille de fonctionnalités d'une page
  Widget _buildFeatureGrid(List<Map<String, dynamic>> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.0,
        mainAxisSpacing: 12.0,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildMenuButton(
          context,
          title: item['title'],
          icon: item['icon'],
          color: item['color'],
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => item['screen'])),
        );
      },
    );
  }

  // Widget pour les points indicateurs de page
  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive ? Theme.of(context).primaryColor : Colors.grey.shade400,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, IpConfigProvider ipProvider, String userName) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.colorScheme.secondary],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [BoxShadow(color: theme.primaryColor.withAlpha(77), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bienvenu(e) $userName',
            style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(color: color.withAlpha(38), shape: BoxShape.circle),
              child: Icon(icon, size: 32.0, color: color),
            ),
            const SizedBox(height: 12.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(fontSize: 14.0, fontWeight: FontWeight.w600, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
