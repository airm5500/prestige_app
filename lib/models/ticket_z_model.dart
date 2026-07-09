// lib/models/ticket_z_model.dart

class TicketZAmount {
  final String modeLibelle;
  final String montant;

  TicketZAmount({
    required this.modeLibelle,
    required this.montant,
  });

  factory TicketZAmount.fromJson(Map<String, dynamic> json) {
    return TicketZAmount(
      modeLibelle: json['modeLibelle'] ?? '',
      montant: json['montant']?.toString() ?? '0',
    );
  }
}

class TicketZUserData {
  final String user;
  final List<TicketZAmount> modePaymentAmounts;
  final List<TicketZAmount> totaux;

  TicketZUserData({
    required this.user,
    required this.modePaymentAmounts,
    required this.totaux,
  });

  factory TicketZUserData.fromJson(Map<String, dynamic> json) {
    return TicketZUserData(
      user: json['user'] ?? 'Inconnu',
      modePaymentAmounts: (json['modePaymentAmounts'] as List? ?? [])
          .map((e) => TicketZAmount.fromJson(e))
          .toList(),
      totaux: (json['totaux'] as List? ?? [])
          .map((e) => TicketZAmount.fromJson(e))
          .toList(),
    );
  }
}

class TicketZResponse {
  final List<TicketZUserData> datas;
  final List<TicketZAmount> totauxGlobaux;

  TicketZResponse({
    required this.datas,
    required this.totauxGlobaux,
  });

  factory TicketZResponse.fromJson(Map<String, dynamic> json) {
    return TicketZResponse(
      datas: (json['datas'] as List? ?? [])
          .map((e) => TicketZUserData.fromJson(e))
          .toList(),
      totauxGlobaux: (json['totaux'] as List? ?? [])
          .map((e) => TicketZAmount.fromJson(e))
          .toList(),
    );
  }
}