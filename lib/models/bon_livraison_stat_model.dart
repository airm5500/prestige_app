// lib/models/bon_livraison_stat_model.dart

import '../utils/date_formatter.dart';

class BonLivraisonStat {
  final String refLivraison;
  final DateTime? dateLivraison;
  final DateTime? dateSaisie;
  final String fournisseur;

  BonLivraisonStat({
    required this.refLivraison,
    this.dateLivraison,
    this.dateSaisie,
    required this.fournisseur,
  });

  int? get delayInDays {
    if (dateLivraison == null || dateSaisie == null) {
      return null;
    }
    // On ne garde que la partie "jour" de la date pour la différence
    final receptionDay = DateTime(dateLivraison!.year, dateLivraison!.month, dateLivraison!.day);
    final saisieDay = DateTime(dateSaisie!.year, dateSaisie!.month, dateSaisie!.day);
    return saisieDay.difference(receptionDay).inDays;
  }

  String get status {
    final delay = delayInDays;
    if (delay == null) {
      return 'N/A';
    }
    return delay <= 1 ? 'Bon' : 'Pas bon';
  }

  factory BonLivraisonStat.fromJson(Map<String, dynamic> json) {
    return BonLivraisonStat(
      refLivraison: json['strREFLIVRAISON'] as String? ?? 'N/A',
      dateLivraison: DateFormatter.parseDDMMYYYYHHMM(json['dtDATELIVRAISON'] as String?),
      dateSaisie: DateFormatter.parseDDMMYYYYHHMM(json['dtCREATED'] as String?),
      fournisseur: json['fournisseurLibelle'] as String? ?? 'N/A',
    );
  }
}