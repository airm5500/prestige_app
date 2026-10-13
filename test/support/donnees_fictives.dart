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
}
