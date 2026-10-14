// Données FICTIVES et routes par défaut du faux serveur pour la vague 1 des nouveaux menus (valorisation rayon /
// réserve / total, alertes du tableau de bord, retraits et abandons, ventes modifiées). Formats réels du serveur
// Prestige (branche claude/new-session-xm8ptu), données inventées. Les listes /common/rayons, /common/grossiste et
// /common/users, déjà lues par d'autres modules, gardent leur réponse par défaut (liste vide) : les tests de la
// vague 1 les scriptent eux-mêmes ([listesCommunesVague1]).
import 'package:intl/intl.dart';

import 'donnees_fictives.dart';
import 'faux_serveur_prestige.dart';

class DonneesVague1 {
  DonneesVague1._();

  // --- Valorisation ---
  static const rayonAchat = 12500000, rayonVente = 18750000, reserveAchat = 3200000, reserveVente = 4800000;

  /// GET /tableau-bord/valorisation.
  static Map<String, Object?> valorisationTableauDeBord() => {
        'success': true,
        'rayon': {'achat': rayonAchat, 'vente': rayonVente},
        'reserve': {'achat': reserveAchat, 'vente': reserveVente},
        'total': {'achat': rayonAchat + reserveAchat, 'vente': rayonVente + reserveVente},
        'dormants': {'produits': 37, 'valeurAchat': 410000, 'vendus': 0},
      };

  static const passeRayonAchat = 11000000, passeRayonVente = 16500000, passeReserveAchat = 2000000, passeReserveVente = 3000000;

  /// GET /produit/valorisation (date passée ou regroupement).
  static Map<String, Object?> valorisationProduit({bool releve = true}) => {
        'data': {
          'value': passeRayonAchat,
          'valueTwo': passeRayonVente,
          'reserveValue': passeReserveAchat,
          'reserveValueTwo': passeReserveVente,
          'totalValue': passeRayonAchat + passeReserveAchat,
          'totalValueTwo': passeRayonVente + passeReserveVente,
          'releveDisponible': releve,
        },
        'user': DonneesFictives.nomComplet,
        'dtCREATED': '14/10/2026 09:00',
      };

  static Map<String, Object?> combo(List<(String, String)> l) => {
        'success': true,
        'total': l.length + 1,
        'data': [for (final (id, libelle) in l) {'id': id, 'libelle': libelle}, {'id': 'ALL', 'libelle': 'Tous'}],
      };

  static Map<String, Object?> familles() => combo([('FAM-TEST-1', 'ANTALGIQUES FICTIFS'), ('FAM-TEST-2', 'SIROPS IMAGINAIRES')]);
  static Map<String, Object?> rayons() => combo([('ZONE-TEST-1', 'RAYON A'), ('ZONE-TEST-2', 'RAYON B')]);
  static Map<String, Object?> grossistes() => combo([('GRO-TEST-1', 'GROSSISTE FICTIF'), ('GRO-TEST-2', 'GROSSISTE IMAGINAIRE')]);

  // --- Utilisateurs (filtre des journaux) ---
  static const utilisateur1 = 'CAISSIERE Fictive Une', utilisateur1Id = 'USR-TEST-0101';
  static const utilisateur2 = 'VENDEUR Fictif Deux', utilisateur2Id = 'USR-TEST-0102';
  static Map<String, Object?> utilisateurs() => {
        'total': 2,
        'data': [
          {'lgUSERID': utilisateur1Id, 'fullName': utilisateur1},
          {'lgUSERID': utilisateur2Id, 'fullName': utilisateur2},
        ],
      };

  // --- Alertes ---
  static const ruptures = 12, negatifs = 2, nonVendus = 4;

  /// GET /tableau-bord/alertes : lots en péremption = ceux du Suivi Péremption fictif (3 lots).
  static Map<String, Object?> alertes() => {
        'success': true,
        'ruptures': {'produits': ruptures, 'vendusRecemment': 4, 'jours': 7, 'fenetre': 90},
        'peremptions': {'produits': 3, 'lots': DonneesFictives.lotsPerimes, 'valeurAchat': 7200, 'mois': 6},
        'suggestionsReserve': 2,
        'suggestionsRayon': 1,
        'suggestionsCommande': {'cloturees': 1, 'jours': 2},
        'renouvellements': {'patients': 5, 'jours': 7},
        'avoirs': 0,
        'negatifs': negatifs,
        'nonVendus': {'produits': nonVendus, 'jours': 30},
      };

  /// GET /tableau-bord/alertes/liste?type=…
  static Map<String, Object?> listeAlerte(String type) {
    final lignes = switch (type) {
      'ruptures' => [
          for (var i = 1; i <= ruptures; i++)
            {'libelle': 'PRODUIT EN RUPTURE FICTIF $i', 'cip': '99920${i.toString().padLeft(2, '0')}', 'derniereVente': '2026-10-0${1 + i % 9}',
              'recent': i <= 4, 'grossiste': 'GROSSISTE FICTIF'},
        ],
      'peremptions' => [
          {'libelle': DonneesFictives.libelleArticle1, 'cip': '9990001', 'lot': 'LOT-TEST-1', 'peremption': '2026-11-15', 'quantite': 2},
          {'libelle': DonneesFictives.libelleArticle2, 'cip': '9990002', 'lot': 'LOT-TEST-2', 'peremption': '2026-12-20', 'quantite': 4},
          {'libelle': 'POMMADE FICTIVE 30G', 'cip': '9990003', 'lot': 'LOT-TEST-3', 'peremption': '2027-03-01', 'quantite': 3},
        ],
      'negatifs' => [
          {'libelle': 'GELULE NEGATIVE FICTIVE', 'cip': '9993001', 'quantite': -3, 'emplacement': 'RAYON A'},
          {'libelle': 'COLLYRE FICTIF 10ML', 'cip': '9993002', 'quantite': -1, 'emplacement': 'RAYON B'},
        ],
      'rayon' => [
          {'libelle': DonneesFictives.libelleArticle1, 'cip': '9990001', 'quantite': 6, 'reference': 'SUG-RAYON-TEST-1'},
        ],
      'nonvendus' => [
          for (var i = 1; i <= nonVendus; i++)
            {'libelle': 'PRODUIT DORMANT FICTIF $i', 'cip': '999400$i', 'entree': '2026-09-2$i', 'quantite': 5 * i, 'grossiste': 'GROSSISTE FICTIF'},
        ],
      _ => <Map<String, Object?>>[],
    };
    return {'type': type, 'success': true, 'data': lignes};
  }

  // --- Retraits et abandons ---
  static String get aujourdhui => DateFormat('dd/MM/yyyy').format(DateTime.now());

  static List<Map<String, Object?>> suppressions() {
    Map<String, Object?> l(int n, String type, String cip, String libelle, int qte, String par, String parId, String origine, String heure) => {
          'id': 'SUP-TEST-$n', 'typeSuppression': type, 'venteId': 'VTE-TEST-$n', 'venteRef': 'VTE-2026-00$n', 'produitId': 'PRD-$cip',
          'produitCip': cip, 'produitLibelle': libelle, 'quantite': qte, 'userName': par, 'userId': parId, 'origineUserName': origine,
          'date': aujourdhui, 'heure': heure,
        };
    return [
      l(1, 'PRODUIT', '9990001', DonneesFictives.libelleArticle1, 2, utilisateur1, utilisateur1Id, utilisateur1, '09:12:30'),
      l(2, 'VENTE', '9990002', DonneesFictives.libelleArticle2, 1, utilisateur2, utilisateur2Id, utilisateur1, '10:05:00'),
      l(3, 'VENTE', '9990003', 'POMMADE FICTIVE 30G', 3, utilisateur2, utilisateur2Id, utilisateur2, '10:05:00'),
      l(4, 'PRODUIT', '9990004', 'SPRAY IMAGINAIRE 20ML', 1, utilisateur1, utilisateur1Id, utilisateur2, '11:40:10'),
      l(5, 'VENTE', '9990005', 'COMPRIMES FICTIFS B/30', 2, 'Système', '', utilisateur1, '12:00:00'),
    ];
  }

  // --- Ventes modifiées ---
  static List<Map<String, Object?>> ventesModifiees() => [
        {
          'id': 'MOD-TEST-1', 'typeModification': 'PRODUITS', 'typeLibelle': 'Modification des produits', 'venteId': 'VTE-TEST-11',
          'venteOrigineId': 'VTE-TEST-10', 'venteRef': 'VTE-2026-011', 'venteDate': '$aujourdhui 08:30', 'userName': utilisateur1,
          'userId': utilisateur1Id, 'date': aujourdhui, 'heure': '09:45:00', 'montantAvant': 5400, 'montantApres': 4200,
          'description': 'Retrait d\'un produit et quantité corrigée',
          'lignes': [
            {'produitCip': '9990001', 'produitLibelle': DonneesFictives.libelleArticle1, 'action': 'RETRAIT', 'qteAvant': 1, 'qteApres': 0,
              'puAvant': 1200, 'puApres': 1200, 'montantAvant': 1200, 'montantApres': 0},
            {'produitCip': '9990002', 'produitLibelle': DonneesFictives.libelleArticle2, 'action': 'QUANTITE', 'qteAvant': 2, 'qteApres': 1,
              'puAvant': 2500, 'puApres': 2500, 'montantAvant': 5000, 'montantApres': 2500},
          ],
        },
        {
          'id': 'MOD-TEST-2', 'typeModification': 'INFOS', 'typeLibelle': 'Modification client / tiers payant', 'venteId': 'VTE-TEST-12',
          'venteRef': 'VTE-2026-012', 'venteDate': '$aujourdhui 09:00', 'userName': utilisateur2, 'userId': utilisateur2Id,
          'date': aujourdhui, 'heure': '10:15:00', 'montantAvant': 8000, 'montantApres': 8000,
          'description': 'Client : CLIENT FICTIF A → CLIENT FICTIF B', 'lignes': <Object>[],
        },
        {
          'id': 'MOD-TEST-3', 'typeModification': 'DATE', 'typeLibelle': 'Modification de la date', 'venteId': 'VTE-TEST-13',
          'venteRef': 'VTE-2026-013', 'venteDate': '$aujourdhui 07:50', 'userName': utilisateur1, 'userId': utilisateur1Id,
          'date': aujourdhui, 'heure': '11:00:00', 'montantAvant': 3000, 'montantApres': 3000,
          'description': 'Date de la vente avancée d\'un jour', 'lignes': <Object>[],
        },
      ];

  /// Filtre et pagination comme le serveur : type exact, utilisateur, recherche par début de CIP, de libellé ou de
  /// n° de vente ; page [start, start+limit[ ; « total » = lignes filtrées.
  static Map<String, Object?> page(List<Map<String, Object?>> lignes, Map<String, String> p, String champType) {
    final type = p['type'] ?? '', user = p['userId'] ?? '', q = (p['query'] ?? '').trim().toLowerCase();
    bool commence(Object? v) => '${v ?? ''}'.toLowerCase().startsWith(q);
    final filtrees = [
      for (final l in lignes)
        if ((type.isEmpty || l[champType] == type) &&
            (user.isEmpty || l['userId'] == user) &&
            (q.isEmpty ||
                commence(l['produitCip']) ||
                commence(l['produitLibelle']) ||
                commence(l['venteRef']) ||
                ((l['lignes'] as List?) ?? const []).any((x) => commence((x as Map)['produitCip']) || commence(x['produitLibelle']))))
          l,
    ];
    final start = int.tryParse(p['start'] ?? '') ?? 0;
    final limit = int.tryParse(p['limit'] ?? '') ?? 0;
    final fin = limit <= 0 ? filtrees.length : (start + limit).clamp(0, filtrees.length);
    return {'total': filtrees.length, 'results': start >= filtrees.length ? <Object>[] : filtrees.sublist(start, fin)};
  }
}

/// Routes par défaut de la vague 1 (appelé par FauxServeurPrestige.installerRoutesParDefaut).
void installerRoutesVague1(FauxServeurPrestige s) {
  s.quand('/tableau-bord/valorisation', ReponseFausse.json(DonneesVague1.valorisationTableauDeBord()), methode: 'GET');
  s.quand('/produit/valorisation', ReponseFausse.json(DonneesVague1.valorisationProduit()), methode: 'GET');
  s.quand('/common/famillearticles', ReponseFausse.json(DonneesVague1.familles()), methode: 'GET');
  s.quand('/tableau-bord/alertes', ReponseFausse.json(DonneesVague1.alertes()), methode: 'GET');
  s.route('/tableau-bord/alertes/liste', (r) => ReponseFausse.json(DonneesVague1.listeAlerte(r.parametres['type'] ?? '')), methode: 'GET');
  s.route('/vente-suppressions', (r) => ReponseFausse.json(DonneesVague1.page(DonneesVague1.suppressions(), r.parametres, 'typeSuppression')),
      methode: 'GET');
  s.route('/ventes-modifiees', (r) => ReponseFausse.json(DonneesVague1.page(DonneesVague1.ventesModifiees(), r.parametres, 'typeModification')),
      methode: 'GET');
}

/// Listes communes que la vague 1 utilise mais qui restent vides par défaut (lues aussi par d'autres modules).
void listesCommunesVague1(FauxServeurPrestige s) {
  s.quand('/common/rayons', ReponseFausse.json(DonneesVague1.rayons()), methode: 'GET');
  s.quand('/common/grossiste', ReponseFausse.json(DonneesVague1.grossistes()), methode: 'GET');
  s.quand('/common/users', ReponseFausse.json(DonneesVague1.utilisateurs()), methode: 'GET');
}
