// lib/models/vente_stat_model.dart

import '../utils/date_formatter.dart';

class VenteStat {
  final String strREFTICKET;
  final bool cancel;
  final String lgPREENREGISTREMENTID;
  final String strTYPEVENTE;
  final String strSTATUT;
  final bool avoir;
  final double intPRICE;
  final String HEUREVENTE;
  final String userVendeurName;
  final String dtCREATED;
  final String strREF;

  VenteStat({
    required this.strREFTICKET,
    required this.cancel,
    required this.lgPREENREGISTREMENTID,
    required this.strTYPEVENTE,
    required this.strSTATUT,
    required this.avoir,
    required this.intPRICE,
    required this.HEUREVENTE,
    required this.userVendeurName,
    required this.dtCREATED,
    required this.strREF,
  });

  factory VenteStat.fromJson(Map<String, dynamic> json) {
    return VenteStat(
      strREFTICKET: json['strREFTICKET'] as String? ?? '',
      cancel: json['cancel'] as bool? ?? false,
      lgPREENREGISTREMENTID: json['lgPREENREGISTREMENTID'] as String? ?? '',
      strTYPEVENTE: json['strTYPEVENTE'] as String? ?? '',
      strSTATUT: json['strSTATUT'] as String? ?? '',
      avoir: json['avoir'] as bool? ?? false,
      intPRICE: (json['intPRICE'] as num?)?.toDouble() ?? 0.0,
      HEUREVENTE: json['HEUREVENTE'] as String? ?? '',
      userVendeurName: json['userVendeurName'] as String? ?? 'N/A',
      dtCREATED: json['dtCREATED'] as String? ?? '',
      strREF: json['strREF'] as String? ?? '',
    );
  }
}
