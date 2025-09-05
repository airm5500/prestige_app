// lib/models/etat_controle_achat_meta_model.dart

class EtatControleAchatMeta {
  final int totalNbreBon;
  final double totalMarge;
  final double totalTtc;
  final double totalTaxe;
  final double totalVenteTtc;
  final double totaltHtaxe;

  EtatControleAchatMeta({
    required this.totalNbreBon,
    required this.totalMarge,
    required this.totalTtc,
    required this.totalTaxe,
    required this.totalVenteTtc,
    required this.totaltHtaxe,
  });

  factory EtatControleAchatMeta.fromJson(Map<String, dynamic> json) {
    return EtatControleAchatMeta(
      totalNbreBon: (json['totalNbreBon'] as num?)?.toInt() ?? 0,
      totalMarge: (json['totalMarge'] as num?)?.toDouble() ?? 0.0,
      totalTtc: (json['totalTtc'] as num?)?.toDouble() ?? 0.0,
      totalTaxe: (json['totalTaxe'] as num?)?.toDouble() ?? 0.0,
      totalVenteTtc: (json['totalVenteTtc'] as num?)?.toDouble() ?? 0.0,
      totaltHtaxe: (json['totaltHtaxe'] as num?)?.toDouble() ?? 0.0,
    );
  }
}