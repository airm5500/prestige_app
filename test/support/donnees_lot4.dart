// Données FICTIVES du lot 4 (« le reste ») : Récap de caisse (ticket Z), Achats Fourn., Fichier Journal, Annulation
// Ventes. Formats réels des routes Prestige (ceux que lisent les modèles de lib/models/), contenus inventés.
// [donneesLot4] installe les routes sur le faux serveur ; certaines réponses dépendent des paramètres reçus (caissier
// du ticket Z, opération et utilisateur du journal, numéro de la recherche de ventes) pour vérifier qu'ils arrivent
// bien au serveur. L'annulation garde son état : une vente annulée revient « cancel: true » à la relecture.
import 'faux_serveur_prestige.dart';

class DonneesLot4 {
  DonneesLot4._();

  // --- Utilisateurs (caissiers du ticket Z, filtre du journal) ---
  static const caissier1 = 'CAISSIERE FICTIVE UNE';
  static const caissier2 = 'CAISSIER FICTIF DEUX';
  static Map<String, Object?> utilisateurs() => {
        'total': 2,
        'data': [
          {'lgUSERID': 'USR-C1', 'fullName': caissier1},
          {'lgUSERID': 'USR-C2', 'fullName': caissier2},
        ],
      };

  // --- Ticket Z : montants déjà formatés par le serveur ---
  static Map<String, Object?> _caissier(String nom, String esp, String om, String total) => {
        'user': nom,
        'modePaymentAmounts': [
          {'modeLibelle': 'Espèces', 'montant': esp},
          {'modeLibelle': 'Orange Money', 'montant': om},
        ],
        'totaux': [
          {'modeLibelle': 'Total encaissé', 'montant': total},
          {'modeLibelle': 'Total Sortie Vir', 'montant': '-1 500'},
        ],
      };

  static const totalEsp = '204 300';
  static const totalVnoVo = '58 900';

  static Map<String, Object?> ticketZ(String userId) => {
        'success': true,
        'data': {
          'datas': [
            if (userId == 'ALL' || userId == 'USR-C1') _caissier(caissier1, '125 000', '18 400', '143 400'),
            if (userId == 'ALL' || userId == 'USR-C2') _caissier(caissier2, '79 300', '6 100', '85 400'),
          ],
          'totaux': userId == 'USR-C2'
              ? [
                  {'modeLibelle': 'TOTAL ESP', 'montant': '79 300'},
                  {'modeLibelle': 'TOTAL OM', 'montant': '6 100'},
                ]
              : [
                  {'modeLibelle': 'TOTAL ESP', 'montant': totalEsp},
                  {'modeLibelle': 'TOTAL OM', 'montant': '24 500'},
                  {'modeLibelle': 'TOTAL DIFFERE', 'montant': '-2 000'},
                  {'modeLibelle': 'TOTAL (VNO/VO)', 'montant': totalVnoVo},
                ],
        },
      };

  // --- Achats fournisseurs ---
  static const fournisseurA = 'GROSSISTE FICTIF ALPHA';
  static const fournisseurB = 'GROSSISTE FICTIF BETA';
  static List<Map<String, Object?>> fournisseurs() => [
        {'fournisseurId': 'FRS-A', 'fournisseurLibelle': fournisseurA},
        {'fournisseurId': 'FRS-B', 'fournisseurLibelle': fournisseurB},
      ];

  static const achatsLignes = <(String, String, int, int, String, String)>[
    ('FRS-A', fournisseurA, 100000, 18000, 'BL-A-001', 'CMD-0001'),
    ('FRS-B', fournisseurB, 50000, 9000, 'BL-B-077', 'CMD-0002'),
    ('FRS-A', fournisseurA, 20000, 0, 'BL-A-002', 'CMD-0003'),
    ('FRS-B', fournisseurB, 35000, 6300, 'BL-B-078', 'CMD-0004'),
  ];
  static List<Map<String, Object?>> achats() => [
        for (final (id, lib, ht, tva, bl, cmd) in achatsLignes)
          {
            'fournisseurId': id,
            'fournisseurLibelle': lib,
            'montantHT': ht,
            'montantTVA': tva,
            'montantTTC': ht + tva,
            'mvtDate': '20261012',
            'numeroBL': bl,
            'numeroCommade': cmd,
          },
      ];
  static int get totalTtc => achatsLignes.fold(0, (s, a) => s + a.$3 + a.$4);

  // --- Fichier Journal ---
  static List<Map<String, Object?>> operations() => [
        {'strDESCRIPTION': 'Ventes', 'order': 1},
        {'strDESCRIPTION': 'Annulations', 'order': 4},
      ];
  /// Journal fictif, paginé comme le vrai serveur (LogServiceImpl : `start` / `limit`, « total » = nombre d'actions
  /// correspondant aux filtres). [avecTotal] = false : serveur qui ne pagine pas (ni start, ni limit, ni total).
  static Map<String, Object?> journal(
      {required String criteria, required String userId, int nombre = 6, int start = 0, int? limit, bool avecTotal = true}) {
    final lignes = <Map<String, Object?>>[
      for (var i = 0; i < nombre; i++)
        {
          'operationDate': '2026-10-13T0${i % 9}:15:00',
          'strTYPELOG': i.isEven ? 'Vente' : 'Annulation',
          'userFullName': i % 3 == 0 ? caissier2 : caissier1,
          'HEURE': '0${i % 9}:15',
          'strDESCRIPTION': 'Action fictive N${i + 1}',
        },
    ];
    final tout = [
      for (final l in lignes)
        if ((criteria == '-1' || (criteria == '4') == (l['strTYPELOG'] == 'Annulation')) &&
            (userId.isEmpty || (userId == 'USR-C2') == (l['userFullName'] == caissier2)))
          l,
    ];
    if (!avecTotal) return {'data': tout};
    return {'total': tout.length, 'data': tout.skip(start).take(limit ?? tout.length).toList()};
  }

  /// Réponse de /common/logs pour la requête [r] (filtres, start, limit), avec [nombre] actions en tout.
  static ReponseFausse journalPour(RequeteRecue r, {int nombre = 6, bool avecTotal = true}) => ReponseFausse.json(journal(
        criteria: r.parametres['criteria'] ?? '-1',
        userId: r.parametres['userId'] ?? '',
        nombre: nombre,
        start: int.tryParse(r.parametres['start'] ?? '') ?? 0,
        limit: int.tryParse(r.parametres['limit'] ?? ''),
        avecTotal: avecTotal,
      ));

  // --- Annulation de ventes ---
  static const idA = 'b097fac5-0000-4000-8000-00000000000a';
  static const idB = '838b80ed-0000-4000-8000-00000000000b';
  static const refA = '261013_00001';
  static const refB = '261013_00002';
  static const clientA = 'CLIENT FICTIF ANNULATION';

  /// Ventes annulées (état du faux serveur).
  static final annulees = <String>{};

  static Map<String, Object?> vente(String id, String ref, int prix) => {
        'strREFTICKET': '5240513328',
        'cancel': annulees.contains(id),
        'lgPREENREGISTREMENTID': id,
        'strTYPEVENTE': 'VNO',
        'strSTATUT': 'is_Closed',
        'avoir': false,
        'intPRICE': prix,
        'HEUREVENTE': '14:52',
        'userVendeurName': 'VENDEUR FICTIF',
        'dtCREATED': '13/10/2026',
        'strREF': ref,
      };

  static Map<String, Object?> ventes(String query) => {
        'total': 2,
        'data': [
          if (refA.contains(query)) vente(idA, refA, 2500),
          if (refB.contains(query)) vente(idB, refB, 7200),
        ],
      };

  static Map<String, Object?> detail(String id) => {
        'data': {
          'strREF': id == idA ? refA : refB,
          'intPRICE': id == idA ? 2500 : 7200,
          'dtCREATED': '13/10/2026',
          'bISCANCEL': annulees.contains(id),
          'typeVente': {'libelle': 'VENTE AU COMPTANT'},
          'vendeur': {'fullName': 'VENDEUR FICTIF'},
          'client': id == idA ? {'fullName': clientA} : null,
          'items': [
            {'produit': {'strDESCRIPTION': 'PRODUIT FICTIF ANNULATION 1'}, 'intQUANTITY': 2, 'intPRICEUNITAIR': 1000, 'intPRICE': 2000},
            {'produit': {'strDESCRIPTION': 'PRODUIT FICTIF ANNULATION 2'}, 'intQUANTITY': 1, 'intPRICEUNITAIR': 500, 'intPRICE': 500},
          ],
        },
      };
}

/// Routes du lot 4 sur le faux serveur (l'état des annulations est remis à zéro).
void donneesLot4(FauxServeurPrestige s) {
  DonneesLot4.annulees.clear();
  s
    ..quand('/common/users', ReponseFausse.json(DonneesLot4.utilisateurs()), methode: 'GET')
    ..route('/caisse/fetch-tickez', (r) => ReponseFausse.json(DonneesLot4.ticketZ('${(r.json as Map)['userId']}')), methode: 'POST')
    ..quand('/fournisseurs', ReponseFausse.json(DonneesLot4.fournisseurs()), methode: 'GET')
    ..quand('/achats-fournisseurs', ReponseFausse.json(DonneesLot4.achats()), methode: 'GET')
    ..quand('/common/log-filtres', ReponseFausse.json({'data': DonneesLot4.operations()}), methode: 'GET')
    ..route('/common/logs', (r) => DonneesLot4.journalPour(r), methode: 'GET')
    ..route('/ventestats', (r) => ReponseFausse.json(DonneesLot4.ventes(r.parametres['query'] ?? '')), methode: 'GET');
  for (final id in [DonneesLot4.idA, DonneesLot4.idB]) {
    s
      ..route('/ventestats/find-one/$id', (_) => ReponseFausse.json(DonneesLot4.detail(id)), methode: 'GET')
      ..route('/vente/annulation/$id', (_) {
        DonneesLot4.annulees.add(id);
        return ReponseFausse.json({'success': true});
      }, methode: 'GET');
  }
}
