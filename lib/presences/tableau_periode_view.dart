// lib/presences/tableau_periode_view.dart
// « Tableau sur une période » : Semaine / Mois / Mois dernier / Personnalisé (366 jours au plus, jamais dans le
// futur) ; une ligne par employé (jours présents / prévus, retards, présence, anomalies) ; exports Excel, Excel
// détaillé (une ligne par employé et par jour) et PDF, téléchargés puis partagés ou ouverts.
import 'package:flutter/material.dart';

import 'export_fichier.dart';
import 'fiche_employe_screen.dart';
import 'presences_api.dart';
import 'presences_modeles.dart';
import 'presences_widgets.dart';

/// Puces de période (partagées avec la fiche employé).
class ChoixPeriode extends StatelessWidget {
  final PeriodePresence periode;
  final ValueChanged<PeriodePresence> onChange;
  const ChoixPeriode({super.key, required this.periode, required this.onChange});

  bool _egal(PeriodePresence a, PeriodePresence b) => a.du == b.du && a.au == b.au;

  @override
  Widget build(BuildContext context) {
    final aujourdhui = HorlogePresences.maintenant();
    final choix = <(String, PeriodePresence)>[
      ('Semaine', PeriodePresence.semaine(aujourdhui)),
      ('Mois', PeriodePresence.mois(aujourdhui)),
      ('Mois dernier', PeriodePresence.moisDernier(aujourdhui)),
    ];
    final predefini = choix.any((c) => _egal(c.$2, periode));
    return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final c in choix)
        ChoiceChip(
          key: Key('periode_${c.$1}'),
          label: Text(c.$1),
          selected: _egal(c.$2, periode),
          onSelected: (_) => onChange(c.$2),
        ),
      ChoiceChip(
        key: const Key('periode_personnalisee'),
        avatar: const Icon(Icons.date_range, size: 18),
        label: Text(predefini ? 'Personnalisé' : periode.texte),
        selected: !predefini,
        onSelected: (_) async {
          final today = jourSeul(aujourdhui);
          final r = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: today,
            initialDateRange: DateTimeRange(start: periode.du, end: periode.au.isAfter(today) ? today : periode.au),
            locale: const Locale('fr', 'FR'),
            helpText: 'Période (${PeriodePresence.maxJours} jours au plus)',
          );
          if (r != null) onChange(PeriodePresence.bornee(r.start, r.end, aujourdhui: aujourdhui));
        },
      ),
    ]);
  }
}

class TableauPeriodeView extends StatefulWidget {
  final PeriodePresence? periode;
  const TableauPeriodeView({super.key, this.periode});

  @override
  State<TableauPeriodeView> createState() => TableauPeriodeViewState();
}

class TableauPeriodeViewState extends State<TableauPeriodeView> {
  late PeriodePresence _periode = widget.periode ?? PeriodePresence.mois(HorlogePresences.maintenant());
  TableauPeriode? _tableau;
  Object? _erreur;
  bool _chargement = false;
  FormatExport? _export;
  int _demande = 0;

  @override
  void initState() {
    super.initState();
    actualiser();
  }

  Future<void> actualiser() async {
    final n = ++_demande;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final t = await const PresencesApi().tableau(context, _periode);
      if (!mounted || n != _demande) return;
      setState(() {
        _tableau = t;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted || n != _demande) return;
      setState(() {
        _erreur = e;
        _tableau = null;
        _chargement = false;
      });
    }
  }

  void _changerPeriode(PeriodePresence p) {
    if (p.correction != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(p.correction!), backgroundColor: Colors.orange));
    }
    setState(() => _periode = p);
    actualiser();
  }

  Future<void> _exporter(FormatExport f) async {
    if (_export != null) return; // un seul téléchargement à la fois
    setState(() => _export = f);
    try {
      final fichier = await const PresencesApi().exporter(context, _periode, f);
      if (!mounted) return;
      setState(() => _export = null);
      await ExportFichier.proposer(context, fichier, sujet: 'Présences ${_periode.texte}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _export = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${f.libelle} : ${messageErreur(e)}'), backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tablette = estTablette(context);
    final t = _tableau;
    final List<Widget> corps;
    if (_erreur != null) {
      corps = [BlocErreur(message: messageErreur(_erreur!), onRetry: actualiser)];
    } else if (t == null) {
      corps = const [];
    } else if (t.lignes.isEmpty) {
      corps = const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Text('Aucun employé prévu ni pointé sur cette période.', key: Key('tableau_vide'), textAlign: TextAlign.center),
        ),
      ];
    } else {
      corps = [
        CartePresence(
          padding: EdgeInsets.zero,
          child: Column(children: [
            _entete(tablette),
            for (final l in t.lignes) _ligne(l, tablette),
          ]),
        ),
      ];
    }
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: actualiser,
          child: ListView(
            key: const Key('tableau_liste'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            children: [
              ChoixPeriode(periode: _periode, onChange: _changerPeriode),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  [
                    _periode.texte,
                    '${_periode.nombreJours} j',
                    if (t != null) '${t.lignes.length} employé${t.lignes.length > 1 ? 's' : ''}',
                  ].join(' · '),
                  key: const Key('tableau_titre'),
                  style: const TextStyle(color: couleurGris, fontSize: 13),
                ),
              ),
              if (_chargement) const LinearProgressIndicator(),
              ...corps,
            ],
          ),
        ),
      ),
      _barreExports(),
    ]);
  }

  static const _styleEntete = TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: couleurGris);

  Widget _entete(bool tablette) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Row(children: [
          const Expanded(flex: 5, child: Text('Employé', style: _styleEntete)),
          const Expanded(flex: 3, child: Text('Jours', textAlign: TextAlign.right, style: _styleEntete)),
          const Expanded(flex: 4, child: Text('Retards', textAlign: TextAlign.right, style: _styleEntete)),
          if (tablette) const Expanded(flex: 3, child: Text('Absences', textAlign: TextAlign.right, style: _styleEntete)),
          const Expanded(flex: 4, child: Text('Heures', textAlign: TextAlign.right, style: _styleEntete)),
          if (tablette) const Expanded(flex: 3, child: Text('Sup.', textAlign: TextAlign.right, style: _styleEntete)),
          const Expanded(flex: 2, child: Icon(Icons.warning_amber_rounded, size: 16, color: couleurGris)),
        ]),
      );

  Widget _ligne(TableauLigne l, bool tablette) {
    const style = TextStyle(fontSize: 13, color: couleurEncre);
    return InkWell(
      key: Key('tableau_${l.employeId}'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FicheEmployeScreen(employeId: l.employeId, employe: l.nomAffiche, matricule: l.matricule, periode: _periode),
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Expanded(flex: 5, child: Text(l.nomAffiche, maxLines: 2, overflow: TextOverflow.ellipsis, style: style.copyWith(fontWeight: FontWeight.w600))),
          Expanded(flex: 3, child: Text('${l.joursPresents}/${l.joursPrevus}', textAlign: TextAlign.right, style: style)),
          Expanded(
            flex: 4,
            child: Text(
              l.retards == 0 ? '0' : '${l.retards} · ${dureeLisible(l.minutesRetard)}',
              textAlign: TextAlign.right,
              style: style.copyWith(color: l.retards > 0 ? couleurRetard : couleurEncre, fontWeight: l.retards > 0 ? FontWeight.bold : null),
            ),
          ),
          if (tablette)
            Expanded(
              flex: 3,
              child: Text('${l.absencesNonJustifiees}', textAlign: TextAlign.right,
                  style: style.copyWith(color: l.absencesNonJustifiees > 0 ? couleurAbsent : couleurEncre)),
            ),
          Expanded(flex: 4, child: Text(dureeLisible(l.minutesPresence), textAlign: TextAlign.right, style: style)),
          if (tablette) Expanded(flex: 3, child: Text(dureeLisible(l.heuresSup), textAlign: TextAlign.right, style: style)),
          Expanded(
            flex: 2,
            child: Text('${l.anomalies}', textAlign: TextAlign.right,
                style: style.copyWith(color: l.anomalies > 0 ? const Color(0xFF9F1239) : couleurEncre, fontWeight: l.anomalies > 0 ? FontWeight.bold : null)),
          ),
        ]),
      ),
    );
  }

  Widget _barreExports() => Material(
        color: Colors.white,
        elevation: 6,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              for (final f in FormatExport.values) ...[
                if (f != FormatExport.excel) const SizedBox(width: 8),
                Expanded(child: _boutonExport(f)),
              ],
            ]),
          ),
        ),
      );

  Widget _boutonExport(FormatExport f) {
    final contenu = _export == f
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : FittedBox(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.download, size: 18),
              const SizedBox(width: 4),
              Text(f.libelle),
            ]),
          );
    final style = ButtonStyle(padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 6, vertical: 10)));
    final onPressed = _export == null ? () => _exporter(f) : null;
    return f == FormatExport.pdf
        ? FilledButton(key: Key('export_${f.name}'), onPressed: onPressed, style: style, child: contenu)
        : OutlinedButton(key: Key('export_${f.name}'), onPressed: onPressed, style: style, child: contenu);
  }
}
