// lib/nouvelle_interface/modules/ca_credit_nouveau.dart
// CA Crédit (ventes à crédit) de la nouvelle interface. Mêmes données et même recherche que l'écran d'origine
// (CaCreditDonnees, lib/donnees/analyses_ventes_donnees.dart) : GET /ca-credit?dtStart=&dtEnd= → liste, recherche
// LOCALE (client, ayant droit, N° de facture, tiers payant ; aucune nouvelle requête). Mise en page refaite : période
// commune chargée dès l'ouverture (« Aujourd'hui », dates par défaut d'origine), recherche contrôlée, tiers payant
// dans la feuille des filtres (filtre local parmi les tiers payants de la période), chiffres clés, cartes
// (téléphone) ou tableau avec total (tablette) construits 50 par 50, détail d'une vente en feuille.
// 3.8.0 (demande du pharmacien) : menu « Exporter » → PDF A4 (AnalysesPdf, lib/donnees/analyses_pdf.dart) des ventes
// AFFICHÉES (recherche et tiers payant appliqués, toutes les lignes), chiffres clés et total identiques à l'écran.
// 3.16.0 (« CA crédit lent ») : réponse décodée hors du fil de l'interface si elle est grosse (CaCreditDonnees.charger),
// recherche et filtre calculés UNE fois par changement (mémoïsés, plus à chaque image), chiffres clés compris ; liste
// construite à la demande (ListView.builder : seules les cartes à l'écran sont construites), toujours 50 par 50.
// La route n'est pas paginée par le serveur : demande serveur 67.
// 3.17.0 (réponse du serveur à la demande 67, déployée plus tard en officine) : la requête porte start=0&limit=50.
//  - Serveur à jour → OBJET { total, montant, clients, tiersPayants, data } : mode PAGINÉ. Chiffres clés et liste des
//    tiers payants lus dans l'objet ; page suivante (start = lignes déjà chargées) demandée près du bas de la liste
//    (indicateur ; « Afficher plus » reste disponible) ; recherche (anti-rebond 300 ms) et tiers payant envoyés au
//    serveur (query, tiersPayant), réponse périmée jamais affichée ; tirer pour rafraîchir = page 0 SANS filtre (le
//    serveur relit alors la base) ; PDF : toutes les ventes filtrées en une requête (limit = total).
//  - Serveur ancien → il ignore ces paramètres et renvoie la LISTE : comportement 3.16.0 (décodage hors du fil de
//    l'interface, recherche et filtre locaux) ; ce mode est retenu pour la session : les requêtes suivantes sont celles
//    de la 3.16.0 (dtStart, dtEnd).
//  - Première page lente (12 à 16 s pour un mois chargé : le serveur lit toute la période) : « Lecture de la
//    période… » dès le départ, délai d'attente de 60 s pour cette route seulement (CaCreditDonnees.delai), jamais deux
//    fois la même lecture en parallèle (⟳ ou recherche pendant la lecture : la lecture en cours est attendue, puis,
//    si la recherche a changé, une seule nouvelle lecture, rapide car la période est gardée par le serveur).
// 3.17.1 (retour du serveur du 20/11, commit serveur 58db6a4e, pas encore déployé en officine) :
//  - repère « luLe » (instant de la lecture du serveur qui sert la page) : celui de la page 0 est gardé ; une page
//    suivante servie par une AUTRE lecture (période relue entre-temps) n'est jamais ajoutée : la page 0 est relue
//    (deux fois de suite au plus, ensuite « Réessayer »), donc ni doublon ni vente oubliée entre les pages ;
//  - « tiersPayantsRetenus » : nombre de tiers payants des ventes retenues par la recherche / le filtre, affiché tel
//    quel (au lieu de celui « de la période ») ;
//  - serveur qui annonce ses routes (tableau-bord/version, lib/donnees/routes_serveur.dart) sans « ca-credit » :
//    requête de la 3.16.0 directement ; serveur sans ces champs : comportement 3.17.0 inchangé.
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;

import '../../donnees/analyses_pdf.dart';
import '../../donnees/analyses_ventes_donnees.dart';
import '../../donnees/cache_court.dart';
import '../../donnees/routes_serveur.dart';
import '../../models/ca_credit_model.dart';
import '../../services/api_service.dart' show ApiLoadException, NatureErreur;
import '../../utils/date_formatter.dart';
import '../charte.dart';
import '../composants.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import 'commun.dart';
import 'commun_lot2.dart';
import 'commun_lot3.dart';
import 'periode.dart';

class CaCreditNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const CaCreditNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<CaCreditNouveau> createState() => _CaCreditNouveauState();
}

/// Lecture de la première page (ou de la liste) : période et filtres envoyés au serveur.
@immutable
class _Demande {
  final Periode periode;
  final String texte;
  final String tiers;
  const _Demande(this.periode, this.texte, this.tiers);

  @override
  bool operator ==(Object o) =>
      o is _Demande && o.periode.debut == periode.debut && o.periode.fin == periode.fin && o.texte == texte && o.tiers == tiers;

  @override
  int get hashCode => Object.hash(periode.debut, periode.fin, texte, tiers);

  bool get filtree => texte.isNotEmpty || tiers.isNotEmpty;
}

class _CaCreditNouveauState extends State<CaCreditNouveau> with AffichageParTranches {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  final _recherche = TextEditingController();
  String _texte = '';

  /// Tiers payant choisi (libellé ; vide = tous).
  String _tiers = '';

  /// Dernière réponse affichée (liste : serveur ancien ; page : serveur à jour), chargement, échec.
  ReponseCaCredit? donnees;
  bool enCours = false;
  Object? erreur;

  /// Génération des lectures : toute réponse d'une génération dépassée est ignorée.
  int _gen = 0;

  /// Lecture de première page en cours (jamais deux fois la même en parallèle).
  ({_Demande demande, Future<void> future})? _vol;

  /// Mode paginé : demande affichée, lignes chargées (pages bout à bout), suite en cours / en échec, fin atteinte.
  _Demande? _lue;
  List<CaCredit> _lignes = const [];
  bool _suiteEnCours = false;
  bool _suiteEnEchec = false;
  bool _fin = false;

  /// Mode paginé (3.17.1) : repère « luLe » de la page 0 affichée (null : serveur qui ne le donne pas).
  int? _luLe;

  /// Relectures de la page 0 enchaînées sur un changement de « luLe » (bornées : jamais de boucle).
  int _relecturesLuLe = 0;
  static const relecturesLuLeMax = 2;

  /// Mode paginé : nombre de ventes de la période sans filtre (s'il est connu) et tiers payants de la période.
  int? _totalSansFiltre;
  List<String> _tiersPeriode = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  /// Mode de la route pour ce serveur et cette session : true paginé, false liste (serveur ancien), null inconnu.
  bool? get _modeConnu => CaCreditDonnees.modeConnu(CacheCourt.source(context));

  bool get _pagine => donnees?.pagine ?? (_modeConnu ?? false);

  /// Ce qu'il faut lire maintenant : en mode liste (serveur ancien), la recherche et le filtre restent locaux.
  _Demande _demandeCourante() => _modeConnu == false ? _Demande(_periode, '', '') : _Demande(_periode, _texte, _tiers);

  /// Période de la requête affichée (le PDF reprend exactement ce qui est affiché).
  Periode? _periodeLue;

  /// Ouverture, période, ⟳, réessai, recherche / tiers payant (mode paginé). Une lecture identique déjà en cours est
  /// reprise telle quelle ; une lecture en cours sur la MÊME période (recherche changée pendant la lecture) est
  /// attendue, puis la demande du moment est lue (la période est alors gardée par le serveur : réponse rapide).
  Future<void> _charger() {
    _relecturesLuLe = 0;
    final d = _demandeCourante();
    final v = _vol;
    if (v != null && (v.demande == d || (v.demande.periode.debut == d.periode.debut && v.demande.periode.fin == d.periode.fin))) {
      setState(() {}); // recherche / filtre affichés en attente
      return v.future;
    }
    return _lancer(d);
  }

  Future<void> _lancer(_Demande d) {
    final g = ++_gen;
    reinitialiserTranches();
    setState(() {
      enCours = true;
      erreur = null;
      donnees = null;
      _lignes = const [];
      _suiteEnCours = false;
      _suiteEnEchec = false;
      _fin = false;
      _ajoutEnAttente = null;
      _periodeLue = null;
      _luLe = null;
      if (_lue == null || _lue!.periode.debut != d.periode.debut || _lue!.periode.fin != d.periode.fin) {
        _totalSansFiltre = null;
        _tiersPeriode = const [];
      }
    });
    final f = _lire(d, g);
    _vol = (demande: d, future: f);
    return f;
  }

  Future<void> _lire(_Demande d, int g) async {
    final source = CacheCourt.source(context);
    // 3.17.1 : serveur qui annonce ses routes sans « ca-credit » paginé → requête de la 3.16.0 (liste) d'emblée.
    if (CaCreditDonnees.modeConnu(source) == null) {
      final etat = await RoutesServeur.etat(RoutesServeur.serveur(context));
      if (!mounted || g != _gen) return;
      if (etat.nonAnnoncee(RoutesServeur.caCredit)) CaCreditDonnees.noterMode(source, false);
    }
    final pagine = CaCreditDonnees.modeConnu(source) != false;
    ReponseCaCredit? r;
    Object? echec;
    try {
      r = await CaCreditDonnees.chargerPage(context, d.periode.debut, d.periode.fin,
          pagine: pagine, query: d.texte, tiersPayant: d.tiers, onSessionInvalid: sessionInvalide(context));
    } catch (e) {
      echec = e;
    }
    if (g == _gen) _vol = null;
    if (!mounted || g != _gen) return;
    if (r != null) CaCreditDonnees.noterMode(source, r.pagine);
    // Recherche, tiers payant (ou mode) changés pendant la lecture : cette réponse est périmée, la demande du moment
    // est lue (une seule fois, même si plusieurs changements ont eu lieu).
    final courante = _demandeCourante();
    if (courante != d && (r == null || r.pagine)) return _lancer(courante);
    if (echec != null) {
      setState(() {
        erreur = echec;
        enCours = false;
      });
      return;
    }
    // Forme inattendue : comme la 3.16.0 (aucune vente).
    final rep = r ?? const ReponseCaCredit.liste(<CaCredit>[]);
    setState(() {
      donnees = rep;
      enCours = false;
      _periodeLue = d.periode;
      _lue = d;
      final p = rep.page;
      if (p != null) {
        _lignes = p.data;
        _fin = p.data.length >= p.total;
        _tiersPeriode = p.tiersPayants;
        _luLe = p.luLe;
        if (!d.filtree) _totalSansFiltre = p.total;
      }
    });
  }

  /// Champ de recherche recréé quand ⟳ efface la recherche (son anti-rebond repart de zéro).
  int _remises = 0;

  /// Tirer pour rafraîchir : serveur à jour → page 0 SANS filtre (le serveur relit la base) ; sinon comme avant.
  Future<void> _rafraichir() {
    if (_pagine && (_texte.isNotEmpty || _tiers.isNotEmpty)) {
      _recherche.clear();
      _remises++;
      _texte = '';
      _tiers = '';
    }
    return _charger();
  }

  /// Mode paginé : la page suivante (mêmes filtres, start = lignes déjà chargées).
  bool get _aSuite => _pagine && donnees?.page != null && !_fin && !enCours;

  /// Page suivante demandée depuis une notification de défilement : elle peut arriver pendant la mise en page (liste
  /// raccourcie) ; la lecture part donc après l'image en cours, une seule fois.
  bool _suitePrevue = false;

  void _suiteBientot() {
    if (_suitePrevue) return;
    _suitePrevue = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _suitePrevue = false;
      if (mounted) _suite();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Défilement en cours (entre le début et la fin d'un défilement, rebond compris).
  bool _defile = false;

  /// Page arrivée pendant un défilement : ajoutée quand la liste s'arrête. La longueur de la liste ne change donc
  /// jamais pendant un rebond en bas de liste (le rebond se terminerait pendant la mise en page de l'image).
  VoidCallback? _ajoutEnAttente;

  void _quandImmobile(VoidCallback ajout) {
    if (_defile) {
      final avant = _ajoutEnAttente;
      _ajoutEnAttente = avant == null
          ? ajout
          : () {
              avant();
              ajout();
            };
    } else {
      ajout();
    }
  }

  bool _surDefilement(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    if (n is ScrollStartNotification) _defile = true;
    if (n is ScrollEndNotification) {
      _defile = false;
      // Fin de défilement notifiée pendant la mise en page : l'ajout attend la fin de l'image (et un nouveau
      // défilement commencé entre-temps le repousse encore).
      if (_ajoutEnAttente != null) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          final a = _ajoutEnAttente;
          if (_defile || a == null || !mounted) return;
          _ajoutEnAttente = null;
          a();
        });
        SchedulerBinding.instance.ensureVisualUpdate();
      }
    }
    // 3.17.0 (mode paginé) : en approchant du bas de la liste, la page suivante est demandée d'elle-même.
    if (n.metrics.extentAfter < 600 && _aSuite && !_suiteEnCours && !_suiteEnEchec) _suiteBientot();
    return false;
  }

  Future<void> _suite() async {
    final d = _lue;
    if (!_aSuite || _suiteEnCours || d == null) return;
    final g = _gen;
    _suiteEnCours = true;
    _suiteEnEchec = false;
    // Indicateur de la page en cours : affiché tout de suite si la liste est immobile, sinon à l'image suivante.
    _quandImmobile(() {
      if (mounted) setState(() {});
    });
    try {
      final r = await CaCreditDonnees.chargerPage(context, d.periode.debut, d.periode.fin,
          start: _lignes.length, query: d.texte, tiersPayant: d.tiers, onSessionInvalid: sessionInvalide(context));
      if (!mounted || g != _gen) return;
      final p = r?.page;
      if (p == null) throw const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse);
      // 3.17.1 : page servie par une autre lecture que la page 0 (période relue par le serveur entre-temps) : elle
      // n'est pas ajoutée (doublons ou oublis possibles à la jointure) ; la page 0 est relue.
      if (_luLe != null && p.luLe != null && p.luLe != _luLe) {
        _suiteEnCours = false;
        if (_relecturesLuLe >= relecturesLuLeMax) throw const ApiLoadException(messageRelue, nature: NatureErreur.reponse);
        _relecturesLuLe++;
        _quandImmobile(() {
          if (mounted && g == _gen) _lancer(d);
        });
        return;
      }
      _quandImmobile(() {
        if (!mounted || g != _gen) return;
        setState(() {
          _lignes = [..._lignes, ...p.data];
          // Page vide ou dernière page : plus rien à demander (au-delà du total, le serveur renvoie une page vide).
          _fin = p.data.isEmpty || _lignes.length >= p.total;
          _suiteEnCours = false;
        });
      });
    } catch (e) {
      if (!mounted || g != _gen) return;
      _suiteEnCours = false;
      _suiteEnEchec = true;
      _quandImmobile(() {
        if (mounted && g == _gen) setState(() {});
      });
      messageResultat(context, DiagnosticErreur.de(e).message, echec: true);
    }
  }

  /// Relectures successives sans lecture stable (3.17.1) : message de la page en échec (« Réessayer »).
  static const messageRelue = 'La période vient d\'être relue par le serveur. Réessayez dans un instant.';

  /// Recherche ou tiers payant changés : serveur à jour → lecture serveur ; serveur ancien → filtre local (3.16.0).
  void _filtresChanges() {
    if (_modeConnu == false) {
      setState(reinitialiserTranches);
      return;
    }
    _charger();
  }

  /// PDF des ventes affichées : mode liste → aucune requête ; mode paginé → toutes les ventes filtrées en une requête
  /// (limit = total ; la période est en général encore gardée par le serveur).
  Future<void> _pdf() async {
    final p = _periodeLue;
    final r = donnees;
    if (enCours || erreur != null || r == null || p == null) {
      messageResultat(context, 'Aucune donnée à exporter', echec: true);
      return;
    }
    final List<CaCredit> l;
    final int ventes;
    final page = r.page;
    if (page == null) {
      final tout = r.liste ?? const <CaCredit>[];
      l = _affichees(tout);
      ventes = tout.length;
    } else {
      final d = _lue!;
      if (page.total == 0) {
        l = const [];
      } else if (_fin) {
        l = _lignes;
      } else {
        try {
          final t = await CaCreditDonnees.chargerPage(context, p.debut, p.fin,
              limit: page.total, query: d.texte, tiersPayant: d.tiers, onSessionInvalid: sessionInvalide(context));
          if (!mounted) return;
          final tp = t?.page;
          if (tp == null) throw const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse);
          l = tp.data;
        } catch (e) {
          if (mounted) messageResultat(context, DiagnosticErreur.de(e).message, echec: true);
          return;
        }
      }
      ventes = _totalSansFiltre ?? l.length;
    }
    if (l.isEmpty) {
      messageResultat(context, 'Aucune donnée à exporter', echec: true);
      return;
    }
    final contenu = contenuPdf(l, ventes,
        periode: p,
        filtres: [
          if (_texte.isNotEmpty) ('Recherche', _texte),
          if (_tiers.isNotEmpty) ('Tiers payant', _tiers.trim()),
        ],
        officine: officineConnectee(context),
        imprimeLe: widget.maintenant());
    try {
      await AnalysesPdf.sortie(contenu, AnalysesPdf.nom('CA_credit', p.debut, p.fin));
    } catch (_) {
      if (mounted) messageResultat(context, 'Erreur lors de la préparation du PDF.', echec: true);
    }
  }

  /// Contenu du PDF : mêmes chiffres clés, mêmes lignes et même total que l'écran.
  static ContenuAnalysePdf contenuPdf(List<CaCredit> l, int ventes,
      {required Periode periode, required List<(String, String)> filtres, required String officine, required DateTime imprimeLe}) {
    final total = CaCreditDonnees.total(l);
    return ContenuAnalysePdf(
      officine: officine,
      titre: 'Ventes à crédit (CA Crédit)',
      periode: periode.resume,
      filtres: filtres,
      imprimeLe: ContenuAnalysePdf.horodatage(imprimeLe),
      chiffres: [
        ('Montant à crédit', formaterMontant(total)),
        ('Ventes', formaterNombre(l.length)),
        ('Clients', formaterNombre({for (final c in l) c.clientName}.length)),
        ('Tiers payants', formaterNombre({for (final c in l) c.tiersPayantLibelle}.length)),
        if (l.length != ventes) ('Ventes de la période (sans filtre)', formaterNombre(ventes)),
      ],
      titreDetail: 'Ventes à crédit',
      colonnes: const ['Date', 'Client', 'Ayant droit', 'N° facture', 'Tiers payant', 'Montant'],
      droite: const {5},
      lignes: [
        for (final c in l) [_date(c), c.clientName, _ayantDroitDistinct(c) ? c.ayantDroitName : '', c.numFacturation, c.tiersPayantLibelle, formaterMontant(c.montant)],
      ],
      total: ['Total', '', '', '', '', formaterMontant(total)],
    );
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  /// Tiers payants proposés : ceux de la période donnés par le serveur (mode paginé), sinon ceux des ventes lues.
  List<String> get _tiersPayants =>
      _pagine ? _tiersPeriode : ({for (final c in donnees?.liste ?? const <CaCredit>[]) c.tiersPayantLibelle}.toList()..sort());

  Future<void> _filtres() async {
    var tiers = _tiers;
    final pagine = _pagine;
    // Libellé affiché sans les espaces autour (certains libellés en base commencent par une espace) ; la valeur
    // envoyée au serveur reste celle qu'il a donnée.
    final options = [for (final t in _tiersPayants) OptionListe(t, pagine ? t.trim() : t)];
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les ventes à crédit',
      effacer: () => tiers = '',
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChoixListe(
          key: const Key('filtre_tiers'),
          libelle: 'Tiers payant',
          icone: Icons.account_balance_outlined,
          options: options,
          erreur: null,
          valeur: tiers,
          tous: 'Tous',
          onChanged: (v) => setState(() => tiers = v),
        ),
        const SizedBox(height: 6),
        Text(pagine ? 'Parmi les tiers payants de la période.' : 'Parmi les tiers payants des ventes de la période (aucune nouvelle requête).',
            style: const TextStyle(color: Charte.gris, fontSize: 13)),
      ]),
    );
    if (!applique || !mounted || tiers == _tiers) return;
    _tiers = tiers;
    _filtresChanges();
  }

  /// Ventes affichées (mode liste) : recherche d'origine puis tiers payant.
  List<CaCredit> _affichees(List<CaCredit> l) => _vue(l).lignes;

  /// Dernier calcul (mémoïsé) : refait seulement si la liste, la recherche ou le tiers payant change.
  ({List<CaCredit> source, String texte, String tiers, VueCaCredit vue})? _memo;

  VueCaCredit _vue(List<CaCredit> l) {
    final m = _memo;
    if (m != null && identical(m.source, l) && m.texte == _texte && m.tiers == _tiers) return m.vue;
    final v = VueCaCredit.calculer(l, _texte, _tiers);
    _memo = (source: l, texte: _texte, tiers: _tiers, vue: v);
    return v;
  }

  static String _date(CaCredit c) => c.mvtDate != null ? DateFormatter.toDisplayFormat(c.mvtDate!).replaceAll('-', '/') : 'N/A';

  static bool _ayantDroitDistinct(CaCredit c) => c.ayantDroitName.isNotEmpty && c.ayantDroitName != c.clientName;

  void _detail(CaCredit c) => ouvrirFeuilleDetail(context, titre: c.clientName, sousTitre: 'Facture ${c.numFacturation}', lignes: [
        if (_ayantDroitDistinct(c)) LigneDetail('Ayant droit', c.ayantDroitName),
        LigneDetail('Date', _date(c)),
        LigneDetail('N° facture', c.numFacturation),
        LigneDetail('Tiers payant', c.tiersPayantLibelle),
        LigneDetail('Montant', formaterMontant(c.montant), gras: true),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ventes à Crédit'), actions: [
          MenuExports(actions: [ActionExport('PDF des ventes à crédit', Icons.picture_as_pdf_outlined, _pdf)]),
          BoutonFiltres(actifs: _tiers.isEmpty ? 0 : 1, onPressed: _filtres),
        ]),
        body: NotificationListener<ScrollNotification>(
          onNotification: _surDefilement,
          child: RefreshIndicator(
            onRefresh: _rafraichir,
            child: LayoutBuilder(builder: (context, c) {
              // Même règle que ListeOuTableau (largeur disponible dans les marges de 16 dp).
              final tableau = c.maxWidth - 32 >= largeurTableau;
              final tete = <Widget>[
                SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
                const SizedBox(height: 8),
                ChampRecherche(
                  key: ValueKey('recherche_ca_credit_$_remises'),
                  controleur: _recherche,
                  libelle: 'Rechercher une vente',
                  aide: 'Client, N° de facture, tiers payant',
                  // Serveur ancien : comme la 3.16.0 ; sinon la recherche part au serveur après 300 ms.
                  antiRebond: Duration(milliseconds: _modeConnu == false ? 500 : 300),
                  enCours: enCours && _pagine && _texte.isNotEmpty,
                  onRecherche: (t) {
                    _texte = t;
                    _filtresChanges();
                  },
                ),
                EtiquettesFiltres(
                  etiquettes: [if (_tiers.isNotEmpty) 'Tiers payant : ${_pagine ? _tiers.trim() : _tiers}'],
                  onRetirer: () {
                    _tiers = '';
                    _filtresChanges();
                  },
                ),
                const SizedBox(height: 8),
              ];
              final corps = _corps(tableau: tableau);
              final avant = tete.length + corps.avant.length;
              return ListView.builder(
                key: const Key('defilement_module'),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: avant + corps.cartes + corps.apres.length,
                itemBuilder: (context, i) {
                  if (i < tete.length) return tete[i];
                  if (i < avant) return corps.avant[i - tete.length];
                  if (i < avant + corps.cartes) return _carte(corps.lignes, i - avant);
                  return corps.apres[i - avant - corps.cartes];
                },
              );
            }),
          ),
        ),
      );

  Widget _carte(List<CaCredit> l, int i) => CarteLigne(
        titre: l[i].clientName,
        lignes: [
          if (_ayantDroitDistinct(l[i])) 'Ayant droit : ${l[i].ayantDroitName}',
          '${_date(l[i])} · Facture ${l[i].numFacturation}',
          'Tiers payant : ${l[i].tiersPayantLibelle}',
        ],
        libelleValeur: 'Montant',
        valeur: formaterMontant(l[i].montant),
        onTap: () => _detail(l[i]),
      );

  /// Texte du chargement : la première lecture d'une période peut être longue sur un serveur à jour (le serveur lit
  /// toute la période) ; une recherche sur une période déjà lue est rapide.
  String get _texteChargement {
    if (_modeConnu == false) return 'Chargement des ventes à crédit…';
    final v = _vol?.demande;
    if (v != null && v.filtree && _lue != null && _lue!.periode.debut == v.periode.debut && _lue!.periode.fin == v.periode.fin) {
      return 'Recherche des ventes à crédit…';
    }
    return 'Lecture de la période…\nUn mois chargé peut demander une quinzaine de secondes.';
  }

  /// Corps de la liste : éléments avant les cartes, nombre de cartes (téléphone, construites à la demande), éléments
  /// après (tableau sur tablette, pied « Afficher plus »).
  ({List<Widget> avant, List<CaCredit> lignes, int cartes, List<Widget> apres}) _corps({required bool tableau}) {
    const rien = <CaCredit>[];
    ({List<Widget> avant, List<CaCredit> lignes, int cartes, List<Widget> apres}) seul(Widget w) => (avant: [w], lignes: rien, cartes: 0, apres: const []);
    if (enCours) return seul(EtatChargement(texte: _texteChargement));
    if (erreur != null) return seul(EtatErreur(erreur: erreur!, reessayer: _charger));
    final page = donnees?.page;
    if (page != null) return _corpsPagine(page, tableau: tableau);
    final tout = donnees?.liste ?? rien;
    if (tout.isEmpty) {
      return seul(const EtatVide(titre: 'Aucune vente à crédit', texte: 'Aucune vente à crédit trouvée pour la période.', icone: Icons.credit_card_outlined));
    }
    final v = _vue(tout);
    final l = v.lignes;
    if (l.isEmpty) {
      return seul(const EtatVide(titre: 'Aucune vente ne correspond', texte: 'Modifiez la recherche ou le filtre.', icone: Icons.filter_alt_off_outlined));
    }
    final n = affichees.clamp(0, l.length);
    final avant = <Widget>[
      GrilleKpi([
        ChiffreCle(libelle: 'Montant à crédit', valeur: formaterMontant(v.total), id: 'montant', enAvant: true),
        ChiffreCle(
          libelle: 'Ventes',
          valeur: formaterNombre(l.length),
          id: 'ventes',
          detail: l.length == tout.length ? null : 'sur ${formaterNombre(tout.length)}',
        ),
        ChiffreCle(libelle: 'Clients', valeur: formaterNombre(v.clients), id: 'clients'),
        ChiffreCle(libelle: 'Tiers payants', valeur: formaterNombre(v.tiersPayants), id: 'tiers'),
      ]),
      const TitreSection('Ventes à crédit'),
    ];
    final apres = <Widget>[
      if (tableau) _tableau(l, n, n == l.length ? formaterMontant(v.total) : null),
      piedTranches(l.length),
    ];
    return (avant: avant, lignes: l, cartes: tableau ? 0 : n, apres: apres);
  }

  /// Mode paginé : chiffres clés du serveur (toutes les lignes retenues, pas seulement la page), lignes chargées,
  /// pied « n affichées sur N » avec la page suivante.
  ({List<Widget> avant, List<CaCredit> lignes, int cartes, List<Widget> apres}) _corpsPagine(PageCaCredit p, {required bool tableau}) {
    final d = _lue;
    final filtree = d != null && d.filtree;
    if (p.total == 0) {
      final w = filtree
          ? const EtatVide(titre: 'Aucune vente ne correspond', texte: 'Modifiez la recherche ou le filtre.', icone: Icons.filter_alt_off_outlined)
          : const EtatVide(titre: 'Aucune vente à crédit', texte: 'Aucune vente à crédit trouvée pour la période.', icone: Icons.credit_card_outlined);
      return (avant: [w], lignes: const [], cartes: 0, apres: const []);
    }
    final l = _lignes;
    final sansFiltre = _totalSansFiltre;
    // Tiers payants : sans filtre, ceux de la période ; avec un tiers payant choisi, un seul ; avec une recherche,
    // ceux des ventes chargées si tout est chargé, sinon ceux de la période (le serveur ne donne pas ce compte).
    final String tiers;
    String? detailTiers;
    if (p.tiersPayantsRetenus != null) {
      // 3.17.1 : compté par le serveur sur les ventes retenues (recherche et filtre appliqués).
      tiers = formaterNombre(p.tiersPayantsRetenus!);
    } else if (d != null && d.tiers.isNotEmpty) {
      tiers = formaterNombre(1);
    } else if (d == null || d.texte.isEmpty) {
      tiers = formaterNombre(p.tiersPayants.length);
    } else if (_fin) {
      tiers = formaterNombre({for (final c in l) c.tiersPayantLibelle}.length);
    } else {
      tiers = formaterNombre(p.tiersPayants.length);
      detailTiers = 'de la période';
    }
    final avant = <Widget>[
      GrilleKpi([
        ChiffreCle(libelle: 'Montant à crédit', valeur: formaterMontant(p.montant), id: 'montant', enAvant: true),
        ChiffreCle(
          libelle: 'Ventes',
          valeur: formaterNombre(p.total),
          id: 'ventes',
          detail: filtree && sansFiltre != null && sansFiltre != p.total ? 'sur ${formaterNombre(sansFiltre)}' : null,
        ),
        ChiffreCle(libelle: 'Clients', valeur: formaterNombre(p.clients), id: 'clients'),
        ChiffreCle(libelle: 'Tiers payants', valeur: tiers, id: 'tiers', detail: detailTiers),
      ]),
      const TitreSection('Ventes à crédit'),
    ];
    final total = _fin ? l.length : p.total;
    final apres = <Widget>[
      if (tableau) _tableau(l, l.length, _fin ? formaterMontant(p.montant) : null),
      if (total > l.length || _suiteEnCours || l.length > AffichageParTranches.tranche)
        KeyedSubtree(
          key: const Key('ca_credit_pied_pages'),
          child: _PiedPages(
            affichees: l.length,
            total: total,
            enCours: _suiteEnCours,
            onPlus: () {
              _suiteEnEchec = false;
              _relecturesLuLe = 0;
              _suite();
            },
          ),
        ),
    ];
    return (avant: avant, lignes: l, cartes: tableau ? 0 : l.length, apres: apres);
  }

  Widget _tableau(List<CaCredit> l, int n, String? total) => ListeOuTableau(
        nombre: n,
        onTap: (i) => _detail(l[i]),
        colonnes: const [
          Colonne('Date', flex: 2),
          Colonne('Client', flex: 4),
          Colonne('Ayant droit', flex: 4),
          Colonne('N° facture', flex: 3),
          Colonne('Tiers payant', flex: 4),
          Colonne('Montant', flex: 3, droite: true),
        ],
        cellules: (i) => [_date(l[i]), l[i].clientName, _ayantDroitDistinct(l[i]) ? l[i].ayantDroitName : '', l[i].numFacturation, l[i].tiersPayantLibelle,
          formaterMontant(l[i].montant)],
        total: total == null ? null : ['Total', '', '', '', '', total],
        carte: (i) => _carte(l, i),
      );
}

/// Ventes affichées et chiffres clés, calculés une fois par (liste, recherche, tiers payant).
class VueCaCredit {
  final List<CaCredit> lignes;
  final double total;
  final int clients;
  final int tiersPayants;
  const VueCaCredit(this.lignes, this.total, this.clients, this.tiersPayants);

  /// Nombre de calculs faits (tests : la recherche n'est pas refaite à chaque image).
  static int calculs = 0;

  static VueCaCredit calculer(List<CaCredit> tout, String texte, String tiers) {
    calculs++;
    final r = CaCreditDonnees.filtrer(tout, texte);
    final l = tiers.isEmpty ? r : [for (final c in r) if (c.tiersPayantLibelle == tiers) c];
    return VueCaCredit(l, CaCreditDonnees.total(l), {for (final c in l) c.clientName}.length, {for (final c in l) c.tiersPayantLibelle}.length);
  }
}

/// Pied du mode paginé : « n lignes affichées sur N » et, s'il en reste, « Afficher plus » ou l'indicateur de la page
/// en cours, à hauteur CONSTANTE (la liste ne change pas de longueur quand la page suivante part).
class _PiedPages extends StatelessWidget {
  final int affichees;
  final int total;
  final bool enCours;
  final VoidCallback onPlus;
  const _PiedPages({required this.affichees, required this.total, required this.enCours, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    final reste = total - affichees;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(children: [
        Text('${formaterNombre(affichees)} ${affichees > 1 ? 'lignes affichées' : 'ligne affichée'} sur ${formaterNombre(total)}',
            style: const TextStyle(color: Charte.gris)),
        if (reste > 0) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: Center(
              child: enCours
                  ? const SizedBox(key: Key('ca_credit_page_en_cours'), width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : OutlinedButton.icon(
                      key: const Key('bouton_afficher_plus'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: onPlus,
                      icon: const Icon(Icons.expand_more),
                      label: Text('Afficher plus (${formaterNombre(reste)})'),
                    ),
            ),
          ),
        ],
      ]),
    );
  }
}
