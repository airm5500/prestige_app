// lib/nouvelle_interface/vague3/donnees_vague3.dart
// Vague 3 des nouveaux menus du pharmacien : ÉCRITURES LÉGÈRES dont le droit est vérifié par le serveur Prestige
// (branche claude/new-session-xm8ptu). Décision du pharmacien : consulter et traiter d'abord, AUCUN envoi de message
// (WhatsApp, SMS, e-mail) depuis le mobile.
//  - Pointage BL (web « pointagebl », droit P_SM_POINTAGE_BL, PointageBLRessource) : GET /pointage-bl?grossiste=
//    &groupe=&du=&au=&etat= ; PUT /pointage-bl/pointer/{BL|RETOUR}/{id}?pointe= ; PUT /pointage-bl/sequence/{blId}
//    ?valeur= ; PUT /pointage-bl/avoir/{retourId}?valeur= ; listes /common/grossiste, /common/groupefournisseurs ;
//  - Avis (web « avisclients », droits P_SM_AVIS_CLIENTS / P_AVIS_REPONDRE, AvisClientRessource) :
//    GET /avis-clients/droits, /avis-clients/liste, /avis-clients/analyse ; GET /avis-clients/avis/{id} ÉCRIT (un
//    avis NOUVEAU passe LU) : appelé SEULEMENT quand l'utilisateur touche un avis ([ApiAvis.ouvrir]), jamais en
//    préchargement ; POST /avis-clients/avis/{id}/traiter {statut, noteInterne} si droits.repondre ;
//  - Rappels traitement (web « rappelstraitement », droit P_SM_RAPPELS_HABITUDE, RappelHabitudeRessource) :
//    GET /rappels-habitude/liste (non paginée, 2000 lignes au plus), /compteur, /analyse ; POST
//    /rappels-habitude/marquer?statut=A_PREPARER|PREPARE|ACHETE|ECARTE {ids} après confirmation (ACHETE : 3.14.0) ; depuis la 3.8.0 (réponse
//    du pharmacien : le serveur ne recalcule pas tout seul), POST /rappels-habitude/actualiser À LA DEMANDE (bouton
//    « Actualiser la liste », confirmation, un appui = un appel, recalcul lourd sur un an de ventes, un seul à la fois
//    côté serveur : refus « déjà en cours » affiché) ; aucun message n'est envoyé.
// JAMAIS appelées (envois externes, secrets) : [routesInterditesVague3], refusées AVANT envoi.
// Données des clients (nom, téléphone, e-mail) et de santé (traitement) : affichées seulement, gardées en mémoire le
// temps de l'écran, jamais écrites dans le journal (JournalApp ne note que le chemin, sans paramètres) ni sur le
// disque (aucune préférence, aucun fichier, aucun cache).
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../utils/date_formatter.dart';
import '../vague1/donnees_vague1.dart';

export '../vague1/donnees_vague1.dart' show OptionListe, PageResultats, entierTolerant, decimalTolerant, texteTolerant, booleenTolerant;

// ---------------------------------------------------------------------------------------------------------------
// Appels contrôlés
// ---------------------------------------------------------------------------------------------------------------

/// Routes que le mobile n'appelle JAMAIS (envoi au client ou au patient, réglages et jeton secret de la page d'avis,
/// import du relevé PDF), quelle que soit la méthode. « /rappels-habitude/actualiser » n'y est plus depuis la 3.8.0 :
/// le pharmacien l'a demandée, à la demande seulement (ApiRappels.actualiser : confirmation, un appel par appui).
const routesInterditesVague3 = <String>[
  '/rappels-habitude/envoyer',
  '/rappels-habitude/sms',
  '/avis-clients/reglages',
  '/avis-clients/affiche',
  '/pointage-bl/releve',
  '/pointage-bl/modele',
];

/// Une route est-elle interdite au mobile ? (y compris /avis-clients/avis/{id}/repondre).
bool routeInterditeVague3(String route) {
  final r = route.split('?').first;
  if (routesInterditesVague3.any((i) => r == i || r.startsWith('$i/'))) return true;
  return RegExp(r'^/avis-clients/avis/[^/]+/repondre$').hasMatch(r);
}

/// « Droit manquant : pointer les BL. (message du serveur) Demandez l'accès à l'administrateur. »
String messageDroitVague3(String action, [String serveur = '']) =>
    'Droit manquant : $action.${serveur.isEmpty ? '' : ' ($serveur)'} Demandez l\'accès à l\'administrateur.';

/// Contrôle d'une réponse de la vague 3. [action] : « consulter le pointage des BL », « traiter les avis »…
/// interdit:true ou message d'accès → droit manquant ; autre success:false → demande refusée (message du serveur).
Map<String, dynamic> lireReponseVague3(dynamic r, String action) {
  if (r == null) return <String, dynamic>{};
  if (r is! Map) throw const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse);
  final m = Map<String, dynamic>.from(r);
  final message = texteTolerant(m['msg'] ?? m['message']);
  if (booleenTolerant(m['interdit'])) throw ApiLoadException(messageDroitVague3(action, message), nature: NatureErreur.droit);
  if (m['success'] == false) {
    if (message.isEmpty || estMessageDeDroit(message)) {
      throw ApiLoadException(messageDroitVague3(action, message), nature: NatureErreur.droit);
    }
    throw ApiLoadException(message, nature: NatureErreur.refus);
  }
  return m;
}

Map<String, dynamic> _carte(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _liste(Object? v) => v is List ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)] : const [];

/// Liste `data` (absente : vide ; autre chose qu'une liste : réponse illisible).
List<Map<String, dynamic>> _donnees(Map<String, dynamic> j) {
  final d = j['data'];
  if (d == null) return const [];
  if (d is! List) throw const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse);
  return _liste(d);
}

double? _decimalOuNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) {
    final n = double.tryParse(v.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.'));
    return n == null || !n.isFinite ? null : n;
  }
  return null;
}

class ApiVague3 {
  ApiVague3._();

  /// Lectures : 45 s (comme les autres écrans).
  static const delaiLecture = ApiService.delaiGet;

  static void _controler(String route) {
    if (routeInterditeVague3(route)) {
      throw const ApiLoadException('Action non disponible sur le mobile.', nature: NatureErreur.refus);
    }
  }

  /// Requalifie un 403 en « Droit manquant : [action] ».
  static Future<Map<String, dynamic>> _appel(String action, Future<dynamic> Function() appel) async {
    try {
      return lireReponseVague3(await appel(), action);
    } on ApiLoadException catch (e) {
      if (e.nature == NatureErreur.droit && !e.message.startsWith('Droit manquant')) {
        throw ApiLoadException(messageDroitVague3(action), nature: NatureErreur.droit, code: e.code);
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> get(BuildContext context, String route, Map<String, String> parametres, String action) {
    _controler(route);
    return _appel(action, () => ApiService().get(context, route, queryParams: parametres, delai: delaiLecture));
  }

  static Future<Map<String, dynamic>> put(BuildContext context, String route, Map<String, String> parametres, String action) {
    _controler(route);
    return _appel(action, () => ApiService().put(context, route, queryParams: parametres));
  }

  static Future<Map<String, dynamic>> post(BuildContext context, String route, Map<String, dynamic> corps, String action,
      {Map<String, String>? parametres, Duration? delai}) {
    _controler(route);
    return _appel(action, () => ApiService().postAvecParametres(context, route, corps, queryParams: parametres, delai: delai));
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

  /// Liste de choix (grossistes, groupes) ; l'entrée « Tous » (id ALL) du serveur est retirée.
  static Future<List<OptionListe>> options(BuildContext context, String route, String action) async {
    _controler(route);
    final r = await ApiService().get(context, route, queryParams: {'limit': '9999', 'page': '1', 'start': '0'});
    if (r is Map) lireReponseVague3(r, action);
    return lireOptions(r);
  }
}

/// « 2026-10-12 » → « 12/10/2026 » ; « 12/10/2026 » rendu tel quel ; vide → « — ».
String dateIsoLisible(String s) {
  final t = s.trim();
  if (t.isEmpty) return '—';
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(t);
  return m == null ? t : '${m.group(3)}/${m.group(2)}/${m.group(1)}';
}

/// « 2026-10-12 » → date (null si illisible).
DateTime? dateIso(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s.trim());
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
}

String _deuxChiffres(int n) => n.toString().padLeft(2, '0');

/// « 14/10/2026 09:05 ».
String horodatage(DateTime d) => '${_deuxChiffres(d.day)}/${_deuxChiffres(d.month)}/${d.year} ${_deuxChiffres(d.hour)}:${_deuxChiffres(d.minute)}';

// ---------------------------------------------------------------------------------------------------------------
// Pointage BL
// ---------------------------------------------------------------------------------------------------------------

/// État des pièces affichées (paramètre « etat »).
enum EtatPointage {
  tous('TOUS', 'Toutes'),
  nonPointes('NON_POINTES', 'Non pointées'),
  pointes('POINTES', 'Pointées');

  final String code;
  final String libelle;
  const EtatPointage(this.code, this.libelle);
}

/// Contrôles des saisies du pointage : IDENTIQUES au serveur (PointageBLService.sequence / referenceAvoir) :
/// valeur facultative (vide = effacée) ; sinon [A-Za-z0-9 ./-], 20 caractères au plus (séquence), 40 (avoir).
class ControlePointage {
  ControlePointage._();

  static const maxSequence = 20;
  static const maxAvoir = 40;
  static final caracteres = RegExp(r'[A-Za-z0-9 ./-]');
  static final _sequence = RegExp(r'^[A-Za-z0-9 ./-]{1,20}$');
  static final _avoir = RegExp(r'^[A-Za-z0-9 ./-]{1,40}$');
  static const messageSequence = 'N° de séquence : 20 caractères au plus (chiffres, lettres, - / .).';
  static const messageAvoir = 'Référence d\'avoir : 40 caractères au plus (chiffres, lettres, - / .).';

  /// Valeur envoyée (espaces de début et de fin retirés, comme le web et le serveur).
  static String nettoyer(String v) => v.trim();

  static String? erreurSequence(String v) {
    final s = nettoyer(v);
    return s.isEmpty || _sequence.hasMatch(s) ? null : messageSequence;
  }

  static String? erreurAvoir(String v) {
    final s = nettoyer(v);
    return s.isEmpty || _avoir.hasMatch(s) ? null : messageAvoir;
  }

  /// Période : début ≤ fin et un an au plus (le serveur refuse si début + 1 an < fin), rien dans le futur.
  static String? erreurPeriode(DateTime debut, DateTime fin, DateTime maintenant) {
    final d = DateTime(debut.year, debut.month, debut.day), f = DateTime(fin.year, fin.month, fin.day);
    final aujourdhui = DateTime(maintenant.year, maintenant.month, maintenant.day);
    if (f.isBefore(d)) return 'La date de début doit précéder la date de fin.';
    if (f.isAfter(aujourdhui)) return 'La période ne peut pas être dans le futur.';
    if (DateTime(d.year + 1, d.month, d.day).isBefore(f)) return 'Période trop longue : un an au plus.';
    return null;
  }
}

/// Une pièce : BL, avoir d'un retour (RETOUR) ou manquants à la réception (RECEPTION, non pointable).
class PieceBl {
  final String type;
  final String id;
  final String reference;
  final String referenceAvoir;
  final String sequence;
  final String statut;
  final String date;

  /// Montant HT (négatif pour un avoir, comme le serveur).
  final double montantHt;
  final bool pointable;
  final bool pointe;
  final String pointeLe;
  final String pointePar;
  final String controle;
  final int controleEcarts;

  /// Grossiste de la pièce (identifiant et libellé) : rendu par le serveur seulement s'il le fournit (demande
  /// regroupé dans prestige_vente_app/docs/serveur/TRANSMISSION_SERVEUR_2026-10-15.md (§ 3)) ; vide sinon.
  final String grossisteId;
  final String grossiste;

  const PieceBl({
    required this.type,
    required this.id,
    this.reference = '',
    this.referenceAvoir = '',
    this.sequence = '',
    this.statut = '',
    this.date = '',
    this.montantHt = 0,
    this.pointable = false,
    this.pointe = false,
    this.pointeLe = '',
    this.pointePar = '',
    this.controle = '',
    this.controleEcarts = 0,
    this.grossisteId = '',
    this.grossiste = '',
  });

  factory PieceBl.depuis(Map<String, dynamic> j) {
    final type = texteTolerant(j['type']).toUpperCase();
    return PieceBl(
      type: type,
      id: texteTolerant(j['id']),
      reference: texteTolerant(j['reference']),
      referenceAvoir: texteTolerant(j['referenceAvoir']),
      sequence: texteTolerant(j['sequence']),
      statut: texteTolerant(j['statut']),
      date: texteTolerant(j['date']),
      montantHt: decimalTolerant(j['montantHt']),
      // Une pièce « RECEPTION » n'est jamais pointable (le serveur refuse ce type).
      pointable: booleenTolerant(j['pointable']) && (type == 'BL' || type == 'RETOUR'),
      pointe: booleenTolerant(j['pointe']),
      pointeLe: texteTolerant(j['pointeLe']),
      pointePar: texteTolerant(j['pointePar']),
      controle: texteTolerant(j['controle']),
      controleEcarts: entierTolerant(j['controleEcarts']),
      grossisteId: texteTolerant(j['grossisteId'] ?? j['lgGROSSISTEID']),
      grossiste: texteTolerant(j['grossiste'] ?? j['grossisteLibelle']),
    );
  }

  bool get estBl => type == 'BL';
  bool get estRetour => type == 'RETOUR';
  bool get estAvoir => type != 'BL';

  /// Clé unique (« BL:123 »).
  String get cle => '$type:$id';

  /// N° de séquence modifiable : BL seulement (comme le web).
  bool get sequenceModifiable => pointable && estBl;

  /// Référence d'avoir modifiable : retour seulement (comme le web).
  bool get avoirModifiable => pointable && estRetour;

  String get libelleType => switch (type) {
        'BL' => 'BL',
        'RETOUR' => 'Avoir (retour)',
        'RECEPTION' => 'Avoir (manquants)',
        _ => type,
      };

  PieceBl copie({bool? pointe, String? pointeLe, String? pointePar, String? sequence, String? referenceAvoir}) => PieceBl(
        type: type,
        id: id,
        reference: reference,
        referenceAvoir: referenceAvoir ?? this.referenceAvoir,
        sequence: sequence ?? this.sequence,
        statut: statut,
        date: date,
        montantHt: montantHt,
        pointable: pointable,
        pointe: pointe ?? this.pointe,
        pointeLe: pointeLe ?? this.pointeLe,
        pointePar: pointePar ?? this.pointePar,
        controle: controle,
        controleEcarts: controleEcarts,
        grossisteId: grossisteId,
        grossiste: grossiste,
      );
}

/// Montant d'un grossiste dans un groupe (3.10.0) : BL, avoirs (négatifs), net HT.
class MontantGrossiste {
  final String grossisteId;
  final String libelle;
  final double totalBl;
  final double totalAvoirs;
  final int pieces;
  const MontantGrossiste({required this.grossisteId, required this.libelle, this.totalBl = 0, this.totalAvoirs = 0, this.pieces = 0});

  double get net => totalBl + totalAvoirs;

  factory MontantGrossiste.depuis(Map<String, dynamic> j) => MontantGrossiste(
        grossisteId: texteTolerant(j['grossisteId']),
        libelle: texteTolerant(j['libelle'] ?? j['grossiste']),
        totalBl: decimalTolerant(j['totalBl']),
        // Le serveur rend les avoirs en négatif (comme « totalAvoirs ») : un positif est remis en négatif.
        totalAvoirs: -decimalTolerant(j['totalAvoirs']).abs(),
        pieces: entierTolerant(j['pieces'] ?? j['total']),
      );
}

/// Origine du détail par grossiste d'un groupe.
enum SourceDetailGroupe {
  /// Champ « parGrossiste » du serveur (tous les montants, quel que soit l'état choisi).
  serveur,

  /// Calculé par l'application sur les pièces reçues, qui portent leur grossiste (état « Toutes » seulement).
  pieces,
}

/// Réponse de GET /pointage-bl : pièces et totaux du serveur.
class PointageBl {
  final List<PieceBl> pieces;
  final double totalBl;
  final double totalAvoirs;
  final double net;
  final int pointes;
  final int nonPointes;

  /// Montant par grossiste (champ « parGrossiste » du serveur, s'il existe) ; null : non fourni.
  final List<MontantGrossiste>? parGrossisteServeur;
  const PointageBl(
      {required this.pieces, this.totalBl = 0, this.totalAvoirs = 0, this.net = 0, this.pointes = 0, this.nonPointes = 0, this.parGrossisteServeur});

  factory PointageBl.depuis(Map<String, dynamic> j) {
    final pg = j['parGrossiste'];
    return PointageBl(
      pieces: [for (final p in _donnees(j)) PieceBl.depuis(p)],
      totalBl: decimalTolerant(j['totalBl']),
      totalAvoirs: decimalTolerant(j['totalAvoirs']),
      net: decimalTolerant(j['net']),
      pointes: entierTolerant(j['pointes']),
      nonPointes: entierTolerant(j['nonPointes']),
      parGrossisteServeur: pg is List ? [for (final e in pg) if (e is Map) MontantGrossiste.depuis(Map<String, dynamic>.from(e))] : null,
    );
  }

  /// Montant par grossiste d'un groupe (3.10.0, demande du pharmacien « le montant par grossiste ou par groupe ») :
  ///  - le détail du serveur (« parGrossiste ») s'il le fournit ;
  ///  - sinon calculé sur les pièces, SEULEMENT si toutes portent leur grossiste et si [toutesLesPieces] (état
  ///    « Toutes » : les totaux du serveur portent sur toutes les pièces, le détail doit en faire autant) ;
  ///  - sinon null : le serveur actuel ne dit pas à quel grossiste appartient chaque pièce (le total du groupe reste
  ///    affiché ; demande au serveur : regroupé dans prestige_vente_app/docs/serveur/TRANSMISSION_SERVEUR_2026-10-15.md (§ 3)).
  (List<MontantGrossiste>, SourceDetailGroupe)? detailGroupe({required bool toutesLesPieces}) {
    final s = parGrossisteServeur;
    if (s != null && s.isNotEmpty) return (s, SourceDetailGroupe.serveur);
    if (!toutesLesPieces || pieces.isEmpty || pieces.any((p) => p.grossisteId.isEmpty)) return null;
    final parId = <String, MontantGrossiste>{};
    for (final p in pieces) {
      final a = parId[p.grossisteId];
      parId[p.grossisteId] = MontantGrossiste(
        grossisteId: p.grossisteId,
        libelle: (a?.libelle.isNotEmpty ?? false) ? a!.libelle : (p.grossiste.isEmpty ? p.grossisteId : p.grossiste),
        totalBl: (a?.totalBl ?? 0) + (p.estBl ? p.montantHt : 0),
        totalAvoirs: (a?.totalAvoirs ?? 0) + (p.estBl ? 0 : -p.montantHt.abs()),
        pieces: (a?.pieces ?? 0) + 1,
      );
    }
    final l = parId.values.toList()..sort((a, b) => b.net.compareTo(a.net));
    return (l, SourceDetailGroupe.pieces);
  }

  /// Compteurs recalculés après un pointage (+1 pointée / −1 à pointer, ou l'inverse), pièces remplacées.
  PointageBl avec(List<PieceBl> pieces, {int deltaPointes = 0}) => PointageBl(
        pieces: pieces,
        totalBl: totalBl,
        totalAvoirs: totalAvoirs,
        net: net,
        pointes: (pointes + deltaPointes).clamp(0, 1 << 30),
        nonPointes: (nonPointes - deltaPointes).clamp(0, 1 << 30),
        parGrossisteServeur: parGrossisteServeur,
      );
}

/// Critères du pointage : un grossiste OU un groupe (obligatoire), période, état.
class FiltresPointage {
  final String grossiste;
  final String groupe;
  final DateTime debut;
  final DateTime fin;
  final EtatPointage etat;
  const FiltresPointage({this.grossiste = '', this.groupe = '', required this.debut, required this.fin, this.etat = EtatPointage.tous});

  /// Un grossiste ou un groupe RÉEL est choisi. « ALL » (entrée « Tous » du serveur) n'en est pas un : l'application
  /// ne demande jamais « tous les grossistes » (décision du pharmacien, 3.10.0 : le montant se lit par grossiste ou par
  /// groupe de grossistes).
  bool get complet => _reel(grossiste) || _reel(groupe);

  static bool _reel(String id) => id.trim().isNotEmpty && id.trim().toUpperCase() != 'ALL';

  /// Recherche par groupe (aucun grossiste choisi).
  bool get parGroupe => !_reel(grossiste) && _reel(groupe);

  /// Paramètres envoyés (comme le web : grossiste, groupe, du, au, etat ; le groupe n'est envoyé que sans grossiste).
  Map<String, String> get parametres => {
        'grossiste': _reel(grossiste) ? grossiste.trim() : '',
        'groupe': _reel(grossiste) || !_reel(groupe) ? '' : groupe.trim(),
        'du': DateFormatter.toApiFormat(debut),
        'au': DateFormatter.toApiFormat(fin),
        'etat': etat.code,
      };

  FiltresPointage copie({String? grossiste, String? groupe, DateTime? debut, DateTime? fin, EtatPointage? etat}) => FiltresPointage(
      grossiste: grossiste ?? this.grossiste, groupe: groupe ?? this.groupe, debut: debut ?? this.debut, fin: fin ?? this.fin, etat: etat ?? this.etat);
}

/// Dernier grossiste (ou groupe) utilisé pour une recherche de pointage (3.9.0) : repris à l'ouverture suivante.
/// Le serveur exige un grossiste ou un groupe (PointageBLRessource.criteres : « Choisissez un grossiste ou un groupe
/// de grossistes. ») ; le pharmacien veut le montant par grossiste ou par groupe (3.10.0) : l'application ne demande
/// jamais « tous les grossistes ».
/// Mémorisé sur l'appareil, au format « grossiste:<id> » ou « groupe:<id> ».
class DernierCriterePointage {
  DernierCriterePointage._();

  static const cle = 'pointage_dernier_critere_v1';

  /// (grossiste, groupe) mémorisés, null si rien.
  static Future<(String, String)?> lire() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(cle) ?? '';
      return decoder(v);
    } catch (_) {
      return null;
    }
  }

  static (String, String)? decoder(String v) {
    final i = v.indexOf(':');
    if (i <= 0 || i == v.length - 1) return null;
    final type = v.substring(0, i), id = v.substring(i + 1);
    return switch (type) { 'grossiste' => (id, ''), 'groupe' => ('', id), _ => null };
  }

  static String? encoder(FiltresPointage f) =>
      f.grossiste.isNotEmpty ? 'grossiste:${f.grossiste}' : (f.groupe.isNotEmpty ? 'groupe:${f.groupe}' : null);

  static Future<void> enregistrer(FiltresPointage f) async {
    final v = encoder(f);
    if (v == null) return;
    try {
      await (await SharedPreferences.getInstance()).setString(cle, v);
    } catch (_) {}
  }

  static Future<void> oublier() async {
    try {
      await (await SharedPreferences.getInstance()).remove(cle);
    } catch (_) {}
  }
}

class ApiPointage {
  ApiPointage._();

  static const route = '/pointage-bl';
  static const routeGroupes = '/common/groupefournisseurs';
  static const routeGrossistes = '/common/grossiste';
  static const _lire = 'consulter le pointage des BL';
  static const _ecrire = 'pointer les BL';

  static Future<List<OptionListe>> grossistes(BuildContext context) => ApiVague3.options(context, routeGrossistes, _lire);
  static Future<List<OptionListe>> groupes(BuildContext context) => ApiVague3.options(context, routeGroupes, _lire);

  static Future<PointageBl> liste(BuildContext context, FiltresPointage f) async {
    if (!f.complet) throw const ApiLoadException('Choisissez un grossiste ou un groupe de grossistes.', nature: NatureErreur.refus);
    final j = await ApiVague3.get(context, route, f.parametres, _lire);
    return ApiVague3.lire(() => PointageBl.depuis(j), 'le pointage des BL');
  }

  /// Pointer / dépointer un BL ou un avoir (RETOUR) pointable.
  static Future<void> pointer(BuildContext context, PieceBl p, bool pointe) async {
    if (!p.pointable) throw const ApiLoadException('Cette pièce ne se pointe pas.', nature: NatureErreur.refus);
    await ApiVague3.put(context, '$route/pointer/${Uri.encodeComponent(p.type)}/${Uri.encodeComponent(p.id)}', {'pointe': '$pointe'}, _ecrire);
  }

  /// N° de séquence d'un BL (contrôlé AVANT envoi : rien n'est envoyé si la saisie est refusée).
  static Future<void> sequence(BuildContext context, PieceBl p, String valeur) async {
    if (!p.sequenceModifiable) throw const ApiLoadException('Le N° de séquence se saisit sur un BL.', nature: NatureErreur.refus);
    final e = ControlePointage.erreurSequence(valeur);
    if (e != null) throw ApiLoadException(e, nature: NatureErreur.refus);
    await ApiVague3.put(context, '$route/sequence/${Uri.encodeComponent(p.id)}', {'valeur': ControlePointage.nettoyer(valeur)}, _ecrire);
  }

  /// Référence d'avoir d'un retour (contrôlée AVANT envoi).
  static Future<void> referenceAvoir(BuildContext context, PieceBl p, String valeur) async {
    if (!p.avoirModifiable) throw const ApiLoadException('La référence d\'avoir se saisit sur un retour.', nature: NatureErreur.refus);
    final e = ControlePointage.erreurAvoir(valeur);
    if (e != null) throw ApiLoadException(e, nature: NatureErreur.refus);
    await ApiVague3.put(context, '$route/avoir/${Uri.encodeComponent(p.id)}', {'valeur': ControlePointage.nettoyer(valeur)}, _ecrire);
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Avis
// ---------------------------------------------------------------------------------------------------------------

/// Statut d'un avis.
enum StatutAvis {
  nouveau('NOUVEAU', 'Nouveau'),
  lu('LU', 'Lu'),
  traite('TRAITE', 'Traité');

  final String code;
  final String libelle;
  const StatutAvis(this.code, this.libelle);

  static StatutAvis? de(String code) {
    for (final s in values) {
      if (s.code == code.trim().toUpperCase()) return s;
    }
    return null;
  }
}

/// Filtre de note (paramètre « note »).
enum NoteAvis {
  toutes('', 'Toutes'),
  negatif('NEGATIF', '1 ou 2 étoiles'),
  positif('POSITIF', '4 ou 5 étoiles'),
  cinq('5', '5 étoiles'),
  quatre('4', '4 étoiles'),
  trois('3', '3 étoiles'),
  deux('2', '2 étoiles'),
  une('1', '1 étoile');

  final String code;
  final String libelle;
  const NoteAvis(this.code, this.libelle);
}

/// Filtre de statut (paramètre « statut »).
enum FiltreStatutAvis {
  tous('', 'Tous'),
  nouveaux('NOUVEAU', 'Nouveaux'),
  lus('LU', 'Lus'),
  traites('TRAITE', 'Traités'),
  nonTraites('NON_TRAITE', 'Non traités');

  final String code;
  final String libelle;
  const FiltreStatutAvis(this.code, this.libelle);
}

/// Tri (paramètre « tri »).
enum TriAvis {
  recents('DATE_DESC', 'Plus récents'),
  anciens('DATE_ASC', 'Plus anciens'),
  notesBasses('NOTE_ASC', 'Notes basses'),
  notesHautes('NOTE_DESC', 'Notes hautes');

  final String code;
  final String libelle;
  const TriAvis(this.code, this.libelle);
}

/// Contrôles des saisies des avis (mêmes bornes que le serveur).
class ControleAvis {
  ControleAvis._();

  /// Note interne : 1500 caractères au plus (Texte.libre(noteInterne, 1500)).
  static const maxNoteInterne = 1500;

  /// Mot-clé : un mot (lettres, chiffres, apostrophe, tiret), 40 caractères au plus.
  static const maxMotCle = 40;
  static final caracteresMotCle = RegExp(r"[\p{L}\p{N}'’-]", unicode: true);

  static final _invisibles = RegExp('[${_plages(const [(0x00, 0x09), (0x0B, 0x1F), (0x7F, 0x7F), (0x200B, 0x200F), (0x202A, 0x202E), (0x2060, 0x2064), (0x2066, 0x2069), (0xFEFF, 0xFEFF)])}]');
  static final _balises = RegExp(r'<[^>]{0,200}>');
  static final _espaces = RegExp('[ ${_plages(const [(0x09, 0x09), (0xA0, 0xA0)])}]+');

  /// Classe de caractères « a-b » écrite par codes (aucun caractère invisible dans le source).
  static String _plages(List<(int, int)> p) => [for (final (a, b) in p) '${String.fromCharCode(a)}-${String.fromCharCode(b)}'].join();
  static final _lignes = RegExp(r'\n{3,}');

  /// Nettoyage IDENTIQUE au serveur (Texte.libre) : sauts de ligne gardés (deux au plus de suite), caractères
  /// invisibles et balises retirés, espaces réduits, borné à 1500 caractères. Vide → '' (le serveur garde null).
  static String nettoyerNoteInterne(String v) {
    var s = v.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    s = s.replaceAll(_invisibles, '');
    s = s.replaceAll(_balises, ' ');
    s = s.replaceAll(_espaces, ' ');
    s = s.replaceAll(_lignes, '\n\n').trim();
    if (s.length > maxNoteInterne) s = s.substring(0, maxNoteInterne).trim();
    return s;
  }

  /// Refus avant envoi : seulement une note trop longue (le reste est nettoyé comme le serveur).
  static String? erreurNoteInterne(String v) =>
      v.length > maxNoteInterne ? 'Note interne : $maxNoteInterne caractères au plus.' : null;

  static String? erreurMotCle(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    if (s.length > maxMotCle) return 'Mot-clé : $maxMotCle caractères au plus.';
    if (!RegExp(r"^[\p{L}\p{N}'’-]+$", unicode: true).hasMatch(s)) return 'Mot-clé : un seul mot (lettres, chiffres).';
    return null;
  }
}

/// Droits de l'utilisateur sur les avis (GET /avis-clients/droits).
class DroitsAvis {
  final bool repondre;
  final int nouveaux;
  final Map<String, String> criteres;
  final List<String> themes;
  const DroitsAvis({this.repondre = false, this.nouveaux = 0, this.criteres = const {}, this.themes = const []});

  factory DroitsAvis.depuis(Map<String, dynamic> j) => DroitsAvis(
        repondre: booleenTolerant(j['repondre']),
        nouveaux: entierTolerant(j['nouveaux']),
        criteres: {for (final e in _carte(j['criteres']).entries) e.key: texteTolerant(e.value)},
        themes: [for (final t in (j['themes'] is List ? j['themes'] as List : const [])) if (texteTolerant(t).isNotEmpty) texteTolerant(t)],
      );
}

/// Un avis (ligne de la liste ou détail).
class Avis {
  final String id;
  final String date;
  final int note;

  /// Critères appréciés (PLUS) ou à améliorer (MOINS), par clé (ACCUEIL…).
  final Map<String, String> criteres;
  final String texte;
  final String employe;
  final bool anonyme;
  final String nom;
  final String telephone;
  final String email;
  final bool rappel;
  final StatutAvis? statut;
  final String dateLu;
  final String noteInterne;
  final String reponse;
  final String canalReponse;
  final String statutReponse;
  final String dateReponse;
  final String auteurReponse;
  final bool reponseAttendue;

  /// Autres avis du même appareil (détail seulement).
  final int? memeAppareil;

  const Avis({
    required this.id,
    this.date = '',
    this.note = 0,
    this.criteres = const {},
    this.texte = '',
    this.employe = '',
    this.anonyme = false,
    this.nom = '',
    this.telephone = '',
    this.email = '',
    this.rappel = false,
    this.statut,
    this.dateLu = '',
    this.noteInterne = '',
    this.reponse = '',
    this.canalReponse = '',
    this.statutReponse = '',
    this.dateReponse = '',
    this.auteurReponse = '',
    this.reponseAttendue = false,
    this.memeAppareil,
  });

  factory Avis.depuis(Map<String, dynamic> j) => Avis(
        id: texteTolerant(j['id']),
        date: texteTolerant(j['date']),
        note: entierTolerant(j['note']).clamp(0, 5),
        criteres: {for (final e in _carte(j['criteres']).entries) e.key: texteTolerant(e.value).toUpperCase()},
        texte: texteTolerant(j['texte']),
        employe: texteTolerant(j['employe']),
        anonyme: booleenTolerant(j['anonyme']),
        nom: texteTolerant(j['nom']),
        telephone: texteTolerant(j['telephone']),
        email: texteTolerant(j['email']),
        rappel: booleenTolerant(j['rappel']),
        statut: StatutAvis.de(texteTolerant(j['statut'])),
        dateLu: texteTolerant(j['dateLu']),
        noteInterne: texteTolerant(j['noteInterne']),
        reponse: texteTolerant(j['reponse']),
        canalReponse: texteTolerant(j['canalReponse']),
        statutReponse: texteTolerant(j['statutReponse']),
        dateReponse: texteTolerant(j['dateReponse']),
        auteurReponse: texteTolerant(j['auteurReponse']),
        reponseAttendue: booleenTolerant(j['reponseAttendue']),
        memeAppareil: j['memeAppareil'] == null ? null : entierTolerant(j['memeAppareil']),
      );

  bool get negatif => note > 0 && note <= 2;
  bool get positif => note >= 4;

  /// Même avis avec un autre statut (liste mise à jour après ouverture ou traitement, sans relecture).
  Avis avecStatut(StatutAvis? s, {String? noteInterne}) => Avis(
        id: id,
        date: date,
        note: note,
        criteres: criteres,
        texte: texte,
        employe: employe,
        anonyme: anonyme,
        nom: nom,
        telephone: telephone,
        email: email,
        rappel: rappel,
        statut: s,
        dateLu: dateLu,
        noteInterne: noteInterne ?? this.noteInterne,
        reponse: reponse,
        canalReponse: canalReponse,
        statutReponse: statutReponse,
        dateReponse: dateReponse,
        auteurReponse: auteurReponse,
        reponseAttendue: reponseAttendue,
        memeAppareil: memeAppareil,
      );
}

/// Filtres de la liste des avis.
class FiltresAvis {
  final DateTime debut;
  final DateTime fin;
  final NoteAvis note;
  final FiltreStatutAvis statut;
  final String contient;
  final String motCle;

  /// Clé d'employé (champ « cle » des employés de l'analyse) et son libellé.
  final String employe;
  final String libelleEmploye;
  final String theme;
  final bool reponseAttendue;
  final TriAvis tri;

  const FiltresAvis({
    required this.debut,
    required this.fin,
    this.note = NoteAvis.toutes,
    this.statut = FiltreStatutAvis.tous,
    this.contient = '',
    this.motCle = '',
    this.employe = '',
    this.libelleEmploye = '',
    this.theme = '',
    this.reponseAttendue = false,
    this.tri = TriAvis.recents,
  });

  /// Période par défaut du web : les 30 derniers jours (aujourd'hui − 29 → aujourd'hui).
  factory FiltresAvis.parDefaut(DateTime maintenant) {
    final j = DateTime(maintenant.year, maintenant.month, maintenant.day);
    return FiltresAvis(debut: DateTime(j.year, j.month, j.day - 29), fin: j);
  }

  Map<String, String> parametres({int start = 0, int limit = ApiAvis.taillePage}) => {
        'du': DateFormatter.toApiFormat(debut),
        'au': DateFormatter.toApiFormat(fin),
        'note': note.code,
        'statut': statut.code,
        'contient': contient,
        'motCle': motCle,
        'employe': employe,
        'theme': theme,
        'reponse': reponseAttendue ? 'ATTENDUE' : '',
        'tri': tri.code,
        'start': '$start',
        'limit': '$limit',
      };

  /// Nombre de filtres actifs de la feuille (période, recherche et tri non compris).
  int get actifs => [note != NoteAvis.toutes, statut != FiltreStatutAvis.tous, motCle.isNotEmpty, employe.isNotEmpty, theme.isNotEmpty, reponseAttendue]
      .where((x) => x)
      .length;

  List<String> get etiquettes => [
        if (note != NoteAvis.toutes) 'Note : ${note.libelle}',
        if (statut != FiltreStatutAvis.tous) 'Statut : ${statut.libelle}',
        if (motCle.isNotEmpty) 'Mot-clé : $motCle',
        if (employe.isNotEmpty) 'Employé : ${libelleEmploye.isEmpty ? employe : libelleEmploye}',
        if (theme.isNotEmpty) 'Thème : $theme',
        if (reponseAttendue) 'Réponse attendue',
      ];

  FiltresAvis copie({
    DateTime? debut,
    DateTime? fin,
    NoteAvis? note,
    FiltreStatutAvis? statut,
    String? contient,
    String? motCle,
    String? employe,
    String? libelleEmploye,
    String? theme,
    bool? reponseAttendue,
    TriAvis? tri,
  }) =>
      FiltresAvis(
        debut: debut ?? this.debut,
        fin: fin ?? this.fin,
        note: note ?? this.note,
        statut: statut ?? this.statut,
        contient: contient ?? this.contient,
        motCle: motCle ?? this.motCle,
        employe: employe ?? this.employe,
        libelleEmploye: libelleEmploye ?? this.libelleEmploye,
        theme: theme ?? this.theme,
        reponseAttendue: reponseAttendue ?? this.reponseAttendue,
        tri: tri ?? this.tri,
      );

  /// Filtres de la feuille retirés (période, recherche et tri gardés).
  FiltresAvis sansFiltres() => FiltresAvis(debut: debut, fin: fin, contient: contient, tri: tri);
}

/// Synthèse de l'analyse des avis.
class SyntheseAvis {
  final int nombre;
  final double moyenne;
  final double satisfaits;
  final double mecontents;
  final int nouveaux;
  final int negatifsNonTraites;
  final int reponsesAttendues;
  final int precedentNombre;
  final double precedentMoyenne;
  final double precedentSatisfaits;
  const SyntheseAvis({
    this.nombre = 0,
    this.moyenne = 0,
    this.satisfaits = 0,
    this.mecontents = 0,
    this.nouveaux = 0,
    this.negatifsNonTraites = 0,
    this.reponsesAttendues = 0,
    this.precedentNombre = 0,
    this.precedentMoyenne = 0,
    this.precedentSatisfaits = 0,
  });

  factory SyntheseAvis.depuis(Map<String, dynamic> j) {
    final p = _carte(j['precedent']);
    return SyntheseAvis(
      nombre: entierTolerant(j['nombre']),
      moyenne: decimalTolerant(j['moyenne']),
      satisfaits: decimalTolerant(j['satisfaits']),
      mecontents: decimalTolerant(j['mecontents']),
      nouveaux: entierTolerant(j['nouveaux']),
      negatifsNonTraites: entierTolerant(j['negatifsNonTraites']),
      reponsesAttendues: entierTolerant(j['reponsesAttendues']),
      precedentNombre: entierTolerant(p['nombre']),
      precedentMoyenne: decimalTolerant(p['moyenne']),
      precedentSatisfaits: decimalTolerant(p['satisfaits']),
    );
  }
}

class CritereAvis {
  final String cle;
  final String libelle;
  final int plus;
  final int moins;
  final int? satisfaction;
  const CritereAvis(this.cle, this.libelle, this.plus, this.moins, this.satisfaction);
}

class ThemeAvis {
  final String theme;
  final int nombre;
  final double moyenne;
  final int negatifs;
  final int positifs;
  final int precedent;
  const ThemeAvis(this.theme, this.nombre, this.moyenne, this.negatifs, this.positifs, this.precedent);
}

class EmployeAvis {
  final String cle;
  final String employe;
  final int nombre;
  final double moyenne;
  final int negatifs;
  final int positifs;
  const EmployeAvis(this.cle, this.employe, this.nombre, this.moyenne, this.negatifs, this.positifs);
}

class MotCleAvis {
  final String cle;
  final String mot;
  final int nombre;
  final String ton;
  const MotCleAvis(this.cle, this.mot, this.nombre, this.ton);
}

class PeriodeAvis {
  final String periode;
  final int nombre;
  final double moyenne;
  final int negatifs;
  const PeriodeAvis(this.periode, this.nombre, this.moyenne, this.negatifs);
}

/// Alerte de l'analyse, avec le filtre de la liste qu'elle propose (ou null).
class AlerteAvis {
  final String niveau;
  final String texte;
  final Map<String, String>? filtre;
  const AlerteAvis(this.niveau, this.texte, this.filtre);

  bool get haute => niveau == 'haute';
}

/// Réponse de GET /avis-clients/analyse.
class AnalyseAvis {
  final SyntheseAvis synthese;

  /// Répartition par note (5 → 1) : (note, nombre, part %).
  final List<(int, int, double)> repartition;
  final List<PeriodeAvis> evolution;
  final List<CritereAvis> criteres;
  final List<ThemeAvis> themes;
  final List<MotCleAvis> motsCles;
  final List<EmployeAvis> employes;
  final List<String> forts;
  final List<String> faibles;
  final List<AlerteAvis> alertes;
  const AnalyseAvis({
    this.synthese = const SyntheseAvis(),
    this.repartition = const [],
    this.evolution = const [],
    this.criteres = const [],
    this.themes = const [],
    this.motsCles = const [],
    this.employes = const [],
    this.forts = const [],
    this.faibles = const [],
    this.alertes = const [],
  });

  factory AnalyseAvis.depuis(Map<String, dynamic> j) {
    final bilan = _carte(j['bilan']);
    List<String> textes(Object? v) => [for (final t in (v is List ? v : const [])) if (texteTolerant(t).isNotEmpty) texteTolerant(t)];
    return AnalyseAvis(
      synthese: SyntheseAvis.depuis(_carte(j['synthese'])),
      repartition: [
        for (final r in _liste(j['repartition'])) (entierTolerant(r['note']), entierTolerant(r['nombre']), decimalTolerant(r['part'])),
      ],
      evolution: [
        for (final e in _liste(j['evolution']))
          PeriodeAvis(texteTolerant(e['periode']), entierTolerant(e['nombre']), decimalTolerant(e['moyenne']), entierTolerant(e['negatifs'])),
      ],
      criteres: [
        for (final c in _liste(j['criteres']))
          CritereAvis(texteTolerant(c['cle']), texteTolerant(c['libelle']), entierTolerant(c['plus']), entierTolerant(c['moins']),
              _decimalOuNull(c['satisfaction'])?.round()),
      ],
      themes: [
        for (final t in _liste(j['themes']))
          ThemeAvis(texteTolerant(t['theme']), entierTolerant(t['nombre']), decimalTolerant(t['moyenne']), entierTolerant(t['negatifs']),
              entierTolerant(t['positifs']), entierTolerant(t['precedent'])),
      ],
      motsCles: [
        for (final m in _liste(j['motsCles']))
          MotCleAvis(texteTolerant(m['cle']), texteTolerant(m['mot']), entierTolerant(m['nombre']), texteTolerant(m['ton'])),
      ],
      employes: [
        for (final e in _liste(j['employes']))
          EmployeAvis(texteTolerant(e['cle']), texteTolerant(e['employe']), entierTolerant(e['nombre']), decimalTolerant(e['moyenne']),
              entierTolerant(e['negatifs']), entierTolerant(e['positifs'])),
      ],
      forts: textes(bilan['forts']),
      faibles: textes(bilan['faibles']),
      alertes: [
        for (final a in _liste(j['alertes']))
          AlerteAvis(texteTolerant(a['niveau']), texteTolerant(a['texte']),
              a['filtre'] is Map ? {for (final e in _carte(a['filtre']).entries) e.key: texteTolerant(e.value)} : null),
      ],
    );
  }
}

class ApiAvis {
  ApiAvis._();

  static const taillePage = 50;
  static const routeDroits = '/avis-clients/droits';
  static const routeListe = '/avis-clients/liste';
  static const routeAnalyse = '/avis-clients/analyse';
  static const _lire = 'consulter les avis clients';
  static const _traiter = 'traiter les avis clients';

  /// Chemin du détail d'un avis (GET qui ÉCRIT : NOUVEAU → LU).
  static String routeAvis(String id) => '/avis-clients/avis/${Uri.encodeComponent(id)}';
  static String routeTraiter(String id) => '${routeAvis(id)}/traiter';

  static Future<DroitsAvis> droits(BuildContext context) async {
    final j = await ApiVague3.get(context, routeDroits, const {}, _lire);
    return ApiVague3.lire(() => DroitsAvis.depuis(j), 'les droits des avis');
  }

  static Future<PageResultats<Avis>> liste(BuildContext context, FiltresAvis f, {int start = 0}) async {
    final j = await ApiVague3.get(context, routeListe, f.parametres(start: start), _lire);
    return ApiVague3.lire(() => PageResultats([for (final a in _donnees(j)) Avis.depuis(a)], entierTolerant(j['total'])), 'les avis');
  }

  /// Détail d'un avis. ATTENTION : le serveur passe l'avis NOUVEAU à LU. À n'appeler que sur un appui explicite de
  /// l'utilisateur sur l'avis (jamais en préchargement ni pour rafraîchir une liste).
  /// [marquerLu] = false (3.10.0, demande serveur 22 : `?marquerLu=false`) : relecture SANS marquer l'avis « lu » —
  /// utilisée par « Actualiser » dans le détail, et SEULEMENT sur un serveur qui connaît ce paramètre
  /// (ProfilAcces.serveurRecent) : un serveur plus ancien l'ignorerait et marquerait l'avis.
  static Future<Avis> ouvrir(BuildContext context, String id, {bool marquerLu = true}) async {
    final j = await ApiVague3.get(context, routeAvis(id), marquerLu ? const {} : const {'marquerLu': 'false'}, _lire);
    return ApiVague3.lire(() {
      final d = _carte(j['data']);
      if (d.isEmpty) throw const ApiLoadException('Avis introuvable.', nature: NatureErreur.refus);
      return Avis.depuis(d);
    }, 'l\'avis');
  }

  /// Statut et note interne (nettoyée comme le serveur ; refusée sans envoi si trop longue).
  static Future<Avis?> traiter(BuildContext context, String id, StatutAvis statut, String noteInterne) async {
    final e = ControleAvis.erreurNoteInterne(noteInterne);
    if (e != null) throw ApiLoadException(e, nature: NatureErreur.refus);
    final j = await ApiVague3.post(context, routeTraiter(id), {'statut': statut.code, 'noteInterne': ControleAvis.nettoyerNoteInterne(noteInterne)}, _traiter);
    return ApiVague3.lire(() {
      final d = _carte(j['data']);
      return d.isEmpty ? null : Avis.depuis(d);
    }, 'l\'avis');
  }

  static Future<AnalyseAvis> analyse(BuildContext context, DateTime debut, DateTime fin) async {
    final j = await ApiVague3.get(context, routeAnalyse, {'du': DateFormatter.toApiFormat(debut), 'au': DateFormatter.toApiFormat(fin)}, _lire);
    return ApiVague3.lire(() => AnalyseAvis.depuis(j), 'l\'analyse des avis');
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Rappels traitement
// ---------------------------------------------------------------------------------------------------------------

/// Statut d'un rappel.
enum StatutRappel {
  aPreparer('A_PREPARER', 'À préparer', 'À préparer'),
  prepare('PREPARE', 'Préparé', 'Préparés'),
  ecarte('ECARTE', 'Écarté', 'Écartés'),
  achete('ACHETE', 'Racheté', 'Rachetés');

  final String code;
  final String libelle;
  final String pluriel;
  const StatutRappel(this.code, this.libelle, this.pluriel);

  static StatutRappel? de(String code) {
    for (final s in values) {
      if (s.code == code.trim().toUpperCase()) return s;
    }
    return null;
  }

  /// Statuts que le serveur accepte pour « marquer » (RappelHabitudeServiceImpl.marquer). 3.14.0 (décision 38 du
  /// pharmacien, serveur du 19/10/2026) : « Racheté » se marque aussi à la main (client revenu acheter ailleurs, vente
  /// non rattachée) ; un serveur plus ancien le refuse (« Statut inconnu. ») : message clair, rien de modifié.
  static const marquables = [prepare, achete, ecarte, aPreparer];

  /// Message d'un serveur antérieur au 19/10/2026 qui refuse « Racheté » à la main.
  static const messageServeurAncien = '« Racheté » à la main demande la mise à jour du serveur Prestige (octobre 2026).';
}

/// Filtre de statut de la liste (paramètre « statut »).
enum FiltreStatutRappel {
  aPreparer('A_PREPARER', 'À préparer'),
  enCours('', 'À préparer et préparés'),
  prepares('PREPARE', 'Préparés'),
  ecartes('ECARTE', 'Écartés'),
  achetes('ACHETE', 'Rachetés'),
  tous('TOUS', 'Tous');

  final String code;
  final String libelle;
  const FiltreStatutRappel(this.code, this.libelle);
}

/// Date prévue du prochain achat (paramètres dtStart / dtEnd, facultatifs ; la date prévue peut être future).
enum PrevuRappel {
  toutes('Toutes les dates'),
  enRetard('En retard'),
  aujourdhui('Aujourd\'hui'),
  septJours('7 prochains jours'),
  trenteJours('30 prochains jours');

  final String libelle;
  const PrevuRappel(this.libelle);

  /// (dtStart, dtEnd) au jour de [maintenant] ; null = pas de borne.
  (DateTime?, DateTime?) bornes(DateTime maintenant) {
    final j = DateTime(maintenant.year, maintenant.month, maintenant.day);
    return switch (this) {
      PrevuRappel.toutes => (null, null),
      PrevuRappel.enRetard => (null, DateTime(j.year, j.month, j.day - 1)),
      PrevuRappel.aujourdhui => (j, j),
      PrevuRappel.septJours => (j, DateTime(j.year, j.month, j.day + 6)),
      PrevuRappel.trenteJours => (j, DateTime(j.year, j.month, j.day + 29)),
    };
  }
}

/// Recherche des rappels : client, téléphone, produit ou CIP ; 50 caractères au plus.
class ControleRappels {
  ControleRappels._();
  static const maxRecherche = 50;

  /// Sélection : au moins une ligne, 2000 au plus (taille maximale de la liste du serveur).
  static const maxSelection = 2000;

  static String? erreurSelection(int n) => n <= 0 ? 'Choisissez au moins un rappel.' : (n > maxSelection ? 'Trop de rappels choisis ($maxSelection au plus).' : null);
}

class FiltresRappels {
  final FiltreStatutRappel statut;
  final String recherche;
  final PrevuRappel prevu;
  const FiltresRappels({this.statut = FiltreStatutRappel.aPreparer, this.recherche = '', this.prevu = PrevuRappel.toutes});

  Map<String, String> parametres(DateTime maintenant) {
    final (d, f) = prevu.bornes(maintenant);
    return {
      'statut': statut.code,
      'query': recherche,
      'dtStart': d == null ? '' : DateFormatter.toApiFormat(d),
      'dtEnd': f == null ? '' : DateFormatter.toApiFormat(f),
    };
  }

  FiltresRappels copie({FiltreStatutRappel? statut, String? recherche, PrevuRappel? prevu}) =>
      FiltresRappels(statut: statut ?? this.statut, recherche: recherche ?? this.recherche, prevu: prevu ?? this.prevu);
}

/// Une ligne « rappel » : un produit habituel d'un client.
class Rappel {
  final String id;
  final String clientId;
  final String client;
  final String telephone;
  final String cip;
  final String produit;
  final int stock;
  final String dernierAchat;
  final String prevu;
  final int frequence;
  final StatutRappel? statut;

  /// Date d'envoi d'un rappel (millisecondes), ou null.
  final DateTime? envoi;
  final String traitePar;
  const Rappel({
    required this.id,
    this.clientId = '',
    this.client = '',
    this.telephone = '',
    this.cip = '',
    this.produit = '',
    this.stock = 0,
    this.dernierAchat = '',
    this.prevu = '',
    this.frequence = 0,
    this.statut,
    this.envoi,
    this.traitePar = '',
  });

  factory Rappel.depuis(Map<String, dynamic> j) {
    final e = j['envoi'];
    return Rappel(
      id: texteTolerant(j['id']),
      clientId: texteTolerant(j['clientId']),
      client: texteTolerant(j['client']),
      telephone: texteTolerant(j['telephone']),
      cip: texteTolerant(j['cip']),
      produit: texteTolerant(j['produit']),
      stock: entierTolerant(j['stock']),
      dernierAchat: texteTolerant(j['dernierAchat']),
      prevu: texteTolerant(j['prevu']),
      frequence: entierTolerant(j['frequence']),
      statut: StatutRappel.de(texteTolerant(j['statut'])),
      envoi: e is num && e > 0 ? DateTime.fromMillisecondsSinceEpoch(e.round()) : null,
      traitePar: texteTolerant(j['traitePar']),
    );
  }

  /// Prévu avant aujourd'hui.
  bool enRetard(DateTime maintenant) {
    final p = dateIso(prevu);
    return p != null && p.isBefore(DateTime(maintenant.year, maintenant.month, maintenant.day));
  }
}

/// Compteurs d'une période (total ou un mois) de l'analyse des rappels.
class CompteurRappels {
  final String mois;
  final int total;
  final int aPreparer;
  final int prepares;
  final int ecartes;
  final int rachetes;
  final int envoyes;
  final int rachetesApresEnvoi;
  final double efficacite;
  final Map<String, int> canaux;
  const CompteurRappels({
    this.mois = '',
    this.total = 0,
    this.aPreparer = 0,
    this.prepares = 0,
    this.ecartes = 0,
    this.rachetes = 0,
    this.envoyes = 0,
    this.rachetesApresEnvoi = 0,
    this.efficacite = 0,
    this.canaux = const {},
  });

  factory CompteurRappels.depuis(Map<String, dynamic> j) => CompteurRappels(
        mois: texteTolerant(j['mois']),
        total: entierTolerant(j['total']),
        aPreparer: entierTolerant(j['aPreparer']),
        prepares: entierTolerant(j['prepares']),
        ecartes: entierTolerant(j['ecartes']),
        rachetes: entierTolerant(j['rachetes']),
        envoyes: entierTolerant(j['envoyes']),
        rachetesApresEnvoi: entierTolerant(j['rachetesApresEnvoi']),
        efficacite: decimalTolerant(j['efficacite']),
        canaux: {for (final e in _carte(j['canaux']).entries) e.key: entierTolerant(e.value)},
      );

  /// « 2026-09 » → « 09/2026 ».
  String get moisLisible {
    final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(mois);
    return m == null ? mois : '${m.group(2)}/${m.group(1)}';
  }
}

class AnalyseRappels {
  final CompteurRappels total;
  final List<CompteurRappels> mois;
  final String debut;
  final String fin;
  const AnalyseRappels({this.total = const CompteurRappels(), this.mois = const [], this.debut = '', this.fin = ''});

  factory AnalyseRappels.depuis(Map<String, dynamic> j) => AnalyseRappels(
        total: CompteurRappels.depuis(_carte(j['total'])),
        mois: [for (final m in _liste(j['mois'])) CompteurRappels.depuis(m)],
        debut: texteTolerant(j['debut']),
        fin: texteTolerant(j['fin']),
      );
}

/// Durée de l'analyse des rappels (mois, jusqu'à aujourd'hui) ; 6 mois par défaut comme le serveur.
enum DureeAnalyseRappels {
  troisMois(3, '3 mois'),
  sixMois(6, '6 mois'),
  douzeMois(12, '12 mois');

  final int mois;
  final String libelle;
  const DureeAnalyseRappels(this.mois, this.libelle);

  /// Du 1er jour du mois (mois − 1) mois avant, à aujourd'hui (même calcul que le serveur pour 6 mois).
  (DateTime, DateTime) bornes(DateTime maintenant) {
    final j = DateTime(maintenant.year, maintenant.month, maintenant.day);
    return (DateTime(j.year, j.month - (mois - 1), 1), j);
  }
}

/// Résultat d'une actualisation (RappelHabitudeServiceImpl.actualiser : inscrits, achetes, habitudes, jour).
class ResultatActualisation {
  final int inscrits;
  final int rachetes;
  final int habitudes;
  const ResultatActualisation(this.inscrits, this.rachetes, this.habitudes);

  factory ResultatActualisation.depuis(Map<String, dynamic> j) =>
      ResultatActualisation(entierTolerant(j['inscrits']), entierTolerant(j['achetes']), entierTolerant(j['habitudes']));

  /// « Liste actualisée : 4 nouveaux rappels, 2 rachetés. »
  String get message {
    String n(int v, String s, String p) => '$v ${v > 1 ? p : s}';
    return 'Liste actualisée : ${n(inscrits, 'nouveau rappel', 'nouveaux rappels')}, ${n(rachetes, 'racheté', 'rachetés')}.';
  }
}

class ApiRappels {
  ApiRappels._();

  static const routeListe = '/rappels-habitude/liste';
  static const routeCompteur = '/rappels-habitude/compteur';
  static const routeAnalyse = '/rappels-habitude/analyse';
  static const routeMarquer = '/rappels-habitude/marquer';
  static const routeActualiser = '/rappels-habitude/actualiser';
  static const _actualiser = 'actualiser les rappels de traitement';

  /// Délai de l'actualisation : le serveur parcourt un an de ventes (comme les calculs longs de la vague 2, en plus
  /// long). Au-delà : « Le serveur ne répond pas » (le calcul peut continuer sur le serveur).
  static const delaiActualisation = Duration(minutes: 5);
  static const _lire = 'consulter les rappels de traitement';
  static const _marquer = 'marquer les rappels de traitement';

  static Future<List<Rappel>> liste(BuildContext context, FiltresRappels f, DateTime maintenant) async {
    final j = await ApiVague3.get(context, routeListe, f.parametres(maintenant), _lire);
    return ApiVague3.lire(() => [for (final r in _donnees(j)) Rappel.depuis(r)], 'les rappels');
  }

  static Future<int> compteur(BuildContext context) async {
    final j = await ApiVague3.get(context, routeCompteur, const {}, _lire);
    return entierTolerant(j['aPreparer']);
  }

  static Future<AnalyseRappels> analyse(BuildContext context, DateTime debut, DateTime fin) async {
    final j = await ApiVague3.get(
        context, routeAnalyse, {'dtStart': DateFormatter.toApiFormat(debut), 'dtEnd': DateFormatter.toApiFormat(fin)}, _lire);
    return ApiVague3.lire(() => AnalyseRappels.depuis(j), 'l\'analyse des rappels');
  }

  /// Recalcule la liste sur le serveur (POST /rappels-habitude/actualiser, sans « jour » : aujourd'hui, corps vide).
  /// Un seul calcul à la fois côté serveur : un second appel pendant le premier est refusé (« Une actualisation est
  /// déjà en cours… », NatureErreur.refus avec ce message). N'envoie AUCUN message au client.
  static Future<ResultatActualisation> actualiser(BuildContext context) async {
    final j = await ApiVague3.post(context, routeActualiser, const {}, _actualiser, delai: delaiActualisation);
    return ResultatActualisation.depuis(j);
  }

  /// Marque les rappels [ids] ; renvoie le nombre modifié par le serveur. Statut et sélection contrôlés AVANT envoi.
  static Future<int> marquer(BuildContext context, List<String> ids, StatutRappel statut) async {
    if (!StatutRappel.marquables.contains(statut)) throw const ApiLoadException('Statut inconnu.', nature: NatureErreur.refus);
    final propres = [for (final i in ids.toSet()) if (i.trim().isNotEmpty) i.trim()];
    final e = ControleRappels.erreurSelection(propres.length);
    if (e != null) throw ApiLoadException(e, nature: NatureErreur.refus);
    try {
      final j = await ApiVague3.post(context, routeMarquer, {'ids': propres}, _marquer, parametres: {'statut': statut.code});
      return entierTolerant(j['modifies']);
    } on ApiLoadException catch (e) {
      // Serveur antérieur au 19/10/2026 : « Racheté » inconnu (RappelHabitudeServiceImpl.marquer → « Statut inconnu. »).
      if (statut == StatutRappel.achete && e.message.contains('Statut inconnu')) {
        throw ApiLoadException(StatutRappel.messageServeurAncien, nature: NatureErreur.refus, code: e.code);
      }
      rethrow;
    }
  }
}
