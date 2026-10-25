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

  /// La veille (3.11.1) : décalée de deux heures, pour avoir des hausses, des baisses et des égalités.
  static List<int> _heuresVeille(int base) => [for (var h = 0; h < 24; h++) h >= 8 && h <= 20 ? base + ((h + 2) % 5) * 3 : 0];

  static Map<String, Object?> frequentationPilotage(String jour) => {
        'success': true,
        'courante': {'libelle': 'Période regardée', 'debut': jour, 'fin': jour, 'jours': 1, 'ventesH': _heures(4), 'caH': [for (final v in _heures(4)) v * 9500]},
        'reference': {'libelle': 'Période précédente', 'debut': jour, 'fin': jour, 'jours': 1, 'ventesH': _heuresVeille(4), 'caH': [for (final v in _heuresVeille(4)) v * 9500]},
        'periode': jour,
      };

  static Map<String, Object?> frequentationSemaine() => {
        'success': true,
        'semaine': {'ventesH': _heures(20), 'caH': _heures(200000), 'jours': 3, 'debut': '2026-10-12', 'fin': '2026-10-14'},
        'precedente': {'ventesH': _heures(30), 'caH': _heures(300000), 'jours': 6, 'debut': '2026-10-05', 'fin': '2026-10-11'},
      };

  /// Affluence (3.15.0, TableauBordServiceImpl.affluence) : semaine du lundi au dimanche contenant [date]
  /// (aaaa-mm-jj, aujourd'hui si vide ou illisible, comme le serveur) ; cases avec au moins une vente seulement
  /// (GROUP BY jour, heure) ; jour 1 = lundi. Lundi → samedi de 8 h à 20 h, dimanche matin (garde) ; pointe le samedi à 10 h.
  static Map<String, Object?> affluence(String date) {
    final d = DateTime.tryParse(date) ?? DateTime.now();
    final lundi = DateTime(d.year, d.month, d.day - (d.weekday - 1));
    String iso(DateTime x) => '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
    return {
      'debut': iso(lundi),
      'fin': iso(DateTime(lundi.year, lundi.month, lundi.day + 6)),
      'cases': [
        for (var j = 1; j <= 7; j++)
          for (var h = 8; h <= (j == 7 ? 12 : 20); h++)
            {'jour': j, 'heure': h, 'ventes': ventesAffluence(j, h), 'ca': ventesAffluence(j, h) * 9500},
      ],
      'success': true,
    };
  }

  static int ventesAffluence(int jour, int heure) => jour == 6 && heure == 10 ? 42 : (jour == 7 ? 2 : 3 + (heure % 5) * 4 + jour);

  // --- Péremptions courtes (3.15.0, ReceptionMobileService.peremptionsCourtes / statutPeremptionCourte) ---

  /// Statuts changés par PUT …/{id}/statut (remis à zéro par installerRoutesVague4).
  static final statutsPc = <String, String>{};

  /// Le compte n'a pas P_BL_MOBILE_ACCEPTER_PEREMPTION_COURTE : PUT refusé (403, Droits.interdit).
  static bool statutPcInterdit = false;

  /// « peutChangerStatut » de la liste (demande 55, a30b33d9) : true / false ; null → champ absent (serveur plus ancien).
  static bool? peutChangerStatutPc = true;

  static const idsPc = ['PC-1', 'PC-2', 'PC-3', 'PC-4'];

  static List<Map<String, Object?>> lignesPc() => [
        {'id': 'PC-1', 'bl': 'BL-FICTIF-1', 'cip': '8000101', 'produit': 'PRODUIT COURT FICTIF A', 'grossiste': 'ALPHA FICTIF', 'numLot': 'L-A1',
          'datePeremption': '2027-01-15', 'joursRestants': 92, 'quantite': 10, 'valeur': 25000, 'decision': 'ACCEPTE', 'motif': 'Produit très demandé',
          'statut': 'A_TRAITER', 'utilisateur': 'Agent Fictif', 'le': '2026-10-15T09:30:00', 'g': 'GRO-TEST-1'},
        {'id': 'PC-2', 'bl': 'BL-FICTIF-2', 'cip': '8000102', 'produit': 'PRODUIT COURT FICTIF B', 'grossiste': 'BETA FICTIF', 'numLot': 'L-B1',
          'datePeremption': '2026-12-01', 'joursRestants': 45, 'quantite': 4, 'valeur': 12000, 'decision': 'REFUSE', 'motif': null,
          'statut': 'RECLAME', 'utilisateur': 'Agent Fictif', 'le': '2026-10-12T15:05:00', 'g': 'GRO-TEST-2'},
        {'id': 'PC-3', 'bl': 'BL-FICTIF-3', 'cip': '8000103', 'produit': 'PRODUIT COURT FICTIF C', 'grossiste': 'ALPHA FICTIF', 'numLot': 'L-C1',
          'datePeremption': '2027-02-28', 'joursRestants': 140, 'quantite': 6, 'valeur': 18600, 'decision': 'ACCEPTE', 'motif': 'Accord du grossiste',
          'statut': 'AVOIR_RECU', 'utilisateur': 'Agent Fictif', 'le': '2026-10-08T11:00:00', 'g': 'GRO-TEST-1'},
        {'id': 'PC-4', 'bl': 'BL-FICTIF-4', 'cip': '8000104', 'produit': 'PRODUIT COURT FICTIF D', 'grossiste': 'BETA FICTIF', 'numLot': 'L-D1',
          'datePeremption': '2026-11-20', 'joursRestants': 35, 'quantite': 2, 'valeur': 7400, 'decision': 'ACCEPTE', 'motif': 'Dernier lot',
          'statut': 'A_TRAITER', 'utilisateur': 'Agent Fictif', 'le': '2026-10-02T08:45:00', 'g': 'GRO-TEST-2'},
      ];

  /// GET /reception/peremptions-courtes : filtres grossiste (identifiant) et statut comme le serveur ; total, valeur.
  static Map<String, Object?> peremptionsCourtes(Map<String, String> p) {
    final g = (p['grossiste'] ?? '').trim(), st = (p['statut'] ?? '').trim();
    final data = <Map<String, Object?>>[];
    for (final l in lignesPc()) {
      final x = {...l, 'statut': statutsPc[l['id']] ?? l['statut']};
      if (g.isNotEmpty && x['g'] != g) continue;
      if (st.isNotEmpty && x['statut'] != st) continue;
      data.add(x..remove('g'));
    }
    return {
      'success': true,
      'total': data.length,
      'valeur': data.fold<int>(0, (s, x) => s + (x['valeur']! as int)),
      if (peutChangerStatutPc != null) 'peutChangerStatut': peutChangerStatutPc,
      'data': data,
    };
  }

  static ReponseFausse statutPc(RequeteRecue r, String id) {
    if (statutPcInterdit) {
      return ReponseFausse.json({'success': false, 'interdit': true, 'msg': 'Droit manquant : Accepter une péremption courte'}, statut: 403);
    }
    final s = (r.parametres['statut'] ?? '').toUpperCase();
    if (!const ['A_TRAITER', 'RECLAME', 'AVOIR_RECU'].contains(s)) {
      return ReponseFausse.json({'success': false, 'code': 'STATUT_INVALIDE', 'msg': 'statut : A_TRAITER, RECLAME ou AVOIR_RECU.'}, statut: 400);
    }
    statutsPc[id] = s;
    return ReponseFausse.json({'success': true});
  }

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
  s.route('/tableau-bord/affluence', (r) => ReponseFausse.json(DonneesVague4.affluence(r.parametres['date'] ?? '')), methode: 'GET');
  s.route('/pilotage/suivi/frequentation', (r) => ReponseFausse.json(DonneesVague4.frequentationPilotage(r.parametres['dtStart'] ?? '')), methode: 'GET');
  s.quand('/recap/dashboard/daily', ReponseFausse.json(DonneesVague4.daily()), methode: 'GET');
  DonneesVague4.statutsPc.clear();
  DonneesVague4.statutPcInterdit = false;
  DonneesVague4.peutChangerStatutPc = true;
  s.route('/reception/peremptions-courtes', (r) => ReponseFausse.json(DonneesVague4.peremptionsCourtes(r.parametres)), methode: 'GET');
  s.quand('/reception/peremptions-courtes/excel', ReponseFausse.octets([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00],
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', entetes: {'content-disposition': 'attachment; filename=peremptions_courtes.xlsx'}),
      methode: 'GET');
  s.quand('/reception/peremptions-courtes/pdf', ReponseFausse.octets('%PDF-1.4 fictif'.codeUnits, type: 'application/pdf'), methode: 'GET');
  for (final id in DonneesVague4.idsPc) {
    s.route('/reception/peremptions-courtes/$id/statut', (r) => DonneesVague4.statutPc(r, id), methode: 'PUT');
  }
}
