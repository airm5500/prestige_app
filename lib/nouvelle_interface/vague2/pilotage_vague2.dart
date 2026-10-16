// lib/nouvelle_interface/vague2/pilotage_vague2.dart
// Onglet « Pilotage » de la barre du bas (administrateur et pharmacien seulement ; droit P_SM_PILOTAGE vérifié par
// le serveur : un refus s'affiche « Droit manquant »). LECTURE SEULE :
//  - onglets internes « Synthèse » et « À suivre » (GET /pilotage/onglet/synthese|asuivre?axe=&dtStart=&dtEnd=) ;
//  - axe de comparaison (GET /pilotage/axes : MOIS, VS_M1, VS_N1, YTD, G12, PERSO) ; PERSO : dates contrôlées
//    (début ≤ fin, rien dans le futur, 3 ans au plus) ;
//  - tuiles : valeur, unité, référence et variation : la flèche suit le sens réel (hausse / baisse) ; couleur selon
//    l'indicateur (sensIndicateurs : couleurs inversées quand une hausse est mauvaise, gris pour les indicateurs
//    neutres). 3.11.0 : les mots « favorable / défavorable » sont retirés (demande du pharmacien).
// JAMAIS appelés : /pilotage/recalculer, POST /pilotage/charges, et depuis la 3.11.0 /pilotage/controler (le bouton
// « Contrôler les chiffres » est retiré : le pharmacien contrôle les chiffres sur Prestige web).
// 3.11.0 (demandes du pharmacien) :
//  - toucher la tuile Marge ou Nombre de ventes ouvre sa courbe des 7 derniers jours (un appel par jour, axe PERSO) ;
//  - onglet À suivre : CA par emplacement et par famille de la période (champs « emplacements » / « familles » de la
//    réponse, jusque-là non affichés) ; toucher une ligne ouvre ses produits (GET /ca-zone-geo/detail, période du
//    Pilotage ; identifiant retrouvé par le libellé dans /common/rayons ou /common/famillearticles).
import 'package:flutter/material.dart';

import '../charte.dart';
import '../composants.dart';
import '../modules/commun.dart';
import '../modules/commun_lot3.dart' show CadreGraphique, GraphiqueCourbes, SerieGraphique;
import '../modules/periode.dart';
import 'ca_zone_vague2.dart' show CaLigneDetailScreen;
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

  /// Courbe des 7 derniers jours de la tuile [t] (marge, nombre de ventes), dans une feuille du bas.
  void _courbe(TuilePilotage t) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => CourbeSeptJours(tuile: t, maintenant: widget.maintenant),
      );

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
              GrilleChiffres([
                for (final t in d.tuiles)
                  TuileIndicateur(t, onTap: ApiPilotage.clesCourbeSeptJours.contains(t.cle) ? () => _courbe(t) : null),
              ]),
            if (_onglet == OngletPilotage.aSuivre) _ASuivre(d, maintenant: widget.maintenant),
          ],
        ]),
      ),
    ]);
  }
}

/// Tuile d'indicateur : libellé, valeur, variation (flèche + texte + couleur), référence, précision.
class TuileIndicateur extends StatelessWidget {
  final TuilePilotage t;

  /// 3.11.0 : tuile touchable (Marge, Nombre de ventes → courbe des 7 derniers jours), signalée par une icône.
  final VoidCallback? onTap;
  const TuileIndicateur(this.t, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tuile = _contenu();
    if (onTap == null) return tuile;
    return Semantics(
      button: true,
      hint: 'Courbe des 7 derniers jours',
      child: Material(
        color: Colors.transparent,
        child: InkWell(key: Key('tuile_courbe_${t.cle}'), borderRadius: BorderRadius.circular(14), onTap: onTap, child: tuile),
      ),
    );
  }

  Widget _contenu() => Container(
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
            if (onTap != null) const Icon(Icons.show_chart, size: 18, color: Charte.navy, semanticLabel: 'Courbe'),
          ]),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(t.valeurTexte, key: Key('valeur_${t.cle}'), maxLines: 1, style: const TextStyle(color: Charte.encre, fontSize: 19, fontWeight: FontWeight.w800)),
          ),
          if (t.reference != null) ...[
            Variation(t.variation, key: Key('variation_${t.cle}'), sens: t.sens, compacte: true),
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
  final DateTime Function() maintenant;
  const _ASuivre(this.d, {required this.maintenant});

  /// Produits d'un emplacement (ou d'une famille) sur la période du Pilotage : même écran que le CA par emplacement.
  Future<void> _produits(BuildContext context, RepartitionPilotage r, {required bool famille}) async {
    final bornes = bornesPeriodePilotage(d.periode);
    if (bornes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Période du Pilotage illisible : produits indisponibles.')));
      return;
    }
    final route = famille ? ApiVague2.routeFamilles : ApiVague2.routeRayons;
    String? id;
    if (r.sansLibelle) {
      id = ''; // ligne « (non renseigné) » : produits sans emplacement (ou sans famille)
    } else {
      try {
        final options = await ApiVague2.options(context, route, famille ? 'la liste des familles' : 'la liste des emplacements');
        id = options.where((o) => o.libelle.trim().toUpperCase() == r.libelle.trim().toUpperCase()).firstOrNull?.id;
      } catch (e) {
        if (context.mounted) {
          final diag = DiagnosticErreur.de(e);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${diag.titre} : ${diag.message}')));
        }
        return;
      }
    }
    if (!context.mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${famille ? 'Famille' : 'Emplacement'} « ${r.libelle} » introuvable dans la liste du serveur.')));
      return;
    }
    final (debut, fin) = bornes;
    final filtres = FiltresCa(
        type: TypePeriodeCa.libre, debut: debut, fin: fin, regroupement: famille ? RegroupementCa.famille : RegroupementCa.zone);
    final ligne = LigneCa(
        zoneId: famille ? '' : id, zone: famille ? '' : r.libelle, familleId: famille ? id : '', famille: famille ? r.libelle : '',
        libelle: r.libelle, total: r.ca, marge: r.marge);
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CaLigneDetailScreen(filtres: filtres, ligne: ligne, tranches: const [], maintenant: maintenant)));
  }

  Widget _repartition(BuildContext context, String titre, String prefixe, List<RepartitionPilotage> l, {required bool famille}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TitreSection(titre),
        for (var i = 0; i < l.length; i++)
          CarteLigne(
            key: Key('${prefixe}_$i'),
            titre: l[i].libelle.isEmpty ? RepartitionPilotage.nonRenseigne : l[i].libelle,
            lignes: ['Marge ${formaterMontant(l[i].marge)} · ${grouperMilliers(l[i].ventes)} vente${l[i].ventes > 1 ? 's' : ''}', 'Part du CA ${pourcentTexte(l[i].part)}'],
            libelleValeur: 'CA',
            valeur: formaterMontant(l[i].ca),
            onTap: () => _produits(context, l[i], famille: famille),
          ),
      ]);

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
        if (d.emplacements.isNotEmpty) _repartition(context, 'CA par emplacement', 'suivi_emplacement', d.emplacements, famille: false),
        if (d.familles.isNotEmpty) _repartition(context, 'CA par famille', 'suivi_famille', d.familles, famille: true),
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

/// Courbe des 7 derniers jours d'une tuile de la Synthèse (marge, nombre de ventes) : chargée à l'ouverture de la
/// feuille ; valeurs jour par jour sous la courbe ; échec affiché avec « Réessayer ».
class CourbeSeptJours extends StatefulWidget {
  final TuilePilotage tuile;
  final DateTime Function() maintenant;
  const CourbeSeptJours({super.key, required this.tuile, this.maintenant = DateTime.now});

  @override
  State<CourbeSeptJours> createState() => _CourbeSeptJoursState();
}

class _CourbeSeptJoursState extends State<CourbeSeptJours> {
  List<(DateTime, double?)>? _points;
  Object? _erreur;
  bool _enCours = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final p = await ApiPilotage.septJours(context, widget.tuile.cle, maintenant: widget.maintenant());
      if (mounted) {
        setState(() {
          _points = p;
          _enCours = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erreur = e;
          _enCours = false;
        });
      }
    }
  }

  String _valeur(double? v) => v == null ? '—' : valeurAvecUnite(v, widget.tuile.unite);

  @override
  Widget build(BuildContext context) {
    final t = widget.tuile, p = _points;
    String jour(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return SingleChildScrollView(
      key: const Key('courbe_sept_jours'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(t.libelle, style: const TextStyle(color: Charte.navy, fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('7 derniers jours, aujourd\'hui compris', style: TextStyle(color: Charte.gris, fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (_enCours) const EtatChargement(texte: 'Chargement des 7 derniers jours…'),
        if (_erreur != null && !_enCours) EtatErreur(erreur: _erreur!, reessayer: _charger),
        if (p != null && !_enCours && _erreur == null) ...[
          CadreGraphique(
            hauteur: 220,
            child: GraphiqueCourbes(
              libelle: 'Courbe ${t.libelle.toLowerCase()} des 7 derniers jours',
              jours: [for (final x in p) x.$1],
              series: [(SerieGraphique(t.libelle, Charte.navy), [for (final x in p) x.$2 ?? 0])],
              valeurTexte: (v) => valeurAvecUnite(v, t.unite),
            ),
          ),
          const SizedBox(height: 8),
          for (final x in p) LigneDetail(jour(x.$1), _valeur(x.$2)),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('courbe_fermer'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ]),
    );
  }
}
