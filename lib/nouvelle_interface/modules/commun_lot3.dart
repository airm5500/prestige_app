// lib/nouvelle_interface/modules/commun_lot3.dart
// Briques communes aux modules refaits du lot 3 (analyses), en plus de commun.dart, commun_lot2.dart et
// periode.dart : montants abrégés des axes de graphique, ratio à la française, étiquette de position par rapport à
// la norme (texte ET couleur), légende de graphique (trait plein / pointillé, marqueur), feuille de détail,
// affichage local par tranches (« Afficher plus » sans nouvelle requête).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../donnees/tableau_bord_donnees.dart';
import '../charte.dart';
import '../composants.dart';
import 'commun.dart';

/// Montant abrégé pour un axe : « 850 », « 12 k », « 1,2 M ».
String montantCourt(double v) {
  final a = v.abs();
  final s = v < 0 ? '-' : '';
  if (a >= 1000000) return '$s${(a / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  if (a >= 1000) return '$s${(a / 1000).toStringAsFixed(0)} k';
  return '$s${a.toStringAsFixed(0)}';
}

/// Ratio à deux décimales et virgule : « 1,51 ».
String formaterRatio(double r) => r.toStringAsFixed(2).replaceAll('.', ',');

/// Pourcentage à une décimale : « 62,3 % ».
String formaterPourcent(double p) => '${p.toStringAsFixed(1).replaceAll('.', ',')} %';

/// Libellé et ton de la position d'un ratio par rapport à la norme (1,51).
(String, Ton) libelleNorme(PositionNorme p) => switch (p) {
      PositionNorme.sansAchat => ('Sans achat', Ton.gris),
      PositionNorme.conforme => ('≥ norme', Ton.vert),
      PositionNorme.sousLaNorme => ('< norme', Ton.rouge),
    };

/// Étiquette « ≥ norme » (vert) / « < norme » (rouge) / « Sans achat » (gris) : le sens est écrit, pas seulement coloré.
class EtiquetteNorme extends StatelessWidget {
  final double ratio;
  const EtiquetteNorme(this.ratio, {super.key});

  @override
  Widget build(BuildContext context) {
    final (texte, ton) = libelleNorme(TableauBord.position(ratio));
    return Etiquette(texte, ton: ton);
  }
}

/// Une série d'un graphique : couleur, trait (plein ou pointillé) et marqueur (rond ou carré).
class SerieGraphique {
  final String libelle;
  final Color couleur;
  final bool pointilles;
  final bool carre;

  /// Marqueur dans la légende (faux pour une ligne de référence, ex. la norme).
  final bool marqueur;
  const SerieGraphique(this.libelle, this.couleur, {this.pointilles = false, this.carre = false, this.marqueur = true});

  /// Motif du trait (fl_chart : dashArray).
  List<int>? get motif => pointilles ? const [7, 4] : null;
}

/// Légende : un échantillon (trait plein ou pointillé + marqueur) et un libellé par série.
class LegendeGraphique extends StatelessWidget {
  final List<SerieGraphique> series;
  const LegendeGraphique(this.series, {super.key});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 16, runSpacing: 4, children: [
        for (final s in series)
          Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 30, height: 14, child: CustomPaint(painter: _Echantillon(s))),
            const SizedBox(width: 6),
            Text(s.libelle, style: const TextStyle(color: Charte.encre, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
      ]);
}

class _Echantillon extends CustomPainter {
  final SerieGraphique s;
  _Echantillon(this.s);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = s.couleur
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (s.pointilles) {
      for (double x = 0; x < size.width; x += 11) {
        canvas.drawLine(Offset(x, y), Offset((x + 7).clamp(0, size.width), y), p);
      }
    } else {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    if (!s.marqueur) return;
    final c = Offset(size.width / 2, y);
    final f = Paint()..color = s.couleur;
    if (s.carre) {
      canvas.drawRect(Rect.fromCenter(center: c, width: 8, height: 8), f);
    } else {
      canvas.drawCircle(c, 4.5, f);
    }
  }

  @override
  bool shouldRepaint(_Echantillon old) => old.s != s;
}

/// Graduation d'axe : rien pour la borne haute quand elle ne tombe pas sur un pas (évite deux libellés collés).
bool graduationVisible(double v, TitleMeta meta) => v < meta.max || (meta.appliedInterval > 0 && (v / meta.appliedInterval - (v / meta.appliedInterval).round()).abs() < 1e-6);

/// Cadre blanc d'un graphique (même aspect que la courbe de l'Évolution du stock).
class CadreGraphique extends StatelessWidget {
  final double hauteur;
  final Widget child;
  const CadreGraphique({super.key, this.hauteur = 260, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        height: hauteur,
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(6, 18, 18, 8),
        child: child,
      );
}

/// Feuille du bas de détail (une ligne touchée) : titre, sous-titre, lignes.
Future<void> ouvrirFeuilleDetail(BuildContext context, {required String titre, String? sousTitre, required List<Widget> lignes}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) => SingleChildScrollView(
        key: const Key('feuille_detail'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(titre, style: const TextStyle(color: Charte.navy, fontSize: 18, fontWeight: FontWeight.bold)),
          if (sousTitre != null) ...[
            const SizedBox(height: 2),
            Text(sousTitre, style: const TextStyle(color: Charte.gris, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          ...lignes,
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('detail_fermer'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ]),
      ),
    );

/// Affichage local par tranches : les listes longues (jusqu'à 9 999 lignes) sont construites [tranche] par
/// [tranche] ; « Afficher plus » n'envoie AUCUNE requête (toutes les lignes sont déjà chargées).
mixin AffichageParTranches<W extends StatefulWidget> on State<W> {
  static const tranche = 50;
  int affichees = tranche;

  void reinitialiserTranches() => affichees = tranche;

  /// Pied « N lignes affichées sur M » et « Afficher plus » quand il en reste.
  Widget piedTranches(int total) => total <= tranche
      ? const SizedBox.shrink()
      : PiedPagination(
          affichees: affichees.clamp(0, total),
          total: total,
          enCours: false,
          onPlus: () => setState(() => affichees += tranche),
        );
}
