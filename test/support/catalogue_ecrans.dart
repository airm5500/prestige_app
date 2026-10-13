// Catalogue des écrans testés : modules de l'accueil (titre de la tuile, titre de la barre, constructeur) et
// états supplémentaires. À COMPLÉTER quand un module est ajouté à l'accueil (voir test/README.md) : le test e2e
// « chaque module de l'accueil s'ouvre et se referme » échoue tant que le nouveau module n'est pas ici, et le test
// d'ergonomie le rend alors automatiquement à toutes les tailles d'écran.
import 'package:flutter/widgets.dart';
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
