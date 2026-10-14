// lib/nouvelle_interface/vague1/valorisation_vague1.dart
// Menu « Valorisation » de la NOUVELLE interface (l'ancienne garde son écran) : valeur du stock en trois onglets
// Rayon / Réserve / Total (valeur d'achat, valeur de vente, écart, marge % = écart / vente, comme l'écran web).
//  - aujourd'hui, sans regroupement : GET /tableau-bord/valorisation, chargé à l'ouverture (léger, cache serveur de
//    15 min) ; le bouton ⟳ envoie frais=1 (relit la base) ;
//  - date passée ou regroupement Famille / Emplacement / Grossiste (cases à cocher, listes /common/…) :
//    GET /produit/valorisation, seulement sur « Calculer » (calcul potentiellement long sur l'historique) ;
//    « relevé indisponible » si releveDisponible:false (jour jamais relevé : les zéros ne sont pas une mesure).
// L'évolution du stock dans le temps reste accessible (écran existant).
// Composants communs du lot 1 : calendrier d'une date (periode.dart), puces, états, lignes de détail et feuille du
// bas (commun.dart).
import 'package:flutter/material.dart';

import '../modules/evolution_stock_nouveau.dart';
import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/periode.dart';
import 'commun_vague1.dart';
import 'donnees_vague1.dart';

class ValorisationVague1 extends StatefulWidget {
  /// Date et regroupement proposés à l'ouverture (aujourd'hui, simple par défaut). Seule la valorisation du jour
  /// sans regroupement est calculée à l'ouverture ; sinon il faut toucher « Calculer ».
  final DateTime? dateInitiale;
  final ModeValorisation modeInitial;
  const ValorisationVague1({super.key, this.dateInitiale, this.modeInitial = ModeValorisation.simple});

  @override
  State<ValorisationVague1> createState() => _ValorisationVague1State();
}

/// Paramètres d'un calcul (pour savoir si le résultat affiché correspond aux choix à l'écran).
class _Demande {
  final DateTime date;
  final ModeValorisation mode;
  final Set<String> ids;
  const _Demande(this.date, this.mode, this.ids);

  bool egale(_Demande o) => memeJour(date, o.date) && mode == o.mode && ids.length == o.ids.length && ids.containsAll(o.ids);
}

class _ValorisationVague1State extends State<ValorisationVague1> with SingleTickerProviderStateMixin {
  late final _onglets = TabController(length: OngletStock.values.length, vsync: this);
  late DateTime _date = jourDe(widget.dateInitiale ?? DateTime.now());
  ModeValorisation _mode = ModeValorisation.simple;
  final _choisis = <String, Set<String>>{};
  final _options = <ModeValorisation, List<OptionListe>>{};
  Object? _erreurOptions;
  bool _chargementOptions = false;

  Valorisation? _resultat;
  _Demande? _demandeAffichee;
  Object? _erreur;
  bool _chargement = false;
  int _generation = 0;

  Set<String> get _ids => _choisis[_mode.name] ?? <String>{};
  _Demande get _demande => _Demande(_date, _mode, {..._ids});
  bool get _duJourSimple => ApiValorisation.parTableauDeBord(_mode, _date, DateTime.now());

  @override
  void initState() {
    super.initState();
    _onglets.addListener(() {
      if (mounted) setState(() {});
    });
    // Aujourd'hui, sans regroupement : léger, chargé à l'ouverture (comme le tableau de bord web).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.modeInitial != ModeValorisation.simple) _changerMode(widget.modeInitial);
      if (_duJourSimple) _calculer();
    });
  }

  @override
  void dispose() {
    _champFiltre.dispose();
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _calculer({bool frais = false}) async {
    if (_chargement) return;
    final demande = _demande;
    final generation = ++_generation;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final r = await ApiValorisation.charger(context, mode: demande.mode, date: demande.date, ids: demande.ids, frais: frais);
      if (!mounted || generation != _generation) return;
      setState(() {
        _resultat = r;
        _demandeAffichee = demande;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _erreur = e;
        _chargement = false;
      });
    }
  }

  Future<void> _choisirDate() async {
    final d = await choisirJour(context, _date, aide: 'Date de valorisation');
    if (d == null || !mounted) return;
    setState(() => _date = d);
  }

  Future<void> _changerMode(ModeValorisation m) async {
    setState(() => _mode = m);
    if (m == ModeValorisation.simple || _options.containsKey(m)) return;
    setState(() {
      _chargementOptions = true;
      _erreurOptions = null;
    });
    try {
      final o = await ApiValorisation.options(context, m);
      if (!mounted) return;
      setState(() {
        _options[m] = o;
        _chargementOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erreurOptions = e;
        _chargementOptions = false;
      });
    }
  }

  /// Champ « Filtrer » de la feuille de choix (gardé par l'écran : la feuille peut encore s'animer après sa fermeture).
  final _champFiltre = TextEditingController();

  /// Choix des familles / emplacements / grossistes dans la feuille du bas commune (« Effacer », « Appliquer »).
  Future<void> _choisirElements() async {
    final options = _options[_mode] ?? const <OptionListe>[];
    final choisis = {..._ids};
    var filtre = '';
    _champFiltre.clear();
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Choisir des ${_mode.pluriel}',
      effacer: choisis.clear,
      contenu: (ctx, setState) {
        final q = filtre.toLowerCase();
        final visibles = [for (final o in options) if (q.isEmpty || o.libelle.toLowerCase().contains(q)) o];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ChampRecherche(
            controleur: _champFiltre,
            libelle: 'Filtrer',
            antiRebond: const Duration(milliseconds: 200),
            onRecherche: (t) => setState(() => filtre = t),
          ),
          const SizedBox(height: 4),
          if (visibles.isEmpty)
            const EtatVide(titre: 'Aucun élément', texte: 'Modifiez le filtre.')
          else
            for (final o in visibles)
              CheckboxListTile(
                value: choisis.contains(o.id),
                title: Text(o.libelle),
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => v == true ? choisis.add(o.id) : choisis.remove(o.id)),
              ),
        ]);
      },
    );
    if (applique && mounted) setState(() => _choisis[_mode.name] = choisis);
  }

  String get _libelleChoix {
    final n = _ids.length;
    final (tous, un, plusieurs) = switch (_mode) {
      ModeValorisation.famille => ('Toutes les familles', 'famille choisie', 'familles choisies'),
      ModeValorisation.emplacement => ('Tous les emplacements', 'emplacement choisi', 'emplacements choisis'),
      ModeValorisation.grossiste => ('Tous les grossistes', 'grossiste choisi', 'grossistes choisis'),
      ModeValorisation.simple => ('', '', ''),
    };
    return n == 0 ? tous : '$n ${n > 1 ? plusieurs : un}';
  }

  @override
  Widget build(BuildContext context) {
    final aJour = _demandeAffichee != null && _demandeAffichee!.egale(_demande);
    final r = _resultat;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Valorisation du Stock'),
        actions: [
          IconButton(
            key: const Key('valorisation_evolution'),
            tooltip: 'Évolution du stock',
            icon: const Icon(Icons.ssid_chart_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EvolutionStockNouveau())),
          ),
          IconButton(
            key: const Key('valorisation_actualiser'),
            tooltip: _duJourSimple ? 'Actualiser (relire la base)' : 'Calculer',
            icon: const Icon(Icons.refresh),
            onPressed: _chargement ? null : () => _calculer(frais: _duJourSimple),
          ),
        ],
      ),
      body: ListView(key: const Key('defilement_valorisation'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        CarteSection(
          titre: 'Date et regroupement',
          icone: Icons.tune,
          enfants: [
            OutlinedButton.icon(
              key: const Key('valorisation_date'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _choisirDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(memeJour(_date, DateTime.now()) ? 'Aujourd\'hui (${dateCourte(_date)})' : 'Au ${dateCourte(_date)}'),
            ),
            const SizedBox(height: 10),
            PucesChoix<ModeValorisation>(
              cle: (_, libelle) => Key('mode_$libelle'),
              choix: [for (final m in ModeValorisation.values) (m, m.libelle)],
              valeur: _mode,
              onChanged: _changerMode,
            ),
            if (_mode != ModeValorisation.simple) ...[
              const SizedBox(height: 8),
              if (_chargementOptions)
                const LinearProgressIndicator()
              else if (_erreurOptions != null)
                EtatErreur(key: const Key('erreur_options'), erreur: _erreurOptions!, reessayer: () {
                  _options.remove(_mode);
                  _changerMode(_mode);
                })
              else
                OutlinedButton.icon(
                  key: const Key('valorisation_choix'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: _choisirElements,
                  icon: const Icon(Icons.checklist),
                  label: Text(_libelleChoix),
                ),
            ],
            if (!_duJourSimple)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Date passée ou regroupement : calcul sur l\'historique, il peut prendre du temps.',
                    style: TextStyle(color: Charte.gris, fontSize: 13)),
              ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              key: const Key('valorisation_calculer'),
              onPressed: _chargement ? null : () => _calculer(),
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Calculer'),
            ),
          ],
        ),
        if (_chargement) const EtatChargement(texte: 'Calcul de la valorisation…'),
        if (_erreur != null) EtatErreur(erreur: _erreur!, reessayer: () => _calculer()),
        if (r != null && !_chargement) ...[
          if (!aJour)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Encadre(
                key: Key('valorisation_perimee'),
                texte: 'Les choix ont changé : touchez « Calculer » pour mettre les montants à jour.',
                icone: Icons.info_outline,
                avertissement: true,
              ),
            ),
          _Resultat(valorisation: r, demande: _demandeAffichee!, onglets: _onglets),
        ],
      ]),
    );
  }
}

class _Resultat extends StatelessWidget {
  final Valorisation valorisation;
  final _Demande demande;
  final TabController onglets;
  const _Resultat({required this.valorisation, required this.demande, required this.onglets});

  @override
  Widget build(BuildContext context) {
    final v = valorisation;
    final source = switch (v.source) {
      SourceValorisation.tableauDeBord => 'Stock de votre emplacement, aujourd\'hui (calcul en direct)',
      SourceValorisation.calculDuJour => 'Aujourd\'hui, calcul en direct · ${demande.mode.libelle}',
      SourceValorisation.releve => 'Relevé du ${dateCourte(demande.date)} · ${demande.mode.libelle}',
    };
    if (!v.releveDisponible) {
      return Encadre(
        key: const Key('valorisation_releve_indisponible'),
        titre: 'Relevé indisponible',
        texte: 'Aucun relevé du stock n\'a été fait le ${dateCourte(demande.date)} : les montants de ce jour ne sont pas '
            'connus. Choisissez une autre date.',
        icone: Icons.event_busy,
        avertissement: true,
      );
    }
    final valeurs = v.de(OngletStock.values[onglets.index]);
    return Container(
      decoration: BoxDecoration(
        color: Charte.blanc,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TabBar(
          key: const Key('valorisation_onglets'),
          controller: onglets,
          tabs: [for (final o in OngletStock.values) Tab(height: 48, text: o.libelle)],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(source, key: const Key('valorisation_source'), style: const TextStyle(color: Charte.gris, fontSize: 13)),
            const SizedBox(height: 8),
            LigneDetail('Valeur d\'achat', formaterMontant(valeurs.achat), gras: true),
            LigneDetail('Valeur de vente', formaterMontant(valeurs.vente), gras: true),
            const Divider(height: 16),
            LigneDetail('Écart (vente − achat)', formaterMontant(valeurs.ecart),
                couleur: valeurs.ecart < 0 ? Charte.rougeTexte : Charte.vertTexte),
            LigneDetail('Marge', pourcent(valeurs.margePourcent), couleur: (valeurs.margePourcent ?? 0) < 0 ? Charte.rougeTexte : null),
            if (v.dormants != null && v.dormants! > 0) ...[
              const Divider(height: 16),
              LigneDetail('Produits dormants', '${grouperMilliers(v.dormants!)} (achat ${formaterMontant(v.dormantsValeurAchat)})'),
            ],
          ]),
        ),
      ]),
    );
  }
}
