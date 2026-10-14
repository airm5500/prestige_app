// Données FICTIVES du lot 2 (achats et stock) : Suggestions, État de Stock, Visualisation BL, État Contrôle Achat,
// Retours fournisseurs, Évolution stock, Analyse Saisies BL, Suivi Ajustements. Formats réels des routes Prestige
// (ceux que lisent les modèles de lib/models/), contenus inventés. [donneesLot2] installe les routes sur le faux
// serveur ; les écritures des Suggestions répondent {success:true} et sont relevées par le journal du serveur.
import 'package:intl/intl.dart';

import 'donnees_fictives.dart';
import 'faux_serveur_prestige.dart';

class DonneesLot2 {
  DonneesLot2._();

  // --- Suggestions ---
  static const suggestion1 = 'SUG-TEST-1', suggestion2 = 'SUG-TEST-2';
  static const grossisteA = 'GROSSISTE FICTIF A', grossisteB = 'GROSSISTE FICTIF B';
  static const article1 = 'ITEM-TEST-1', article2 = 'ITEM-TEST-2', article3 = 'ITEM-TEST-3';

  static Map<String, Object?> suggestions() => {
        'data': [
          {'lg_SUGGESTION_ORDER_ID': suggestion1, 'str_REF': 'SUGG-FICTIVE-01', 'str_STATUT': 'pending', 'lg_GROSSISTE_ID': grossisteA, 'dt_CREATED': '12/10/2026'},
          {'lg_SUGGESTION_ORDER_ID': suggestion2, 'str_REF': 'SUGG-FICTIVE-02', 'str_STATUT': 'is_Process', 'lg_GROSSISTE_ID': grossisteB, 'dt_CREATED': '13/10/2026'},
        ],
        'total': 2,
      };

  static Map<String, Object?> lignesSuggestion() => {
        'data': [
          {'lg_SUGGESTION_ORDER_DETAILS_ID': article1, 'str_FAMILLE_CIP': '3400000000011', 'str_FAMILLE_NAME': DonneesFictives.libelleArticle1, 'int_VENTE': 1200,
            'int_ACHAT': 850, 'int_STOCK': 4, 'int_NUMBER': 10, 'int_VALUE0': 6, 'int_VALUE1': 12, 'int_VALUE2': 9, 'int_VALUE3': 15},
          {'lg_SUGGESTION_ORDER_DETAILS_ID': article2, 'str_FAMILLE_CIP': '3400000000028', 'str_FAMILLE_NAME': DonneesFictives.libelleArticle2, 'int_VENTE': 2500,
            'int_ACHAT': 1800, 'int_STOCK': 0, 'int_NUMBER': 5, 'int_VALUE0': 2, 'int_VALUE1': 4, 'int_VALUE2': 3, 'int_VALUE3': 5},
          {'lg_SUGGESTION_ORDER_DETAILS_ID': article3, 'str_FAMILLE_CIP': '3400000000035', 'str_FAMILLE_NAME': 'POMMADE IMAGINAIRE 30G', 'int_VENTE': 3100,
            'int_ACHAT': 2200, 'int_STOCK': 2, 'int_NUMBER': 3, 'int_VALUE0': 1, 'int_VALUE1': 2, 'int_VALUE2': 2, 'int_VALUE3': 2},
        ],
        'total': 3,
      };

  static const montantAchat = 23600, montantVente = 33800;
  static Map<String, Object?> montantSuggestion() => {'montantAchat': montantAchat, 'montantVente': montantVente};

  // --- Listes communes (emplacements, grossistes, groupes, utilisateurs, fournisseurs, motifs) ---
  static Map<String, Object?> rayons() => {
        'data': [
          {'id': 'RAY-A', 'libelle': 'RAYON A'},
          {'id': 'RAY-B', 'libelle': 'RAYON B'},
        ],
      };
  static Map<String, Object?> grossistes() => {
        'data': [
          {'id': 'GRO-A', 'libelle': grossisteA},
          {'id': 'GRO-B', 'libelle': grossisteB},
        ],
      };
  static Map<String, Object?> groupes() => {
        'data': [
          {'id': 1, 'libelle': 'GROUPE FICTIF A'},
          {'id': 2, 'libelle': 'GROUPE FICTIF B'},
        ],
      };
  static Map<String, Object?> utilisateurs() => {
        'data': [
          {'lgUSERID': 'USR-1', 'fullName': DonneesFictives.nomComplet},
          {'lgUSERID': 'USR-2', 'fullName': 'EMPLOYE Fictif Deux'},
        ],
      };
  static Map<String, Object?> fournisseurs() => {
        'data': [
          {'fournisseurId': 'FOU-A', 'fournisseurLibelle': grossisteA},
          {'fournisseurId': 'FOU-B', 'fournisseurLibelle': grossisteB},
        ],
      };
  static Map<String, Object?> typesAjustement() => {
        'data': [
          {'id': 'TYP-CASSE', 'libelle': 'CASSE'},
          {'id': 'TYP-INVENT', 'libelle': 'INVENTAIRE'},
        ],
      };

  // --- État de Stock : 20 articles (2 pages de 15), RAYON A pour les pairs, stock nul pour un sur cinq ---
  static const articlesStock = 20;
  static List<Map<String, Object?>> articles() => [
        for (var i = 1; i <= articlesStock; i++)
          {
            'id': 'ART-$i',
            'code': '34000000${i.toString().padLeft(5, '0')}',
            'libelle': i == 1 ? DonneesFictives.libelleArticle1 : (i == 2 ? DonneesFictives.libelleArticle2 : 'ARTICLE FICTIF $i'),
            'stock': i % 5 == 0 ? 0 : i * 3,
            'prixAchat': 500 + i * 100,
            'prixVente': 700 + i * 140,
            'rayonLibelle': i.isEven ? 'RAYON A' : 'RAYON B',
            'codeEan': '76100000${i.toString().padLeft(5, '0')}',
            'dateInventaire': '01/09/2026',
            'dateEntree': '10/10/2026',
            'qteReappro': 6,
            'grossisteId': i.isEven ? 'GRO-A' : 'GRO-B',
          },
      ];

  static ReponseFausse comparaison(RequeteRecue r) {
    final q = (r.parametres['query'] ?? '').toLowerCase();
    final rayon = r.parametres['codeRayon'] ?? '';
    var l = [
      for (final a in articles())
        if ((q.isEmpty || '${a['libelle']}'.toLowerCase().contains(q) || '${a['code']}'.contains(q)) &&
            (rayon.isEmpty || (rayon == 'RAY-A') == (a['rayonLibelle'] == 'RAYON A')))
          a,
    ];
    final filtre = r.parametres['filtreStock'] ?? '';
    final seuil = int.tryParse(r.parametres['stock'] ?? '');
    if (filtre.isNotEmpty && seuil != null) {
      bool garde(num s) => switch (filtre) {
            'EQUAL' => s == seuil,
            'LESS' => s < seuil,
            'GREATER' => s > seuil,
            'GREATER_EQUAL' => s >= seuil,
            'LESS_EQUAL' => s <= seuil,
            _ => s != seuil,
          };
      l = [for (final a in l) if (garde(a['stock'] as num)) a];
    }
    final start = int.tryParse(r.parametres['start'] ?? '0') ?? 0;
    final limit = int.tryParse(r.parametres['limit'] ?? '15') ?? 15;
    return ReponseFausse.json({'total': l.length, 'data': l.skip(start).take(limit).toList()});
  }

  // --- Bons de livraison (Visualisation BL : pages de 20 ; Analyse Saisies BL : tout, mêmes bons) : 23 BL ---
  static const bonsLivraison = 23;
  static String _jj(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);
  static List<Map<String, Object?>> bons() {
    final j = DateTime.now();
    return [
      for (var i = 1; i <= bonsLivraison; i++)
        {
          'lgBONLIVRAISONID': 'BL-ID-$i',
          'strREFLIVRAISON': 'BL-TEST-${i.toString().padLeft(3, '0')}',
          'dtDATELIVRAISON': _jj(DateTime(j.year, j.month, j.day - (i % 4), 9)),
          'dtCREATED': _jj(DateTime(j.year, j.month, j.day, 10)),
          'dtUPDATED': _jj(DateTime(j.year, j.month, j.day, 10)),
          'fournisseurLibelle': i.isEven ? grossisteA : grossisteB,
          'user': {'fullName': i.isEven ? DonneesFictives.nomComplet : 'EMPLOYE Fictif Deux'},
          'checked': ['TERMINE', 'EN_COURS', 'NON_TRAITE'][i % 3],
          'intMHT': 100000 + i * 1000,
          'intTVA': 18000 + i * 180,
          'intHTTC': 118000 + i * 1180,
          'bonLivraisonDetails': [
            {
              'produit': {'intCIP': '3400000000011', 'strDESCRIPTION': DonneesFictives.libelleArticle1},
              'intQTERECUE': 10, 'intQTECMDE': 12, 'intQTEUG': 1, 'intPAF': 850, 'intPRIXVENTE': 1200, 'intINITSTOCK': 4,
              'quantiteControle': i == 1 ? 13 : 14, 'checked': true,
            },
            {
              'produit': {'intCIP': '3400000000028', 'strDESCRIPTION': DonneesFictives.libelleArticle2},
              'intQTERECUE': 5, 'intQTECMDE': 5, 'intQTEUG': 0, 'intPAF': 1800, 'intPRIXVENTE': 2500, 'intINITSTOCK': 0,
              'quantiteControle': 5, 'checked': true,
            },
          ],
        },
    ];
  }

  static ReponseFausse listeBons(RequeteRecue r) {
    final q = (r.parametres['search'] ?? '').toLowerCase();
    // Comme le serveur (FiltresControleAchat) : « statutControle » CONTROLE = contrôle terminé, NON_CONTROLE = le
    // reste, autre valeur ou vide = tous ; filtré AVANT la pagination (total juste). « checked » et « userId » sont
    // ignorés, comme par le vrai serveur.
    final statut = (r.parametres['statutControle'] ?? '').toUpperCase();
    bool garde(Map<String, Object?> b) => switch (statut) {
          'CONTROLE' => b['checked'] == 'TERMINE',
          'NON_CONTROLE' => b['checked'] != 'TERMINE',
          _ => true,
        };
    final l = [for (final b in bons()) if ((q.isEmpty || '${b['strREFLIVRAISON']}'.toLowerCase().contains(q)) && garde(b)) b];
    final start = int.tryParse(r.parametres['start'] ?? '0') ?? 0;
    final limit = int.tryParse(r.parametres['limit'] ?? '20') ?? 20;
    return ReponseFausse.json({'total': l.length, 'data': l.skip(start).take(limit).toList()});
  }

  // --- Retours fournisseurs ---
  static const retour1 = 'RET-TEST-1';
  static Map<String, Object?> retours() => {
        'results': [
          {'lg_RETOUR_FRS_ID': retour1, 'str_GROSSISTE_LIBELLE': grossisteA, 'str_REF_RETOUR_FRS': 'RF-TEST-001', 'str_REF_LIVRAISON': 'BL-TEST-001',
            'dt_CREATED': '12/10/2026', 'MONTANTRETOUR': 42500, 'str_STATUT': 'enable', 'closed': false, 'int_LINE': 2},
          {'lg_RETOUR_FRS_ID': 'RET-TEST-2', 'str_GROSSISTE_LIBELLE': grossisteB, 'str_REF_RETOUR_FRS': 'RF-TEST-002', 'str_REF_LIVRAISON': 'BL-TEST-002',
            'dt_CREATED': '13/10/2026', 'MONTANTRETOUR': 18000, 'str_STATUT': 'enable', 'closed': true, 'int_LINE': 1},
        ],
      };
  static Map<String, Object?> detailsRetour() => {
        'data': [
          {'strNAME': DonneesFictives.libelleArticle1, 'intCIP': '3400000000011', 'intNUMBERRETURN': 5, 'intNUMBERANSWER': 3, 'prixPaf': 850,
            'motif': 'PRODUIT ABIMÉ', 'operateur': DonneesFictives.nomComplet, 'dtCREATED': '12/10/2026'},
          {'strNAME': DonneesFictives.libelleArticle2, 'intCIP': '3400000000028', 'intNUMBERRETURN': 2, 'intNUMBERANSWER': 0, 'prixPaf': 1800,
            'motif': 'ERREUR DE LIVRAISON', 'operateur': DonneesFictives.nomComplet, 'dtCREATED': '12/10/2026'},
        ],
      };
  static List<Map<String, Object?>> produitsRetournes() => [
        {'cip': '3400000000011', 'libelle': DonneesFictives.libelleArticle1, 'quantite': 5, 'prixAchatHt': 850, 'natureReclamation': 'PRODUIT ABIMÉ',
          'numeroBl': 'BL-TEST-001', 'dateAvoir': '12/10/2026 11:30'},
      ];

  // --- Évolution du stock : un point par jour (valeur d'achat croissante de 125 000 par jour) ---
  static const valeurInitiale = 10000000, pasJournalier = 125000;
  static ReponseFausse valorisations(RequeteRecue r) {
    final d = DateTime.tryParse(r.parametres['dtStart'] ?? '');
    final f = DateTime.tryParse(r.parametres['dtEnd'] ?? '');
    if (d == null || f == null) return ReponseFausse.json(const <Object>[]);
    final n = f.difference(d).inDays + 1;
    return ReponseFausse.json([
      for (var i = 0; i < n; i++) {'valeurAchat': valeurInitiale + i * pasJournalier, 'valeurVente': (valeurInitiale + i * pasJournalier) * 14 ~/ 10},
    ]);
  }

  // --- Ajustements ---
  static const ajustement1 = 'AJU-TEST-1';
  static Map<String, Object?> ajustements() => {
        'data': [
          {'lgAJUSTEMENTID': ajustement1, 'description': 'AJUSTEMENT FICTIF CASSE', 'userFullName': DonneesFictives.nomComplet, 'dtUPDATED': '13/10/2026',
            'heure': '10:15', 'details': ''},
          {'lgAJUSTEMENTID': 'AJU-TEST-2', 'description': 'AJUSTEMENT FICTIF INVENTAIRE', 'userFullName': 'EMPLOYE Fictif Deux', 'dtUPDATED': '13/10/2026',
            'heure': '16:40', 'details': ''},
        ],
      };
  static Map<String, Object?> produitsAjustement() => {
        'data': [
          {'strNAME': DonneesFictives.libelleArticle1, 'intNUMBER': -2, 'intPAF': 850, 'motifAjustement': 'CASSE', 'intNUMBERCURRENTSTOCK': 6, 'intNUMBERAFTERSTOCK': 4},
          {'strNAME': DonneesFictives.libelleArticle2, 'intNUMBER': 3, 'intPAF': 1800, 'motifAjustement': 'INVENTAIRE', 'intNUMBERCURRENTSTOCK': 0, 'intNUMBERAFTERSTOCK': 3},
        ],
      };
}

/// Routes du lot 2 sur le faux serveur (données fictives ci-dessus).
void donneesLot2(FauxServeurPrestige s) {
  final ok = ReponseFausse.json({'success': true});
  s
    ..quand('/suggestion/list', ReponseFausse.json(DonneesLot2.suggestions()), methode: 'GET')
    ..quand('/suggestion/list/items', ReponseFausse.json(DonneesLot2.lignesSuggestion()), methode: 'GET')
    ..quand('/suggestion/item/update-qte-cmde', ok, methode: 'POST');
  for (final id in [DonneesLot2.suggestion1, DonneesLot2.suggestion2]) {
    s
      ..quand('/suggestion/set-pending/$id', ok, methode: 'GET')
      ..quand('/suggestion/amount/$id', ReponseFausse.json(DonneesLot2.montantSuggestion()), methode: 'GET')
      ..quand('/suggestion/suggestion/$id', ok, methode: 'DELETE');
  }
  for (final id in [DonneesLot2.article1, DonneesLot2.article2, DonneesLot2.article3]) {
    s.quand('/suggestion/item/$id', ok, methode: 'DELETE');
  }
  s
    ..quand('/common/rayons', ReponseFausse.json(DonneesLot2.rayons()), methode: 'GET')
    ..quand('/common/grossiste', ReponseFausse.json(DonneesLot2.grossistes()), methode: 'GET')
    ..quand('/common/users', ReponseFausse.json(DonneesLot2.utilisateurs()), methode: 'GET')
    ..quand('/groupegrossiste', ReponseFausse.json(DonneesLot2.groupes()), methode: 'GET')
    ..route('/fichearticle/comparaison', DonneesLot2.comparaison, methode: 'GET')
    ..route('/etat-control-bon/list', DonneesLot2.listeBons, methode: 'GET')
    ..quand('/etat-control-bon/list-annuelle', ReponseFausse.json(DonneesFictives.etatControleAchat()), methode: 'GET')
    ..quand('/grossiste/all', ReponseFausse.json(DonneesLot2.fournisseurs()), methode: 'GET')
    ..quand('/produit/retours-data', ReponseFausse.json(DonneesLot2.retours()), methode: 'GET')
    ..quand('/retourfournisseur/retours-items', ReponseFausse.json(DonneesLot2.detailsRetour()), methode: 'GET')
    ..quand('/avoirs-fournisseurs', ReponseFausse.json(DonneesLot2.produitsRetournes()), methode: 'GET')
    ..route('/valorisation/all', DonneesLot2.valorisations, methode: 'GET')
    ..quand('/common/type-ajustements', ReponseFausse.json(DonneesLot2.typesAjustement()), methode: 'GET')
    ..quand('/ajustement', ReponseFausse.json(DonneesLot2.ajustements()), methode: 'GET')
    ..quand('/ajustement/items', ReponseFausse.json(DonneesLot2.produitsAjustement()), methode: 'GET');
}
