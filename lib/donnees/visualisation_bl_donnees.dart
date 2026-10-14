// lib/donnees/visualisation_bl_donnees.dart
// Visualisation BL, logique COMMUNE aux deux interfaces : listes des filtres (grossistes GET /common/grossiste,
// groupes GET /groupegrossiste, utilisateurs GET /common/users, appels successifs) et bons de livraison paginés
// GET /etat-control-bon/list (ApiService.getBonLivraisons : search, grossisteId, groupeId, userId, checked, dtStart,
// dtEnd au format yyyy-MM-dd, page, start, limit 20, group / sort). Totaux HT / TVA / TTC = somme des bons chargés
// (même calcul que l'écran d'origine) ; « Total BL » = total annoncé par le serveur.
// Ce que le serveur LIT réellement (EtatControlBonResource.list, vérifié en 3.8.0) : search, grossisteId, groupeId
// (un groupe choisi remplace le grossiste : grossistes du groupe), dtStart, dtEnd, start, limit, statutControle
// (TOUS / CONTROLE / NON_CONTROLE : contrôle terminé ou non, filtré AVANT la pagination, total juste) et ecart. Il
// IGNORE userId et checked. L'écran d'origine envoie toujours « checked » (inchangé) ; la nouvelle interface envoie
// « statutControle » ([statutsControle]) et n'offre plus le filtre utilisateur tant que le serveur ne le lit pas
// (demande : docs/serveur/DEMANDE_FILTRES_LISTES.md).
import 'package:flutter/widgets.dart';

import '../models/bon_livraison_model.dart';
import '../models/common_data_model.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../utils/saisie.dart';

class PageBonsLivraison {
  final int total;
  final List<BonLivraisonModel> bons;
  const PageBonsLivraison(this.total, this.bons);
}

class OptionsVisualisationBl {
  final List<CommonData> grossistes;
  final List<CommonData> groupes;
  final List<CommonData> utilisateurs;
  const OptionsVisualisationBl(this.grossistes, this.groupes, this.utilisateurs);
}

/// Totaux des bons chargés.
class TotauxBl {
  final double ht;
  final double tva;
  final double ttc;
  const TotauxBl(this.ht, this.tva, this.ttc);
}

class VisualisationBl {
  VisualisationBl._();

  static const taillePage = 20;

  /// Statuts (valeur envoyée dans « checked » → libellé).
  static const statuts = {
    'TERMINE': 'Terminé',
    'NON_TRAITE': 'Non Traité',
    'EN_COURS': 'En Cours',
  };

  /// Statuts du filtre LU par le serveur (valeur de « statutControle » → libellé), nouvelle interface (3.8.0).
  /// « Contrôlés » = contrôle terminé (statut TERMINE) ; « Non contrôlés » = non traité ou en cours.
  static const statutsControle = {
    'CONTROLE': 'Contrôlés',
    'NON_CONTROLE': 'Non contrôlés',
  };

  static Future<OptionsVisualisationBl> options(BuildContext context) async {
    final api = ApiService();
    final g = await api.getGrossistes(context);
    if (!context.mounted) return OptionsVisualisationBl(g, const [], const []);
    final gr = await api.getGroupeGrossistes(context);
    if (!context.mounted) return OptionsVisualisationBl(g, gr, const []);
    final u = await api.getUsers(context);
    return OptionsVisualisationBl(g, gr, u);
  }

  static Future<PageBonsLivraison> page(
    BuildContext context, {
    required String recherche,
    String grossisteId = '',
    String groupeId = '',
    String userId = '',
    String? statut,
    String? statutControle,
    required DateTime debut,
    required DateTime fin,
    required int page,
  }) async {
    final r = await ApiService().getBonLivraisons(
      context,
      search: Saisie.recherche(recherche),
      grossisteId: grossisteId,
      groupeId: groupeId,
      userId: userId,
      statut: statut ?? '',
      statutControle: statutControle ?? '',
      dtStart: DateFormatter.toApiFormat(debut),
      dtEnd: DateFormatter.toApiFormat(fin),
      page: page,
      limit: taillePage,
    );
    return PageBonsLivraison((r['total'] as num?)?.toInt() ?? 0, List<BonLivraisonModel>.from(r['data'] as List));
  }

  static TotauxBl totaux(List<BonLivraisonModel> bons) => TotauxBl(
        bons.fold(0.0, (s, b) => s + b.montantHT),
        bons.fold(0.0, (s, b) => s + b.montantTVA),
        bons.fold(0.0, (s, b) => s + b.montantTTC),
      );
}
