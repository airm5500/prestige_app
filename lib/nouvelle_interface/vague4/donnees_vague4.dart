// lib/nouvelle_interface/vague4/donnees_vague4.dart
// 3.11.0 — nouveaux menus du pharmacien, en LECTURE SEULE, sur des routes EXISTANTES du serveur (branche dev ET
// branche claude/new-session-xm8ptu, mêmes réponses) :
//  - Balance vente / caisse (web « balancesalecahs », BalanceVenteRessource) :
//    GET /balance/balancesalecash?dtStart=&dtEnd= (onglet Balance : lignes COMPTANT / CRÉDIT dans « data », résumé
//    dans « metaData », ventilation (comptant, crédit, modes, mobile, caisse, TVA) dans « ventilation ») ;
//    GET /balance/balancesalecash/analyse?typePeriode=TROIS_SEMAINES|TROIS_MOIS|SIX_MOIS|TROIS_ANS|LIBRE[&dtStart=&dtEnd=]
//    (onglets Analyse comparative et Évolution par mode de paiement : une ligne par période, « evolutions » par
//    indicateur, « parModes », « modes », « totalGeneral ») ; GET /balance/balancesalecash/pdf (édition du web).
//  - Gestion des sur-stocks (web « gestionsurstock », SurstockRessource) :
//    GET /surstock?start=&limit=&moisHistorique=&moisProjection=&query=&codeRayon=&codeGrossiste=&codeFamille=
//    (start=0 : recalcul ; pages suivantes : cache du serveur) ; GET /surstock/excel (classeur du web).
//    JAMAIS appelé : POST /surstock/create-inventaire (écriture).
//  - Saisies en périmés (web « saisie des périmés ») : GET /fichearticle/saisieperimes?dtStart=&dtEnd=&query=&start=&limit=.
// Lecture tolérante et messages d'erreur communs : outils de la vague 2 (ApiVague2.get, lireReponseVague2).
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/date_formatter.dart';
import '../modules/periode.dart' show ControlePeriode, Periode;
import '../vague2/donnees_vague2.dart';

Map<String, dynamic> _carte(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _liste(Object? v) => v is List ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)] : const [];

// ---------------------------------------------------------------------------------------------------------------
// Balance vente / caisse
// ---------------------------------------------------------------------------------------------------------------

/// Indicateurs de la balance (résumé « metaData », lignes de l'analyse, total général) : mêmes clés que le serveur.
class IndicateursBalance {
  final Map<String, dynamic> brut;
  const IndicateursBalance(this.brut);

  int n(String cle) => entierTolerant(brut[cle]);
  int get nbreVente => n('nbreVente');
  int get montantTTC => n('montantTTC');
  int get montantRemise => n('montantRemise');
  int get montantNet => n('montantNet');
  int get montantAchat => n('montantAchat');
  int get marge => n('marge');
  int get panierMoyen => n('panierMoyen');
  int get montantEsp => n('montantEsp');
  int get montantCB => n('montantCB');
  int get montantCheque => n('montantCheque');
  int get montantVirement => n('montantVirement');
  int get montantMobile => brut.containsKey('montantMobilePayment') ? n('montantMobilePayment') : n('montantMobile');
  int get montantTp => n('montantTp');
  int get montantDiff => n('montantDiff');
}

/// Ligne COMPTANT / CRÉDIT de la balance.
class LigneBalance {
  final String typeVente;
  final IndicateursBalance valeurs;
  const LigneBalance(this.typeVente, this.valeurs);

  /// VNO → COMPTANT, VO → CRÉDIT (comme le web).
  String get libelle => switch (typeVente) { 'VNO' => 'COMPTANT', 'VO' => 'CRÉDIT', _ => typeVente };
}

/// Ligne de ventilation (mode de paiement, bloc comptant / crédit, taux de TVA…).
class PartBalance {
  final String libelle;
  final int montant;
  final double part;
  final int ventes;
  const PartBalance(this.libelle, this.montant, this.part, {this.ventes = 0});
}

class TvaBalance {
  final double taux;
  final int ht;
  final int tva;
  final int ttc;
  final double part;
  const TvaBalance(this.taux, this.ht, this.tva, this.ttc, this.part);
}

/// Réponse de GET /balance/balancesalecash.
class BalanceCaisse {
  final List<LigneBalance> lignes;
  final IndicateursBalance resume;
  final PartBalance? comptant;
  final PartBalance? credit;
  final List<PartBalance> modes;
  final List<PartBalance> caisse;
  final List<TvaBalance> tva;
  const BalanceCaisse({
    this.lignes = const [],
    this.resume = const IndicateursBalance({}),
    this.comptant,
    this.credit,
    this.modes = const [],
    this.caisse = const [],
    this.tva = const [],
  });

  bool get vide => resume.nbreVente == 0 && resume.montantTTC == 0 && lignes.every((l) => l.valeurs.montantTTC == 0);

  static const _libellesCaisse = {
    'fondCaisse': 'Fond de caisse',
    'entrees': 'Entrées de caisse',
    'sorties': 'Sorties de caisse',
    'reglementsTp': 'Règlements tiers payants',
    'reglementsDifferes': 'Règlements différés',
  };

  factory BalanceCaisse.depuis(Map<String, dynamic> j) {
    final v = _carte(j['ventilation']);
    PartBalance? bloc(String cle, String libelle) {
      final b = v[cle];
      if (b is! Map) return null;
      return PartBalance(libelle, entierTolerant(b['montant']), decimalTolerant(b['partMontant']), ventes: entierTolerant(b['ventes']));
    }

    final caisse = _carte(v['caisse']);
    return BalanceCaisse(
      lignes: [for (final l in _liste(j['data'])) LigneBalance(texteTolerant(l['typeVente']), IndicateursBalance(l))],
      resume: IndicateursBalance(_carte(j['metaData'])),
      comptant: bloc('comptant', 'Comptant'),
      credit: bloc('credit', 'Crédit'),
      modes: [
        for (final m in _liste(v['modes']))
          PartBalance(texteTolerant(m['libelle']), entierTolerant(m['montant']), decimalTolerant(m['part']), ventes: entierTolerant(m['ventes'])),
      ],
      caisse: [
        for (final e in _libellesCaisse.entries)
          if (caisse[e.key] is Map)
            PartBalance(e.value, entierTolerant((caisse[e.key] as Map)['montant']), 0, ventes: entierTolerant((caisse[e.key] as Map)['nombre'])),
      ],
      tva: [
        for (final t in _liste(v['tva']))
          TvaBalance(decimalTolerant(t['taux']), entierTolerant(t['montantHt']), entierTolerant(t['montantTva']), entierTolerant(t['montantTtc']),
              decimalTolerant(t['part'])),
      ],
    );
  }
}

/// Périodes de l'analyse comparative (mêmes codes que le web).
enum PeriodeAnalyse {
  troisSemaines('TROIS_SEMAINES', '3 dernières semaines'),
  troisMois('TROIS_MOIS', '3 derniers mois'),
  sixMois('SIX_MOIS', '6 derniers mois'),
  troisAns('TROIS_ANS', '3 dernières années'),
  libre('LIBRE', 'Période libre');

  final String code;
  final String libelle;
  const PeriodeAnalyse(this.code, this.libelle);
}

/// Mode de paiement rencontré sur les périodes de l'analyse.
class ModeBalance {
  final String id;
  final String libelle;
  final bool mobile;
  const ModeBalance(this.id, this.libelle, this.mobile);
}

/// Une période de l'analyse comparative.
class PeriodeBalance {
  final String libelle;
  final bool enCours;
  final IndicateursBalance valeurs;

  /// Taux d'évolution par indicateur par rapport à la période précédente (null : pas de comparaison).
  final Map<String, double?> evolutions;
  final Map<String, int> parModes;
  final Map<String, double?> evolutionsModes;
  const PeriodeBalance(this.libelle, this.enCours, this.valeurs, this.evolutions, this.parModes, this.evolutionsModes);

  /// Libellé court pour l'axe d'un graphique : sans la précision entre parenthèses (« S39 (21/09-27/09) » → « S39 »),
  /// 8 caractères au plus.
  String get libelleCourt {
    final i = libelle.indexOf(' (');
    final t = (i > 0 ? libelle.substring(0, i) : libelle).trim();
    return t.length <= 8 ? t : t.substring(0, 8);
  }

  factory PeriodeBalance.depuis(Map<String, dynamic> j) {
    final e = _carte(j['evolutions']);
    return PeriodeBalance(
      texteTolerant(j['libelle']),
      booleenTolerant(j['enCours']),
      IndicateursBalance(j),
      {for (final k in e.keys) if (k != 'parModes') k: decimalOuNull(e[k])},
      {for (final m in _carte(j['parModes']).entries) m.key: entierTolerant(m.value)},
      {for (final m in _carte(e['parModes']).entries) m.key: decimalOuNull(m.value)},
    );
  }
}

/// Réponse de GET /balance/balancesalecash/analyse.
class AnalyseBalance {
  final List<PeriodeBalance> periodes;
  final List<ModeBalance> modes;
  final IndicateursBalance total;
  final Map<String, int> totalModes;
  final bool comparatif;
  const AnalyseBalance(this.periodes, this.modes, this.total, this.totalModes, this.comparatif);

  factory AnalyseBalance.depuis(Map<String, dynamic> j) {
    final t = _carte(j['totalGeneral']);
    final p = [for (final l in _liste(j['data'])) PeriodeBalance.depuis(l)];
    return AnalyseBalance(
      p,
      [
        for (final m in _liste(j['modes']))
          if (texteTolerant(m['modeId']).isNotEmpty) ModeBalance(texteTolerant(m['modeId']), texteTolerant(m['libelle']), booleenTolerant(m['mobile'])),
      ],
      IndicateursBalance(t),
      {for (final m in _carte(t['parModes']).entries) m.key: entierTolerant(m.value)},
      j.containsKey('comparatif') ? booleenTolerant(j['comparatif']) : p.length >= 2,
    );
  }
}

class ApiBalance {
  ApiBalance._();

  static const route = '/balance/balancesalecash';
  static const routeAnalyse = '/balance/balancesalecash/analyse';
  static const routePdf = '/balance/balancesalecash/pdf';
  static const quoi = 'la balance vente / caisse';
  static const quoiAnalyse = 'l\'analyse comparative';

  static Map<String, String> parametres(Periode p) => p.parametres;

  /// Paramètres de l'analyse ; dates seulement pour la période libre.
  static Map<String, String> parametresAnalyse(PeriodeAnalyse t, {DateTime? debut, DateTime? fin}) => {
        'typePeriode': t.code,
        if (t == PeriodeAnalyse.libre && debut != null) 'dtStart': DateFormatter.toApiFormat(debut),
        if (t == PeriodeAnalyse.libre && fin != null) 'dtEnd': DateFormatter.toApiFormat(fin),
      };

  /// Contrôle d'une période libre (dates obligatoires, contrôles communs).
  static String? erreurAnalyse(PeriodeAnalyse t, DateTime? debut, DateTime? fin, DateTime maintenant) {
    if (t != PeriodeAnalyse.libre) return null;
    if (debut == null || fin == null) return 'Choisissez les dates de la période.';
    return ControlePeriode.erreur(debut, fin, maintenant);
  }

  /// Analyse longue (3 ans, ou période libre de plus d'un an) : délai long.
  static bool longue(PeriodeAnalyse t, DateTime? debut, DateTime? fin) =>
      t == PeriodeAnalyse.troisAns || (t == PeriodeAnalyse.libre && debut != null && fin != null && fin.difference(debut).inDays > 366);

  static Future<BalanceCaisse> balance(BuildContext context, Periode p) async {
    final j = await ApiVague2.get(context, route, parametres(p), quoi);
    return ApiVague2.lire(() => BalanceCaisse.depuis(j), quoi);
  }

  static Future<AnalyseBalance> analyse(BuildContext context, PeriodeAnalyse t, {DateTime? debut, DateTime? fin, DateTime? maintenant}) async {
    final e = erreurAnalyse(t, debut, fin, maintenant ?? DateTime.now());
    if (e != null) throw ApiLoadException(e, nature: NatureErreur.refus);
    final j = await ApiVague2.get(context, routeAnalyse, parametresAnalyse(t, debut: debut, fin: fin), quoiAnalyse,
        delai: longue(t, debut, fin) ? ApiVague2.delaiLong : ApiVague2.delaiNormal);
    return ApiVague2.lire(() => AnalyseBalance.depuis(j), quoiAnalyse);
  }

  /// Édition PDF de la balance (même modèle que le web).
  static Future<FichierTelecharge> pdf(BuildContext context, Periode p) =>
      ApiService().getBytes(context, routePdf, queryParams: parametres(p), nomParDefaut: 'balance_vente_caisse.pdf');
}

// ---------------------------------------------------------------------------------------------------------------
// Gestion des sur-stocks
// ---------------------------------------------------------------------------------------------------------------

class ProduitSurstock {
  final String id;
  final String cip;
  final String libelle;
  final String emplacement;
  final String datePeremption;
  final int prixAchat;
  final int prixVente;
  final int stock;
  final int qteVendue;
  final List<int> mois;
  final int qteSurplus;
  final int valeurSurplus;
  final double moyenneMensuelle;
  final double nbMoisStock;
  const ProduitSurstock({
    this.id = '',
    this.cip = '',
    this.libelle = '',
    this.emplacement = '',
    this.datePeremption = '',
    this.prixAchat = 0,
    this.prixVente = 0,
    this.stock = 0,
    this.qteVendue = 0,
    this.mois = const [0, 0, 0, 0],
    this.qteSurplus = 0,
    this.valeurSurplus = 0,
    this.moyenneMensuelle = 0,
    this.nbMoisStock = 0,
  });

  factory ProduitSurstock.depuis(Map<String, dynamic> j) => ProduitSurstock(
        id: texteTolerant(j['id']),
        cip: texteTolerant(j['cip']),
        libelle: texteTolerant(j['libelle']),
        emplacement: texteTolerant(j['emplacement']),
        datePeremption: texteTolerant(j['datePeremption']),
        prixAchat: entierTolerant(j['prixAchat']),
        prixVente: entierTolerant(j['prixVente']),
        stock: entierTolerant(j['stock']),
        qteVendue: entierTolerant(j['qteVendue']),
        mois: [entierTolerant(j['mois0']), entierTolerant(j['mois1']), entierTolerant(j['mois2']), entierTolerant(j['mois3'])],
        qteSurplus: entierTolerant(j['qteSurplus']),
        valeurSurplus: entierTolerant(j['valeurSurplus']),
        moyenneMensuelle: decimalTolerant(j['moyenneMensuelle']),
        nbMoisStock: decimalTolerant(j['nbMoisStock']),
      );
}

/// Une page de sur-stocks : produits, nombre total, valeur totale du surplus, libellés des mois (mois0 = en cours).
class PageSurstocks {
  final List<ProduitSurstock> produits;
  final int total;
  final int totalValeur;
  final List<String> mois;
  const PageSurstocks(this.produits, this.total, this.totalValeur, this.mois);
}

/// Critères de recherche des sur-stocks (valeurs par défaut du web : 3 mois d'historique, 3 mois de projection).
class FiltresSurstock {
  final int moisHistorique;
  final int moisProjection;
  final String recherche;
  final List<String> rayons;
  final List<String> grossistes;
  final List<String> familles;
  const FiltresSurstock({
    this.moisHistorique = 3,
    this.moisProjection = 3,
    this.recherche = '',
    this.rayons = const [],
    this.grossistes = const [],
    this.familles = const [],
  });

  /// Choix proposés (bornes du web : 1 à 12 mois).
  static const choixMois = [1, 2, 3, 6, 12];
  static const maxRecherche = 50;

  FiltresSurstock copie({int? moisHistorique, int? moisProjection, String? recherche, List<String>? rayons, List<String>? grossistes, List<String>? familles}) =>
      FiltresSurstock(
        moisHistorique: moisHistorique ?? this.moisHistorique,
        moisProjection: moisProjection ?? this.moisProjection,
        recherche: recherche ?? this.recherche,
        rayons: rayons ?? this.rayons,
        grossistes: grossistes ?? this.grossistes,
        familles: familles ?? this.familles,
      );

  int get actifs => (rayons.isEmpty ? 0 : 1) + (grossistes.isEmpty ? 0 : 1) + (familles.isEmpty ? 0 : 1);

  /// Paramètres communs (liste, Excel) : identifiants séparés par des virgules, comme le web.
  Map<String, String> get parametres => {
        'moisHistorique': '${moisHistorique.clamp(1, 12)}',
        'moisProjection': '${moisProjection.clamp(1, 12)}',
        'query': recherche.trim().length > maxRecherche ? recherche.trim().substring(0, maxRecherche) : recherche.trim(),
        'codeRayon': idsSepares(rayons),
        'codeGrossiste': idsSepares(grossistes),
        'codeFamille': idsSepares(familles),
      };
}

class ApiSurstock {
  ApiSurstock._();

  static const route = '/surstock';
  static const routeExcel = '/surstock/excel';

  /// Écriture JAMAIS appelée depuis le mobile.
  static const routeInterdite = '/surstock/create-inventaire';
  static const taillePage = 50;
  static const quoi = 'les sur-stocks';

  static Map<String, String> parametres(FiltresSurstock f, int start) => {...f.parametres, 'start': '$start', 'limit': '$taillePage'};

  /// [start] = 0 : le serveur recalcule ; les pages suivantes relisent son cache (mêmes critères).
  static Future<PageSurstocks> page(BuildContext context, FiltresSurstock f, {int start = 0}) async {
    final j = await ApiVague2.get(context, route, parametres(f, start), quoi, delai: ApiVague2.delaiLong);
    return ApiVague2.lire(() {
      final m = _carte(j['mois']);
      return PageSurstocks(
        [for (final p in donneesListe(j, quoi)) ProduitSurstock.depuis(p)],
        entierTolerant(j['total']),
        entierTolerant(j['totalValeur']),
        [for (final k in ['mois0', 'mois1', 'mois2', 'mois3']) texteTolerant(m[k])],
      );
    }, quoi);
  }

  static Future<FichierTelecharge> excel(BuildContext context, FiltresSurstock f) =>
      ApiService().getBytes(context, routeExcel, queryParams: f.parametres, nomParDefaut: 'gestion_surstocks.xls');
}

// ---------------------------------------------------------------------------------------------------------------
// Saisies en périmés
// ---------------------------------------------------------------------------------------------------------------

class SaisiePerime {
  final String cip;
  final String libelle;
  final int quantite;
  final String lot;
  final String peremption;
  final String saisieLe;
  final String rayon;
  final int valeur;
  const SaisiePerime(this.cip, this.libelle, this.quantite, this.lot, this.peremption, this.saisieLe, this.rayon, this.valeur);

  factory SaisiePerime.depuis(Map<String, dynamic> j) => SaisiePerime(
        texteTolerant(j['intCIP']),
        texteTolerant(j['strNAME']),
        entierTolerant(j['intQUANTITY']),
        texteTolerant(j['ticketNum']),
        texteTolerant(j['dtCREATED']),
        texteTolerant(j['dateHeure']),
        texteTolerant(j['libelleRayon']),
        entierTolerant(j['intPRICE']),
      );
}

class ApiSaisiesPerimes {
  ApiSaisiesPerimes._();

  static const route = '/fichearticle/saisieperimes';
  static const taillePage = 50;
  static const quoi = 'les saisies en périmés';

  /// Fenêtre de l'alerte de l'accueil : saisies des 30 derniers jours.
  static const joursAlerte = 30;

  static Map<String, String> parametres(DateTime debut, DateTime fin, {String recherche = '', int start = 0, int limit = taillePage}) => {
        'dtStart': DateFormatter.toApiFormat(debut),
        'dtEnd': DateFormatter.toApiFormat(fin),
        'query': recherche.trim(),
        'start': '$start',
        'limit': '$limit',
      };

  static Future<PageResultats<SaisiePerime>> page(BuildContext context, DateTime debut, DateTime fin, {String recherche = '', int start = 0}) async {
    final j = await ApiVague2.get(context, route, parametres(debut, fin, recherche: recherche, start: start), quoi);
    return ApiVague2.lire(
        () => PageResultats<SaisiePerime>([for (final x in donneesListe(j, quoi)) SaisiePerime.depuis(x)], entierTolerant(j['total'])), quoi);
  }

  /// Nombre de saisies en périmés des [joursAlerte] derniers jours (une ligne demandée : seul « total » sert).
  static Future<int> compter(BuildContext context, DateTime maintenant) async {
    final fin = DateTime(maintenant.year, maintenant.month, maintenant.day);
    final debut = DateTime(fin.year, fin.month, fin.day - (joursAlerte - 1));
    final j = await ApiVague2.get(context, route, parametres(debut, fin, limit: 1), quoi);
    return entierTolerant(j['total']);
  }
}
