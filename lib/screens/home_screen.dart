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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final ipProvider = Provider.of<IpConfigProvider>(context);

    final AppUser? currentUser = authProvider.user;
    final String userName = currentUser?.fullName ?? 'Utilisateur';
    final String officineName = currentUser?.officineName ?? 'Prestige App';

    final List<Map<String, dynamic>> menuItems = [
      {'title': 'Analyse Article', 'icon': Icons.pie_chart_outline_rounded, 'color': Colors.indigo, 'screen': const AnalyseArticleScreen()},
      {'title': 'Achats Fourn.', 'icon': Icons.shopping_cart_checkout_outlined, 'color': Colors.deepOrange, 'screen': const AchatsFournisseursScreen()},
      {'title': 'CA Comptant', 'icon': Icons.payments_outlined, 'color': Colors.green, 'screen': const CaComptantScreen()},
      {'title': 'CA Crédit', 'icon': Icons.credit_card_outlined, 'color': Colors.blue, 'screen': const CaCreditScreen()},
      {'title': 'CA Global', 'icon': Icons.receipt_long_outlined, 'color': Colors.amber.shade700, 'screen': const CaGlobalScreen()},
      {'title': 'Evolution Stock', 'icon': Icons.ssid_chart_outlined, 'color': Colors.brown, 'screen': const EvolutionStockScreen()},
      {'title': 'Fiche Article', 'icon': Icons.article_outlined, 'color': Colors.cyan, 'screen': const FicheArticleScreen()},
      {'title': 'Fournisseurs', 'icon': Icons.people_alt_outlined, 'color': Colors.teal, 'screen': const FournisseursScreen()},
      {'title': 'Tableau: Analyses', 'icon': Icons.analytics_outlined, 'color': Colors.pinkAccent, 'screen': const TableauBordAnalyseMenuScreen()},
      {'title': 'Tableau: Ratios', 'icon': Icons.compare_arrows_outlined, 'color': Colors.lime.shade700, 'screen': const TableauBordRatioScreen()},
      {'title': 'Suivi Crédit','icon': Icons.request_quote_outlined,'color': Colors.redAccent,'screen': const SuiviCreditScreen()},
      {'title': 'Valorisation', 'icon': Icons.inventory_2_outlined, 'color': Colors.purple, 'screen': const ValorisationScreen()},
    ];

    menuItems.sort((a, b) => a['title'].compareTo(b['title']));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prestige'), // Titre simple
        actions: [
          // CORRECTION: Interrupteur de mode de retour dans la barre d'outils
          Tooltip(
            message: ipProvider.useLocalIp ? 'Passer en mode Distant' : 'Passer en mode Local',
            child: Row(
              children: [
                Text(ipProvider.useLocalIp ? 'Local' : 'Distant', style: const TextStyle(color: Colors.white)),
                Switch(
                  value: ipProvider.useLocalIp,
                  onChanged: (value) {
                    if (!value && (ipProvider.remoteIp.isEmpty || ipProvider.remoteIp == AppConstants.defaultRemoteIp)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('L\'adresse IP distante n\'est pas configurée.'), backgroundColor: Colors.orange));
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
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildWelcomeCard(context, userName, officineName),
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

  Widget _buildWelcomeCard(BuildContext context, String userName, String officineName) {
    final theme = Theme.of(context);

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
          // CORRECTION: Affiche le nom de la pharmacie en grand
          Text(
            officineName,
            style: GoogleFonts.lato(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // CORRECTION: Message de bienvenue mis à jour
          Text(
            'Bienvenu(e) $userName',
            style: GoogleFonts.lato(
                fontSize: 16, color: Colors.white.withAlpha(230), fontWeight: FontWeight.w500),
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
