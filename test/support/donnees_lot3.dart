// Données FICTIVES du lot 3 (analyses) : Tableau : Analyses, Tableau : Ratios (et Ratios mensuels), Suivi 20/80,
// Stat TVA, Marge Produits Vendus, CA Crédit, CA Global. Formats réels des routes Prestige (ceux que lisent les
// modèles de lib/models/), contenus inventés. [donneesLot3] installe les routes sur le faux serveur ; certaines
// réponses dépendent des paramètres reçus (nombre d'articles du 20/80, type de vente de la TVA), pour vérifier
// qu'ils arrivent bien au serveur.
import 'donnees_fictives.dart';
import 'faux_serveur_prestige.dart';

class DonneesLot3 {
  DonneesLot3._();

  // --- Tableau de bord achats / ventes : 9 jours sur 3 mois, volontairement dans le désordre ---
  // Ratios : 1,60 · 1,40 · 0 (sans achat) · 1,51 (pile la norme) · 2,00 · 1,25 · 1,80 · 1,50 · 1,55.
  static const jours = <(String, int, int)>[
    ('05/10/2026', 200000, 320000),
    ('02/08/2026', 250000, 350000),
    ('06/10/2026', 0, 41000),
    ('15/09/2026', 100000, 151000),
    ('03/08/2026', 90000, 180000),
    ('16/09/2026', 240000, 300000),
    ('07/10/2026', 150000, 270000),
    ('04/08/2026', 300000, 450000),
    ('17/09/2026', 400000, 620000),
  ];
  static List<Map<String, Object?>> achatsVentes() => [
        for (final (d, a, v) in jours) {'dateMvt': d, 'montantAchat': a, 'montantVente': v},
      ];
  static int get totalAchats => jours.fold(0, (s, j) => s + j.$2);
  static int get totalVentes => jours.fold(0, (s, j) => s + j.$3);

  // --- Suivi 20/80 : 120 articles, montants décroissants ; la réponse respecte « limit » ---
  static const articles2080 = 120;
  static Map<String, Object?> suivi2080(int limite) => {
        'data': [
          for (var i = 1; i <= (limite < articles2080 ? limite : articles2080); i++)
            {
              'intCIP': '34009${i.toString().padLeft(8, '0')}',
              'strNAME': i == 1 ? DonneesFictives.libelleArticle1 : (i == 2 ? DonneesFictives.libelleArticle2 : 'PRODUIT FICTIF 20-80 N$i'),
              'intPRICE': 250000 - i * 1500,
              'intQUANTITY': 300 - i * 2,
              'intQUANTITYSERVED': i % 7 == 0 ? 0 : i + 4,
            },
        ],
        'total': limite < articles2080 ? limite : articles2080,
      };
  static int montant2080(int n) => [for (var i = 1; i <= n; i++) 250000 - i * 1500].fold(0, (s, v) => s + v);

  // --- Stat TVA : 3 taux pour TOUT, 2 pour VNO, 1 pour VO ---
  static Map<String, Object?> statTva(String type) => {
        'data': switch (type) {
          'VNO' => [
              {'TAUX': 0, 'Total HT': 400000, 'Total TVA': 0, 'Total TTC': 400000, 'montantUg': 0},
              {'TAUX': 18, 'Total HT': 200000, 'Total TVA': 36000, 'Total TTC': 236000, 'montantUg': 0},
            ],
          'VO' => [
              {'TAUX': 0, 'Total HT': 650000, 'Total TVA': 0, 'Total TTC': 650000, 'montantUg': 1200},
            ],
          _ => [
              {'TAUX': 0, 'Total HT': 1050000, 'Total TVA': 0, 'Total TTC': 1050000, 'montantUg': 1200},
              {'TAUX': 9, 'Total HT': 100000, 'Total TVA': 9000, 'Total TTC': 109000, 'montantUg': 0},
              {'TAUX': 18, 'Total HT': 500000, 'Total TVA': 90000, 'Total TTC': 590000, 'montantUg': 0},
            ],
        },
      };

  // --- Marge Produits Vendus : 70 produits, marges de -5 à 64 % ---
  static const produitsMarge = 70;
  static int margePct(int i) => i - 6;
  static Map<String, Object?> marges() => {
        'data': [
          for (var i = 1; i <= produitsMarge; i++)
            {
              'code': '34008${i.toString().padLeft(8, '0')}',
              'libelle': i == 1 ? DonneesFictives.libelleArticle1 : 'PRODUIT FICTIF MARGE N$i',
              'montantCumulAchat': 10000 + i * 100,
              'montantCumulTTC': 10000 + i * 100 + (10000 + i * 100) * margePct(i) ~/ 100,
              'montantCumulMarge': (10000 + i * 100) * margePct(i) ~/ 100,
              'pourcentageCumulMage': margePct(i),
            },
        ],
      };

  // --- CA Crédit : 6 ventes, 3 clients, 2 tiers payants ---
  static const assuranceA = 'ASSURANCE FICTIVE UNE', assuranceB = 'MUTUELLE IMAGINAIRE';
  static List<Map<String, Object?>> caCredit() => [
        _credit('CLIENT FICTIF ALPHA', 'CLIENT FICTIF ALPHA', 'FAC-T-001', assuranceA, 12500, '20261013'),
        _credit('CLIENT FICTIF ALPHA', 'AYANT DROIT FICTIF', 'FAC-T-002', assuranceA, 8300, '20261013'),
        _credit('CLIENT FICTIF BETA', 'CLIENT FICTIF BETA', 'FAC-T-003', assuranceB, 21000, '20261014'),
        _credit('CLIENT FICTIF GAMMA', 'CLIENT FICTIF GAMMA', 'FAC-T-004', assuranceA, 4700, '20261014'),
        _credit('CLIENT FICTIF BETA', 'CLIENT FICTIF BETA', 'FAC-T-005', assuranceB, 9900, '20261012'),
        _credit('CLIENT FICTIF GAMMA', 'ENFANT FICTIF', 'FAC-T-006', assuranceB, 15600, '20261012'),
      ];
  static const totalCredit = 12500 + 8300 + 21000 + 4700 + 9900 + 15600;
  static Map<String, Object?> _credit(String client, String ayantDroit, String facture, String tiers, int montant, String date) => {
        'clientId': 'CLI-${client.hashCode.abs() % 1000}',
        'clientName': client,
        'ayantDroitName': ayantDroit,
        'numFacturation': facture,
        'tiersPayantId': tiers == assuranceA ? 'TP-1' : 'TP-2',
        'tiersPayantLibelle': tiers,
        'montant': montant,
        'mvtDate': date,
      };
}

/// Routes du lot 3 sur le faux serveur (CA Global : /ca-all de DonneesFictives.caParJour, 3 jours).
void donneesLot3(FauxServeurPrestige serveur) {
  serveur
    ..quand('/ws/ca-achats-ventes', ReponseFausse.json(DonneesLot3.achatsVentes()), methode: 'GET')
    ..route('/statfamillearticle/vingtQuatreVingt', (r) => ReponseFausse.json(DonneesLot3.suivi2080(int.tryParse(r.parametres['limit'] ?? '') ?? 50)),
        methode: 'GET')
    ..route('/tvas', (r) => ReponseFausse.json(DonneesLot3.statTva(r.parametres['typeVente'] ?? 'TOUT')), methode: 'GET')
    ..quand('/datareporting/margeproduitsvendus', ReponseFausse.json(DonneesLot3.marges()), methode: 'GET')
    ..quand('/ca-credit', ReponseFausse.json(DonneesLot3.caCredit()), methode: 'GET')
    ..quand('/ca-all', ReponseFausse.json(DonneesFictives.caParJour()), methode: 'GET');
}
