// lib/models/suivi_20_80_model.dart

class Suivi2080 {
  final String cip;
  final String libelle;
  final int montant;
  final int quantiteVendue;
  final int stock;

  Suivi2080({
    required this.cip,
    required this.libelle,
    required this.montant,
    required this.quantiteVendue,
    required this.stock,
  });

  factory Suivi2080.fromJson(Map<String, dynamic> json) {
    return Suivi2080(
      cip: json['intCIP'] as String? ?? '',
      libelle: json['strNAME'] as String? ?? 'N/A',
      montant: (json['intPRICE'] as num?)?.toInt() ?? 0,
      quantiteVendue: (json['intQUANTITY'] as num?)?.toInt() ?? 0,
      stock: (json['intQUANTITYSERVED'] as num?)?.toInt() ?? 0,
    );
  }
}