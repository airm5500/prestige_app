// lib/models/ca_credit_model.dart

import '../utils/date_formatter.dart'; // Pour parser mvtDate

class CaCredit {
  // final String ayantDroitId; // Non affiché, donc optionnel dans le modèle si non utilisé ailleurs
  final String ayantDroitName;
  final String clientId;
  final String clientName;
  final double montant;
  final DateTime? mvtDate;
  final String numFacturation;
  final String tiersPayantId;
  final String tiersPayantLibelle;

  CaCredit({
    // required this.ayantDroitId,
    required this.ayantDroitName,
    required this.clientId,
    required this.clientName,
    required this.montant,
    this.mvtDate,
    required this.numFacturation,
    required this.tiersPayantId,
    required this.tiersPayantLibelle,
  });

  factory CaCredit.fromJson(Map<String, dynamic> json) {
    return CaCredit(
      // ayantDroitId: json['ayantDroitId'] as String? ?? '',
      ayantDroitName: json['ayantDroitName'] as String? ?? 'N/A',
      clientId: json['clientId'] as String? ?? '',
      clientName: json['clientName'] as String? ?? 'N/A',
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      mvtDate: DateFormatter.parseApiDateString(json['mvtDate'] as String?),
      numFacturation: json['numFacturation'] as String? ?? '',
      tiersPayantId: json['tiersPayantId'] as String? ?? '',
      tiersPayantLibelle: json['tiersPayantLibelle'] as String? ?? 'N/A',
    );
  }

  @override
  String toString() {
    return 'CaCredit{clientName: $clientName, montant: $montant, mvtDate: ${mvtDate != null ? DateFormatter.toDisplayFormat(mvtDate!) : 'N/A'}, tiersPayant: $tiersPayantLibelle}';
  }
}
