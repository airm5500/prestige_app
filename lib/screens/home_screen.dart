// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/ip_config_provider.dart';
import '../services/api_service.dart';
import '../models/officine_model.dart';
import '../utils/constants.dart';
import 'analyse_article_screen.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Officine? _officineData;
  bool _isOfficineLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOfficineData();
    });
  }

  Future<void> _fetchOfficineData() async {
    if (!mounted) return;
    setState(() {
      _isOfficineLoading = true;
    });

    try {
      final apiService = ApiService(context);
      final data = await apiService.get(AppConstants.officineEndpoint);

      if (mounted && data is List && data.isNotEmpty) {
        setState(() {
          _officineData = Officine.fromJson(data[0]);
          _isOfficineLoading = false;
        });
      } else {
        if (mounted) {
          setState(() => _isOfficineLoading = false);
        }
      }
    } catch (e) {
      debugPrint("Erreur lors de la récupération des données de l'officine: $e");
      if (mounted) {
        setState(() => _isOfficineLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ipProvider = Provider.of<IpConfigProvider>(context);

    final List<Map<String, dynamic>> menuItems = [
      {'title': 'Analyse Article', 'icon': Icons.pie_chart_outline_rounded, 'color': Colors.indigo, 'screen': const AnalyseArticleScreen()},
      {'title': 'Achats Fourn.', 'icon': Icons.shopping_cart_checkout_outlined, 'color': Colors.deepOrange, 'screen': const AchatsFournisseursScreen()},
      {'title': 'CA Comptant', 'icon': Icons.payments_outlined, 'color': Colors.green, 'screen': const CaComptantScreen()},
      {'title': 'CA Crédit', 'icon': Icons.credit_card_outlined, 'color': Colors.blue, 'screen': const CaCreditScreen()},
      {'title': 'CA Global', 'icon': Icons.receipt_long_outlined, 'color': Colors.amber.shade700, 'screen': const CaGlobalScreen()},
      {'title': 'Evolution Stock', 'icon': Icons.ssid_chart_outlined, 'color': Colors.brown, 'screen': const EvolutionStockScreen()},
      {'title': 'Fiche Article', 'icon': Icons.article_outlined, 'color': Colors.cyan, 'screen': const FicheArticleScreen()},
      {'title': 'Fournisseurs', 'icon': Icons.people_alt_outlined, 'color': Colors.teal, 'screen': const FournisseursScreen()},
      {'title': 'TdB: Analyses', 'icon': Icons.analytics_outlined, 'color': Colors.pinkAccent, 'screen': const TableauBordAnalyseMenuScreen()},
      {'title': 'TdB: Ratios', 'icon': Icons.compare_arrows_outlined, 'color': Colors.lime.shade700, 'screen': const TableauBordRatioScreen()},
      {'title': 'Valorisation', 'icon': Icons.inventory_2_outlined, 'color': Colors.purple, 'screen': const ValorisationScreen()},
    ];

    menuItems.sort((a, b) => a['title'].compareTo(b['title']));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prestige'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_applications_outlined),
            tooltip: 'Configuration IP',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildWelcomeCard(context, ipProvider, _officineData, _isOfficineLoading),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
              child: Text(
                'Fonctionnalités',
                style: GoogleFonts.lato(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12.0, mainAxisSpacing: 12.0, childAspectRatio: 1.1,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final item = menuItems[index];
                  return _buildMenuButton(context, title: item['title'], icon: item['icon'], color: item['color'],
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => item['screen'])),
                  );
                },
                childCount: menuItems.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, IpConfigProvider ipProvider, Officine? officineData, bool isLoading) {
    final theme = Theme.of(context);

    String welcomeMessage = 'Bienvenue';
    if (isLoading) {
      welcomeMessage = 'Chargement...';
    } else if (officineData != null && officineData.fullName.isNotEmpty) {
      welcomeMessage = 'Bienvenue ${officineData.fullName}';
    }

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.primaryColor, theme.colorScheme.secondary],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(color: theme.primaryColor.withAlpha(77), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            welcomeMessage,
            style: GoogleFonts.lato(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (officineData != null)
            Text(
              officineData.nomComplet,
              style: GoogleFonts.lato(fontSize: 16, color: Colors.white.withAlpha(230)),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                ipProvider.useLocalIp ? 'Mode Local' : 'Mode Distant',
                style: GoogleFonts.lato(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Switch(
                value: ipProvider.useLocalIp,
                onChanged: (value) {
                  if (!value && (ipProvider.remoteIp.isEmpty || ipProvider.remoteIp == AppConstants.defaultRemoteIp)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('L\'adresse IP distante n\'est pas configurée.'),
                      backgroundColor: Colors.orange,
                    ));
                    return;
                  }
                  ipProvider.setUseLocalIp(value);
                },
                activeColor: Colors.white,
                activeTrackColor: Colors.white.withAlpha(128),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.black.withAlpha(51),
              ),
            ],
          )
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
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 4))
          ],
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
