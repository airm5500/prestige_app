// lib/donnees/retours_fournisseurs_donnees.dart
// Retours fournisseurs (LECTURE SEULE), logique COMMUNE aux deux interfaces :
//  - fournisseurs : GET /grossiste/all → « data » ;
//  - retours : GET /produit/retours-data?query=&fourId=&filtre=&dtEnd=&dtStart=&page=1&start=0&limit=9999 → « results »
//    (filtre : vide = tout, WITH = avec réponse, WITHOUT = sans réponse) ;
//  - détail d'un retour : GET /retourfournisseur/retours-items?retourId=&page=1&start=0&limit=9999 → « data » ;
//  - produits retournés (avoirs) de la période : GET /avoirs-fournisseurs?dtStart=&dtEnd= → liste.
// Aucune création ni modification de retour (prévue plus tard).
import 'package:flutter/widgets.dart';

import '../models/avoir_fournisseur_produit_model.dart';
import '../models/fournisseur_model.dart';
import '../models/retour_fournisseur_detail_model.dart';
import '../models/retour_fournisseur_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../utils/saisie.dart';

/// Filtre « réponse du fournisseur » (valeur envoyée → libellé).
enum FiltreReponse {
  tout('', 'Tout'),
  avec('WITH', 'Avec réponse'),
  sans('WITHOUT', 'Sans réponse');

  final String valeur;
  final String libelle;
  const FiltreReponse(this.valeur, this.libelle);
}

class RetoursFournisseurs {
  RetoursFournisseurs._();

  static Map<String, String> parametres(
          {required String recherche, String fourId = '', FiltreReponse filtre = FiltreReponse.tout, required DateTime debut, required DateTime fin}) =>
      {
        'query': Saisie.recherche(recherche),
        'fourId': fourId,
        'filtre': filtre.valeur,
        'dtEnd': DateFormatter.toApiFormat(fin),
        'dtStart': DateFormatter.toApiFormat(debut),
        'page': '1',
        'start': '0',
        'limit': '9999',
      };

  static List<Fournisseur>? lireFournisseurs(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => Fournisseur.fromJson(i)).toList() : null;

  /// Retours de la réponse ({results: [...]} attendu ; sinon null).
  static List<RetourFournisseur>? lireRetours(dynamic data) =>
      data is Map && data['results'] is List ? (data['results'] as List).map((i) => RetourFournisseur.fromJson(i)).toList() : null;

  static List<RetourFournisseurDetail>? lireDetails(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => RetourFournisseurDetail.fromJson(i)).toList() : null;

  /// Produits retournés (liste attendue ; sinon null).
  static List<AvoirFournisseurProduit>? lireProduits(dynamic data) =>
      data is List ? data.map((i) => AvoirFournisseurProduit.fromJson(i)).toList() : null;

  static Future<List<Fournisseur>?> fournisseurs(BuildContext context, {VoidCallback? onSessionInvalid}) async =>
      lireFournisseurs(await ApiService().get(context, AppConstants.grossistesEndpoint, onSessionInvalid: onSessionInvalid));

  static Future<List<RetourFournisseur>?> retours(BuildContext context,
          {required String recherche, String fourId = '', FiltreReponse filtre = FiltreReponse.tout, required DateTime debut, required DateTime fin,
          VoidCallback? onSessionInvalid}) async =>
      lireRetours(await ApiService().get(context, AppConstants.retoursFournisseursEndpoint,
          queryParams: parametres(recherche: recherche, fourId: fourId, filtre: filtre, debut: debut, fin: fin), onSessionInvalid: onSessionInvalid));

  static Map<String, String> parametresDetail(String retourId) => {'retourId': retourId, 'page': '1', 'start': '0', 'limit': '9999'};

  static Future<List<RetourFournisseurDetail>?> details(BuildContext context, String retourId, {VoidCallback? onSessionInvalid}) async =>
      lireDetails(await ApiService().get(context, AppConstants.retourFournisseurDetailEndpoint,
          queryParams: parametresDetail(retourId), onSessionInvalid: onSessionInvalid));

  static Map<String, String> parametresProduits(DateTime debut, DateTime fin) =>
      {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin)};

  static Future<List<AvoirFournisseurProduit>?> produits(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async =>
      lireProduits(await ApiService().get(context, AppConstants.avoirsFournisseursEndpoint,
          queryParams: parametresProduits(debut, fin), onSessionInvalid: onSessionInvalid));

  /// Montant total des retours.
  static double montantTotal(List<RetourFournisseur> retours) => retours.fold(0.0, (s, r) => s + r.montantRetour);
}
