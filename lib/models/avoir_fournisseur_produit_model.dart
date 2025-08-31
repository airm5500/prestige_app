// lib/models/avoir_fournisseur_produit_model.dart

import '../utils/date_formatter.dart';

class AvoirFournisseurProduit {
  final String cip;
  final DateTime? dateAvoir;
  final String libelle;
  final String natureReclamation;
  final String numeroBl;
  final int prixAchatHt;
  final int quantite;

  AvoirFournisseurProduit({
    required this.cip,
    this.dateAvoir,
    required this.libelle,
    required this.natureReclamation,
    required this.numeroBl,
    required this.prixAchatHt,
    required this.quantite,
  });

  factory AvoirFournisseurProduit.fromJson(Map<String, dynamic> json) {
    return AvoirFournisseurProduit(
      cip: json['cip'] as String? ?? '',
      dateAvoir: DateFormatter.parseDDMMYYYYHHMM(json['dateAvoir'] as String?),
      libelle: json['libelle'] as String? ?? 'N/A',
      natureReclamation: json['natureReclamation'] as String? ?? '',
      numeroBl: json['numeroBl'] as String? ?? '',
      prixAchatHt: json['prixAchatHt'] as int? ?? 0,
      quantite: json['quantite'] as int? ?? 0,
    );
  }
}