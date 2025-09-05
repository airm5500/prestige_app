// lib/models/etat_controle_achat_model.dart

class EtatControleAchat {
  final double pourcentage;
  final double montantMarge;
  final int nbreBon;
  final double montantTtc;
  final double montantTaxe;
  final double montantVenteTtc;
  final double montantHtaxe;
  final String groupByLibelle;

  EtatControleAchat({
    required this.pourcentage,
    required this.montantMarge,
    required this.nbreBon,
    required this.montantTtc,
    required this.montantTaxe,
    required this.montantVenteTtc,
    required this.montantHtaxe,
    required this.groupByLibelle,
  });

  factory EtatControleAchat.fromJson(Map<String, dynamic> json) {
    return EtatControleAchat(
      pourcentage: (json['pourcentage'] as num?)?.toDouble() ?? 0.0,
      montantMarge: (json['montantMarge'] as num?)?.toDouble() ?? 0.0,
      nbreBon: (json['nbreBon'] as num?)?.toInt() ?? 0,
      montantTtc: (json['montantTtc'] as num?)?.toDouble() ?? 0.0,
      montantTaxe: (json['montantTaxe'] as num?)?.toDouble() ?? 0.0,
      montantVenteTtc: (json['montantVenteTtc'] as num?)?.toDouble() ?? 0.0,
      montantHtaxe: (json['montantHtaxe'] as num?)?.toDouble() ?? 0.0,
      groupByLibelle: json['groupByLibelle'] as String? ?? 'N/A',
    );
  }
}