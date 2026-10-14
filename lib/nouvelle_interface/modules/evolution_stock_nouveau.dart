// lib/nouvelle_interface/modules/evolution_stock_nouveau.dart
// Évolution du Stock de la nouvelle interface. Mêmes données que l'écran d'origine (EvolutionStock,
// lib/donnees/evolution_stock_donnees.dart) : GET /valorisation/all?dtStart=&dtEnd=, un point par jour (valeur
// d'achat du stock). Mise en page refaite : période commune (chargée à l'ouverture sur « 7 jours » : une courbe a
// besoin de plusieurs jours), chiffres clés (début, fin, variation, plus haut, plus bas), courbe, jour par jour
// (cartes sur téléphone, tableau sur tablette), PDF du graphique d'origine dans le menu Exporter.
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../donnees/evolution_stock_donnees.dart';
import '../../models/evolution_stock_point_model.dart';
import '../../services/journal_app.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot2.dart';
import 'periode.dart';

class EvolutionStockNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const EvolutionStockNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<EvolutionStockNouveau> createState() => _EvolutionStockNouveauState();
}

class _EvolutionStockNouveauState extends State<EvolutionStockNouveau> with ChargementSuivi<EvolutionStockNouveau, List<EvolutionStockPoint>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.septJours, widget.maintenant());
  final _cleGraphique = GlobalKey();

  /// Jours affichés dans « jour par jour » (les plus récents d'abord) avant « Afficher tout ».
  static const joursAffiches = 31;
  bool _tousLesJours = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() {
    _tousLesJours = false;
    return charger(() async =>
        await EvolutionStock.charger(context, _periode.debut, _periode.fin, onSessionInvalid: sessionInvalide(context)) ?? const <EvolutionStockPoint>[]);
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  Future<void> _pdf() async {
    final contexte = _cleGraphique.currentContext;
    if (contexte == null || (donnees ?? const []).isEmpty) {
      messageResultat(context, 'Aucune donnée à imprimer', echec: true);
      return;
    }
    try {
      final boundary = contexte.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final octets = await image.toByteData(format: ui.ImageByteFormat.png);
      if (octets == null) return;
      await EvolutionStock.imprimerPdf(octets.buffer.asUint8List(), _periode.debut, _periode.fin);
    } catch (e) {
      JournalApp.debug('Evolution stock, PDF : ${e.runtimeType}');
      if (mounted) messageResultat(context, 'Erreur lors de la préparation de l\'impression.', echec: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Évolution du Stock'), actions: [
          MenuExports(actions: [ActionExport('PDF du graphique', Icons.picture_as_pdf_outlined, _pdf)]),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  static String _jour(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Calcul de l\'évolution du stock…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final p = donnees ?? const <EvolutionStockPoint>[];
    final r = EvolutionStock.resume(p);
    if (r == null) {
      return const [EtatVide(titre: 'Aucune donnée à afficher', texte: 'Choisissez une autre période.', icone: Icons.ssid_chart_outlined)];
    }
    final pct = r.variationPourcent;
    final signe = r.variation > 0 ? '+' : '';
    final recents = p.reversed.toList();
    final jours = _tousLesJours ? recents : recents.take(joursAffiches).toList();
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Valeur d\'achat à la fin', valeur: formaterMontant(r.fin), id: 'fin', enAvant: true, detail: _jour(p.last.date)),
        ChiffreCle(libelle: 'Valeur d\'achat au début', valeur: formaterMontant(r.debut), id: 'debut', detail: _jour(p.first.date)),
        ChiffreCle(
          libelle: 'Variation',
          valeur: '$signe${formaterMontant(r.variation)}',
          id: 'variation',
          detail: pct == null ? null : '$signe${pct.toStringAsFixed(1).replaceAll('.', ',')} % ${r.variation > 0 ? '(hausse)' : (r.variation < 0 ? '(baisse)' : '')}',
        ),
        ChiffreCle(libelle: 'Plus haut', valeur: formaterMontant(r.maximum), id: 'max', detail: _jour(r.dateMax)),
      ]),
      const TitreSection('Valeur d\'achat du stock'),
      Container(
        height: 260,
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: RepaintBoundary(key: _cleGraphique, child: Container(color: Charte.blanc, padding: const EdgeInsets.fromLTRB(6, 18, 18, 8), child: _Courbe(points: p))),
      ),
      const SizedBox(height: 6),
      Text('Plus bas : ${formaterMontant(r.minimum)} le ${_jour(r.dateMin)}', style: const TextStyle(color: Charte.grisTexte, fontSize: 13, fontWeight: FontWeight.w600)),
      const TitreSection('Jour par jour'),
      ListeOuTableau(
        nombre: jours.length,
        colonnes: const [Colonne('Date', flex: 2), Colonne('Valeur d\'achat', flex: 3, droite: true), Colonne('Valeur de vente', flex: 3, droite: true)],
        cellules: (i) => [_jour(jours[i].date), formaterMontant(jours[i].data.valeurAchat), formaterMontant(jours[i].data.valeurVente)],
        carte: (i) => CarteLigne(
          titre: _jour(jours[i].date),
          lignes: ['Valeur de vente ${formaterMontant(jours[i].data.valeurVente)}'],
          libelleValeur: 'Valeur d\'achat',
          valeur: formaterMontant(jours[i].data.valeurAchat),
        ),
      ),
      if (!_tousLesJours && recents.length > joursAffiches)
        Center(
          child: OutlinedButton.icon(
            key: const Key('evolution_tous_les_jours'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => setState(() => _tousLesJours = true),
            icon: const Icon(Icons.expand_more),
            label: Text('Afficher tous les jours (${formaterNombre(recents.length)})'),
          ),
        ),
    ];
  }
}

/// Courbe de la valeur d'achat (fl_chart), aux couleurs de la charte.
class _Courbe extends StatelessWidget {
  final List<EvolutionStockPoint> points;
  const _Courbe({required this.points});

  static String _court(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)} k';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final spots = [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].data.valeurAchat)];
    if (points.length == 1) spots.add(FlSpot(1, points.first.data.valeurAchat));
    final maxY = points.fold<double>(0, (m, p) => p.data.valeurAchat > m ? p.data.valeurAchat : m);
    final pas = points.length > 5 ? (points.length / 5).roundToDouble().clamp(1.0, double.infinity) : 1.0;
    const style = TextStyle(color: Charte.gris, fontWeight: FontWeight.bold, fontSize: 10);
    return Semantics(
      label: 'Courbe de la valeur d\'achat du stock, ${points.length} jours',
      child: LineChart(LineChartData(
        minX: 0,
        maxX: (points.length == 1 ? 1 : points.length - 1).toDouble(),
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
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 6,
                  child: Text(i >= 0 && i < points.length ? DateFormat('dd/MM').format(points[i].date) : '', style: style),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: maxY > 0 ? (maxY / 4).clamp(1, double.infinity) : 1,
              getTitlesWidget: (v, meta) => Text(_court(v), style: style),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Charte.navy,
            getTooltipItems: (touches) => [
              for (final t in touches)
                t.x.toInt() < points.length
                    ? LineTooltipItem(
                        '${DateFormat('dd/MM/yyyy').format(points[t.x.toInt()].date)}\n',
                        const TextStyle(color: Charte.enteteGris, fontSize: 11),
                        children: [TextSpan(text: formaterMontant(t.y), style: const TextStyle(color: Charte.blanc, fontWeight: FontWeight.bold))],
                      )
                    : null,
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: Charte.navy,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: spots.length < 20),
            belowBarData: BarAreaData(show: true, color: Charte.bleuClair),
          ),
        ],
      )),
    );
  }
}
