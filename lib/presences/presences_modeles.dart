// lib/presences/presences_modeles.dart
// Module « Présences » : modèles et règles pures (sans réseau ni écran), testés à part.
//
// Données lues sur les routes RH EXISTANTES de Prestige (droit P_SM_RH, session cookie de /user/auth) :
//   GET  /rh/presence?jour=AAAA-MM-JJ   → {success, data:[RhPresenceDTO], pointages:[{id, employeId, horodatage, sens, source, motif}]}
//   GET  /rh/tableau?du=&au=&employeId= → {success, du, au, data:[RhTableauDTO]}
//   GET  /rh/mobile/code                → {success, code, contenu, resteSec, periodeSec, actif, qr, gps, rayon}
//   GET  /rh/mobile/terminaux           → {success, data:[{id, login, utilisateur, appareil, statut, creeLe, derniereActivite, adresse}]}
// Logique reprise de prestige_vente_app (lib/rh/rh_models.dart, presences_screen.dart), complétée par le seuil
// de retard du pharmacien et le tri « retards et absents en tête ».
import 'package:intl/intl.dart';

String _s(Object? v) => v == null ? '' : '$v'.trim();
int _i(Object? v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;
double _d(Object? v) => v is num ? v.toDouble() : double.tryParse(_s(v).replaceAll(',', '.')) ?? 0;
bool _b(Object? v) => v == true || v == 1 || _s(v) == '1' || _s(v).toLowerCase() == 'true';

/// Horloge du module (remplaçable dans les tests).
class HorlogePresences {
  HorlogePresences._();
  static DateTime Function() maintenant = DateTime.now;
}

/// Jour sans l'heure.
DateTime jourSeul(DateTime d) => DateTime(d.year, d.month, d.day);

/// « AAAA-MM-JJ » (format des routes RH).
String jourCle(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// « 1 h 18 » / « 12 min » / « 0 min ».
String dureeLisible(int minutes) {
  if (minutes <= 0) return '0 min';
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// « 08:30 » → minutes depuis minuit (null si illisible).
int? minutesDuJour(String hhmm) {
  final m = RegExp(r'^(\d{1,2})[:hH](\d{2})').firstMatch(hhmm.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!), mi = int.parse(m.group(2)!);
  if (h > 23 || mi > 59) return null;
  return h * 60 + mi;
}

/// Anomalie du serveur (AnalysePresence.java) traduite en phrase.
String anomalieEnPhrase(String code) => switch (code.trim().toUpperCase()) {
      'ABSENT' => 'Absent sans justification',
      'DOUBLON' => 'Pointage en double',
      'DEUX_ENTREES' => 'Deux arrivées de suite',
      'SORTIE_SANS_ENTREE' => 'Départ sans arrivée',
      'ENTREE_SANS_SORTIE' => 'Arrivée sans départ',
      'POINTAGE_EN_CONGE' => 'A pointé pendant un congé',
      'HORS_PLANNING' => 'Pointé hors planning',
      'JOURNEE_LONGUE' => 'Journée anormalement longue',
      final c => c.isEmpty ? '' : '${c[0]}${c.substring(1).toLowerCase().replaceAll('_', ' ')}',
    };

/// Source d'un pointage (t_pointage.source).
String sourceLisible(String source) => switch (source.trim().toUpperCase()) {
      'MOBILE' => 'Téléphone',
      'POINTEUSE' => 'Pointeuse',
      'MANUEL' => 'Saisie manuelle',
      '' => 'Source inconnue',
      final s => s[0] + s.substring(1).toLowerCase(),
    };

/// Absence validée (« CONGE », « MALADIE (matin) ») en clair : « congé », « maladie (matin) ».
String absenceLisible(String absence) {
  final t = absence.trim();
  final i = t.indexOf(' ');
  final type = (i < 0 ? t : t.substring(0, i)).toUpperCase();
  final reste = i < 0 ? '' : t.substring(i);
  final libelle = switch (type) {
    'CONGE' => 'congé',
    'MALADIE' => 'maladie',
    'REPOS' => 'repos',
    'AUTRE' => 'autre absence',
    _ => type.toLowerCase().replaceAll('_', ' '),
  };
  return '$libelle$reste';
}

/// Statut affiché d'un employé pour un jour (ordre = ordre de tri : les plus urgents d'abord).
enum StatutPresence { absent, enRetard, anomalie, partiTot, attendu, present, conge, repos }

extension StatutPresenceInfo on StatutPresence {
  String get libelle => switch (this) {
        StatutPresence.absent => 'Absent',
        StatutPresence.enRetard => 'En retard',
        StatutPresence.anomalie => 'Anomalie',
        StatutPresence.partiTot => 'Parti tôt',
        StatutPresence.attendu => 'Attendu',
        StatutPresence.present => 'Présent',
        StatutPresence.conge => 'Congé',
        StatutPresence.repos => 'Repos',
      };
}

/// Pointage brut du jour (`pointages` de /rh/presence).
class PointageJour {
  final String id;
  final String employeId;

  /// « AAAA-MM-JJ HH:mm » (heure du serveur).
  final String horodatage;

  /// ENTREE / SORTIE / INCONNU.
  final String sens;
  final String source;
  final String motif;
  const PointageJour({this.id = '', required this.employeId, required this.horodatage, this.sens = '', this.source = '', this.motif = ''});

  factory PointageJour.fromJson(Map<String, dynamic> j) => PointageJour(
        id: _s(j['id']),
        employeId: _s(j['employeId']),
        horodatage: _s(j['horodatage']),
        sens: _s(j['sens']).toUpperCase(),
        source: _s(j['source']),
        motif: _s(j['motif']),
      );

  String get jour => horodatage.length >= 10 ? horodatage.substring(0, 10) : '';
  String get heure => horodatage.length >= 16 ? horodatage.substring(11, 16) : horodatage;
  bool get entree => sens == 'ENTREE' || sens == 'ENTRÉE';
  bool get sortie => sens == 'SORTIE';
  String get sensLisible => entree ? 'Arrivée' : (sortie ? 'Départ' : 'Sens inconnu');
}

/// Une ligne de /rh/presence (commonTasks.dto.RhPresenceDTO) : un employé, un jour.
class PresenceJour {
  final String employeId;
  final String employe;
  final String matricule;
  final String jour;

  /// « 08:00-16:00 », « Garde 20:00-08:00 », « Repos » ou vide (rien de prévu).
  final String prevu;
  final String entree;
  final String sortie;
  final int minutesPrevues;
  final int minutesPresence;

  /// Retard en minutes calculé par le serveur (0 sous la tolérance du serveur).
  final int retard;
  final int departAnticipe;
  final int heuresSup;

  /// Absence validée (« CONGE », « MALADIE (matin) »…), vide sinon.
  final String absence;

  /// Codes séparés par des virgules (ABSENT, DOUBLON…).
  final List<String> anomalies;

  /// « 08:02↑ 17:01↓ ».
  final String pointages;

  const PresenceJour({
    required this.employeId,
    this.employe = '',
    this.matricule = '',
    this.jour = '',
    this.prevu = '',
    this.entree = '',
    this.sortie = '',
    this.minutesPrevues = 0,
    this.minutesPresence = 0,
    this.retard = 0,
    this.departAnticipe = 0,
    this.heuresSup = 0,
    this.absence = '',
    this.anomalies = const [],
    this.pointages = '',
  });

  factory PresenceJour.fromJson(Map<String, dynamic> j) => PresenceJour(
        employeId: _s(j['employeId']),
        employe: _s(j['employe']),
        matricule: _s(j['matricule']),
        jour: _s(j['jour']),
        prevu: _s(j['prevu']),
        entree: _s(j['entree']),
        sortie: _s(j['sortie']),
        minutesPrevues: _i(j['minutesPrevues']),
        minutesPresence: _i(j['minutesPresence']),
        retard: _i(j['retard']),
        departAnticipe: _i(j['departAnticipe']),
        heuresSup: _i(j['heuresSup']),
        absence: _s(j['absence']),
        anomalies: [
          for (final a in _s(j['anomalies']).split(RegExp(r'[,;\s]+')))
            if (a.trim().isNotEmpty) a.trim().toUpperCase(),
        ],
        pointages: _s(j['pointages']),
      );

  String get nomAffiche => employe.isEmpty ? (matricule.isEmpty ? 'Employé' : matricule) : employe;
  bool get arrive => entree.isNotEmpty;
  bool get repos => prevu.toLowerCase() == 'repos';

  /// Heure de début prévue (« 08:00-16:00 » → 08:00), null si rien de prévu.
  int? get debutPrevu {
    final m = RegExp(r'(\d{1,2}:\d{2})\s*-\s*\d{1,2}:\d{2}').firstMatch(prevu);
    return m == null ? null : minutesDuJour(m.group(1)!);
  }

  /// Retard en minutes : celui du serveur s'il en donne un, sinon arrivée − heure prévue (le serveur ne compte
  /// pas un retard sous sa propre tolérance, KEY_RH_TOLERANCE_RETARD, 5 min par défaut).
  int get minutesRetard {
    if (retard > 0) return retard;
    final debut = debutPrevu, arrivee = minutesDuJour(entree);
    if (debut == null || arrivee == null) return 0;
    final r = arrivee - debut;
    return r > 0 && r < 12 * 60 ? r : 0;
  }

  /// En retard selon le seuil du pharmacien : arrivée après l'heure prévue + [seuilMinutes].
  bool enRetard(int seuilMinutes) => arrive && minutesRetard > seuilMinutes;

  /// La journée est-elle celle d'aujourd'hui (journée en cours) ?
  bool estAujourdhui(DateTime maintenant) => jour == jourCle(maintenant);

  /// Anomalies à signaler. Aujourd'hui, « Arrivée sans départ » est normal tant que la journée n'est pas finie :
  /// elle n'est pas comptée comme anomalie ; « Absent » est un statut, pas une anomalie.
  List<String> anomaliesASignaler(DateTime maintenant) => [
        for (final a in anomalies)
          if (a != 'ABSENT' && !(a == 'ENTREE_SANS_SORTIE' && estAujourdhui(maintenant))) a,
      ];

  /// Phrases des anomalies à signaler.
  List<String> phrasesAnomalies(DateTime maintenant) => [for (final a in anomaliesASignaler(maintenant)) anomalieEnPhrase(a)];

  /// Statut à afficher, selon le seuil de retard du pharmacien.
  StatutPresence statut(int seuilMinutes, DateTime maintenant) {
    if (anomalies.contains('ABSENT')) {
      // Aujourd'hui, avant l'heure prévue + seuil : pas encore en retard, simplement attendu.
      final debut = debutPrevu;
      if (estAujourdhui(maintenant) && debut != null && maintenant.hour * 60 + maintenant.minute <= debut + seuilMinutes) {
        return StatutPresence.attendu;
      }
      return StatutPresence.absent;
    }
    if (absence.isNotEmpty && !arrive && anomaliesASignaler(maintenant).isEmpty) return StatutPresence.conge;
    if (enRetard(seuilMinutes)) return StatutPresence.enRetard;
    if (anomaliesASignaler(maintenant).isNotEmpty) return StatutPresence.anomalie;
    if (departAnticipe > 0) return StatutPresence.partiTot;
    if (arrive) return StatutPresence.present;
    if (repos) return StatutPresence.repos;
    return StatutPresence.attendu;
  }
}

/// Réponse de /rh/presence pour un jour.
class PresenceDuJour {
  final DateTime jour;
  final List<PresenceJour> lignes;
  final List<PointageJour> pointages;
  const PresenceDuJour({required this.jour, this.lignes = const [], this.pointages = const []});

  /// Pointages d'un employé pour CE jour (la réponse contient aussi ceux du lendemain matin, pour les gardes de
  /// nuit : ils ne sont gardés que s'ils figurent dans la ligne de l'employé).
  List<PointageJour> pointagesDe(PresenceJour ligne) {
    final cle = jourCle(jour);
    return [
      for (final p in pointages)
        if (p.employeId == ligne.employeId && (p.jour == cle || ligne.pointages.contains(p.heure))) p,
    ]..sort((a, b) => a.horodatage.compareTo(b.horodatage));
  }
}

/// Compteurs en tête de la présence du jour.
class CompteursPresence {
  final int presents;
  final int prevus;
  final int retards;
  final int minutesRetard;
  final int absents;
  final int anomalies;
  const CompteursPresence({this.presents = 0, this.prevus = 0, this.retards = 0, this.minutesRetard = 0, this.absents = 0, this.anomalies = 0});

  factory CompteursPresence.de(List<PresenceJour> lignes, int seuil, DateTime maintenant) {
    var presents = 0, prevus = 0, retards = 0, minutes = 0, absents = 0, anomalies = 0;
    for (final l in lignes) {
      if (l.arrive) presents++;
      if (l.minutesPrevues > 0) prevus++;
      final st = l.statut(seuil, maintenant);
      if (l.enRetard(seuil)) {
        retards++;
        minutes += l.minutesRetard;
      }
      if (st == StatutPresence.absent) absents++;
      if (l.anomaliesASignaler(maintenant).isNotEmpty) anomalies++;
    }
    return CompteursPresence(presents: presents, prevus: prevus, retards: retards, minutesRetard: minutes, absents: absents, anomalies: anomalies);
  }
}

/// Tri : absents et retards en tête (les plus gros retards d'abord), puis anomalies, départs anticipés,
/// attendus, présents, congés, repos ; à statut égal, par nom.
List<PresenceJour> trierPresences(Iterable<PresenceJour> lignes, int seuil, DateTime maintenant) {
  final l = [...lignes];
  l.sort((a, b) {
    final sa = a.statut(seuil, maintenant), sb = b.statut(seuil, maintenant);
    if (sa != sb) return sa.index.compareTo(sb.index);
    if (sa == StatutPresence.enRetard && a.minutesRetard != b.minutesRetard) return b.minutesRetard.compareTo(a.minutesRetard);
    return a.nomAffiche.toLowerCase().compareTo(b.nomAffiche.toLowerCase());
  });
  return l;
}

/// Sans accents ni majuscules (recherche par nom).
String sansAccents(String s) {
  const avec = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const sans = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = avec.indexOf(c);
    b.write(i < 0 ? c : sans[i]);
  }
  return b.toString();
}

/// Filtre par nom ou matricule (recherche déjà nettoyée et bornée par Saisie.recherche).
List<PresenceJour> filtrerPresences(List<PresenceJour> lignes, String recherche) {
  final q = sansAccents(recherche.trim());
  if (q.isEmpty) return lignes;
  final mots = q.split(RegExp(r'\s+'));
  return [
    for (final l in lignes)
      if (mots.every((m) => sansAccents('${l.employe} ${l.matricule}').contains(m))) l,
  ];
}

/// Une ligne de /rh/tableau (commonTasks.dto.RhTableauDTO) : un employé sur la période.
class TableauLigne {
  final String employeId;
  final String employe;
  final String matricule;
  final int joursPrevus;
  final int joursPresents;
  final double joursAbsenceJustifiee;
  final int absencesNonJustifiees;
  final int retards;
  final int minutesRetard;
  final int departsAnticipes;
  final int minutesPrevues;
  final int minutesPresence;
  final int heuresSup;
  final int anomalies;

  const TableauLigne({
    required this.employeId,
    this.employe = '',
    this.matricule = '',
    this.joursPrevus = 0,
    this.joursPresents = 0,
    this.joursAbsenceJustifiee = 0,
    this.absencesNonJustifiees = 0,
    this.retards = 0,
    this.minutesRetard = 0,
    this.departsAnticipes = 0,
    this.minutesPrevues = 0,
    this.minutesPresence = 0,
    this.heuresSup = 0,
    this.anomalies = 0,
  });

  factory TableauLigne.fromJson(Map<String, dynamic> j) => TableauLigne(
        employeId: _s(j['employeId']),
        employe: _s(j['employe']),
        matricule: _s(j['matricule']),
        joursPrevus: _i(j['joursPrevus']),
        joursPresents: _i(j['joursPresents']),
        joursAbsenceJustifiee: _d(j['joursAbsenceJustifiee']),
        absencesNonJustifiees: _i(j['absencesNonJustifiees']),
        retards: _i(j['retards']),
        minutesRetard: _i(j['minutesRetard']),
        departsAnticipes: _i(j['departsAnticipes']),
        minutesPrevues: _i(j['minutesPrevues']),
        minutesPresence: _i(j['minutesPresence']),
        heuresSup: _i(j['heuresSup']),
        anomalies: _i(j['anomalies']),
      );

  String get nomAffiche => employe.isEmpty ? (matricule.isEmpty ? 'Employé' : matricule) : employe;

  /// « 1,5 » / « 2 ».
  String get absencesJustifieesTexte {
    final v = joursAbsenceJustifiee;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');
  }
}

/// Réponse de /rh/tableau : période réellement appliquée par le serveur et lignes.
class TableauPeriode {
  final DateTime du;
  final DateTime au;
  final List<TableauLigne> lignes;
  const TableauPeriode({required this.du, required this.au, this.lignes = const []});
}

/// Période d'analyse : jamais à l'envers, jamais plus de [maxJours] jours (limite du serveur), jamais dans le futur.
class PeriodePresence {
  static const int maxJours = 366;
  final DateTime du;
  final DateTime au;

  /// Vrai si la saisie a dû être corrigée (message à afficher).
  final String? correction;
  const PeriodePresence._(this.du, this.au, this.correction);

  factory PeriodePresence.bornee(DateTime du, DateTime au, {DateTime? aujourdhui}) {
    final today = jourSeul(aujourdhui ?? HorlogePresences.maintenant());
    var d = jourSeul(du), a = jourSeul(au);
    String? correction;
    if (a.isAfter(today)) {
      a = today;
      correction = 'La fin de période ne peut pas dépasser aujourd\'hui.';
    }
    if (d.isAfter(a)) {
      d = a;
      correction = 'Le début était après la fin : période ramenée à un jour.';
    }
    if (a.difference(d).inDays > maxJours) {
      d = a.subtract(const Duration(days: maxJours));
      correction = 'Période limitée à $maxJours jours : début ramené au ${DateFormat('dd/MM/yyyy').format(d)}.';
    }
    return PeriodePresence._(d, a, correction);
  }

  /// Du lundi de la semaine à aujourd'hui.
  factory PeriodePresence.semaine(DateTime aujourdhui) {
    final a = jourSeul(aujourdhui);
    return PeriodePresence.bornee(a.subtract(Duration(days: a.weekday - 1)), a, aujourdhui: aujourdhui);
  }

  /// Du 1er du mois à aujourd'hui.
  factory PeriodePresence.mois(DateTime aujourdhui) =>
      PeriodePresence.bornee(DateTime(aujourdhui.year, aujourdhui.month, 1), aujourdhui, aujourdhui: aujourdhui);

  /// Mois précédent complet.
  factory PeriodePresence.moisDernier(DateTime aujourdhui) => PeriodePresence.bornee(
      DateTime(aujourdhui.year, aujourdhui.month - 1, 1), DateTime(aujourdhui.year, aujourdhui.month, 0), aujourdhui: aujourdhui);

  int get nombreJours => au.difference(du).inDays + 1;
  String get texte => '${DateFormat('dd/MM/yyyy').format(du)} → ${DateFormat('dd/MM/yyyy').format(au)}';
  Map<String, String> get parametres => {'du': jourCle(du), 'au': jourCle(au)};
}

/// QR de pointage du moment (/rh/mobile/code).
class CodePointageMoment {
  final String code;
  final String contenu;
  final int resteSec;
  final int periodeSec;
  final bool actif;
  final bool qrExige;
  final bool gpsExige;
  final int rayon;
  const CodePointageMoment({
    required this.code,
    required this.contenu,
    this.resteSec = 60,
    this.periodeSec = 60,
    this.actif = true,
    this.qrExige = true,
    this.gpsExige = false,
    this.rayon = 0,
  });

  factory CodePointageMoment.fromJson(Map<String, dynamic> j) {
    final periode = _i(j['periodeSec']);
    final p = periode <= 0 || periode > 3600 ? 60 : periode;
    final reste = _i(j['resteSec']);
    return CodePointageMoment(
      code: _s(j['code']),
      contenu: _s(j['contenu']).isEmpty ? _s(j['code']) : _s(j['contenu']),
      resteSec: reste <= 0 || reste > p ? p : reste,
      periodeSec: p,
      actif: j['actif'] == null ? true : _b(j['actif']),
      qrExige: j['qr'] == null ? true : _b(j['qr']),
      gpsExige: _b(j['gps']),
      rayon: _i(j['rayon']),
    );
  }

  /// « WPY X5V » (lecture plus facile, saisie à la main possible dans Prestige Vente).
  String get codeAffiche => code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3)}' : code;
}

/// Téléphone enregistré pour le pointage (/rh/mobile/terminaux).
class TerminalMobile {
  final String id;
  final String login;
  final String utilisateur;
  final String appareil;

  /// ACTIF / REVOQUE.
  final String statut;
  final String creeLe;
  final String derniereActivite;
  final String adresse;
  const TerminalMobile({
    required this.id,
    this.login = '',
    this.utilisateur = '',
    this.appareil = '',
    this.statut = '',
    this.creeLe = '',
    this.derniereActivite = '',
    this.adresse = '',
  });

  factory TerminalMobile.fromJson(Map<String, dynamic> j) => TerminalMobile(
        id: _s(j['id']),
        login: _s(j['login']),
        utilisateur: _s(j['utilisateur']),
        appareil: _s(j['appareil']),
        statut: _s(j['statut']).toUpperCase(),
        creeLe: _s(j['creeLe']),
        derniereActivite: _s(j['derniereActivite']),
        adresse: _s(j['adresse']),
      );

  bool get actif => statut == 'ACTIF';
  String get statutLisible => actif ? 'Actif' : (statut == 'REVOQUE' ? 'Retiré' : (statut.isEmpty ? 'Inconnu' : statut));
  String get titre => utilisateur.isEmpty ? (login.isEmpty ? 'Utilisateur inconnu' : login) : utilisateur;
}
