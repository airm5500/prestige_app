// lib/models/ca_comptant_model.dart

import '../utils/date_formatter.dart';

class CaComptant {
  final double montantCredit; // Même si c'est CA comptant, l'API le retourne
  final DateTime? mvtDate;
  final double remiseSurCA;
  final double totCB; // Carte Bancaire
  final double totChq; // Chèque
  final double totEsp; // Espèces
  final double totMobile; // Mobile Money
  final double totTVA;
  final double totVirement; // Virement

  /// Détail du Mobile Money par opérateur (champ « detailMobile » de /ca-all, PAS ENCORE fourni par le serveur :
  /// voir docs/serveur/DEMANDE_DETAIL_MOBILE_MONEY.md). null = champ absent de la réponse.
  final List<OperateurMobile>? detailMobile;

  CaComptant({
    required this.montantCredit,
    this.mvtDate,
    required this.remiseSurCA,
    required this.totCB,
    required this.totChq,
    required this.totEsp,
    required this.totMobile,
    required this.totTVA,
    required this.totVirement,
    this.detailMobile,
  });

  factory CaComptant.fromJson(Map<String, dynamic> json) {
    return CaComptant(
      montantCredit: (json['montantCredit'] as num?)?.toDouble() ?? 0.0,
      mvtDate: DateFormatter.parseApiDateString(json['mvtDate'] as String?),
      remiseSurCA: (json['remiseSurCA'] as num?)?.toDouble() ?? 0.0,
      totCB: (json['totCB'] as num?)?.toDouble() ?? 0.0,
      totChq: (json['totChq'] as num?)?.toDouble() ?? 0.0,
      totEsp: (json['totEsp'] as num?)?.toDouble() ?? 0.0,
      totMobile: (json['totMobile'] as num?)?.toDouble() ?? 0.0,
      totTVA: (json['totTVA'] as num?)?.toDouble() ?? 0.0,
      totVirement: (json['totVirement'] as num?)?.toDouble() ?? 0.0,
      detailMobile: OperateurMobile.lireListe(json['detailMobile']),
    );
  }

  // Pour le total et le camembert
  double get totalPaiements => totEsp + montantCredit + totMobile + totCB + totChq + totVirement;

  @override
  String toString() {
    return 'CaComptant{mvtDate: ${mvtDate != null ? DateFormatter.toDisplayFormat(mvtDate!) : 'N/A'}, totEsp: $totEsp, totalPaiements: $totalPaiements}';
  }
}

/// Un opérateur Mobile Money (Orange, Wave, MTN…) et son montant. Lecture tolérante : identifiant « modeId » (ou
/// « id »), libellé « libelle » (ou « mode », « str_NAME »), montant en nombre ou en texte (« 12 500 », « 12,5 »).
class OperateurMobile {
  final String modeId;
  final String libelle;
  final double montant;
  const OperateurMobile({required this.modeId, required this.libelle, required this.montant});

  static String _texte(Object? v) {
    if (v == null) return '';
    final t = v.toString().trim();
    return t == 'null' ? '' : t;
  }

  static double montantTolerant(Object? v) {
    if (v is num) return v.isFinite ? v.toDouble() : 0;
    if (v is String) {
      final n = double.tryParse(v.replaceAll(RegExp(r'[\s\u00a0\u202f]'), '').replaceAll(',', '.'));
      return n == null || !n.isFinite ? 0 : n;
    }
    return 0;
  }

  /// null si [j] n'est pas un objet.
  static OperateurMobile? lire(Object? j) {
    if (j is! Map) return null;
    final id = _texte(j['modeId'] ?? j['id'] ?? j['typeReglement']);
    var libelle = _texte(j['libelle'] ?? j['mode'] ?? j['str_NAME'] ?? j['nom']);
    if (libelle.isEmpty) libelle = id.isEmpty ? 'Opérateur inconnu' : 'Opérateur $id';
    return OperateurMobile(modeId: id, libelle: libelle, montant: montantTolerant(j['montant'] ?? j['montantVerse']));
  }

  /// Liste « detailMobile » : null si le champ est absent (ou n'est pas une liste), sinon les opérateurs lisibles.
  static List<OperateurMobile>? lireListe(Object? v) {
    if (v is! List) return null;
    return v.map(lire).whereType<OperateurMobile>().toList();
  }

  @override
  String toString() => 'OperateurMobile($modeId, $libelle, $montant)';
}
