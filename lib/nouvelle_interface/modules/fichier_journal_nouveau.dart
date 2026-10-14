// lib/nouvelle_interface/modules/fichier_journal_nouveau.dart
// Fichier Journal (actions des utilisateurs) de la nouvelle interface, en LECTURE SEULE comme l'écran d'origine.
// Mêmes données (JournalDonnees, lib/donnees/fichier_journal_donnees.dart) : opérations GET /common/log-filtres,
// utilisateurs GET /common/users, journal GET /common/logs (mêmes filtres dtStart, dtEnd, criteria, userId). Depuis
// la 3.6.1, le journal est demandé PAR PAGES DE 50 (start=0 & limit=50, puis start=50… à chaque « Afficher plus »,
// mêmes filtres) : le serveur pagine et rend « total ». S'il ne rend pas de total (serveur sans pagination), ce qui
// est reçu est affiché 50 par 50 sans autre requête, avec l'avertissement « d'autres actions peuvent manquer ».
// Mise en page : période commune chargée dès l'ouverture (« Aujourd'hui », toutes opérations, tous utilisateurs :
// valeurs par défaut d'origine), opération et utilisateur dans la feuille des filtres (envoyés au serveur, comme
// avant), recherche contrôlée LOCALE sur les actions chargées (description, type, utilisateur ; aucune requête),
// chiffres clés, cartes (téléphone) ou tableau dense (tablette), détail d'une action en feuille. Aucun export à
// l'origine : pas de menu « Exporter ».
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../donnees/fichier_journal_donnees.dart';
import '../../models/fichier_journal_model.dart';
import '../../models/log_filtre_model.dart';
import '../../models/log_user_model.dart';
import '../charte.dart';
import '../composants.dart';
import '../vague1/donnees_vague1.dart' show OptionListe;
import '../vague2/commun_vague2.dart' show ChoixListe;
import 'commun.dart';
import 'commun_lot2.dart';
import 'commun_lot3.dart';
import 'periode.dart';

class FichierJournalNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const FichierJournalNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<FichierJournalNouveau> createState() => _FichierJournalNouveauState();
}

class _FichierJournalNouveauState extends State<FichierJournalNouveau> with AffichageParTranches {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  final _recherche = TextEditingController();
  String _texte = '';

  List<LogFiltre>? _operations;
  List<LogUser>? _utilisateurs;
  Object? _erreurListes;
  LogFiltre? _operation;
  LogUser? _utilisateur;

  // Pages chargées (mêmes filtres pour toutes les pages d'une même lecture).
  final _actions = <FichierJournal>[];
  int? _total;
  bool _derniereVide = false;
  bool _enCours = false;
  bool _suiteEnCours = false;
  bool _charge = false;
  Object? _erreur;
  int _generation = 0;
  ({Periode periode, LogFiltre? operation, LogUser? utilisateur})? _filtresLus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chargerListes();
      _charger();
    });
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _chargerListes() async {
    setState(() => _erreurListes = null);
    try {
      final r = await Future.wait([
        JournalDonnees.operations(context, onSessionInvalid: sessionInvalide(context)),
        JournalDonnees.utilisateurs(context, onSessionInvalid: sessionInvalide(context)),
      ]);
      if (!mounted) return;
      setState(() {
        _operations = (r[0] as List<LogFiltre>?) ?? const [];
        _utilisateurs = (r[1] as List<LogUser>?) ?? const [];
      });
    } catch (e) {
      if (mounted) setState(() => _erreurListes = e);
    }
  }

  Future<PageJournal> _lire(int start) {
    final f = _filtresLus!;
    return JournalDonnees.page(context,
        debut: f.periode.debut,
        fin: f.periode.fin,
        operation: f.operation,
        utilisateur: f.utilisateur,
        start: start,
        onSessionInvalid: sessionInvalide(context));
  }

  /// Première page (filtres du moment) ; toute lecture précédente encore en route est ignorée.
  Future<void> _charger() async {
    final g = ++_generation;
    _filtresLus = (periode: _periode, operation: _operation, utilisateur: _utilisateur);
    setState(() {
      reinitialiserTranches();
      _enCours = true;
      _suiteEnCours = false;
      _erreur = null;
      _actions.clear();
      _total = null;
      _derniereVide = false;
    });
    try {
      final p = await _lire(0);
      if (!mounted || g != _generation) return;
      setState(() {
        _actions.addAll(p.actions);
        _total = p.total;
        _derniereVide = p.actions.isEmpty;
        _enCours = false;
        _charge = true;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _enCours = false;
      });
    }
  }

  /// Le serveur annonce-t-il d'autres actions que celles chargées ?
  bool get _aSuite => _total != null && !_derniereVide && _actions.length < _total!;

  /// Page suivante (« Afficher plus ») : mêmes filtres, start = actions déjà chargées.
  Future<void> _suite() async {
    if (_suiteEnCours || _enCours || !_aSuite) return;
    final g = _generation;
    setState(() => _suiteEnCours = true);
    try {
      final p = await _lire(_actions.length);
      if (!mounted || g != _generation) return;
      setState(() {
        _actions.addAll(p.actions);
        _total = p.total ?? _total;
        _derniereVide = p.actions.isEmpty;
        affichees += AffichageParTranches.tranche;
        _suiteEnCours = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() => _suiteEnCours = false);
      messageResultat(context, DiagnosticErreur.de(e).message, echec: true);
    }
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  int get _actifs => (_operation == null ? 0 : 1) + (_utilisateur == null ? 0 : 1);

  Future<void> _filtres() async {
    if ((_operations == null || _utilisateurs == null) && _erreurListes != null) _chargerListes();
    var operation = _operation == null ? '' : '${_operation!.order}';
    var utilisateur = _utilisateur?.lgUserID ?? '';
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer le journal',
      effacer: () {
        operation = '';
        utilisateur = '';
      },
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ChoixListe(
          key: const Key('filtre_operation'),
          libelle: 'Opération',
          icone: Icons.category_outlined,
          options: _operations == null ? null : [for (final o in _operations!) OptionListe('${o.order}', o.description)],
          erreur: _erreurListes,
          valeur: operation,
          tous: 'Toutes les opérations',
          onChanged: (v) => setState(() => operation = v),
        ),
        const SizedBox(height: 14),
        ChoixListe(
          key: const Key('filtre_utilisateur'),
          libelle: 'Utilisateur',
          icone: Icons.person_outline,
          options: _utilisateurs == null ? null : [for (final u in _utilisateurs!) OptionListe(u.lgUserID, u.fullName)],
          erreur: _erreurListes,
          valeur: utilisateur,
          tous: 'Tous les utilisateurs',
          onChanged: (v) => setState(() => utilisateur = v),
        ),
      ]),
    );
    if (!applique || !mounted) return;
    setState(() {
      _operation = operation.isEmpty ? null : _operations?.where((o) => '${o.order}' == operation).firstOrNull;
      _utilisateur = utilisateur.isEmpty ? null : _utilisateurs?.where((u) => u.lgUserID == utilisateur).firstOrNull;
    });
    _charger();
  }

  static final _format = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

  static String _quand(FichierJournal a) => a.operationDate != null ? _format.format(a.operationDate!) : 'Date N/A';

  void _detail(FichierJournal a) => ouvrirFeuilleDetail(context, titre: a.typeLog, sousTitre: _quand(a), lignes: [
        LigneDetail('Utilisateur', a.userFullName),
        LigneDetail('Date et heure', _quand(a)),
        LigneDetail('Type d\'action', a.typeLog),
        const SizedBox(height: 8),
        const Text('Description', style: TextStyle(color: Charte.grisTexte, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(a.description.isEmpty ? '—' : a.description, style: const TextStyle(color: Charte.encre, fontSize: 14.5)),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fichier Journal'), actions: [
          BoutonFiltres(actifs: _actifs, onPressed: _filtres),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ChampRecherche(
              controleur: _recherche,
              libelle: 'Rechercher dans le journal',
              aide: 'Description, type, utilisateur',
              onRecherche: (t) => setState(() {
                _texte = t;
                reinitialiserTranches();
              }),
            ),
            EtiquettesFiltres(etiquettes: [
              if (_operation != null) 'Opération : ${_operation!.description}',
              if (_utilisateur != null) 'Utilisateur : ${_utilisateur!.fullName}',
            ], onRetirer: () {
              setState(() {
                _operation = null;
                _utilisateur = null;
              });
              _charger();
            }),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (_enCours || !_charge && _erreur == null) return const [EtatChargement(texte: 'Chargement du journal…')];
    if (_erreur != null) return [EtatErreur(erreur: _erreur!, reessayer: _charger)];
    final tout = _actions;
    if (tout.isEmpty) {
      return const [EtatVide(titre: 'Aucune action', texte: 'Aucune action trouvée pour les critères sélectionnés.', icone: Icons.history_edu_outlined)];
    }
    final l = JournalDonnees.filtrer(tout, _texte);
    // Serveur sans pagination (pas de « total ») qui a rendu au moins une page entière : d'autres peuvent manquer.
    final limite = _total == null && tout.length >= JournalDonnees.taillePage;
    final total = _total ?? tout.length;
    final n = affichees.clamp(0, l.length);
    return [
      GrilleKpi([
        ChiffreCle(
          libelle: 'Actions',
          valeur: formaterNombre(_texte.isEmpty ? total : l.length),
          id: 'actions',
          enAvant: true,
          detail: _texte.isNotEmpty
              ? 'sur ${formaterNombre(tout.length)} chargée${tout.length > 1 ? 's' : ''}'
              : (limite ? 'limite atteinte' : (tout.length < total ? '${formaterNombre(tout.length)} chargée${tout.length > 1 ? 's' : ''}' : null)),
        ),
        ChiffreCle(libelle: 'Utilisateurs', valeur: formaterNombre({for (final a in l) a.userFullName}.length), id: 'utilisateurs'),
        ChiffreCle(libelle: 'Types d\'action', valeur: formaterNombre({for (final a in l) a.typeLog}.length), id: 'types'),
      ]),
      if (limite) ...[
        const SizedBox(height: 10),
        const Encadre(
          key: Key('journal_limite'),
          titre: 'Limite du serveur atteinte',
          texte: 'Le serveur n\'indique pas le nombre total d\'actions : d\'autres peuvent manquer. Réduisez la période ou filtrez par opération ou utilisateur.',
          icone: Icons.info_outline,
          avertissement: true,
        ),
      ],
      const TitreSection('Actions'),
      if (l.isEmpty)
        const EtatVide(titre: 'Aucune action ne correspond', texte: 'Modifiez la recherche.', icone: Icons.filter_alt_off_outlined)
      else
        ListeOuTableau(
          nombre: n,
          onTap: (i) => _detail(l[i]),
          colonnes: const [
            Colonne('Date et heure', flex: 3),
            Colonne('Utilisateur', flex: 3),
            Colonne('Type', flex: 3),
            Colonne('Description', flex: 6),
          ],
          cellules: (i) => [_quand(l[i]), l[i].userFullName, l[i].typeLog, l[i].description],
          carte: (i) => CarteLigne(
            titre: l[i].description.isEmpty ? l[i].typeLog : l[i].description,
            lignes: ['${l[i].typeLog} · ${l[i].userFullName}', 'Le ${_quand(l[i])}'],
            onTap: () => _detail(l[i]),
          ),
        ),
      _pied(l.length),
    ];
  }

  /// Pied : d'abord les actions déjà chargées (50 par 50, sans requête), puis la page suivante du serveur.
  Widget _pied(int filtrees) {
    if (filtrees > affichees || !_aSuite) return piedTranches(filtrees);
    return PiedPagination(affichees: _actions.length, total: _total!, enCours: _suiteEnCours, onPlus: _suite);
  }
}
