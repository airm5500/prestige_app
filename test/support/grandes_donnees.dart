// GRANDES données FICTIVES pour les tests de performance et de réseau : mêmes formats que les routes réelles de
// Prestige (ceux de donnees_fictives.dart, donnees_lot2/3/4.dart, donnees_vague2.dart), en grand nombre.
import 'donnees_lot2.dart';
import 'donnees_vague2.dart';
import 'faux_serveur_prestige.dart';

class GrandesDonnees {
  GrandesDonnees._();

  /// GET /recap/credits : [n] tiers payants.
  static Map<String, Object?> credits(int n) => {
        'data': [
          for (var i = 1; i <= n; i++)
            {
              'libelleTypeTiersPayant': ['ASSURANCE', 'CLIENT EN COMPTE', 'MUTUELLE'][i % 3],
              'libelleTiersPayant': 'TIERS PAYANT FICTIF $i',
              'nbreClient': 1 + i % 17,
              'nbreBons': 1 + i % 23,
              'montant': 5000 + i * 137,
            },
        ],
      };

  /// GET /suggestion/list/items : [n] lignes (identifiants ITEM-PERF-1 … ITEM-PERF-n).
  static Map<String, Object?> lignesSuggestion(int n) => {
        'data': [
          for (var i = 1; i <= n; i++)
            {
              'lg_SUGGESTION_ORDER_DETAILS_ID': 'ITEM-PERF-$i',
              'str_FAMILLE_CIP': '34009${i.toString().padLeft(8, '0')}',
              'str_FAMILLE_NAME': 'PRODUIT SUGGERE FICTIF $i CPR B/${10 + i % 20}',
              'int_VENTE': 1000 + i % 50 * 100,
              'int_ACHAT': 700 + i % 50 * 70,
              'int_STOCK': i % 7,
              'int_NUMBER': 1 + i % 12,
              'int_VALUE0': i % 9,
              'int_VALUE1': i % 11,
              'int_VALUE2': i % 13,
              'int_VALUE3': i % 5,
            },
        ],
        'total': n,
      };

  /// Un bon de livraison fictif (format de DonneesLot2.bons()).
  static Map<String, Object?> bon(int i) {
    final b = Map<String, Object?>.of(DonneesLot2.bons().first);
    b['lgBONLIVRAISONID'] = 'BL-PERF-ID-$i';
    b['strREFLIVRAISON'] = 'BL-PERF-$i';
    b['fournisseurLibelle'] = i.isEven ? DonneesLot2.grossisteA : DonneesLot2.grossisteB;
    b['checked'] = ['TERMINE', 'EN_COURS', 'NON_TRAITE'][i % 3];
    b['intMHT'] = 100000 + i * 10;
    b['intTVA'] = 18000 + i;
    b['intHTTC'] = 118000 + i * 11;
    return b;
  }

  /// GET /etat-control-bon/list : [n] bons, paginés comme le serveur (start / limit, « total »).
  static ReponseFausse pageBons(RequeteRecue r, int n) {
    final start = int.tryParse(r.parametres['start'] ?? '0') ?? 0;
    final limit = int.tryParse(r.parametres['limit'] ?? '20') ?? 20;
    return ReponseFausse.json({
      'total': n,
      'data': [for (var i = start + 1; i <= n && i <= start + limit; i++) bon(i)],
    });
  }

  /// GET /analyse-commande/previsions : [n] produits, paginés (start / limit).
  static Map<String, Object?> previsions(Map<String, String> p, int n) {
    final start = int.tryParse(p['start'] ?? '') ?? 0, limit = int.tryParse(p['limit'] ?? '') ?? 25;
    return {
      'success': true,
      'total': n,
      'data': [for (var i = start + 1; i <= n && i <= start + limit; i++) DonneesVague2.lignePrevision(i)],
      'couvertureVoulue': 15,
    };
  }

  /// GET /ca-zone-geo : [tranches] semaines × [lignes] emplacements (colonnes dynamiques t_ / q_ / e_).
  static Map<String, Object?> caZone({required int tranches, required int lignes}) {
    final t = [
      for (var k = 1; k <= tranches; k++)
        {'cle': 'T$k', 'libelle': 'S$k', 'debut': '', 'fin': '', 'enCours': k == tranches},
    ];
    final totaux = <String, int>{};
    final data = <Map<String, Object?>>[];
    for (var i = 0; i < lignes; i++) {
      final l = <String, Object?>{
        'zoneId': 'ZONE-PERF-$i',
        'zone': 'RAYON FICTIF $i',
        'familleId': '',
        'famille': '',
        'libelle': 'RAYON FICTIF $i',
        'montantHt': 0,
        'achat': 0,
        'tva': 0,
        'marge': 10000 + i,
        'pourcentageMarge': 30.5,
      };
      var total = 0;
      int? precedent;
      for (final tr in t) {
        final cle = tr['cle']! as String;
        final v = 50000 + i * 1000 + cle.hashCode % 5000;
        l['t_$cle'] = v;
        l['q_$cle'] = v ~/ 1000;
        l['e_$cle'] = precedent == null ? null : ((v - precedent) * 1000 / precedent).round() / 10;
        precedent = v;
        total += v;
        totaux[cle] = (totaux[cle] ?? 0) + v;
      }
      l['total'] = total;
      l['evolution'] = 4.5;
      data.add(l);
    }
    return {
      'success': true,
      'data': data,
      'total': data.length,
      'tranches': t,
      'granularite': 'SEMAINE',
      'totauxTranches': totaux,
      'evolutionsTranches': {for (final tr in t) tr['cle']! as String: 2.5},
      'totalGeneral': data.fold<int>(0, (s, l) => s + (l['total']! as int)),
      'margeGenerale': 150000,
      'montantHtGeneral': 600000,
      'achatGeneral': 450000,
      'pourcentageMargeGeneral': 25.0,
      'debut': '2025-08-25',
      'fin': '2026-10-14',
      'evolutionGenerale': 3.2,
    };
  }

  /// GET /ws/ca-achats-ventes : un jour par ligne sur [jours] jours finissant le [fin] (dd/MM/yyyy).
  static List<Map<String, Object?>> achatsVentes(int jours, DateTime fin) => [
        for (var i = 0; i < jours; i++)
          () {
            final d = fin.subtract(Duration(days: i));
            String d2(int n) => n.toString().padLeft(2, '0');
            return {
              'dateMvt': '${d2(d.day)}/${d2(d.month)}/${d.year}',
              'montantAchat': i % 6 == 0 ? 0 : 150000 + (i * 7919) % 250000,
              'montantVente': 200000 + (i * 104729) % 300000,
            };
          }(),
      ];

  /// GET /valorisation/all : [n] points (Évolution du stock, un point par jour, format de DonneesLot2.valorisations).
  static List<Map<String, Object?>> valorisations(int n) => [
        for (var i = 0; i < n; i++) {'valeurAchat': 10000000 + (i * 7919) % 900000 + i * 1000, 'valeurVente': 14000000 + (i * 104729) % 1200000 + i * 1400},
      ];

  /// POST /caisse/fetch-tickez : [caissiers] caissiers × [modes] modes de paiement (montants formatés par le serveur).
  static Map<String, Object?> ticketZ({int caissiers = 40, int modes = 8}) => {
        'success': true,
        'data': {
          'datas': [
            for (var c = 1; c <= caissiers; c++)
              {
                'user': 'CAISSIER FICTIF $c',
                'modePaymentAmounts': [
                  for (var m = 1; m <= modes; m++) {'modeLibelle': 'Mode fictif $m', 'montant': '${c * 1000 + m * 100} 500'},
                ],
                'totaux': [
                  {'modeLibelle': 'Total encaissé', 'montant': '${c * 9} 000'},
                  {'modeLibelle': 'Total Sortie Vir', 'montant': '-1 500'},
                ],
              },
          ],
          'totaux': [
            {'modeLibelle': 'TOTAL ESP', 'montant': '9 204 300'},
            {'modeLibelle': 'TOTAL OM', 'montant': '1 024 500'},
            {'modeLibelle': 'TOTAL DIFFERE', 'montant': '-2 000'},
            {'modeLibelle': 'TOTAL (VNO/VO)', 'montant': '658 900'},
          ],
        },
      };

  /// GET /datareporting/margeproduitsvendus : [n] produits.
  static Map<String, Object?> marges(int n) => {
        'data': [
          for (var i = 1; i <= n; i++)
            {
              'code': '34008${i.toString().padLeft(8, '0')}',
              'libelle': 'PRODUIT FICTIF MARGE N$i',
              'montantCumulAchat': 10000 + i * 100,
              'montantCumulTTC': 13000 + i * 130,
              'montantCumulMarge': 3000 + i * 30,
              'pourcentageCumulMage': 23,
            },
        ],
      };

  /// GET /ca-credit : [n] ventes à crédit.
  static List<Map<String, Object?>> caCredit(int n) => [
        for (var i = 1; i <= n; i++)
          {
            'clientId': 'CLI-$i',
            'clientName': 'CLIENT FICTIF ${i % 120}',
            'ayantDroitName': i % 4 == 0 ? 'AYANT DROIT FICTIF $i' : 'CLIENT FICTIF ${i % 120}',
            'numFacturation': 'FAC-P-$i',
            'tiersPayantId': 'TP-${i % 9}',
            'tiersPayantLibelle': 'ASSURANCE FICTIVE ${i % 9}',
            'montant': 1000 + i * 37,
            'mvtDate': '202610${(1 + i % 14).toString().padLeft(2, '0')}',
          },
      ];

  /// GET /fichearticle/perimes : [n] lots (format de DonneesFictives.perimes()).
  static Map<String, Object?> perimes(int n) => {
        'total': n,
        'metaData': {'totalQuantiteLot': n * 3, 'totalValeurAchat': n * 2400, 'totalValeurVente': n * 3600, 'periode': 0},
        'data': [
          for (var i = 1; i <= n; i++)
            {
              'libelle': 'PRODUIT FICTIF PÉRIMÉ $i', 'codeCip': '999${i.toString().padLeft(4, '0')}', 'numLot': 'LOT-P-$i', 'datePerement': '30/09/2026',
              'statut': i.isEven ? 'Périmé' : 'Périme dans 1 mois', 'quantiteLot': 3, 'valeurAchat': 2400, 'valeurVente': 3600, 'libelleRayon': 'RAYON A',
              'libelleGrossiste': 'GROSSISTE FICTIF', 'libelleFamille': 'FAMILLE FICTIVE',
            },
        ],
      };
}
