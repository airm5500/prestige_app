class RecapCaisseResponse {
  final RecapData data;

  RecapCaisseResponse({required this.data});

  factory RecapCaisseResponse.fromJson(Map<String, dynamic> json) {
    return RecapCaisseResponse(
      data: json['data'] != null
          ? RecapData.fromJson(json['data'])
          : RecapData(datas: [], totaux: []),
    );
  }
}

class RecapData {
  final List<RecapUser> datas;
  final List<RecapAmount> totaux;

  RecapData({required this.datas, required this.totaux});

  factory RecapData.fromJson(Map<String, dynamic> json) {
    return RecapData(
      datas: json['datas'] != null
          ? (json['datas'] as List).map((i) => RecapUser.fromJson(i)).toList()
          : [],
      totaux: json['totaux'] != null
          ? (json['totaux'] as List).map((i) => RecapAmount.fromJson(i)).toList()
          : [],
    );
  }
}

class RecapUser {
  final String user;
  final List<RecapAmount> modePaymentAmounts;
  final List<RecapAmount> totaux;

  RecapUser({
    required this.user,
    required this.modePaymentAmounts,
    required this.totaux,
  });

  factory RecapUser.fromJson(Map<String, dynamic> json) {
    return RecapUser(
      user: json['user'] ?? 'Utilisateur inconnu',
      modePaymentAmounts: json['modePaymentAmounts'] != null
          ? (json['modePaymentAmounts'] as List)
          .map((i) => RecapAmount.fromJson(i))
          .toList()
          : [],
      totaux: json['totaux'] != null
          ? (json['totaux'] as List).map((i) => RecapAmount.fromJson(i)).toList()
          : [],
    );
  }
}

class RecapAmount {
  final String modeLibelle;
  final String montant;

  RecapAmount({required this.modeLibelle, required this.montant});

  factory RecapAmount.fromJson(Map<String, dynamic> json) {
    return RecapAmount(
      modeLibelle: json['modeLibelle'] ?? '',
      montant: json['montant'] ?? '0',
    );
  }
}