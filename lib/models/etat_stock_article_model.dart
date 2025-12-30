// lib/models/etat_stock_article_model.dart

class EtatStockArticleModel {
  final String id;
  final String code;
  final String libelle;
  final double stock;
  final double prixAchat;
  final double prixVente;
  final String rayonLibelle;
  final String? codeEan;
  final String? tva;
  final String? dateInventaire;
  final String? dateEntree;
  final double? seuiRappro;
  final double? qteReappro;
  final String? grossisteId;

  EtatStockArticleModel({
    required this.id,
    required this.code,
    required this.libelle,
    required this.stock,
    required this.prixAchat,
    required this.prixVente,
    required this.rayonLibelle,
    this.codeEan,
    this.tva,
    this.dateInventaire,
    this.dateEntree,
    this.seuiRappro,
    this.qteReappro,
    this.grossisteId,
  });

  // Fonction utilitaire pour convertir n'importe quel nombre/chaîne en double en toute sécurité
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory EtatStockArticleModel.fromJson(Map<String, dynamic> json) {
    return EtatStockArticleModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      libelle: json['libelle']?.toString() ?? 'Sans nom',
      stock: _parseDouble(json['stock']),
      prixAchat: _parseDouble(json['prixAchat']),
      prixVente: _parseDouble(json['prixVente']),
      rayonLibelle: json['rayonLibelle']?.toString() ?? '',
      codeEan: json['codeEan']?.toString(),
      tva: json['tva']?.toString(),
      dateInventaire: json['dateInventaire']?.toString(),
      dateEntree: json['dateEntree']?.toString(),
      seuiRappro: _parseDouble(json['seuiRappro']),
      qteReappro: _parseDouble(json['qteReappro']),
      grossisteId: json['grossisteId']?.toString(),
    );
  }
}