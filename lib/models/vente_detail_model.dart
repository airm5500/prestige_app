// lib/models/vente_detail_model.dart

class VenteDetail {
  final String strREF;
  final String typeVente;
  final String vendeur;
  final double intPRICE;
  final List<VenteItem> items;

  VenteDetail({
    required this.strREF,
    required this.typeVente,
    required this.vendeur,
    required this.intPRICE,
    required this.items,
  });

  factory VenteDetail.fromJson(Map<String, dynamic> json) {
    var itemsList = <VenteItem>[];
    if (json['items'] is List) {
      itemsList = (json['items'] as List)
          .map((itemJson) => VenteItem.fromJson(itemJson))
          .toList();
    }

    return VenteDetail(
      strREF: json['strREF'] as String? ?? 'N/A',
      typeVente: (json['typeVente'] as Map<String, dynamic>?)?['libelle'] as String? ?? 'N/A',
      vendeur: (json['vendeur'] as Map<String, dynamic>?)?['fullName'] as String? ?? 'N/A',
      intPRICE: (json['intPRICE'] as num?)?.toDouble() ?? 0.0,
      items: itemsList,
    );
  }
}

class VenteItem {
  final String strDESCRIPTION;
  final int intQUANTITY;
  final double intPRICEUNITAIR;
  final double intPRICE;

  VenteItem({
    required this.strDESCRIPTION,
    required this.intQUANTITY,
    required this.intPRICEUNITAIR,
    required this.intPRICE,
  });

  factory VenteItem.fromJson(Map<String, dynamic> json) {
    final produit = json['produit'] as Map<String, dynamic>?;
    return VenteItem(
      strDESCRIPTION: produit?['strDESCRIPTION'] as String? ?? 'N/A',
      intQUANTITY: (json['intQUANTITY'] as num?)?.toInt() ?? 0,
      intPRICEUNITAIR: (json['intPRICEUNITAIR'] as num?)?.toDouble() ?? 0.0,
      intPRICE: (json['intPRICE'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
