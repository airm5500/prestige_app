// lib/nouvelle_interface/modules/tableau_analyses_nouveau.dart
// Tableau : Analyses de la nouvelle interface. Mêmes données que l'écran d'origine et ses trois graphiques
// (TableauBord, lib/donnees/tableau_bord_donnees.dart) : GET /ws/ca-achats-ventes?dtStart=&dtEnd=, une ligne par jour
// triée par date. Mise en page refaite : période commune chargée dès l'ouverture (« Ce mois » depuis la 3.8.0, choix
// du pharmacien : une courbe d'un seul jour n'a pas de sens ; « Aujourd'hui » avant), chiffres clés (achats, ventes, écart, ratio ventes / achats et norme 1,51), UN graphique
// avec le choix Comparée / Achats / Ventes (les trois écrans d'origine), lisible sur téléphone (légende, axes
// abrégés, valeurs au toucher ; achats en pointillés à marqueurs carrés, ventes en trait plein à marqueurs ronds),
// jour par jour (cartes sur téléphone, tableau sur tablette), détail d'un jour en feuille.
// 3.11.0 (demandes du pharmacien) : jour par jour, montant des achats en gras et taux d'évolution des ventes par
// rapport à la veille (jour précédent de la liste ; sa date est écrite si ce n'est pas la veille), avec flèche
// hausse / baisse et le mot « Hausse » / « Baisse » pour le lecteur d'écran.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../donnees/tableau_bord_donnees.dart';
import '../../models/tableau_bord_achats_ventes_model.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot3.dart';
import 'periode.dart';

/// Graphique affiché (les trois analyses de l'écran d'origine).
enum VueAnalyse {
  comparee('Comparée'),
  achats('Achats'),
  ventes('Ventes');

  final String libelle;
  const VueAnalyse(this.libelle);
}

const serieAchats = SerieGraphique('Achats', Charte.ambreTexte, pointilles: true, carre: true);
const serieVentes = SerieGraphique('Ventes', Charte.navy);

class TableauAnalysesNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const TableauAnalysesNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<TableauAnalysesNouveau> createState() => _TableauAnalysesNouveauState();
}

class _TableauAnalysesNouveauState extends State<TableauAnalysesNouveau> with ChargementSuivi<TableauAnalysesNouveau, List<TableauBordAchatsVentes>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.ceMois, widget.maintenant());
  VueAnalyse _vue = VueAnalyse.comparee;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() => charger(() async {
        final l = await TableauBord.charger(context, _periode.debut, _periode.fin, onSessionInvalid: sessionInvalide(context));
        return TableauBord.trier(l ?? const []);
      });

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  static String _date(TableauBordAchatsVentes l) => l.dateMvt == null ? 'N/A' : DateFormat('dd/MM/yyyy').format(l.dateMvt!);

  void _detail(TableauBordAchatsVentes l) => ouvrirFeuilleDetail(context, titre: _date(l), sousTitre: 'Achats et ventes du jour', lignes: [
        LigneDetail('Achats', formaterMontant(l.montantAchat)),
        LigneDetail('Ventes', formaterMontant(l.montantVente)),
        LigneDetail('Écart (ventes − achats)', formaterMontant(l.montantVente - l.montantAchat)),
        LigneDetail('Ratio ventes / achats', formaterRatio(l.ratio), gras: true),
        Align(alignment: Alignment.centerRight, child: EtiquetteNorme(l.ratio)),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tableau: Menu Analyses')),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des achats et des ventes…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <TableauBordAchatsVentes>[];
    if (l.isEmpty) {
      return const [
        EtatVide(titre: 'Aucune donnée pour cette période', texte: 'Choisissez une autre période.', icone: Icons.analytics_outlined),
      ];
    }
    final achats = TableauBord.totalAchats(l), ventes = TableauBord.totalVentes(l);
    final ratio = TableauBord.ratio(achats, ventes);
    final ecart = ventes - achats;
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Ventes', valeur: formaterMontant(ventes), id: 'ventes', enAvant: true, detail: '${l.length} jour${l.length > 1 ? 's' : ''}'),
        ChiffreCle(libelle: 'Achats', valeur: formaterMontant(achats), id: 'achats'),
        ChiffreCle(libelle: 'Écart (ventes − achats)', valeur: '${ecart > 0 ? '+' : ''}${formaterMontant(ecart)}', id: 'ecart'),
        ChiffreCle(
          libelle: 'Ratio ventes / achats',
          valeur: formaterRatio(ratio),
          id: 'ratio',
          detail: 'Norme ${formaterRatio(TableauBord.norme)} · ${libelleNorme(TableauBord.position(ratio)).$1}',
        ),
      ]),
      const TitreSection('Évolution'),
      PucesChoix<VueAnalyse>(
        choix: [for (final v in VueAnalyse.values) (v, v.libelle)],
        valeur: _vue,
        cle: (v, _) => Key('graphique_${v.name}'),
        onChanged: (v) => setState(() => _vue = v),
      ),
      const SizedBox(height: 8),
      if (l.length < 2)
        const Encadre(
          titre: 'Un seul jour',
          texte: 'Choisissez « Autres périodes » (7 jours, ce mois…) ou « Personnaliser » pour voir l\'évolution sur plusieurs jours.',
          icone: Icons.show_chart,
          avertissement: true,
        )
      else ...[
        CadreGraphique(child: GraphiqueAchatsVentes(lignes: l, vue: _vue)),
        const SizedBox(height: 8),
        LegendeGraphique([
          if (_vue != VueAnalyse.ventes) serieAchats,
          if (_vue != VueAnalyse.achats) serieVentes,
        ]),
        const SizedBox(height: 2),
        const Text('Touchez la courbe pour lire les montants d\'un jour.', style: TextStyle(color: Charte.grisTexte, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
      const TitreSection('Jour par jour'),
      _JourParJour(lignes: l, total: ['Total', formaterMontant(achats), formaterMontant(ventes), '', formaterRatio(ratio)], detail: _detail),
    ];
  }
}

/// Évolution des ventes d'un jour par rapport au jour précédent de la liste : (pourcentage, libellé « veille » ou
/// date du jour comparé) ; null pour le premier jour ou si le jour précédent n'a pas de vente.
(double, String)? evolutionVeille(List<TableauBordAchatsVentes> l, int i) {
  if (i <= 0 || i >= l.length) return null;
  final avant = l[i - 1], jour = l[i];
  if (avant.montantVente == 0) return null;
  final p = (jour.montantVente - avant.montantVente) / avant.montantVente * 100;
  final d0 = avant.dateMvt, d1 = jour.dateMvt;
  final veille = d0 != null && d1 != null && DateTime(d1.year, d1.month, d1.day).difference(DateTime(d0.year, d0.month, d0.day)).inDays == 1;
  return (p, veille || d0 == null ? 'veille' : DateFormat('dd/MM').format(d0));
}

String _texteEvolution((double, String) e) => '${e.$1 > 0 ? '+' : (e.$1 < 0 ? '−' : '')}${e.$1.abs().toStringAsFixed(1).replaceAll('.', ',')} % vs ${e.$2}';

/// Flèche (hausse / baisse / stable) et taux d'évolution des ventes ; vert en hausse, rouge en baisse.
class EvolutionVentesJour extends StatelessWidget {
  final (double, String)? evolution;
  const EvolutionVentesJour(this.evolution, {super.key});

  @override
  Widget build(BuildContext context) {
    final e = evolution;
    if (e == null) return const SizedBox.shrink();
    final (icone, mot, couleur) = e.$1 > 0
        ? (Icons.arrow_upward, 'Hausse', Charte.vertTexte)
        : e.$1 < 0
            ? (Icons.arrow_downward, 'Baisse', Charte.rougeTexte)
            : (Icons.drag_handle, 'Stable', Charte.gris);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icone, size: 16, color: couleur, semanticLabel: mot),
      const SizedBox(width: 3),
      Flexible(child: Text(_texteEvolution(e), style: TextStyle(color: couleur, fontSize: 13, fontWeight: FontWeight.w700))),
    ]);
  }
}

class _JourParJour extends StatelessWidget {
  final List<TableauBordAchatsVentes> lignes;
  final List<String> total;
  final void Function(TableauBordAchatsVentes) detail;
  const _JourParJour({required this.lignes, required this.total, required this.detail});

  static String _date(TableauBordAchatsVentes l) => l.dateMvt == null ? 'N/A' : DateFormat('dd/MM/yyyy').format(l.dateMvt!);

  @override
  Widget build(BuildContext context) {
    final l = lignes;
    return ListeOuTableau(
      nombre: l.length,
      onTap: (i) => detail(l[i]),
      colonnes: const [
        Colonne('Date', flex: 2),
        Colonne('Achats', flex: 3, droite: true),
        Colonne('Ventes', flex: 3, droite: true),
        Colonne('Évol. ventes', flex: 3, droite: true),
        Colonne('Ratio', flex: 2, droite: true),
      ],
      cellules: (i) {
        final e = evolutionVeille(l, i);
        return [
          _date(l[i]),
          formaterMontant(l[i].montantAchat),
          formaterMontant(l[i].montantVente),
          e == null ? '—' : '${e.$1 > 0 ? '↑' : (e.$1 < 0 ? '↓' : '=')} ${_texteEvolution(e)}',
          formaterRatio(l[i].ratio),
        ];
      },
      total: total,
      carte: (i) => CarteLigne(
        key: Key('jour_$i'),
        titre: _date(l[i]),
        lignes: ['Ratio ${formaterRatio(l[i].ratio)}'],
        etiquette: Text.rich(
          TextSpan(text: 'Achats ', children: [
            TextSpan(text: formaterMontant(l[i].montantAchat), style: const TextStyle(fontWeight: FontWeight.w800, color: Charte.encre)),
          ]),
          key: Key('jour_achats_$i'),
          style: const TextStyle(fontSize: 13.5, color: Charte.gris),
        ),
        pied: Padding(padding: const EdgeInsets.only(top: 3), child: EvolutionVentesJour(evolutionVeille(l, i), key: Key('jour_evolution_$i'))),
        libelleValeur: 'Ventes',
        valeur: formaterMontant(l[i].montantVente),
        onTap: () => detail(l[i]),
      ),
    );
  }
}

/// Courbes achats / ventes (fl_chart) : mêmes points que les graphiques d'origine (x = rang du jour, y = montant).
class GraphiqueAchatsVentes extends StatelessWidget {
  final List<TableauBordAchatsVentes> lignes;
  final VueAnalyse vue;
  const GraphiqueAchatsVentes({super.key, required this.lignes, required this.vue});

  List<FlSpot> _points(double Function(TableauBordAchatsVentes) y) {
    final s = [for (var i = 0; i < lignes.length; i++) FlSpot(i.toDouble(), y(lignes[i]))];
    if (lignes.length == 1) s.add(FlSpot(1, y(lignes.first)));
    return s;
  }

  LineChartBarData _barre(List<FlSpot> spots, SerieGraphique s) => LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        color: s.couleur,
        barWidth: 3,
        dashArray: s.motif,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: spots.length < 32,
          getDotPainter: (spot, _, __, ___) => s.carre
              ? FlDotSquarePainter(size: 7, color: s.couleur, strokeWidth: 0)
              : FlDotCirclePainter(radius: 3.5, color: s.couleur, strokeWidth: 0),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final series = <(SerieGraphique, List<FlSpot>)>[
      if (vue != VueAnalyse.ventes) (serieAchats, _points((l) => l.montantAchat)),
      if (vue != VueAnalyse.achats) (serieVentes, _points((l) => l.montantVente)),
    ];
    var maxY = 0.0;
    for (final (_, pts) in series) {
      for (final p in pts) {
        if (p.y > maxY) maxY = p.y;
      }
    }
    final pas = lignes.length > 5 ? (lignes.length / 5).roundToDouble().clamp(1.0, double.infinity) : 1.0;
    const style = TextStyle(color: Charte.gris, fontWeight: FontWeight.bold, fontSize: 10);
    return Semantics(
      label: 'Graphique ${vue.libelle.toLowerCase()} des achats et des ventes, ${lignes.length} jours',
      child: LineChart(LineChartData(
        minX: 0,
        maxX: (lignes.length == 1 ? 1 : lignes.length - 1).toDouble(),
        minY: 0,
        maxY: maxY == 0 ? 10 : maxY * 1.1,
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (_) => const FlLine(color: Charte.ligne, strokeWidth: 0.8),
          getDrawingVerticalLine: (_) => const FlLine(color: Charte.ligne, strokeWidth: 0.8),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Charte.bordure)),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: pas,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                final d = i >= 0 && i < lignes.length ? lignes[i].dateMvt : null;
                return SideTitleWidget(axisSide: meta.axisSide, space: 6, child: Text(d == null ? '' : DateFormat('dd/MM').format(d), style: style));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: maxY > 0 ? (maxY / 4).clamp(1, double.infinity) : 1,
              getTitlesWidget: (v, meta) => Text(graduationVisible(v, meta) ? montantCourt(v) : '', style: style),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Charte.navy,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touches) => [
              for (var k = 0; k < touches.length; k++)
                () {
                  final t = touches[k];
                  final i = t.x.toInt();
                  final s = series[t.barIndex].$1;
                  final d = i < lignes.length ? lignes[i].dateMvt : null;
                  return LineTooltipItem(
                    k == 0 && d != null ? '${DateFormat('dd/MM/yyyy').format(d)}\n' : '',
                    const TextStyle(color: Charte.enteteGris, fontSize: 11),
                    children: [TextSpan(text: '${s.libelle} : ${formaterMontant(t.y)}', style: const TextStyle(color: Charte.blanc, fontWeight: FontWeight.bold))],
                  );
                }(),
            ],
          ),
        ),
        lineBarsData: [for (final (s, pts) in series) _barre(pts, s)],
      )),
    );
  }
}
