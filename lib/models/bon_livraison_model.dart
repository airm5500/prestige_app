// lib/models/bon_livraison_model.dart

class BonLivraisonModel {
  final String id;
  final String refLivraison;
  final String dateLivraison;
  final String dateEntree;
  final String fournisseurLibelle;
  final String userFullName;
  final String statut;
  final double montantHT;
  final double montantTVA;
  final double montantTTC;
  final List<BonLivraisonDetail> details;

  BonLivraisonModel({
    required this.id,
    required this.refLivraison,
    required this.dateLivraison,
    required this.dateEntree,
    required this.fournisseurLibelle,
    required this.userFullName,
    required this.statut,
    required this.montantHT,
    required this.montantTVA,
    required this.montantTTC,
    required this.details,
  });

  factory BonLivraisonModel.fromJson(Map<String, dynamic> json) {
    return BonLivraisonModel(
      id: json['lgBONLIVRAISONID']?.toString() ?? '',
      refLivraison: json['strREFLIVRAISON']?.toString() ?? '',
      dateLivraison: json['dtDATELIVRAISON']?.toString() ?? '',
      dateEntree: json['dtUPDATED']?.toString() ?? '',
      fournisseurLibelle: json['fournisseurLibelle']?.toString() ?? '',
      userFullName: json['user'] != null ? json['user']['fullName'] ?? '' : '',
      statut: json['checked']?.toString() ?? '',
      montantHT: _toDouble(json['intMHT']),
      montantTVA: _toDouble(json['intTVA']),
      montantTTC: _toDouble(json['intHTTC']),
      details: (json['bonLivraisonDetails'] as List? ?? [])
          .map((e) => BonLivraisonDetail.fromJson(e))
          .toList(),
    );
  }
}

class BonLivraisonDetail {
  final String cip;
  final String designation;
  final int qteRecue;
  final int qteCmde;
  final int qteGratuite;
  final double prixAchat;
  final double prixVente;
  final int initStock;
  final int qteControle;
  final bool checked;

  BonLivraisonDetail({
    required this.cip,
    required this.designation,
    required this.qteRecue,
    required this.qteCmde,
    required this.qteGratuite,
    required this.prixAchat,
    required this.prixVente,
    required this.initStock,
    required this.qteControle,
    required this.checked,
  });

  factory BonLivraisonDetail.fromJson(Map<String, dynamic> json) {
    final produit = json['produit'] ?? {};
    return BonLivraisonDetail(
      cip: produit['intCIP']?.toString() ?? '',
      designation: produit['strDESCRIPTION']?.toString() ?? '',
      qteRecue: _toInt(json['intQTERECUE']),
      qteCmde: _toInt(json['intQTECMDE']),
      qteGratuite: _toInt(json['intQTEUG']),
      prixAchat: _toDouble(json['intPAF']),
      prixVente: _toDouble(json['intPRIXVENTE']),
      initStock: _toInt(json['intINITSTOCK']),
      qteControle: _toInt(json['quantiteControle']),
      checked: json['checked'] == true,
    );
  }

  // Calcul du stock théorique
  int get stockTheorique => initStock + qteRecue;

  // Calcul de l'écart (Stock Théo - Qte Controlée)
  int get ecart => stockTheorique - qteControle;
}

double _toDouble(dynamic val) {
  if (val == null) return 0.0;
  if (val is int) return val.toDouble();
  if (val is double) return val;
  if (val is String) return double.tryParse(val) ?? 0.0;
  return 0.0;
}

int _toInt(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is String) return int.tryParse(val) ?? 0;
  return 0;
}