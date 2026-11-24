// Faux serveur À JOUR pour la 3.17.0 (réponse du serveur aux demandes 67 et 68, branche serveur
// correctif/demandes67-68-2011, pas encore déployée en officine) — données fictives uniquement :
//  - GET /ca-credit : sans « limit », la liste (filtrée si query / tiersPayant) ; avec « limit », la page
//    { total, montant, clients, tiersPayants, data } calculée comme PageCaCredit du serveur : filtres (query
//    « contient » sans casse sur client, ayant droit, facture, tiers payant ; tiersPayant = libellé sans casse ni
//    espaces autour, ou identifiant), tri date décroissante puis facture, totaux de TOUTES les lignes retenues,
//    tiers payants de la période AVANT filtres, page vide au-delà du total ;
//  - GET /tableau-bord/tva : { success, data : [{ taux, ht, tva, ttc }] } (mêmes montants que /api/v3/tvas TOUT).
import 'donnees_lot3.dart';
import '../serveur_fictif.dart';

class Donnees3170 {
  Donnees3170._();

  /// Lignes retenues par query / tiersPayant (ordre d'origine), comme PageCaCredit.filtrer.
  static List<Map<String, Object?>> filtrer(List<Map<String, Object?>> lignes, String? query, String? tiersPayant) {
    final q = (query ?? '').trim().toLowerCase();
    final tp = (tiersPayant ?? '').trim();
    bool contient(Object? v) => v is String && v.toLowerCase().contains(q);
    return [
      for (final o in lignes)
        if ((q.isEmpty || contient(o['clientName']) || contient(o['ayantDroitName']) || contient(o['numFacturation']) || contient(o['tiersPayantLibelle'])) &&
            (tp.isEmpty || '${o['tiersPayantLibelle'] ?? ''}'.trim().toLowerCase() == tp.toLowerCase() || o['tiersPayantId'] == tp))
          o,
    ];
  }

  /// Ordre du serveur : date décroissante, puis numéro de facture.
  static List<Map<String, Object?>> trier(List<Map<String, Object?>> l) => [...l]..sort((a, b) {
        final d = '${b['mvtDate']}'.compareTo('${a['mvtDate']}');
        return d != 0 ? d : '${a['numFacturation']}'.compareTo('${b['numFacturation']}');
      });

  /// Réponse de GET /ca-credit d'un serveur à jour pour les paramètres [p].
  static Object caCredit(List<Map<String, Object?>> lignes, Map<String, String> p) {
    final retenues = filtrer(lignes, p['query'], p['tiersPayant']);
    final limit = int.tryParse(p['limit'] ?? '');
    if (limit == null) return retenues;
    final triees = trier(retenues);
    final debut = (int.tryParse(p['start'] ?? '') ?? 0).clamp(0, 1 << 30);
    final data = debut >= triees.length || limit <= 0 ? const <Map<String, Object?>>[] : triees.sublist(debut, (debut + limit).clamp(0, triees.length));
    return {
      'total': retenues.length,
      'montant': retenues.fold<num>(0, (s, o) => s + (o['montant'] as num)),
      'clients': {for (final o in retenues) o['clientId'] != null ? 'id:${o['clientId']}' : 'nom:${o['clientName']}'}.length,
      'tiersPayants': ({for (final o in lignes) if (o['tiersPayantLibelle'] is String) o['tiersPayantLibelle'] as String}.toList()..sort()),
      'data': data,
    };
  }

  /// Installe /ca-credit « serveur à jour » sur [s] ; [delai] : délai d'une réponse (null = immédiat).
  static void installerCaCredit(ServeurFictif s, List<Map<String, Object?>> lignes, {Duration? Function(Map<String, String> p)? delai}) =>
      s.route('/ca-credit', (r) {
        final rep = ReponseFausse.json(caCredit(lignes, r.parametres));
        final d = delai?.call(r.parametres);
        return d == null ? rep : rep.apres(d);
      }, methode: 'GET');

  /// Première page sans filtre (le serveur lit toute la période) ?
  static bool premiere(Map<String, String> p) =>
      (int.tryParse(p['start'] ?? '') ?? 0) <= 0 && (p['query'] ?? '').trim().isEmpty && (p['tiersPayant'] ?? '').trim().isEmpty;

  /// Ventes fictives avec un libellé de tiers payant précédé d'une espace (comme « VITALIS NSIA » en base).
  static const tiersEspace = ' MUTUELLE FICTIVE ESPACE';
  static List<Map<String, Object?>> ventesAvecEspace() => [
        ...DonneesLot3.caCredit(),
        {
          'clientId': 'CLI-ESP-1', 'clientName': 'CLIENT FICTIF DELTA', 'ayantDroitName': 'CLIENT FICTIF DELTA', 'numFacturation': 'FAC-T-007',
          'tiersPayantId': 'TP-3', 'tiersPayantLibelle': tiersEspace, 'montant': 7000, 'mvtDate': '20261015',
        },
      ];

  /// GET /tableau-bord/tva : les montants de DonneesLot3.statTva('TOUT') au format de la nouvelle route.
  static Map<String, Object?> tva() => {
        'success': true,
        'data': [
          for (final l in (DonneesLot3.statTva('TOUT')['data'] as List).cast<Map<String, Object?>>())
            {'taux': l['TAUX'], 'ht': l['Total HT'], 'tva': l['Total TVA'], 'ttc': l['Total TTC']},
        ],
      };
}
