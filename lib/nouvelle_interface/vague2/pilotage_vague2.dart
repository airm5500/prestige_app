// lib/nouvelle_interface/vague2/pilotage_vague2.dart
// Onglet « Pilotage » de la barre du bas (administrateur et pharmacien seulement ; droit P_SM_PILOTAGE vérifié par
// le serveur : un refus s'affiche « Droit manquant »). LECTURE SEULE :
//  - onglets internes « Synthèse » et « À suivre » (GET /pilotage/onglet/synthese|asuivre?axe=&dtStart=&dtEnd=) ;
//  - axe de comparaison (GET /pilotage/axes : MOIS, VS_M1, VS_N1, YTD, G12, PERSO) ; PERSO : dates contrôlées
//    (début ≤ fin, rien dans le futur, 3 ans au plus) ;
//  - tuiles : valeur, unité, référence et variation (flèche + « Hausse / Baisse » + couleur, jamais la couleur
//    seule).
// JAMAIS appelés : /pilotage/recalculer, POST /pilotage/charges. /pilotage/controler ÉCRIT en base (vérifie les
// mois affichés et recalcule ceux qui ont changé) : le web l'appelle à l'ouverture du menu et sur « Actualiser » ;
// sur le mobile, SEULEMENT par le bouton « Contrôler les chiffres », après confirmation, un appui à la fois.
import 'package:flutter/material.dart';

import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/periode.dart';
import 'commun_vague2.dart';
import 'donnees_vague2.dart';

class OngletPilotageAccueil extends StatefulWidget {
  /// Horloge (remplaçable dans les tests).
  final DateTime Function() maintenant;
  const OngletPilotageAccueil({super.key, this.maintenant = DateTime.now});

  @override
  State<OngletPilotageAccueil> createState() => _OngletPilotageAccueilState();
}

class _OngletPilotageAccueilState extends State<OngletPilotageAccueil> with SingleTickerProviderStateMixin {
  late final _onglets = TabController(length: OngletPilotage.values.length, vsync: this);
  List<AxePilotage> _axes = axesPilotageParDefaut;
  ChoixAxe _choix = const ChoixAxe(AxePilotage('MOIS', 'Mois en cours'));

  final _donnees = <String, DonneesPilotage>{};
  bool _chargement = false;
  Object? _erreur;
  int _generation = 0;
  bool _controleEnCours = false;

  OngletPilotage get _onglet => OngletPilotage.values[_onglets.index];
  String _cle(OngletPilotage o, ChoixAxe c) => '${o.cle}|${c.parametres}';

  @override
  void initState() {
    super.initState();
    _onglets.addListener(() {
      if (!mounted || _onglets.indexIsChanging) return;
      setState(() {});
      if (!_donnees.containsKey(_cle(_onglet, _choix))) _charger();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _chargerAxes();
      _charger();
    });
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _chargerAxes() async {
    try {
      final a = await ApiPilotage.axes(context);
      if (mounted) setState(() => _axes = a);
    } catch (_) {
      // Liste par défaut (celle du serveur) ; le refus éventuel s'affiche avec les chiffres.
    }
  }

  Future<void> _charger() async {
    final g = ++_generation;
    final o = _onglet, c = _choix;
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final d = await ApiPilotage.onglet(context, o, c, maintenant: widget.maintenant());
      if (!mounted || g != _generation) return;
      setState(() {
        _donnees[_cle(o, c)] = d;
        _chargement = false;
      });
    } catch (e) {
      if (!mounted || g != _generation) return;
      setState(() {
        _erreur = e;
        _chargement = false;
      });
    }
  }

  void _actualiser() {
    _donnees.clear();
    _charger();
  }

  Future<void> _choisirAxe(AxePilotage a) async {
    if (!a.personnalise) {
      setState(() => _choix = ChoixAxe(a));
      if (!_donnees.containsKey(_cle(_onglet, _choix))) _charger();
      return;
    }
    final now = widget.maintenant();
    final aujourdhui = Periode.jour(now);
    final r = await showDateRangePicker(
      context: context,
      firstDate: ControlePeriode.borneMin,
      lastDate: aujourdhui,
      initialDateRange: DateTimeRange(start: _choix.debut ?? DateTime(aujourdhui.year, aujourdhui.month, 1), end: _choix.fin ?? aujourdhui),
      locale: const Locale('fr', 'FR'),
      helpText: 'Période personnalisée',
      saveText: 'Valider',
    );
    if (r == null || !mounted) return;
    final erreur = ControlePeriode.erreur(r.start, r.end, now);
    if (erreur != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erreur)));
      return;
    }
    setState(() => _choix = ChoixAxe(a, debut: Periode.jour(r.start), fin: Periode.jour(r.end)));
    _charger();
  }

  /// « Contrôler les chiffres » : confirmation, puis UN appel à /pilotage/controler (anti double appui).
  Future<void> _controler() async {
    if (_controleEnCours) return;
    setState(() => _controleEnCours = true);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Contrôler les chiffres'),
          content: const Text('Prestige vérifie les ventes des mois affichés et recalcule les mois modifiés '
              '(vente annulée, bon de livraison saisi en retard). Cela peut prendre du temps.'),
          actions: [
            TextButton(key: const Key('controle_annuler'), onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
            ElevatedButton(key: const Key('controle_confirmer'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Contrôler')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final n = await ApiPilotage.controler(context, _choix, maintenant: widget.maintenant());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        key: const Key('controle_resultat'),
        content: Text(n == 0 ? 'Chiffres à jour : aucun mois à recalculer.' : '$n mois recalculé${n > 1 ? 's' : ''} : chiffres mis à jour.'),
      ));
      _actualiser();
    } catch (e) {
      if (!mounted) return;
      final d = DiagnosticErreur.de(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(key: const Key('controle_echec'), content: Text('${d.titre} : ${d.message}')));
    } finally {
      if (mounted) setState(() => _controleEnCours = false);
    }
  }

  String get _resumeAxe {
    final c = _choix;
    if (c.axe.personnalise && c.debut != null && c.fin != null) {
      String f(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      return 'Du ${f(c.debut!)} au ${f(c.fin!)}';
    }
    return c.axe.libelle;
  }

  @override
  Widget build(BuildContext context) {
    final d = _donnees[_cle(_onglet, _choix)];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      EnTeteNavy(
        titre: 'Pilotage',
        sousTitre: d == null || d.periode.isEmpty ? _resumeAxe : '${d.libellePeriode.isEmpty ? _resumeAxe : d.libellePeriode} · ${d.periode}',
        retour: false,
        actions: [
          IconButton(
            key: const Key('pilotage_actualiser'),
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh, color: Charte.blanc),
            onPressed: _chargement ? null : _actualiser,
          ),
        ],
      ),
      Material(
        color: Charte.blanc,
        child: TabBar(
          key: const Key('pilotage_onglets'),
          controller: _onglets,
          tabs: [for (final o in OngletPilotage.values) Tab(height: 48, text: o.libelle)],
        ),
      ),
      Expanded(
        child: ListView(key: const Key('defilement_pilotage'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          SingleChildScrollView(
            key: const Key('pilotage_axes'),
            scrollDirection: Axis.horizontal,
            child: PucesChoix<AxePilotage>(
              choix: [for (final a in _axes) (a, a.libelle)],
              valeur: _choix.axe,
              cle: (a, _) => Key('axe_${a.code}'),
              onChanged: _choisirAxe,
            ),
          ),
          if (d != null && d.libelleReference.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Text('Comparé à : ${d.libelleReference}${d.periodeReference.isEmpty ? '' : ' (${d.periodeReference})'}',
                  key: const Key('pilotage_reference'), style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 8),
          if (_chargement) const EtatChargement(texte: 'Chargement des chiffres…'),
          if (_erreur != null && !_chargement) EtatErreur(erreur: _erreur!, reessayer: _charger),
          if (d != null && !_chargement && _erreur == null) ...[
            if (d.tuiles.isEmpty)
              const EtatVide(titre: 'Aucun chiffre', texte: 'Aucun indicateur pour cette période.')
            else
              GrilleChiffres([for (final t in d.tuiles) TuileIndicateur(t)]),
            if (_onglet == OngletPilotage.aSuivre) _ASuivre(d),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('pilotage_controler'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _controleEnCours ? null : _controler,
            icon: _controleEnCours
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.fact_check_outlined),
            label: Text(_controleEnCours ? 'Contrôle en cours…' : 'Contrôler les chiffres'),
          ),
        ]),
      ),
    ]);
  }
}

/// Tuile d'indicateur : libellé, valeur, variation (flèche + texte + couleur), référence, précision.
class TuileIndicateur extends StatelessWidget {
  final TuilePilotage t;
  const TuileIndicateur(this.t, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        key: Key('tuile_${t.cle}'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(14),
          border: t.alerte ? Border.all(color: Charte.ambreBord, width: 1.5) : null,
          boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            if (t.alerte) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.warning_amber_rounded, size: 16, color: Charte.ambreTexte)),
            Expanded(
              child: Text(t.libelle,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Charte.gris, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ]),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(t.valeurTexte, key: Key('valeur_${t.cle}'), maxLines: 1, style: const TextStyle(color: Charte.encre, fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          if (t.reference != null) ...[
            Variation(t.variation, key: Key('variation_${t.cle}'), compacte: true),
            Text('${t.libelleReference.isEmpty ? 'Réf.' : t.libelleReference} : ${t.referenceTexte}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Charte.gris, fontSize: 12)),
          ],
          if (t.sousTitre.isNotEmpty)
            Text(t.sousTitre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Charte.gris, fontSize: 12)),
        ]),
      );
}

class _ASuivre extends StatelessWidget {
  final DonneesPilotage d;
  const _ASuivre(this.d);

  @override
  Widget build(BuildContext context) => Column(key: const Key('pilotage_a_suivre'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (d.alertes.isNotEmpty) ...[
          const TitreSection('Points d\'attention'),
          for (final a in d.alertes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: a.ok
                  ? CarteBande(
                      bande: Charte.vert,
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline, color: Charte.vertTexte),
                        const SizedBox(width: 8),
                        Expanded(child: Text(a.texte, style: const TextStyle(color: Charte.encre))),
                      ]),
                    )
                  : Encadre(
                      titre: a.critique ? 'Critique' : 'À surveiller',
                      texte: a.texte,
                      icone: a.critique ? Icons.error_outline : Icons.warning_amber_rounded,
                      avertissement: !a.critique,
                    ),
            ),
        ],
        if (d.ruptures.isNotEmpty) ...[
          const TitreSection('Vendus récemment, en rupture'),
          for (final p in d.ruptures)
            CarteLigne(titre: p.libelle, lignes: [if (p.cip.isNotEmpty) 'CIP ${p.cip}'], libelleValeur: 'Vendus (90 j)', valeur: grouperMilliers(p.vendus)),
        ],
        if (d.margeNegative.isNotEmpty) ...[
          const TitreSection('Vendus sous le prix d\'achat'),
          for (final p in d.margeNegative)
            CarteLigne(
              titre: p.libelle,
              bande: Charte.rouge,
              lignes: [
                if (p.cip.isNotEmpty) 'CIP ${p.cip}',
                'Prix d\'achat ${formaterMontant(p.paf)} · vendu ${formaterMontant(p.prix)}',
              ],
              libelleValeur: 'Vendus',
              valeur: grouperMilliers(p.vendus),
            ),
        ],
      ]);
}
