// lib/donnees/detail_ca_donnees.dart
// Données du Détail CA, COMMUNES aux deux interfaces : GET /ca-all?dtStart=&dtEnd= (une ligne par jour), triée
// par date ; cumul de la période et répartition par mode de paiement (mêmes calculs que l'écran d'origine).
import 'package:flutter/widgets.dart';

import '../models/ca_comptant_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class DetailCa {
  DetailCa._();

  static Map<String, String> parametres(DateTime debut, DateTime fin) =>
      {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin)};

  /// Lignes de la réponse (liste attendue ; tout autre format = aucune ligne), triées par date.
  static List<CaComptant> lire(dynamic data) {
    if (data is! List) return [];
    final liste = data.map((item) => CaComptant.fromJson(item)).toList();
    liste.sort((a, b) {
      if (a.mvtDate == null || b.mvtDate == null) return 0;
      return a.mvtDate!.compareTo(b.mvtDate!);
    });
    return liste;
  }

  static Future<List<CaComptant>> charger(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async =>
      lire(await ApiService().get(context, AppConstants.caComptantEndpoint,
          queryParams: parametres(debut, fin), onSessionInvalid: onSessionInvalid));

  /// Cumul de la période (somme de chaque total).
  static CaComptant cumul(List<CaComptant> lignes) {
    if (lignes.isEmpty) {
      return CaComptant(montantCredit: 0, remiseSurCA: 0, totCB: 0, totChq: 0, totEsp: 0, totMobile: 0, totTVA: 0, totVirement: 0);
    }
    return lignes.reduce((acc, c) => CaComptant(
          montantCredit: acc.montantCredit + c.montantCredit,
          mvtDate: null,
          remiseSurCA: acc.remiseSurCA + c.remiseSurCA,
          totCB: acc.totCB + c.totCB,
          totChq: acc.totChq + c.totChq,
          totEsp: acc.totEsp + c.totEsp,
          totMobile: acc.totMobile + c.totMobile,
          totTVA: acc.totTVA + c.totTVA,
          totVirement: acc.totVirement + c.totVirement,
        ));
  }

  /// Modes de paiement (libellé court, montant), dans l'ordre de l'écran d'origine.
  static Map<String, double> modes(CaComptant c) => {
        'Espèces': c.totEsp,
        'Crédit': c.montantCredit,
        'Mobile': c.totMobile,
        'Carte B.': c.totCB,
        'Chèque': c.totChq,
        'Virement': c.totVirement,
      };

  /// Répartition (libellé, montant, pourcentage) des modes de montant > 0 ; vide si rien n'a été encaissé.
  static List<(String, double, double)> repartition(CaComptant c) {
    final m = modes(c);
    var total = 0.0;
    m.forEach((_, v) {
      if (v > 0) total += v;
    });
    if (total == 0) return const [];
    return [for (final e in m.entries) if (e.value > 0) (e.key, e.value, e.value / total * 100)];
  }
}
