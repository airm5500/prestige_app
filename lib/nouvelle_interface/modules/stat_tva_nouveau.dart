// lib/nouvelle_interface/modules/stat_tva_nouveau.dart
// Statistiques TVA de la nouvelle interface. Mêmes données et mêmes calculs que l'écran d'origine (StatTvaDonnees,
// lib/donnees/analyses_ventes_donnees.dart) : GET /api/v3/tvas?dtStart=&dtEnd=&typeVente= → « data », totaux HT,
// TVA, TTC et part du TTC de chaque taux (le camembert d'origine). Mise en page refaite : période commune chargée dès
// l'ouverture (« Aujourd'hui », dates par défaut d'origine), type de vente dans la feuille des filtres, chiffres
// clés, anneau des parts (chaque part porte son taux écrit, valeurs du taux touché au centre), tableau par taux avec
// total (cartes sur téléphone), détail d'un taux en feuille.
// 3.8.0 (demande du pharmacien) : menu « Exporter » → PDF A4 (AnalysesPdf, lib/donnees/analyses_pdf.dart) avec
// l'officine, la période, le type de vente, les chiffres clés et le tableau par taux, textes identiques à l'écran.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../donnees/analyses_pdf.dart';
import '../../donnees/analyses_ventes_donnees.dart';
import '../../models/stat_tva_model.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';
import 'commun_lot2.dart';
import 'commun_lot3.dart';
import 'periode.dart';

/// Couleur d'un taux (charte) : 18 % bleu nuit, 9 % vert, 0 % bleu, autre gris (même répartition que l'origine).
Color couleurTaux(int taux) => switch (taux) {
      0 => Charte.bleu,
      9 => Charte.vert,
      18 => Charte.navy,
      _ => Charte.gris,
    };

class StatTvaNouveau extends StatefulWidget {
  final DateTime Function() maintenant;
  const StatTvaNouveau({super.key, this.maintenant = DateTime.now});

  @override
  State<StatTvaNouveau> createState() => _StatTvaNouveauState();
}

class _StatTvaNouveauState extends State<StatTvaNouveau> with ChargementSuivi<StatTvaNouveau, List<StatTva>> {
  late Periode _periode = Periode.rapide(PeriodeRapide.aujourdhui, widget.maintenant());
  TypeVente _type = TypeVente.tout;
  int? _touche;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  Future<void> _charger() {
    _touche = null;
    final lu = (periode: _periode, type: _type);
    _lu = null;
    return charger(() async {
      final r = await StatTvaDonnees.charger(context, lu.periode.debut, lu.periode.fin, lu.type, onSessionInvalid: sessionInvalide(context)) ?? const <StatTva>[];
      _lu = lu;
      return r;
    });
  }

  void _changerPeriode(Periode p) {
    setState(() => _periode = p);
    _charger();
  }

  Future<void> _filtres() async {
    var type = _type;
    final applique = await ouvrirFeuilleFiltres(
      context,
      titre: 'Filtrer les statistiques TVA',
      effacer: () => type = TypeVente.tout,
      contenu: (ctx, setState) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Type de vente', style: TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        PucesChoix<TypeVente>(
          choix: [for (final t in TypeVente.values) (t, t.libelle)],
          valeur: type,
          cle: (v, _) => Key('filtre_type_${v.name}'),
          onChanged: (v) => setState(() => type = v),
        ),
      ]),
    );
    if (!applique || !mounted) return;
    setState(() => _type = type);
    _charger();
  }

  /// Chargement lu (période et type de la requête affichée) : le PDF reprend exactement ce qui est affiché.
  ({Periode periode, TypeVente type})? _lu;

  /// PDF des statistiques affichées (aucune requête, aucun recalcul).
  Future<void> _pdf() async {
    final l = donnees;
    final lu = _lu;
    if (enCours || erreur != null || l == null || l.isEmpty || lu == null) {
      messageResultat(context, 'Aucune donnée à exporter', echec: true);
      return;
    }
    final contenu = contenuPdf(l, periode: lu.periode, type: lu.type, officine: officineConnectee(context), imprimeLe: widget.maintenant());
    try {
      await AnalysesPdf.sortie(contenu, AnalysesPdf.nom('Stat_TVA', lu.periode.debut, lu.periode.fin));
    } catch (_) {
      if (mounted) messageResultat(context, 'Erreur lors de la préparation du PDF.', echec: true);
    }
  }

  /// Contenu du PDF : mêmes textes que l'écran (chiffres clés, tableau par taux, total).
  static ContenuAnalysePdf contenuPdf(List<StatTva> l,
      {required Periode periode, required TypeVente type, required String officine, required DateTime imprimeLe}) {
    final ht = StatTvaDonnees.totalHt(l), tva = StatTvaDonnees.totalTva(l), ttc = StatTvaDonnees.totalTtc(l);
    final parts = StatTvaDonnees.parts(l);
    String part(int i) => parts.isEmpty ? '—' : formaterPourcent(parts[i]);
    return ContenuAnalysePdf(
      officine: officine,
      titre: 'Statistiques TVA',
      periode: periode.resume,
      filtres: [('Type de vente', type.libelle)],
      imprimeLe: ContenuAnalysePdf.horodatage(imprimeLe),
      chiffres: [
        ('Total TTC', formaterMontant(ttc)),
        ('Total HT', formaterMontant(ht)),
        ('Total TVA', formaterMontant(tva)),
        ('Taux de TVA', formaterNombre(l.length)),
      ],
      titreDetail: 'Par taux',
      colonnes: const ['Taux', 'HT', 'TVA', 'TTC', 'Part du TTC'],
      droite: const {1, 2, 3, 4},
      lignes: [
        for (var i = 0; i < l.length; i++) ['${l[i].taux} %', formaterMontant(l[i].totalHt), formaterMontant(l[i].totalTva), formaterMontant(l[i].totalTtc), part(i)],
      ],
      total: ['Total', formaterMontant(ht), formaterMontant(tva), formaterMontant(ttc), parts.isEmpty ? '—' : '100 %'],
    );
  }

  void _detail(StatTva s, double? part) => ouvrirFeuilleDetail(context, titre: 'TVA ${s.taux} %', sousTitre: _type.libelle, lignes: [
        LigneDetail('Total HT', formaterMontant(s.totalHt)),
        LigneDetail('Total TVA', formaterMontant(s.totalTva)),
        LigneDetail('Total TTC', formaterMontant(s.totalTtc), gras: true),
        LigneDetail('Part du TTC', part == null ? '—' : formaterPourcent(part)),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Statistiques TVA'), actions: [
          MenuExports(actions: [ActionExport('PDF des statistiques TVA', Icons.picture_as_pdf_outlined, _pdf)]),
          BoutonFiltres(actifs: _type == TypeVente.tout ? 0 : 1, onPressed: _filtres),
        ]),
        body: RefreshIndicator(
          onRefresh: _charger,
          child: ListView(key: const Key('defilement_module'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            SelecteurPeriode(periode: _periode, onChanged: _changerPeriode, maintenant: widget.maintenant),
            EtiquettesFiltres(
              etiquettes: [if (_type != TypeVente.tout) _type.libelle],
              onRetirer: () {
                setState(() => _type = TypeVente.tout);
                _charger();
              },
            ),
            const SizedBox(height: 8),
            ..._corps(),
          ]),
        ),
      );

  List<Widget> _corps() {
    if (enCours) return const [EtatChargement(texte: 'Chargement des statistiques TVA…')];
    if (erreur != null) return [EtatErreur(erreur: erreur!, reessayer: _charger)];
    final l = donnees ?? const <StatTva>[];
    if (l.isEmpty) {
      return const [
        EtatVide(titre: 'Aucune statistique de TVA', texte: 'Aucune vente pour les critères sélectionnés.', icone: Icons.pie_chart_outline),
      ];
    }
    final ht = StatTvaDonnees.totalHt(l), tva = StatTvaDonnees.totalTva(l), ttc = StatTvaDonnees.totalTtc(l);
    final parts = StatTvaDonnees.parts(l);
    String part(int i) => parts.isEmpty ? '—' : formaterPourcent(parts[i]);
    return [
      GrilleKpi([
        ChiffreCle(libelle: 'Total TTC', valeur: formaterMontant(ttc), id: 'ttc', enAvant: true),
        ChiffreCle(libelle: 'Total HT', valeur: formaterMontant(ht), id: 'ht'),
        ChiffreCle(libelle: 'Total TVA', valeur: formaterMontant(tva), id: 'tva'),
        ChiffreCle(libelle: 'Taux de TVA', valeur: formaterNombre(l.length), id: 'taux'),
      ]),
      if (parts.isNotEmpty) ...[
        const TitreSection('Part du TTC par taux'),
        CadreGraphique(
          hauteur: 250,
          child: _Anneau(stats: l, parts: parts, touche: _touche, onTouche: (i) => setState(() => _touche = i)),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          for (var i = 0; i < l.length; i++)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: couleurTaux(l[i].taux), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text('${l[i].taux} % · ${part(i)}', style: const TextStyle(color: Charte.encre, fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
        ]),
        const SizedBox(height: 2),
        const Text('Touchez une part pour lire ses montants.', style: TextStyle(color: Charte.grisTexte, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
      const TitreSection('Par taux'),
      ListeOuTableau(
        nombre: l.length,
        onTap: (i) => _detail(l[i], parts.isEmpty ? null : parts[i]),
        colonnes: const [
          Colonne('Taux', flex: 2),
          Colonne('HT', flex: 3, droite: true),
          Colonne('TVA', flex: 3, droite: true),
          Colonne('TTC', flex: 3, droite: true),
          Colonne('Part', flex: 2, droite: true),
        ],
        cellules: (i) => ['${l[i].taux} %', formaterMontant(l[i].totalHt), formaterMontant(l[i].totalTva), formaterMontant(l[i].totalTtc), part(i)],
        total: ['Total', formaterMontant(ht), formaterMontant(tva), formaterMontant(ttc), parts.isEmpty ? '—' : '100 %'],
        carte: (i) => CarteLigne(
          titre: 'TVA ${l[i].taux} %',
          lignes: ['HT ${formaterMontant(l[i].totalHt)}', 'TVA ${formaterMontant(l[i].totalTva)} · ${part(i)} du TTC'],
          bande: couleurTaux(l[i].taux),
          libelleValeur: 'TTC',
          valeur: formaterMontant(l[i].totalTtc),
          onTap: () => _detail(l[i], parts.isEmpty ? null : parts[i]),
        ),
      ),
    ];
  }
}

/// Anneau des parts du TTC (fl_chart) : chaque part porte une étiquette « 18 % » (le taux, écrit), la part touchée
/// s'élargit et ses montants s'affichent au centre.
class _Anneau extends StatelessWidget {
  final List<StatTva> stats;
  final List<double> parts;
  final int? touche;
  final ValueChanged<int?> onTouche;
  const _Anneau({required this.stats, required this.parts, required this.touche, required this.onTouche});

  @override
  Widget build(BuildContext context) {
    final t = touche != null && touche! < stats.length ? touche : null;
    return Semantics(
      label: 'Anneau des parts du TTC : ${[for (var i = 0; i < stats.length; i++) '${stats[i].taux} % ${formaterPourcent(parts[i])}'].join(', ')}',
      child: Stack(alignment: Alignment.center, children: [
        PieChart(PieChartData(
          centerSpaceRadius: 46,
          sectionsSpace: 2,
          pieTouchData: PieTouchData(touchCallback: (evenement, reponse) {
            if (!evenement.isInterestedForInteractions) return;
            final i = reponse?.touchedSection?.touchedSectionIndex;
            onTouche(i == null || i < 0 ? null : i);
          }),
          sections: [
            for (var i = 0; i < stats.length; i++)
              PieChartSectionData(
                color: couleurTaux(stats[i].taux),
                value: stats[i].totalTtc,
                showTitle: false,
                radius: i == t ? 46 : 40,
                badgeWidget: parts[i] < 4 ? null : Etiquette('${stats[i].taux} %', ton: Ton.gris),
                badgePositionPercentageOffset: 1.18,
              ),
          ],
        )),
        IgnorePointer(
          child: SizedBox(
            width: 96,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(t == null ? 'Total TTC' : 'TVA ${stats[t].taux} %',
                  textAlign: TextAlign.center, style: const TextStyle(color: Charte.gris, fontSize: 11.5, fontWeight: FontWeight.w600)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  key: const Key('anneau_centre'),
                  t == null ? montantCourt(StatTvaDonnees.totalTtc(stats)) : formaterPourcent(parts[t]),
                  style: const TextStyle(color: Charte.encre, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              if (t != null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(montantCourt(stats[t].totalTtc), style: const TextStyle(color: Charte.gris, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
