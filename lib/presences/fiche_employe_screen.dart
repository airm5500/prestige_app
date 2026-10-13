// lib/presences/fiche_employe_screen.dart
// Fiche d'un employé : pointages du jour (heure, arrivée / départ, source : téléphone, pointeuse, saisie
// manuelle) et anomalies en phrases ; puis synthèse sur une période (GET /rh/tableau?employeId=, 366 jours max).
// Lecture seule : les corrections se font dans Prestige (menu RH).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'presences_api.dart';
import 'presences_modeles.dart';
import 'presences_reglages.dart';
import 'presences_widgets.dart';
import 'tableau_periode_view.dart' show ChoixPeriode;

class FicheEmployeScreen extends StatefulWidget {
  final String employeId;
  final String employe;
  final String matricule;

  /// Jour des pointages affichés (null : synthèse seule, depuis le tableau).
  final DateTime? jour;
  final PresenceJour? ligne;
  final List<PointageJour> pointages;

  /// Période de la synthèse au départ (par défaut : du 1er du mois du jour à ce jour).
  final PeriodePresence? periode;

  const FicheEmployeScreen({
    super.key,
    required this.employeId,
    required this.employe,
    this.matricule = '',
    this.jour,
    this.ligne,
    this.pointages = const [],
    this.periode,
  });

  @override
  State<FicheEmployeScreen> createState() => _FicheEmployeScreenState();
}

class _FicheEmployeScreenState extends State<FicheEmployeScreen> {
  late PeriodePresence _periode = widget.periode ?? PeriodePresence.mois(widget.jour ?? HorlogePresences.maintenant());
  TableauPeriode? _synthese;
  Object? _erreur;
  bool _chargement = false;
  int _demande = 0;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final n = ++_demande;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final t = await const PresencesApi().tableau(context, _periode, employeId: widget.employeId);
      if (!mounted || n != _demande) return;
      setState(() {
        _synthese = t;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted || n != _demande) return;
      setState(() {
        _erreur = e;
        _synthese = null;
        _chargement = false;
      });
    }
  }

  void _changerPeriode(PeriodePresence p) {
    if (p.correction != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.correction!), backgroundColor: Colors.orange));
    }
    setState(() => _periode = p);
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final seuil = ReglagesPresences.seuil.value;
    final maintenant = HorlogePresences.maintenant();
    final tablette = estTablette(context);
    final jour = _sectionJour(seuil, maintenant);
    final synthese = _sectionSynthese();
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.employe, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (widget.matricule.isNotEmpty) Text('Matricule ${widget.matricule}', style: const TextStyle(fontSize: 13)),
        ]),
        actions: [IconButton(tooltip: 'Actualiser', onPressed: _charger, icon: const Icon(Icons.refresh))],
      ),
      backgroundColor: const Color(0xFFF2F4F7),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          key: const Key('fiche_employe_liste'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            if (tablette && jour.isNotEmpty)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: jour)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: synthese)),
              ])
            else ...[
              ...jour,
              ...synthese,
            ],
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text('Corrections de pointage : dans Prestige, menu RH (non modifiable depuis le téléphone).',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: couleurGris)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _sectionJour(int seuil, DateTime maintenant) {
    final l = widget.ligne;
    final jour = widget.jour;
    if (l == null || jour == null) return const [];
    final statut = l.statut(seuil, maintenant);
    final phrases = l.phrasesAnomalies(maintenant);
    return [
      TitreSection('Pointages du ${DateFormat('EEEE d MMMM', 'fr_FR').format(jour)}'),
      CartePresence(
        bande: couleurStatut(statut),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            PastilleStatut(statut, complement: statut == StatutPresence.enRetard ? '+${dureeLisible(l.minutesRetard)}' : null),
            const Spacer(),
            if (l.prevu.isNotEmpty) Text('Prévu ${l.prevu}', style: const TextStyle(color: couleurGris, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 16, runSpacing: 4, children: [
            _info('Arrivée', l.entree.isEmpty ? '—' : l.entree),
            _info('Départ', l.sortie.isEmpty ? '—' : l.sortie),
            _info('Durée', l.minutesPresence > 0 ? dureeLisible(l.minutesPresence) : '—'),
            if (l.minutesRetard > 0) _info('Retard', dureeLisible(l.minutesRetard)),
            if (l.departAnticipe > 0) _info('Départ anticipé', dureeLisible(l.departAnticipe)),
            if (l.heuresSup > 0) _info('Heures sup.', dureeLisible(l.heuresSup)),
          ]),
          if (l.absence.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('Absence validée : ${l.absence.toLowerCase()}')),
          for (final p in phrases)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFF9F1239)),
                const SizedBox(width: 6),
                Expanded(child: Text(p, style: const TextStyle(color: Color(0xFF9F1239), fontWeight: FontWeight.w600))),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      if (widget.pointages.isEmpty)
        const CartePresence(child: Text('Aucun pointage ce jour-là.', style: TextStyle(color: couleurGris)))
      else
        CartePresence(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final p in widget.pointages)
              ListTile(
                key: Key('pointage_${p.id}'),
                dense: true,
                leading: Icon(p.entree ? Icons.login : (p.sortie ? Icons.logout : Icons.swap_vert),
                    color: p.entree ? couleurPresent : (p.sortie ? couleurPrincipale : couleurGris)),
                title: Text('${p.heure}  ${p.sensLisible}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(p.motif.isEmpty ? sourceLisible(p.source) : '${sourceLisible(p.source)} · ${p.motif}'),
                trailing: Icon(iconeSource(p.source), color: couleurGris, size: 20),
              ),
          ]),
        ),
    ];
  }

  List<Widget> _sectionSynthese() {
    final s = _synthese;
    final ligne = s == null || s.lignes.isEmpty ? null : s.lignes.firstWhere((x) => x.employeId == widget.employeId, orElse: () => s.lignes.first);
    return [
      const TitreSection('Synthèse sur la période'),
      ChoixPeriode(periode: _periode, onChange: _changerPeriode),
      const SizedBox(height: 8),
      if (_chargement) const LinearProgressIndicator(),
      if (_erreur != null)
        BlocErreur(message: messageErreur(_erreur!), onRetry: _charger)
      else if (s != null && ligne == null)
        const CartePresence(
          child: Text('Aucune journée prévue ni pointée sur la période.', key: Key('fiche_synthese_vide'), style: TextStyle(color: couleurGris)),
        )
      else if (ligne != null) ...[
        Text('Du ${DateFormat('dd/MM/yyyy').format(s!.du)} au ${DateFormat('dd/MM/yyyy').format(s.au)}',
            style: const TextStyle(fontSize: 12, color: couleurGris)),
        const SizedBox(height: 6),
        RangeeTuiles([
          TuileCompteur(libelle: 'Jours présents', valeur: '${ligne.joursPresents} / ${ligne.joursPrevus}', couleur: couleurPresent),
          TuileCompteur(
            libelle: 'Retards',
            valeur: '${ligne.retards}',
            couleur: couleurRetard,
            detail: ligne.minutesRetard > 0 ? 'cumul ${dureeLisible(ligne.minutesRetard)}' : null,
          ),
        ]),
        const SizedBox(height: 8),
        RangeeTuiles([
          TuileCompteur(libelle: 'Présence', valeur: dureeLisible(ligne.minutesPresence), detail: 'sur ${dureeLisible(ligne.minutesPrevues)} prévues'),
          TuileCompteur(libelle: 'Heures sup.', valeur: dureeLisible(ligne.heuresSup)),
        ]),
        const SizedBox(height: 8),
        CartePresence(
          key: const Key('fiche_synthese'),
          child: Column(children: [
            _ligne('Absences non justifiées', '${ligne.absencesNonJustifiees}', alerte: ligne.absencesNonJustifiees > 0),
            _ligne('Absences justifiées (jours)', ligne.absencesJustifieesTexte),
            _ligne('Départs anticipés', '${ligne.departsAnticipes}', alerte: ligne.departsAnticipes > 0),
            _ligne('Anomalies à vérifier', '${ligne.anomalies}', alerte: ligne.anomalies > 0),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Retards comptés par Prestige (au-delà de sa tolérance) ; le détail jour par jour est dans l\'export « Excel détaillé ».',
              style: TextStyle(fontSize: 11.5, color: couleurGris)),
        ),
      ],
    ];
  }

  Widget _info(String t, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontSize: 12, color: couleurGris)),
        Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: couleurEncre)),
      ]);

  Widget _ligne(String t, String v, {bool alerte = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(t, style: const TextStyle(color: couleurEncre))),
          Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: alerte ? couleurAbsent : couleurEncre)),
        ]),
      );
}
