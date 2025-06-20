// lib/models/produit_model.dart

class Produit {
  final String? emplacement;
  final String familleCip;
  final String? familleId;
  final String familleLibelle; // Designation
  final double pachat; // Prix d'achat
  final double pvente; // Prix de vente
  final int stock;

  Produit({
    this.emplacement,
    required this.familleCip,
    this.familleId,
    required this.familleLibelle,
    required this.pachat,
    required this.pvente,
    required this.stock,
  });

  factory Produit.fromJson(Map<String, dynamic> json) {
    return Produit(
      emplacement: json['emplacement'] as String?,
      familleCip: json['familleCip'] as String? ?? '',
      familleId: json['familleId'] as String?,
      familleLibelle: json['familleLibelle'] as String? ?? 'N/A',
      pachat: (json['pachat'] as num?)?.toDouble() ?? 0.0,
      pvente: (json['pvente'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
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
