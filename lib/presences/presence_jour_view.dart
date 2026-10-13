// lib/presences/presence_jour_view.dart
// « Présence du jour » : bascule Aujourd'hui / Hier en tête, puis sélecteur de date ; compteurs (présents,
// retards, absents, anomalies) ; liste triée (absents et retards d'abord) ; recherche par nom ; tirer pour
// actualiser (et bouton Actualiser dans la barre). Toucher un employé ouvre sa fiche.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/saisie.dart';
import '../widgets/erreurs_chargement.dart';
import 'fiche_employe_screen.dart';
import 'presences_api.dart';
import 'presences_modeles.dart';
import 'presences_reglages.dart';
import 'presences_widgets.dart';

class PresenceJourView extends StatefulWidget {
  /// Jour affiché au départ (aujourd'hui par défaut).
  final DateTime? jour;
  const PresenceJourView({super.key, this.jour});

  @override
  State<PresenceJourView> createState() => PresenceJourViewState();
}

class PresenceJourViewState extends State<PresenceJourView> {
  late DateTime _jour = jourSeul(widget.jour ?? HorlogePresences.maintenant());
  PresenceDuJour? _donnees;
  Object? _erreur;
  bool _chargement = false;
  DateTime? _misAJour;
  int _demande = 0;
  final _recherche = TextEditingController();
  String _filtre = '';

  @override
  void initState() {
    super.initState();
    ReglagesPresences.seuil.addListener(_seuilChange);
    actualiser();
  }

  @override
  void dispose() {
    ReglagesPresences.seuil.removeListener(_seuilChange);
    _recherche.dispose();
    super.dispose();
  }

  void _seuilChange() {
    if (mounted) setState(() {});
  }

  DateTime get _aujourdhui => jourSeul(HorlogePresences.maintenant());
  DateTime get _hier => _aujourdhui.subtract(const Duration(days: 1));

  /// Recharge le jour affiché (bouton Actualiser, tirer pour actualiser, changement de jour).
  Future<void> actualiser() async {
    final n = ++_demande;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final d = await const PresencesApi().presence(context, _jour);
      if (!mounted || n != _demande) return;
      setState(() {
        _donnees = d;
        _misAJour = HorlogePresences.maintenant();
        _chargement = false;
      });
    } catch (e) {
      if (!mounted || n != _demande) return;
      setState(() {
        _erreur = e;
        _chargement = false;
        // Les données d'un autre jour ne restent pas affichées sous le nouveau jour.
        if (_donnees != null && !_memeJour(_donnees!.jour, _jour)) _donnees = null;
      });
    }
  }

  static bool _memeJour(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  void _choisirJour(DateTime j) {
    final jour = jourSeul(j);
    if (jour.isAfter(_aujourdhui)) return; // pas de présence dans le futur
    setState(() => _jour = jour);
    actualiser();
  }

  Future<void> _calendrier() async {
    final j = await showDatePicker(
      context: context,
      initialDate: _jour,
      firstDate: DateTime(2020),
      lastDate: _aujourdhui,
      locale: const Locale('fr', 'FR'),
      helpText: 'Jour à afficher',
    );
    if (j != null) _choisirJour(j);
  }

  @override
  Widget build(BuildContext context) {
    final seuil = ReglagesPresences.seuil.value;
    final maintenant = HorlogePresences.maintenant();
    final lignes = _donnees == null ? <PresenceJour>[] : trierPresences(_donnees!.lignes, seuil, maintenant);
    final visibles = filtrerPresences(lignes, _filtre);
    final compteurs = CompteursPresence.de(lignes, seuil, maintenant);
    final tablette = estTablette(context);

    final enTete = <Widget>[
      _barreJour(),
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(
          [
            toBeginningOfSentenceCase(DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_jour)),
            if (_misAJour != null && _donnees != null) 'mis à jour ${DateFormat('HH:mm').format(_misAJour!)}',
            // Espace insécable : « 1 h » jamais coupé en fin de ligne.
            'retard au-delà de ${dureeLisible(seuil).replaceAll(' ', '\u00a0')}',
          ].join(' · '),
          key: const Key('presences_jour_titre'),
          style: const TextStyle(color: couleurGris, fontSize: 13),
        ),
      ),
      if (_donnees != null)
        RangeeTuiles([
          TuileCompteur(libelle: 'Présents', valeur: '${compteurs.presents} / ${compteurs.prevus}', couleur: couleurPresent),
          TuileCompteur(
            libelle: 'Retards',
            valeur: '${compteurs.retards}',
            couleur: couleurRetard,
            detail: compteurs.retards == 0 ? null : 'cumul ${dureeLisible(compteurs.minutesRetard)}',
          ),
          TuileCompteur(libelle: 'Absents', valeur: '${compteurs.absents}', couleur: couleurAbsent),
          TuileCompteur(libelle: 'Anomalies', valeur: '${compteurs.anomalies}', couleur: const Color(0xFF9F1239)),
        ]),
      const SizedBox(height: 10),
      TextField(
        key: const Key('presences_recherche'),
        controller: _recherche,
        inputFormatters: Saisie.rechercheFormatters,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search),
          hintText: 'Rechercher un employé (nom, matricule)',
          suffixIcon: _filtre.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Effacer',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    _recherche.clear();
                    _filtre = '';
                  }),
                ),
        ),
        onChanged: (v) => setState(() => _filtre = Saisie.recherche(v)),
      ),
      const SizedBox(height: 10),
      if (_chargement) const LinearProgressIndicator(),
      if (_erreur != null && _donnees != null) LoadErrorBanner(message: messageErreur(_erreur!), onRetry: actualiser),
    ];

    final List<Widget> corps;
    if (_erreur != null && _donnees == null) {
      corps = [BlocErreur(message: messageErreur(_erreur!), onRetry: actualiser)];
    } else if (_donnees == null) {
      corps = const [];
    } else if (lignes.isEmpty) {
      corps = const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Text('Aucun employé attendu ni pointé ce jour-là.', key: Key('presences_vide'), textAlign: TextAlign.center),
        ),
      ];
    } else if (visibles.isEmpty) {
      corps = [Padding(padding: const EdgeInsets.all(32), child: Text('Aucun employé ne correspond à « $_filtre ».', textAlign: TextAlign.center))];
    } else {
      corps = enColonnes([for (final l in visibles) _carte(l, seuil, maintenant)], tablette);
    }

    return RefreshIndicator(
      onRefresh: actualiser,
      child: ListView(
        key: const Key('presences_jour_liste'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [...enTete, ...corps],
      ),
    );
  }

  Widget _barreJour() {
    final selection = _memeJour(_jour, _aujourdhui) ? 0 : (_memeJour(_jour, _hier) ? 1 : null);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<int>(
          key: const Key('presences_bascule_jour'),
          segments: const [
            ButtonSegment(value: 0, label: Text('Aujourd\'hui')),
            ButtonSegment(value: 1, label: Text('Hier')),
          ],
          selected: {if (selection != null) selection},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            if (s.isEmpty) return;
            _choisirJour(s.first == 0 ? _aujourdhui : _hier);
          },
        ),
        OutlinedButton.icon(
          key: const Key('presences_choisir_date'),
          onPressed: _calendrier,
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: Text(DateFormat('dd/MM/yyyy').format(_jour)),
        ),
      ],
    );
  }

  Widget _carte(PresenceJour l, int seuil, DateTime maintenant) {
    final statut = l.statut(seuil, maintenant);
    final phrases = l.phrasesAnomalies(maintenant);
    final initiales = l.nomAffiche.split(RegExp(r'\s+')).where((m) => m.isNotEmpty).take(2).map((m) => m[0].toUpperCase()).join();
    final details = <String>[
      if (l.prevu.isNotEmpty) 'Prévu ${l.prevu}',
      if (l.arrive) 'arrivée ${l.entree}',
      if (l.sortie.isNotEmpty) 'départ ${l.sortie}',
      if (l.minutesPresence > 0) 'durée ${dureeLisible(l.minutesPresence)}',
    ];
    return CartePresence(
      key: Key('presence_${l.employeId}'),
      bande: statut == StatutPresence.present || statut == StatutPresence.repos || statut == StatutPresence.conge ? null : couleurStatut(statut),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FicheEmployeScreen(
            employeId: l.employeId,
            employe: l.nomAffiche,
            matricule: l.matricule,
            jour: _jour,
            ligne: l,
            pointages: _donnees?.pointagesDe(l) ?? const [],
          ),
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: couleurPrincipale.withAlpha(20),
          child: Text(initiales, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: couleurPrincipale)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(l.nomAffiche, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: couleurEncre)),
              ),
              const SizedBox(width: 6),
              PastilleStatut(statut, complement: statut == StatutPresence.enRetard ? '+${dureeLisible(l.minutesRetard)}' : null),
            ]),
            if (details.isNotEmpty) Text(details.join(' · '), style: const TextStyle(fontSize: 13, color: couleurGris)),
            if (statut == StatutPresence.absent) const Text('Aucun pointage', style: TextStyle(fontSize: 13, color: couleurGris)),
            if (statut == StatutPresence.attendu && !l.arrive)
              const Text('Pas encore arrivé(e)', style: TextStyle(fontSize: 13, color: couleurGris)),
            if (l.absence.isNotEmpty) Text('Absence validée : ${absenceLisible(l.absence)}', style: const TextStyle(fontSize: 13, color: couleurGris)),
            if (l.departAnticipe > 0)
              Text('Départ anticipé de ${dureeLisible(l.departAnticipe)}', style: const TextStyle(fontSize: 13, color: Color(0xFFA16207))),
            if (l.pointages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(l.pointages, style: const TextStyle(fontSize: 13, color: couleurEncre, fontFeatures: [FontFeature.tabularFigures()])),
              ),
            for (final p in phrases)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFF9F1239)),
                  const SizedBox(width: 4),
                  Expanded(child: Text(p, style: const TextStyle(fontSize: 13, color: Color(0xFF9F1239), fontWeight: FontWeight.w600))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
