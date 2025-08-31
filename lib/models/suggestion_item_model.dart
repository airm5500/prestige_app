// lib/models/suggestion_item_model.dart

class SuggestionItem {
  final String itemId;
  final String cip;
  final String name;
  final int prixVente;
  final int prixAchat;
  final int stock;
  int quantiteSuggeree;
  final int consoM0;
  final int consoM1;
  final int consoM2;
  final int consoM3;

  SuggestionItem({
    required this.itemId,
    required this.cip,
    required this.name,
    required this.prixVente,
    required this.prixAchat,
    required this.stock,
    required this.quantiteSuggeree,
    required this.consoM0,
    required this.consoM1,
    required this.consoM2,
    required this.consoM3,
  });

  // AJOUT: Getter pour la moyenne
  double get averageConsumption => (consoM1 + consoM2 + consoM3) / 3.0;

  factory SuggestionItem.fromJson(Map<String, dynamic> json) {
    return SuggestionItem(
      itemId: json['lg_SUGGESTION_ORDER_DETAILS_ID'] as String? ?? '',
      cip: json['str_FAMILLE_CIP'] as String? ?? '',
      name: json['str_FAMILLE_NAME'] as String? ?? 'N/A',
      prixVente: (json['int_VENTE'] as num?)?.toInt() ?? 0,
      prixAchat: (json['int_ACHAT'] as num?)?.toInt() ?? 0,
      stock: (json['int_STOCK'] as num?)?.toInt() ?? 0,
      quantiteSuggeree: (json['int_NUMBER'] as num?)?.toInt() ?? 0,
      consoM0: (json['int_VALUE0'] as num?)?.toInt() ?? 0,
      consoM1: (json['int_VALUE1'] as num?)?.toInt() ?? 0,
      consoM2: (json['int_VALUE2'] as num?)?.toInt() ?? 0,
      consoM3: (json['int_VALUE3'] as num?)?.toInt() ?? 0,
    );
  }
}