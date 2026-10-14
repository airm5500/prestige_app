// lib/donnees/suggestions_donnees.dart
// Suggestions de commande, logique COMMUNE aux deux interfaces (écran d'origine et nouvel écran) : mêmes routes,
// mêmes paramètres, mêmes corps de requête, mêmes contrôles.
//  Lecture :
//   - GET /suggestion/list?limit=50 → « data » ;
//   - GET /suggestion/list/items?orderId=&limit=9999 → « data » (lignes) ;
//   - GET /suggestion/amount/{id} → montants d'achat et de vente.
//  Écritures (inchangées) :
//   - GET /suggestion/set-pending/{id} à l'ouverture d'une suggestion ;
//   - POST /suggestion/item/update-qte-cmde {itemId, qte} (quantité ENTIÈRE de 0 à Saisie.maxQuantite) ;
//   - DELETE /suggestion/item/{itemId} et DELETE /suggestion/suggestion/{id} (toujours après confirmation, à la
//     charge de l'écran).
//  Export CSV « cip;qte » (fichier dans Téléchargements, nom horodaté), comme l'écran d'origine.
// Tout échec est une ApiLoadException (réseau, délai, serveur, session, droit…) propagée à l'écran.
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/suggestion_amount_model.dart';
import '../models/suggestion_item_model.dart';
import '../models/suggestion_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/saisie.dart';

class Suggestions {
  Suggestions._();

  /// Paramètres de la liste des suggestions.
  static const parametresListe = {'limit': '50'};

  /// Paramètres des lignes d'une suggestion.
  static Map<String, String> parametresLignes(String suggestionId) => {'orderId': suggestionId, 'limit': '9999'};

  /// Suggestions de la réponse ({data: [...]} attendu ; tout autre format = null, rien n'est remplacé).
  static List<Suggestion>? lireListe(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => Suggestion.fromJson(i)).toList() : null;

  /// Lignes de la réponse ({data: [...]} attendu ; tout autre format = null).
  static List<SuggestionItem>? lireLignes(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => SuggestionItem.fromJson(i)).toList() : null;

  /// Montants de la réponse (objet attendu ; tout autre format = null).
  static SuggestionAmount? lireMontant(dynamic data) => data is Map ? SuggestionAmount.fromJson(Map<String, dynamic>.from(data)) : null;

  static Future<List<Suggestion>?> liste(BuildContext context, {VoidCallback? onSessionInvalid}) async =>
      lireListe(await ApiService().get(context, AppConstants.suggestionListEndpoint, queryParams: parametresListe, onSessionInvalid: onSessionInvalid));

  /// Passe la suggestion « en cours » (écriture du serveur faite à l'ouverture, comme l'écran d'origine).
  static Future<dynamic> ouvrir(BuildContext context, String suggestionId, {VoidCallback? onSessionInvalid}) =>
      ApiService().get(context, '${AppConstants.suggestionSetPendingEndpoint}/$suggestionId', onSessionInvalid: onSessionInvalid);

  static Future<List<SuggestionItem>?> lignes(BuildContext context, String suggestionId, {VoidCallback? onSessionInvalid}) async =>
      lireLignes(await ApiService().get(context, AppConstants.suggestionListItemsEndpoint,
          queryParams: parametresLignes(suggestionId), onSessionInvalid: onSessionInvalid));

  static Future<SuggestionAmount?> montant(BuildContext context, String suggestionId, {VoidCallback? onSessionInvalid}) async =>
      lireMontant(await ApiService().get(context, '${AppConstants.suggestionAmountEndpoint}/$suggestionId', onSessionInvalid: onSessionInvalid));

  // -------------------------------------------------------------------------------------------------------------
  // Écritures
  // -------------------------------------------------------------------------------------------------------------

  /// Message d'une quantité refusée.
  static const messageQuantiteInvalide = 'Quantité invalide (0 à ${Saisie.maxQuantite}) : non enregistrée.';

  /// Quantité saisie acceptée (entier de 0 à Saisie.maxQuantite), ou null.
  static int? quantite(String texte) => Saisie.entier(texte, min: 0, max: Saisie.maxQuantite);

  /// Corps de POST /suggestion/item/update-qte-cmde.
  static Map<String, dynamic> corpsQuantite(String itemId, int qte) => {'itemId': itemId, 'qte': qte};

  static Future<Map<String, dynamic>> enregistrerQuantite(BuildContext context, String itemId, int qte, {VoidCallback? onSessionInvalid}) =>
      ApiService().post(context, AppConstants.suggestionUpdateQteEndpoint, corpsQuantite(itemId, qte), onSessionInvalid: onSessionInvalid);

  static Future<Map<String, dynamic>> supprimerLigne(BuildContext context, String itemId, {VoidCallback? onSessionInvalid}) =>
      ApiService().delete(context, '${AppConstants.suggestionDeleteItemEndpoint}/$itemId', onSessionInvalid: onSessionInvalid);

  static Future<Map<String, dynamic>> supprimer(BuildContext context, String suggestionId, {VoidCallback? onSessionInvalid}) =>
      ApiService().delete(context, '${AppConstants.suggestionDeleteEndpoint}/$suggestionId', onSessionInvalid: onSessionInvalid);

  // -------------------------------------------------------------------------------------------------------------
  // Export CSV
  // -------------------------------------------------------------------------------------------------------------

  /// Contenu du CSV (« cip;qte », une ligne par article).
  static String csv(List<SuggestionItem> lignes) =>
      const ListToCsvConverter(fieldDelimiter: ';').convert([
        ['cip', 'qte'],
        for (final l in lignes) [l.cip, l.quantiteSuggeree],
      ]);

  /// Nom du fichier : « suggestion_<nom nettoyé>_<horodatage>.csv » (unique à chaque export).
  static String nomFichier(Suggestion s, {DateTime Function() maintenant = DateTime.now}) {
    final propre = s.name.replaceAll(RegExp(r'[^\w\s\.-]'), '');
    return 'suggestion_${propre}_${maintenant().millisecondsSinceEpoch}.csv';
  }

  /// Écrit [contenu] dans Téléchargements (Android) ou les documents de l'application. Renvoie le nom du fichier,
  /// ou null si la permission de stockage est refusée (Android < 13) ; toute autre erreur est levée.
  static Future<String?> enregistrerCsv(String nom, String contenu) async {
    var permission = true;
    if (Platform.isAndroid) {
      final android = await DeviceInfoPlugin().androidInfo;
      if (android.version.sdkInt < 33) permission = (await Permission.storage.request()).isGranted;
    }
    if (!permission) return null;
    Directory? dossier;
    if (Platform.isAndroid) {
      dossier = Directory('/storage/emulated/0/Download');
      if (!await dossier.exists()) dossier = await getExternalStorageDirectory();
    } else {
      dossier = await getApplicationDocumentsDirectory();
    }
    if (dossier == null) throw const FileSystemException('Dossier de téléchargement introuvable');
    await File('${dossier.path}/$nom').writeAsString(contenu, flush: true);
    return nom;
  }
}
