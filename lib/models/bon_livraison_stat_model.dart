// lib/models/bon_livraison_stat_model.dart

import '../utils/date_formatter.dart';

class BonLivraisonStat {
  final String refLivraison;
  final DateTime? dateLivraison;
  final DateTime? dateSaisie;
  final String fournisseur;

  /// 3.11.0 : clôture du BL (« entrée en stock ») = dtUPDATED, posé par le serveur à la clôture
  /// (closureBonlivraison / cloturerBonLivraison) ; [statut] = strSTATUT (« is_Closed » une fois clôturé).
  final DateTime? dateCloture;
  final String statut;

  BonLivraisonStat({
    required this.refLivraison,
    this.dateLivraison,
    this.dateSaisie,
    required this.fournisseur,
    this.dateCloture,
    this.statut = '',
  });

  /// Durée maximale retenue pour un temps de saisie : au-delà, le BL est resté ouvert (pause, reprise le lendemain)
  /// et sa durée ne mesure plus la saisie.
  static const dureeSaisieMax = Duration(hours: 24);

  /// Temps de saisie du BL : de sa création (dtCREATED) à sa clôture (dtUPDATED), BL clôturés seulement ; null si une
  /// date manque, si le BL n'est pas clôturé ou si la durée est négative.
  Duration? get tempsSaisie {
    if (statut != 'is_Closed' || dateSaisie == null || dateCloture == null) return null;
    final d = dateCloture!.difference(dateSaisie!);
    return d.isNegative ? null : d;
  }

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
      dateCloture: DateFormatter.parseDDMMYYYYHHMM(json['dtUPDATED'] is String ? json['dtUPDATED'] as String : null),
      statut: json['strSTATUT'] is String ? json['strSTATUT'] as String : '',
    );
  }
}