// lib/nouvelle_interface/modules/tableau_ratios_nouveau.dart
// Tableau : Ratios de la nouvelle interface. Mêmes données et mêmes calculs que l'écran d'origine (TableauBord,
// lib/donnees/tableau_bord_donnees.dart) : GET /ws/ca-achats-ventes?dtStart=&dtEnd= (lignes dans l'ordre du
// serveur), ratio du jour = ventes / achats, norme 1,51, achat normé = vente / 1,51, vente normée = achat × 1,51.
// Mise en page refaite : période commune chargée dès l'ouverture (« Aujourd'hui », dates par défaut d'origine),
// chiffres clés (achats, ventes, ratio de la période, jours au niveau de la norme), ratio jour par jour avec une
// étiquette écrite « ≥ norme » / « < norme » (pas seulement une couleur), calcul selon la norme, et les Ratios
// mensuels de l'année (même requête que l'origine : 1er janvier → aujourd'hui) avec un graphique en barres et la
// ligne de la norme.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../donnees/tableau_bord_donnees.dart';
import '../../models/tableau_bord_achats_ventes_model.dart';
import '../../utils/saisie.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot3.dart';
import 'periode.dart';

class TableauRatiosNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const TableauRatiosNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<TableauRatiosNouveau> createState() => _TableauRatiosNouveauState();
}

class _TableauRatiosNouveauState extends State<TableauRatiosNouveau> with ChargementSuivi<TableauRatiosNouveau, List<TableauBordAchatsVentes>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() async =>
      await TableauBord.charger(context, _periode.debut, _periode.fin, onSessionInvalid: sessionInvalide(context)) ?? const <TableauBordAchatsVentes>[]);

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  void _mensuels() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RatiosMensuelsNouveau(maintenant: widget.maintenant)));

  static String _date(TableauBordAchatsVentes l) => l.dateMvt == null ? 'N/A' : DateFormat('dd/MM/yyyy').format(l.dateMvt!);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tableau: Ratios Achats/Ventes'), actions: [
          IconButton(
              key: const Key('ratios_mensuels_barre'), tooltip: 'Ratios mensuels de l\'année', icon: const Icon(Icons.calendar_month_outlined), onPressed: _mensuels),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('ratios_mensuels'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _mensuels,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text('Ratios mensuels ${widget.maintenant().year}'),
            ),
            const SizedBox(height: 8),
            ..._corps(),
            const TitreSection('Calcul selon la norme'),
            const CalculNorme(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des ratios…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <TableauBordAchatsVentes>[];
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucune donnée pour cette période', texte: 'Choisissez une autre période.', icone: Icons.compare_arrows_outlined)];
    }
    final achats = TableauBord.totalAchats(l), ventes = TableauBord.totalVentes(l);
    final ratio = TableauBord.ratio(achats, ventes);
    final conformes = l.where((e) => TableauBord.position(e.ratio) == PositionNorme.conforme).length;
    return [
      GrilleKpi([
        ChiffreCle(
          libelle: 'Ratio de la période',
          valeur: formaterRatio(ratio),
          id: 'ratio',
          enAvant: true,
          detail: 'Norme ${formaterRatio(TableauBord.norme)} · ${libelleNorme(TableauBord.position(ratio)).$1}',
        ),
        ChiffreCle(libelle: 'Achats', valeur: formaterMontant(achats), id: 'achats'),
        ChiffreCle(libelle: 'Ventes', valeur: formaterMontant(ventes), id: 'ventes'),
        ChiffreCle(libelle: 'Jours ≥ norme', valeur: '$conformes / ${l.length}', id: 'jours_norme'),
      ]),
      const TitreSection('Ratio jour par jour'),
      ListeOuTableau(
        nombre: l.length,
        colonnes: const [
          Colonne('Date', flex: 2),
          Colonne('Achats', flex: 3, droite: true),
          Colonne('Ventes', flex: 3, droite: true),
          Colonne('Ratio', flex: 2, droite: true),
          Colonne('Norme', flex: 2),
        ],
        cellules: (i) => [
          _date(l[i]),
          formaterMontant(l[i].montantAchat),
          formaterMontant(l[i].montantVente),
          formaterRatio(l[i].ratio),
          libelleNorme(TableauBord.position(l[i].ratio)).$1,
        ],
        total: ['Période', formaterMontant(achats), formaterMontant(ventes), formaterRatio(ratio), libelleNorme(TableauBord.position(ratio)).$1],
        carte: (i) => CarteLigne(
          titre: _date(l[i]),
          lignes: ['Achats ${formaterMontant(l[i].montantAchat)}', 'Ventes ${formaterMontant(l[i].montantVente)}'],
          etiquette: EtiquetteNorme(l[i].ratio),
          libelleValeur: 'Ratio',
          valeur: formaterRatio(l[i].ratio),
        ),
      ),
    ];
  }
}

/// Calcul selon la norme (1,51) : saisir une vente donne l'achat normé, saisir un achat donne la vente normée ; un
/// seul champ à la fois (le second est vidé quand on touche le premier), comme l'écran d'origine.
class CalculNorme extends StatefulWidget {
  const CalculNorme({super.key});

  @override
  State<CalculNorme> createState() => _CalculNormeState();
}

class _CalculNormeState extends State<CalculNorme> {
  final _vente = TextEditingController();
  final _achat = TextEditingController();
  final _focusVente = FocusNode();
  final _focusAchat = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusVente.addListener(() {
      if (_focusVente.hasFocus) setState(_achat.clear);
    });
    _focusAchat.addListener(() {
      if (_focusAchat.hasFocus) setState(_vente.clear);
    });
  }

  @override
  void dispose() {
    _vente.dispose();
    _achat.dispose();
    _focusVente.dispose();
    _focusAchat.dispose();
    super.dispose();
  }

  Widget _champ(String cle, String libelle, IconData icone, TextEditingController c, FocusNode f) => TextField(
        key: Key(cle),
        controller: c,
        focusNode: f,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: Saisie.montantFormatters,
        decoration: InputDecoration(labelText: libelle, prefixIcon: Icon(icone)),
        onChanged: (_) => setState(() {}),
      );

  Widget _resultat(String cle, String libelle, double? v) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Row(children: [
          Expanded(child: Text(libelle, style: const TextStyle(color: Charte.grisTexte, fontSize: 14, fontWeight: FontWeight.w600))),
          Text(v == null ? '—' : formaterMontant(v), key: Key(cle), style: const TextStyle(color: Charte.navy, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      );

  @override
  Widget build(BuildContext context) => CarteSection(
        titre: 'Norme ${formaterRatio(TableauBord.norme)} (ventes / achats)',
        icone: Icons.calculate_outlined,
        enfants: [
          _champ('norme_vente', 'Si vente (FCFA)', Icons.trending_up, _vente, _focusVente),
          _resultat('norme_achat_resultat', 'Achat normé', TableauBord.achatNorme(Saisie.montant(_vente.text))),
          const SizedBox(height: 14),
          _champ('norme_achat', 'Si achat (FCFA)', Icons.trending_down, _achat, _focusAchat),
          _resultat('norme_vente_resultat', 'Vente normée', TableauBord.venteNormee(Saisie.montant(_achat.text))),
          const SizedBox(height: 8),
          const Text('Saisissez une valeur dans l\'un des champs pour calculer l\'autre.', style: TextStyle(color: Charte.gris, fontSize: 13)),
        ],
      );
}

/// Ratios mensuels de l'année en cours (même requête que l'origine : 1er janvier → aujourd'hui), cumul par mois.
class RatiosMensuelsNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const RatiosMensuelsNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<RatiosMensuelsNouveau> createState() => _RatiosMensuelsNouveauState();
}

class _RatiosMensuelsNouveauState extends State<RatiosMensuelsNouveau> with ChargementSuivi<RatiosMensuelsNouveau, List<MonthlyRatioData>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() async {
        final (debut, fin) = TableauBord.anneeEnCours(widget.maintenant());
        final l = await TableauBord.charger(context, debut, fin, onSessionInvalid: sessionInvalide(context));
        return TableauBord.mensuels(l ?? const []);
      });

  static String _mois(MonthlyRatioData m) {
    final n = m.monthName;
    return n.isEmpty ? n : '${n[0].toUpperCase()}${n.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final annee = widget.maintenant().year;
    return Scaffold(
      appBar: AppBar(title: Text('Ratios Mensuels $annee')),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(key: const Key('defilement_detail'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Row(children: [
            const Icon(Icons.event_outlined, size: 16, color: Charte.gris),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Du 01/01/$annee à aujourd\'hui', style: const TextStyle(color: Charte.gris, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          ..._corps(),
        ]),
      ),
    );
  }

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Calcul des ratios mensuels…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <MonthlyRatioData>[];
    if (l.isEmpty) {
      return const [EtatVide(titre: 'Aucune donnée pour l\'année en cours', icone: Icons.calendar_month_outlined)];
    }
    final achats = l.fold(0.0, (s, m) => s + m.totalAchats), ventes = l.fold(0.0, (s, m) => s + m.totalVentes);
    final ratio = TableauBord.ratio(achats, ventes);
    final conformes = l.where((m) => TableauBord.position(m.ratio) == PositionNorme.conforme).length;
    return [
      GrilleKpi([
        ChiffreCle(
          libelle: 'Ratio de l\'année',
          valeur: formaterRatio(ratio),
          id: 'ratio_annee',
          enAvant: true,
          detail: 'Norme ${formaterRatio(TableauBord.norme)} · ${libelleNorme(TableauBord.position(ratio)).$1}',
        ),
        ChiffreCle(libelle: 'Achats', valeur: formaterMontant(achats), id: 'achats_annee'),
        ChiffreCle(libelle: 'Ventes', valeur: formaterMontant(ventes), id: 'ventes_annee'),
        ChiffreCle(libelle: 'Mois ≥ norme', valeur: '$conformes / ${l.length}', id: 'mois_norme'),
      ]),
      const TitreSection('Ratio par mois'),
      CadreGraphique(hauteur: 240, child: _Barres(mois: l)),
      const SizedBox(height: 8),
      const LegendeGraphique([
        SerieGraphique('≥ norme', Charte.navy),
        SerieGraphique('< norme', Charte.ambreTexte, carre: true),
        SerieGraphique('Norme 1,51', Charte.rougeTexte, pointilles: true, marqueur: false),
      ]),
      const TitreSection('Détail par mois'),
      ListeOuTableau(
        nombre: l.length,
        colonnes: const [
          Colonne('Mois', flex: 3),
          Colonne('Total achats', flex: 3, droite: true),
          Colonne('Total ventes', flex: 3, droite: true),
          Colonne('Ratio', flex: 2, droite: true),
          Colonne('Norme', flex: 2),
        ],
        cellules: (i) => [
          _mois(l[i]),
          formaterMontant(l[i].totalAchats),
          formaterMontant(l[i].totalVentes),
          formaterRatio(l[i].ratio),
          libelleNorme(TableauBord.position(l[i].ratio)).$1,
        ],
        total: ['Année', formaterMontant(achats), formaterMontant(ventes), formaterRatio(ratio), libelleNorme(TableauBord.position(ratio)).$1],
        carte: (i) => CarteLigne(
          titre: _mois(l[i]),
          lignes: ['Total achats ${formaterMontant(l[i].totalAchats)}', 'Total ventes ${formaterMontant(l[i].totalVentes)}'],
          etiquette: EtiquetteNorme(l[i].ratio),
          libelleValeur: 'Ratio',
          valeur: formaterRatio(l[i].ratio),
        ),
      ),
    ];
  }
}

/// Barres du ratio de chaque mois, ligne pointillée de la norme ; mois sous la norme en barre ambre foncé à bout
/// carré (et « < norme » écrit dans la liste), valeur au toucher.
class _Barres extends StatelessWidget {
  final List<MonthlyRatioData> mois;
  const _Barres({required this.mois});

  @override
  Widget build(BuildContext context) {
    final max = [TableauBord.norme, for (final m in mois) m.ratio].reduce((a, b) => a > b ? a : b);
    const style = TextStyle(color: Charte.gris, fontWeight: FontWeight.bold, fontSize: 10);
    return Semantics(
      label: 'Barres du ratio ventes sur achats de ${mois.length} mois, norme ${formaterRatio(TableauBord.norme)}',
      child: BarChart(BarChartData(
        maxY: max * 1.2,
        minY: 0,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: Charte.ligne, strokeWidth: 0.8)),
        borderData: FlBorderData(show: true, border: Border.all(color: Charte.bordure)),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(y: TableauBord.norme, color: Charte.rougeTexte, strokeWidth: 2, dashArray: const [7, 4]),
        ]),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 34, getTitlesWidget: (v, meta) => Text(graduationVisible(v, meta) ? v.toStringAsFixed(1).replaceAll('.', ',') : '', style: style)),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                final t = i >= 0 && i < mois.length ? DateFormat.MMM('fr_FR').format(DateTime(2000, mois[i].month)) : '';
                return SideTitleWidget(axisSide: meta.axisSide, space: 4, child: Text(t, style: style));
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Charte.navy,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (g, _, rod, __) => BarTooltipItem(
              '${_RatiosMensuelsNouveauState._mois(mois[g.x])}\n',
              const TextStyle(color: Charte.enteteGris, fontSize: 11),
              children: [
                TextSpan(
                    text: 'Ratio ${formaterRatio(rod.toY)} · ${libelleNorme(TableauBord.position(rod.toY)).$1}',
                    style: const TextStyle(color: Charte.blanc, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < mois.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: mois[i].ratio,
                width: 14,
                color: TableauBord.position(mois[i].ratio) == PositionNorme.conforme ? Charte.navy : Charte.ambreTexte,
                borderRadius: TableauBord.position(mois[i].ratio) == PositionNorme.conforme
                    ? const BorderRadius.vertical(top: Radius.circular(5))
                    : BorderRadius.zero,
              ),
            ]),
        ],
      )),
    );
  }
}
