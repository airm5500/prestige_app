// lib/models/retour_fournisseur_model.dart

import '../utils/date_formatter.dart';

class RetourFournisseur {
  final double montantRetour;
  final bool btnDelete;
  final String strGrossisteLibelle;
  final DateTime? dtCreated;
  final DateTime? dtDate;
  final String strRefLivraison;
  final String lgGrossisteId;
  final String strReponseFrs;
  final String strFamilleItem;
  final String lgUserId;
  final String lgBonLivraisonId;
  final String strStatut;
  final String lgRetourFrsId;
  final bool closed;
  final String dateBl;
  final String strCommentaire;
  final int intLine;
  final String lgUserId2;
  final String strRefRetourFrs;

  RetourFournisseur({
    required this.montantRetour,
    required this.btnDelete,
    required this.strGrossisteLibelle,
    this.dtCreated,
    this.dtDate,
    required this.strRefLivraison,
    required this.lgGrossisteId,
    required this.strReponseFrs,
    required this.strFamilleItem,
    required this.lgUserId,
    required this.lgBonLivraisonId,
    required this.strStatut,
    required this.lgRetourFrsId,
    required this.closed,
    required this.dateBl,
    required this.strCommentaire,
    required this.intLine,
    required this.lgUserId2,
    required this.strRefRetourFrs,
  });

  factory RetourFournisseur.fromJson(Map<String, dynamic> json) {
    return RetourFournisseur(
      montantRetour: (json['MONTANTRETOUR'] as num?)?.toDouble() ?? 0.0,
      btnDelete: json['BTNDELETE'] as bool? ?? false,
      strGrossisteLibelle: json['str_GROSSISTE_LIBELLE'] as String? ?? 'N/A',
      dtCreated: DateFormatter.parseDDMMYYYY(json['dt_CREATED'] as String?),
      dtDate: DateFormatter.parseDDMMYYYY(json['dt_DATE'] as String?),
      strRefLivraison: json['str_REF_LIVRAISON'] as String? ?? '',
      lgGrossisteId: json['lg_GROSSISTE_ID'] as String? ?? '',
      strReponseFrs: json['str_REPONSE_FRS'] as String? ?? '',
      strFamilleItem: json['str_FAMILLE_ITEM'] as String? ?? '',
      lgUserId: json['lg_USER_ID'] as String? ?? '',
      lgBonLivraisonId: json['lg_BON_LIVRAISON_ID'] as String? ?? '',
      strStatut: json['str_STATUT'] as String? ?? '',
      lgRetourFrsId: json['lg_RETOUR_FRS_ID'] as String? ?? '',
      closed: json['closed'] as bool? ?? false,
      dateBl: json['DATEBL'] as String? ?? '',
      strCommentaire: json['str_COMMENTAIRE'] as String? ?? '',
      intLine: json['int_LINE'] as int? ?? 0,
      lgUserId2: json['lgUSERID'] as String? ?? '',
      strRefRetourFrs: json['str_REF_RETOUR_FRS'] as String? ?? '',
    );
  }
}