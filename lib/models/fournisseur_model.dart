// lib/models/fournisseur_model.dart


class Fournisseur {
  final String fournisseurId;
  final String fournisseurLibelle;
  final String? adresse;
  final String? groupeId; // Peut être null si non toujours présent
  final String? groupeLibelle; // Peut être null
  final String? telephone; // Peut être null

  Fournisseur({
    required this.fournisseurId,
    required this.fournisseurLibelle,
    this.adresse,
    this.groupeId,
    this.groupeLibelle,
    this.telephone,
  });

  factory Fournisseur.fromJson(Map<String, dynamic> json) {
    return Fournisseur(
      fournisseurId: json['fournisseurId'] as String? ?? '',
      fournisseurLibelle: json['fournisseurLibelle'] as String? ?? 'N/A',
      adresse: json['adresse'] as String?,
      groupeId: json['groupeId'] as String?,
      groupeLibelle: json['groupeLibelle'] as String?,
      telephone: json['telephone'] as String?,
    );
  }

  // Surtout utile pour le débogage
  @override
  String toString() {
    return 'Fournisseur{fournisseurId: $fournisseurId, fournisseurLibelle: $fournisseurLibelle, adresse: $adresse, groupeId: $groupeId, groupeLibelle: $groupeLibelle, telephone: $telephone}';
  }
}
