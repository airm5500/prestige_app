// Jeux de données FICTIFS pour le faux serveur Prestige (test/support/faux_serveur_prestige.dart).
// Règle : jamais de vraies données de patients, de clients ou d'employés, jamais de vrais identifiants ni de
// vraies clés de licence. Noms, codes CIP, montants et identifiants ci-dessous sont inventés.
import 'package:intl/intl.dart';

class DonneesFictives {
  DonneesFictives._();

  // --- Connexion ---
  static const identifiant = 'pharmacien.test';
  static const motDePasse = 'MotDePasse-Fictif-1';
  static const prenom = 'Docteur';
  static const nom = 'Fictif';
  static const nomComplet = '$prenom $nom';

  /// Réponse de POST /user/auth (champs lus par AppUser.fromJson).
  static Map<String, Object?> utilisateur() => {
        'success': true,
        'str_USER_ID': 'USR-TEST-0001',
        'str_FIRST_NAME': prenom,
        'str_LAST_NAME': nom,
        'str_LOGIN': identifiant,
        'OFFICINE': 'Pharmacie Fictive des Tests',
        'str_PIC': null,
        // Profil donné par Prestige à l'administrateur et au pharmacien (nouveaux menus visibles).
        'xtypeuser': 'dashboard',
      };

  static const messageIdentifiantsIncorrects = 'Identifiant ou mot de passe incorrect.';

  // --- Officine ---
  static const nomOfficine = 'Pharmacie Fictive des Tests';
  static List<Map<String, Object?>> officine() => [
        {'id': 'OFF-TEST-1', 'fullName': 'PHARMACIE FICTIVE', 'nomComplet': nomOfficine},
      ];

  // --- Licence ---
  static String _jour(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  /// Licence valide encore [jours] jours (par défaut : très lointaine, aucun bandeau d'alerte).
  static Map<String, Object?> licenceValide({int? jours}) => {
        'id': 'LIC-TEST-0001',
        'typeLicence': 'ANNUELLE',
        'dateStart': '2026-01-01',
        'dateEnd': jours == null ? '2099-12-31' : _jour(DateTime.now().add(Duration(days: jours))),
      };

  static Map<String, Object?> licenceExpiree() =>
      {'id': 'LIC-TEST-0002', 'typeLicence': 'ANNUELLE', 'dateStart': '2025-01-01', 'dateEnd': '2026-01-01'};

  // --- Articles (Analyse Article : GET /info ; Fiche Article : GET /checkproduit) ---
  static const libelleArticle1 = 'PARAFICTIF 500MG CPR B/16';
  static const libelleArticle2 = 'SIROP IMAGINAIRE 125ML';

  static List<Map<String, Object?>> articlesAnalyse() => [
        {
          'produitId': 'PRD-TEST-1', 'codeCip': '9990001', 'libelle': libelleArticle1, 'prixVente': 1200, 'prixAchat': 800,
          'moyenne': 4.5, 'moyenneJour': 0.15, 'quantiteVendue': 42, 'stock': 3, 'quantiteMois': '5:1',
          'grossiste': 'GROSSISTE FICTIF', 'emplacement': 'RAYON A',
          'stockReserve': 20, 'seuilReserve': 10, 'seuilMiniRayon': 5,
        },
        {
          'produitId': 'PRD-TEST-2', 'codeCip': '9990002', 'libelle': libelleArticle2, 'prixVente': 2500, 'prixAchat': 1700,
          'moyenne': 1.0, 'quantiteVendue': 3, 'stock': 12, 'quantiteMois': '',
          'stockReserve': null, 'seuilReserve': null, 'seuilMiniRayon': null,
        },
      ];

  /// Réponse de GET /espace-produit/recherche?q= (comme EspaceProduitRessource : « contient » dans le CIP ou le
  /// nom, sans tenir compte de la casse, rien sous 2 caractères, 50 lignes au plus, triées par nom).
  static Map<String, Object?> rechercheProduit(String? q, {List<Map<String, Object?>>? articles}) {
    final t = (q ?? '').trim().toLowerCase();
    if (t.length < 2) return {'total': 0, 'data': const <Object>[]};
    final lignes = [
      for (final a in articles ?? articlesAnalyse())
        if ('${a['libelle']}'.toLowerCase().contains(t) || '${a['codeCip']}'.contains(t))
          {
            'cip': a['codeCip'], 'designation': a['libelle'], 'emplacement': a['emplacement'] ?? '', 'prixVente': a['prixVente'],
            'stockRayon': a['stock'], 'stockReserve': a['stockReserve'] ?? 0,
            'stockTotal': ((a['stock'] as num?) ?? 0) + ((a['stockReserve'] as num?) ?? 0), 'id': a['produitId'],
          },
    ]..sort((x, y) => '${x['designation']}'.compareTo('${y['designation']}'));
    final data = lignes.take(50).toList();
    return {'total': data.length, 'data': data};
  }

  static List<Map<String, Object?>> produitsFiche() => [
        {
          'familleId': 'PRD-TEST-1', 'familleCip': '9990001', 'familleLibelle': libelleArticle1, 'pachat': 800, 'pvente': 1200,
          'stock': 8, 'emplacement': 'RAYON A', 'stockReserve': '4', 'seuilReserve': '5', 'seuilMiniRayon': 2,
        },
        {'familleId': 'PRD-TEST-2', 'familleCip': '9990002', 'familleLibelle': libelleArticle2, 'pachat': 1700, 'pvente': 2500, 'stock': 12},
      ];

  // --- Présences (routes /rh/…) : un seul employé fictif ---
  static const employe = 'EMPLOYE Fictif Un';
  static const employeId = 'EMP-TEST-0001';

  static Map<String, Object?> presenceDuJour(String jour) => {
        'success': true,
        'pointages': [
          {'horodatage': '$jour 08:05', 'sens': 'ENTREE', 'id': 'PT-TEST-1', 'employeId': employeId, 'source': 'MOBILE', 'motif': ''},
        ],
        'data': [
          {
            'employeId': employeId, 'employe': employe, 'matricule': 'TEST-0001', 'jour': jour, 'prevu': '08:00-16:00',
            'prevuTexte': '8 h 00', 'minutesPrevues': 480, 'minutesPresence': 0, 'presenceTexte': '', 'pointages': '08:05↑',
            'entree': '08:05', 'sortie': '', 'retard': 5, 'departAnticipe': 0, 'heuresSup': 0, 'absence': '',
            'anomalies': 'ENTREE_SANS_SORTIE',
          },
        ],
      };

  static Map<String, Object?> tableauPresences(String du, String au) => {
        'success': true,
        'du': du,
        'au': au,
        'data': [
          {
            'employeId': employeId, 'employe': employe, 'matricule': 'TEST-0001', 'joursPrevus': 2, 'joursPresents': 2,
            'minutesPrevues': 960, 'minutesPresence': 900, 'presenceTexte': '15 h 00', 'prevuTexte': '16 h 00',
            'minutesRetard': 5, 'retards': 1, 'retardTexte': '5 min', 'departsAnticipes': 0, 'heuresSup': 0,
            'heuresSupTexte': '', 'absencesNonJustifiees': 0, 'joursAbsenceJustifiee': 0, 'anomalies': 1,
          },
        ],
      };

  static Map<String, Object?> codePointage(int n) {
    final code = ['TEST01', 'TEST02', 'TEST03'][n % 3];
    return {
      'success': true, 'qr': true, 'actif': true, 'gps': false, 'periodeSec': 60, 'resteSec': 60, 'code': code,
      'contenu': 'PRESTIGE-POINTAGE:$code', 'rayon': 150, 'latitude': '', 'longitude': '',
    };
  }

  static Map<String, Object?> terminaux() => {
        'success': true,
        'data': [
          {
            'id': 'TERM-TEST-1', 'appareil': 'Téléphone de test', 'utilisateur': employe, 'login': 'EMPLOYE.TEST',
            'adresse': '', 'creeLe': '01/10/2026 08:00', 'derniereActivite': '13/10/2026 08:05', 'statut': 'ACTIF',
          },
        ],
      };

  /// Réponse « liste vide » de Prestige (vraie absence de données, ≠ panne).
  static Map<String, Object?> listeVide() => {'data': <Object>[], 'total': 0};

  // --- Accueil « A · Tableau de bord » : GET /recap/dashboard (format du Rapport d'Activité) ---
  static const caDuJour = 1245300;
  static Map<String, Object?> recapDuJour() => {
        'success': true,
        'data': {
          'montantTTC': caDuJour, 'montantHT': 1055339, 'marge': 312800, 'montantCredit': 186000, 'montantRegle': 1059300,
          'montantTotalTVA': 189961, 'ratio': 1.52, 'achats': <Object>[], 'reglements': <Object>[], 'mvtsCaisse': <Object>[],
        },
      };

  /// Présence du jour d'une équipe fictive de 4 personnes (un retard, un absent) pour les captures et l'accueil.
  static Map<String, Object?> presenceEquipe(String jour) {
    Map<String, Object?> l(String id, String nom, String prevu, String entree, int retard, String absence, String anomalies) => {
          'employeId': id, 'employe': nom, 'matricule': id, 'jour': jour, 'prevu': prevu, 'minutesPrevues': 480,
          'minutesPresence': 0, 'pointages': entree.isEmpty ? '' : '$entree↑', 'entree': entree, 'sortie': '', 'retard': retard,
          'departAnticipe': 0, 'heuresSup': 0, 'absence': absence, 'anomalies': anomalies,
        };
    return {
      'success': true,
      'pointages': <Object>[],
      'data': [
        l('EMP-TEST-0001', employe, '08:00-16:00', '08:05', 5, '', 'ENTREE_SANS_SORTIE'),
        l('EMP-TEST-0002', 'EMPLOYEE Fictive Deux', '07:30-15:30', '08:52', 82, '', 'ENTREE_SANS_SORTIE'),
        l('EMP-TEST-0003', 'EMPLOYE Fictif Trois', '07:30-15:30', '07:24', 0, '', 'ENTREE_SANS_SORTIE'),
        l('EMP-TEST-0004', 'EMPLOYEE Fictive Quatre', '08:00-16:00', '', 0, '', 'ABSENT'),
      ],
    };
  }

  // --- Alertes de l'accueil A (comptées à la demande) ---

  /// Suivi Péremption : GET /fichearticle/perimes (format de SuiviPeremptionResponse) : 3 lots.
  static const lotsPerimes = 3;
  static Map<String, Object?> perimes() {
    Map<String, Object?> lot(String cip, String libelle, String numLot, String date, String statut, int qte) => {
          'libelle': libelle, 'codeCip': cip, 'numLot': numLot, 'datePerement': date, 'statut': statut, 'quantiteLot': qte,
          'valeurAchat': qte * 800, 'valeurVente': qte * 1200, 'libelleRayon': 'RAYON A', 'libelleGrossiste': 'GROSSISTE FICTIF',
          'libelleFamille': 'FAMILLE FICTIVE',
        };
    return {
      'total': lotsPerimes,
      'metaData': {'totalQuantiteLot': 9, 'totalValeurAchat': 7200, 'totalValeurVente': 10800, 'periode': 0},
      'data': [
        lot('9990001', libelleArticle1, 'LOT-TEST-1', '30/09/2026', 'Périmé', 2),
        lot('9990002', libelleArticle2, 'LOT-TEST-2', '15/11/2026', 'Périme dans 1 mois', 4),
        lot('9990003', 'POMMADE FICTIVE 30G', 'LOT-TEST-3', '20/12/2026', 'Périme dans 2 mois', 3),
      ],
    };
  }

  /// Etat Contrôle Achat : GET /etat-control-bon/list-annuelle (par groupe) : 4 + 3 = 7 bons.
  static const bonsControles = 7;
  static Map<String, Object?> etatControleAchat() => {
        'data': [
          {'groupByLibelle': 'GROUPE FICTIF A', 'nbreBon': 4, 'montantHtaxe': 400000, 'montantTtc': 472000, 'montantTaxe': 72000,
            'montantVenteTtc': 600000, 'montantMarge': 128000, 'pourcentage': 60},
          {'groupByLibelle': 'GROUPE FICTIF B', 'nbreBon': 3, 'montantHtaxe': 250000, 'montantTtc': 295000, 'montantTaxe': 45000,
            'montantVenteTtc': 380000, 'montantMarge': 85000, 'pourcentage': 40},
        ],
        'metaData': {'totalNbreBon': bonsControles, 'totalMarge': 213000, 'totalTtc': 767000, 'totalTaxe': 117000,
          'totalVenteTtc': 980000, 'totaltHtaxe': 650000},
      };

  // --- Lot 1 (modules refaits) : Rapport d'Activité, Détail CA, Suivi Crédit ---

  /// GET /recap/dashboard : récapitulatif complet (règlements, achats, mouvements de caisse).
  static Map<String, Object?> rapportActivite() => {
        'success': true,
        'data': {
          'montantTTC': 2480650, 'montantHT': 2102246, 'marge': 615300, 'montantCredit': 412500, 'montantRegle': 1868150,
          'montantTotalTVA': 378404, 'ratio': 1.47,
          'achats': [
            {'libelleGroupeGrossiste': 'GROUPE FICTIF A', 'montantHT': 610000, 'montantTTC': 719800, 'montantTVA': 109800},
            {'libelleGroupeGrossiste': 'GROUPE FICTIF B', 'montantHT': 205000, 'montantTTC': 241900, 'montantTVA': 36900},
          ],
          'reglements': [
            {'libelle': 'Espèces', 'montant': 1325400},
            {'libelle': 'Mobile Money', 'montant': 402750},
            {'libelle': 'Carte bancaire', 'montant': 140000},
          ],
          'mvtsCaisse': [
            {'libelle': 'Fond de caisse', 'montant': 50000},
            {'libelle': 'Sortie fictive', 'montant': 12500},
          ],
        },
      };

  /// GET /recap/credits (Rapport d'Activité et Suivi Crédit) : crédits par tiers payant.
  static Map<String, Object?> creditsTiersPayants() => {
        'data': [
          {'libelleTypeTiersPayant': 'ASSURANCE', 'libelleTiersPayant': 'ASSURANCE FICTIVE UNE', 'nbreClient': 12, 'nbreBons': 18, 'montant': 243000},
          {'libelleTypeTiersPayant': 'ASSURANCE', 'libelleTiersPayant': 'MUTUELLE IMAGINAIRE', 'nbreClient': 5, 'nbreBons': 6, 'montant': 98500},
          {'libelleTypeTiersPayant': 'CLIENT EN COMPTE', 'libelleTiersPayant': 'SOCIETE FICTIVE SARL', 'nbreClient': 3, 'nbreBons': 4, 'montant': 71000},
        ],
      };

  /// GET /recap/credits/totaux.
  static Map<String, Object?> creditsTotaux() => {'nbreClient': 20, 'nbreBons': 28, 'montant': 412500};

  /// GET /recap/reglements : règlements reçus.
  static Map<String, Object?> reglementsRecus() => {
        'data': [
          {'type': 'TP', 'description': 'Règlement ASSURANCE FICTIVE UNE', 'reference': 'REG-TEST-1', 'montant': 150000},
          {'type': 'CLIENT', 'description': 'Règlement SOCIETE FICTIVE SARL', 'reference': 'REG-TEST-2', 'montant': 35000},
        ],
      };

  /// GET /ca-all : une ligne par jour (dates AAAAMMJJ, volontairement dans le désordre).
  static List<Map<String, Object?>> caParJour() => [
        {'mvtDate': '20261013', 'totEsp': 512300, 'montantCredit': 140500, 'totMobile': 98200, 'totCB': 45000, 'totChq': 0, 'totVirement': 12000,
          'remiseSurCA': 8400, 'totTVA': 128700},
        {'mvtDate': '20261012', 'totEsp': 433100, 'montantCredit': 121000, 'totMobile': 75400, 'totCB': 30000, 'totChq': 25000, 'totVirement': 0,
          'remiseSurCA': 6100, 'totTVA': 104950},
        {'mvtDate': '20261014', 'totEsp': 380000, 'montantCredit': 151000, 'totMobile': 64150, 'totCB': 65000, 'totChq': 0, 'totVirement': 0,
          'remiseSurCA': 4300, 'totTVA': 98300},
      ];

  /// GET /stats-recette-caisse/modes (période) : ventilation par mode ; seules les lignes mobile:true servent au
  /// détail Mobile Money. Σ opérateurs mobiles = 235 000 ≠ totMobile de /ca-all (237 750) : écart de 2 750.
  /// « part » / « partCa » volontairement faux (l'application doit les ignorer).
  static const mobileOrange = 118500, mobileWave = 71250, mobileMtn = 30000, mobileMoov = 15250;
  static const totMobileCa = 237750, totalBrutCa = 2152650, ecartMobile = totMobileCa - (mobileOrange + mobileWave + mobileMtn + mobileMoov);
  static Map<String, Object?> modesPaiement() => {
        'success': true,
        'data': [
          {'modeId': '1', 'mode': 'Espèces', 'montant': 1325400, 'operations': 210, 'mobile': false, 'part': 70.1, 'partCa': 61.5},
          {'modeId': '9', 'mode': 'MTN', 'montant': mobileMtn, 'operations': 6, 'mobile': true, 'part': 99, 'partCa': 99},
          {'modeId': '7', 'mode': 'Orange', 'montant': mobileOrange, 'operations': 31, 'mobile': true, 'part': 99, 'partCa': 99},
          {'modeId': '3', 'mode': 'Carte bancaire', 'montant': 140000, 'operations': 9, 'mobile': false, 'part': 7.4, 'partCa': 6.5},
          {'modeId': '10', 'mode': 'Wave', 'montant': mobileWave, 'operations': 18, 'mobile': true, 'part': 99, 'partCa': 99},
          {'modeId': '8', 'mode': 'Moov', 'montant': mobileMoov, 'operations': 4, 'mobile': true, 'part': 99, 'partCa': 99},
        ],
        'totalMobile': 235000,
        'partMobileCa': 99,
        'chiffreAffaires': 1,
      };

  /// GET /ca-all avec le champ futur « detailMobile » par jour (compatibilité : réponse SIMULÉE, le serveur ne le
  /// fournit pas encore). Σ par jour = totMobile du jour ; cumul : Orange 120 000, Wave 80 750, MTN 37 000.
  static List<Map<String, Object?>> caParJourAvecDetail() {
    final detail = {
      '20261013': [
        {'modeId': '7', 'libelle': 'Orange', 'montant': 50000},
        {'modeId': '10', 'libelle': 'Wave', 'montant': 30200},
        {'modeId': '9', 'libelle': 'MTN', 'montant': 18000},
      ],
      '20261012': [
        {'modeId': '7', 'libelle': 'Orange', 'montant': 40000},
        {'modeId': '10', 'libelle': 'Wave', 'montant': '35 400'},
      ],
      '20261014': [
        {'modeId': '7', 'libelle': 'Orange', 'montant': 30000},
        {'modeId': '10', 'libelle': 'Wave', 'montant': 15150},
        {'modeId': '9', 'libelle': 'MTN', 'montant': 19000},
      ],
    };
    return [for (final j in caParJour()) {...j, 'detailMobile': detail[j['mvtDate']]}];
  }
}
