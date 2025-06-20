// lib/models/evolution_stock_point_model.dart

import './valorisation_model.dart';

// Classe pour combiner un point de donnée de valorisation avec sa date
class EvolutionStockPoint {
  final DateTime date;
  final ValorisationStock data;

  EvolutionStockPoint({
    required this.date,
    required this.data,
  });
}
