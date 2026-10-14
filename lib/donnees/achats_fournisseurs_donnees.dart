// lib/donnees/achats_fournisseurs_donnees.dart
// Achats fournisseurs (LECTURE SEULE), logique COMMUNE aux deux interfaces :
//  - fournisseurs (filtre) : GET /fournisseurs → liste (fournisseurId, fournisseurLibelle) ;
//  - achats : GET /achats-fournisseurs?dtStart=&dtEnd= → liste ;
//  - recherche et filtre fournisseur LOCAUX (aucune nouvelle requête) : nom du fournisseur, N° de BL, N° de commande ;
//  - récapitulatif (« Récap Achat ») : totaux HT / TVA / TTC du fournisseur choisi, ou par fournisseur — sur TOUS les
//    achats chargés de la période (la recherche n'en retire rien, comme à l'origine).
import 'package:flutter/widgets.dart';

import '../models/achat_fournisseur_model.dart';
import '../models/fournisseur_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

/// Totaux HT / TVA / TTC d'un groupe d'achats.
class TotauxAchats {
  final double ht;
  final double tva;
  final double ttc;
  final int nombre;
  const TotauxAchats(this.ht, this.tva, this.ttc, this.nombre);
}

class AchatsFournisseurs {
  AchatsFournisseurs._();

  static Map<String, String> parametres(DateTime debut, DateTime fin) =>
      {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin)};

  /// Fournisseurs de la réponse (liste attendue ; sinon null).
  static List<Fournisseur>? lireFournisseurs(dynamic data) => data is List ? data.map((i) => Fournisseur.fromJson(i)).toList() : null;

  /// Achats de la réponse (liste attendue ; sinon null).
  static List<AchatFournisseur>? lireAchats(dynamic data) => data is List ? data.map((i) => AchatFournisseur.fromJson(i)).toList() : null;

  static Future<List<Fournisseur>?> fournisseurs(BuildContext context, {VoidCallback? onSessionInvalid}) async =>
      lireFournisseurs(await ApiService().get(context, AppConstants.fournisseursEndpoint, onSessionInvalid: onSessionInvalid));

  static Future<List<AchatFournisseur>?> achats(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async =>
      lireAchats(await ApiService().get(context, AppConstants.achatsFournisseursEndpoint,
          queryParams: parametres(debut, fin), onSessionInvalid: onSessionInvalid));

  /// Filtre LOCAL d'origine : [recherche] (insensible à la casse) dans le fournisseur, le N° de BL ou de commande ;
  /// [fournisseurId] null = tous.
  static List<AchatFournisseur> filtrer(List<AchatFournisseur> achats, String recherche, String? fournisseurId) {
    final q = recherche.toLowerCase();
    return [
      for (final a in achats)
        if ((q.isEmpty ||
                a.fournisseurLibelle.toLowerCase().contains(q) ||
                a.numeroBL.toLowerCase().contains(q) ||
                a.numeroCommade.toLowerCase().contains(q)) &&
            (fournisseurId == null || a.fournisseurId == fournisseurId))
          a,
    ];
  }

  static TotauxAchats totaux(Iterable<AchatFournisseur> achats) {
    double ht = 0, tva = 0, ttc = 0;
    var n = 0;
    for (final a in achats) {
      ht += a.montantHT;
      tva += a.montantTVA;
      ttc += a.montantTTC;
      n++;
    }
    return TotauxAchats(ht, tva, ttc, n);
  }

  /// Récapitulatif d'origine : fournisseur choisi seul, sinon un total par fournisseur (libellé, ordre de première
  /// apparition), toujours sur TOUS les achats chargés.
  static Map<String, TotauxAchats> recapitulatif(List<AchatFournisseur> achats, {String? fournisseurId, String? libelle}) {
    if (fournisseurId != null) {
      return {libelle ?? fournisseurId: totaux(achats.where((a) => a.fournisseurId == fournisseurId))};
    }
    final groupes = <String, List<AchatFournisseur>>{};
    for (final a in achats) {
      groupes.putIfAbsent(a.fournisseurLibelle, () => []).add(a);
    }
    return {for (final e in groupes.entries) e.key: totaux(e.value)};
  }
}
