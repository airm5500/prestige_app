// Données FICTIVES et routes par défaut du faux serveur pour la vague 3 des nouveaux menus (Pointage BL, Avis,
// Rappels traitement). Formats réels du serveur Prestige (branche claude/new-session-xm8ptu : PointageBLRessource /
// PointageBLService, AvisClientRessource / AvisClientService / Analyse, RappelHabitudeRessource / RappelHabitudeDTO
// / AnalyseRappels), données inventées. Le faux serveur GARDE l'état des écritures (pointage, séquence, avoir,
// statut d'un avis ouvert ou traité, rappels marqués) pour que les relectures le montrent, comme Prestige.
// Contrôle des requêtes : [requetesInterditesVague3] (routes d'envoi, de réglages et d'actualisation, JAMAIS reçues).
import 'faux_serveur_prestige.dart';

/// Routes d'envoi externe, de secret ou de recalcul lourd : le mobile ne doit JAMAIS les appeler.
const routesInterditesVague3Testees = <String>[
  '/rappels-habitude/envoyer',
  '/rappels-habitude/sms',
  '/rappels-habitude/actualiser',
  '/avis-clients/reglages',
  '/avis-clients/reglages/regenerer',
  '/avis-clients/affiche',
  '/avis-clients/avis/AVIS-TEST-1/repondre',
  '/avis-clients/avis/AVIS-TEST-2/repondre',
  '/pointage-bl/releve',
  '/pointage-bl/modele',
];

/// Requêtes fautives reçues : route interdite (envoi, réglages, actualisation, relevé), toute réponse au client.
List<String> requetesInterditesVague3(FauxServeurPrestige s) => [
      for (final r in s.requetes)
        if (routesInterditesVague3Testees.contains(r.chemin) ||
            RegExp(r'^/avis-clients/avis/[^/]+/repondre$').hasMatch(r.chemin) ||
            r.chemin.startsWith('/avis-clients/reglages') ||
            r.chemin.startsWith('/pointage-bl/releve') ||
            r.chemin.startsWith('/rappels-habitude/envoyer') ||
            r.chemin.startsWith('/rappels-habitude/actualiser'))
          '$r',
    ];

/// Requêtes de détail d'avis (GET /avis-clients/avis/{id}) : elles passent l'avis NOUVEAU → LU.
List<RequeteRecue> detailsAvisDemandes(FauxServeurPrestige s) =>
    [for (final r in s.requetes) if (r.methode == 'GET' && RegExp(r'^/avis-clients/avis/[^/]+$').hasMatch(r.chemin)) r];

class DonneesVague3 {
  DonneesVague3._();

  // --- Pointage BL ---
  static const grossiste = 'GRO-TEST-1';
  static const groupe = 'GRP-TEST-1';

  static Map<String, Object?> groupes() => {
        'success': true,
        'total': 2,
        'data': [
          {'id': groupe, 'libelle': 'GROUPE FICTIF'},
          {'id': 'GRP-TEST-2', 'libelle': 'GROUPE IMAGINAIRE'},
        ],
      };

  /// Pièces de départ : BL-1 non pointé avec un écart de contrôle, BL-2 pointé, BL-3 non pointé, un retour (avoir)
  /// non pointé, des manquants à la réception (non pointables).
  static List<Map<String, Object?>> piecesInitiales() => [
        piece('BL', 'BL-TEST-1', 'BLF-1001', 250000, sequence: 'S-12', controle: '10/12 · 2 écarts · par CAISSIERE Fictive le 03/10/2026', ecarts: 2),
        piece('BL', 'BL-TEST-2', 'BLF-1002', 180000, pointeLe: '05/10/2026 10:12', pointePar: 'Pharmacien Fictif'),
        piece('BL', 'BL-TEST-3', 'BLF-1003', 95500),
        piece('RETOUR', 'RET-TEST-1', 'BLF-1001', 32000, referenceAvoir: 'AV 12/3', statut: 'Retour RF-0007'),
        piece('RECEPTION', 'BL-TEST-1', 'BLF-1001', 4500, statut: 'Manquants à la réception'),
      ];

  static Map<String, Object?> piece(String type, String id, String reference, num montant,
          {String sequence = '', String referenceAvoir = '', String pointeLe = '', String pointePar = '', String controle = '', int ecarts = 0, String? statut}) =>
      {
        'type': type,
        'id': id,
        'cle': '$type:$id',
        'reference': reference,
        'referenceAvoir': referenceAvoir,
        'sequence': sequence,
        'statut': statut ?? 'Entré en stock',
        'date': '0${id.codeUnits.last % 9 + 1}/10/2026',
        'montantHt': type == 'BL' ? montant : -montant,
        'pointable': type != 'RECEPTION',
        'pointe': pointeLe.isNotEmpty,
        'pointeLe': pointeLe,
        'pointePar': pointePar,
        'controle': controle,
        'controleEcarts': ecarts,
      };

  // --- Avis ---
  static const nombreAvis = 60;

  static Map<String, Object?> droits({bool repondre = true}) => {
        'success': true,
        'repondre': repondre,
        'reglages': false,
        'nouveaux': 3,
        'publie': true,
        'criteres': {
          'ACCUEIL': 'Accueil',
          'ATTENTE': 'Temps d\'attente',
          'CONSEIL': 'Conseils',
          'DISPONIBILITE': 'Produits disponibles',
          'PRIX': 'Prix',
          'PROPRETE': 'Propreté'
        },
        'themes': ['Attente', 'Accueil', 'Conseil', 'Prix'],
      };

  /// Avis i (1 = le plus récent) : notes 1 à 5 en boucle, les 3 premiers NOUVEAU, le 4e TRAITÉ, les autres LU.
  static Map<String, Object?> avis(int i) {
    final note = (i % 5) + 1;
    final anonyme = i % 4 == 0;
    return {
      'id': 'AVIS-TEST-$i',
      'date': '${(30 - (i % 28)).toString().padLeft(2, '0')}/09/2026 1${i % 10}:05',
      'dateIso': '2026-09-${(30 - (i % 28)).toString().padLeft(2, '0')}T1${i % 10}:05',
      'note': note,
      'criteres': note >= 4 ? {'ACCUEIL': 'PLUS', 'CONSEIL': 'PLUS'} : {'ATTENTE': 'MOINS'},
      'texte': i == 5 ? '' : (note >= 4 ? 'Accueil fictif très agréable, conseils clairs ($i).' : 'Attente fictive trop longue au comptoir ($i).'),
      'employe': i % 3 == 0 ? 'Vendeur Fictif' : '',
      'anonyme': anonyme,
      'nom': anonyme ? '' : 'CLIENT FICTIF $i',
      'telephone': anonyme ? '' : '00 00 00 ${i.toString().padLeft(2, '0')}',
      'email': anonyme ? '' : 'client$i@exemple.invalid',
      'rappel': i % 2 == 1,
      'statut': i <= 3 ? 'NOUVEAU' : (i == 4 ? 'TRAITE' : 'LU'),
      'dateLu': i <= 3 ? '' : '01/10/2026 09:00',
      'noteInterne': i == 4 ? 'Client rappelé (fictif).' : '',
      'reponse': '',
      'canalReponse': '',
      'statutReponse': '',
      'dateReponse': '',
      'auteurReponse': '',
      'reponseAttendue': i % 2 == 1,
    };
  }

  static Map<String, Object?> analyseAvis() => {
        'success': true,
        'du': '2026-09-15',
        'au': '2026-10-14',
        'synthese': {
          'nombre': 60,
          'moyenne': 3.0,
          'satisfaits': 40.0,
          'mecontents': 40.0,
          'nouveaux': 3,
          'negatifsNonTraites': 23,
          'reponsesAttendues': 30,
          'avecEmploye': 20,
          'avecTexte': 59,
          'precedent': {'nombre': 41, 'moyenne': 3.4, 'satisfaits': 51.2},
        },
        'repartition': [
          for (var n = 5; n >= 1; n--) {'note': n, 'nombre': 12, 'part': 20.0},
        ],
        'evolution': [
          {'periode': 'sem. 14/09', 'date': '2026-09-14', 'pas': 'SEMAINE', 'nombre': 10, 'moyenne': 3.1, 'negatifs': 4},
          {'periode': 'sem. 21/09', 'date': '2026-09-21', 'pas': 'SEMAINE', 'nombre': 25, 'moyenne': 2.9, 'negatifs': 10},
          {'periode': 'sem. 28/09', 'date': '2026-09-28', 'pas': 'SEMAINE', 'nombre': 25, 'moyenne': 3.0, 'negatifs': 10},
        ],
        'criteres': [
          {'cle': 'ACCUEIL', 'libelle': 'Accueil', 'plus': 24, 'moins': 0, 'solde': 24, 'satisfaction': 100},
          {'cle': 'ATTENTE', 'libelle': 'Temps d\'attente', 'plus': 0, 'moins': 36, 'solde': -36, 'satisfaction': 0},
          {'cle': 'PRIX', 'libelle': 'Prix', 'plus': 0, 'moins': 0, 'solde': 0, 'satisfaction': null},
        ],
        'themes': [
          {'theme': 'Attente', 'nombre': 36, 'moyenne': 2.0, 'negatifs': 24, 'positifs': 0, 'precedent': 10, 'motsCles': 'attente long'},
        ],
        'motsCles': [
          {'mot': 'attente', 'cle': 'attente', 'nombre': 36, 'moyenne': 2.0, 'negatifs': 24, 'positifs': 0, 'ton': 'negatif'},
          {'mot': 'accueil', 'cle': 'accueil', 'nombre': 24, 'moyenne': 4.5, 'negatifs': 0, 'positifs': 24, 'ton': 'positif'},
        ],
        'employes': [
          {
            'employe': 'Vendeur Fictif',
            'cle': 'vendeur fictif',
            'variantes': ['Vendeur Fictif'],
            'nombre': 20,
            'moyenne': 2.8,
            'negatifs': 8,
            'positifs': 8,
            'trenteJours': 20,
            'dernier': '2026-09-30T10:05',
            'criteresNegatifs': {'Temps d\'attente': 8},
            'motsCles': [],
            'avis': ['AVIS-TEST-3'],
            'correspondance': null,
          },
        ],
        'bilan': {
          'forts': ['Accueil (24 appréciations)'],
          'faibles': ['Temps d\'attente (36 remarques)', '« Attente » évoqué dans 24 avis négatifs'],
        },
        'alertes': [
          {'niveau': 'haute', 'texte': '23 avis à 1 ou 2 étoiles non traités', 'filtre': {'note': 'NEGATIF', 'statut': 'NON_TRAITE'}},
          {'niveau': 'moyenne', 'texte': '30 clients attendent une réponse', 'filtre': {'reponse': 'ATTENDUE'}},
          {'niveau': 'moyenne', 'texte': 'Note moyenne en baisse : 3.0 contre 3.4 la période précédente', 'filtre': null},
        ],
      };

  // --- Rappels traitement ---
  static const nombreRappels = 40;

  /// Rappel i : 1 à 25 À préparer, 26 à 32 Préparés, 33 à 36 Écartés, 37 à 40 Rachetés ; un client pour 2 produits.
  static Map<String, Object?> rappel(int i) => {
        'id': 'RAP-TEST-$i',
        'clientId': 'CLI-TEST-${(i + 1) ~/ 2}',
        'client': 'PATIENT FICTIF ${(i + 1) ~/ 2}',
        'telephone': '00 11 22 ${i.toString().padLeft(2, '0')}',
        'consentSms': i.isEven,
        'msgMedicaments': false,
        'familleId': 'PRD-RAP-$i',
        'cip': '77700${i.toString().padLeft(2, '0')}',
        'produit': 'TRAITEMENT FICTIF $i MG',
        'stock': i % 7 == 0 ? 0 : i,
        'dernierAchat': '2026-09-${(i % 28 + 1).toString().padLeft(2, '0')}',
        'prevu': '2026-10-${(i % 28 + 1).toString().padLeft(2, '0')}',
        'frequence': 30,
        'achats': 4,
        'statut': i <= 25 ? 'A_PREPARER' : (i <= 32 ? 'PREPARE' : (i <= 36 ? 'ECARTE' : 'ACHETE')),
        'envoi': i % 10 == 0 ? DateTime(2026, 10, 2, 9, 30).millisecondsSinceEpoch : null,
        'traitePar': i > 25 ? 'Pharmacien Fictif' : '',
      };

  static Map<String, Object?> analyseRappels(String debut, String fin) => {
        'success': true,
        'debut': debut,
        'fin': fin,
        'total': {
          'total': 120,
          'aPreparer': 25,
          'prepares': 40,
          'ecartes': 15,
          'rachetes': 40,
          'envoyes': 50,
          'rachetesApresEnvoi': 30,
          'rachetesSansEnvoi': 10,
          'efficacite': 60.0,
          'canaux': {'SMS': 30, 'WHATSAPP': 15, 'NON_RENSEIGNE': 5},
        },
        'mois': [
          for (var m = 5; m <= 10; m++)
            {
              'mois': '2026-${m.toString().padLeft(2, '0')}',
              'total': 20,
              'aPreparer': m == 10 ? 25 : 0,
              'prepares': 7,
              'ecartes': 2,
              'rachetes': 7,
              'envoyes': 8,
              'rachetesApresEnvoi': 5,
              'rachetesSansEnvoi': 2,
              'efficacite': 62.5,
              'canaux': {'SMS': 8},
            },
        ],
      };
}

/// État des écritures du faux serveur (remis à zéro par [installerRoutesVague3]).
class EtatVague3 {
  final pieces = DonneesVague3.piecesInitiales();
  final avis = [for (var i = 1; i <= DonneesVague3.nombreAvis; i++) DonneesVague3.avis(i)];
  final rappels = [for (var i = 1; i <= DonneesVague3.nombreRappels; i++) DonneesVague3.rappel(i)];
}

/// Dernier état installé (tests : vérifier ce que le serveur a gardé).
late EtatVague3 etatVague3;

Map<String, Object?> _listePointage(EtatVague3 e, Map<String, String> p) {
  if ((p['grossiste'] ?? '').isEmpty && (p['groupe'] ?? '').isEmpty) {
    return {'success': false, 'msg': 'Choisissez un grossiste ou un groupe de grossistes.'};
  }
  final etat = p['etat'] ?? 'TOUS';
  num bl = 0, avoirs = 0;
  var pointes = 0, nonPointes = 0;
  final data = <Map<String, Object?>>[];
  for (final x in e.pieces) {
    final pointe = x['pointe'] == true, reception = x['type'] == 'RECEPTION';
    if (x['type'] == 'BL') {
      bl += x['montantHt'] as num;
    } else {
      avoirs += x['montantHt'] as num;
    }
    if (!reception) pointe ? pointes++ : nonPointes++;
    if (etat == 'POINTES' && !pointe || etat == 'NON_POINTES' && (pointe || reception)) continue;
    data.add(Map.of(x));
  }
  return {'success': true, 'data': data, 'total': data.length, 'totalBl': bl, 'totalAvoirs': avoirs, 'net': bl + avoirs, 'pointes': pointes, 'nonPointes': nonPointes};
}

Map<String, Object?> _listeAvis(EtatVague3 e, Map<String, String> p) {
  final statut = p['statut'] ?? '', note = p['note'] ?? '', contient = (p['contient'] ?? '').toLowerCase();
  final toutes = [
    for (final a in e.avis)
      if ((statut.isEmpty || (statut == 'NON_TRAITE' ? a['statut'] != 'TRAITE' : a['statut'] == statut)) &&
          (note.isEmpty ||
              (note == 'NEGATIF' && (a['note'] as int) <= 2) ||
              (note == 'POSITIF' && (a['note'] as int) >= 4) ||
              note == '${a['note']}') &&
          (p['reponse'] != 'ATTENDUE' || a['reponseAttendue'] == true) &&
          (contient.isEmpty || '${a['texte']} ${a['employe']} ${a['nom']}'.toLowerCase().contains(contient)))
        a,
  ];
  final start = int.tryParse(p['start'] ?? '') ?? 0, limit = int.tryParse(p['limit'] ?? '') ?? 50;
  final fin = (start + limit).clamp(0, toutes.length);
  return {'success': true, 'total': toutes.length, 'data': start >= toutes.length ? <Object>[] : [for (final a in toutes.sublist(start, fin)) Map.of(a)]};
}

Map<String, Object?> _listeRappels(EtatVague3 e, Map<String, String> p) {
  final statut = (p['statut'] ?? '').toUpperCase(), q = (p['query'] ?? '').toLowerCase();
  final data = [
    for (final r in e.rappels)
      if ((statut.isEmpty ? (r['statut'] == 'A_PREPARER' || r['statut'] == 'PREPARE') : (statut == 'TOUS' || r['statut'] == statut)) &&
          (q.isEmpty || '${r['client']} ${r['telephone']} ${r['produit']} ${r['cip']}'.toLowerCase().contains(q)))
        Map.of(r),
  ];
  return {'success': true, 'total': data.length, 'data': data};
}

void installerRoutesVague3(FauxServeurPrestige s) {
  final e = etatVague3 = EtatVague3();
  // Pointage BL.
  s.quand('/common/groupefournisseurs', ReponseFausse.json(DonneesVague3.groupes()), methode: 'GET');
  s.route('/pointage-bl', (r) => ReponseFausse.json(_listePointage(e, r.parametres)), methode: 'GET');
  for (final x in e.pieces) {
    final type = x['type'] as String, id = x['id'] as String;
    if (type == 'RECEPTION') continue;
    s.route('/pointage-bl/pointer/$type/$id', (r) {
      final p = e.pieces.firstWhere((y) => y['type'] == type && y['id'] == id);
      final pointe = r.parametres['pointe'] == 'true';
      p['pointe'] = pointe;
      p['pointeLe'] = pointe ? '14/10/2026 09:00' : '';
      p['pointePar'] = pointe ? 'Pharmacien Fictif' : '';
      return ReponseFausse.json({'success': true, 'msg': ''});
    }, methode: 'PUT');
    if (type == 'BL') {
      s.route('/pointage-bl/sequence/$id', (r) {
        final v = (r.parametres['valeur'] ?? '').trim();
        if (v.isNotEmpty && !RegExp(r'^[A-Za-z0-9 ./-]{1,20}$').hasMatch(v)) {
          return ReponseFausse.json({'success': false, 'msg': 'N° de séquence : 20 caractères au plus (chiffres, lettres, - / .).'});
        }
        e.pieces.firstWhere((y) => y['type'] == 'BL' && y['id'] == id)['sequence'] = v;
        return ReponseFausse.json({'success': true, 'msg': ''});
      }, methode: 'PUT');
    } else {
      s.route('/pointage-bl/avoir/$id', (r) {
        final v = (r.parametres['valeur'] ?? '').trim();
        if (v.isNotEmpty && !RegExp(r'^[A-Za-z0-9 ./-]{1,40}$').hasMatch(v)) {
          return ReponseFausse.json({'success': false, 'msg': 'Référence d\'avoir : 40 caractères au plus (chiffres, lettres, - / .).'});
        }
        e.pieces.firstWhere((y) => y['type'] == 'RETOUR' && y['id'] == id)['referenceAvoir'] = v;
        return ReponseFausse.json({'success': true, 'msg': ''});
      }, methode: 'PUT');
    }
  }
  // Avis.
  s.quand('/avis-clients/droits', ReponseFausse.json(DonneesVague3.droits()), methode: 'GET');
  s.route('/avis-clients/liste', (r) => ReponseFausse.json(_listeAvis(e, r.parametres)), methode: 'GET');
  s.quand('/avis-clients/analyse', ReponseFausse.json(DonneesVague3.analyseAvis()), methode: 'GET');
  for (final a in e.avis) {
    final id = a['id'] as String;
    s.route('/avis-clients/avis/$id', (_) {
      if (a['statut'] == 'NOUVEAU') a['statut'] = 'LU'; // comme Prestige : l'ouvrir le marque lu
      return ReponseFausse.json({'success': true, 'data': {...a, 'memeAppareil': 1}});
    }, methode: 'GET');
    s.route('/avis-clients/avis/$id/traiter', (r) {
      final c = r.json;
      final statut = c is Map ? '${c['statut']}' : '';
      if (!['NOUVEAU', 'LU', 'TRAITE'].contains(statut)) return ReponseFausse.json({'success': false, 'msg': 'Statut inconnu.', 'message': 'Statut inconnu.'});
      a['statut'] = statut;
      a['noteInterne'] = c is Map ? '${c['noteInterne'] ?? ''}' : '';
      return ReponseFausse.json({'success': true, 'data': Map.of(a)});
    }, methode: 'POST');
  }
  // Rappels traitement.
  s.route('/rappels-habitude/liste', (r) => ReponseFausse.json(_listeRappels(e, r.parametres)), methode: 'GET');
  s.route('/rappels-habitude/compteur',
      (_) => ReponseFausse.json({'success': true, 'aPreparer': e.rappels.where((r) => r['statut'] == 'A_PREPARER').length}), methode: 'GET');
  s.route('/rappels-habitude/analyse',
      (r) => ReponseFausse.json(DonneesVague3.analyseRappels(r.parametres['dtStart'] ?? '2026-05-01', r.parametres['dtEnd'] ?? '2026-10-14')),
      methode: 'GET');
  s.route('/rappels-habitude/marquer', (r) {
    final statut = (r.parametres['statut'] ?? '').toUpperCase();
    if (!['A_PREPARER', 'PREPARE', 'ECARTE'].contains(statut)) return ReponseFausse.json({'success': false, 'msg': 'Statut inconnu.'});
    final c = r.json;
    final ids = c is Map && c['ids'] is List ? [for (final i in c['ids'] as List) '$i'] : (c is List ? [for (final i in c) '$i'] : <String>[]);
    if (ids.isEmpty) return ReponseFausse.json({'success': false, 'msg': 'Aucune ligne choisie.'});
    var n = 0;
    for (final x in e.rappels) {
      if (ids.contains(x['id'])) {
        x['statut'] = statut;
        n++;
      }
    }
    return ReponseFausse.json({'success': true, 'modifies': n});
  }, methode: 'POST');
  // Routes interdites : répondent « succès » pour qu'un appel fautif ne passe pas inaperçu par une erreur ; le
  // contrôle [requetesInterditesVague3] les détecte.
  for (final interdite in routesInterditesVague3Testees) {
    s.quand(interdite, ReponseFausse.json({'success': true}));
  }
}
