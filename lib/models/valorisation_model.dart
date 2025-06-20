// lib/models/valorisation_model.dart

class ValorisationStock {
  final double valeurAchat;
  final double valeurVente;

  ValorisationStock({
    required this.valeurAchat,
    required this.valeurVente,
  });

  factory ValorisationStock.fromJson(Map<String, dynamic> json) {
    return ValorisationStock(
      valeurAchat: (json['valeurAchat'] as num?)?.toDouble() ?? 0.0,
      valeurVente: (json['valeurVente'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'ValorisationStock{valeurAchat: $valeurAchat, valeurVente: $valeurVente}';
  }
}
