// lib/nouvelle_interface/modules/fichier_journal_nouveau.dart
// Fichier Journal (actions des utilisateurs) de la nouvelle interface, en LECTURE SEULE comme l'écran d'origine.
// Mêmes données (JournalDonnees, lib/donnees/fichier_journal_donnees.dart) : opérations GET /common/log-filtres,
// utilisateurs GET /common/users, journal GET /common/logs?dtStart=&dtEnd=&criteria=&userId=&limit=200. Mise en page
// refaite : période commune chargée dès l'ouverture (« Aujourd'hui », toutes opérations, tous utilisateurs : valeurs
// par défaut d'origine), opération et utilisateur dans la feuille des filtres (envoyés au serveur, comme avant),
// recherche contrôlée LOCALE (description, type, utilisateur ; aucune requête), chiffres clés, avertissement quand la
// limite de 200 actions du serveur est atteinte, cartes (téléphone) ou tableau dense (tablette) construits 50 par 50,
// détail d'une action en feuille. Aucun export à l'origine : pas de menu « Exporter ».
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

class _FichierJournalNouveauState extends State<FichierJournalNouveau>
    with ChargementSuivi<FichierJournalNouveau, List<FichierJournal>>, AffichageParTranches {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  final _recherche = TextEditingController();
  String _texte = '';

  List<LogFiltre>? _operations;
  List<LogUser>? _utilisateurs;
  Object? _erreurListes;
  LogFiltre? _operation;
  LogUser? _utilisateur;

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

  Future<void> _charger() {
    reinitialiserTranches();
    return charger(() async =>
        await JournalDonnees.actions(context,
            debut: _periode.debut, fin: _periode.fin, operation: _operation, utilisateur: _utilisateur, onSessionInvalid: sessionInvalide(context)) ??
        const <FichierJournal>[]);
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
    if (enCours) return const [EtatChargement(texte: 'Chargement du journal…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final tout = donnees ?? const <FichierJournal>[];
    if (tout.isEmpty) {
      return const [EtatVide(titre: 'Aucune action', texte: 'Aucune action trouvée pour les critères sélectionnés.', icone: Icons.history_edu_outlined)];
    }
    final l = JournalDonnees.filtrer(tout, _texte);
    final limite = tout.length >= JournalDonnees.limite;
    final n = affichees.clamp(0, l.length);
    return [
      GrilleKpi([
        ChiffreCle(
          libelle: 'Actions',
          valeur: formaterNombre(l.length),
          id: 'actions',
          enAvant: true,
          detail: l.length == tout.length ? (limite ? 'limite atteinte' : null) : 'sur ${formaterNombre(tout.length)}',
        ),
        ChiffreCle(libelle: 'Utilisateurs', valeur: formaterNombre({for (final a in l) a.userFullName}.length), id: 'utilisateurs'),
        ChiffreCle(libelle: 'Types d\'action', valeur: formaterNombre({for (final a in l) a.typeLog}.length), id: 'types'),
      ]),
      if (limite) ...[
        const SizedBox(height: 10),
        const Encadre(
          key: Key('journal_limite'),
          titre: '200 actions au plus',
          texte: 'Le serveur rend au plus 200 actions : d\'autres peuvent manquer. Réduisez la période ou filtrez par opération ou utilisateur.',
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
      piedTranches(l.length),
    ];
  }
}
