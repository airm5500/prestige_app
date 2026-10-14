// lib/donnees/detail_ca_donnees.dart
// Données du Détail CA, COMMUNES aux deux interfaces : GET /ca-all?dtStart=&dtEnd= (une ligne par jour), triée
// par date ; cumul de la période et répartition par mode de paiement (mêmes calculs que l'écran d'origine).
// Détail du Mobile Money par opérateur (nouvelle interface, à la demande) : champ « detailMobile » de /ca-all s'il
// existe un jour, sinon GET /stats-recette-caisse/modes (mêmes dates) ; les totaux de référence restent ceux de
// /ca-all (voir DetailMobile).
import 'package:flutter/widgets.dart';

import '../models/ca_comptant_model.dart';
import '../nouvelle_interface/vague1/donnees_vague1.dart' show booleenTolerant, lireReponseVague1;
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

  // -------------------------------------------------------------------------------------------------------------
  // Détail du Mobile Money par opérateur
  // -------------------------------------------------------------------------------------------------------------

  /// Route complémentaire (ventilation par mode de paiement de la période ; seules les lignes mobile:true servent).
  static const routeModes = '/stats-recette-caisse/modes';

  /// Détail fourni par /ca-all lui-même (champ « detailMobile » de CHAQUE ligne qui a du Mobile Money), cumulé sur la
  /// période ; null si le serveur ne le fournit pas (cas actuel) : il faut alors l'appel complémentaire.
  static List<OperateurMobile>? detailDepuisCaAll(List<CaComptant> lignes) {
    if (lignes.isEmpty || lignes.every((c) => c.detailMobile == null)) return null;
    if (lignes.any((c) => c.detailMobile == null && c.totMobile != 0)) return null; // détail incomplet : non fiable
    return cumulerOperateurs([for (final c in lignes) ...?c.detailMobile]);
  }

  /// Cumul par opérateur (même identifiant, sinon même libellé), montants nuls retirés, ordre décroissant.
  static List<OperateurMobile> cumulerOperateurs(Iterable<OperateurMobile> operateurs) {
    final parCle = <String, OperateurMobile>{};
    for (final o in operateurs) {
      final cle = o.modeId.isNotEmpty ? 'id:${o.modeId}' : 'lib:${o.libelle.toLowerCase()}';
      final avant = parCle[cle];
      parCle[cle] = avant == null
          ? o
          : OperateurMobile(modeId: avant.modeId, libelle: avant.libelle, montant: avant.montant + o.montant);
    }
    final liste = [for (final o in parCle.values) if (o.montant.abs() >= 0.5) o];
    liste.sort((a, b) {
      final c = b.montant.compareTo(a.montant);
      return c != 0 ? c : a.libelle.compareTo(b.libelle);
    });
    return liste;
  }

  /// Réponse de /stats-recette-caisse/modes : {success, data:[{modeId, mode, montant, mobile, part, partCa…}]} (ou
  /// la liste seule, ou data.data). Seules les lignes mobile:true sont gardées ; « part » / « partCa » du serveur
  /// sont IGNORÉS (autre base de calcul). Refus (success:false) → « Droit manquant » ; autre format → erreur.
  static List<OperateurMobile> lireModes(dynamic r) {
    if (r == null) return const [];
    final Object? data;
    if (r is List) {
      data = r;
    } else {
      final m = lireReponseVague1(r, 'le détail Mobile Money');
      final d = m['data'];
      data = d is Map ? d['data'] : d;
    }
    if (data == null) return const [];
    if (data is! List) {
      throw const ApiLoadException('Réponse inattendue du serveur pour le détail Mobile Money.', nature: NatureErreur.reponse);
    }
    return cumulerOperateurs([
      for (final e in data)
        if (e is Map && booleenTolerant(e['mobile'])) OperateurMobile.lire(e)!,
    ]);
  }

  /// Appel complémentaire, avec EXACTEMENT les dates de /ca-all.
  static Future<List<OperateurMobile>> chargerModes(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async =>
      lireModes(await ApiService().get(context, routeModes, queryParams: parametres(debut, fin), onSessionInvalid: onSessionInvalid));
}

/// Origine du détail par opérateur.
enum SourceDetailMobile {
  /// Champ « detailMobile » de /ca-all (même calcul que totMobile) : jamais d'écart.
  caAll,

  /// GET /stats-recette-caisse/modes : autre calcul du serveur, écart possible avec totMobile.
  modes,
}

/// Détail du Mobile Money de la période. Totaux de référence : ceux de /ca-all ([totMobile], et [caGlobal] = le
/// « Total brut paiements » affiché par l'écran, CaComptant.totalPaiements).
class DetailMobile {
  final List<OperateurMobile> operateurs;
  final double totMobile;
  final double caGlobal;
  final SourceDetailMobile source;
  const DetailMobile({required this.operateurs, required this.totMobile, required this.caGlobal, required this.source});

  double get somme => operateurs.fold(0.0, (s, o) => s + o.montant);

  /// « Autres / écart » = totMobile − Σ opérateurs ; null si nul (moins d'un franc) ou si le détail vient de /ca-all.
  double? get ecart {
    if (source == SourceDetailMobile.caAll) return null;
    final e = totMobile - somme;
    return e.abs() < 0.5 ? null : e;
  }

  /// Taux dans le total Mobile Money (en %), null si ce total est nul.
  double? tauxMobile(double montant) => totMobile == 0 ? null : montant / totMobile * 100;

  /// Taux dans le chiffre d'affaires global (en %), null si celui-ci est nul.
  double? tauxCa(double montant) => caGlobal == 0 ? null : montant / caGlobal * 100;
}
