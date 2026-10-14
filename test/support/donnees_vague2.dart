// Données FICTIVES et routes par défaut du faux serveur pour la vague 2 des nouveaux menus (Prévisions, Pilotage,
// Analyse de garde, CA emplacement / famille). Formats réels du serveur Prestige (branche claude/new-session-xm8ptu,
// PrevisionCommandeRessource, PilotageRessource, GardeRessource, CaZoneGeoRessource), données inventées.
import 'faux_serveur_prestige.dart';
import 'requetes_vague2.dart';

export 'requetes_vague2.dart';

class DonneesVague2 {
  DonneesVague2._();

  // --- Prévisions ---
  static Map<String, Object?> tableau() => {
        'success': true,
        'calcule': true,
        'dernierCalcul': '14/10/2026 03:12',
        'origine': 'NUIT',
        'produits': 1240,
        'produitsVendus': 860,
        'tauxRupture': 4.2,
        'ruptures': 18,
        'produitsReguliers': 430,
        'valeurInvendus': 385000,
        'invendus': 57,
        'couvertureMoyenne': 21,
        'fiabilite': 78,
        'aCommander': 42,
        'valeurACommander': 1250000,
        'surstock': 33,
        'joursLente': 90,
        'joursSurstock': 90,
        'methodes': [
          {'methode': 'MOYENNE', 'produits': 300, 'fiabilite': 74},
          {'methode': 'SAISON', 'produits': 120, 'fiabilite': 81},
        ],
        'evolution': <Object>[],
      };

  static const nombrePrevisions = 30;

  static Map<String, Object?> lignePrevision(int i) => {
        'id': 'PRD-PREV-$i',
        'nom': 'PRODUIT PREVU FICTIF $i',
        'cip': '88800${i.toString().padLeft(2, '0')}',
        'methode': i.isEven ? 'SAISON' : 'MOYENNE',
        'prevuMois': 10.5 + i,
        'fiabilite': 60 + i,
        'ventes12': 120 + i * 3,
        'derniereVente': '12/10/2026',
        'stock': i % 5 == 0 ? 0 : i,
        'enCours': i % 3 == 0 ? 6 : 0,
        'equivalents': i % 4,
        'delai': 2,
        'couverture': i % 5 == 0 ? null : i * 2,
        'recommande': i % 2 == 0 ? i : 0,
        'paf': 1500,
        'valeur': (i % 2 == 0 ? i : 0) * 1500,
        'grossiste': 'GROSSISTE FICTIF',
        'historique': '10,12,9,14,11,13',
        'ecartType': 1.8,
      };

  /// GET /analyse-commande/previsions : filtre ACOMMANDER = recommandé > 0, RUPTURE = stock 0 ; recherche dans le
  /// nom ou le CIP ; pages start / limit.
  static Map<String, Object?> previsions(Map<String, String> p) {
    final q = (p['query'] ?? '').trim().toLowerCase();
    final f = p['filtre'] ?? '';
    final toutes = [
      for (var i = 1; i <= nombrePrevisions; i++)
        if ((f != 'ACOMMANDER' || i.isEven) &&
            (f != 'RUPTURE' || i % 5 == 0) &&
            (q.isEmpty || 'produit prevu fictif $i'.contains(q) || '88800${i.toString().padLeft(2, '0')}'.contains(q)))
          lignePrevision(i),
    ];
    final start = int.tryParse(p['start'] ?? '') ?? 0, limit = int.tryParse(p['limit'] ?? '') ?? 25;
    final fin = (start + limit).clamp(0, toutes.length);
    return {'success': true, 'total': toutes.length, 'data': start >= toutes.length ? <Object>[] : toutes.sublist(start, fin), 'couvertureVoulue': 15};
  }

  static Map<String, Object?> produit(int i) => {
        ...lignePrevision(i),
        'success': true,
        'mois': [
          for (final (m, v) in [('avr. 26', 10), ('mai 26', 12), ('juin 26', 9), ('juil. 26', 14), ('août 26', 11), ('sept. 26', 13)]) {'mois': m, 'ventes': v},
        ],
        'prochainMois': 'oct. 26',
        'methodes': [
          {'methode': 'MOYENNE', 'erreur': 2.4, 'retenue': i.isOdd},
          {'methode': 'SAISON', 'erreur': 1.9, 'retenue': i.isEven},
        ],
        'calcul': {'parJour': 0.38, 'delai': 2, 'couvertureVoulue': 15, 'besoin': 6.5, 'securite': 2.1, 'ecartType': 1.8},
        'delaiOrigine': 'délai du grossiste GROSSISTE FICTIF',
        'delaiDuGrossiste': true,
        'rayon': 3,
        'reserve': 2,
        'couvertureOrigine': 'paramètre (couverture voulue)',
        'derniereVenteQte': 1,
      };

  static Map<String, Object?> equivalents() => {
        'success': true,
        'total': 2,
        'data': [
          {'id': 'EQ-1', 'nom': 'EQUIVALENT FICTIF 500MG', 'cip': '7770001', 'prix': 1200, 'stock': 8, 'niveau': 'DIRECT', 'detail': false, 'raison': 'même DCI, même dosage', 'rayon': 8, 'reserve': 4},
          {'id': 'EQ-2', 'nom': 'EQUIVALENT IMAGINAIRE 1G', 'cip': '7770002', 'prix': 2100, 'stock': 0, 'niveau': 'ADAPTER', 'detail': false, 'raison': 'dosage différent', 'rayon': 0, 'reserve': 0},
        ],
      };

  static Map<String, Object?> aAnalyser() => {
        'success': true,
        'data': [
          {'type': 'SUGGESTION', 'id': 'SUG-TEST-1', 'ref': 'SUG-2026-0101', 'grossiste': 'GROSSISTE FICTIF', 'date': '14/10/2026 08:10', 'statut': 'is_Process', 'lignes': 3},
          {'type': 'COMMANDE', 'id': 'CMD-TEST-1', 'ref': 'CMD-2026-0042', 'grossiste': 'GROSSISTE IMAGINAIRE', 'date': '13/10/2026 17:45', 'statut': 'is_Process', 'lignes': 2},
        ],
      };

  static Map<String, Object?> analyse(String type) => {
        'success': true,
        'type': type,
        'ref': type == 'COMMANDE' ? 'CMD-2026-0042' : 'SUG-2026-0101',
        'grossiste': 'GROSSISTE FICTIF',
        'statut': 'is_Process',
        'resume': {'lignes': 3, 'lignesAlerte': 2, 'valeurProposee': 45000, 'valeurRecommandee': 30000, 'SURSTOCK': 1},
        'calcule': true,
        'data': [
          {'id': 'PRD-PREV-1', 'nom': 'PRODUIT PREVU FICTIF 1', 'cip': '8880001', 'quantite': 20, 'recommande': 5, 'ecart': 15, 'prevuMois': 11.5, 'stock': 12,
            'enCours': 0, 'equivalents': 0, 'couverture': 31, 'prix': 1500, 'dernierPrix': 1450, 'fiabilite': 61, 'methode': 'MOYENNE', 'nouveau': false,
            'alertes': [{'code': 'SURSTOCK', 'texte': 'Quantité bien supérieure au besoin', 'grave': true}], 'grave': true},
          {'id': 'PRD-PREV-2', 'nom': 'PRODUIT PREVU FICTIF 2', 'cip': '8880002', 'quantite': 4, 'recommande': 6, 'ecart': -2, 'prevuMois': 12.5, 'stock': 2,
            'enCours': 0, 'equivalents': 1, 'couverture': null, 'prix': 2000, 'dernierPrix': 2300, 'fiabilite': 62, 'methode': 'SAISON', 'nouveau': false,
            'alertes': [{'code': 'PRIX', 'texte': 'Prix plus bas que le dernier achat', 'grave': false}], 'grave': false},
          {'id': 'PRD-PREV-3', 'nom': 'PRODUIT PREVU FICTIF 3', 'cip': '8880003', 'quantite': 3, 'recommande': 3, 'ecart': 0, 'prevuMois': 13.5, 'stock': 3,
            'enCours': 6, 'equivalents': 0, 'couverture': 20, 'prix': 1000, 'dernierPrix': 1000, 'alertes': <Object>[], 'grave': false},
        ],
      };

  static Map<String, Object?> demande(int mois) => {
        'success': true,
        'debut': '2025-10-01',
        'fin': '2026-09-30',
        'mois': mois,
        'total': 4820,
        'annees': [
          {'annee': 2025, 'mois': [null, null, null, null, null, null, null, null, null, 390, 410, 520], 'total': 1320},
          {'annee': 2026, 'mois': [480, 430, 380, 350, 330, 320, 310, 300, 310, null, null, null], 'total': 3210},
        ],
        'indices': [1.2, 1.07, 0.95, 0.87, 0.82, 0.8, 0.77, 0.75, 0.77, 0.97, 1.02, 1.29],
        'pic': 12,
        'force': 0.18,
        'tendance': mois >= 24 ? {'recent': 4820, 'avant': 4400, 'evolution': 9.5} : <String, Object?>{},
        'produits': [
          {'id': 'PRD-SAI-1', 'cip': '6660001', 'libelle': 'SIROP SAISONNIER FICTIF', 'unites': 240, 'force': 0.62, 'pic': 12, 'indicePic': 2.1, 'anticiper': false},
          {'id': 'PRD-SAI-2', 'cip': '6660002', 'libelle': 'SPRAY HIVERNAL IMAGINAIRE', 'unites': 130, 'force': 0.48, 'pic': 11, 'indicePic': 1.7, 'anticiper': true},
        ],
        'anticiper': [
          {'id': 'PRD-SAI-2', 'cip': '6660002', 'libelle': 'SPRAY HIVERNAL IMAGINAIRE', 'unites': 130, 'force': 0.48, 'pic': 11, 'indicePic': 1.7, 'anticiper': true},
        ],
        'prochainMois': 11,
        'produitsClasses': 85,
      };

  // --- Pilotage ---
  static Map<String, Object?> axes() => {
        'success': true,
        'total': 6,
        'data': [
          {'code': 'MOIS', 'libelle': 'Mois en cours'},
          {'code': 'VS_M1', 'libelle': 'Vs mois précédent'},
          {'code': 'VS_N1', 'libelle': 'Vs même mois l\'an dernier'},
          {'code': 'YTD', 'libelle': 'Cumul annuel vs an dernier'},
          {'code': 'G12', 'libelle': 'Glissant 12 mois'},
          {'code': 'PERSO', 'libelle': 'Période personnalisée'},
        ],
      };

  static const caPilotage = 18450000;

  static Map<String, Object?> synthese(String axe) {
    final ref = axe == 'VS_M1' || axe == 'VS_N1' || axe == 'YTD';
    Map<String, Object?> t(String cle, String libelle, num v, num? r, String unite, [String? sous]) => {
          'cle': cle, 'libelle': libelle, 'valeur': v, 'unite': unite, if (sous != null) 'sousTitre': sous,
          if (ref && r != null) ...{'reference': r, 'variation': ((v - r) * 100 / r * 10).round() / 10, 'ecart': v - r, 'libelleReference': 'septembre 2026'},
        };
    return {
      'success': true,
      'axe': {
        'code': axe,
        'libelle': 'Octobre 2026',
        'periode': 'du 01/10/2026 au 14/10/2026',
        'explication': '',
        'comparaison': ref,
        if (ref) 'libelleReference': 'septembre 2026',
        if (ref) 'periodeReference': 'du 01/09/2026 au 14/09/2026',
      },
      'tuiles': [
        t('caTTC', 'Chiffre d\'affaires TTC', caPilotage, 17000000, 'FCFA'),
        t('marge', 'Marge', 5200000, 5600000, 'FCFA', 'taux : 28,2 %'),
        t('achats', 'Achats TTC', 12000000, 11000000, 'FCFA', '14 bon(s) de livraison'),
        t('ratioVA', 'Ratio ventes / achats', 1.54, 1.55, '', 'CA TTC rapporté aux achats TTC de la période'),
        t('nbVentes', 'Nombre de ventes', 2140, 2140, '', 'panier moyen : 8622 FCFA'),
      ],
      'mois': <Object>[],
    };
  }

  static Map<String, Object?> aSuivre(String axe) => {
        'success': true,
        'axe': {'code': axe, 'libelle': 'Octobre 2026', 'periode': 'du 01/10/2026 au 14/10/2026', 'comparaison': false},
        'tuiles': [
          {'cle': 'rupturesVendus', 'libelle': 'Produits vendus en rupture', 'valeur': 7, 'unite': '', 'sousTitre': 'vendus ces 90 derniers jours, stock à zéro aujourd\'hui', 'alerte': true},
          {'cle': 'rateesACommander', 'libelle': 'Ventes ratées à commander', 'valeur': 3, 'unite': ''},
          {'cle': 'margeNegative', 'libelle': 'Vendus sous le prix d\'achat', 'valeur': 1, 'unite': '', 'alerte': true},
        ],
        'alertes': [
          {'niveau': 'critique', 'texte': '7 produit(s) vendu(s) ces 90 derniers jours sont en rupture : à commander.'},
          {'niveau': 'alerte', 'texte': '3 vente(s) ratée(s) pas encore commandée(s).'},
        ],
        'ruptures': [
          {'cip': '5550001', 'libelle': 'PRODUIT RUPTURE PILOTAGE FICTIF', 'vendus': 25},
        ],
        'margeNegative': [
          {'cip': '5550002', 'libelle': 'PRODUIT A PERTE FICTIF', 'paf': 2000, 'prix': 1800, 'vendus': 4},
        ],
        'emplacements': <Object>[],
        'familles': <Object>[],
      };

  // --- Gardes ---
  static Map<String, Object?> annees() => {
        'success': true,
        'total': 2,
        'data': [
          {'annee': 2026, 'libelle': '2026'},
          {'annee': 2025, 'libelle': '2025'},
        ],
      };

  static Map<String, Object?> garde(String id, String libelle, String debut, String fin) => {
        'id': id, 'libelle': libelle, 'dateDebut': '$debut:00', 'dateFin': '$fin:00', 'jourDebut': debut.substring(0, 10), 'heureDebut': debut.substring(11),
        'jourFin': fin.substring(0, 10), 'heureFin': fin.substring(11), 'dureeMinutes': 720, 'duree': '12 h',
      };

  static Map<String, Object?> gardes(String annee) => {
        'success': true,
        'data': annee == '2026'
            ? [
                garde('GARDE-TEST-1', 'Garde du 05/09', '2026-09-05 20:00', '2026-09-06 08:00'),
                garde('GARDE-TEST-2', 'Garde du 19/09', '2026-09-19 20:00', '2026-09-20 08:00'),
              ]
            : [garde('GARDE-TEST-0', 'Garde de décembre', '2025-12-24 20:00', '2025-12-25 08:00')],
      };

  static const nombreProduitsGarde = 30;

  static Map<String, Object?> rapport(Map<String, String> p) {
    final classe = p['classe'] ?? '';
    final tous = [
      for (var i = 1; i <= nombreProduitsGarde; i++)
        {
          'produitId': 'PG-$i', 'classe': i <= 5 ? 'A' : (i <= 12 ? 'B' : 'C'), 'cip': '44400${i.toString().padLeft(2, '0')}',
          'libelle': 'PRODUIT DE GARDE FICTIF $i', 'quantite': 40 - i, 'montant': (40 - i) * 1000, 'marge': (40 - i) * 300, 'tauxMarge': 30.0,
          'part': 3.3, 'cumulPart': 3.3 * i, 'stock': i,
        },
    ];
    final filtres = [for (final x in tous) if (classe.isEmpty || x['classe'] == classe) x];
    final start = int.tryParse(p['start'] ?? '') ?? 0, limit = int.tryParse(p['limit'] ?? '') ?? 0;
    final fin = limit <= 0 ? filtres.length : (start + limit).clamp(0, filtres.length);
    final h = int.tryParse(p['heures'] ?? '') ?? 2;
    return {
      'success': true,
      'garde': garde('GARDE-TEST-1', 'Garde du 05/09', '2026-09-05 20:00', '2026-09-06 08:00'),
      'indicateurs': {'ventes': 64, 'montant': 410000},
      'tranches': [
        for (var debut = 20; debut < 32; debut += h)
          {'libelle': '${(debut % 24).toString().padLeft(2, '0')}h-${((debut + h) % 24).toString().padLeft(2, '0')}h', 'heureDuJour': debut % 24, 'ventes': 6,
            'clients': 5 + debut % 3, 'quantite': 12, 'montant': 30000 + (debut % 4) * 5000, 'heuresCouvertes': h, 'clientsParHeure': 2.5},
      ],
      'kpi': {
        'ventes': 64, 'clients': 58, 'montant': 410000, 'marge': 118000, 'tauxMarge': 28.78, 'montantParHeure': 34167, 'dureeMinutes': 720,
        'rates': 2, 'clientsCredit': 3, 'montantCredit': 25000, 'caEspeces': 300000, 'caMobile': 85000, 'caCheque': 0, 'caCarte': 0, 'caDiffere': 0, 'caAutres': 0,
      },
      'abc': start >= filtres.length ? <Object>[] : filtres.sublist(start, fin),
      'totalAbc': tous.length,
      'totalFiltre': filtres.length,
      'resumeAbc': [
        {'classe': 'A', 'produits': 5, 'montant': 185000, 'marge': 55000, 'tauxMarge': 29.7, 'part': 45.1},
        {'classe': 'B', 'produits': 7, 'montant': 150000, 'marge': 42000, 'tauxMarge': 28.0, 'part': 36.6},
        {'classe': 'C', 'produits': 18, 'montant': 75000, 'marge': 21000, 'tauxMarge': 28.0, 'part': 18.3},
      ],
    };
  }

  static Map<String, Object?> vendeurs() => {
        'success': true,
        'total': 2,
        'data': [
          {'vendeurId': 'USR-TEST-0101', 'nom': 'CAISSIERE Fictive Une', 'ventes': 40, 'clients': 36, 'montant': 260000, 'marge': 75000, 'tauxMarge': 28.8, 'part': 63.4},
          {'vendeurId': 'USR-TEST-0102', 'nom': 'VENDEUR Fictif Deux', 'ventes': 24, 'clients': 22, 'montant': 150000, 'marge': 43000, 'tauxMarge': 28.7, 'part': 36.6},
        ],
      };

  // --- CA emplacement / famille ---
  static List<Map<String, Object?>> tranchesCa(String type) => switch (type) {
        'TROIS_ANS' => [
            for (final a in [2023, 2024, 2025, 2026]) {'cle': '$a', 'libelle': '$a', 'debut': '$a-01-01', 'fin': '$a-12-31', 'enCours': a == 2026},
          ],
        'TROIS_MOIS' => [
            for (final m in ['07', '08', '09', '10'])
              {'cle': '2026-$m', 'libelle': '$m/2026', 'debut': '2026-$m-01', 'fin': '2026-$m-28', 'enCours': m == '10'},
          ],
        _ => [
            for (final (s, l) in [('2026-W39', 'S39 (21/09-27/09)'), ('2026-W40', 'S40 (28/09-04/10)'), ('2026-W41', 'S41 (05/10-11/10)'), ('2026-W42', 'S42 (12/10-14/10)')])
              {'cle': s, 'libelle': l, 'debut': '', 'fin': '', 'enCours': s == '2026-W42'},
          ],
      };

  static Map<String, Object?> caZone(Map<String, String> p) {
    final tranches = tranchesCa(p['typePeriode'] ?? 'TROIS_SEMAINES');
    final reg = p['regroupement'] ?? 'ZONE';
    final lignes = <Map<String, Object?>>[];
    final base = [('ZONE-TEST-1', 'RAYON A', 'FAM-TEST-1', 'ANTALGIQUES FICTIFS', 100000), ('ZONE-TEST-2', 'RAYON B', 'FAM-TEST-2', 'SIROPS IMAGINAIRES', 60000)];
    final totaux = <String, int>{};
    for (final (zid, z, fid, f, m) in base) {
      if ((p['zoneId'] ?? '').isNotEmpty && p['zoneId'] != zid) continue;
      final l = <String, Object?>{
        'zoneId': reg == 'FAMILLE' ? '' : zid, 'zone': reg == 'FAMILLE' ? '' : z, 'familleId': reg == 'ZONE' ? '' : fid, 'famille': reg == 'ZONE' ? '' : f,
        'libelle': reg == 'FAMILLE' ? f : z, 'montantHt': 0, 'achat': 0, 'tva': 0, 'marge': m ~/ 3, 'pourcentageMarge': 30.5,
      };
      var total = 0;
      int? precedent;
      for (var i = 0; i < tranches.length; i++) {
        final cle = tranches[i]['cle']! as String;
        final v = m + i * 10000;
        l['t_$cle'] = v;
        l['q_$cle'] = v ~/ 1000;
        l['e_$cle'] = precedent == null ? null : ((v - precedent) * 1000 / precedent).round() / 10;
        precedent = v;
        total += v;
        totaux[cle] = (totaux[cle] ?? 0) + v;
      }
      l['total'] = total;
      l['evolution'] = 20.0;
      lignes.add(l);
    }
    return {
      'success': true,
      'data': lignes,
      'total': lignes.length,
      'tranches': tranches,
      'granularite': 'SEMAINE',
      'totauxTranches': totaux,
      'evolutionsTranches': {for (var i = 0; i < tranches.length; i++) tranches[i]['cle']! as String: i == 0 ? null : 8.5},
      'totalGeneral': lignes.fold<int>(0, (s, l) => s + (l['total']! as int)),
      'margeGenerale': 150000,
      'montantHtGeneral': 600000,
      'achatGeneral': 450000,
      'pourcentageMargeGeneral': 25.0,
      'debut': '2026-09-21',
      'fin': '2026-10-14',
      'evolutionGenerale': 18.2,
    };
  }

  static Map<String, Object?> detailCa() => {
        'success': true,
        'total': 2,
        'data': [
          {'produitId': 'PCA-1', 'cip': '3330001', 'designation': 'PRODUIT CA FICTIF 1', 'prixAchat': 800, 'prixVente': 1200, 'quantite': 50, 'montant': 60000,
            'montantHt': 55000, 'achat': 40000, 'marge': 15000, 'pourcentageMarge': 27.3},
          {'produitId': 'PCA-2', 'cip': '3330002', 'designation': 'PRODUIT CA FICTIF 2', 'prixAchat': 1000, 'prixVente': 1500, 'quantite': 20, 'montant': 30000,
            'montantHt': 28000, 'achat': 20000, 'marge': 8000, 'pourcentageMarge': 28.6},
        ],
        'totaux': {'quantite': 70, 'montant': 90000, 'montantHt': 83000, 'achat': 60000, 'marge': 23000, 'pourcentageMarge': 27.7},
        'debut': '2026-09-21',
        'fin': '2026-10-14',
      };
}

/// Routes par défaut de la vague 2 (appelé par FauxServeurPrestige.installerRoutesParDefaut). Les routes INTERDITES
/// répondent comme le serveur (succès) : seuls les tests vérifient qu'elles ne sont jamais appelées.
void installerRoutesVague2(FauxServeurPrestige s) {
  s.quand('/analyse-commande/tableau', ReponseFausse.json(DonneesVague2.tableau()), methode: 'GET');
  s.route('/analyse-commande/previsions', (r) => ReponseFausse.json(DonneesVague2.previsions(r.parametres)), methode: 'GET');
  for (var i = 1; i <= DonneesVague2.nombrePrevisions; i++) {
    s.quand('/analyse-commande/produit/PRD-PREV-$i', ReponseFausse.json(DonneesVague2.produit(i)), methode: 'GET');
    s.quand('/analyse-commande/equivalents/PRD-PREV-$i', ReponseFausse.json(DonneesVague2.equivalents()), methode: 'GET');
  }
  s.quand('/analyse-commande/a-analyser', ReponseFausse.json(DonneesVague2.aAnalyser()), methode: 'GET');
  s.route('/analyse-commande/analyse', (r) => ReponseFausse.json(DonneesVague2.analyse(r.parametres['type'] ?? '')), methode: 'GET');
  s.route('/analyse-commande/demande', (r) => ReponseFausse.json(DonneesVague2.demande(int.tryParse(r.parametres['mois'] ?? '') ?? 12)), methode: 'GET');
  s.quand('/pilotage/axes', ReponseFausse.json(DonneesVague2.axes()), methode: 'GET');
  s.route('/pilotage/onglet/synthese', (r) => ReponseFausse.json(DonneesVague2.synthese(r.parametres['axe'] ?? 'MOIS')), methode: 'GET');
  s.route('/pilotage/onglet/asuivre', (r) => ReponseFausse.json(DonneesVague2.aSuivre(r.parametres['axe'] ?? 'MOIS')), methode: 'GET');
  s.quand('/pilotage/controler', ReponseFausse.json({'success': true, 'repris': 2}), methode: 'GET');
  s.quand('/gardes/annees', ReponseFausse.json(DonneesVague2.annees()), methode: 'GET');
  s.route('/gardes', (r) => ReponseFausse.json(DonneesVague2.gardes(r.parametres['annee'] ?? '')), methode: 'GET');
  for (final id in ['GARDE-TEST-0', 'GARDE-TEST-1', 'GARDE-TEST-2']) {
    s.route('/gardes/$id/rapport', (r) => ReponseFausse.json(DonneesVague2.rapport(r.parametres)), methode: 'GET');
    s.quand('/gardes/$id/vendeurs', ReponseFausse.json(DonneesVague2.vendeurs()), methode: 'GET');
  }
  s.route('/ca-zone-geo', (r) => ReponseFausse.json(DonneesVague2.caZone(r.parametres)), methode: 'GET');
  s.quand('/ca-zone-geo/detail', ReponseFausse.json(DonneesVague2.detailCa()), methode: 'GET');
  for (final interdite in routesInterditesTestees) {
    s.quand(interdite, ReponseFausse.json({'success': true}));
  }
}
