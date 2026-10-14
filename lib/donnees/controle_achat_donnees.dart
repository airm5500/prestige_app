// lib/donnees/controle_achat_donnees.dart
// État de Contrôle des Achats, logique COMMUNE aux deux interfaces (et au comptage à la demande de l'accueil A) :
//  - groupes de grossistes : GET /groupegrossiste → « data » ;
//  - état : GET /etat-control-bon/list-annuelle?dtStart=&dtEnd=&groupeId=&groupBy=GROUP&limit=9999 → lignes par
//    groupe (« data ») et totaux (« metaData »).
import 'package:flutter/widgets.dart';

import '../models/common_data_model.dart';
import '../models/etat_controle_achat_meta_model.dart';
import '../models/etat_controle_achat_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

/// Paramètres de GET /etat-control-bon/list-annuelle (écran et comptage à la demande de l'accueil A : mêmes
/// paramètres, l'accueil utilisant les filtres par défaut de l'écran — période du jour, tous les groupes).
Map<String, String> parametresEtatControleAchat(DateTime debut, DateTime fin, {String groupeId = ''}) => {
      'dtStart': DateFormatter.toApiFormat(debut),
      'dtEnd': DateFormatter.toApiFormat(fin),
      'groupeId': groupeId,
      'groupBy': 'GROUP', // Comme spécifié dans l'URL d'exemple
      'limit': '9999',
    };

/// Réponse lue : lignes par groupe et totaux (null si absents).
class EtatControleAchats {
  final List<EtatControleAchat> lignes;
  final EtatControleAchatMeta? totaux;
  const EtatControleAchats(this.lignes, this.totaux);

  /// Lecture (même règle que l'écran d'origine : « data » liste, « metaData » objet ; sinon absents). Null si la
  /// réponse n'est pas un objet.
  static EtatControleAchats? lire(dynamic data) {
    if (data is! Map) return null;
    return EtatControleAchats(
      data['data'] is List ? (data['data'] as List).map((i) => EtatControleAchat.fromJson(i)).toList() : const [],
      data['metaData'] is Map ? EtatControleAchatMeta.fromJson(Map<String, dynamic>.from(data['metaData'])) : null,
    );
  }

  static Future<EtatControleAchats?> charger(BuildContext context, DateTime debut, DateTime fin,
          {String groupeId = '', VoidCallback? onSessionInvalid}) async =>
      lire(await ApiService().get(context, AppConstants.etatControleAchatEndpoint,
          queryParams: parametresEtatControleAchat(debut, fin, groupeId: groupeId), onSessionInvalid: onSessionInvalid));

  /// Groupes de grossistes ({data: [...]} attendu ; sinon null).
  static List<CommonData>? lireGroupes(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => CommonData.fromJson(i)).toList() : null;

  static Future<List<CommonData>?> groupes(BuildContext context, {VoidCallback? onSessionInvalid}) async =>
      lireGroupes(await ApiService().get(context, AppConstants.groupeGrossisteEndpoint, onSessionInvalid: onSessionInvalid));
}
