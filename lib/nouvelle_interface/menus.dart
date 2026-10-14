// lib/nouvelle_interface/menus.dart
// Les menus de l'accueil d'origine, rangés par familles (présentations A et B) et par questions métier
// (présentation C). Les titres sont ceux de l'ancien accueil : ils servent aussi de clé à « Personnaliser
// l'accueil » (ordre et menus masqués, partagés par les deux interfaces). Chaque menu ouvre l'écran du module
// d'origine (mêmes données, mêmes routes serveur), présenté avec le thème de la nouvelle interface, sauf les
// modules refaits (lot 1, lib/nouvelle_interface/modules/ : Rapport d'Activité, Détail CA, Analyse Article,
// Fiche Article, Suivi Péremption, Suivi Crédit), qui ouvrent leur nouvel écran (mêmes données, même logique).
// « Fournisseurs » (liste des fournisseurs) n'est plus proposé dans la nouvelle interface (demande du
// pharmacien) ; il reste dans l'ancienne.
import 'package:flutter/material.dart';

import '../presences/presences_screen.dart';
import '../providers/home_settings_provider.dart';
import '../screens/achats_fournisseurs_screen.dart';
import '../screens/analyse_saisie_bl_screen.dart';
import '../screens/annulation_vente_screen.dart';
import '../screens/ca_credit_screen.dart';
import '../screens/ca_global_screen.dart';
import '../screens/etat_controle_achat_screen.dart';
import '../screens/etat_stock_screen.dart';
import '../screens/evolution_stock_screen.dart';
import '../screens/fichier_journal_screen.dart';
import '../screens/marge_produits_vendus_screen.dart';
import '../screens/recap_caisse_screen.dart';
import '../screens/retours_fournisseurs_screen.dart';
import '../screens/stat_tva_screen.dart';
import '../screens/suggestion_list_screen.dart';
import '../screens/suivi_20_80_screen.dart';
import '../screens/suivi_ajustement_screen.dart';
import '../screens/tableau_bord_analyse_menu_screen.dart';
import '../screens/tableau_bord_ratio_screen.dart';
import '../screens/valorisation_screen.dart';
import '../screens/visualisation_bl_screen.dart';
import 'charte.dart';
import 'modules/articles_nouveau.dart';
import 'modules/detail_ca_nouveau.dart';
import 'modules/rapport_activite_nouveau.dart';
import 'modules/suivi_credit_nouveau.dart';
import 'modules/suivi_peremption_nouveau.dart';

enum Famille { ventes, credits, analyses, stock, fournisseurs, equipe }

extension FamilleTextes on Famille {
  String get libelle => switch (this) {
        Famille.ventes => 'Ventes & caisse',
        Famille.credits => 'Crédits & clients',
        Famille.analyses => 'Analyses',
        Famille.stock => 'Stock',
        Famille.fournisseurs => 'Fournisseurs & achats',
        Famille.equipe => 'Équipe',
      };
}

/// Questions de la présentation C (« Que voulez-vous savoir ? »).
enum Question { vendu, credits, commander, fournisseurs, equipe }

extension QuestionTextes on Question {
  String get titre => switch (this) {
        Question.vendu => 'Combien ai-je vendu ?',
        Question.credits => 'Qui me doit de l\'argent ?',
        Question.commander => 'Que dois-je commander ?',
        Question.fournisseurs => 'Mes fournisseurs',
        Question.equipe => 'Mon équipe',
      };

  String get detail => switch (this) {
        Question.vendu => 'CA, marge, caisse, rapport d\'activité',
        Question.credits => 'Crédits clients et tiers payants',
        Question.commander => 'Stock, périmés, suggestions',
        Question.fournisseurs => 'Achats, BL, retours',
        Question.equipe => 'Présences, retards, journal',
      };

  IconData get icone => switch (this) {
        Question.vendu => Icons.payments_outlined,
        Question.credits => Icons.credit_card_outlined,
        Question.commander => Icons.inventory_2_outlined,
        Question.fournisseurs => Icons.local_shipping_outlined,
        Question.equipe => Icons.badge_outlined,
      };

  Color get fond => switch (this) {
        Question.vendu => Charte.vertClair,
        Question.credits => Charte.ambreClair,
        Question.commander => Charte.rougeClair,
        Question.fournisseurs => Charte.bleuClair,
        Question.equipe => Charte.grisClair,
      };
}

class MenuModule {
  /// Titre (identique à l'ancien accueil).
  final String titre;
  final String sousTitre;
  final IconData icone;
  final Famille famille;
  final Question question;
  final Widget Function() ecran;
  const MenuModule(this.titre, this.sousTitre, this.icone, this.famille, this.question, this.ecran);

  /// Format attendu par l'écran « Personnaliser l'accueil » (commun aux deux interfaces).
  Map<String, dynamic> get pourPersonnalisation => {'title': titre, 'icon': icone, 'color': Charte.navy};
}

final menusModules = <MenuModule>[
  MenuModule('Détail CA', 'Comptant, crédit, modes de paiement', Icons.payments_outlined, Famille.ventes, Question.vendu,
      () => const DetailCaNouveau()),
  MenuModule('CA Crédit', 'Ventes à crédit par client', Icons.credit_card_outlined, Famille.credits, Question.credits,
      () => const CaCreditScreen()),
  MenuModule('CA Global', 'Chiffre d\'affaires jour par jour', Icons.receipt_long_outlined, Famille.ventes, Question.vendu,
      () => const CaGlobalScreen()),
  MenuModule('Récap de caisse', 'Encaissements par caissier et période', Icons.point_of_sale_outlined, Famille.ventes,
      Question.vendu, () => const RecapCaisseScreen()),
  MenuModule('Rapport d\'Activité', 'Synthèse ventes, achats, règlements', Icons.summarize_outlined, Famille.ventes,
      Question.vendu, () => const RapportActiviteNouveau()),
  MenuModule('Fichier Journal', 'Actions des utilisateurs', Icons.history_edu_outlined, Famille.equipe, Question.equipe,
      () => const FichierJournalScreen()),
  MenuModule('Etat Contrôle Achat', 'Contrôle des bons sur l\'année', Icons.fact_check_outlined, Famille.fournisseurs,
      Question.fournisseurs, () => const EtatControleAchatScreen()),
  MenuModule('Marge Produits Vendus', 'Marge par produit', Icons.percent_outlined, Famille.analyses, Question.vendu,
      () => const MargeProduitsVendusScreen()),
  MenuModule('Analyse Saisies BL', 'Saisie des bons de livraison', Icons.document_scanner_outlined, Famille.fournisseurs,
      Question.fournisseurs, () => const AnalyseSaisieBlScreen()),
  MenuModule('Suivi Crédit', 'Reste à payer par client', Icons.request_quote_outlined, Famille.credits, Question.credits,
      () => const SuiviCreditNouveau()),
  MenuModule('Tableau: Analyses', 'Évolutions des ventes et des achats', Icons.analytics_outlined, Famille.analyses,
      Question.vendu, () => const TableauBordAnalyseMenuScreen()),
  MenuModule('Tableau: Ratios', 'Ratios achats / ventes', Icons.compare_arrows_outlined, Famille.analyses, Question.vendu,
      () => const TableauBordRatioScreen()),
  MenuModule('Stat TVA', 'Ventes par taux de TVA', Icons.pie_chart_outline, Famille.ventes, Question.vendu,
      () => const StatTvaScreen()),
  MenuModule('Analyse Article', 'Ventes, stock et réserve d\'un article', Icons.query_stats, Famille.analyses,
      Question.commander, () => const AnalyseArticleNouveau()),
  MenuModule('Fiche Article', 'Prix, stock, emplacement', Icons.article_outlined, Famille.analyses, Question.commander,
      () => const FicheArticleNouveau()),
  MenuModule('Suivi 20/80', 'Articles qui font le chiffre', Icons.star_border, Famille.analyses, Question.commander,
      () => const Suivi2080Screen()),
  MenuModule('Suivi Péremption', 'Produits bientôt périmés', Icons.warning_amber_rounded, Famille.stock, Question.commander,
      () => const SuiviPeremptionNouveau()),
  MenuModule('Evolution Stock', 'Valeur du stock dans le temps', Icons.ssid_chart_outlined, Famille.stock, Question.commander,
      () => const EvolutionStockScreen()),
  MenuModule('Valorisation', 'Valeur du stock à une date', Icons.inventory_2_outlined, Famille.stock, Question.commander,
      () => const ValorisationScreen()),
  MenuModule('Suivi Ajustements', 'Corrections de stock', Icons.rule_folder_outlined, Famille.stock, Question.commander,
      () => const SuiviAjustementScreen()),
  MenuModule('Achats Fourn.', 'Achats par fournisseur', Icons.shopping_cart_checkout_outlined, Famille.fournisseurs,
      Question.fournisseurs, () => const AchatsFournisseursScreen()),
  MenuModule('Retours Fournisseurs', 'Retours et avoirs', Icons.assignment_return_outlined, Famille.fournisseurs,
      Question.fournisseurs, () => const RetoursFournisseursScreen()),
  MenuModule('Suggestions', 'Suggestions de commande', Icons.lightbulb_outline, Famille.stock, Question.commander,
      () => const SuggestionListScreen()),
  MenuModule('Annulation Ventes', 'Annuler une vente (protégé)', Icons.cancel_presentation_outlined, Famille.ventes,
      Question.vendu, () => const AnnulationVenteScreen()),
  MenuModule('Etat de Stock', 'Stock par rayon et grossiste', Icons.warehouse_outlined, Famille.stock, Question.commander,
      () => const EtatStockScreen()),
  MenuModule('Visualisation BL', 'Bons de livraison du jour', Icons.receipt_outlined, Famille.fournisseurs,
      Question.fournisseurs, () => const VisualisationBlScreen()),
  MenuModule('Présences', 'Présence du jour, période, pointage', Icons.badge_outlined, Famille.equipe, Question.equipe,
      () => const PresencesScreen()),
];

/// Menus affichés : ordre de « Personnaliser l'accueil », menus masqués retirés.
List<MenuModule> menusVisibles(HomeSettingsProvider reglages) {
  final ordre = {for (var i = 0; i < reglages.featureOrder.length; i++) reglages.featureOrder[i]: i};
  int rang(MenuModule m) => ordre[m.titre] ?? 1000 + menusModules.indexOf(m);
  final tries = [...menusModules]..sort((a, b) => rang(a).compareTo(rang(b)));
  return [for (final m in tries) if (!reglages.disabledFeatures.contains(m.titre)) m];
}

/// Menus de [famille] parmi [menus] (ordre conservé).
List<MenuModule> deLaFamille(List<MenuModule> menus, Famille famille) => [for (final m in menus) if (m.famille == famille) m];

/// Ouvre le module.
void ouvrirModule(BuildContext context, MenuModule m) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => m.ecran()));

/// Familles de l'onglet « Analyses ».
const famillesAnalyses = [Famille.analyses, Famille.ventes, Famille.credits];
