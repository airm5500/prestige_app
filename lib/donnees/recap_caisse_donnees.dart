// lib/donnees/recap_caisse_donnees.dart
// Récap de caisse (ticket Z), logique COMMUNE aux deux interfaces :
//  - caissiers : GET /common/users?limit=9999 (ApiService.getUsers) → « data » (lgUSERID, fullName), précédés de
//    « Tous les utilisateurs » (id ALL) ;
//  - récapitulatif : POST /caisse/fetch-tickez {description: ALL, dtStart, dtEnd (yyyy-MM-dd), hrStart, hrEnd (HH:mm),
//    userId (ALL = tous)} → « data » : {datas: [{user, modePaymentAmounts, totaux}], totaux: [...]}. Réponse sans
//    « data » = aucune donnée (comme l'écran d'origine).
// Les montants arrivent DÉJÀ formatés par le serveur (« 125 000 ») : ils sont affichés tels quels, sans recalcul.
import 'package:flutter/material.dart';

import '../models/common_data_model.dart';
import '../models/ticket_z_model.dart';
import '../services/api_service.dart';

class RecapCaisse {
  RecapCaisse._();

  /// Identifiant « tous les caissiers » (valeur d'origine).
  static const tous = 'ALL';
  static const libelleTous = 'Tous les utilisateurs';

  /// Heures par défaut de l'écran d'origine (journée entière).
  static const heureDebutDefaut = TimeOfDay(hour: 0, minute: 0);
  static const heureFinDefaut = TimeOfDay(hour: 23, minute: 59);

  static String date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String heure(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Corps envoyé à /caisse/fetch-tickez (mêmes clés et mêmes formats que l'écran d'origine).
  static Map<String, dynamic> corps({
    required DateTime debut,
    required DateTime fin,
    TimeOfDay heureDebut = heureDebutDefaut,
    TimeOfDay heureFin = heureFinDefaut,
    String userId = tous,
  }) =>
      {
        'description': tous,
        'dtStart': date(debut),
        'dtEnd': date(fin),
        'hrStart': heure(heureDebut),
        'hrEnd': heure(heureFin),
        'userId': userId,
      };

  /// Caissiers (sans l'entrée « Tous »). Échec : ApiLoadException.
  static Future<List<CommonData>> caissiers(BuildContext context) => ApiService().getUsers(context);

  /// Lecture de la réponse : « data » absent = récapitulatif vide.
  static TicketZResponse lire(Map<String, dynamic>? reponse) =>
      reponse != null && reponse['data'] is Map ? TicketZResponse.fromJson(Map<String, dynamic>.from(reponse['data'] as Map)) : TicketZResponse(datas: [], totauxGlobaux: []);

  /// Récapitulatif de la période. Échec : ApiLoadException (« ticket Z »).
  static Future<TicketZResponse> charger(BuildContext context, Map<String, dynamic> corps) async =>
      lire(await ApiService().fetchTicketZ(context, corps));

  static bool estVide(TicketZResponse r) => r.datas.isEmpty && r.totauxGlobaux.isEmpty;

  /// Ligne « TOTAL (VNO/VO) » (mise en avant par l'écran d'origine).
  static bool estTotalVnoVo(String libelle) => libelle.toUpperCase().contains('TOTAL (VNO/VO)');

  /// Montant négatif (affiché en rouge par l'écran d'origine).
  static bool estNegatif(String montant) => montant.contains('-');

  /// « 125 000 F » à partir du montant déjà formaté par le serveur (écran ET PDF : mêmes textes).
  static String montant(String m) => m.trim().isEmpty ? '—' : '${m.trim()} F';

  /// Montant « TOTAL (VNO/VO) » des totaux globaux, sinon null.
  static String? totalVnoVo(TicketZResponse r) =>
      r.totauxGlobaux.where((t) => estTotalVnoVo(t.modeLibelle)).map((t) => t.montant).firstOrNull;

  /// Montant du total global dont le libellé est [libelle] (insensible à la casse), sinon null.
  static String? totalGlobal(TicketZResponse r, String libelle) {
    for (final t in r.totauxGlobaux) {
      if (t.modeLibelle.trim().toUpperCase() == libelle.toUpperCase()) return t.montant;
    }
    return null;
  }
}
