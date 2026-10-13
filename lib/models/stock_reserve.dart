// lib/models/stock_reserve.dart
// Stock en réserve d'un produit, renvoyé par GET /info et GET /checkproduit (serveur 2e4615e) :
// `stockReserve` (quantité en réserve, 0 si le produit est géré en réserve sans rien en réserve),
// `seuilReserve` (seuil de réapprovisionnement de la réserve), `seuilMiniRayon` (seuil mini du rayon).
// Les trois sont null quand le produit n'est pas géré en réserve, et absents d'un serveur plus ancien.

/// Entier lu sans échec : nombre (décimal tronqué), texte numérique (« 12 », « 12.0 », « 12,5 »),
/// sinon null (absent, null, texte vide ou non numérique, booléen…).
int? entierTolerant(dynamic v) {
  num? n;
  if (v is num) {
    n = v;
  } else if (v is String) {
    final t = v.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (t.isEmpty) return null;
    n = num.tryParse(t);
  }
  if (n == null || n.isNaN || n.isInfinite) return null;
  return n.toInt();
}

class StockReserve {
  /// Quantité en réserve ; null : produit non géré en réserve (ou serveur ancien).
  final int? stockReserve;

  /// Seuil de réapprovisionnement de la réserve (null ou ≤ 0 : non renseigné).
  final int? seuilReserve;

  /// Seuil mini du rayon (null ou ≤ 0 : non renseigné).
  final int? seuilMiniRayon;

  const StockReserve({this.stockReserve, this.seuilReserve, this.seuilMiniRayon});

  static const aucun = StockReserve();

  factory StockReserve.fromJson(Map<String, dynamic> json) => StockReserve(
        stockReserve: entierTolerant(json['stockReserve']),
        seuilReserve: entierTolerant(json['seuilReserve']),
        seuilMiniRayon: entierTolerant(json['seuilMiniRayon']),
      );

  /// Produit géré en réserve (le serveur a renvoyé une quantité, même 0).
  bool get geree => stockReserve != null;

  /// Seuils affichés : seulement s'ils sont renseignés (> 0).
  int? get seuilReserveRenseigne => (seuilReserve ?? 0) > 0 ? seuilReserve : null;
  int? get seuilMiniRayonRenseigne => (seuilMiniRayon ?? 0) > 0 ? seuilMiniRayon : null;

  /// Total rayon + réserve (null si le produit n'est pas géré en réserve).
  int? total(int stockRayon) => geree ? stockRayon + stockReserve! : null;

  /// Rayon au seuil mini ou en dessous (seuil renseigné, produit géré en réserve).
  bool rayonBas(int stockRayon) => geree && seuilMiniRayonRenseigne != null && stockRayon <= seuilMiniRayonRenseigne!;

  /// Réserve au seuil de réapprovisionnement ou en dessous (seuil renseigné).
  bool get reserveBasse => geree && seuilReserveRenseigne != null && stockReserve! <= seuilReserveRenseigne!;

  /// Pastille « À réapprovisionner » : rayon ≤ seuil mini rayon ou réserve ≤ seuil réserve.
  bool aReapprovisionner(int stockRayon) => rayonBas(stockRayon) || reserveBasse;
}
