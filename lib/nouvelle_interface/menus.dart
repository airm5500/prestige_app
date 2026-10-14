// lib/nouvelle_interface/menus.dart
// Les menus de l'accueil d'origine, rangés par familles (présentations A et B) et par questions métier
// (présentation C). Les titres sont ceux de l'ancien accueil : ils servent aussi de clé à « Personnaliser
// l'accueil » (ordre et menus masqués, partagés par les deux interfaces). Chaque menu ouvre l'écran du module
// d'origine (mêmes données, mêmes routes serveur), présenté avec le thème de la nouvelle interface, sauf les
// modules refaits (lib/nouvelle_interface/modules/), qui ouvrent leur nouvel écran (mêmes données, même logique) :
// lot 1 (Rapport d'Activité, Détail CA, Analyse Article, Fiche Article, Suivi Péremption, Suivi Crédit) et lot 2,
// achats et stock (Suggestions, État de Stock, Visualisation BL, État Contrôle Achat, Retours fournisseurs,
// Évolution stock, Analyse Saisies BL, Suivi Ajustements) et lot 3, analyses (Tableau : Analyses, Tableau : Ratios,
// Suivi 20/80, Stat TVA, Marge Produits Vendus, CA Crédit, CA Global) et lot 4, le reste (Récap de caisse, Achats Fourn.,
// Fichier Journal, Annulation Ventes ; seule Présences garde son écran, déjà refait). Nouveaux menus réservés à l'administrateur et au
// pharmacien : vague 1 (vague1/), vague 2 (vague2/), vague 3 (vague3/ : Pointage BL, Avis, Rappels traitement).
// « Fournisseurs » (liste des fournisseurs) n'est plus proposé dans la nouvelle interface (demande du
// pharmacien) ; il reste dans l'ancienne.
import 'package:flutter/material.dart';

import '../presences/presences_screen.dart';
import '../providers/home_settings_provider.dart';
import 'charte.dart';
import 'modules/achats_fournisseurs_nouveau.dart';
import 'modules/ajustements_nouveau.dart';
import 'modules/analyse_bl_nouveau.dart';
import 'modules/annulation_ventes_nouveau.dart';
import 'modules/articles_nouveau.dart';
import 'modules/ca_credit_nouveau.dart';
import 'modules/ca_global_nouveau.dart';
import 'modules/controle_achat_nouveau.dart';
import 'modules/detail_ca_nouveau.dart';
import 'modules/etat_stock_nouveau.dart';
import 'modules/evolution_stock_nouveau.dart';
import 'modules/fichier_journal_nouveau.dart';
import 'modules/marge_produits_nouveau.dart';
import 'modules/rapport_activite_nouveau.dart';
import 'modules/recap_caisse_nouveau.dart';
import 'modules/retours_fournisseurs_nouveau.dart';
import 'modules/stat_tva_nouveau.dart';
import 'modules/suivi_2080_nouveau.dart';
import 'modules/suggestions_nouveau.dart';
import 'modules/suivi_credit_nouveau.dart';
import 'modules/suivi_peremption_nouveau.dart';
import 'modules/tableau_analyses_nouveau.dart';
import 'modules/tableau_ratios_nouveau.dart';
import 'modules/visualisation_bl_nouveau.dart';
import 'vague1/alertes_vague1.dart';
import 'vague1/journaux_vague1.dart';
import 'vague1/profil_acces.dart';
import 'vague1/valorisation_vague1.dart';
import 'vague2/ca_zone_vague2.dart';
import 'vague2/garde_vague2.dart';
import 'vague2/previsions_vague2.dart';
import 'vague3/avis_vague3.dart';
import 'vague3/pointage_vague3.dart';
import 'vague3/rappels_vague3.dart';

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

  /// Réservé à l'administrateur et au pharmacien (nouveaux menus et Valorisation, vague1/profil_acces.dart).
  final bool responsables;
  const MenuModule(this.titre, this.sousTitre, this.icone, this.famille, this.question, this.ecran, {this.responsables = false});

  /// Format attendu par l'écran « Personnaliser l'accueil » (commun aux deux interfaces).
  Map<String, dynamic> get pourPersonnalisation => {'title': titre, 'icon': icone, 'color': Charte.navy};
}

final menusModules = <MenuModule>[
  MenuModule('Détail CA', 'Comptant, crédit, modes de paiement', Icons.payments_outlined, Famille.ventes, Question.vendu,
      () => const DetailCaNouveau()),
  MenuModule('CA Crédit', 'Ventes à crédit par client', Icons.credit_card_outlined, Famille.credits, Question.credits,
      () => const CaCreditNouveau()),
  MenuModule('CA Global', 'Chiffre d\'affaires jour par jour', Icons.receipt_long_outlined, Famille.ventes, Question.vendu,
      () => const CaGlobalNouveau()),
  MenuModule('Récap de caisse', 'Encaissements par caissier et période', Icons.point_of_sale_outlined, Famille.ventes,
      Question.vendu, () => const RecapCaisseNouveau()),
  MenuModule('Rapport d\'Activité', 'Synthèse ventes, achats, règlements', Icons.summarize_outlined, Famille.ventes,
      Question.vendu, () => const RapportActiviteNouveau()),
  MenuModule('Fichier Journal', 'Actions des utilisateurs', Icons.history_edu_outlined, Famille.equipe, Question.equipe,
      () => const FichierJournalNouveau()),
  MenuModule('Etat Contrôle Achat', 'Contrôle des bons sur l\'année', Icons.fact_check_outlined, Famille.fournisseurs,
      Question.fournisseurs, () => const ControleAchatNouveau()),
  MenuModule('Marge Produits Vendus', 'Marge par produit', Icons.percent_outlined, Famille.analyses, Question.vendu,
      () => const MargeProduitsNouveau()),
  MenuModule('Analyse Saisies BL', 'Saisie des bons de livraison', Icons.document_scanner_outlined, Famille.fournisseurs,
      Question.fournisseurs, () => const AnalyseBlNouveau()),
  MenuModule('Suivi Crédit', 'Reste à payer par client', Icons.request_quote_outlined, Famille.credits, Question.credits,
      () => const SuiviCreditNouveau()),
  MenuModule('Tableau: Analyses', 'Évolutions des ventes et des achats', Icons.analytics_outlined, Famille.analyses,
      Question.vendu, () => const TableauAnalysesNouveau()),
  MenuModule('Tableau: Ratios', 'Ratios achats / ventes', Icons.compare_arrows_outlined, Famille.analyses, Question.vendu,
      () => const TableauRatiosNouveau()),
  MenuModule('Stat TVA', 'Ventes par taux de TVA', Icons.pie_chart_outline, Famille.ventes, Question.vendu,
      () => const StatTvaNouveau()),
  MenuModule('Analyse Article', 'Ventes, stock et réserve d\'un article', Icons.query_stats, Famille.analyses,
      Question.commander, () => const AnalyseArticleNouveau()),
  MenuModule('Fiche Article', 'Prix, stock, emplacement', Icons.article_outlined, Famille.analyses, Question.commander,
      () => const FicheArticleNouveau()),
  MenuModule('Suivi 20/80', 'Articles qui font le chiffre', Icons.star_border, Famille.analyses, Question.commander,
      () => const Suivi2080Nouveau()),
  MenuModule('Suivi Péremption', 'Produits bientôt périmés', Icons.warning_amber_rounded, Famille.stock, Question.commander,
      () => const SuiviPeremptionNouveau()),
  MenuModule('Evolution Stock', 'Valeur du stock dans le temps', Icons.ssid_chart_outlined, Famille.stock, Question.commander,
      () => const EvolutionStockNouveau()),
  MenuModule('Valorisation', 'Valeur du stock à une date', Icons.inventory_2_outlined, Famille.stock, Question.commander,
      () => const ValorisationVague1(), responsables: true), // réservée (décision du pharmacien, 3.1.0)
  MenuModule('Suivi Ajustements', 'Corrections de stock', Icons.rule_folder_outlined, Famille.stock, Question.commander,
      () => const AjustementsNouveau()),
  MenuModule('Achats Fourn.', 'Achats par fournisseur', Icons.shopping_cart_checkout_outlined, Famille.fournisseurs,
      Question.fournisseurs, () => const AchatsFournisseursNouveau()),
  MenuModule('Retours Fournisseurs', 'Retours et avoirs', Icons.assignment_return_outlined, Famille.fournisseurs,
      Question.fournisseurs, () => const RetoursFournisseursNouveau()),
  MenuModule('Suggestions', 'Suggestions de commande', Icons.lightbulb_outline, Famille.stock, Question.commander,
      () => const SuggestionsNouveau()),
  MenuModule('Annulation Ventes', 'Annuler une vente (protégé)', Icons.cancel_presentation_outlined, Famille.ventes,
      Question.vendu, () => const AnnulationVentesNouveau()),
  MenuModule('Etat de Stock', 'Stock par rayon et grossiste', Icons.warehouse_outlined, Famille.stock, Question.commander,
      () => const EtatStockNouveau()),
  MenuModule('Visualisation BL', 'Bons de livraison du jour', Icons.receipt_outlined, Famille.fournisseurs,
      Question.fournisseurs, () => const VisualisationBlNouveau()),
  MenuModule('Présences', 'Présence du jour, période, pointage', Icons.badge_outlined, Famille.equipe, Question.equipe,
      () => const PresencesScreen()),
  // Vague 1 des nouveaux menus (lecture seule) : administrateur et pharmacien seulement.
  MenuModule('Alertes', 'Ruptures, péremptions, suggestions, négatifs', Icons.notifications_active_outlined, Famille.stock,
      Question.commander, () => const AlertesScreen(), responsables: true),
  MenuModule('Retraits et abandons', 'Produits retirés, ventes abandonnées', Icons.remove_shopping_cart_outlined, Famille.ventes,
      Question.equipe, () => const RetraitsAbandonsScreen(), responsables: true),
  MenuModule('Ventes modifiées', 'Produits, client ou date changés après coup', Icons.edit_note_outlined, Famille.ventes,
      Question.equipe, () => const VentesModifieesScreen(), responsables: true),
  // Vague 2 (lecture seule, 3.2.0) : administrateur et pharmacien seulement. Le Pilotage est un onglet de la barre
  // du bas (accueil_nouveau.dart), pas un menu.
  MenuModule('Prévisions', 'Quoi commander, ruptures, saisonnalité', Icons.auto_graph, Famille.stock, Question.commander,
      () => const PrevisionsScreen(), responsables: true),
  MenuModule('Analyse de garde', 'Chiffres, heures, produits et vendeurs d\'une garde', Icons.nightlight_outlined, Famille.analyses,
      Question.vendu, () => const AnalyseGardeScreen(), responsables: true),
  MenuModule('CA emplacement / famille', 'Chiffre d\'affaires comparé par rayon et famille', Icons.stacked_bar_chart, Famille.analyses,
      Question.vendu, () => const CaZoneScreen(), responsables: true),
  // Vague 3 (écritures légères dont le droit est vérifié par le serveur, 3.4.0) : administrateur et pharmacien
  // seulement. Aucun envoi de message (WhatsApp, SMS, e-mail) depuis le mobile.
  MenuModule('Pointage BL', 'Pointer les BL et avoirs d\'un grossiste', Icons.playlist_add_check, Famille.fournisseurs,
      Question.fournisseurs, () => const PointageBlScreen(), responsables: true),
  MenuModule('Avis', 'Avis des clients : lire, traiter, analyser', Icons.reviews_outlined, Famille.credits, Question.equipe,
      () => const AvisScreen(), responsables: true),
  MenuModule('Rappels traitement', 'Traitements habituels à préparer', Icons.medication_outlined, Famille.credits,
      Question.commander, () => const RappelsScreen(), responsables: true),
];

/// Menus auxquels le compte connecté a droit : les menus réservés (vague 1) seulement pour l'administrateur et le
/// pharmacien. Sert à l'accueil, à la recherche et à « Personnaliser l'accueil ».
List<MenuModule> menusAutorises() {
  final responsable = ProfilAcces.responsable;
  return [for (final m in menusModules) if (responsable || !m.responsables) m];
}

/// Menus affichés : ordre de « Personnaliser l'accueil », menus masqués et menus non autorisés retirés.
List<MenuModule> menusVisibles(HomeSettingsProvider reglages) {
  final ordre = {for (var i = 0; i < reglages.featureOrder.length; i++) reglages.featureOrder[i]: i};
  int rang(MenuModule m) => ordre[m.titre] ?? 1000 + menusModules.indexOf(m);
  final tries = menusAutorises()..sort((a, b) => rang(a).compareTo(rang(b)));
  return [for (final m in tries) if (!reglages.disabledFeatures.contains(m.titre)) m];
}

/// Menus de [famille] parmi [menus] (ordre conservé).
List<MenuModule> deLaFamille(List<MenuModule> menus, Famille famille) => [for (final m in menus) if (m.famille == famille) m];

/// Ouvre le module.
void ouvrirModule(BuildContext context, MenuModule m) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => m.ecran()));

/// Familles de l'onglet « Analyses ».
const famillesAnalyses = [Famille.analyses, Famille.ventes, Famille.credits];
