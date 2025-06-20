// lib/models/achat_fournisseur_model.dart

import '../utils/date_formatter.dart'; // Pour parser mvtDate

class AchatFournisseur {
  final String fournisseurId;
  final String fournisseurLibelle;
  final double montantHT;
  final double montantTTC;
  final double montantTVA;
  final DateTime? mvtDate; // Sera un DateTime après parsing
  final String numeroBL;
  final String numeroCommade;

  AchatFournisseur({
    required this.fournisseurId,
    required this.fournisseurLibelle,
    required this.montantHT,
    required this.montantTTC,
    required this.montantTVA,
    this.mvtDate,
    required this.numeroBL,
    required this.numeroCommade,
  });

  factory AchatFournisseur.fromJson(Map<String, dynamic> json) {
    return AchatFournisseur(
      fournisseurId: json['fournisseurId'] as String? ?? '',
      fournisseurLibelle: json['fournisseurLibelle'] as String? ?? 'N/A',
      montantHT: (json['montantHT'] as num?)?.toDouble() ?? 0.0,
      montantTTC: (json['montantTTC'] as num?)?.toDouble() ?? 0.0,
      montantTVA: (json['montantTVA'] as num?)?.toDouble() ?? 0.0,
      mvtDate: DateFormatter.parseApiDateString(json['mvtDate'] as String?),
      numeroBL: json['numeroBL'] as String? ?? '',
      numeroCommade: json['numeroCommade'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'AchatFournisseur{fournisseurLibelle: $fournisseurLibelle, montantTTC: $montantTTC, mvtDate: ${mvtDate != null ? DateFormatter.toDisplayFormat(mvtDate!) : 'N/A'}}';
  }
}
