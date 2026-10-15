// lib/donnees/annulation_vente_donnees.dart
// Annulation de ventes, logique COMMUNE aux deux interfaces :
//  - recherche : GET /ventestats?dtStart=&dtEnd=&query=&start=0&limit=50 → « data » (numéro de vente obligatoire) ;
//  - détail : GET /ventestats/find-one/{id} → « data » ;
//  - ANNULATION (écriture IRRÉVERSIBLE) : GET /vente/annulation/{id}, route serveur INCHANGÉE (un GET qui modifie :
//    voir docs/serveur/DEMANDE_ECRITURES_SENSIBLES.md, point 9). Le serveur vérifie le droit P_BT_ANNULER_VENTE et
//    répond {success:false, msg} en cas de refus.
// Déroulé d'une annulation ([AnnulationVente.executer], protections de l'étape 1f, identiques dans les deux écrans) :
//  1. relecture de la vente AVANT l'envoi (même recherche que la liste) : déjà annulée (double appui, autre poste) →
//     aucun envoi ; relecture impossible → aucun envoi ;
//  2. UN seul envoi ;
//  3. relecture APRÈS l'envoi pour vérifier le résultat ; sans réponse du serveur (délai, réseau), la demande n'est
//     JAMAIS renvoyée automatiquement : l'état réel de la vente est relu et annoncé.
// La confirmation, le verrou anti double envoi et le code administrateur sont à la charge de chaque écran.
// Journal : seulement l'issue (aucun numéro de vente, client, montant ni identifiant).
import 'package:flutter/widgets.dart';

import '../models/vente_detail_model.dart';
import '../models/vente_stat_model.dart';
import '../services/api_service.dart';
import '../services/journal_app.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../utils/saisie.dart';

/// Ton du message de résultat (écran d'origine : vert, rouge, orange).
enum TonResultat { succes, erreur, neutre }

/// Issue d'une demande d'annulation.
enum IssueAnnulation {
  /// Relecture avant l'envoi impossible : rien n'a été envoyé.
  nonEnvoyee,

  /// Déjà annulée (relecture avant l'envoi) : rien n'a été envoyé.
  dejaAnnulee,

  /// Session expirée pendant l'envoi (retour à la connexion géré globalement).
  session,

  /// Refus du serveur (droit, erreur, réponse success:false).
  refusee,

  /// Annulée et vérifiée par relecture.
  annulee,

  /// Acceptée par le serveur mais la relecture ne la montre pas annulée.
  accepteeNonVerifiee,

  /// Acceptée par le serveur, relecture impossible.
  accepteeSansRelecture,

  /// Pas de réponse du serveur, mais la vente est annulée (vérifié).
  sansReponseAnnulee,

  /// Pas de réponse du serveur et la vente n'est pas annulée (vérifié) : peut être retentée.
  sansReponseNonAnnulee,

  /// Pas de réponse du serveur et relecture impossible : état inconnu.
  sansReponseInconnue,
}

class ResultatAnnulation {
  final IssueAnnulation issue;
  final String message;
  final TonResultat ton;
  const ResultatAnnulation(this.issue, this.message, this.ton);

  /// La requête d'annulation est partie au serveur.
  bool get envoyee => issue != IssueAnnulation.nonEnvoyee && issue != IssueAnnulation.dejaAnnulee;

  /// La vente est (vérifiée ou déclarée) annulée.
  bool get venteAnnulee =>
      issue == IssueAnnulation.annulee ||
      issue == IssueAnnulation.dejaAnnulee ||
      issue == IssueAnnulation.sansReponseAnnulee ||
      issue == IssueAnnulation.accepteeSansRelecture;
}

class AnnulationVente {
  AnnulationVente._();

  /// Nombre de ventes demandées par recherche (valeur d'origine).
  static const limite = 50;

  /// Mot à saisir (ou la référence de la vente) pour valider la confirmation renforcée de la nouvelle interface.
  static const motConfirmation = 'ANNULER';

  static Map<String, String> parametres({required DateTime debut, required DateTime fin, required String recherche}) => {
        'dtStart': DateFormatter.toApiFormat(debut),
        'dtEnd': DateFormatter.toApiFormat(fin),
        'query': Saisie.recherche(recherche),
        'start': '0',
        'limit': '$limite',
      };

  static String cheminDetail(String id) => '${AppConstants.venteDetailEndpoint}/$id';
  static String cheminAnnulation(String id) => '${AppConstants.venteAnnulationEndpoint}/$id';

  static List<VenteStat>? lireVentes(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => VenteStat.fromJson(Map<String, dynamic>.from(i as Map))).toList() : null;

  static VenteDetail? lireDetail(dynamic data) =>
      data is Map && data['data'] is Map ? VenteDetail.fromJson(Map<String, dynamic>.from(data['data'] as Map)) : null;

  /// Recherche des ventes (numéro obligatoire : l'appelant ne l'appelle pas avec une recherche vide).
  static Future<List<VenteStat>?> rechercher(BuildContext context,
          {required DateTime debut, required DateTime fin, required String recherche, VoidCallback? onSessionInvalid}) async =>
      lireVentes(await ApiService().get(context, AppConstants.ventesStatsEndpoint,
          queryParams: parametres(debut: debut, fin: fin, recherche: recherche), onSessionInvalid: onSessionInvalid));

  static Future<VenteDetail?> detail(BuildContext context, String id, {VoidCallback? onSessionInvalid}) async =>
      lireDetail(await ApiService().get(context, cheminDetail(id), onSessionInvalid: onSessionInvalid));

  /// La saisie de confirmation est-elle complète : référence de la vente ou « ANNULER » (espaces et casse ignorés) ?
  static bool confirmationValide(String saisie, String reference) {
    final s = saisie.trim().toUpperCase();
    if (s.isEmpty) return false;
    return s == motConfirmation || (reference.trim().isNotEmpty && s == reference.trim().toUpperCase());
  }

  /// Annule [vente] (relecture avant, envoi unique, relecture après). [relire] relit la vente sur le serveur
  /// (null si elle n'est plus dans la recherche ; échec : ApiLoadException). Null si l'écran a été fermé entre-temps.
  static Future<ResultatAnnulation?> executer(BuildContext context, VenteStat vente, {required Future<VenteStat?> Function() relire}) async {
    final r = await _executer(context, vente, relire);
    if (r != null) JournalApp.debug('Annulation de vente : ${r.issue.name}');
    return r;
  }

  static Future<ResultatAnnulation?> _executer(BuildContext context, VenteStat vente, Future<VenteStat?> Function() relire) async {
    // 1. Relecture avant l'envoi : déjà annulée (double appui, autre poste) → aucun envoi.
    final VenteStat? avant;
    try {
      avant = await relire();
    } on ApiLoadException catch (e) {
      return ResultatAnnulation(IssueAnnulation.nonEnvoyee, 'Annulation non envoyée : ${e.message}', TonResultat.erreur);
    }
    if (!context.mounted) return null;
    if (avant != null && avant.cancel) {
      return ResultatAnnulation(IssueAnnulation.dejaAnnulee, 'La vente N° ${vente.strREF} est déjà annulée.', TonResultat.neutre);
    }

    // 2. Envoi unique (route inchangée : GET /vente/annulation/{id}).
    dynamic result;
    ApiLoadException? echec;
    try {
      result = await ApiService().get(context, cheminAnnulation(vente.lgPREENREGISTREMENTID));
    } on ApiLoadException catch (e) {
      echec = e;
    }
    if (!context.mounted) return null;
    if (echec != null && echec.nature == NatureErreur.session) {
      return ResultatAnnulation(IssueAnnulation.session, echec.message, TonResultat.erreur); // retour à la connexion géré globalement
    }
    // Réponse illisible (JSON partiel, 3.9.1) : le serveur a pu annuler la vente avant que sa réponse ne soit abîmée ;
    // comme sans réponse, l'état est VÉRIFIÉ par la relecture au lieu d'annoncer « refusée ».
    final sansReponse =
        echec != null && (echec.nature == NatureErreur.reseau || echec.nature == NatureErreur.delai || echec.nature == NatureErreur.reponse);
    if (echec != null && !sansReponse) {
      return ResultatAnnulation(IssueAnnulation.refusee, 'Annulation refusée : ${echec.message}', TonResultat.erreur);
    }
    final accepte = result is Map && result['success'] == true;
    if (!sansReponse && !accepte) {
      return ResultatAnnulation(IssueAnnulation.refusee,
          result is Map && result['msg'] != null ? '${result['msg']}' : 'Erreur d\'annulation de la vente', TonResultat.erreur);
    }

    // 3. Relecture du résultat (jamais de renvoi automatique).
    VenteStat? apres;
    try {
      apres = await relire();
    } on ApiLoadException {
      return sansReponse
          ? const ResultatAnnulation(IssueAnnulation.sansReponseInconnue,
              'Pas de réponse du serveur et état de la vente impossible à vérifier. Relancez la recherche AVANT de réessayer.', TonResultat.erreur)
          : const ResultatAnnulation(IssueAnnulation.accepteeSansRelecture,
              'Vente annulée (réponse du serveur), mais la liste n\'a pas pu être relue. Relancez la recherche.', TonResultat.succes);
    }
    if (!context.mounted) return null;
    final annulee = apres?.cancel ?? false;
    if (accepte) {
      return annulee
          ? const ResultatAnnulation(IssueAnnulation.annulee, 'Vente annulée avec succès', TonResultat.succes)
          : const ResultatAnnulation(
              IssueAnnulation.accepteeNonVerifiee, 'Le serveur a accepté l\'annulation : vérifiez la vente dans Prestige.', TonResultat.erreur);
    }
    return annulee
        ? ResultatAnnulation(IssueAnnulation.sansReponseAnnulee,
            'Pas de réponse du serveur, mais la vente N° ${vente.strREF} est bien annulée (vérifié).', TonResultat.succes)
        : ResultatAnnulation(IssueAnnulation.sansReponseNonAnnulee,
            'Pas de réponse du serveur : la vente N° ${vente.strREF} n\'est pas annulée. Vous pouvez réessayer.', TonResultat.erreur);
  }
}
