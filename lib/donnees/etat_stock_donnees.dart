// lib/donnees/etat_stock_donnees.dart
// État de Stock, logique COMMUNE aux deux interfaces : listes des emplacements (GET /common/rayons) et des
// grossistes (GET /common/grossiste, pour le nom du grossiste dans le détail), puis recherche paginée
// GET /fichearticle/comparaison (ApiService.getEtatStockArticles : query, codeRayon, stock, filtreStock, page,
// start, limit 15 ; codeGrossiste, seuil, filtreSeuil, codeFamile vides comme l'écran d'origine).
// Contrôle du filtre de stock : comparaison choisie → quantité obligatoire, entière, bornée à ± Saisie.maxQuantite.
import 'package:flutter/widgets.dart';

import '../models/common_data_model.dart';
import '../models/etat_stock_article_model.dart';
import '../services/api_service.dart';
import '../utils/saisie.dart';

/// Une page de résultats : total annoncé par le serveur et articles de la page.
class PageEtatStock {
  final int total;
  final List<EtatStockArticleModel> articles;
  const PageEtatStock(this.total, this.articles);
}

/// Listes des filtres : emplacements (rayons) et grossistes (identifiant → libellé).
class OptionsEtatStock {
  final List<CommonData> rayons;
  final Map<String, String> grossistes;
  const OptionsEtatStock(this.rayons, this.grossistes);
}

class EtatStock {
  EtatStock._();

  /// Lignes demandées par page (écran d'origine).
  static const taillePage = 15;

  /// 3.16.0 (« État de stock lent ») : une recherche de 1 ou 2 caractères n'est pas envoyée (GET /fichearticle/comparaison
  /// sur presque tout le catalogue). 3 caractères au moins ; un code CIP / EAN complet (7 chiffres ou plus) passe
  /// évidemment. Recherche vide : seuls les filtres comptent (comme avant).
  static const longueurMinimale = 3;

  /// Anti-rebond de la saisie (nouvelle interface).
  static const antiRebond = Duration(milliseconds: 300);

  /// [texte] saisi (avant nettoyage) est-il trop court pour partir ?
  static bool rechercheTropCourte(String texte) {
    final t = Saisie.recherche(texte);
    return t.isNotEmpty && t.length < longueurMinimale;
  }

  /// Comparaisons du filtre de stock (valeur envoyée → libellé).
  static const comparaisons = {
    'EQUAL': 'Egal (=)',
    'LESS': 'Inférieur (<)',
    'GREATER': 'Supérieur (>)',
    'GREATER_EQUAL': 'Sup. ou Egal (>=)',
    'LESS_EQUAL': 'Inf. ou Egal (<=)',
    'NOT': 'Différent (!=)',
  };

  static const messageQuantiteInvalide = 'Quantité invalide (nombre entier, ${Saisie.maxQuantite} au plus).';
  static const messageQuantiteManquante = 'Saisissez une quantité pour le filtre stock';

  /// Motif de refus du filtre de stock ([comparaison] choisie, [quantite] saisie), ou null s'il est acceptable.
  static String? erreurFiltre(String? comparaison, String quantite) {
    if (comparaison == null) return null;
    if (quantite.isEmpty) return messageQuantiteManquante;
    if (Saisie.entier(quantite, min: -Saisie.maxQuantite, max: Saisie.maxQuantite) == null) return messageQuantiteInvalide;
    return null;
  }

  /// Emplacements puis grossistes (deux appels successifs, comme l'écran d'origine).
  static Future<OptionsEtatStock> options(BuildContext context) async {
    final api = ApiService();
    final rayons = await api.getRayons(context);
    if (!context.mounted) return OptionsEtatStock(rayons, const {});
    final grossistes = await api.getGrossistes(context);
    return OptionsEtatStock(rayons, {for (final g in grossistes) g.id: g.libelle});
  }

  /// Page [page] de la recherche (même paramètres que l'écran d'origine).
  static Future<PageEtatStock> page(BuildContext context,
      {required String recherche, String codeRayon = '', String quantite = '', String? comparaison, required int page}) async {
    final r = await ApiService().getEtatStockArticles(
      context,
      query: Saisie.recherche(recherche),
      codeRayon: codeRayon,
      stock: quantite.trim(),
      filtreStock: comparaison ?? '',
      page: page,
      limit: taillePage,
    );
    return PageEtatStock((r['total'] as num?)?.toInt() ?? 0, List<EtatStockArticleModel>.from(r['data'] as List));
  }
}
