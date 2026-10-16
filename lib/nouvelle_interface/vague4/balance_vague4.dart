// lib/nouvelle_interface/vague4/balance_vague4.dart
// 3.11.0 — menu « Balance vente / caisse » (web « balancesalecahs »), administrateur et pharmacien, LECTURE SEULE,
// quatre onglets :
//  - Balance : période commune (Aujourd'hui à l'ouverture), GET /balance/balancesalecash : chiffres clés, balance
//    COMPTANT / CRÉDIT, résumé (brut, remise, net, achat, marge, modes), modes de paiement, caisse, TVA ; menu Exporter
//    → édition PDF du web (GET /balance/balancesalecash/pdf), Partager / Ouvrir ;
//  - Analyse comparative et Évolution par mode de paiement : UN appel commun GET /balance/balancesalecash/analyse
//    (3 semaines à l'ouverture comme le web, 3 mois, 6 mois, 3 ans, période libre contrôlée), lancé à la première
//    ouverture d'un de ces deux onglets ; une carte par période (taux d'évolution par rapport à la précédente, flèche
//    et texte), total général ;
//  - Surveiller et alertes : le bloc « À surveiller » de l'accueil (péremption, ruptures, avoirs, saisies en
//    périmés) puis toutes les alertes du tableau de bord (GET /tableau-bord/alertes, même appel unique, même ⟳).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../presences/export_fichier.dart';
import '../../providers/home_settings_provider.dart';
import '../../providers/ip_config_provider.dart';
import '../accueil_nouveau.dart' show BlocAlertesSurveiller;
import '../charte.dart';
import '../composants.dart';
import '../menus.dart';
import '../modules/commun.dart';
import '../modules/commun_lot2.dart' show messageResultat;
import '../modules/commun_lot3.dart' show CadreGraphique;
import '../modules/periode.dart';
import '../vague1/alertes_vague1.dart';
import '../vague2/commun_vague2.dart' show ChargementAnnulable, Variation;
import '../vague2/donnees_vague2.dart' show grouperMilliers, pourcentTexte;
import 'donnees_vague4.dart';
import 'graphiques_vague4.dart';

enum OngletBalance {
  balance('Balance'),
  analyse('Analyse comparative'),
  modes('Évolution par mode'),
  surveiller('Surveiller et alertes');

  final String libelle;
  const OngletBalance(this.libelle);
}

class BalanceCaisseScreen extends StatefulWidget {
  final DateTime Function() maintenant;
  final OngletBalance initial;
  const BalanceCaisseScreen({super.key, this.maintenant = DateTime.now, this.initial = OngletBalance.balance});

  @override
  State<BalanceCaisseScreen> createState() => _BalanceCaisseScreenState();
}

class _BalanceCaisseScreenState extends State<BalanceCaisseScreen> with SingleTickerProviderStateMixin {
  late final _onglets = TabController(length: OngletBalance.values.length, vsync: this, initialIndex: widget.initial.index);

  // Onglet Balance.
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  BalanceCaisse? _balance;
  bool _balanceEnCours = false;
  Object? _balanceErreur;
  int _genBalance = 0;
  bool _export = false;

  /// Camembert de la Balance : par type de vente (sinon par mode de paiement), 3.11.1.
  bool _repartitionParType = false;

  // Onglets Analyse et Modes (un seul appel commun).
  PeriodeAnalyse _type = PeriodeAnalyse.troisSemaines;
  DateTime? _debut;
  DateTime? _fin;
  AnalyseBalance? _analyse;
  bool _analyseEnCours = false;
  Object? _analyseErreur;
  int _genAnalyse = 0;
  bool _analyseDemandee = false;

  OngletBalance get _onglet => OngletBalance.values[_onglets.index];

  @override
  void initState() {
    super.initState();
    _onglets.addListener(() {
      if (!mounted || _onglets.indexIsChanging) return;
      setState(() {});
      _chargerOnglet();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _chargerOnglet());
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  /// Charge l'onglet affiché la première fois qu'il est ouvert (rien pour « Surveiller » : comptage à la demande).
  void _chargerOnglet() {
    if (!mounted) return;
    switch (_onglet) {
      case OngletBalance.balance:
        if (_balance == null && !_balanceEnCours && _balanceErreur == null) _chargerBalance();
      case OngletBalance.analyse || OngletBalance.modes:
        if (!_analyseDemandee) _chargerAnalyse();
      case OngletBalance.surveiller:
        break;
    }
  }

  Future<void> _chargerBalance() async {
    final g = ++_genBalance;
    setState(() {
      _balanceEnCours = true;
      _balanceErreur = null;
    });
    try {
      final b = await ApiBalance.balance(context, _periode);
      if (!mounted || g != _genBalance) return;
      setState(() {
        _balance = b;
        _balanceEnCours = false;
      });
    } catch (e) {
      if (!mounted || g != _genBalance) return;
      setState(() {
        _balanceErreur = e;
        _balanceEnCours = false;
      });
    }
  }

  Future<void> _chargerAnalyse() async {
    _analyseDemandee = true;
    final g = ++_genAnalyse;
    setState(() {
      _analyseEnCours = true;
      _analyseErreur = null;
      _analyse = null;
    });
    try {
      final a = await ApiBalance.analyse(context, _type, debut: _debut, fin: _fin, maintenant: widget.maintenant());
      if (!mounted || g != _genAnalyse) return;
      setState(() {
        _analyse = a;
        _analyseEnCours = false;
      });
    } catch (e) {
      if (!mounted || g != _genAnalyse) return;
      setState(() {
        _analyseErreur = e;
        _analyseEnCours = false;
      });
    }
  }

  void _abandonnerAnalyse() => setState(() {
        _genAnalyse++;
        _analyseEnCours = false;
      });

  Future<void> _choisirType(PeriodeAnalyse t) async {
    if (t != PeriodeAnalyse.libre) {
      setState(() {
        _type = t;
        _debut = null;
        _fin = null;
      });
      _chargerAnalyse();
      return;
    }
    final now = widget.maintenant();
    final aujourdhui = Periode.jour(now);
    final r = await showDateRangePicker(
      context: context,
      firstDate: ControlePeriode.borneMin,
      lastDate: aujourdhui,
      initialDateRange: DateTimeRange(start: _debut ?? DateTime(aujourdhui.year, aujourdhui.month, 1), end: _fin ?? aujourdhui),
      locale: const Locale('fr', 'FR'),
      helpText: 'Période libre',
      saveText: 'Valider',
    );
    if (r == null || !mounted) return;
    final erreur = ControlePeriode.erreur(r.start, r.end, now);
    if (erreur != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erreur)));
      return;
    }
    setState(() {
      _type = PeriodeAnalyse.libre;
      _debut = Periode.jour(r.start);
      _fin = Periode.jour(r.end);
    });
    _chargerAnalyse();
  }

  Future<void> _exporterPdf() async {
    if (_export) return;
    setState(() => _export = true);
    try {
      final f = await ApiBalance.pdf(context, _periode);
      if (!mounted) return;
      await ExportFichier.proposer(context, f, sujet: 'Balance vente / caisse ${_periode.resume}');
    } catch (e) {
      if (mounted) messageResultat(context, 'Édition impossible : ${DiagnosticErreur.de(e).message}', echec: true);
    } finally {
      if (mounted) setState(() => _export = false);
    }
  }

  void _actualiser() => switch (_onglet) {
        OngletBalance.balance => _chargerBalance(),
        OngletBalance.analyse || OngletBalance.modes => _chargerAnalyse(),
        OngletBalance.surveiller => AlertesTableauBord.instance.actualiser(context),
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Balance vente / caisse'),
          actions: [
            if (_onglet == OngletBalance.balance)
              _export
                  ? const SizedBox(width: 48, height: 48, child: Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(
                      key: const Key('balance_pdf'),
                      tooltip: 'Édition PDF de la balance',
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      onPressed: _balance == null ? null : _exporterPdf,
                    ),
            IconButton(key: const Key('balance_actualiser'), tooltip: 'Actualiser', icon: const Icon(Icons.refresh), onPressed: _actualiser),
          ],
          // Onglets sur fond blanc (comme le Pilotage) : lisibles, l'onglet choisi souligné.
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Material(
              color: Charte.blanc,
              child: TabBar(
                key: const Key('balance_onglets'),
                controller: _onglets,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: Charte.navy,
                unselectedLabelColor: Charte.gris,
                indicatorColor: Charte.navy,
                tabs: [for (final o in OngletBalance.values) Tab(height: 48, key: Key('balance_onglet_${o.name}'), text: o.libelle)],
              ),
            ),
          ),
        ),
        body: TabBarView(controller: _onglets, children: [
          _ongletBalance(),
          _ongletAnalyse(modes: false),
          _ongletAnalyse(modes: true),
          const _OngletSurveiller(),
        ]),
      );

  // ------------------------------------------------------------------------------------------------- Balance

  Widget _ongletBalance() => RefreshIndicator(
        onRefresh: _chargerBalance,
        child: ListView(key: const Key('defilement_balance'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          SelecteurPeriode(
            periode: _periode,
            maintenant: widget.maintenant,
            onChanged: (p) {
              setState(() => _periode = p);
              _chargerBalance();
            },
          ),
          const SizedBox(height: 8),
          if (_balanceEnCours) const EtatChargement(texte: 'Calcul de la balance…'),
          if (_balanceErreur != null && !_balanceEnCours) EtatErreur(erreur: _balanceErreur!, reessayer: _chargerBalance),
          if (_balance != null && !_balanceEnCours && _balanceErreur == null) ..._corpsBalance(_balance!),
        ]),
      );

  List<Widget> _corpsBalance(BalanceCaisse b) {
    if (b.vide) {
      return const [EtatVide(titre: 'Aucune vente', texte: 'Aucune vente sur cette période.', icone: Icons.point_of_sale_outlined)];
    }
    final r = b.resume;
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Net TTC', valeur: formaterMontant(r.montantNet), id: 'balance_net', enAvant: true),
        ChiffreCle(libelle: 'Nombre de ventes', valeur: grouperMilliers(r.nbreVente), id: 'balance_ventes'),
        ChiffreCle(libelle: 'Panier moyen', valeur: formaterMontant(r.panierMoyen), id: 'balance_panier'),
        ChiffreCle(libelle: 'Marge', valeur: formaterMontant(r.marge), id: 'balance_marge'),
      ]),
      const SizedBox(height: 12),
      CarteSection(key: const Key('balance_comptant_credit'), titre: 'Balance vente / caisse', icone: Icons.balance_outlined, enfants: [
        for (final l in b.lignes)
          LigneDetail('${l.libelle} · ${grouperMilliers(l.valeurs.nbreVente)} vente${l.valeurs.nbreVente > 1 ? 's' : ''}', formaterMontant(l.valeurs.montantNet)),
        const Divider(height: 14),
        LigneDetail('TOTAL · ${grouperMilliers(r.nbreVente)} vente${r.nbreVente > 1 ? 's' : ''}', formaterMontant(r.montantNet), gras: true, couleur: Charte.navy),
      ]),
      CarteSection(key: const Key('balance_resume'), titre: 'Résumé', icone: Icons.functions, enfants: [
        LigneDetail('Brut TTC', formaterMontant(r.montantTTC)),
        LigneDetail('Remise', formaterMontant(r.montantRemise)),
        LigneDetail('Net TTC', formaterMontant(r.montantNet), gras: true),
        LigneDetail('Achat', formaterMontant(r.montantAchat)),
        LigneDetail('Marge', formaterMontant(r.marge), gras: true),
        const Divider(height: 14),
        LigneDetail('Espèces', formaterMontant(r.montantEsp)),
        LigneDetail('Carte bancaire', formaterMontant(r.montantCB)),
        LigneDetail('Chèque', formaterMontant(r.montantCheque)),
        LigneDetail('Virement', formaterMontant(r.montantVirement)),
        LigneDetail('Mobile money', formaterMontant(r.montantMobile)),
        LigneDetail('Tiers payant', formaterMontant(r.montantTp)),
        LigneDetail('Différé', formaterMontant(r.montantDiff)),
      ]),
      // 3.11.1 : camembert de la répartition (modes de paiement ou type de vente), légende avec montants et %.
      if (b.modes.isNotEmpty || b.lignes.isNotEmpty)
        CarteSection(key: const Key('balance_modes'), titre: 'Répartition du chiffre d\'affaires', icone: Icons.pie_chart_outline, enfants: [
          if (b.modes.isNotEmpty && b.lignes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: PucesChoix<bool>(
                choix: const [(false, 'Modes de paiement'), (true, 'Type de vente')],
                valeur: _repartitionParType || b.modes.isEmpty,
                cle: (v, _) => Key(v ? 'repartition_type' : 'repartition_modes'),
                onChanged: (v) => setState(() => _repartitionParType = v),
              ),
            ),
          if ((_repartitionParType || b.modes.isEmpty) && b.lignes.isNotEmpty)
            CamembertParts(
              key: const Key('repartition_type_vente'),
              titre: 'Répartition par type de vente',
              prefixeCle: 'repartition_type',
              parts: [for (final l in b.lignes) (libelle: l.libelle, montant: l.valeurs.montantNet)],
            )
          else
            CamembertParts(
              key: const Key('repartition_modes_paiement'),
              titre: 'Répartition par mode de paiement',
              prefixeCle: 'repartition_modes',
              parts: [for (final m in b.modes) (libelle: m.libelle, montant: m.montant)],
            ),
        ]),
      if (b.caisse.isNotEmpty)
        CarteSection(key: const Key('balance_caisse'), titre: 'Caisse', icone: Icons.point_of_sale_outlined, enfants: [
          for (final c in b.caisse) LigneDetail('${c.libelle} (${grouperMilliers(c.ventes)})', formaterMontant(c.montant)),
        ]),
      if (b.tva.isNotEmpty)
        CarteSection(key: const Key('balance_tva'), titre: 'Répartition par taux de TVA', icone: Icons.pie_chart_outline, enfants: [
          for (final t in b.tva)
            LigneDetail('TVA ${t.taux.toStringAsFixed(t.taux == t.taux.roundToDouble() ? 0 : 1).replaceAll('.', ',')} % (${pourcentTexte(t.part)})',
                formaterMontant(t.ttc)),
        ]),
    ];
  }

  // ------------------------------------------------------------------------------------- Analyse et modes

  Widget _ongletAnalyse({required bool modes}) {
    final a = _analyse;
    String date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return RefreshIndicator(
      onRefresh: _chargerAnalyse,
      child: ListView(key: Key(modes ? 'defilement_balance_modes' : 'defilement_balance_analyse'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        PucesChoix<PeriodeAnalyse>(
          choix: [for (final t in PeriodeAnalyse.values) (t, t.libelle)],
          valeur: _type,
          cle: (t, _) => Key('${modes ? 'modes' : 'analyse'}_periode_${t.code}'),
          onChanged: _choisirType,
        ),
        if (_type == PeriodeAnalyse.libre && _debut != null && _fin != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
            child: Text('Du ${date(_debut!)} au ${date(_fin!)}', style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 8),
        if (_analyseEnCours)
          ChargementAnnulable(
            texte: 'Calcul de l\'analyse…',
            indication: ApiBalance.longue(_type, _debut, _fin) ? 'Longue période, le calcul peut prendre un moment.' : null,
            annuler: _abandonnerAnalyse,
          ),
        if (_analyseErreur != null && !_analyseEnCours) EtatErreur(erreur: _analyseErreur!, reessayer: _chargerAnalyse),
        if (a != null && !_analyseEnCours && _analyseErreur == null) ...(modes ? _corpsModes(a) : _corpsAnalyse(a)),
      ]),
    );
  }

  List<Widget> _corpsAnalyse(AnalyseBalance a) {
    if (a.periodes.isEmpty) return const [EtatVide(titre: 'Aucune période', texte: 'Aucune donnée pour ce choix.', icone: Icons.search_off)];
    final t = a.total;
    return [
      if (!a.comparatif)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Une seule période : chiffres bruts, sans comparaison.', style: TextStyle(color: Charte.grisTexte, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      for (var i = 0; i < a.periodes.length; i++) _CartePeriode(key: Key('analyse_periode_$i'), p: a.periodes[i]),
      CarteSection(key: const Key('analyse_total'), titre: 'Total général', icone: Icons.functions, enfants: [
        LigneDetail('Ventes', grouperMilliers(t.nbreVente)),
        LigneDetail('Brut TTC', formaterMontant(t.montantTTC)),
        LigneDetail('Remise', formaterMontant(t.montantRemise)),
        LigneDetail('Net TTC', formaterMontant(t.montantNet), gras: true),
        LigneDetail('Achat', formaterMontant(t.montantAchat)),
        LigneDetail('Marge', formaterMontant(t.marge), gras: true),
        LigneDetail('Panier moyen', formaterMontant(t.panierMoyen)),
      ]),
    ];
  }

  List<Widget> _corpsModes(AnalyseBalance a) {
    if (a.periodes.isEmpty || a.modes.isEmpty) {
      return const [EtatVide(titre: 'Aucun mode de paiement', texte: 'Aucun encaissement pour ce choix.', icone: Icons.search_off)];
    }
    final totalModes = [for (final m in a.modes) (libelle: m.libelle, montant: a.totalModes[m.id] ?? 0)];
    return [
      // 3.11.1 : barres de l'évolution, une barre par période empilée par mode ; légende : total de chaque mode et %.
      CarteSection(key: const Key('modes_graphique'), titre: 'Évolution par mode de paiement', icone: Icons.bar_chart, enfants: [
        CadreGraphique(
          hauteur: 220,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
            child: BarresEmpilees(
              titre: 'Encaissements par période et par mode',
              periodes: [for (final p in a.periodes) p.libelleCourt],
              series: [for (final m in a.modes) m.libelle],
              valeurs: [
                for (final p in a.periodes) [for (final m in a.modes) p.parModes[m.id] ?? 0],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        LegendeParts(parts: totalModes, pourcents: pourcentages(totalModes), prefixeCle: 'modes'),
      ]),
      for (var i = 0; i < a.periodes.length; i++)
        Padding(
          key: Key('modes_periode_$i'),
          padding: const EdgeInsets.only(bottom: 8),
          child: CarteSection(
            titre: '${a.periodes[i].libelle}${a.periodes[i].enCours ? ' (en cours)' : ''}',
            icone: Icons.calendar_month_outlined,
            enfants: [
              for (final m in a.modes)
                _LigneMode(m.libelle, a.periodes[i].parModes[m.id] ?? 0, a.periodes[i].evolutionsModes[m.id]),
            ],
          ),
        ),
      CarteSection(key: const Key('modes_total'), titre: 'Total', icone: Icons.functions, enfants: [
        for (final m in a.modes) LigneDetail(m.libelle, formaterMontant(a.totalModes[m.id] ?? 0)),
      ]),
    ];
  }
}

/// Une période de l'analyse comparative : net TTC en grand, évolution par rapport à la période précédente, puis
/// ventes, panier moyen, achat et marge avec leur propre évolution.
class _CartePeriode extends StatelessWidget {
  final PeriodeBalance p;
  const _CartePeriode({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final v = p.valeurs;
    Widget ligne(String libelle, String valeur, String cle) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(libelle, style: const TextStyle(color: Charte.gris, fontSize: 13.5))),
            Text(valeur, style: const TextStyle(color: Charte.encre, fontSize: 13.5, fontWeight: FontWeight.w700)),
            if (p.evolutions[cle] != null) ...[const SizedBox(width: 8), Variation(p.evolutions[cle], compacte: true)],
          ]),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CarteBande(
        bande: p.enCours ? Charte.gris : Charte.navy2,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text('${p.libelle}${p.enCours ? ' (en cours)' : ''}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Charte.encre)),
            ),
            Text(formaterMontant(v.montantNet), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Charte.navy)),
          ]),
          Variation(p.evolutions['montantNet'], suffixe: 'net TTC vs période précédente'),
          const Divider(height: 14),
          ligne('Ventes', grouperMilliers(v.nbreVente), 'nbreVente'),
          ligne('Panier moyen', formaterMontant(v.panierMoyen), 'panierMoyen'),
          ligne('Achat', formaterMontant(v.montantAchat), 'montantAchat'),
          ligne('Marge', formaterMontant(v.marge), 'marge'),
        ]),
      ),
    );
  }
}

class _LigneMode extends StatelessWidget {
  final String libelle;
  final int montant;
  final double? evolution;
  const _LigneMode(this.libelle, this.montant, this.evolution);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(libelle, style: const TextStyle(color: Charte.encre, fontSize: 14, fontWeight: FontWeight.w600))),
          Text(formaterMontant(montant), style: const TextStyle(color: Charte.encre, fontSize: 14, fontWeight: FontWeight.w700)),
          if (evolution != null) ...[const SizedBox(width: 8), Variation(evolution, compacte: true)],
        ]),
      );
}

/// Onglet « Surveiller et alertes » : le bloc « À surveiller » de l'accueil, puis toutes les alertes.
class _OngletSurveiller extends StatelessWidget {
  const _OngletSurveiller();

  @override
  Widget build(BuildContext context) {
    final alertes = AlertesTableauBord.instance;
    context.watch<IpConfigProvider>();
    alertes.preparer(AlertesTableauBord.cleDe(context));
    final menus = menusVisibles(context.watch<HomeSettingsProvider>());
    final suggestionsVisibles = menus.any((m) => m.titre == 'Suggestions');
    return ListenableBuilder(
      listenable: alertes,
      builder: (context, _) => ListView(key: const Key('defilement_balance_surveiller'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        const TitreSection('À surveiller'),
        const BlocAlertesSurveiller(peremption: true, ruptures: true, toutesAlertes: true, carteToutesAlertes: false),
        const TitreSection('Toutes les alertes'),
        CorpsAlertes(etat: alertes.etat, suggestionsVisibles: suggestionsVisibles),
      ]),
    );
  }
}
