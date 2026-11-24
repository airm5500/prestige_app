// Serveur Prestige de DÉMONSTRATION (3.18.0) : le serveur fictif des tests (serveur_fictif.dart, données de
// donnees/) avec toutes les rubriques remplies, servi par un client HTTP en mémoire. AUCUNE requête réseau, aucune
// donnée réelle (ni marque, ni patient, ni client, ni employé), aucune clé ni secret ; rien n'est journalisé.
//
// Dates : les données fictives sont écrites pour une « journée de référence » ([ServeurDemo.reference], mi-octobre
// 2026). Le client de démonstration décale les dates de chaque requête vers cette journée, puis celles de chaque
// réponse vers aujourd'hui ([ServeurDemo.horloge]) : le tableau de bord montre « aujourd'hui », « hier »… quel que soit
// le jour, et les tests (horloge fixe) restent déterministes.
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'donnees/donnees_3_17_1.dart';
import 'donnees/donnees_fictives.dart';
import 'donnees/donnees_lot2.dart';
import 'donnees/donnees_lot4.dart';
import 'serveur_fictif.dart';

/// Article du catalogue de démonstration (noms génériques suivis de « FICTIF » : aucune marque réelle).
class ArticleDemo {
  final String cip;
  final String libelle;
  final int prixVente;
  final int stock;
  final int reserve;
  final double moyenne;
  final String rayon;
  const ArticleDemo(this.cip, this.libelle, this.prixVente, this.stock, this.reserve, this.moyenne, this.rayon);
}

class ServeurDemo extends ServeurFictif {
  /// Journée de référence des données fictives (dernier jour des ventes fictives de donnees/).
  static final reference = DateTime(2026, 10, 14);

  /// Horloge de la démonstration (fixe dans les tests).
  final DateTime Function() horloge;

  ServeurDemo({DateTime Function()? horloge}) : horloge = horloge ?? DateTime.now {
    controlerSession = false; // aucune session à ouvrir : la démonstration est « connectée » d'office
    journaliser = false; // aucune requête (donc aucune recherche) gardée
    installerRoutesDemo();
  }

  static const officine = 'PHARMACIE DE DÉMONSTRATION';
  static const prenom = 'Pharmacien';
  static const nom = 'Démonstration';

  /// Utilisateur de la démonstration (réponse de POST /user/auth) : profil responsable (tous les menus).
  static Map<String, Object?> utilisateur() => {
        ...DonneesFictives.utilisateur(),
        'str_USER_ID': 'USR-DEMO-0001',
        'str_FIRST_NAME': prenom,
        'str_LAST_NAME': nom,
        'str_LOGIN': 'demonstration',
        'OFFICINE': officine,
      };

  static List<Map<String, Object?>> officineDemo() => [
        {'id': 'OFF-DEMO-1', 'fullName': officine, 'nomComplet': officine},
      ];

  /// Catalogue de démonstration : « para » et « doli » trouvent plusieurs produits FICTIFS.
  static const catalogue = <ArticleDemo>[
    ArticleDemo('9992001', 'PARACÉTAMOL FICTIF 500MG CPR B/16', 900, 46, 120, 6.2, 'RAYON A'),
    ArticleDemo('9992002', 'PARACÉTAMOL FICTIF 1000MG CPR B/8', 1100, 31, 60, 4.8, 'RAYON A'),
    ArticleDemo('9992003', 'PARACÉTAMOL FICTIF 2,4% SIROP 100ML', 1650, 12, 24, 1.9, 'RAYON B'),
    ArticleDemo('9992004', 'DOLIFICTIF 500MG GÉLULES B/16', 950, 18, 40, 3.1, 'RAYON A'),
    ArticleDemo('9992005', 'DOLIFICTIF 1000MG CPR B/8', 1200, 4, 0, 2.6, 'RAYON A'),
    ArticleDemo('9992006', 'DOLIFICTIF 150MG SUPPOSITOIRES B/10', 1400, 9, 10, 0.8, 'RAYON C'),
    ArticleDemo('9992007', 'IBUPROFÈNE FICTIF 400MG CPR B/20', 1800, 22, 30, 2.4, 'RAYON A'),
    ArticleDemo('9992008', 'AMOXICILLINE FICTIVE 500MG GÉLULES B/12', 2300, 15, 36, 1.5, 'RAYON B'),
    ArticleDemo('9992009', 'VITAMINE C FICTIVE 500MG CPR À CROQUER B/30', 2100, 27, 0, 1.2, 'RAYON C'),
    ArticleDemo('9992010', 'SÉRUM PHYSIOLOGIQUE FICTIF 5ML B/40', 1500, 0, 48, 3.7, 'RAYON B'),
  ];

  /// Lignes « Analyse Article » (format de GET /info).
  static List<Map<String, Object?>> articlesAnalyse() => [
        for (final (i, a) in catalogue.indexed)
          {
            'produitId': 'PRD-DEMO-${i + 1}', 'codeCip': a.cip, 'libelle': a.libelle, 'prixVente': a.prixVente,
            'prixAchat': (a.prixVente * 0.68).round(), 'moyenne': a.moyenne, 'moyenneJour': (a.moyenne / 30 * 10).round() / 10,
            'quantiteVendue': (a.moyenne * 9).round(), 'stock': a.stock, 'quantiteMois': '${a.moyenne.round()}:${(a.moyenne / 2).round()}',
            'grossiste': i.isEven ? 'GROSSISTE FICTIF' : 'GROSSISTE IMAGINAIRE', 'emplacement': a.rayon,
            'stockReserve': a.reserve, 'seuilReserve': 10, 'seuilMiniRayon': 5,
          },
      ];

  /// Lignes « Fiche Article » (format de GET /checkproduit).
  static List<Map<String, Object?>> produitsFiche() => [
        for (final (i, a) in catalogue.indexed)
          {
            'familleId': 'PRD-DEMO-${i + 1}', 'familleCip': a.cip, 'familleLibelle': a.libelle, 'pachat': (a.prixVente * 0.68).round(),
            'pvente': a.prixVente, 'stock': a.stock, 'emplacement': a.rayon, 'stockReserve': '${a.reserve}', 'seuilReserve': '10',
            'seuilMiniRayon': 5,
          },
      ];

  static String _sansAccents(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  static bool _correspond(String libelle, String cip, String? q) {
    final t = _sansAccents((q ?? '').trim());
    return t.isEmpty || _sansAccents(libelle).contains(t) || cip.contains(t);
  }

  void installerRoutesDemo() {
    // Toutes les rubriques : routes par défaut (vagues 1 à 4), lots 2 à 4, serveur à jour (CA crédit paginé, carte TVA).
    donneesLot2(this);
    donneesLot4(this);
    Donnees3171.installer(this, ServeurOfficine.retour);
    quand('/officine', ReponseFausse.json(officineDemo()), methode: 'GET');
    quand('/user/auth', ReponseFausse.json(utilisateur()), methode: 'POST');
    // Accueil, Rapport d'Activité, Détail CA, crédits, alertes (comme test/support/nouvelle_interface.dart).
    quand('/recap/dashboard', ReponseFausse.json(DonneesFictives.rapportActivite()), methode: 'GET');
    quand('/recap/credits', ReponseFausse.json(DonneesFictives.creditsTiersPayants()), methode: 'GET');
    quand('/recap/credits/totaux', ReponseFausse.json(DonneesFictives.creditsTotaux()), methode: 'GET');
    quand('/recap/reglements', ReponseFausse.json(DonneesFictives.reglementsRecus()), methode: 'GET');
    quand('/ca-all', ReponseFausse.json(DonneesFictives.caParJour()), methode: 'GET');
    quand('/fichearticle/perimes', ReponseFausse.json(DonneesFictives.perimes()), methode: 'GET');
    quand('/etat-control-bon/list-annuelle', ReponseFausse.json(DonneesFictives.etatControleAchat()), methode: 'GET');
    route('/rh/presence', (r) => ReponseFausse.json(DonneesFictives.presenceEquipe(r.parametres['jour'] ?? '2026-10-14')), methode: 'GET');
    // Catalogue de démonstration (Analyse Article, recherche de produit, Fiche Article).
    route('/info', (r) => ReponseFausse.json([
          for (final a in articlesAnalyse())
            if (_correspond('${a['libelle']}', '${a['codeCip']}', r.parametres['search'])) a,
        ]), methode: 'GET');
    route('/espace-produit/recherche', (r) {
      final q = (r.parametres['q'] ?? '').trim();
      if (q.length < 2) return ReponseFausse.json({'total': 0, 'data': const <Object>[]});
      final lignes = [
        for (final a in articlesAnalyse())
          if (_correspond('${a['libelle']}', '${a['codeCip']}', q))
            {
              'cip': a['codeCip'], 'designation': a['libelle'], 'emplacement': a['emplacement'], 'prixVente': a['prixVente'],
              'stockRayon': a['stock'], 'stockReserve': a['stockReserve'],
              'stockTotal': (a['stock'] as int) + (a['stockReserve'] as int), 'id': a['produitId'],
            },
      ];
      return ReponseFausse.json({'total': lignes.length, 'data': lignes});
    }, methode: 'GET');
    route('/checkproduit', (r) => ReponseFausse.json([
          for (final p in produitsFiche())
            if (_correspond('${p['familleLibelle']}', '${p['familleCip']}', r.parametres['nompdt'])) p,
        ]), methode: 'GET');
  }

  // --- Dates ---

  /// Décalage (en jours) entre aujourd'hui et la journée de référence.
  int get decalage {
    final n = horloge();
    return DateTime(n.year, n.month, n.day).difference(reference).inDays;
  }

  static final _iso = RegExp(r'\b(20\d\d)-(\d\d)-(\d\d)');
  static final _fr = RegExp(r'\b(\d\d)/(\d\d)/(20\d\d)\b');
  static final _compacte = RegExp(r'^(20\d\d)(\d\d)(\d\d)$');

  static String _deux(int n) => n.toString().padLeft(2, '0');

  static DateTime? _date(String a, String m, String j) {
    final an = int.parse(a), mois = int.parse(m), jour = int.parse(j);
    if (mois < 1 || mois > 12 || jour < 1 || jour > 31) return null;
    final d = DateTime(an, mois, jour);
    return d.month == mois ? d : null;
  }

  /// Décale de [jours] toutes les dates d'un texte (AAAA-MM-JJ, JJ/MM/AAAA, ou AAAAMMJJ seul).
  static String decalerTexte(String s, int jours) {
    if (jours == 0) return s;
    DateTime plus(DateTime d) => DateTime(d.year, d.month, d.day + jours);
    final c = _compacte.firstMatch(s);
    if (c != null) {
      final d = _date(c[1]!, c[2]!, c[3]!);
      if (d == null) return s;
      final n = plus(d);
      return '${n.year}${_deux(n.month)}${_deux(n.day)}';
    }
    var t = s.replaceAllMapped(_iso, (m) {
      final d = _date(m[1]!, m[2]!, m[3]!);
      if (d == null) return m[0]!;
      final n = plus(d);
      return '${n.year}-${_deux(n.month)}-${_deux(n.day)}';
    });
    t = t.replaceAllMapped(_fr, (m) {
      final d = _date(m[3]!, m[2]!, m[1]!);
      if (d == null) return m[0]!;
      final n = plus(d);
      return '${_deux(n.day)}/${_deux(n.month)}/${n.year}';
    });
    return t;
  }

  /// Décale les dates de toutes les chaînes d'une valeur JSON.
  static Object? decalerJson(Object? v, int jours) {
    if (jours == 0) return v;
    if (v is String) return decalerTexte(v, jours);
    if (v is List) return [for (final e in v) decalerJson(e, jours)];
    if (v is Map) return {for (final e in v.entries) '${e.key}': decalerJson(e.value, jours)};
    return v;
  }

  /// Client HTTP de la démonstration : en mémoire (aucune socket), dates ramenées à la journée de référence à
  /// l'aller et à aujourd'hui au retour.
  http.Client client() => MockClient((req) async {
        final j = decalage;
        final uri = req.url.replace(
            queryParameters: req.url.queryParameters.isEmpty ? null : req.url.queryParameters.map((k, v) => MapEntry(k, decalerTexte(v, -j))));
        var corps = req.body;
        if (corps.isNotEmpty) {
          try {
            corps = jsonEncode(decalerJson(jsonDecode(corps), -j));
          } catch (_) {}
        }
        final r = await repondre(req.method, uri, req.headers['cookie'], corps);
        var octets = r.octets;
        final type = r.entetes['content-type'] ?? '';
        if (type.contains('json') && octets.isNotEmpty) {
          try {
            octets = utf8.encode(jsonEncode(decalerJson(jsonDecode(utf8.decode(octets)), j)));
          } catch (_) {}
        }
        return http.Response.bytes(octets, r.statut,
            headers: r.entetes.map((k, v) => MapEntry(k, v.replaceAll('\n', ', '))), request: req);
      });
}
