// lib/nouvelle_interface/vague3/avis_vague3.dart
// Menu « Avis » (web « avisclients ») : avis laissés par les clients (QR code de l'officine).
// Droits vérifiés par le serveur : P_SM_AVIS_CLIENTS (lire), P_AVIS_REPONDRE (traiter). GET /avis-clients/droits au
// chargement : sans droit de lecture → « Droit manquant » ; sans « répondre » → l'action « Traiter » n'existe pas.
//  - onglet « Avis » : liste paginée par 50 (« Afficher plus »), période (30 derniers jours comme le web), recherche
//    « contient » (texte, employé, client), filtres note / statut / mot-clé / employé / thème / réponse attendue et tri
//    dans la feuille du bas ;
//  - détail d'un avis : ATTENTION, GET /avis-clients/avis/{id} passe un avis NOUVEAU à LU (écriture). Il n'est appelé
//    QUE lorsque l'utilisateur touche l'avis — jamais en préchargement, ni au retour dans la liste (la liste est mise
//    à jour avec le statut renvoyé, sans relecture) ;
//  - « Traiter » : statut Nouveau / Lu / Traité et note interne (1500 caractères, nettoyée comme le serveur), POST
//    /avis-clients/avis/{id}/traiter, un envoi par appui ;
//  - « Remettre en Nouveau » (3.8.0, demande du pharmacien) : bouton visible dans le détail d'un avis Lu ou Traité,
//    seulement avec droits.repondre ; même route « traiter » avec le statut NOUVEAU (accepté par le serveur :
//    AvisClientService.traiter) et la note interne ENREGISTRÉE renvoyée telle quelle (le serveur réécrit la note à
//    chaque traitement : elle n'est donc pas effacée) ; confirmation légère, un envoi par appui ;
//  - onglet « Analyse » : GET /avis-clients/analyse?du=&au= (synthèse comparée à la période précédente, alertes —
//    touchables : elles filtrent la liste —, points forts / à améliorer, notes, critères, thèmes, employés cités,
//    mots-clés, évolution).
// PAS de « Répondre au client » (envoi WhatsApp / e-mail), PAS de réglages, d'affiche ni de régénération du jeton
// (secret) : ces routes sont refusées avant envoi (donnees_vague3.dart). Nom, téléphone et e-mail du client :
// affichés seulement, jamais journalisés ni gardés sur le disque.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/commun_lot2.dart';
import '../modules/periode.dart';
import '../vague2/commun_vague2.dart' show BarresHorizontales, GrilleChiffres, ongletsBlancs;
import 'donnees_vague3.dart';

/// Étoiles d'une note (icônes + texte lu par le lecteur d'écran : « Note 4 sur 5 »).
class Etoiles extends StatelessWidget {
  final int note;
  final double taille;
  const Etoiles(this.note, {super.key, this.taille = 18});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Note $note sur 5',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 1; i <= 5; i++) Icon(i <= note ? Icons.star : Icons.star_border, size: taille, color: i <= note ? Charte.ambre : Charte.gris),
        ]),
      );
}

Etiquette etiquetteStatutAvis(StatutAvis? s) => switch (s) {
      StatutAvis.nouveau => const Etiquette('Nouveau', ton: Ton.ambre),
      StatutAvis.lu => const Etiquette('Lu', ton: Ton.bleu),
      StatutAvis.traite => const Etiquette('Traité', ton: Ton.vert),
      null => const Etiquette('—', ton: Ton.gris),
    };

String _nombreTexte(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1).replaceAll('.', ',');

class AvisScreen extends StatefulWidget {
  final DateTime Function() maintenant;
  final int ongletInitial;
  const AvisScreen({super.key, this.maintenant = DateTime.now, this.ongletInitial = 0});

  @override
  State<AvisScreen> createState() => _AvisScreenState();
}

class _AvisScreenState extends State<AvisScreen> with SingleTickerProviderStateMixin {
  late final _onglets = TabController(length: 2, vsync: this, initialIndex: widget.ongletInitial);
  final _recherche = TextEditingController();

  DroitsAvis? _droits;
  Object? _erreurDroits;

  late FiltresAvis _filtres = FiltresAvis.parDefaut(widget.maintenant());
  late Periode _periode = Periode.personnalisee(_filtres.debut, _filtres.fin, widget.maintenant())!;
  final _avis = <Avis>[];
  int _total = 0;
  bool _chargement = false;
  bool _chargementPlus = false;
  Object? _erreur;
  int _generation = 0;
  bool _listeChargee = false;

  late Periode _periodeAnalyse = _periode;
  AnalyseAvis? _analyse;
  Object? _erreurAnalyse;
  bool _chargementAnalyse = false;
  int _generationAnalyse = 0;

  /// Prévient la feuille des filtres (route à part) que l'analyse — donc la liste des employés — a changé.
  final _versionAnalyse = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _onglets.addListener(() {
      if (!mounted || _onglets.indexIsChanging) return;
      setState(() {});
      if (_onglets.index == 1 && _analyse == null && !_chargementAnalyse && _droits != null) _chargerAnalyse();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chargerDroits();
    });
  }

  @override
  void dispose() {
    _onglets.dispose();
    _recherche.dispose();
    _versionAnalyse.dispose();
    super.dispose();
  }

  Future<void> _chargerDroits() async {
    setState(() {
      _erreurDroits = null;
      _droits = null;
    });
    try {
      final d = await ApiAvis.droits(context);
      if (!mounted) return;
      setState(() => _droits = d);
      if (_onglets.index == 0) {
        _charger();
      } else {
        _chargerAnalyse();
      }
    } catch (e) {
      if (mounted) setState(() => _erreurDroits = e);
    }
  }

  Future<void> _charger({bool plus = false}) async {
    final g = ++_generation;
    final f = _filtres;
    final start = plus ? _avis.length : 0;
    setState(() {
      _erreur = null;
      if (plus) {
        _chargementPlus = true;
      } else {
        _chargement = true;
      }
    });
    try {
      final r = await ApiAvis.liste(context, f, start: start);
      if (!mounted || g != _generation) return;
      setState(() {
        if (!plus) _avis.clear();
        _avis.addAll(r.lignes);
        _total = r.total;
        _chargement = false;
        _chargementPlus = false;
        _listeChargee = true;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _chargement = false;
        _chargementPlus = false;
      });
    }
  }

  Future<void> _chargerAnalyse() async {
    final g = ++_generationAnalyse;
    final p = _periodeAnalyse;
    setState(() {
      _chargementAnalyse = true;
      _erreurAnalyse = null;
    });
    try {
      final a = await ApiAvis.analyse(context, p.debut, p.fin);
      if (!mounted || g != _generationAnalyse) return;
      setState(() {
        _analyse = a;
        _chargementAnalyse = false;
      });
    } catch (e) {
      if (!mounted || g != _generationAnalyse) return;
      setState(() {
        _erreurAnalyse = e;
        _chargementAnalyse = false;
      });
    }
    _versionAnalyse.value++;
  }

  void _appliquer(FiltresAvis f) {
    setState(() => _filtres = f);
    _charger();
  }

  /// Ouverture d'un avis : SEUL endroit où le détail est demandé (appui de l'utilisateur).
  Future<void> _ouvrir(Avis a) async {
    final droits = _droits;
    if (droits == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AvisDetailScreen(
        id: a.id,
        droits: droits,
        onMisAJour: (maj) {
          if (!mounted) return;
          setState(() {
            final i = _avis.indexWhere((x) => x.id == maj.id);
            if (i >= 0) _avis[i] = maj;
          });
        },
      ),
    ));
  }

  /// Une alerte ou un employé de l'analyse filtre la liste (onglet « Avis »).
  void _filtrerDepuisAnalyse(Map<String, String> filtre, {String libelleEmploye = ''}) {
    var f = _filtres.sansFiltres().copie(debut: _periodeAnalyse.debut, fin: _periodeAnalyse.fin);
    final note = NoteAvis.values.where((n) => n.code == (filtre['note'] ?? '')).firstOrNull;
    final statut = FiltreStatutAvis.values.where((s) => s.code == (filtre['statut'] ?? '')).firstOrNull;
    f = f.copie(
      note: note ?? NoteAvis.toutes,
      statut: statut ?? FiltreStatutAvis.tous,
      reponseAttendue: filtre['reponse'] == 'ATTENDUE',
      employe: filtre['employe'] ?? '',
      libelleEmploye: libelleEmploye,
      theme: filtre['theme'] ?? '',
      motCle: filtre['motCle'] ?? '',
    );
    setState(() => _periode = _periodeAnalyse);
    _onglets.animateTo(0);
    _appliquer(f);
  }

  Future<void> _ouvrirFiltres() async {
    var f = _filtres;
    final motCle = TextEditingController(text: f.motCle);
    String? erreurMotCle;
    final droits = _droits;
    // Employés cités : ceux de l'analyse de la même période (comme le web), lue une fois à la demande.
    if (_analyse == null && !_chargementAnalyse) {
      _periodeAnalyse = _periode;
      _chargerAnalyse();
    }
    final ok = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les avis',
      effacer: () {
        f = f.sansFiltres();
        motCle.clear();
        erreurMotCle = null;
      },
      valider: () {
        erreurMotCle = ControleAvis.erreurMotCle(motCle.text);
        return erreurMotCle == null;
      },
      contenu: (ctx, majFeuille) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _TitreFiltre('Note'),
          PucesChoix<NoteAvis>(
            choix: [for (final n in NoteAvis.values) (n, n.libelle)],
            valeur: f.note,
            cle: (n, _) => Key('filtre_note_${n.name}'),
            onChanged: (n) => majFeuille(() => f = f.copie(note: n)),
          ),
          const _TitreFiltre('Statut'),
          PucesChoix<FiltreStatutAvis>(
            choix: [for (final s in FiltreStatutAvis.values) (s, s.libelle)],
            valeur: f.statut,
            cle: (s, _) => Key('filtre_statut_${s.name}'),
            onChanged: (s) => majFeuille(() => f = f.copie(statut: s)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('filtre_reponse_attendue'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Seulement les clients qui attendent une réponse'),
            value: f.reponseAttendue,
            onChanged: (v) => majFeuille(() => f = f.copie(reponseAttendue: v)),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('filtre_mot_cle'),
            controller: motCle,
            maxLength: ControleAvis.maxMotCle,
            inputFormatters: [FilteringTextInputFormatter.allow(ControleAvis.caracteresMotCle)],
            decoration: InputDecoration(labelText: 'Mot-clé du texte', prefixIcon: const Icon(Icons.short_text), errorText: erreurMotCle),
            onChanged: (_) {
              if (erreurMotCle != null) majFeuille(() => erreurMotCle = ControleAvis.erreurMotCle(motCle.text));
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('filtre_theme'),
            value: (droits?.themes ?? const <String>[]).contains(f.theme) ? f.theme : '',
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Thème', prefixIcon: Icon(Icons.topic_outlined)),
            items: [
              const DropdownMenuItem(value: '', child: Text('Tous les thèmes')),
              for (final t in droits?.themes ?? const <String>[]) DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => majFeuille(() => f = f.copie(theme: v ?? '')),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: _versionAnalyse,
            builder: (_, __, ___) {
              final employes = _analyse?.employes ?? const <EmployeAvis>[];
              return DropdownButtonFormField<String>(
                key: const Key('filtre_employe'),
                value: f.employe.isEmpty || employes.any((e) => e.cle == f.employe) ? f.employe : '',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Employé cité',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  helperText: _erreurAnalyse != null ? 'Liste indisponible' : (_analyse == null ? 'Chargement de la liste…' : null),
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Tous')),
                  for (final e in employes) DropdownMenuItem(value: e.cle, child: Text('${e.employe} (${e.nombre})', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: _analyse == null
                    ? null
                    : (v) => majFeuille(() {
                          final e = employes.where((x) => x.cle == v).firstOrNull;
                          f = f.copie(employe: v ?? '', libelleEmploye: e?.employe ?? '');
                        }),
              );
            },
          ),
          const _TitreFiltre('Tri'),
          PucesChoix<TriAvis>(
            choix: [for (final t in TriAvis.values) (t, t.libelle)],
            valeur: f.tri,
            cle: (t, _) => Key('filtre_tri_${t.name}'),
            onChanged: (t) => majFeuille(() => f = f.copie(tri: t)),
          ),
        ]);
      },
    );
    final mot = motCle.text.trim();
    motCle.dispose();
    if (ok && mounted) _appliquer(f.copie(motCle: mot));
  }

  @override
  Widget build(BuildContext context) {
    final avisOuvert = _onglets.index == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avis'),
        actions: [
          if (avisOuvert && _droits != null) BoutonFiltres(actifs: _filtres.actifs, onPressed: _ouvrirFiltres),
          IconButton(
            key: const Key('avis_actualiser'),
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
            onPressed: _droits == null ? _chargerDroits : (avisOuvert ? (_chargement ? null : _charger) : (_chargementAnalyse ? null : _chargerAnalyse)),
          ),
        ],
        bottom: ongletsBlancs(_onglets, const ['Avis', 'Analyse'], key: const Key('onglets_avis')),
      ),
      body: TabBarView(controller: _onglets, children: [
        _ongletAvis(),
        _ongletAnalyse(),
      ]),
    );
  }

  List<Widget> _etatDroits() => [
        if (_erreurDroits != null) EtatErreur(erreur: _erreurDroits!, reessayer: _chargerDroits),
        if (_droits == null && _erreurDroits == null) const EtatChargement(texte: 'Chargement des avis…'),
      ];

  Widget _ongletAvis() => ListView(key: const Key('defilement_avis'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        ..._etatDroits(),
        if (_droits != null) ...[
          SelecteurPeriode(
            periode: _periode,
            maintenant: widget.maintenant,
            onChanged: (p) {
              setState(() => _periode = p);
              _appliquer(_filtres.copie(debut: p.debut, fin: p.fin));
            },
          ),
          const SizedBox(height: 8),
          ChampRecherche(
            controleur: _recherche,
            libelle: 'Rechercher dans les avis',
            aide: 'Texte, employé, client',
            enCours: _chargement && _filtres.contient.isNotEmpty,
            onRecherche: (t) => _appliquer(_filtres.copie(contient: t)),
          ),
          EtiquettesFiltres(etiquettes: _filtres.etiquettes, onRetirer: () => _appliquer(_filtres.sansFiltres())),
          const SizedBox(height: 8),
          if (_chargement) const EtatChargement(texte: 'Chargement des avis…'),
          if (_erreur != null && !_chargement) EtatErreur(erreur: _erreur!, reessayer: _charger),
          if (_listeChargee && !_chargement && _erreur == null && _avis.isEmpty)
            const EtatVide(titre: 'Aucun avis', texte: 'Aucun avis ne correspond à la période et aux filtres.', icone: Icons.reviews_outlined),
          if (!_chargement && _avis.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                '$_total avis${_droits!.nouveaux > 0 ? ' · ${_droits!.nouveaux} nouveau${_droits!.nouveaux > 1 ? 'x' : ''} au total' : ''}',
                key: const Key('avis_total'),
                style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600),
              ),
            ),
            for (final a in _avis) _CarteAvis(key: Key('avis_${a.id}'), avis: a, onTap: () => _ouvrir(a)),
            PiedPagination(affichees: _avis.length, total: _total, enCours: _chargementPlus, onPlus: () => _charger(plus: true)),
          ],
        ],
      ]);

  Widget _ongletAnalyse() {
    final a = _analyse;
    return ListView(key: const Key('defilement_analyse_avis'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      ..._etatDroits(),
      if (_droits != null) ...[
        SelecteurPeriode(
          key: const Key('periode_analyse_avis'),
          periode: _periodeAnalyse,
          maintenant: widget.maintenant,
          onChanged: (p) {
            setState(() => _periodeAnalyse = p);
            _chargerAnalyse();
          },
        ),
        const SizedBox(height: 8),
        if (_chargementAnalyse) const EtatChargement(texte: 'Analyse des avis…'),
        if (_erreurAnalyse != null && !_chargementAnalyse) EtatErreur(erreur: _erreurAnalyse!, reessayer: _chargerAnalyse),
        if (a != null && !_chargementAnalyse) ..._analyseRemplie(a),
      ],
    ]);
  }

  List<Widget> _analyseRemplie(AnalyseAvis a) {
    final s = a.synthese;
    if (s.nombre == 0) {
      return [const EtatVide(titre: 'Aucun avis sur la période', icone: Icons.reviews_outlined)];
    }
    return [
      GrilleChiffres([
        ChiffreCle(libelle: 'Avis', valeur: '${s.nombre}', detail: 'période précédente : ${s.precedentNombre}', id: 'avis_nombre'),
        ChiffreCle(
            libelle: 'Note moyenne', valeur: '${_nombreTexte(s.moyenne)} / 5', detail: 'précédente : ${_nombreTexte(s.precedentMoyenne)}', enAvant: true, id: 'avis_moyenne'),
        ChiffreCle(libelle: 'Satisfaits (4–5 ★)', valeur: '${_nombreTexte(s.satisfaits)} %', detail: 'précédente : ${_nombreTexte(s.precedentSatisfaits)} %'),
        ChiffreCle(libelle: 'Mécontents (1–2 ★)', valeur: '${_nombreTexte(s.mecontents)} %'),
        ChiffreCle(libelle: 'Nouveaux', valeur: '${s.nouveaux}'),
        ChiffreCle(libelle: 'Négatifs non traités', valeur: '${s.negatifsNonTraites}', id: 'avis_negatifs_non_traites'),
        ChiffreCle(libelle: 'Réponses attendues', valeur: '${s.reponsesAttendues}'),
      ]),
      const SizedBox(height: 12),
      if (a.alertes.isNotEmpty)
        CarteSection(titre: 'À regarder', icone: Icons.priority_high, enfants: [
          for (var i = 0; i < a.alertes.length; i++)
            _LigneAlerte(
              key: Key('alerte_avis_$i'),
              alerte: a.alertes[i],
              onTap: a.alertes[i].filtre == null ? null : () => _filtrerDepuisAnalyse(a.alertes[i].filtre!),
            ),
        ]),
      if (a.forts.isNotEmpty || a.faibles.isNotEmpty)
        CarteSection(titre: 'Bilan', icone: Icons.balance_outlined, enfants: [
          for (final t in a.forts) _Puce(texte: t, positif: true),
          for (final t in a.faibles) _Puce(texte: t, positif: false),
        ]),
      CarteSection(titre: 'Notes', icone: Icons.star_outline, enfants: [
        BarresHorizontales(
          largeurLibelle: 48,
          barres: [for (final (n, nb, part) in a.repartition) ('$n ★', nb.toDouble(), '$nb (${_nombreTexte(part)} %)')],
        ),
      ]),
      if (a.criteres.isNotEmpty)
        CarteSection(titre: 'Critères', icone: Icons.checklist, enfants: [
          for (final c in a.criteres)
            LigneDetail(c.libelle,
                '${c.plus} apprécié${c.plus > 1 ? 's' : ''} · ${c.moins} à améliorer${c.satisfaction == null ? '' : ' · ${c.satisfaction} %'}'),
        ]),
      if (a.themes.isNotEmpty)
        CarteSection(titre: 'Thèmes évoqués', icone: Icons.topic_outlined, enfants: [
          for (final t in a.themes) LigneDetail(t.theme, '${t.nombre} avis · ${t.negatifs} négatif${t.negatifs > 1 ? 's' : ''} · moy. ${_nombreTexte(t.moyenne)}'),
        ]),
      if (a.employes.isNotEmpty)
        CarteSection(titre: 'Employés cités', icone: Icons.badge_outlined, enfants: [
          for (final e in a.employes)
            InkWell(
              key: Key('employe_avis_${e.cle}'),
              onTap: () => _filtrerDepuisAnalyse({'employe': e.cle}, libelleEmploye: e.employe),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(children: [
                  Expanded(child: LigneDetail(e.employe, '${e.nombre} avis · moy. ${_nombreTexte(e.moyenne)} · ${e.negatifs} négatif${e.negatifs > 1 ? 's' : ''}')),
                  const Icon(Icons.chevron_right, color: Charte.gris),
                ]),
              ),
            ),
        ]),
      if (a.motsCles.isNotEmpty)
        CarteSection(titre: 'Mots-clés', icone: Icons.short_text, enfants: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in a.motsCles.take(30))
              Etiquette('${m.mot} (${m.nombre})', ton: m.ton == 'positif' ? Ton.vert : (m.ton == 'negatif' ? Ton.rouge : Ton.gris)),
          ]),
        ]),
      if (a.evolution.isNotEmpty)
        CarteSection(titre: 'Évolution', icone: Icons.show_chart, enfants: [
          BarresHorizontales(
            largeurLibelle: 92,
            barres: [for (final e in a.evolution) (e.periode, e.nombre.toDouble(), e.nombre == 0 ? '0' : '${e.nombre} · ${_nombreTexte(e.moyenne)} ★')],
          ),
        ]),
    ];
  }
}

class _TitreFiltre extends StatelessWidget {
  final String texte;
  const _TitreFiltre(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(texte, style: const TextStyle(color: Charte.encre, fontWeight: FontWeight.bold)),
      );
}

class _Puce extends StatelessWidget {
  final String texte;
  final bool positif;
  const _Puce({required this.texte, required this.positif});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(positif ? Icons.thumb_up_alt_outlined : Icons.thumb_down_alt_outlined,
              size: 18, color: positif ? Charte.vertTexte : Charte.rougeTexte, semanticLabel: positif ? 'Point fort' : 'À améliorer'),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: const TextStyle(color: Charte.encre, fontSize: 14))),
        ]),
      );
}

class _LigneAlerte extends StatelessWidget {
  final AlerteAvis alerte;
  final VoidCallback? onTap;
  const _LigneAlerte({super.key, required this.alerte, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(alerte.haute ? Icons.error_outline : Icons.info_outline,
                  color: alerte.haute ? Charte.rougeTexte : Charte.ambreTexte, semanticLabel: alerte.haute ? 'Important' : 'À surveiller'),
              const SizedBox(width: 10),
              Expanded(child: Text(alerte.texte, style: const TextStyle(color: Charte.encre, fontSize: 14))),
              if (onTap != null) const Icon(Icons.chevron_right, color: Charte.gris),
            ]),
          ),
        ),
      );
}

/// Carte d'un avis dans la liste (sans coordonnées du client).
class _CarteAvis extends StatelessWidget {
  final Avis avis;
  final VoidCallback onTap;
  const _CarteAvis({super.key, required this.avis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = avis;
    final nouveau = a.statut == StatutAvis.nouveau;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarteBande(
        bande: a.negatif ? Charte.rouge : (a.positif ? Charte.vert : Charte.ambre),
        onTap: onTap,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Etoiles(a.note),
                etiquetteStatutAvis(a.statut),
                if (a.reponseAttendue) const Etiquette('Réponse attendue', ton: Ton.rouge),
              ]),
              const SizedBox(height: 4),
              Text(a.texte.isEmpty ? '(pas de texte)' : a.texte,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: a.texte.isEmpty ? Charte.gris : Charte.encre, fontWeight: nouveau ? FontWeight.bold : FontWeight.normal)),
              const SizedBox(height: 3),
              Text('${a.date}${a.employe.isEmpty ? '' : ' · employé cité : ${a.employe}'}', style: const TextStyle(fontSize: 13, color: Charte.gris)),
            ]),
          ),
          const Padding(padding: EdgeInsets.only(left: 4, top: 2), child: Icon(Icons.chevron_right, color: Charte.gris)),
        ]),
      ),
    );
  }
}

/// Détail d'un avis : ouvert par un appui sur l'avis (le serveur le marque alors « Lu » s'il était nouveau).
class AvisDetailScreen extends StatefulWidget {
  final String id;
  final DroitsAvis droits;

  /// Avis relu ou traité : la liste se met à jour sans nouvelle requête.
  final ValueChanged<Avis>? onMisAJour;
  const AvisDetailScreen({super.key, required this.id, required this.droits, this.onMisAJour});

  @override
  State<AvisDetailScreen> createState() => _AvisDetailScreenState();
}

class _AvisDetailScreenState extends State<AvisDetailScreen> with ChargementSuivi<AvisDetailScreen, Avis> {
  final _note = TextEditingController();
  StatutAvis _statut = StatutAvis.lu;
  bool _envoi = false;
  String? _erreurNote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    await charger(() => ApiAvis.ouvrir(context, widget.id));
    final a = donnees;
    if (a == null || !mounted) return;
    setState(() {
      _statut = a.statut ?? StatutAvis.lu;
      _note.text = a.noteInterne;
    });
    widget.onMisAJour?.call(a);
  }

  Future<void> _traiter() async {
    if (_envoi || !widget.droits.repondre) return; // un seul envoi à la fois ; jamais sans le droit
    final e = ControleAvis.erreurNoteInterne(_note.text);
    if (e != null) {
      setState(() => _erreurNote = e);
      return;
    }
    setState(() {
      _envoi = true;
      _erreurNote = null;
    });
    try {
      final maj = await ApiAvis.traiter(context, widget.id, _statut, _note.text);
      if (!mounted) return;
      final a = maj ?? donnees?.avecStatut(_statut, noteInterne: ControleAvis.nettoyerNoteInterne(_note.text));
      setState(() {
        if (a != null) {
          donnees = a;
          _statut = a.statut ?? _statut;
          _note.text = a.noteInterne;
        }
      });
      if (a != null) widget.onMisAJour?.call(a);
      messageResultat(context, 'Traitement enregistré : ${_statut.libelle}');
    } catch (e) {
      if (!mounted) return;
      final d = DiagnosticErreur.de(e);
      messageResultat(context, 'Traitement non enregistré : ${d.cause == CauseErreur.autre ? d.message : '${d.titre}. ${d.message}'}', echec: true);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  /// « Remettre en Nouveau » : confirmation légère, puis UN envoi (statut NOUVEAU, note interne enregistrée inchangée).
  Future<void> _remettreEnNouveau() async {
    final a = donnees;
    if (_envoi || !widget.droits.repondre || a == null || a.statut == StatutAvis.nouveau) return;
    setState(() => _envoi = true);
    try {
      final oui = await confirmer(
        context,
        titre: 'Remettre en « Nouveau »',
        texte: 'Cet avis apparaîtra de nouveau comme non lu pour toute l\'équipe. La note interne est gardée.',
        oui: 'Oui, remettre en Nouveau',
      );
      if (!oui || !mounted) return;
      final maj = await ApiAvis.traiter(context, widget.id, StatutAvis.nouveau, a.noteInterne);
      if (!mounted) return;
      final b = maj ?? a.avecStatut(StatutAvis.nouveau, noteInterne: a.noteInterne);
      setState(() {
        donnees = b;
        _statut = b.statut ?? StatutAvis.nouveau;
      });
      widget.onMisAJour?.call(b);
      messageResultat(context, 'Avis remis en « Nouveau ».');
    } catch (e) {
      if (!mounted) return;
      final d = DiagnosticErreur.de(e);
      messageResultat(context, 'Avis non remis en Nouveau : ${d.cause == CauseErreur.autre ? d.message : '${d.titre}. ${d.message}'}', echec: true);
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = donnees;
    return Scaffold(
      appBar: AppBar(title: const Text('Avis')),
      body: ListView(key: const Key('defilement_detail_avis'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        if (enCours) const EtatChargement(texte: 'Ouverture de l\'avis…'),
        if (erreur != null && !enCours) EtatErreur(erreur: erreur!, reessayer: _charger),
        if (a != null && !enCours) ..._contenu(a),
      ]),
    );
  }

  List<Widget> _contenu(Avis a) => [
        CarteSection(enfants: [
          Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Etoiles(a.note, taille: 24),
            Text('${a.note} / 5', style: const TextStyle(color: Charte.encre, fontWeight: FontWeight.bold, fontSize: 16)),
            etiquetteStatutAvis(a.statut),
          ]),
          const SizedBox(height: 4),
          Text(
              '${a.date}${a.memeAppareil != null && a.memeAppareil! > 0 ? ' · ${a.memeAppareil} autre${a.memeAppareil! > 1 ? 's' : ''} avis du même appareil' : ''}',
              style: const TextStyle(color: Charte.gris, fontSize: 13)),
          if (a.criteres.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in a.criteres.entries)
                Etiquette('${widget.droits.criteres[e.key] ?? e.key} : ${e.value == 'PLUS' ? 'apprécié' : 'à améliorer'}',
                    ton: e.value == 'PLUS' ? Ton.vert : Ton.rouge),
            ]),
          ],
          const SizedBox(height: 10),
          Text(a.texte.isEmpty ? '(pas de texte)' : a.texte,
              key: const Key('avis_texte'), style: TextStyle(color: a.texte.isEmpty ? Charte.gris : Charte.encre, fontSize: 15, height: 1.35)),
          if (a.employe.isNotEmpty) ...[
            const SizedBox(height: 8),
            LigneDetail('Employé cité', a.employe),
          ],
        ]),
        CarteSection(titre: 'Client', icone: Icons.person_outline, enfants: [
          if (a.anonyme)
            const Text('Anonyme', style: TextStyle(color: Charte.gris))
          else ...[
            if (a.nom.isNotEmpty) LigneDetail('Nom', a.nom),
            if (a.telephone.isNotEmpty) LigneDetail('Téléphone', a.telephone),
            if (a.email.isNotEmpty) LigneDetail('E-mail', a.email),
            LigneDetail('Réponse', a.rappel ? 'souhaitée' : 'non souhaitée'),
          ],
          if (a.reponse.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
                'Réponse ${a.canalReponse == 'EMAIL' ? 'par e-mail' : 'par WhatsApp'} le ${a.dateReponse}${a.auteurReponse.isEmpty ? '' : ', ${a.auteurReponse}'} :',
                style: const TextStyle(color: Charte.encre, fontWeight: FontWeight.bold)),
            Text(a.reponse, style: const TextStyle(color: Charte.encre)),
          ] else if (a.statutReponse == 'ECHEC')
            const Text('Le dernier envoi de réponse a échoué.', style: TextStyle(color: Charte.rougeTexte)),
          const SizedBox(height: 6),
          const Text('La réponse au client se fait depuis Prestige (web).', style: TextStyle(color: Charte.gris, fontSize: 13)),
        ]),
        _traitement(a),
      ];

  Widget _traitement(Avis a) {
    if (!widget.droits.repondre) {
      return CarteSection(key: const Key('avis_traitement_lecture'), titre: 'Traitement', icone: Icons.assignment_turned_in_outlined, enfants: [
        LigneDetail('Statut', a.statut?.libelle ?? '—'),
        if (a.noteInterne.isNotEmpty) LigneDetail('Note interne', a.noteInterne),
        const SizedBox(height: 6),
        const Encadre(
          titre: 'Lecture seule',
          texte: 'Le traitement des avis demande le droit « Répondre aux avis ». Demandez l\'accès à l\'administrateur.',
          icone: Icons.lock_outline,
          avertissement: true,
        ),
      ]);
    }
    return CarteSection(key: const Key('avis_traitement'), titre: 'Traiter', icone: Icons.assignment_turned_in_outlined, enfants: [
      if (a.statut == StatutAvis.lu || a.statut == StatutAvis.traite) ...[
        OutlinedButton.icon(
          key: const Key('avis_remettre_nouveau'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _envoi ? null : _remettreEnNouveau,
          icon: const Icon(Icons.mark_email_unread_outlined),
          label: const Text('Remettre en Nouveau'),
        ),
        const SizedBox(height: 12),
      ],
      PucesChoix<StatutAvis>(
        choix: [for (final s in StatutAvis.values) (s, s.libelle)],
        valeur: _statut,
        cle: (s, _) => Key('statut_avis_${s.code}'),
        onChanged: (s) => setState(() => _statut = s),
      ),
      const SizedBox(height: 10),
      TextField(
        key: const Key('note_interne'),
        controller: _note,
        enabled: !_envoi,
        minLines: 2,
        maxLines: 6,
        maxLength: ControleAvis.maxNoteInterne,
        decoration: InputDecoration(labelText: 'Note interne (non visible du client)', errorText: _erreurNote, alignLabelWithHint: true),
      ),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        key: const Key('avis_enregistrer'),
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        onPressed: _envoi ? null : _traiter,
        icon: _envoi
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Icon(Icons.save_outlined),
        label: Text(_envoi ? 'Enregistrement…' : 'Enregistrer le traitement'),
      ),
    ]);
  }
}
