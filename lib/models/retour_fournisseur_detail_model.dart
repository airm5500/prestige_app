// lib/models/retour_fournisseur_detail_model.dart

import '../utils/date_formatter.dart';

class RetourFournisseurDetail {
  final String heure;
  final DateTime? dateOperation;
  final DateTime? dtCreated;
  final int ecart;
  final String intCIP;
  final int intNUMBERANSWER;
  final int intNUMBERRETURN;
  final int intSTOCK;
  final String lgRETOURFRSDETAIL;
  final String lgRETOURFRSID;
  final String motif;
  final String operateur;
  final int prixPaf;
  final String produitId;
  final int qtyMvt;
  final String referenceBl;
  final String strCOMMENTAIRE;
  final String strLIBELLE;
  final String strNAME;
  final String strREFRETOURFRS;

  RetourFournisseurDetail({
    required this.heure,
    this.dateOperation,
    this.dtCreated,
    required this.ecart,
    required this.intCIP,
    required this.intNUMBERANSWER,
    required this.intNUMBERRETURN,
    required this.intSTOCK,
    required this.lgRETOURFRSDETAIL,
    required this.lgRETOURFRSID,
    required this.motif,
    required this.operateur,
    required this.prixPaf,
    required this.produitId,
    required this.qtyMvt,
    required this.referenceBl,
    required this.strCOMMENTAIRE,
    required this.strLIBELLE,
    required this.strNAME,
    required this.strREFRETOURFRS,
  });

  factory RetourFournisseurDetail.fromJson(Map<String, dynamic> json) {
    return RetourFournisseurDetail(
      heure: json['HEURE'] as String? ?? '',
      dateOperation: DateFormatter.parseIsoDateTime(json['dateOperation'] as String?),
      dtCreated: DateFormatter.parseDDMMYYYY(json['dtCREATED'] as String?),
      ecart: json['ecart'] as int? ?? 0,
      intCIP: json['intCIP'] as String? ?? '',
      intNUMBERANSWER: json['intNUMBERANSWER'] as int? ?? 0,
      intNUMBERRETURN: json['intNUMBERRETURN'] as int? ?? 0,
      intSTOCK: json['intSTOCK'] as int? ?? 0,
      lgRETOURFRSDETAIL: json['lgRETOURFRSDETAIL'] as String? ?? '',
      lgRETOURFRSID: json['lgRETOURFRSID'] as String? ?? '',
      motif: json['motif'] as String? ?? '',
      operateur: json['operateur'] as String? ?? '',
      prixPaf: json['prixPaf'] as int? ?? 0,
      produitId: json['produitId'] as String? ?? '',
      qtyMvt: json['qtyMvt'] as int? ?? 0,
      referenceBl: json['referenceBl'] as String? ?? '',
      strCOMMENTAIRE: json['strCOMMENTAIRE'] as String? ?? '',
      strLIBELLE: json['strLIBELLE'] as String? ?? 'N/A',
      strNAME: json['strNAME'] as String? ?? 'N/A',
      strREFRETOURFRS: json['strREFRETOURFRS'] as String? ?? '',
    );
  }
}