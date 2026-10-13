// lib/widgets/stock_reserve.dart
// Affichage du stock réserve (GET /info : Analyse Article ; GET /checkproduit : Fiche Article) :
// « Stock rayon », « Stock réserve » (« — » si le produit n'est pas géré en réserve), seuils s'ils sont
// renseignés, « Total rayon + réserve », et pastille orange « À réapprovisionner » quand le rayon est au seuil
// mini ou en dessous, ou la réserve au seuil de réapprovisionnement ou en dessous.
import 'package:flutter/material.dart';

import '../models/stock_reserve.dart';

/// Lignes (libellé, valeur) du stock rayon / réserve, dans l'ordre d'affichage.
/// [rayon] null : stock rayon inconnu (« N/A », pas de total). [avecRayon] faux : la ligne
/// « Stock rayon » est omise (l'écran affiche déjà le stock).
List<(String, String)> stockReserveInfos(int? rayon, StockReserve r, {bool avecRayon = true}) => [
      if (avecRayon) ('Stock rayon', rayon?.toString() ?? 'N/A'),
      ('Stock réserve', r.geree ? '${r.stockReserve}' : '—'),
      if (r.seuilReserveRenseigne != null) ('Seuil réserve', '${r.seuilReserveRenseigne}'),
      if (r.seuilMiniRayonRenseigne != null) ('Seuil mini rayon', '${r.seuilMiniRayonRenseigne}'),
      if (r.geree && rayon != null) ('Total rayon + réserve', '${r.total(rayon)}'),
    ];

/// Pastille d'alerte douce, lisible en thème clair comme sombre.
class PastilleReappro extends StatelessWidget {
  final StockReserve reserve;
  final int? rayon;
  const PastilleReappro({super.key, required this.reserve, required this.rayon});

  /// Raison détaillée (infobulle / lecteur d'écran).
  String get raison => [
        if (rayon != null && reserve.rayonBas(rayon!)) 'rayon au seuil mini ou en dessous',
        if (reserve.reserveBasse) 'réserve au seuil ou en dessous',
      ].join(' ; ');

  static bool visible(StockReserve r, int? rayon) => rayon != null ? r.aReapprovisionner(rayon) : r.reserveBasse;

  @override
  Widget build(BuildContext context) {
    if (!visible(reserve, rayon)) return const SizedBox.shrink();
    final sombre = Theme.of(context).brightness == Brightness.dark;
    final fond = sombre ? const Color(0xFF4A2A0A) : const Color(0xFFFFEDD5);
    final texte = sombre ? const Color(0xFFFED7AA) : const Color(0xFF9A3412);
    return Tooltip(
      message: 'À réapprovisionner : $raison',
      child: Container(
        key: const ValueKey('pastille-reappro'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inventory_2_outlined, size: 13, color: texte),
          const SizedBox(width: 4),
          Flexible(
            child: Text('À réapprovisionner',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: texte)),
          ),
        ]),
      ),
    );
  }
}

/// Résumé d'une ligne de liste : « Réserve : Y · Total : X+Y » + pastille ; rien si non géré en réserve.
class StockReserveResume extends StatelessWidget {
  final StockReserve reserve;
  final int? rayon;
  const StockReserveResume({super.key, required this.reserve, required this.rayon});

  @override
  Widget build(BuildContext context) {
    if (!reserve.geree) return const SizedBox.shrink();
    final couleur = Theme.of(context).colorScheme.onSurfaceVariant;
    final total = rayon == null ? '' : ' · Total : ${reserve.total(rayon!)}';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Réserve : ${reserve.stockReserve}$total', style: TextStyle(fontSize: 13, color: couleur)),
        PastilleReappro(reserve: reserve, rayon: rayon),
      ]),
    );
  }
}
