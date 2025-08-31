// lib/models/suggestion_amount_model.dart

class SuggestionAmount {
  final double montantAchat;
  final double montantVente;

  SuggestionAmount({required this.montantAchat, required this.montantVente});

  factory SuggestionAmount.fromJson(Map<String, dynamic> json) {
    return SuggestionAmount(
      montantAchat: (json['montantAchat'] as num?)?.toDouble() ?? 0.0,
      montantVente: (json['montantVente'] as num?)?.toDouble() ?? 0.0,
    );
  }
}