// lib/nouvelle_interface/vague1/donnees_vague1.dart
// Vague 1 des nouveaux menus du pharmacien (lecture seule) : modèles et appels au serveur Prestige.
// Routes EXISTANTES du serveur (branche claude/new-session-xm8ptu), aucune écriture :
//  - Valorisation : GET /tableau-bord/valorisation?frais=0|1 (aujourd'hui, mode simple ; cache serveur 15 min,
//    frais=1 relit la base) et GET /produit/valorisation?mode=&dtStart=&lgFAMILLEARTICLEID=&lgZONEGEOID=&lgGROSSISTEID=
//    (date passée ou regroupement) ; listes GET /common/famillearticles, /common/rayons, /common/grossiste ;
//  - Alertes : GET /tableau-bord/alertes?per=6&rup=7&ren=7&sug=2&nv=30 (comptage) et
//    GET /tableau-bord/alertes/liste?type=&per=6&rup=7&nv=30&limite=500 (détail) ;
//  - Retraits et abandons : GET /vente-suppressions?start=&limit=&dtStart=&dtEnd=&userId=&query=&type= (clé
//    « results ») ; Ventes modifiées : GET /ventes-modifiees (mêmes paramètres, clé « results »).
// Lecture TOLÉRANTE : nombres en entier, décimal ou texte (« 1 245 »), champs absents = 0 ou vide, clé « results »
// ou « data ». Un refus du serveur (interdit:true, success:false) devient « Droit manquant : … » SANS déconnexion ;
// « success:false » avec « erreur:true » (calcul en échec côté serveur) devient une erreur du serveur ; la session
// expirée (401, « Veuillez vous connecter ») suit le mécanisme existant d'ApiService (retour à la connexion).
import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/date_formatter.dart';

// ---------------------------------------------------------------------------------------------------------------
// Lecture tolérante
// ---------------------------------------------------------------------------------------------------------------

/// Entier lu dans un nombre, un décimal (arrondi) ou un texte (« 1 245 », « 12,0 ») ; 0 sinon.
int entierTolerant(Object? v) {
  if (v is int) return v;
  if (v is num) return v.isFinite ? v.round() : 0;
  if (v is String) {
    final t = v.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.');
    final n = num.tryParse(t);
    return n == null || !n.isFinite ? 0 : n.round();
  }
  if (v is bool) return v ? 1 : 0;
  return 0;
}

/// Nombre décimal tolérant (mêmes règles qu'[entierTolerant]).
double decimalTolerant(Object? v) {
  if (v is num) return v.isFinite ? v.toDouble() : 0;
  if (v is String) {
    final n = double.tryParse(v.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.'));
    return n == null || !n.isFinite ? 0 : n;
  }
  return 0;
}

/// Texte tolérant : null → '' ; « null » (texte) → ''.
String texteTolerant(Object? v) {
  if (v == null) return '';
  final t = v.toString().trim();
  return t == 'null' ? '' : t;
}

bool booleenTolerant(Object? v, {bool defaut = false}) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.trim().toLowerCase();
    if (t == 'true' || t == '1' || t == 'oui') return true;
    if (t == 'false' || t == '0' || t == 'non') return false;
  }
  return defaut;
}

Map<String, dynamic> _carte(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Mots d'un message du serveur qui signalent un droit manquant.
bool estMessageDeDroit(String message) {
  final m = message.toLowerCase();
  return m.contains('droit') || m.contains('accès') || m.contains('acces') || m.contains('autoris') || m.contains('interdit');
}

/// Réponse d'une route de la vague 1 : contrôle du format et des refus. [quoi] : « la valorisation », « les alertes »…
/// Réponse vide (corps vide) : carte vide (vraie absence de données).
Map<String, dynamic> lireReponseVague1(dynamic r, String quoi) {
  if (r == null) return <String, dynamic>{};
  if (r is! Map) throw ApiLoadException('Réponse inattendue du serveur pour $quoi.', nature: NatureErreur.reponse);
  final m = Map<String, dynamic>.from(r);
  final message = texteTolerant(m['msg'] ?? m['message']);
  if (booleenTolerant(m['interdit'])) {
    throw ApiLoadException(messageDroitManquant(quoi, message), nature: NatureErreur.droit);
  }
  if (m['success'] == false) {
    if (booleenTolerant(m['erreur'])) {
      throw ApiLoadException('Le serveur n\'a pas pu calculer $quoi. Réessayez dans un instant.', nature: NatureErreur.serveur);
    }
    throw ApiLoadException(messageDroitManquant(quoi, message), nature: NatureErreur.droit);
  }
  return m;
}

/// « Droit manquant : consulter les alertes. (message du serveur) »
String messageDroitManquant(String quoi, [String serveur = '']) =>
    'Droit manquant : consulter $quoi.${serveur.isEmpty ? '' : ' ($serveur)'} Demandez l\'accès à l\'administrateur.';

/// Appel GET d'une route de la vague 1 : 403 → « Droit manquant : … » (sans déconnexion) ; le reste comme ApiService.
Future<Map<String, dynamic>> getVague1(BuildContext context, String route, Map<String, String> parametres, String quoi) async {
  try {
    final r = await ApiService().get(context, route, queryParams: parametres);
    return lireReponseVague1(r, quoi);
  } on ApiLoadException catch (e) {
    if (e.nature == NatureErreur.droit && !e.message.startsWith('Droit manquant')) {
      throw ApiLoadException(messageDroitManquant(quoi), nature: NatureErreur.droit, code: e.code);
    }
    rethrow;
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Valorisation rayon / réserve / total
// ---------------------------------------------------------------------------------------------------------------

/// Valeur d'achat et de vente d'un stock ; écart et marge comme l'écran web (marge % = écart / vente).
class ValeursStock {
  final int achat;
  final int vente;
  const ValeursStock(this.achat, this.vente);

  int get ecart => vente - achat;

  /// Marge en % de la valeur de vente ; null si la valeur de vente est nulle.
  double? get margePourcent => vente == 0 ? null : ecart * 100 / vente;

  ValeursStock operator +(ValeursStock o) => ValeursStock(achat + o.achat, vente + o.vente);

  static ValeursStock depuis(Object? j) {
    final m = _carte(j);
    return ValeursStock(entierTolerant(m['achat']), entierTolerant(m['vente']));
  }
}

enum OngletStock { rayon, reserve, total }

extension OngletStockTextes on OngletStock {
  String get libelle => switch (this) {
        OngletStock.rayon => 'Rayon',
        OngletStock.reserve => 'Réserve',
        OngletStock.total => 'Total',
      };
}

/// Regroupement de la valorisation (paramètre « mode » de /produit/valorisation).
enum ModeValorisation {
  simple(0, 'Simple', '', ''),
  famille(1, 'Famille', 'lgFAMILLEARTICLEID', '/common/famillearticles'),
  emplacement(2, 'Emplacement', 'lgZONEGEOID', '/common/rayons'),
  grossiste(3, 'Grossiste', 'lgGROSSISTEID', '/common/grossiste');

  final int code;
  final String libelle;

  /// Paramètre qui porte les identifiants choisis (séparés par des virgules).
  final String parametre;

  /// Liste des choix possibles.
  final String routeListe;
  const ModeValorisation(this.code, this.libelle, this.parametre, this.routeListe);

  String get pluriel => switch (this) {
        ModeValorisation.simple => '',
        ModeValorisation.famille => 'familles',
        ModeValorisation.emplacement => 'emplacements',
        ModeValorisation.grossiste => 'grossistes',
      };
}

/// D'où vient la valorisation affichée.
enum SourceValorisation { tableauDeBord, calculDuJour, releve }

class Valorisation {
  final ValeursStock rayon;
  final ValeursStock reserve;
  final ValeursStock total;

  /// Faux : jour jamais relevé (les zéros ne sont pas une mesure).
  final bool releveDisponible;
  final SourceValorisation source;

  /// Produits dormants (tableau de bord seulement).
  final int? dormants;
  final int? dormantsValeurAchat;

  const Valorisation({
    required this.rayon,
    required this.reserve,
    required this.total,
    this.releveDisponible = true,
    required this.source,
    this.dormants,
    this.dormantsValeurAchat,
  });

  ValeursStock de(OngletStock o) => switch (o) {
        OngletStock.rayon => rayon,
        OngletStock.reserve => reserve,
        OngletStock.total => total,
      };

  /// GET /tableau-bord/valorisation : {rayon:{achat,vente}, reserve:{…}, total:{…}, dormants:{produits, valeurAchat}}.
  /// Total absent : rayon + réserve.
  factory Valorisation.depuisTableauDeBord(Map<String, dynamic> j) {
    final rayon = ValeursStock.depuis(j['rayon']);
    final reserve = ValeursStock.depuis(j['reserve']);
    final total = j['total'] is Map ? ValeursStock.depuis(j['total']) : rayon + reserve;
    final d = j['dormants'];
    return Valorisation(
      rayon: rayon,
      reserve: reserve,
      total: total,
      source: SourceValorisation.tableauDeBord,
      dormants: d is Map ? entierTolerant(d['produits']) : null,
      dormantsValeurAchat: d is Map ? entierTolerant(d['valeurAchat']) : null,
    );
  }

  /// GET /produit/valorisation : {data:{value (rayon achat), valueTwo (rayon vente), reserveValue, reserveValueTwo,
  /// totalValue, totalValueTwo, releveDisponible}} (données aussi acceptées sans l'enveloppe « data »).
  factory Valorisation.depuisProduit(Map<String, dynamic> j, {required bool duJour}) {
    final d = j['data'] is Map ? _carte(j['data']) : j;
    final rayon = ValeursStock(entierTolerant(d['value']), entierTolerant(d['valueTwo']));
    final reserve = ValeursStock(entierTolerant(d['reserveValue']), entierTolerant(d['reserveValueTwo']));
    final total = d.containsKey('totalValue') || d.containsKey('totalValueTwo')
        ? ValeursStock(entierTolerant(d['totalValue']), entierTolerant(d['totalValueTwo']))
        : rayon + reserve;
    return Valorisation(
      rayon: rayon,
      reserve: reserve,
      total: total,
      releveDisponible: booleenTolerant(d['releveDisponible'], defaut: true),
      source: duJour ? SourceValorisation.calculDuJour : SourceValorisation.releve,
    );
  }
}

/// Élément d'une liste de choix (familles, emplacements, grossistes, utilisateurs).
class OptionListe {
  final String id;
  final String libelle;
  const OptionListe(this.id, this.libelle);

  @override
  bool operator ==(Object other) => other is OptionListe && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Liste {data:[{id, libelle}]} ou [...] ; l'entrée « Tous » (id ALL) ajoutée par le serveur est retirée.
List<OptionListe> lireOptions(dynamic r, {String champId = 'id', String champLibelle = 'libelle'}) {
  final data = r is Map ? (r['data'] ?? r['results']) : r;
  if (data is! List) return const [];
  final options = <OptionListe>[];
  for (final e in data) {
    if (e is! Map) continue;
    final id = texteTolerant(e[champId]);
    final libelle = texteTolerant(e[champLibelle]);
    if (id.isEmpty || id.toUpperCase() == 'ALL') continue;
    options.add(OptionListe(id, libelle.isEmpty ? id : libelle));
  }
  return options;
}

/// Date du jour (sans l'heure).
DateTime jourDe(DateTime d) => DateTime(d.year, d.month, d.day);
bool memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

class ApiValorisation {
  ApiValorisation._();

  static const routeTableauDeBord = '/tableau-bord/valorisation';
  static const routeProduit = '/produit/valorisation';

  /// Paramètres de /produit/valorisation (contrôlés : date jamais future, identifiants séparés par des virgules).
  static Map<String, String> parametresProduit(ModeValorisation mode, DateTime date, Iterable<String> ids) {
    final p = <String, String>{'mode': '${mode.code}', 'dtStart': DateFormatter.toApiFormat(date)};
    if (mode != ModeValorisation.simple && ids.isNotEmpty) p[mode.parametre] = ids.join(',');
    return p;
  }

  /// Aujourd'hui, mode simple : tableau de bord (léger). Date passée ou regroupement : /produit/valorisation.
  static bool parTableauDeBord(ModeValorisation mode, DateTime date, DateTime maintenant) =>
      mode == ModeValorisation.simple && memeJour(date, maintenant);

  static Future<Valorisation> charger(BuildContext context,
      {required ModeValorisation mode, required DateTime date, Iterable<String> ids = const [], bool frais = false, DateTime? maintenant}) async {
    final m = maintenant ?? DateTime.now();
    if (jourDe(date).isAfter(jourDe(m))) {
      throw const ApiLoadException('La date de valorisation ne peut pas être dans le futur.', nature: NatureErreur.refus);
    }
    if (parTableauDeBord(mode, date, m)) {
      final j = await getVague1(context, routeTableauDeBord, {'frais': frais ? '1' : '0'}, 'la valorisation du stock');
      return _lire(() => Valorisation.depuisTableauDeBord(j));
    }
    final j = await getVague1(context, routeProduit, parametresProduit(mode, date, ids), 'la valorisation du stock');
    return _lire(() => Valorisation.depuisProduit(j, duJour: memeJour(date, m)));
  }

  static Future<List<OptionListe>> options(BuildContext context, ModeValorisation mode) async {
    if (mode == ModeValorisation.simple) return const [];
    final r = await ApiService().get(context, mode.routeListe, queryParams: {'limit': '9999', 'page': '1', 'start': '0'});
    lireReponseVague1(r is Map ? r : null, 'la liste des ${mode.pluriel}');
    return lireOptions(r);
  }

  static T _lire<T>(T Function() f) {
    try {
      return f();
    } catch (_) {
      throw const ApiLoadException('Données de valorisation illisibles.', nature: NatureErreur.reponse);
    }
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Alertes du tableau de bord
// ---------------------------------------------------------------------------------------------------------------

/// Type d'alerte. [typeListe] : type accepté par /tableau-bord/alertes/liste (null : pas de liste côté serveur).
enum TypeAlerte {
  ruptures('ruptures', 'Ruptures de stock'),
  peremptions('peremptions', 'Produits proches de la péremption'),
  negatifs('negatifs', 'Stocks négatifs'),
  nonVendus('nonvendus', 'Entrés et jamais vendus'),
  suggestionsRayon('rayon', 'Réassort du rayon'),
  suggestionsCommande(null, 'Suggestions non commandées'),
  suggestionsReserve(null, 'Suggestions de réserve'),
  renouvellements(null, 'Ordonnances à renouveler'),
  avoirs(null, 'Ventes en avoir non clôturées');

  final String? typeListe;
  final String titre;
  const TypeAlerte(this.typeListe, this.titre);

  bool get listable => typeListe != null;
}

/// Réglages des alertes (mêmes valeurs par défaut que le tableau de bord web).
class ReglagesAlertes {
  static const moisPeremption = 6;
  static const joursRupture = 7;
  static const joursRenouvellement = 7;
  static const joursSuggestion = 2;
  static const joursNonVendus = 30;
  static const limiteListe = 500;

  /// Paramètres du comptage : per=6&rup=7&ren=7&sug=2&nv=30.
  static Map<String, String> get parametresComptage => {
        'per': '$moisPeremption',
        'rup': '$joursRupture',
        'ren': '$joursRenouvellement',
        'sug': '$joursSuggestion',
        'nv': '$joursNonVendus',
      };

  /// Paramètres d'une liste : mêmes réglages que le comptage (même nombre de lignes), 500 lignes au plus.
  static Map<String, String> parametresListe(TypeAlerte t) => {
        'type': t.typeListe!,
        'per': '$moisPeremption',
        'rup': '$joursRupture',
        'nv': '$joursNonVendus',
        'limite': '$limiteListe',
      };
}

/// Une alerte comptée : nombre principal, unité, précisions.
class Alerte {
  final TypeAlerte type;
  final int nombre;
  final String unite;
  final String unites;
  final String detail;
  const Alerte(this.type, this.nombre, this.unite, this.unites, this.detail);

  String get nombreTexte => '${grouperMilliers(nombre)} ${nombre > 1 ? unites : unite}';
}

/// « 1 245 » (espaces insécables).
String grouperMilliers(num n) {
  final t = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < t.length; i++) {
    if (i > 0 && (t.length - i) % 3 == 0) b.write(' ');
    b.write(t[i]);
  }
  return b.toString();
}

String _pl(int n, String s, String p) => n > 1 ? p : s;

/// Réponse de GET /tableau-bord/alertes, lue de façon tolérante (bloc absent : 0 ; nombre seul à la place d'un bloc
/// accepté).
class AlertesTableauDeBord {
  final Map<String, dynamic> brut;
  AlertesTableauDeBord(this.brut);

  int _n(String bloc, [String? champ]) {
    final v = brut[bloc];
    if (champ == null || v is! Map) return entierTolerant(v);
    return entierTolerant(v[champ]);
  }

  int _jours(String bloc, String champ, int defaut) {
    final v = brut[bloc];
    return v is Map && v[champ] != null ? entierTolerant(v[champ]) : defaut;
  }

  int get ruptures => _n('ruptures', 'produits');
  int get rupturesVenduesRecemment => _n('ruptures', 'vendusRecemment');
  int get joursRupture => _jours('ruptures', 'jours', ReglagesAlertes.joursRupture);
  int get peremptionsLots => _n('peremptions', 'lots');
  int get peremptionsProduits => _n('peremptions', 'produits');
  int get peremptionsValeurAchat => _n('peremptions', 'valeurAchat');
  int get moisPeremption => _jours('peremptions', 'mois', ReglagesAlertes.moisPeremption);
  int get suggestionsReserve => _n('suggestionsReserve');
  int get suggestionsRayon => _n('suggestionsRayon');
  int get suggestionsCommande => _n('suggestionsCommande', 'cloturees');
  int get joursSuggestion => _jours('suggestionsCommande', 'jours', ReglagesAlertes.joursSuggestion);
  int get renouvellements => _n('renouvellements', 'patients');
  int get joursRenouvellement => _jours('renouvellements', 'jours', ReglagesAlertes.joursRenouvellement);
  int get avoirs => _n('avoirs');
  int get negatifs => _n('negatifs');
  int get nonVendus => _n('nonVendus', 'produits');
  int get joursNonVendus => _jours('nonVendus', 'jours', ReglagesAlertes.joursNonVendus);

  Alerte alerte(TypeAlerte t) => switch (t) {
        TypeAlerte.ruptures => Alerte(t, ruptures, 'produit', 'produits',
            'Stock nul, articles actifs · ${grouperMilliers(rupturesVenduesRecemment)} ${_pl(rupturesVenduesRecemment, 'vendu', 'vendus')} ces $joursRupture derniers jours'),
        TypeAlerte.peremptions => Alerte(t, peremptionsLots, 'lot', 'lots',
            'Lots qui périment d\'ici $moisPeremption mois · ${grouperMilliers(peremptionsProduits)} ${_pl(peremptionsProduits, 'produit', 'produits')}'),
        TypeAlerte.negatifs => Alerte(t, negatifs, 'article', 'articles', 'Stock inférieur à zéro à votre emplacement'),
        TypeAlerte.nonVendus =>
          Alerte(t, nonVendus, 'produit', 'produits', 'Reçus (bons clôturés) depuis $joursNonVendus jours, aucune vente depuis'),
        TypeAlerte.suggestionsRayon => Alerte(t, suggestionsRayon, 'suggestion', 'suggestions', 'Suggestions de rayon à traiter'),
        TypeAlerte.suggestionsCommande =>
          Alerte(t, suggestionsCommande, 'suggestion', 'suggestions', 'Clôturées depuis plus de $joursSuggestion jours, pas encore commandées'),
        TypeAlerte.suggestionsReserve =>
          Alerte(t, suggestionsReserve, 'suggestion', 'suggestions', 'À traiter dans Prestige (gestion de la réserve)'),
        TypeAlerte.renouvellements =>
          Alerte(t, renouvellements, 'patient', 'patients', 'Dans les $joursRenouvellement prochains jours · à traiter dans Prestige'),
        TypeAlerte.avoirs => Alerte(t, avoirs, 'vente', 'ventes', 'À clôturer dans Prestige'),
      };

  List<Alerte> get toutes => [for (final t in TypeAlerte.values) alerte(t)];

  /// Nombre de types d'alerte non nuls (« 5 alertes à traiter »).
  int get typesAlerte => toutes.where((a) => a.nombre > 0).length;
}

/// Ligne d'une liste d'alerte (/tableau-bord/alertes/liste) : libellé, CIP et champs propres au type.
class LigneAlerte {
  final String libelle;
  final String cip;
  final Map<String, dynamic> brut;
  const LigneAlerte(this.libelle, this.cip, this.brut);

  factory LigneAlerte.depuis(Map<String, dynamic> j) => LigneAlerte(texteTolerant(j['libelle']), texteTolerant(j['cip']), j);

  int get quantite => entierTolerant(brut['quantite']);
  String texte(String champ) => texteTolerant(brut[champ]);

  /// Précisions affichées sous le libellé, selon le type.
  List<(String, String)> details(TypeAlerte t) => switch (t) {
        TypeAlerte.ruptures => [
            ('Dernière vente', dateLisibleApi(texte('derniereVente'))),
            if (booleenTolerant(brut['recent'])) ('Vendu récemment', 'oui'),
            if (texte('grossiste').isNotEmpty) ('Grossiste', texte('grossiste')),
          ],
        TypeAlerte.peremptions => [
            ('Lot', texte('lot').isEmpty ? '—' : texte('lot')),
            ('Péremption', dateLisibleApi(texte('peremption'))),
            ('Quantité', grouperMilliers(quantite)),
          ],
        TypeAlerte.negatifs => [
            ('Stock', grouperMilliers(quantite)),
            if (texte('emplacement').isNotEmpty) ('Emplacement', texte('emplacement')),
          ],
        TypeAlerte.suggestionsRayon => [
            ('Quantité', grouperMilliers(quantite)),
            if (texte('reference').isNotEmpty) ('Suggestion', texte('reference')),
          ],
        TypeAlerte.nonVendus => [
            ('Entré le', dateLisibleApi(texte('entree'))),
            ('Quantité reçue', grouperMilliers(quantite)),
            if (texte('grossiste').isNotEmpty) ('Grossiste', texte('grossiste')),
          ],
        _ => const [],
      };
}

/// « 2026-10-12 » → « 12/10/2026 » ; vide → « — » ; autre format rendu tel quel.
String dateLisibleApi(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s.trim());
  if (m != null) return '${m.group(3)}/${m.group(2)}/${m.group(1)}';
  return s.trim().isEmpty ? '—' : s.trim();
}

class ApiAlertes {
  ApiAlertes._();

  static const routeComptage = '/tableau-bord/alertes';
  static const routeListe = '/tableau-bord/alertes/liste';

  static Future<AlertesTableauDeBord> compter(BuildContext context) async {
    final j = await getVague1(context, routeComptage, ReglagesAlertes.parametresComptage, 'les alertes');
    return AlertesTableauDeBord(j);
  }

  static Future<List<LigneAlerte>> liste(BuildContext context, TypeAlerte t) async {
    if (!t.listable) return const [];
    final j = await getVague1(context, routeListe, ReglagesAlertes.parametresListe(t), 'la liste « ${t.titre} »');
    final data = j['data'] ?? j['results'];
    if (data == null) return const [];
    if (data is! List) throw ApiLoadException('Réponse inattendue du serveur pour la liste « ${t.titre} ».', nature: NatureErreur.reponse);
    return [for (final e in data) if (e is Map) LigneAlerte.depuis(Map<String, dynamic>.from(e))];
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Retraits et abandons, ventes modifiées (journaux paginés, clé « results »)
// ---------------------------------------------------------------------------------------------------------------

/// Une page de résultats : lignes et nombre total (pour « Afficher plus »).
class PageResultats<T> {
  final List<T> lignes;
  final int total;
  const PageResultats(this.lignes, this.total);
}

/// Filtres communs des deux journaux. Dates au format de l'API (aaaa-mm-jj), utilisateur et type facultatifs.
class FiltresJournal {
  final DateTime debut;
  final DateTime fin;
  final String utilisateurId;
  final String type;
  final String recherche;
  const FiltresJournal({required this.debut, required this.fin, this.utilisateurId = '', this.type = '', this.recherche = ''});

  FiltresJournal copie({DateTime? debut, DateTime? fin, String? utilisateurId, String? type, String? recherche}) => FiltresJournal(
        debut: debut ?? this.debut,
        fin: fin ?? this.fin,
        utilisateurId: utilisateurId ?? this.utilisateurId,
        type: type ?? this.type,
        recherche: recherche ?? this.recherche,
      );

  Map<String, String> parametres(int start, int limit) => {
        'start': '$start',
        'limit': '$limit',
        'dtStart': DateFormatter.toApiFormat(debut),
        'dtEnd': DateFormatter.toApiFormat(fin),
        'userId': utilisateurId,
        'query': recherche.trim(),
        'type': type,
      };
}

/// Ligne de GET /vente-suppressions.
class SuppressionVente {
  final String id;
  final String type;
  final String venteRef;
  final String produitCip;
  final String produitLibelle;
  final int quantite;
  final String utilisateur;
  final String utilisateurOrigine;
  final String date;
  final String heure;
  const SuppressionVente({
    required this.id,
    required this.type,
    required this.venteRef,
    required this.produitCip,
    required this.produitLibelle,
    required this.quantite,
    required this.utilisateur,
    required this.utilisateurOrigine,
    required this.date,
    required this.heure,
  });

  factory SuppressionVente.depuis(Map<String, dynamic> j) => SuppressionVente(
        id: texteTolerant(j['id']),
        type: texteTolerant(j['typeSuppression']).toUpperCase(),
        venteRef: texteTolerant(j['venteRef']),
        produitCip: texteTolerant(j['produitCip']),
        produitLibelle: texteTolerant(j['produitLibelle']),
        quantite: entierTolerant(j['quantite']),
        utilisateur: texteTolerant(j['userName']),
        utilisateurOrigine: texteTolerant(j['origineUserName']),
        date: texteTolerant(j['date']),
        heure: texteTolerant(j['heure']),
      );

  bool get venteAbandonnee => type == 'VENTE';
  String get typeLibelle => switch (type) {
        'VENTE' => 'Vente abandonnée',
        'PRODUIT' => 'Produit retiré',
        _ => type.isEmpty ? 'Suppression' : type,
      };

  /// « 14/10/2026 à 09:12 » (secondes retirées).
  String get moment => momentJournal(date, heure);
}

/// « 14/10/2026 », « 09:12:30 » → « 14/10/2026 à 09:12 ».
String momentJournal(String date, String heure) {
  final h = heure.length >= 5 ? heure.substring(0, 5) : heure;
  if (date.isEmpty) return h;
  return h.isEmpty ? date : '$date à $h';
}

/// Ligne modifiée d'une vente (avant / après).
class LigneModifiee {
  final String produitCip;
  final String produitLibelle;
  final String action;
  final int? qteAvant;
  final int? qteApres;
  final int? puAvant;
  final int? puApres;
  final int? montantAvant;
  final int? montantApres;
  const LigneModifiee({
    required this.produitCip,
    required this.produitLibelle,
    required this.action,
    this.qteAvant,
    this.qteApres,
    this.puAvant,
    this.puApres,
    this.montantAvant,
    this.montantApres,
  });

  static int? _opt(Object? v) => v == null || (v is String && v.trim().isEmpty) ? null : entierTolerant(v);

  factory LigneModifiee.depuis(Map<String, dynamic> j) => LigneModifiee(
        produitCip: texteTolerant(j['produitCip']),
        produitLibelle: texteTolerant(j['produitLibelle']),
        action: texteTolerant(j['action']).toUpperCase(),
        qteAvant: _opt(j['qteAvant']),
        qteApres: _opt(j['qteApres']),
        puAvant: _opt(j['puAvant']),
        puApres: _opt(j['puApres']),
        montantAvant: _opt(j['montantAvant'] ?? j['valeurAvant']),
        montantApres: _opt(j['montantApres'] ?? j['valeurApres']),
      );

  String get actionLibelle => switch (action) {
        'AJOUT' => 'Produit ajouté',
        'RETRAIT' => 'Produit retiré',
        'QUANTITE' => 'Quantité modifiée',
        'PRIX' => 'Prix modifié',
        'INFO' => 'Information modifiée',
        _ => action.isEmpty ? 'Modification' : action,
      };
}

/// Ligne de GET /ventes-modifiees.
class VenteModifiee {
  final String id;
  final String type;
  final String typeLibelleServeur;
  final String venteRef;
  final String venteDate;
  final String utilisateur;
  final String date;
  final String heure;
  final int? montantAvant;
  final int? montantApres;
  final String description;
  final List<LigneModifiee> lignes;
  const VenteModifiee({
    required this.id,
    required this.type,
    required this.typeLibelleServeur,
    required this.venteRef,
    required this.venteDate,
    required this.utilisateur,
    required this.date,
    required this.heure,
    this.montantAvant,
    this.montantApres,
    required this.description,
    required this.lignes,
  });

  factory VenteModifiee.depuis(Map<String, dynamic> j) {
    final l = j['lignes'];
    return VenteModifiee(
      id: texteTolerant(j['id']),
      type: texteTolerant(j['typeModification']).toUpperCase(),
      typeLibelleServeur: texteTolerant(j['typeLibelle']),
      venteRef: texteTolerant(j['venteRef']),
      venteDate: texteTolerant(j['venteDate']),
      utilisateur: texteTolerant(j['userName']),
      date: texteTolerant(j['date']),
      heure: texteTolerant(j['heure']),
      montantAvant: LigneModifiee._opt(j['montantAvant']),
      montantApres: LigneModifiee._opt(j['montantApres']),
      description: texteTolerant(j['description']),
      lignes: l is List ? [for (final e in l) if (e is Map) LigneModifiee.depuis(Map<String, dynamic>.from(e))] : const [],
    );
  }

  String get typeLibelle {
    if (typeLibelleServeur.isNotEmpty) return typeLibelleServeur;
    return switch (type) {
      'PRODUITS' => 'Modification des produits',
      'INFOS' => 'Modification client / tiers payant',
      'DATE' => 'Modification de la date',
      _ => type.isEmpty ? 'Modification' : type,
    };
  }

  String get moment => momentJournal(date, heure);

  /// Écart après − avant (null si un des deux montants manque).
  int? get ecart => montantAvant == null || montantApres == null ? null : montantApres! - montantAvant!;
}

/// Page {total, results:[…]} (clé « data » acceptée aussi) ; total absent : nombre de lignes reçues.
PageResultats<T> lirePage<T>(Map<String, dynamic> j, T Function(Map<String, dynamic>) lire, String quoi) {
  final liste = j['results'] ?? j['data'];
  if (liste == null) return PageResultats<T>(const [], entierTolerant(j['total']));
  if (liste is! List) throw ApiLoadException('Réponse inattendue du serveur pour $quoi.', nature: NatureErreur.reponse);
  try {
    final lignes = [for (final e in liste) if (e is Map) lire(Map<String, dynamic>.from(e))];
    final total = j.containsKey('total') ? entierTolerant(j['total']) : lignes.length;
    return PageResultats<T>(lignes, total < lignes.length ? lignes.length : total);
  } catch (_) {
    throw ApiLoadException('Données illisibles pour $quoi.', nature: NatureErreur.reponse);
  }
}

class ApiJournaux {
  ApiJournaux._();

  static const routeSuppressions = '/vente-suppressions';
  static const routeModifiees = '/ventes-modifiees';
  static const taillePage = 50;

  static Future<PageResultats<SuppressionVente>> suppressions(BuildContext context, FiltresJournal f, {int start = 0, int limit = taillePage}) async {
    final j = await getVague1(context, routeSuppressions, f.parametres(start, limit), 'les retraits et abandons');
    return lirePage(j, SuppressionVente.depuis, 'les retraits et abandons');
  }

  static Future<PageResultats<VenteModifiee>> modifiees(BuildContext context, FiltresJournal f, {int start = 0, int limit = taillePage}) async {
    final j = await getVague1(context, routeModifiees, f.parametres(start, limit), 'les ventes modifiées');
    return lirePage(j, VenteModifiee.depuis, 'les ventes modifiées');
  }

  /// Utilisateurs (filtre) : GET /common/users (lgUSERID, fullName).
  static Future<List<OptionListe>> utilisateurs(BuildContext context) async {
    final r = await ApiService().get(context, '/common/users', queryParams: {'limit': '9999'});
    if (r is Map) lireReponseVague1(r, 'la liste des utilisateurs');
    return lireOptions(r, champId: 'lgUSERID', champLibelle: 'fullName');
  }
}
