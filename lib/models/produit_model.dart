// lib/models/produit_model.dart

import 'stock_reserve.dart';

class Produit {
  final String? emplacement;
  final String familleCip;
  final String? familleId;
  final String familleLibelle; // Designation
  final double pachat; // Prix d'achat
  final double pvente; // Prix de vente
  final int stock;

  // Stock réserve (null : produit non géré en réserve, ou serveur ancien sans ces champs)
  final int? stockReserve;
  final int? seuilReserve;
  final int? seuilMiniRayon;

  Produit({
    this.emplacement,
    required this.familleCip,
    this.familleId,
    required this.familleLibelle,
    required this.pachat,
    required this.pvente,
    required this.stock,
    this.stockReserve,
    this.seuilReserve,
    this.seuilMiniRayon,
  });

  /// Stock réserve et seuils (affichage, alerte de réapprovisionnement).
  StockReserve get reserve => StockReserve(stockReserve: stockReserve, seuilReserve: seuilReserve, seuilMiniRayon: seuilMiniRayon);

  factory Produit.fromJson(Map<String, dynamic> json) {
    return Produit(
      emplacement: json['emplacement'] as String?,
      familleCip: json['familleCip'] as String? ?? '',
      familleId: json['familleId'] as String?,
      familleLibelle: json['familleLibelle'] as String? ?? 'N/A',
      pachat: (json['pachat'] as num?)?.toDouble() ?? 0.0,
      pvente: (json['pvente'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      // Lecture tolérante : absent, null, nombre, texte numérique, décimal.
      stockReserve: entierTolerant(json['stockReserve']),
      seuilReserve: entierTolerant(json['seuilReserve']),
      seuilMiniRayon: entierTolerant(json['seuilMiniRayon']),
    );
  }

  // Pour l'affichage simplifié dans la liste de recherche
  String get designation => familleLibelle;
  double get prixVente => pvente;
  int get stockActuel => stock;

  @override
  String toString() {
    return 'Produit{familleLibelle: $familleLibelle, pvente: $pvente, stock: $stock}';
  }
}
