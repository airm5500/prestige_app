// lib/nouvelle_interface/vague2/donnees_vague2.dart
// Vague 2 des nouveaux menus du pharmacien (LECTURE SEULE) : modèles et appels au serveur Prestige.
// Routes EXISTANTES du serveur (branche claude/new-session-xm8ptu), toutes en GET :
//  - Prévisions (web « analysecommande », droit P_SM_ANALYSE_COMMANDE vérifié par le serveur) :
//    /analyse-commande/tableau, /analyse-commande/previsions?filtre=&methode=&stock=&query=&start=&limit=25,
//    /analyse-commande/produit/{id}, /analyse-commande/equivalents/{id}, /analyse-commande/a-analyser,
//    /analyse-commande/analyse?type=SUGGESTION|COMMANDE&id=, /analyse-commande/demande?mois=12|24|36&query=&rayonId= ;
//  - Pilotage (web « pilotage », droit P_SM_PILOTAGE vérifié par le serveur) : /pilotage/axes,
//    /pilotage/onglet/synthese|asuivre?axe=&dtStart=&dtEnd=, et /pilotage/controler (écrit en base : seulement sur
//    le bouton « Contrôler les chiffres », après confirmation) ;
//  - Analyse de garde (web « gardemanager », session seulement) : /gardes/annees, /gardes?annee=,
//    /gardes/{id}/rapport?heures=&tri=&classe=&start=&limit=100, /gardes/{id}/vendeurs ;
//  - CA emplacement / famille (web « cazonegeomanager », session seulement) : /ca-zone-geo et /ca-zone-geo/detail.
// JAMAIS appelées depuis le mobile (écritures ou calculs lourds) : [routesInterditesVague2].
// Lecture TOLÉRANTE (outils de la vague 1) ; « success:false » : droit manquant si le message parle d'accès / de
// droit (ou s'il est vide), erreur du serveur s'il dit que le calcul a échoué, sinon demande refusée avec le
// message du serveur. Délais bornés : [ApiVague2.delaiNormal] (45 s) ou [ApiVague2.delaiLong] (2 min) pour les
// calculs longs demandés explicitement (3 ans, 24 / 36 mois, contrôle du pilotage).
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/date_formatter.dart';
import '../modules/periode.dart' show ControlePeriode;
import '../vague1/donnees_vague1.dart';

export '../vague1/donnees_vague1.dart'
    show OptionListe, PageResultats, entierTolerant, decimalTolerant, texteTolerant, booleenTolerant, grouperMilliers, estMessageDeDroit;

// ---------------------------------------------------------------------------------------------------------------
// Appels et lecture des réponses
// ---------------------------------------------------------------------------------------------------------------

/// Routes que le mobile n'appelle JAMAIS (écritures, recalculs, créations), quelle que soit la méthode.
/// Contrôlé avant chaque appel ([ApiVague2.get]) et vérifié par les tests contre le faux serveur.
const routesInterditesVague2 = <String>[
  '/analyse-commande/analyse/appliquer',
  '/analyse-commande/previsions/suggestion',
  '/analyse-commande/previsions/inventaire',
  '/analyse-commande/recalculer',
  '/analyse-commande/parametres',
  '/pilotage/recalculer',
  '/pilotage/charges',
  '/ca-zone-geo/detail/inventaire',
  '/gardes/supprimer',
];

/// Une route est-elle interdite au mobile ? (y compris /gardes/{id}/inventaire et /gardes/{id}/suggestion).
bool routeInterditeVague2(String route) {
  final r = route.split('?').first;
  if (routesInterditesVague2.any((i) => r == i || r.startsWith('$i/'))) return true;
  return RegExp(r'^/gardes/[^/]+/(inventaire|suggestion)$').hasMatch(r);
}

Map<String, dynamic> _carte(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _liste(Object? v) => v is List ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)] : const [];

/// Nombre décimal facultatif (null si absent, vide ou « null »).
double? decimalOuNull(Object? v) {
  if (v == null) return null;
  if (v is String && (v.trim().isEmpty || v.trim() == 'null')) return null;
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) {
    final n = double.tryParse(v.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.'));
    return n == null || !n.isFinite ? null : n;
  }
  return null;
}

int? entierOuNull(Object? v) {
  final d = decimalOuNull(v);
  return d?.round();
}

/// Mots d'un message du serveur qui signalent un calcul en échec.
bool _estEchecDeCalcul(String m) {
  final t = m.toLowerCase();
  return t.contains('pas pu') || t.contains('échou') || t.contains('echou') || t.contains('erreur');
}

/// « Droit manquant : consulter les prévisions. (message du serveur) Demandez l'accès à l'administrateur. »
String messageDroitVague2(String quoi, [String serveur = '']) =>
    'Droit manquant : consulter $quoi.${serveur.isEmpty ? '' : ' ($serveur)'} Demandez l\'accès à l\'administrateur.';

/// Contrôle d'une réponse de la vague 2. [quoi] : « les prévisions », « le pilotage »…
Map<String, dynamic> lireReponseVague2(dynamic r, String quoi) {
  if (r == null) return <String, dynamic>{};
  if (r is! Map) throw ApiLoadException('Réponse inattendue du serveur pour $quoi.', nature: NatureErreur.reponse);
  final m = Map<String, dynamic>.from(r);
  final message = texteTolerant(m['msg'] ?? m['message']);
  if (booleenTolerant(m['interdit'])) throw ApiLoadException(messageDroitVague2(quoi, message), nature: NatureErreur.droit);
  if (m['success'] == false) {
    if (booleenTolerant(m['erreur'])) {
      throw ApiLoadException('Le serveur n\'a pas pu calculer $quoi. Réessayez dans un instant.', nature: NatureErreur.serveur);
    }
    if (message.isEmpty || estMessageDeDroit(message)) {
      throw ApiLoadException(messageDroitVague2(quoi, message), nature: NatureErreur.droit);
    }
    if (_estEchecDeCalcul(message)) {
      throw ApiLoadException('$message Réessayez dans un instant.', nature: NatureErreur.serveur);
    }
    throw ApiLoadException(message, nature: NatureErreur.refus);
  }
  return m;
}

/// Liste `data` d'une réponse (absente : vide ; autre chose qu'une liste : réponse illisible).
List<Map<String, dynamic>> donneesListe(Map<String, dynamic> j, String quoi, {String cle = 'data'}) {
  final d = j[cle] ?? (cle == 'data' ? j['results'] : null);
  if (d == null) return const [];
  if (d is! List) throw ApiLoadException('Réponse inattendue du serveur pour $quoi.', nature: NatureErreur.reponse);
  return _liste(d);
}

class ApiVague2 {
  ApiVague2._();

  static const delaiNormal = ApiService.delaiGet;

  /// Calculs longs demandés explicitement : plus long, mais borné.
  static const delaiLong = Duration(minutes: 2);

  /// GET contrôlé : route interdite → refus SANS requête ; 403 → « Droit manquant » ; le reste comme ApiService.
  static Future<Map<String, dynamic>> get(BuildContext context, String route, Map<String, String> parametres, String quoi,
      {Duration? delai}) async {
    if (routeInterditeVague2(route)) {
      throw const ApiLoadException('Action non disponible sur le mobile.', nature: NatureErreur.refus);
    }
    try {
      final r = await ApiService().get(context, route, queryParams: parametres, delai: delai ?? delaiNormal);
      return lireReponseVague2(r, quoi);
    } on ApiLoadException catch (e) {
      if (e.nature == NatureErreur.droit && !e.message.startsWith('Droit manquant')) {
        throw ApiLoadException(messageDroitVague2(quoi), nature: NatureErreur.droit, code: e.code);
      }
      rethrow;
    }
  }

  static T lire<T>(T Function() f, String quoi) {
    try {
      return f();
    } on ApiLoadException {
      rethrow;
    } catch (_) {
      throw ApiLoadException('Données illisibles pour $quoi.', nature: NatureErreur.reponse);
    }
  }

  /// Listes des filtres (emplacements, familles, grossistes) : mêmes routes que la Valorisation.
  static Future<List<OptionListe>> options(BuildContext context, String route, String quoi) async {
    if (routeInterditeVague2(route)) throw const ApiLoadException('Action non disponible sur le mobile.', nature: NatureErreur.refus);
    final r = await ApiService().get(context, route, queryParams: {'limit': '9999', 'page': '1', 'start': '0'});
    if (r is Map) lireReponseVague2(r, quoi);
    return lireOptions(r);
  }

  static const routeRayons = '/common/rayons';
  static const routeFamilles = '/common/famillearticles';
  static const routeGrossistes = '/common/grossiste';
}

/// « 2026-10-12 » → « 12/10/2026 » (autre format rendu tel quel, vide → « — »).
String dateApiLisible(String s) => dateLisibleApi(s);

/// « 12,5 % » ; « — » si null.
String pourcentTexte(double? v, {int decimales = 1}) => v == null ? '—' : '${v.toStringAsFixed(decimales).replaceAll('.', ',')} %';

/// « +12,5 % » / « −3,0 % » ; « — » si null.
String variationTexte(double? v) {
  if (v == null) return '—';
  final s = v.abs().toStringAsFixed(1).replaceAll('.', ',');
  return v > 0 ? '+$s %' : (v < 0 ? '−$s %' : '0,0 %');
}

/// Nombre décimal lisible (« 12,5 », « 3 »).
String decimalTexte(double v, {int decimales = 1}) {
  if (v == v.roundToDouble()) return grouperMilliers(v);
  var t = v.toStringAsFixed(decimales);
  if (t.contains('.')) t = t.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return t.replaceAll('.', ',');
}

// ---------------------------------------------------------------------------------------------------------------
// Prévisions
// ---------------------------------------------------------------------------------------------------------------

/// Filtre principal de l'onglet Prévisions (paramètre « filtre »).
enum FiltrePrevision {
  tous('', 'Tous'),
  aCommander('ACOMMANDER', 'À commander'),
  rupture('RUPTURE', 'En rupture'),
  surstock('SURSTOCK', 'Surstock'),
  lente('LENTE', 'Rotation lente'),
  peuFiable('PEU_FIABLE', 'Peu fiables');

  final String code;
  final String libelle;
  const FiltrePrevision(this.code, this.libelle);
}

/// Méthode de prévision (paramètre « methode »).
enum MethodePrevision {
  toutes('', 'Toutes'),
  moyenne('MOYENNE', 'Moyenne 3 mois'),
  saison('SAISON', 'Saisonnière'),
  holt('HOLT', 'Tendance (Holt)'),
  holtWinters('HOLT_WINTERS', 'Tendance + saison');

  final String code;
  final String libelle;
  const MethodePrevision(this.code, this.libelle);

  static String libelleDe(String code) =>
      MethodePrevision.values.where((m) => m.code.isNotEmpty && m.code == code.trim().toUpperCase()).firstOrNull?.libelle ??
      (code.trim().isEmpty ? '—' : code.trim());
}

/// État du stock (paramètre « stock »).
enum StockPrevision {
  tous('', 'Tous'),
  rupture('RUPTURE', 'En rupture'),
  enStock('EN_STOCK', 'En stock'),
  surstock('SURSTOCK', 'Surstock');

  final String code;
  final String libelle;
  const StockPrevision(this.code, this.libelle);
}

class FiltresPrevisions {
  final FiltrePrevision filtre;
  final MethodePrevision methode;
  final StockPrevision stock;
  final String recherche;
  const FiltresPrevisions({this.filtre = FiltrePrevision.tous, this.methode = MethodePrevision.toutes, this.stock = StockPrevision.tous, this.recherche = ''});

  FiltresPrevisions copie({FiltrePrevision? filtre, MethodePrevision? methode, StockPrevision? stock, String? recherche}) => FiltresPrevisions(
        filtre: filtre ?? this.filtre,
        methode: methode ?? this.methode,
        stock: stock ?? this.stock,
        recherche: recherche ?? this.recherche,
      );

  /// Nombre de filtres de la feuille actifs (méthode, stock).
  int get actifs => (methode == MethodePrevision.toutes ? 0 : 1) + (stock == StockPrevision.tous ? 0 : 1);

  Map<String, String> parametres(int start, int limit) => {
        'filtre': filtre.code,
        'query': recherche.trim(),
        'methode': methode.code,
        'stock': stock.code,
        'start': '$start',
        'limit': '$limit',
      };
}

/// Synthèse du dernier calcul (GET /analyse-commande/tableau).
class TableauPrevisions {
  final bool calcule;
  final String dernierCalcul;

  /// Heure (« jj/mm/aaaa hh:mm ») de la dernière mise à jour des quantités « en cours de commande » par le serveur
  /// (champ « enCoursAJour », serveurs récents, demande 23) ; vide si absent.
  final String enCoursAJour;
  final int produits;
  final int produitsVendus;
  final double tauxRupture;
  final int ruptures;
  final int valeurInvendus;
  final int invendus;
  final int? couvertureMoyenne;
  final int? fiabilite;
  final int aCommander;
  final int valeurACommander;
  final int surstock;
  final int joursLente;
  final int joursSurstock;
  final List<(String methode, int produits, int fiabilite)> methodes;

  const TableauPrevisions({
    required this.calcule,
    this.dernierCalcul = '',
    this.enCoursAJour = '',
    this.produits = 0,
    this.produitsVendus = 0,
    this.tauxRupture = 0,
    this.ruptures = 0,
    this.valeurInvendus = 0,
    this.invendus = 0,
    this.couvertureMoyenne,
    this.fiabilite,
    this.aCommander = 0,
    this.valeurACommander = 0,
    this.surstock = 0,
    this.joursLente = 0,
    this.joursSurstock = 0,
    this.methodes = const [],
  });

  factory TableauPrevisions.depuis(Map<String, dynamic> j) => TableauPrevisions(
        // « calcule » absent : on regarde s'il y a des chiffres.
        calcule: booleenTolerant(j['calcule'], defaut: j.containsKey('produits')),
        dernierCalcul: texteTolerant(j['dernierCalcul']),
        enCoursAJour: texteTolerant(j['enCoursAJour']),
        produits: entierTolerant(j['produits']),
        produitsVendus: entierTolerant(j['produitsVendus']),
        tauxRupture: decimalTolerant(j['tauxRupture']),
        ruptures: entierTolerant(j['ruptures']),
        valeurInvendus: entierTolerant(j['valeurInvendus']),
        invendus: entierTolerant(j['invendus']),
        couvertureMoyenne: entierOuNull(j['couvertureMoyenne']),
        fiabilite: entierOuNull(j['fiabilite']),
        aCommander: entierTolerant(j['aCommander']),
        valeurACommander: entierTolerant(j['valeurACommander']),
        surstock: entierTolerant(j['surstock']),
        joursLente: entierTolerant(j['joursLente']),
        joursSurstock: entierTolerant(j['joursSurstock']),
        methodes: [
          for (final m in _liste(j['methodes'])) (texteTolerant(m['methode']), entierTolerant(m['produits']), entierTolerant(m['fiabilite'])),
        ],
      );
}

/// Ligne de l'onglet Prévisions (GET /analyse-commande/previsions, et en-tête du détail produit).
class LignePrevision {
  final String id;
  final String cip;
  final String nom;
  final String grossiste;
  final String methode;
  final int fiabilite;
  final int ventes12;
  final double prevuMois;
  final int stock;
  final int enCours;
  final int equivalents;
  final int? couverture;
  final int delai;
  final int recommande;
  final int paf;
  final int valeur;
  final String derniereVente;

  const LignePrevision({
    required this.id,
    required this.cip,
    required this.nom,
    this.grossiste = '',
    this.methode = '',
    this.fiabilite = 0,
    this.ventes12 = 0,
    this.prevuMois = 0,
    this.stock = 0,
    this.enCours = 0,
    this.equivalents = 0,
    this.couverture,
    this.delai = 0,
    this.recommande = 0,
    this.paf = 0,
    this.valeur = 0,
    this.derniereVente = '',
  });

  factory LignePrevision.depuis(Map<String, dynamic> j) => LignePrevision(
        id: texteTolerant(j['id']),
        cip: texteTolerant(j['cip']),
        nom: texteTolerant(j['nom']),
        grossiste: texteTolerant(j['grossiste']),
        methode: texteTolerant(j['methode']),
        fiabilite: entierTolerant(j['fiabilite']),
        ventes12: entierTolerant(j['ventes12']),
        prevuMois: decimalTolerant(j['prevuMois']),
        stock: entierTolerant(j['stock']),
        enCours: entierTolerant(j['enCours']),
        equivalents: entierTolerant(j['equivalents']),
        couverture: entierOuNull(j['couverture']),
        delai: entierTolerant(j['delai']),
        recommande: entierTolerant(j['recommande']),
        paf: entierTolerant(j['paf']),
        valeur: j.containsKey('valeur') ? entierTolerant(j['valeur']) : entierTolerant(j['recommande']) * entierTolerant(j['paf']),
        derniereVente: texteTolerant(j['derniereVente']),
      );

  String get methodeLibelle => MethodePrevision.libelleDe(methode);

  /// « 12 j » ; « — » si inconnue.
  String get couvertureTexte => couverture == null ? '—' : '${grouperMilliers(couverture!)} j';
}

/// Détail d'un produit (GET /analyse-commande/produit/{id}).
class DetailPrevision {
  final LignePrevision ligne;
  final List<(String mois, int ventes)> historique;
  final String prochainMois;
  final List<(String methode, double erreur, bool retenue)> methodes;
  final double parJour;
  final int delai;
  final int couvertureVoulue;
  final double besoin;
  final double securite;
  final String delaiOrigine;
  final int? rayon;
  final int? reserve;
  final int? derniereVenteQte;

  const DetailPrevision({
    required this.ligne,
    this.historique = const [],
    this.prochainMois = '',
    this.methodes = const [],
    this.parJour = 0,
    this.delai = 0,
    this.couvertureVoulue = 0,
    this.besoin = 0,
    this.securite = 0,
    this.delaiOrigine = '',
    this.rayon,
    this.reserve,
    this.derniereVenteQte,
  });

  factory DetailPrevision.depuis(Map<String, dynamic> j) {
    final c = _carte(j['calcul']);
    return DetailPrevision(
      ligne: LignePrevision.depuis(j),
      historique: [for (final m in _liste(j['mois'])) (texteTolerant(m['mois']), entierTolerant(m['ventes']))],
      prochainMois: texteTolerant(j['prochainMois']),
      methodes: [
        for (final m in _liste(j['methodes'])) (texteTolerant(m['methode']), decimalTolerant(m['erreur']), booleenTolerant(m['retenue'])),
      ],
      parJour: decimalTolerant(c['parJour']),
      delai: entierTolerant(c['delai'] ?? j['delai']),
      couvertureVoulue: entierTolerant(c['couvertureVoulue']),
      besoin: decimalTolerant(c['besoin']),
      securite: decimalTolerant(c['securite']),
      delaiOrigine: texteTolerant(j['delaiOrigine']),
      rayon: entierOuNull(j['rayon']),
      reserve: entierOuNull(j['reserve']),
      derniereVenteQte: entierOuNull(j['derniereVenteQte']),
    );
  }
}

/// Équivalent d'un produit (GET /analyse-commande/equivalents/{id}).
class EquivalentProduit {
  final String id;
  final String nom;
  final String cip;
  final int prix;
  final int rayon;
  final int reserve;
  final bool direct;
  final String raison;
  const EquivalentProduit(this.id, this.nom, this.cip, this.prix, this.rayon, this.reserve, this.direct, this.raison);

  factory EquivalentProduit.depuis(Map<String, dynamic> j) => EquivalentProduit(
        texteTolerant(j['id']),
        texteTolerant(j['nom']),
        texteTolerant(j['cip']),
        entierTolerant(j['prix']),
        entierTolerant(j['rayon'] ?? j['stock']),
        entierTolerant(j['reserve']),
        texteTolerant(j['niveau']).toUpperCase() == 'DIRECT',
        texteTolerant(j['raison']),
      );
}

class Equivalents {
  final List<EquivalentProduit> lignes;
  final String message;
  final String avertissement;
  const Equivalents(this.lignes, {this.message = '', this.avertissement = ''});
}

/// Suggestion ou commande proposée à l'analyse (GET /analyse-commande/a-analyser).
class ElementAAnalyser {
  final String type;
  final String id;
  final String ref;
  final String grossiste;
  final String date;
  final String statut;
  final int lignes;
  const ElementAAnalyser(this.type, this.id, this.ref, this.grossiste, this.date, this.statut, this.lignes);

  factory ElementAAnalyser.depuis(Map<String, dynamic> j) => ElementAAnalyser(
        texteTolerant(j['type']).toUpperCase(),
        texteTolerant(j['id']),
        texteTolerant(j['ref']),
        texteTolerant(j['grossiste']),
        texteTolerant(j['date']),
        texteTolerant(j['statut']),
        entierTolerant(j['lignes']),
      );

  bool get commande => type == 'COMMANDE';
  String get typeLibelle => commande ? 'Commande' : 'Suggestion';
}

/// Ligne analysée d'une suggestion ou d'une commande.
class LigneAnalysee {
  final String cip;
  final String nom;
  final int quantite;
  final int recommande;
  final int ecart;
  final double prevuMois;
  final int stock;
  final int enCours;
  final int? couverture;
  final int prix;
  final int dernierPrix;
  final List<(String texte, bool grave)> alertes;
  const LigneAnalysee({
    required this.cip,
    required this.nom,
    this.quantite = 0,
    this.recommande = 0,
    this.ecart = 0,
    this.prevuMois = 0,
    this.stock = 0,
    this.enCours = 0,
    this.couverture,
    this.prix = 0,
    this.dernierPrix = 0,
    this.alertes = const [],
  });

  factory LigneAnalysee.depuis(Map<String, dynamic> j) {
    final q = entierTolerant(j['quantite']), r = entierTolerant(j['recommande']);
    return LigneAnalysee(
      cip: texteTolerant(j['cip']),
      nom: texteTolerant(j['nom']),
      quantite: q,
      recommande: r,
      ecart: j.containsKey('ecart') ? entierTolerant(j['ecart']) : q - r,
      prevuMois: decimalTolerant(j['prevuMois']),
      stock: entierTolerant(j['stock']),
      enCours: entierTolerant(j['enCours']),
      couverture: entierOuNull(j['couverture']),
      prix: entierTolerant(j['prix']),
      dernierPrix: entierTolerant(j['dernierPrix']),
      alertes: [
        for (final a in j['alertes'] is List ? j['alertes'] as List : const [])
          if (a is Map)
            (texteTolerant(a['texte']), booleenTolerant(a['grave']))
          else if (a is String && a.trim().isNotEmpty)
            (a.trim(), false),
      ],
    );
  }

  bool get grave => alertes.any((a) => a.$2);
}

/// Analyse d'une suggestion / commande (GET /analyse-commande/analyse).
class AnalyseSuggestion {
  final String type;
  final String ref;
  final String grossiste;
  final String statut;
  final int nombreLignes;
  final int lignesAlerte;
  final int valeurProposee;
  final int valeurRecommandee;
  final bool calcule;
  final List<LigneAnalysee> lignes;
  const AnalyseSuggestion({
    this.type = '',
    this.ref = '',
    this.grossiste = '',
    this.statut = '',
    this.nombreLignes = 0,
    this.lignesAlerte = 0,
    this.valeurProposee = 0,
    this.valeurRecommandee = 0,
    this.calcule = true,
    this.lignes = const [],
  });

  factory AnalyseSuggestion.depuis(Map<String, dynamic> j) {
    final r = _carte(j['resume']);
    final lignes = [for (final l in _liste(j['data'])) LigneAnalysee.depuis(l)];
    return AnalyseSuggestion(
      type: texteTolerant(j['type']).toUpperCase(),
      ref: texteTolerant(j['ref']),
      grossiste: texteTolerant(j['grossiste']),
      statut: texteTolerant(j['statut']),
      nombreLignes: r.containsKey('lignes') ? entierTolerant(r['lignes']) : lignes.length,
      lignesAlerte: r.containsKey('lignesAlerte') ? entierTolerant(r['lignesAlerte']) : lignes.where((l) => l.alertes.isNotEmpty).length,
      valeurProposee: entierTolerant(r['valeurProposee']),
      valeurRecommandee: entierTolerant(r['valeurRecommandee']),
      calcule: booleenTolerant(j['calcule'], defaut: true),
      lignes: lignes,
    );
  }
}

/// Durées proposées pour l'analyse de la demande (mois).
const moisDemande = [12, 24, 36];

/// Noms courts des mois (indices 0..11).
const nomsMois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
const nomsMoisLongs = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];

/// Nom du mois [n] (1..12), « — » sinon.
String nomMois(int? n) => n == null || n < 1 || n > 12 ? '—' : nomsMoisLongs[n - 1];

class AnneeDemande {
  final int annee;

  /// Unités vendues par mois (null : mois hors de la fenêtre).
  final List<int?> mois;
  final int total;
  const AnneeDemande(this.annee, this.mois, this.total);
}

class ProduitSaisonnier {
  final String id;
  final String cip;
  final String libelle;
  final int unites;
  final double force;
  final int pic;
  final double indicePic;
  final bool anticiper;
  const ProduitSaisonnier(this.id, this.cip, this.libelle, this.unites, this.force, this.pic, this.indicePic, this.anticiper);

  factory ProduitSaisonnier.depuis(Map<String, dynamic> j) => ProduitSaisonnier(
        texteTolerant(j['id']),
        texteTolerant(j['cip']),
        texteTolerant(j['libelle']),
        entierTolerant(j['unites']),
        decimalTolerant(j['force']),
        entierTolerant(j['pic']),
        decimalTolerant(j['indicePic']),
        booleenTolerant(j['anticiper']),
      );
}

/// Analyse saisonnière de la demande (GET /analyse-commande/demande).
class DemandeSaisonniere {
  final String debut;
  final String fin;
  final int mois;
  final int total;
  final List<AnneeDemande> annees;
  final List<double> indices;
  final int? pic;
  final double force;
  final int? tendanceRecent;
  final int? tendanceAvant;
  final double? tendanceEvolution;
  final List<ProduitSaisonnier> produits;
  final List<ProduitSaisonnier> anticiper;
  final int prochainMois;
  final int produitsClasses;

  const DemandeSaisonniere({
    this.debut = '',
    this.fin = '',
    this.mois = 12,
    this.total = 0,
    this.annees = const [],
    this.indices = const [],
    this.pic,
    this.force = 0,
    this.tendanceRecent,
    this.tendanceAvant,
    this.tendanceEvolution,
    this.produits = const [],
    this.anticiper = const [],
    this.prochainMois = 0,
    this.produitsClasses = 0,
  });

  factory DemandeSaisonniere.depuis(Map<String, dynamic> j) {
    final t = _carte(j['tendance']);
    final ind = j['indices'] is List ? [for (final v in j['indices'] as List) decimalTolerant(v)] : <double>[];
    return DemandeSaisonniere(
      debut: texteTolerant(j['debut']),
      fin: texteTolerant(j['fin']),
      mois: entierTolerant(j['mois']),
      total: entierTolerant(j['total']),
      annees: [
        for (final a in _liste(j['annees']))
          AnneeDemande(
            entierTolerant(a['annee']),
            [
              for (var i = 0; i < 12; i++)
                (a['mois'] is List && i < (a['mois'] as List).length) ? entierOuNull((a['mois'] as List)[i]) : null,
            ],
            entierTolerant(a['total']),
          ),
      ],
      indices: [for (var i = 0; i < 12; i++) i < ind.length ? ind[i] : 0],
      pic: entierOuNull(j['pic']),
      force: decimalTolerant(j['force']),
      tendanceRecent: entierOuNull(t['recent']),
      tendanceAvant: entierOuNull(t['avant']),
      tendanceEvolution: decimalOuNull(t['evolution']),
      produits: [for (final p in _liste(j['produits'])) ProduitSaisonnier.depuis(p)],
      anticiper: [for (final p in _liste(j['anticiper'])) ProduitSaisonnier.depuis(p)],
      prochainMois: entierTolerant(j['prochainMois']),
      produitsClasses: entierTolerant(j['produitsClasses']),
    );
  }

  bool get vide => total == 0;
}

class ApiPrevisions {
  ApiPrevisions._();

  static const racine = '/analyse-commande';
  static const routeTableau = '$racine/tableau';
  static const routePrevisions = '$racine/previsions';
  static const routeAAnalyser = '$racine/a-analyser';
  static const routeAnalyse = '$racine/analyse';
  static const routeDemande = '$racine/demande';
  static String routeProduit(String id) => '$racine/produit/${Uri.encodeComponent(id)}';
  static String routeEquivalents(String id) => '$racine/equivalents/${Uri.encodeComponent(id)}';
  static const taillePage = 25;
  static const quoi = 'les prévisions';

  static Future<TableauPrevisions> tableau(BuildContext context) async {
    final j = await ApiVague2.get(context, routeTableau, const {}, quoi);
    return ApiVague2.lire(() => TableauPrevisions.depuis(j), quoi);
  }

  static Future<PageResultats<LignePrevision>> previsions(BuildContext context, FiltresPrevisions f, {int start = 0}) async {
    final j = await ApiVague2.get(context, routePrevisions, f.parametres(start, taillePage), quoi);
    return ApiVague2.lire(() {
      final lignes = [for (final l in donneesListe(j, quoi)) LignePrevision.depuis(l)];
      final total = j.containsKey('total') ? entierTolerant(j['total']) : start + lignes.length;
      return PageResultats(lignes, total < start + lignes.length ? start + lignes.length : total);
    }, quoi);
  }

  static Future<DetailPrevision> produit(BuildContext context, String id) async {
    if (id.trim().isEmpty) throw const ApiLoadException('Produit inconnu.', nature: NatureErreur.refus);
    final j = await ApiVague2.get(context, routeProduit(id), const {}, 'la prévision du produit');
    return ApiVague2.lire(() => DetailPrevision.depuis(j), 'la prévision du produit');
  }

  static Future<Equivalents> equivalents(BuildContext context, String id) async {
    final j = await ApiVague2.get(context, routeEquivalents(id), const {}, 'les équivalents');
    return ApiVague2.lire(
        () => Equivalents([for (final l in donneesListe(j, 'les équivalents')) EquivalentProduit.depuis(l)],
            message: texteTolerant(j['message']), avertissement: texteTolerant(j['avertissement'])),
        'les équivalents');
  }

  static Future<List<ElementAAnalyser>> aAnalyser(BuildContext context) async {
    final j = await ApiVague2.get(context, routeAAnalyser, const {}, 'les suggestions et commandes');
    return ApiVague2.lire(() => [for (final l in donneesListe(j, 'les suggestions et commandes')) ElementAAnalyser.depuis(l)],
        'les suggestions et commandes');
  }

  static Future<AnalyseSuggestion> analyse(BuildContext context, ElementAAnalyser e) async {
    final type = e.commande ? 'COMMANDE' : 'SUGGESTION';
    if (e.id.trim().isEmpty) throw const ApiLoadException('Choisissez une suggestion ou une commande.', nature: NatureErreur.refus);
    final j = await ApiVague2.get(context, routeAnalyse, {'type': type, 'id': e.id.trim()}, 'l\'analyse');
    return ApiVague2.lire(() => AnalyseSuggestion.depuis(j), 'l\'analyse');
  }

  /// Paramètres de l'analyse de la demande, contrôlés (12, 24 ou 36 mois ; recherche ≤ 100 caractères).
  static Map<String, String> parametresDemande(int mois, String recherche, String rayonId) {
    if (!moisDemande.contains(mois)) throw ArgumentError.value(mois, 'mois', '12, 24 ou 36');
    final q = recherche.trim();
    return {'mois': '$mois', 'query': q.length > 100 ? q.substring(0, 100) : q, 'rayonId': rayonId};
  }

  /// Calcul long sur 24 / 36 mois : délai plus long (borné).
  static Duration delaiDemande(int mois) => mois > 12 ? ApiVague2.delaiLong : ApiVague2.delaiNormal;

  static Future<DemandeSaisonniere> demande(BuildContext context, {required int mois, String recherche = '', String rayonId = ''}) async {
    final p = parametresDemande(mois, recherche, rayonId);
    final j = await ApiVague2.get(context, routeDemande, p, 'l\'analyse de la demande', delai: delaiDemande(mois));
    return ApiVague2.lire(() => DemandeSaisonniere.depuis(j), 'l\'analyse de la demande');
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Pilotage
// ---------------------------------------------------------------------------------------------------------------

/// Onglets du pilotage lus sur le mobile.
enum OngletPilotage {
  synthese('synthese', 'Synthèse'),
  aSuivre('asuivre', 'À suivre');

  final String cle;
  final String libelle;
  const OngletPilotage(this.cle, this.libelle);
}

class AxePilotage {
  final String code;
  final String libelle;
  const AxePilotage(this.code, this.libelle);

  bool get personnalise => code == 'PERSO';

  @override
  bool operator ==(Object other) => other is AxePilotage && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Axes du serveur (GET /pilotage/axes), dans cet ordre si la liste ne peut pas être lue.
const axesPilotageParDefaut = <AxePilotage>[
  AxePilotage('MOIS', 'Mois en cours'),
  AxePilotage('VS_M1', 'Vs mois précédent'),
  AxePilotage('VS_N1', 'Vs même mois l\'an dernier'),
  AxePilotage('YTD', 'Cumul annuel vs an dernier'),
  AxePilotage('G12', 'Glissant 12 mois'),
  AxePilotage('PERSO', 'Période personnalisée'),
];

/// Axe choisi, avec ses dates s'il est personnalisé.
class ChoixAxe {
  final AxePilotage axe;
  final DateTime? debut;
  final DateTime? fin;
  const ChoixAxe(this.axe, {this.debut, this.fin});

  Map<String, String> get parametres => {
        'axe': axe.code,
        if (axe.personnalise && debut != null) 'dtStart': DateFormatter.toApiFormat(debut!),
        if (axe.personnalise && fin != null) 'dtEnd': DateFormatter.toApiFormat(fin!),
      };

  @override
  bool operator ==(Object other) => other is ChoixAxe && other.axe == axe && other.debut == debut && other.fin == fin;

  @override
  int get hashCode => Object.hash(axe, debut, fin);
}

/// Sens d'un indicateur : une hausse est-elle une bonne ou une mauvaise nouvelle ?
enum SensIndicateur {
  /// Une hausse est favorable (chiffre d'affaires, marge, ventes…).
  hausseFavorable,

  /// Une hausse est défavorable (ruptures, stock négatif, dormant, crédits, remises, annulations…).
  hausseDefavorable,

  /// Ni l'un ni l'autre (achats, valeur du stock, part tiers payant…) : flèche et texte, sans jugement.
  neutre,
}

/// Sens de chaque tuile de /pilotage/onglet/* (clés « cle » de PilotageService, serveur claude/new-session-xm8ptu).
/// Le web (PilotageManager.js : sens() = hausse / baisse / plat) ne qualifie pas les variations : la table est donc
/// établie ici, indicateur par indicateur. Clé inconnue : neutre (on ne juge pas ce qu'on ne connaît pas).
const sensIndicateurs = <String, SensIndicateur>{
  // Ventes et marge : une hausse est favorable.
  'caTTC': SensIndicateur.hausseFavorable,
  'caHT': SensIndicateur.hausseFavorable,
  'ca': SensIndicateur.hausseFavorable,
  'marge': SensIndicateur.hausseFavorable,
  'tauxMarge': SensIndicateur.hausseFavorable,
  'nbVentes': SensIndicateur.hausseFavorable,
  'panier': SensIndicateur.hausseFavorable,
  'evolPanier': SensIndicateur.hausseFavorable,
  'ratioVA': SensIndicateur.hausseFavorable,
  'ratio': SensIndicateur.hausseFavorable,
  'ecart': SensIndicateur.hausseFavorable, // écart ventes − achats
  'rotation': SensIndicateur.hausseFavorable, // rotation du stock
  'encaisse': SensIndicateur.hausseFavorable,
  'tpRegle': SensIndicateur.hausseFavorable, // tiers payant réglé (créances encaissées)
  // Une hausse est défavorable.
  'tauxRupture': SensIndicateur.hausseDefavorable,
  'ruptures': SensIndicateur.hausseDefavorable,
  'rupturesVendus': SensIndicateur.hausseDefavorable,
  'sousSeuil': SensIndicateur.hausseDefavorable,
  'negatifs': SensIndicateur.hausseDefavorable,
  'dormant': SensIndicateur.hausseDefavorable,
  'peremption': SensIndicateur.hausseDefavorable,
  'margeNegative': SensIndicateur.hausseDefavorable,
  'rateesACommander': SensIndicateur.hausseDefavorable,
  'remises': SensIndicateur.hausseDefavorable,
  'tauxRemise': SensIndicateur.hausseDefavorable,
  'credit': SensIndicateur.hausseDefavorable, // porté à crédit (impayés)
  'annulees': SensIndicateur.hausseDefavorable,
  'sansPrix': SensIndicateur.hausseDefavorable,
  'sansRayon': SensIndicateur.hausseDefavorable,
  'sansSeuil': SensIndicateur.hausseDefavorable,
  // Neutres : dépendent du contexte (acheter plus n'est ni bien ni mal, etc.).
  'achats': SensIndicateur.neutre,
  'achatTTC': SensIndicateur.neutre,
  'achat': SensIndicateur.neutre,
  'nbBons': SensIndicateur.neutre,
  'achatMoyen': SensIndicateur.neutre,
  'coutAchat': SensIndicateur.neutre,
  'tiersPayant': SensIndicateur.neutre,
  'partTiersPayant': SensIndicateur.neutre,
  'tpFacture': SensIndicateur.neutre,
  'valeurAchat': SensIndicateur.neutre,
  'valeurVente': SensIndicateur.neutre,
  'frequentation': SensIndicateur.neutre,
};

SensIndicateur sensIndicateur(String cle) => sensIndicateurs[cle.trim()] ?? SensIndicateur.neutre;

/// Lecture d'une variation : favorable (true), défavorable (false) ou sans jugement (null : neutre, nulle, absente).
bool? variationFavorable(double? variation, SensIndicateur sens) {
  if (variation == null || variation == 0 || sens == SensIndicateur.neutre) return null;
  return (variation > 0) == (sens == SensIndicateur.hausseFavorable);
}

class TuilePilotage {
  final String cle;
  final String libelle;
  final double valeur;
  final String unite;
  final String sousTitre;
  final double? reference;
  final double? variation;
  final String libelleReference;
  final bool alerte;
  const TuilePilotage({
    required this.cle,
    required this.libelle,
    required this.valeur,
    this.unite = '',
    this.sousTitre = '',
    this.reference,
    this.variation,
    this.libelleReference = '',
    this.alerte = false,
  });

  factory TuilePilotage.depuis(Map<String, dynamic> j) => TuilePilotage(
        cle: texteTolerant(j['cle']),
        libelle: texteTolerant(j['libelle']),
        valeur: decimalTolerant(j['valeur']),
        unite: texteTolerant(j['unite']),
        sousTitre: texteTolerant(j['sousTitre']),
        reference: decimalOuNull(j['reference']),
        variation: decimalOuNull(j['variation']),
        libelleReference: texteTolerant(j['libelleReference']),
        alerte: booleenTolerant(j['alerte']),
      );

  /// Valeur avec son unité (« 1 245 300 F », « 32,5 % », « 1,8 »).
  String get valeurTexte => valeurAvecUnite(valeur, unite);
  String? get referenceTexte => reference == null ? null : valeurAvecUnite(reference!, unite);

  SensIndicateur get sens => sensIndicateur(cle);
}

String valeurAvecUnite(double v, String unite) {
  final u = unite.trim();
  if (u.toUpperCase() == 'FCFA' || u.toUpperCase() == 'F') return '${v < 0 ? '-' : ''}${grouperMilliers(v.abs())} F';
  if (u == '%') return pourcentTexte(v);
  final n = decimalTexte(v, decimales: 2);
  return u.isEmpty ? n : '$n $u';
}

class AlertePilotage {
  final String niveau;
  final String texte;
  const AlertePilotage(this.niveau, this.texte);
  bool get critique => niveau == 'critique';
  bool get ok => niveau == 'ok';
}

class ProduitPilotage {
  final String cip;
  final String libelle;
  final int vendus;
  final int? paf;
  final int? prix;
  const ProduitPilotage(this.cip, this.libelle, this.vendus, {this.paf, this.prix});
}

/// Données d'un onglet (GET /pilotage/onglet/{onglet}).
class DonneesPilotage {
  final String axeCode;
  final String periode;
  final String libellePeriode;
  final String explication;
  final String libelleReference;
  final String periodeReference;
  final List<TuilePilotage> tuiles;
  final List<AlertePilotage> alertes;
  final List<ProduitPilotage> ruptures;
  final List<ProduitPilotage> margeNegative;
  const DonneesPilotage({
    this.axeCode = '',
    this.periode = '',
    this.libellePeriode = '',
    this.explication = '',
    this.libelleReference = '',
    this.periodeReference = '',
    this.tuiles = const [],
    this.alertes = const [],
    this.ruptures = const [],
    this.margeNegative = const [],
  });

  factory DonneesPilotage.depuis(Map<String, dynamic> j) {
    final a = _carte(j['axe']);
    return DonneesPilotage(
      axeCode: texteTolerant(a['code']),
      periode: texteTolerant(a['periode']),
      libellePeriode: texteTolerant(a['libelle']),
      explication: texteTolerant(a['explication']),
      libelleReference: texteTolerant(a['libelleReference']),
      periodeReference: texteTolerant(a['periodeReference']),
      tuiles: [for (final t in _liste(j['tuiles'])) TuilePilotage.depuis(t)],
      alertes: [for (final x in _liste(j['alertes'])) AlertePilotage(texteTolerant(x['niveau']).toLowerCase(), texteTolerant(x['texte']))],
      ruptures: [for (final x in _liste(j['ruptures'])) ProduitPilotage(texteTolerant(x['cip']), texteTolerant(x['libelle']), entierTolerant(x['vendus']))],
      margeNegative: [
        for (final x in _liste(j['margeNegative']))
          ProduitPilotage(texteTolerant(x['cip']), texteTolerant(x['libelle']), entierTolerant(x['vendus']),
              paf: entierTolerant(x['paf']), prix: entierTolerant(x['prix'])),
      ],
    );
  }
}

class ApiPilotage {
  ApiPilotage._();

  static const routeAxes = '/pilotage/axes';
  static String routeOnglet(OngletPilotage o) => '/pilotage/onglet/${o.cle}';
  static const routeControler = '/pilotage/controler';
  static const quoi = 'le pilotage';

  /// Motif de refus d'une période personnalisée (dates obligatoires, contrôles communs, 3 ans au plus).
  static String? erreurAxe(ChoixAxe c, DateTime maintenant) {
    if (!c.axe.personnalise) return null;
    if (c.debut == null || c.fin == null) return 'Choisissez les dates de la période.';
    return ControlePeriode.erreur(c.debut!, c.fin!, maintenant);
  }

  static Future<List<AxePilotage>> axes(BuildContext context) async {
    final j = await ApiVague2.get(context, routeAxes, const {}, quoi);
    final l = ApiVague2.lire(
        () => [
              for (final a in donneesListe(j, quoi))
                if (texteTolerant(a['code']).isNotEmpty) AxePilotage(texteTolerant(a['code']), texteTolerant(a['libelle']).isEmpty ? texteTolerant(a['code']) : texteTolerant(a['libelle'])),
            ],
        quoi);
    return l.isEmpty ? axesPilotageParDefaut : l;
  }

  static Future<DonneesPilotage> onglet(BuildContext context, OngletPilotage o, ChoixAxe c, {DateTime? maintenant}) async {
    final e = erreurAxe(c, maintenant ?? DateTime.now());
    if (e != null) throw ApiLoadException(e, nature: NatureErreur.refus);
    final j = await ApiVague2.get(context, routeOnglet(o), c.parametres, quoi);
    return ApiVague2.lire(() => DonneesPilotage.depuis(j), quoi);
  }

  /// Contrôle des chiffres : vérifie et recalcule les mois modifiés (ÉCRIT en base). Appelé SEULEMENT par le bouton
  /// « Contrôler les chiffres », après confirmation. Renvoie le nombre de mois repris.
  static Future<int> controler(BuildContext context, ChoixAxe c, {DateTime? maintenant}) async {
    final e = erreurAxe(c, maintenant ?? DateTime.now());
    if (e != null) throw ApiLoadException(e, nature: NatureErreur.refus);
    final j = await ApiVague2.get(context, routeControler, c.parametres, 'le contrôle des chiffres', delai: ApiVague2.delaiLong);
    return entierTolerant(j['repris']);
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Analyse de garde
// ---------------------------------------------------------------------------------------------------------------

class Garde {
  final String id;
  final String libelle;
  final String dateDebut;
  final String dateFin;
  final int dureeMinutes;
  final String duree;
  const Garde(this.id, this.libelle, this.dateDebut, this.dateFin, this.dureeMinutes, this.duree);

  factory Garde.depuis(Map<String, dynamic> j) {
    final minutes = entierTolerant(j['dureeMinutes']);
    var duree = texteTolerant(j['duree']);
    if (duree.isEmpty && minutes > 0) duree = '${minutes ~/ 60} h${minutes % 60 == 0 ? '' : ' ${(minutes % 60).toString().padLeft(2, '0')}'}';
    return Garde(texteTolerant(j['id']), texteTolerant(j['libelle']), texteTolerant(j['dateDebut']), texteTolerant(j['dateFin']), minutes, duree);
  }

  /// « 2026-09-05 20:00:00 » → « 05/09/2026 20:00 ».
  static String momentLisible(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})').firstMatch(s.trim());
    if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)} ${m.group(4)}:${m.group(5)}';
    return dateLisibleApi(s);
  }

  String get debutLisible => momentLisible(dateDebut);
  String get finLisible => momentLisible(dateFin);
  String get titre => libelle.isEmpty ? 'Garde du $debutLisible' : libelle;
}

class KpiGarde {
  final int ventes;
  final int clients;
  final int montant;
  final int marge;
  final double tauxMarge;
  final int montantParHeure;
  final int caEspeces;
  final int caMobile;
  final int caCheque;
  final int caCarte;
  final int caDiffere;
  final int montantCredit;
  final int rates;
  const KpiGarde({
    this.ventes = 0,
    this.clients = 0,
    this.montant = 0,
    this.marge = 0,
    this.tauxMarge = 0,
    this.montantParHeure = 0,
    this.caEspeces = 0,
    this.caMobile = 0,
    this.caCheque = 0,
    this.caCarte = 0,
    this.caDiffere = 0,
    this.montantCredit = 0,
    this.rates = 0,
  });

  factory KpiGarde.depuis(Map<String, dynamic> j) => KpiGarde(
        ventes: entierTolerant(j['ventes']),
        clients: entierTolerant(j['clients']),
        montant: entierTolerant(j['montant']),
        marge: entierTolerant(j['marge']),
        tauxMarge: decimalTolerant(j['tauxMarge']),
        montantParHeure: entierTolerant(j['montantParHeure']),
        caEspeces: entierTolerant(j['caEspeces']),
        caMobile: entierTolerant(j['caMobile']),
        caCheque: entierTolerant(j['caCheque']),
        caCarte: entierTolerant(j['caCarte']),
        caDiffere: entierTolerant(j['caDiffere']),
        montantCredit: entierTolerant(j['montantCredit']),
        rates: entierTolerant(j['rates']),
      );
}

class TrancheGarde {
  final String libelle;
  final int ventes;
  final int clients;
  final int montant;
  const TrancheGarde(this.libelle, this.ventes, this.clients, this.montant);
}

class ProduitAbc {
  final String classe;
  final String cip;
  final String libelle;
  final int quantite;
  final int montant;
  final int marge;
  final double tauxMarge;
  final double part;
  final int stock;
  const ProduitAbc(this.classe, this.cip, this.libelle, this.quantite, this.montant, this.marge, this.tauxMarge, this.part, this.stock);

  factory ProduitAbc.depuis(Map<String, dynamic> j) => ProduitAbc(
        texteTolerant(j['classe']).toUpperCase(),
        texteTolerant(j['cip']),
        texteTolerant(j['libelle']),
        entierTolerant(j['quantite']),
        entierTolerant(j['montant']),
        entierTolerant(j['marge']),
        decimalTolerant(j['tauxMarge']),
        decimalTolerant(j['part']),
        entierTolerant(j['stock']),
      );
}

class ResumeClasse {
  final String classe;
  final int produits;
  final int montant;
  final double part;
  const ResumeClasse(this.classe, this.produits, this.montant, this.part);
}

/// Rapport d'une garde (GET /gardes/{id}/rapport).
class RapportGarde {
  final Garde? garde;
  final KpiGarde kpi;
  final List<TrancheGarde> tranches;
  final List<ProduitAbc> abc;
  final int totalAbc;
  final int totalFiltre;
  final List<ResumeClasse> resume;
  const RapportGarde({this.garde, this.kpi = const KpiGarde(), this.tranches = const [], this.abc = const [], this.totalAbc = 0, this.totalFiltre = 0, this.resume = const []});

  factory RapportGarde.depuis(Map<String, dynamic> j) {
    final abc = [for (final p in _liste(j['abc'])) ProduitAbc.depuis(p)];
    return RapportGarde(
      garde: j['garde'] is Map ? Garde.depuis(_carte(j['garde'])) : null,
      kpi: KpiGarde.depuis(_carte(j['kpi'] ?? j['indicateurs'])),
      tranches: [
        for (final t in _liste(j['tranches']))
          TrancheGarde(texteTolerant(t['libelle']), entierTolerant(t['ventes']), entierTolerant(t['clients']), entierTolerant(t['montant'])),
      ],
      abc: abc,
      totalAbc: j.containsKey('totalAbc') ? entierTolerant(j['totalAbc']) : abc.length,
      totalFiltre: j.containsKey('totalFiltre') ? entierTolerant(j['totalFiltre']) : abc.length,
      resume: [
        for (final r in _liste(j['resumeAbc']))
          ResumeClasse(texteTolerant(r['classe']), entierTolerant(r['produits']), entierTolerant(r['montant']), decimalTolerant(r['part'])),
      ],
    );
  }
}

class VendeurGarde {
  final String nom;
  final int ventes;
  final int clients;
  final int montant;
  final int marge;
  final double tauxMarge;
  final double part;
  const VendeurGarde(this.nom, this.ventes, this.clients, this.montant, this.marge, this.tauxMarge, this.part);

  factory VendeurGarde.depuis(Map<String, dynamic> j) => VendeurGarde(
        texteTolerant(j['nom']),
        entierTolerant(j['ventes']),
        entierTolerant(j['clients']),
        entierTolerant(j['montant']),
        entierTolerant(j['marge']),
        decimalTolerant(j['tauxMarge']),
        decimalTolerant(j['part']),
      );
}

enum TriGarde {
  montant('montant', 'Montant'),
  quantite('quantite', 'Quantité'),
  marge('marge', 'Marge');

  final String code;
  final String libelle;
  const TriGarde(this.code, this.libelle);
}

class ApiGardes {
  ApiGardes._();

  static const routeGardes = '/gardes';
  static const routeAnnees = '/gardes/annees';
  static String routeRapport(String id) => '/gardes/${Uri.encodeComponent(id)}/rapport';
  static String routeVendeurs(String id) => '/gardes/${Uri.encodeComponent(id)}/vendeurs';
  /// Pages de 100 produits (et non 25) : le serveur recalcule toute l'analyse à chaque page demandée
  /// (GardeRessource : calcul complet puis découpe start / limit) ; moins de pages = moins de recalculs.
  static const taillePage = 100;

  /// Largeurs de tranche horaire proposées (heures).
  static const heuresPossibles = [1, 2, 3, 4];
  static const classes = ['', 'A', 'B', 'C'];

  static Future<List<int>> annees(BuildContext context) async {
    final j = await ApiVague2.get(context, routeAnnees, const {}, 'les gardes');
    final l = ApiVague2.lire(() => [for (final a in donneesListe(j, 'les gardes')) entierTolerant(a['annee'])], 'les gardes');
    return [for (final a in l) if (a >= 2000 && a <= 2100) a]..sort((a, b) => b.compareTo(a));
  }

  static Future<List<Garde>> gardes(BuildContext context, int annee) async {
    if (annee < 2000 || annee > 2100) throw const ApiLoadException('Année incorrecte.', nature: NatureErreur.refus);
    final j = await ApiVague2.get(context, routeGardes, {'annee': '$annee'}, 'les gardes');
    return ApiVague2.lire(() => [for (final g in donneesListe(j, 'les gardes')) Garde.depuis(g)], 'les gardes');
  }

  /// Paramètres du rapport, contrôlés (heures 1 à 4, classe A / B / C ou vide, tri connu).
  static Map<String, String> parametresRapport({int heures = 2, TriGarde tri = TriGarde.montant, String classe = '', int start = 0, int limit = taillePage}) {
    if (!heuresPossibles.contains(heures)) throw ArgumentError.value(heures, 'heures');
    if (!classes.contains(classe)) throw ArgumentError.value(classe, 'classe');
    return {'heures': '$heures', 'tri': tri.code, 'classe': classe, 'start': '${start < 0 ? 0 : start}', 'limit': '${limit.clamp(1, taillePage)}'};
  }

  static Future<RapportGarde> rapport(BuildContext context, String id,
      {int heures = 2, TriGarde tri = TriGarde.montant, String classe = '', int start = 0, int limit = taillePage}) async {
    final j = await ApiVague2.get(
        context, routeRapport(id), parametresRapport(heures: heures, tri: tri, classe: classe, start: start, limit: limit), 'l\'analyse de la garde');
    return ApiVague2.lire(() => RapportGarde.depuis(j), 'l\'analyse de la garde');
  }

  static Future<List<VendeurGarde>> vendeurs(BuildContext context, String id) async {
    final j = await ApiVague2.get(context, routeVendeurs(id), const {}, 'les vendeurs de la garde');
    return ApiVague2.lire(() => [for (final v in donneesListe(j, 'les vendeurs')) VendeurGarde.depuis(v)], 'les vendeurs de la garde');
  }
}

// ---------------------------------------------------------------------------------------------------------------
// CA emplacement / famille
// ---------------------------------------------------------------------------------------------------------------

enum TypePeriodeCa {
  troisSemaines('TROIS_SEMAINES', '3 semaines'),
  troisMois('TROIS_MOIS', '3 mois'),
  sixMois('SIX_MOIS', '6 mois'),
  troisAns('TROIS_ANS', '3 ans'),
  libre('LIBRE', 'Période libre');

  final String code;
  final String libelle;
  const TypePeriodeCa(this.code, this.libelle);
}

enum RegroupementCa {
  zone('ZONE', 'Emplacement'),
  famille('FAMILLE', 'Famille'),
  zoneFamille('ZONE_FAMILLE', 'Emplacement et famille');

  final String code;
  final String libelle;
  const RegroupementCa(this.code, this.libelle);
}

/// Choix multiple d'identifiants (emplacements, familles, grossistes cochés), envoyé comme le web depuis le 13/10 :
/// identifiants séparés par des virgules (serveur : util.FiltreListe, vide ou « ALL » = pas de filtre, 500 au plus).
/// Vide = aucun filtre (« Tous ») ; tout cocher revient aussi à ne pas filtrer (voir [FiltresCa.normaliser]).
String idsSepares(Iterable<String> ids) => {for (final i in ids) if (i.trim().isNotEmpty) i.trim()}.join(',');

class FiltresCa {
  final TypePeriodeCa type;
  final DateTime? debut;
  final DateTime? fin;
  final RegroupementCa regroupement;
  final List<String> zones;
  final List<String> familles;
  final List<String> grossistes;
  const FiltresCa({
    this.type = TypePeriodeCa.troisSemaines,
    this.debut,
    this.fin,
    this.regroupement = RegroupementCa.zone,
    this.zones = const [],
    this.familles = const [],
    this.grossistes = const [],
  });

  FiltresCa copie({TypePeriodeCa? type, DateTime? debut, DateTime? fin, RegroupementCa? regroupement, List<String>? zones, List<String>? familles, List<String>? grossistes}) =>
      FiltresCa(
        type: type ?? this.type,
        debut: debut ?? this.debut,
        fin: fin ?? this.fin,
        regroupement: regroupement ?? this.regroupement,
        zones: zones ?? this.zones,
        familles: familles ?? this.familles,
        grossistes: grossistes ?? this.grossistes,
      );

  /// Paramètres envoyés (« Z1,Z2 »).
  String get zoneId => idsSepares(zones);
  String get familleId => idsSepares(familles);
  String get grossisteId => idsSepares(grossistes);

  /// Choix « tout coché » ramené à « aucun filtre » (même résultat, URL courte, sous la borne de 500 du serveur).
  static List<String> normaliser(List<String> choisis, List<String>? toutes) {
    final c = {for (final i in choisis) if (i.trim().isNotEmpty) i.trim()};
    if (toutes != null && toutes.isNotEmpty && toutes.every(c.contains)) return const [];
    return c.toList();
  }

  /// Calcul long (3 ans, ou période libre de plus d'un an) : délai plus long, indication pendant le chargement.
  bool get long => type == TypePeriodeCa.troisAns || (type == TypePeriodeCa.libre && debut != null && fin != null && fin!.difference(debut!).inDays > 366);

  int get actifs => (zones.isEmpty ? 0 : 1) + (familles.isEmpty ? 0 : 1) + (grossistes.isEmpty ? 0 : 1);

  String? erreur(DateTime maintenant) {
    if (type != TypePeriodeCa.libre) return null;
    if (debut == null || fin == null) return 'Choisissez les dates de la période.';
    return ControlePeriode.erreur(debut!, fin!, maintenant);
  }

  Map<String, String> get parametres => {
        'typePeriode': type.code,
        if (type == TypePeriodeCa.libre) 'dtStart': DateFormatter.toApiFormat(debut!),
        if (type == TypePeriodeCa.libre) 'dtEnd': DateFormatter.toApiFormat(fin!),
        'regroupement': regroupement.code,
        'zoneId': zoneId,
        'familleId': familleId,
        'grossisteId': grossisteId,
      };
}

class TrancheCa {
  final String cle;
  final String libelle;
  final String debut;
  final String fin;
  final bool enCours;
  const TrancheCa(this.cle, this.libelle, {this.debut = '', this.fin = '', this.enCours = false});
}

/// Valeurs d'une ligne pour une tranche (colonnes dynamiques t_<cle>, q_<cle>, e_<cle>).
class ValeurTranche {
  final int montant;
  final int quantite;
  final double? evolution;
  const ValeurTranche(this.montant, this.quantite, this.evolution);
}

class LigneCa {
  final String zoneId;
  final String zone;
  final String familleId;
  final String famille;
  final String libelle;
  final int total;
  final int marge;
  final double? pourcentageMarge;
  final double? evolution;
  final Map<String, ValeurTranche> tranches;
  const LigneCa({
    this.zoneId = '',
    this.zone = '',
    this.familleId = '',
    this.famille = '',
    this.libelle = '',
    this.total = 0,
    this.marge = 0,
    this.pourcentageMarge,
    this.evolution,
    this.tranches = const {},
  });

  factory LigneCa.depuis(Map<String, dynamic> j, List<TrancheCa> tranches) => LigneCa(
        zoneId: texteTolerant(j['zoneId']),
        zone: texteTolerant(j['zone']),
        familleId: texteTolerant(j['familleId']),
        famille: texteTolerant(j['famille']),
        libelle: texteTolerant(j['libelle']),
        total: entierTolerant(j['total']),
        marge: entierTolerant(j['marge']),
        pourcentageMarge: decimalOuNull(j['pourcentageMarge']),
        evolution: decimalOuNull(j['evolution']),
        tranches: {
          for (final t in tranches) t.cle: ValeurTranche(entierTolerant(j['t_${t.cle}']), entierTolerant(j['q_${t.cle}']), decimalOuNull(j['e_${t.cle}'])),
        },
      );

  ValeurTranche de(String cle) => tranches[cle] ?? const ValeurTranche(0, 0, null);

  String titre(RegroupementCa r) {
    final z = zone.isEmpty ? '(sans emplacement)' : zone;
    final f = famille.isEmpty ? '(sans famille)' : famille;
    return switch (r) {
      RegroupementCa.zone => z,
      RegroupementCa.famille => f,
      RegroupementCa.zoneFamille => '$z · $f',
    };
  }
}

/// Comparatif (GET /ca-zone-geo).
class ComparatifCa {
  final List<TrancheCa> tranches;
  final List<LigneCa> lignes;
  final Map<String, int> totauxTranches;
  final Map<String, double?> evolutionsTranches;
  final int totalGeneral;
  final int margeGenerale;
  final double? pourcentageMargeGeneral;
  final double? evolutionGenerale;
  final String debut;
  final String fin;
  final String granularite;
  const ComparatifCa({
    this.tranches = const [],
    this.lignes = const [],
    this.totauxTranches = const {},
    this.evolutionsTranches = const {},
    this.totalGeneral = 0,
    this.margeGenerale = 0,
    this.pourcentageMargeGeneral,
    this.evolutionGenerale,
    this.debut = '',
    this.fin = '',
    this.granularite = '',
  });

  /// Tranches : liste « tranches » du serveur ; absente, déduites des colonnes t_<cle> (ordre des clés).
  static List<TrancheCa> lireTranches(Map<String, dynamic> j, List<Map<String, dynamic>> data) {
    final t = _liste(j['tranches']);
    if (t.isNotEmpty) {
      return [
        for (final x in t)
          if (texteTolerant(x['cle']).isNotEmpty)
            TrancheCa(texteTolerant(x['cle']), texteTolerant(x['libelle']).isEmpty ? texteTolerant(x['cle']) : texteTolerant(x['libelle']),
                debut: texteTolerant(x['debut']), fin: texteTolerant(x['fin']), enCours: booleenTolerant(x['enCours'])),
      ];
    }
    final cles = <String>{};
    for (final l in data) {
      for (final k in l.keys) {
        if (k.startsWith('t_') && k.length > 2) cles.add(k.substring(2));
      }
    }
    return [for (final c in cles.toList()..sort()) TrancheCa(c, c)];
  }

  factory ComparatifCa.depuis(Map<String, dynamic> j) {
    final data = _liste(j['data']);
    final tranches = lireTranches(j, data);
    final lignes = [for (final l in data) LigneCa.depuis(l, tranches)];
    final tt = _carte(j['totauxTranches']), et = _carte(j['evolutionsTranches']);
    return ComparatifCa(
      tranches: tranches,
      lignes: lignes,
      totauxTranches: {
        for (final t in tranches) t.cle: tt.containsKey(t.cle) ? entierTolerant(tt[t.cle]) : lignes.fold(0, (s, l) => s + l.de(t.cle).montant),
      },
      evolutionsTranches: {for (final t in tranches) t.cle: decimalOuNull(et[t.cle])},
      totalGeneral: j.containsKey('totalGeneral') ? entierTolerant(j['totalGeneral']) : lignes.fold(0, (s, l) => s + l.total),
      margeGenerale: entierTolerant(j['margeGenerale']),
      pourcentageMargeGeneral: decimalOuNull(j['pourcentageMargeGeneral']),
      evolutionGenerale: decimalOuNull(j['evolutionGenerale']),
      debut: texteTolerant(j['debut']),
      fin: texteTolerant(j['fin']),
      granularite: texteTolerant(j['granularite']),
    );
  }
}

class ProduitCa {
  final String cip;
  final String designation;
  final int quantite;
  final int montant;
  final int marge;
  final double? pourcentageMarge;
  const ProduitCa(this.cip, this.designation, this.quantite, this.montant, this.marge, this.pourcentageMarge);

  factory ProduitCa.depuis(Map<String, dynamic> j) => ProduitCa(texteTolerant(j['cip']), texteTolerant(j['designation'] ?? j['libelle']),
      entierTolerant(j['quantite']), entierTolerant(j['montant']), entierTolerant(j['marge']), decimalOuNull(j['pourcentageMarge']));
}

class DetailLigneCa {
  final List<ProduitCa> produits;
  final int quantite;
  final int montant;
  final int marge;
  const DetailLigneCa(this.produits, this.quantite, this.montant, this.marge);
}

class ApiCaZone {
  ApiCaZone._();

  static const route = '/ca-zone-geo';
  static const routeDetail = '/ca-zone-geo/detail';
  static const quoi = 'le chiffre d\'affaires par emplacement';

  static Duration delai(FiltresCa f) => f.long ? ApiVague2.delaiLong : ApiVague2.delaiNormal;

  static Future<ComparatifCa> comparatif(BuildContext context, FiltresCa f, {DateTime? maintenant}) async {
    final e = f.erreur(maintenant ?? DateTime.now());
    if (e != null) throw ApiLoadException(e, nature: NatureErreur.refus);
    final j = await ApiVague2.get(context, route, f.parametres, quoi, delai: delai(f));
    return ApiVague2.lire(() => ComparatifCa.depuis(j), quoi);
  }

  static Map<String, String> parametresDetail(FiltresCa f, LigneCa l) => {
        ...f.parametres,
        'ligneZoneId': f.regroupement == RegroupementCa.famille ? '' : l.zoneId,
        'ligneFamilleId': f.regroupement == RegroupementCa.zone ? '' : l.familleId,
      };

  static Future<DetailLigneCa> detail(BuildContext context, FiltresCa f, LigneCa l, {DateTime? maintenant}) async {
    final e = f.erreur(maintenant ?? DateTime.now());
    if (e != null) throw ApiLoadException(e, nature: NatureErreur.refus);
    final j = await ApiVague2.get(context, routeDetail, parametresDetail(f, l), 'le détail de la ligne', delai: delai(f));
    return ApiVague2.lire(() {
      final p = [for (final x in donneesListe(j, 'le détail')) ProduitCa.depuis(x)];
      final t = _carte(j['totaux']);
      return DetailLigneCa(
        p,
        t.containsKey('quantite') ? entierTolerant(t['quantite']) : p.fold(0, (s, x) => s + x.quantite),
        t.containsKey('montant') ? entierTolerant(t['montant']) : p.fold(0, (s, x) => s + x.montant),
        t.containsKey('marge') ? entierTolerant(t['marge']) : p.fold(0, (s, x) => s + x.marge),
      );
    }, 'le détail de la ligne');
  }
}
