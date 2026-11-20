// lib/donnees/analyses_ventes_donnees.dart
// Analyses des ventes, logique COMMUNE aux deux interfaces, pour quatre modules d'origine :
//  - Suivi 20/80 : GET /statfamillearticle/vingtQuatreVingt?dtStart=&dtEnd=&limit=&codeFamile=&codeRayon=
//    &codeGrossiste=&qtyOrCa=false&page=1&start=0 → « data » (nombre d'articles : 1 à 9 999, 50 par défaut) ;
//    nouvelle interface (3.8.0) : classement par chiffre d'affaires (défaut, requête inchangée) ou par QUANTITÉ :
//    le serveur le sait faire (FamilleArticleRessource.vingtQuatreVingt lit « vingtType » = CA / QTY / MARGE ;
//    QTY → procédure analyse_20_80_par_quantite, triée par quantité décroissante) : vingtType=QTY est ajouté, et
//    l'application trie aussi par quantité décroissante (tri stable : sans effet si le serveur l'a fait ; protège
//    d'un serveur plus ancien qui ignorerait vingtType) ;
//    3.8.1 (correction) : le serveur limite le nombre d'articles avec « topN » (FamilleArticleRessource lit topN,
//    Integer ; absent ou ≤ 0 = tous ; appliqué après le classement et les filtres) et IGNORE « limit ». Les deux
//    interfaces envoient donc topN = nombre choisi (limit reste envoyé, inoffensif pour un serveur plus ancien) et
//    l'application ne garde que les N premiers si le serveur en renvoie plus (serveur qui ignorerait topN) ;
//  - Stat TVA : GET /api/v3/tvas?dtStart=&dtEnd=&typeVente= (TOUT, VNO, VO) → « data » ;
//  - Marge Produits Vendus : GET /datareporting/margeproduitsvendus?dtStart=&dtEnd=&limit=9999 → « data », filtre
//    LOCAL sur la marge (%) : =, >, <, >=, <=, !=, ~= (± 1) ;
//  - CA Crédit : GET /ca-credit?dtStart=&dtEnd= → liste, recherche LOCALE (client, ayant droit, N° de facture,
//    tiers payant) ; 3.17.0 (demande serveur 67) : la nouvelle interface ajoute start / limit (+ query, tiersPayant) :
//    un serveur à jour répond par une PAGE { total, montant, clients, tiersPayants, data }, un serveur plus ancien
//    ignore ces paramètres et renvoie la liste (comportement 3.16.0) ;
//  - CA Global : GET /ca-all?dtStart=&dtEnd= → une ligne par jour triée par date, cumul de la période, CA brut et
//    net (brut − remise).
// Aucun de ces écrans n'a d'export.
import 'package:flutter/widgets.dart';

import '../models/ca_comptant_model.dart' show OperateurMobile;
import '../models/ca_credit_model.dart';
import '../models/ca_global_model.dart';
import '../models/marge_produit_vendu_model.dart';
import '../models/stat_tva_model.dart';
import '../models/suivi_20_80_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';
import '../utils/saisie.dart';
import 'detail_ca_donnees.dart' show DetailCa;

Map<String, String> _dates(DateTime debut, DateTime fin) => {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin)};

// -----------------------------------------------------------------------------------------------------------------
// Suivi 20/80
// -----------------------------------------------------------------------------------------------------------------

/// Critère de classement du Suivi 20/80 (nouvelle interface, 3.8.0).
enum CritereVingt {
  chiffreAffaires('Chiffre d\'affaires'),
  quantite('Quantité');

  final String libelle;
  const CritereVingt(this.libelle);
}

class Suivi2080Donnees {
  Suivi2080Donnees._();

  /// Nombre d'articles par défaut (champ vide ou hors bornes).
  static const limiteParDefaut = 50;

  /// « Tous » (nouvelle interface, 3.9.0) : aucun « topN » envoyé (absent = tous les articles pour le serveur).
  static const tous = 0;

  /// Nombre d'articles demandé : entier de 1 à 9 999, sinon 50 (comme l'écran d'origine pour un champ vide).
  static int limite(String? texte) => Saisie.entier(texte, min: 1, max: Saisie.maxLignes) ?? limiteParDefaut;

  /// [critere] quantité : « vingtType=QTY » en plus ; chiffre d'affaires : la requête d'origine. « topN » (3.8.1) :
  /// le paramètre que le serveur lit vraiment ; « limit » (ignoré par le serveur) est gardé tel quel.
  /// [limite] = [tous] (3.9.0) : « topN » ABSENT (= tous pour le serveur) et « limit » à 9 999 (comme l'ancien
  /// « tous » : inoffensif, le serveur l'ignore).
  static Map<String, String> parametres(DateTime debut, DateTime fin, int limite, {CritereVingt critere = CritereVingt.chiffreAffaires}) => {
        ..._dates(debut, fin),
        'limit': (limite > 0 ? limite : Saisie.maxLignes).toString(),
        if (limite > 0) 'topN': limite.toString(),
        'codeFamile': '',
        'codeRayon': '',
        'codeGrossiste': '',
        'qtyOrCa': 'false',
        'page': '1',
        'start': '0',
        if (critere == CritereVingt.quantite) 'vingtType': 'QTY',
      };

  /// Articles dans l'ordre du classement : chiffre d'affaires = ordre du serveur (comme l'origine) ; quantité = tri
  /// stable par quantité vendue décroissante (à égalité, l'ordre du serveur).
  static List<Suivi2080> classer(List<Suivi2080> l, CritereVingt critere) {
    if (critere == CritereVingt.chiffreAffaires) return l;
    final indices = [for (var i = 0; i < l.length; i++) i]
      ..sort((a, b) {
        final c = l[b].quantiteVendue.compareTo(l[a].quantiteVendue);
        return c != 0 ? c : a.compareTo(b);
      });
    return [for (final i in indices) l[i]];
  }

  static List<Suivi2080>? lire(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((item) => Suivi2080.fromJson(item)).toList() : null;

  static Future<List<Suivi2080>?> charger(BuildContext context, DateTime debut, DateTime fin, int limite,
      {CritereVingt critere = CritereVingt.chiffreAffaires, VoidCallback? onSessionInvalid}) async {
    final l = lire(await ApiService().get(context, AppConstants.suivi2080Endpoint,
        queryParams: parametres(debut, fin, limite, critere: critere), onSessionInvalid: onSessionInvalid));
    return l == null ? null : garder(classer(l, critere), limite);
  }

  /// Les [limite] premiers articles (dans l'ordre du classement) : sans effet si le serveur a appliqué topN ;
  /// protège d'un serveur plus ancien qui l'ignorerait et renverrait tous les articles. [tous] : liste entière.
  static List<Suivi2080> garder(List<Suivi2080> l, int limite) => limite > 0 && l.length > limite ? l.sublist(0, limite) : l;

  static int montantTotal(List<Suivi2080> l) => l.fold(0, (s, e) => s + e.montant);
  static int quantiteTotale(List<Suivi2080> l) => l.fold(0, (s, e) => s + e.quantiteVendue);
}

// -----------------------------------------------------------------------------------------------------------------
// Stat TVA
// -----------------------------------------------------------------------------------------------------------------

/// Type de vente (valeur envoyée → libellé de l'écran d'origine).
enum TypeVente {
  tout('TOUT', 'Tout'),
  vno('VNO', 'Vente Non-Ordonnancée'),
  vo('VO', 'Vente Ordonnancée');

  final String valeur;
  final String libelle;
  const TypeVente(this.valeur, this.libelle);
}

class StatTvaDonnees {
  StatTvaDonnees._();

  static Map<String, String> parametres(DateTime debut, DateTime fin, TypeVente type) => {..._dates(debut, fin), 'typeVente': type.valeur};

  static List<StatTva>? lire(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((item) => StatTva.fromJson(item)).toList() : null;

  /// Route de l'API v3 (comme l'écran d'origine).
  static Future<List<StatTva>?> charger(BuildContext context, DateTime debut, DateTime fin, TypeVente type, {VoidCallback? onSessionInvalid}) async =>
      lire(await ApiService().getV3(context, AppConstants.statTvaEndpoint, queryParams: parametres(debut, fin, type), onSessionInvalid: onSessionInvalid));

  static double totalHt(List<StatTva> l) => l.fold(0.0, (s, e) => s + e.totalHt);
  static double totalTva(List<StatTva> l) => l.fold(0.0, (s, e) => s + e.totalTva);
  static double totalTtc(List<StatTva> l) => l.fold(0.0, (s, e) => s + e.totalTtc);

  /// Part du TTC de chaque taux (%), comme le camembert d'origine ; vide si le TTC total est nul.
  static List<double> parts(List<StatTva> l) {
    final t = totalTtc(l);
    if (t == 0) return const [];
    return [for (final s in l) s.totalTtc / t * 100];
  }
}

// -----------------------------------------------------------------------------------------------------------------
// Marge Produits Vendus
// -----------------------------------------------------------------------------------------------------------------

/// Opérateur du filtre de marge (valeur de l'écran d'origine → libellé).
enum OperateurMarge {
  egal('=', 'Égal à', '='),
  superieur('>', 'Supérieur à', '>'),
  inferieur('<', 'Inférieur à', '<'),
  superieurEgal('>=', 'Supérieur ou égal à', '≥'),
  inferieurEgal('<=', 'Inférieur ou égal à', '≤'),
  different('!=', 'Différent de', '≠'),
  environ('~=', 'Environ (±1)', '≈');

  final String valeur;
  final String libelle;
  final String symbole;
  const OperateurMarge(this.valeur, this.libelle, this.symbole);

  static OperateurMarge de(String v) => values.firstWhere((o) => o.valeur == v, orElse: () => egal);
}

class MargeDonnees {
  MargeDonnees._();

  static Map<String, String> parametres(DateTime debut, DateTime fin) => {..._dates(debut, fin), 'limit': '9999'};

  static List<MargeProduitVendu>? lire(dynamic data) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((item) => MargeProduitVendu.fromJson(item)).toList() : null;

  static Future<List<MargeProduitVendu>?> charger(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async =>
      lire(await ApiService().get(context, AppConstants.margeProduitsVendusEndpoint, queryParams: parametres(debut, fin), onSessionInvalid: onSessionInvalid));

  /// Filtre local de l'écran d'origine : [texte] vide ou non entier = aucun filtre.
  static List<MargeProduitVendu> filtrer(List<MargeProduitVendu> l, OperateurMarge op, String texte) {
    final int? marge = int.tryParse(texte);
    if (marge == null || texte.isEmpty) return List.of(l);
    return l.where((item) {
      final m = item.margePourcentage;
      return switch (op) {
        OperateurMarge.superieur => m > marge,
        OperateurMarge.inferieur => m < marge,
        OperateurMarge.superieurEgal => m >= marge,
        OperateurMarge.inferieurEgal => m <= marge,
        OperateurMarge.different => m != marge,
        OperateurMarge.environ => (m >= marge - 1) && (m <= marge + 1),
        OperateurMarge.egal => m == marge,
      };
    }).toList();
  }

  static double totalAchat(List<MargeProduitVendu> l) => l.fold(0.0, (s, e) => s + e.montantAchat);
  static double totalVente(List<MargeProduitVendu> l) => l.fold(0.0, (s, e) => s + e.montantVente);
  static double totalMarge(List<MargeProduitVendu> l) => l.fold(0.0, (s, e) => s + e.montantMarge);
}

// -----------------------------------------------------------------------------------------------------------------
// CA Crédit
// -----------------------------------------------------------------------------------------------------------------

class CaCreditDonnees {
  CaCreditDonnees._();

  static Map<String, String> parametres(DateTime debut, DateTime fin) => _dates(debut, fin);

  static List<CaCredit>? lire(dynamic data) => data is List ? data.map((item) => CaCredit.fromJson(item)).toList() : null;

  /// 3.16.0 (« CA crédit lent ») : la route n'est pas paginée par le serveur (ErpRessource.caCredis : dtStart, dtEnd
  /// seulement ; demande serveur 67) ; une grande réponse est décodée et lue hors du fil de l'interface
  /// (ApiService.getLourd).
  static Future<List<CaCredit>?> charger(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) =>
      ApiService().getLourd(context, AppConstants.caCreditEndpoint, lire, queryParams: parametres(debut, fin), onSessionInvalid: onSessionInvalid);

  // --- 3.17.0 : pagination, totaux, recherche et filtre côté serveur (demande 67) ---------------------------------

  /// Taille d'une page demandée au serveur.
  static const taillePage = 50;

  /// Délai d'attente de cette route seulement : le serveur lit toute la période avant de découper la page (12 à
  /// 16 s pour un mois chargé, mesuré par le serveur) ; les autres routes gardent ApiService.delaiGet.
  static const delai = Duration(seconds: 60);

  /// Mode de la route détecté pour une source (serveur local / distant et session, CacheCourt.source) : true = page
  /// (serveur à jour), false = liste (serveur ancien). Absent : pas encore détecté.
  static final _modes = <String, bool>{};

  static bool? modeConnu(String source) => _modes[source];
  static void noterMode(String source, bool pagine) => _modes[source] = pagine;

  /// Tests : oublie les modes détectés.
  static void oublierModes() => _modes.clear();

  /// Paramètres d'une page : période, start, limit ; query et tiersPayant seulement s'ils sont donnés.
  static Map<String, String> parametresPage(DateTime debut, DateTime fin, {int start = 0, int limit = taillePage, String query = '', String tiersPayant = ''}) => {
        ..._dates(debut, fin),
        'start': '$start',
        'limit': '$limit',
        if (query.isNotEmpty) 'query': query,
        if (tiersPayant.isNotEmpty) 'tiersPayant': tiersPayant,
      };

  /// Réponse de /ca-credit : liste (serveur ancien, ou sans limit), page (serveur à jour, avec limit), sinon null
  /// (forme inattendue). Fonction statique : peut être exécutée dans un isolat (ApiService.getLourd).
  static ReponseCaCredit? lireReponse(dynamic data) {
    if (data is List) {
      final l = lire(data);
      return l == null ? null : ReponseCaCredit.liste(l);
    }
    final p = PageCaCredit.lire(data);
    return p == null ? null : ReponseCaCredit.page(p);
  }

  /// Une lecture de /ca-credit avec start / limit (+ query, tiersPayant) : page ou liste selon le serveur.
  /// [pagine] false (serveur ancien déjà détecté) : la requête de la 3.16.0 (dtStart, dtEnd seulement).
  static Future<ReponseCaCredit?> chargerPage(BuildContext context, DateTime debut, DateTime fin,
      {bool pagine = true, int start = 0, int limit = taillePage, String query = '', String tiersPayant = '', VoidCallback? onSessionInvalid}) {
    final p = pagine ? parametresPage(debut, fin, start: start, limit: limit, query: query, tiersPayant: tiersPayant) : parametres(debut, fin);
    return ApiService().getLourd(context, AppConstants.caCreditEndpoint, lireReponse, queryParams: p, onSessionInvalid: onSessionInvalid, delai: delai);
  }

  /// Recherche locale de l'écran d'origine (sans tenir compte de la casse).
  static List<CaCredit> filtrer(List<CaCredit> l, String texte) {
    final query = texte.toLowerCase();
    return l.where((credit) {
      return query.isEmpty ||
          credit.clientName.toLowerCase().contains(query) ||
          credit.ayantDroitName.toLowerCase().contains(query) ||
          credit.numFacturation.toLowerCase().contains(query) ||
          credit.tiersPayantLibelle.toLowerCase().contains(query);
    }).toList();
  }

  static double total(List<CaCredit> l) => l.fold(0.0, (s, e) => s + e.montant);
}

/// Réponse de /ca-credit : la liste entière (serveur ancien) ou une page (serveur à jour, demande 67).
class ReponseCaCredit {
  final List<CaCredit>? liste;
  final PageCaCredit? page;
  const ReponseCaCredit.liste(List<CaCredit> l)
      : liste = l,
        page = null;
  const ReponseCaCredit.page(PageCaCredit p)
      : page = p,
        liste = null;

  bool get pagine => page != null;
}

/// Page de /ca-credit (demande 67) : totaux de TOUTES les lignes retenues par les filtres (total, montant, clients),
/// tiers payants de toute la période (avant filtres, triés), lignes de la page (date décroissante, puis facture).
class PageCaCredit {
  final int total;
  final double montant;
  final int clients;
  final List<String> tiersPayants;
  final List<CaCredit> data;

  /// 3.17.1 (retour du serveur du 20/11, après la demande 67) : nombre de tiers payants distincts des lignes RETENUES
  /// (après recherche et filtre) ; null sur un serveur qui ne le donne pas (67 initial).
  final int? tiersPayantsRetenus;

  /// 3.17.1 : repère de la lecture qui sert la page (millisecondes depuis 1970) : identique tant que la même lecture
  /// du serveur sert les pages, change à chaque relecture ; null sur un serveur qui ne le donne pas (67 initial).
  final int? luLe;
  const PageCaCredit(
      {required this.total, required this.montant, required this.clients, required this.tiersPayants, required this.data, this.tiersPayantsRetenus, this.luLe});

  /// Objet { total, montant, clients, tiersPayants, data [, tiersPayantsRetenus, luLe] } ; null si la forme est
  /// inattendue. Un champ ajouté illisible est ignoré (comme absent).
  static PageCaCredit? lire(dynamic j) {
    if (j is! Map) return null;
    final total = j['total'], montant = j['montant'], clients = j['clients'], tiers = j['tiersPayants'], data = j['data'];
    final retenus = j['tiersPayantsRetenus'], luLe = j['luLe'];
    if (total is! num || data is! List) return null;
    try {
      return PageCaCredit(
        total: total.toInt(),
        montant: montant is num ? montant.toDouble() : 0,
        clients: clients is num ? clients.toInt() : 0,
        tiersPayants: tiers is List ? [for (final t in tiers) if (t is String) t] : const [],
        data: [for (final x in data) CaCredit.fromJson(Map<String, dynamic>.from(x as Map))],
        tiersPayantsRetenus: retenus is num && retenus >= 0 ? retenus.toInt() : null,
        luLe: luLe is num ? luLe.toInt() : null,
      );
    } catch (_) {
      return null;
    }
  }
}

// -----------------------------------------------------------------------------------------------------------------
// CA Global
// -----------------------------------------------------------------------------------------------------------------

class CaGlobalDonnees {
  CaGlobalDonnees._();

  static Map<String, String> parametres(DateTime debut, DateTime fin) => _dates(debut, fin);

  /// Lignes triées par date, dates absentes à la fin (liste attendue ; sinon null).
  static List<CaGlobal>? lire(dynamic data) {
    if (data is! List) return null;
    final l = data.map((item) => CaGlobal.fromJson(item)).toList();
    l.sort((a, b) {
      if (a.mvtDate == null && b.mvtDate == null) return 0;
      if (a.mvtDate == null) return 1;
      if (b.mvtDate == null) return -1;
      return a.mvtDate!.compareTo(b.mvtDate!);
    });
    return l;
  }

  static Future<List<CaGlobal>?> charger(BuildContext context, DateTime debut, DateTime fin, {VoidCallback? onSessionInvalid}) async =>
      lire(await ApiService().get(context, AppConstants.caAllEndpoint, queryParams: parametres(debut, fin), onSessionInvalid: onSessionInvalid));

  /// Cumul de la période (somme de chaque total).
  static CaGlobal cumul(List<CaGlobal> l) {
    if (l.isEmpty) {
      return CaGlobal(montantCredit: 0, remiseSurCA: 0, totCB: 0, totChq: 0, totEsp: 0, totMobile: 0, totTVA: 0, totVirement: 0);
    }
    return l.reduce((acc, current) => CaGlobal(
          montantCredit: acc.montantCredit + current.montantCredit,
          mvtDate: null,
          remiseSurCA: acc.remiseSurCA + current.remiseSurCA,
          totCB: acc.totCB + current.totCB,
          totChq: acc.totChq + current.totChq,
          totEsp: acc.totEsp + current.totEsp,
          totMobile: acc.totMobile + current.totMobile,
          totTVA: acc.totTVA + current.totTVA,
          totVirement: acc.totVirement + current.totVirement,
        ));
  }

  /// CA net : CA brut − remise.
  static double net(CaGlobal c) => c.totalCa - c.remiseSurCA;

  /// Mobile Money par opérateur sur la période (3.10.0) : champ « detailMobile » de /ca-all (serveurs récents,
  /// demande 25), cumulé ; null si le serveur ne le fournit pas, ou s'il manque sur un jour qui a du Mobile Money
  /// (détail incomplet : rien plutôt qu'un détail faux). Aucun appel de plus (même règle que le Détail CA).
  static List<OperateurMobile>? detailMobile(List<CaGlobal> l) {
    if (l.isEmpty || l.every((c) => c.detailMobile == null)) return null;
    if (l.any((c) => c.detailMobile == null && c.totMobile != 0)) return null;
    return DetailCa.cumulerOperateurs([for (final c in l) ...?c.detailMobile]);
  }

  /// Modes de paiement (libellé de l'écran d'origine, montant), dans l'ordre d'origine.
  static List<(String, double)> modes(CaGlobal c) => [
        ('Total Espèces', c.totEsp),
        ('Total Crédit', c.montantCredit),
        ('Total Mobile Money', c.totMobile),
        ('Total Carte Bancaire', c.totCB),
        ('Total Chèque', c.totChq),
        ('Total Virement', c.totVirement),
      ];
}
