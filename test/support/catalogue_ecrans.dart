// Catalogue des écrans testés : modules de l'accueil (titre de la tuile, titre de la barre, constructeur) et
// états supplémentaires. À COMPLÉTER quand un module est ajouté à l'accueil (voir test/README.md) : le test e2e
// « chaque module de l'accueil s'ouvre et se referme » échoue tant que le nouveau module n'est pas ici, et le test
// d'ergonomie le rend alors automatiquement à toutes les tailles d'écran.
import 'package:flutter/widgets.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/modules/ajustements_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/analyse_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_global_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/controle_achat_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/etat_stock_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/evolution_stock_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/marge_produits_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/rapport_activite_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/retours_fournisseurs_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/stat_tva_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_2080_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_peremption_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_analyses_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_ratios_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/visualisation_bl_nouveau.dart';
import 'package:prestige_app/presences/presences_screen.dart';
import 'package:prestige_app/screens/achats_fournisseurs_screen.dart';
import 'package:prestige_app/screens/analyse_article_screen.dart';
import 'package:prestige_app/screens/analyse_saisie_bl_screen.dart';
import 'package:prestige_app/screens/annulation_vente_screen.dart';
import 'package:prestige_app/screens/ca_comptant_screen.dart';
import 'package:prestige_app/screens/ca_credit_screen.dart';
import 'package:prestige_app/screens/ca_global_screen.dart';
import 'package:prestige_app/screens/etat_controle_achat_screen.dart';
import 'package:prestige_app/screens/etat_stock_screen.dart';
import 'package:prestige_app/screens/evolution_stock_screen.dart';
import 'package:prestige_app/screens/fiche_article_screen.dart';
import 'package:prestige_app/screens/fichier_journal_screen.dart';
import 'package:prestige_app/screens/fournisseurs_screen.dart';
import 'package:prestige_app/screens/marge_produits_vendus_screen.dart';
import 'package:prestige_app/screens/rapport_activite_screen.dart';
import 'package:prestige_app/screens/recap_caisse_screen.dart';
import 'package:prestige_app/screens/retours_fournisseurs_screen.dart';
import 'package:prestige_app/screens/stat_tva_screen.dart';
import 'package:prestige_app/screens/suggestion_list_screen.dart';
import 'package:prestige_app/screens/suivi_20_80_screen.dart';
import 'package:prestige_app/screens/suivi_ajustement_screen.dart';
import 'package:prestige_app/screens/suivi_credit_screen.dart';
import 'package:prestige_app/screens/suivi_peremption_screen.dart';
import 'package:prestige_app/screens/tableau_bord_analyse_menu_screen.dart';
import 'package:prestige_app/screens/tableau_bord_ratio_screen.dart';
import 'package:prestige_app/screens/valorisation_screen.dart';
import 'package:prestige_app/screens/visualisation_bl_screen.dart';

class ModuleAccueil {
  final String tuile;
  final String titreEcran;

  /// Construit l'écran du module (rendu seul par le test d'ergonomie).
  final Widget Function({Key? key}) ecran;
  const ModuleAccueil(this.tuile, this.titreEcran, this.ecran);
}

/// Dans l'ordre d'origine de l'accueil (6 tuiles par page).
const modulesAccueil = <ModuleAccueil>[
  ModuleAccueil('Détail CA', 'Détail CA', CaComptantScreen.new),
  ModuleAccueil('CA Crédit', 'Ventes à Crédit', CaCreditScreen.new),
  ModuleAccueil('CA Global', 'CA Global', CaGlobalScreen.new),
  ModuleAccueil('Récap de caisse', 'Récap de caisse', RecapCaisseScreen.new),
  ModuleAccueil('Rapport d\'Activité', 'Rapport d\'Activité', RapportActiviteScreen.new),
  ModuleAccueil('Fichier Journal', 'Fichier Journal', FichierJournalScreen.new),
  ModuleAccueil('Etat Contrôle Achat', 'Etat de Contrôle des Achats', EtatControleAchatScreen.new),
  ModuleAccueil('Marge Produits Vendus', 'Marge Produits Vendus', MargeProduitsVendusScreen.new),
  ModuleAccueil('Analyse Saisies BL', 'Analyse des Saisies BL', AnalyseSaisieBlScreen.new),
  ModuleAccueil('Suivi Crédit', 'Suivi des Crédits', SuiviCreditScreen.new),
  ModuleAccueil('Tableau: Analyses', 'Tableau: Menu Analyses', TableauBordAnalyseMenuScreen.new),
  ModuleAccueil('Tableau: Ratios', 'Tableau: Ratios Achats/Ventes', TableauBordRatioScreen.new),
  ModuleAccueil('Stat TVA', 'Statistiques TVA', StatTvaScreen.new),
  ModuleAccueil('Analyse Article', 'Analyse Article', AnalyseArticleScreen.new),
  ModuleAccueil('Fiche Article', 'Fiche Article', FicheArticleScreen.new),
  ModuleAccueil('Suivi 20/80', 'Suivi 20/80', Suivi2080Screen.new),
  ModuleAccueil('Suivi Péremption', 'Suivi Péremption', SuiviPeremptionScreen.new),
  ModuleAccueil('Evolution Stock', 'Évolution du Stock', EvolutionStockScreen.new),
  ModuleAccueil('Valorisation', 'Valorisation du Stock', ValorisationScreen.new),
  ModuleAccueil('Suivi Ajustements', 'Suivi des Ajustements', SuiviAjustementScreen.new),
  ModuleAccueil('Fournisseurs', 'Liste des Fournisseurs', FournisseursScreen.new),
  ModuleAccueil('Achats Fourn.', 'Achats Fournisseurs', AchatsFournisseursScreen.new),
  ModuleAccueil('Retours Fournisseurs', 'Retours Fournisseurs', RetoursFournisseursScreen.new),
  ModuleAccueil('Suggestions', 'Suggestions de Commande', SuggestionListScreen.new),
  ModuleAccueil('Annulation Ventes', 'Annulation de Ventes', AnnulationVenteScreen.new),
  ModuleAccueil('Etat de Stock', 'État de Stock', EtatStockScreen.new),
  ModuleAccueil('Visualisation BL', 'Visualisation BL', VisualisationBlScreen.new),
  ModuleAccueil('Présences', 'Présence du jour', PresencesScreen.new),
];

/// Modules refaits dans la nouvelle interface (lot 1) : écran d'origine (ancienne interface) et nouvel écran
/// (nouvelle interface), même titre de barre. Les tests de non-régression comparent leurs requêtes et leurs chiffres.
class ModuleLot1 {
  final String tuile;
  final String titreEcran;
  final Widget Function() ancien;
  final Widget Function() nouveau;
  final Type typeNouveau;
  const ModuleLot1(this.tuile, this.titreEcran, this.ancien, this.nouveau, this.typeNouveau);
}

final modulesLot1 = <ModuleLot1>[
  ModuleLot1('Rapport d\'Activité', 'Rapport d\'Activité', () => const RapportActiviteScreen(), () => const RapportActiviteNouveau(),
      RapportActiviteNouveau),
  ModuleLot1('Détail CA', 'Détail CA', () => const CaComptantScreen(), () => const DetailCaNouveau(), DetailCaNouveau),
  ModuleLot1('Analyse Article', 'Analyse Article', () => const AnalyseArticleScreen(), () => const AnalyseArticleNouveau(), AnalyseArticleNouveau),
  ModuleLot1('Fiche Article', 'Fiche Article', () => const FicheArticleScreen(), () => const FicheArticleNouveau(), FicheArticleNouveau),
  ModuleLot1('Suivi Péremption', 'Suivi Péremption', () => const SuiviPeremptionScreen(), () => const SuiviPeremptionNouveau(),
      SuiviPeremptionNouveau),
  ModuleLot1('Suivi Crédit', 'Suivi des Crédits', () => const SuiviCreditScreen(), () => const SuiviCreditNouveau(), SuiviCreditNouveau),
];

/// Modules refaits du lot 2 (achats et stock) : même déclaration que le lot 1.
final modulesLot2 = <ModuleLot1>[
  ModuleLot1('Suggestions', 'Suggestions de Commande', () => const SuggestionListScreen(), () => const SuggestionsNouveau(), SuggestionsNouveau),
  ModuleLot1('Etat de Stock', 'État de Stock', () => const EtatStockScreen(), () => const EtatStockNouveau(), EtatStockNouveau),
  ModuleLot1('Visualisation BL', 'Visualisation BL', () => const VisualisationBlScreen(), () => const VisualisationBlNouveau(), VisualisationBlNouveau),
  ModuleLot1('Etat Contrôle Achat', 'Etat de Contrôle des Achats', () => const EtatControleAchatScreen(), () => const ControleAchatNouveau(),
      ControleAchatNouveau),
  ModuleLot1('Retours Fournisseurs', 'Retours Fournisseurs', () => const RetoursFournisseursScreen(), () => const RetoursFournisseursNouveau(),
      RetoursFournisseursNouveau),
  ModuleLot1('Evolution Stock', 'Évolution du Stock', () => const EvolutionStockScreen(), () => const EvolutionStockNouveau(), EvolutionStockNouveau),
  ModuleLot1('Analyse Saisies BL', 'Analyse des Saisies BL', () => const AnalyseSaisieBlScreen(), () => const AnalyseBlNouveau(), AnalyseBlNouveau),
  ModuleLot1('Suivi Ajustements', 'Suivi des Ajustements', () => const SuiviAjustementScreen(), () => const AjustementsNouveau(), AjustementsNouveau),
];

/// Modules refaits du lot 3 (analyses) : même déclaration que les lots 1 et 2.
final modulesLot3 = <ModuleLot1>[
  ModuleLot1('Tableau: Analyses', 'Tableau: Menu Analyses', () => const TableauBordAnalyseMenuScreen(), () => const TableauAnalysesNouveau(),
      TableauAnalysesNouveau),
  ModuleLot1('Tableau: Ratios', 'Tableau: Ratios Achats/Ventes', () => const TableauBordRatioScreen(), () => const TableauRatiosNouveau(),
      TableauRatiosNouveau),
  ModuleLot1('Suivi 20/80', 'Suivi 20/80', () => const Suivi2080Screen(), () => const Suivi2080Nouveau(), Suivi2080Nouveau),
  ModuleLot1('Stat TVA', 'Statistiques TVA', () => const StatTvaScreen(), () => const StatTvaNouveau(), StatTvaNouveau),
  ModuleLot1('Marge Produits Vendus', 'Marge Produits Vendus', () => const MargeProduitsVendusScreen(), () => const MargeProduitsNouveau(),
      MargeProduitsNouveau),
  ModuleLot1('CA Crédit', 'Ventes à Crédit', () => const CaCreditScreen(), () => const CaCreditNouveau(), CaCreditNouveau),
  ModuleLot1('CA Global', 'CA Global', () => const CaGlobalScreen(), () => const CaGlobalNouveau(), CaGlobalNouveau),
];

/// Tous les modules refaits (lots 1, 2 et 3) : leurs nouveaux écrans ne tolèrent aucun écart d'ergonomie.
List<ModuleLot1> get modulesRefaits => [...modulesLot1, ...modulesLot2, ...modulesLot3];

/// Modules de la NOUVELLE interface (ceux de l'accueil d'origine moins « Fournisseurs ») : écran ouvert par son menu
/// (nouvel écran pour les modules refaits, écran d'origine sinon).
List<ModuleAccueil> get modulesNouvelleInterface => [
      for (final m in modulesAccueil)
        for (final menu in menusModules.where((x) => x.titre == m.tuile)) ModuleAccueil(m.tuile, m.titreEcran, ({Key? key}) => menu.ecran()),
    ];

/// États supplémentaires rendus par le test d'ergonomie (en plus de l'écran d'ouverture de chaque module) :
/// listes remplies par une recherche, autres onglets. [recherche] : texte saisi dans le premier champ.
class EtatEcran {
  final String nom;
  final Widget Function() ecran;
  final String? recherche;
  const EtatEcran(this.nom, this.ecran, {this.recherche});
}

final etatsSupplementaires = <EtatEcran>[
  EtatEcran('Analyse Article · résultats', () => const AnalyseArticleScreen(), recherche: 'PARAFICTIF'),
  EtatEcran('Fiche Article · résultats', () => const FicheArticleScreen(), recherche: 'PARAFICTIF'),
  EtatEcran('Présences · Période', () => const PresencesScreen(onglet: 1)),
  EtatEcran('Présences · Pointage', () => const PresencesScreen(onglet: 2)),
];
