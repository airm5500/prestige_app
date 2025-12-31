// lib/models/suivi_peremption_model.dart

class SuiviPeremptionResponse {
  final PeremptionMetaData metaData;
  final List<PeremptionItem> data;
  final int total;

  SuiviPeremptionResponse({
    required this.metaData,
    required this.data,
    required this.total,
  });

  factory SuiviPeremptionResponse.fromJson(Map<String, dynamic> json) {
    return SuiviPeremptionResponse(
      metaData: PeremptionMetaData.fromJson(json['metaData'] ?? {}),
      data: (json['data'] as List? ?? [])
          .map((item) => PeremptionItem.fromJson(item))
          .toList(),
      total: json['total'] is int ? json['total'] : 0,
    );
  }
}

class PeremptionMetaData {
  final double totalQuantiteLot;
  final double totalValeurAchat;
  final double totalValeurVente;
  final int periode;

  PeremptionMetaData({
    this.totalQuantiteLot = 0,
    this.totalValeurAchat = 0,
    this.totalValeurVente = 0,
    this.periode = 0,
  });

  factory PeremptionMetaData.fromJson(Map<String, dynamic> json) {
    return PeremptionMetaData(
      totalQuantiteLot: _toDouble(json['totalQuantiteLot']),
      totalValeurAchat: _toDouble(json['totalValeurAchat']),
      totalValeurVente: _toDouble(json['totalValeurVente']),
      periode: json['periode'] is int ? json['periode'] : 0,
    );
  }
}

class PeremptionItem {
  final String libelle;
  final String codeCip;
  final String numLot;
  final String datePerement;
  final String statut;
  final double quantiteLot;
  final double valeurAchat;
  final double valeurVente;
  final String libelleRayon;
  final String libelleGrossiste;
  final String libelleFamille;

  PeremptionItem({
    required this.libelle,
    required this.codeCip,
    required this.numLot,
    required this.datePerement,
    required this.statut,
    required this.quantiteLot,
    required this.valeurAchat,
    required this.valeurVente,
    required this.libelleRayon,
    required this.libelleGrossiste,
    required this.libelleFamille,
  });

  factory PeremptionItem.fromJson(Map<String, dynamic> json) {
    return PeremptionItem(
      libelle: json['libelle']?.toString() ?? '',
      codeCip: json['codeCip']?.toString() ?? '',
      numLot: json['numLot']?.toString() ?? '',
      datePerement: json['datePerement']?.toString() ?? '',
      statut: json['statut']?.toString() ?? '',
      quantiteLot: _toDouble(json['quantiteLot']),
      valeurAchat: _toDouble(json['valeurAchat']),
      valeurVente: _toDouble(json['valeurVente']),
      libelleRayon: json['libelleRayon']?.toString() ?? '',
      libelleGrossiste: json['libelleGrossiste']?.toString() ?? '',
      libelleFamille: json['libelleFamille']?.toString() ?? '',
    );
  }
}

// Fonction utilitaire pour la conversion sécurisée
double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is int) return val.toDouble();
  if (val is double) return val;
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}