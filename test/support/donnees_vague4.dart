// Données FICTIVES et routes par défaut du faux serveur pour les menus de la 3.11.0 (Balance vente / caisse,
// Sur-stocks, Saisies en périmés, tableau de bord). Formats réels du serveur Prestige (BalanceVenteRessource,
// VentilationBalance, AnalyseBalance, SurstockRessource / SurstockServiceImpl, FicheArticleRessource.saisiePerimes,
// TableauBordRessource / TableauBordServiceImpl, PilotageRessource « suivi/frequentation ») ; données inventées.
import 'faux_serveur_prestige.dart';

class DonneesVague4 {
  DonneesVague4._();

  // --- Balance vente / caisse ---
  static const netBalance = 845000;

  static Map<String, Object?> balance() => {
        'total': 2,
        'data': [
          {'typeVente': 'VNO', 'nbreVente': 52, 'montantTTC': 640000, 'montantNet': 610000, 'montantRemise': 30000, 'panierMoyen': 11731, 'pourcentage': 72},
          {'typeVente': 'VO', 'nbreVente': 18, 'montantTTC': 245000, 'montantNet': 235000, 'montantRemise': 10000, 'panierMoyen': 13056, 'pourcentage': 28},
        ],
        'metaData': {
          'nbreVente': 70, 'montantTTC': 885000, 'montantRemise': 40000, 'montantNet': netBalance, 'montantAchat': 600000, 'marge': 245000,
          'panierMoyen': 12071, 'montantEsp': 400000, 'montantCB': 50000, 'montantCheque': 0, 'montantVirement': 10000,
          'montantMobilePayment': 150000, 'montantTp': 185000, 'montantDiff': 50000,
        },
        'ventilation': {
          'totalVentes': 70,
          'chiffreAffaires': netBalance,
          'comptant': {'ventes': 52, 'montant': 610000, 'partVentes': 74.3, 'partMontant': 72.2},
          'credit': {'ventes': 18, 'montant': 235000, 'partVentes': 25.7, 'partMontant': 27.8},
          'modes': [
            {'modeId': '1', 'libelle': 'Espèces', 'mobile': false, 'montant': 400000, 'part': 47.3, 'ventes': 40, 'partVentes': 57.1},
            {'modeId': '7', 'libelle': 'Orange Money', 'mobile': true, 'montant': 150000, 'part': 17.8, 'ventes': 12, 'partVentes': 17.1},
          ],
          'caisse': {
            'fondCaisse': {'nombre': 1, 'montant': 50000},
            'entrees': {'nombre': 2, 'montant': 20000},
            'sorties': {'nombre': 1, 'montant': 15000},
            'reglementsTp': {'nombre': 0, 'montant': 0},
            'reglementsDifferes': {'nombre': 1, 'montant': 30000},
          },
          'tva': [
            {'taux': 0, 'montantHt': 700000, 'montantTva': 0, 'montantTtc': 700000, 'part': 82.8},
            {'taux': 18, 'montantHt': 122881, 'montantTva': 22119, 'montantTtc': 145000, 'part': 17.2},
          ],
        },
      };

  static Map<String, Object?> analyse(String type) {
    Map<String, Object?> ligne(String libelle, int net, int ventes, {bool enCours = false, double? evol}) => {
          'cle': libelle, 'libelle': libelle, 'enCours': enCours, 'nbreVente': ventes, 'montantTTC': net + 20000, 'montantRemise': 20000,
          'montantNet': net, 'montantAchat': net * 7 ~/ 10, 'marge': net * 3 ~/ 10, 'panierMoyen': ventes == 0 ? 0 : net ~/ ventes,
          'montantEsp': net ~/ 2, 'montantCB': 0, 'montantCheque': 0, 'montantVirement': 0, 'montantMobilePayment': net ~/ 4, 'montantTp': net ~/ 4,
          'montantDiff': 0, 'parModes': {'1': net ~/ 2, '7': net ~/ 4},
          'evolutions': {'montantNet': evol, 'nbreVente': evol, 'panierMoyen': null, 'montantAchat': evol, 'marge': evol, 'parModes': {'1': evol, '7': evol}},
          'ecartPourcentage': evol,
        };
    return {
      'success': true,
      'total': 3,
      'data': [
        ligne('S40 ($type)', 4000000, 400),
        ligne('S41', 4400000, 420, evol: 10.0),
        ligne('S42', 1300000, 130, enCours: true, evol: -70.5),
      ],
      'modes': [
        {'modeId': '1', 'libelle': 'Espèces', 'mobile': false},
        {'modeId': '7', 'libelle': 'Orange Money', 'mobile': true},
      ],
      'totalGeneral': {'libelle': 'TOTAL GÉNÉRAL', 'total': true, 'nbreVente': 950, 'montantNet': 9700000, 'montantTTC': 9760000, 'montantRemise': 60000,
          'montantAchat': 6790000, 'marge': 2910000, 'panierMoyen': 10274, 'parModes': {'1': 4850000, '7': 2425000}},
      'comparatif': true,
    };
  }

  // --- Sur-stocks ---
  static const surstocksTotal = 120;

  static Map<String, Object?> surstocks(Map<String, String> p) {
    final start = int.tryParse(p['start'] ?? '') ?? 0;
    final limit = int.tryParse(p['limit'] ?? '') ?? 50;
    final fin = (start + limit).clamp(0, surstocksTotal);
    return {
      'total': surstocksTotal,
      'totalValeur': 3600000,
      'mois': {'mois0': 'oct.', 'mois1': 'sept.', 'mois2': 'août', 'mois3': 'juil.', 'moisEnCours': 'oct.', 'histDebut': 'juil.', 'histFin': 'sept.'},
      'data': [
        for (var i = start; i < fin; i++)
          {
            'id': 'SUR-$i', 'cip': '${7000000 + i}', 'libelle': 'PRODUIT SURSTOCK FICTIF $i', 'emplacement': 'RAYON A', 'datePeremption': '',
            'prixAchat': 1000, 'prixVente': 1500, 'stock': 60, 'qteVendue': 9, 'mois0': 1, 'mois1': 3, 'mois2': 3, 'mois3': 3,
            'qteSurplus': 30, 'valeurSurplus': 30000, 'moyenneMensuelle': 3.0, 'nbMoisStock': 20.0, 'coefficient': 6.67,
          },
      ],
    };
  }

  // --- Saisies en périmés ---
  static Map<String, Object?> saisiesPerimes(Map<String, String> p) {
    final limit = int.tryParse(p['limit'] ?? '') ?? 50;
    const total = 3;
    return {
      'total': total,
      'data': [
        for (var i = 0; i < total && i < limit; i++)
          {'intCIP': '${8000000 + i}', 'strNAME': 'PRODUIT PERIME FICTIF $i', 'intQUANTITY': 2 + i, 'ticketNum': 'LOT-$i', 'dtCREATED': '30/09/2026',
            'dateHeure': '02/10/2026 10:15', 'libelleRayon': 'RAYON A', 'intPRICE': 3000},
      ],
    };
  }

  // --- Tableau de bord ---
  static Map<String, Object?> tuiles() => {
        'success': true, 'ca': 1245300, 'clients': 87, 'caVeille': 1100000, 'evolutionVeille': 13.2, 'marge': 312800, 'tauxMarge': 25.1,
        'panier': 14314, 'achats': {'ht': 900000, 'tva': 0, 'ttc': 950000, 'bl': 4, 'mode': 'saisie'},
        'ruptures': {'produits': 12, 'vendusRecemment': 5, 'jours': 7, 'fenetre': 90},
      };

  static Map<String, Object?> encaissements() => {
        'success': true,
        'modes': [
          {'id': '1', 'libelle': 'Espèces', 'montant': 820000},
          {'id': 'MM', 'libelle': 'Mobile money', 'montant': 240000, 'operateurs': <Object>[]},
          {'id': 'TP', 'libelle': 'Tiers payants (crédit)', 'montant': 185300},
        ],
        'typeVente': {'comptant': 1060000, 'credit': 185300, 'depot': 0},
      };

  static Map<String, Object?> emplacements(String axe) => {
        'success': true,
        'data': [
          for (var i = 0; i < 10; i++) {'libelle': axe == 'famille' ? 'FAMILLE FICTIVE $i' : 'RAYON FICTIF $i', 'valeur': 900000 - i * 70000},
        ],
      };

  static List<int> _heures(int base) => [for (var h = 0; h < 24; h++) h >= 8 && h <= 20 ? base + (h % 5) * 3 : 0];

  static Map<String, Object?> frequentationPilotage(String jour) => {
        'success': true,
        'courante': {'libelle': 'Période regardée', 'debut': jour, 'fin': jour, 'jours': 1, 'ventesH': _heures(4), 'caH': _heures(40000)},
        'reference': {'libelle': 'Période précédente', 'debut': jour, 'fin': jour, 'jours': 1, 'ventesH': _heures(3), 'caH': _heures(30000)},
        'periode': jour,
      };

  static Map<String, Object?> frequentationSemaine() => {
        'success': true,
        'semaine': {'ventesH': _heures(20), 'caH': _heures(200000), 'jours': 3, 'debut': '2026-10-12', 'fin': '2026-10-14'},
        'precedente': {'ventesH': _heures(30), 'caH': _heures(300000), 'jours': 6, 'debut': '2026-10-05', 'fin': '2026-10-11'},
      };

  /// Ancien tableau de bord web (branche dev) : nombres déjà mis en forme par le serveur.
  static Map<String, Object?> daily() => {
        'DailyCA': '1 245 300', 'DailyCount': 87, 'DailyAchatAmount': '950 000', 'DailyAchatCount': '4', 'PanierMY': '14 314', 'MARGENET': '312 800',
        'MONTANTVO': 185300.0, 'MONTANTVNO': 1060000.0, 'MONTANTDEPO': 0.0,
      };
}

/// Routes par défaut de la 3.11.0 (appelé par FauxServeurPrestige.installerRoutesParDefaut). Création d'inventaire
/// des sur-stocks : JAMAIS appelée (répond, pour que les tests puissent vérifier qu'aucune requête n'y part).
void installerRoutesVague4(FauxServeurPrestige s) {
  s.quand('/balance/balancesalecash', ReponseFausse.json(DonneesVague4.balance()), methode: 'GET');
  s.route('/balance/balancesalecash/analyse', (r) => ReponseFausse.json(DonneesVague4.analyse(r.parametres['typePeriode'] ?? '')), methode: 'GET');
  s.quand('/balance/balancesalecash/pdf', ReponseFausse.octets('%PDF-1.4 fictif'.codeUnits, type: 'application/pdf'), methode: 'GET');
  s.route('/surstock', (r) => ReponseFausse.json(DonneesVague4.surstocks(r.parametres)), methode: 'GET');
  s.quand('/surstock/excel', ReponseFausse.octets([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1], type: 'application/vnd.ms-excel'), methode: 'GET');
  s.quand('/surstock/create-inventaire', ReponseFausse.json({'success': true}));
  s.route('/fichearticle/saisieperimes', (r) => ReponseFausse.json(DonneesVague4.saisiesPerimes(r.parametres)), methode: 'GET');
  s.quand('/tableau-bord/tuiles', ReponseFausse.json(DonneesVague4.tuiles()), methode: 'GET');
  s.quand('/tableau-bord/encaissements', ReponseFausse.json(DonneesVague4.encaissements()), methode: 'GET');
  s.route('/tableau-bord/emplacements', (r) => ReponseFausse.json(DonneesVague4.emplacements(r.parametres['axe'] ?? '')), methode: 'GET');
  s.quand('/tableau-bord/frequentation', ReponseFausse.json(DonneesVague4.frequentationSemaine()), methode: 'GET');
  s.route('/pilotage/suivi/frequentation', (r) => ReponseFausse.json(DonneesVague4.frequentationPilotage(r.parametres['dtStart'] ?? '')), methode: 'GET');
  s.quand('/recap/dashboard/daily', ReponseFausse.json(DonneesVague4.daily()), methode: 'GET');
}
