// lib/nouvelle_interface/chiffres_du_jour.dart
// Chiffres du jour de l'accueil « A · Tableau de bord » : lus sur les routes EXISTANTES du serveur, celles des
// écrans d'origine (aucune nouvelle route) :
//  - GET /recap/dashboard?dtStart=&dtEnd= (Rapport d'Activité) : CA TTC, marge, crédits du jour ;
//  - GET /rh/presence?jour= (Présences) : présents / prévus et retards.
// Un échec (réseau, droit RH manquant…) n'empêche pas l'accueil : la tuile affiche « — » et la raison.
// Une session expirée (401) ramène à la connexion comme partout (ApiService).
import 'package:flutter/material.dart';

import '../presences/presences_api.dart';
import '../presences/presences_modeles.dart';
import '../presences/presences_reglages.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class ChiffresDuJour {
  final double? ca;
  final double? marge;
  final double? credits;
  final String? erreurVentes;
  final CompteursPresence? equipe;
  final String? erreurEquipe;
  const ChiffresDuJour({this.ca, this.marge, this.credits, this.erreurVentes, this.equipe, this.erreurEquipe});

  /// Marge en % du CA (null si CA nul).
  double? get tauxMarge => ca == null || marge == null || ca == 0 ? null : marge! * 100 / ca!;

  static String _message(Object e) => e is ApiLoadException ? e.message : 'Indisponible';

  static Future<ChiffresDuJour> charger(BuildContext context) async {
    final aujourdhui = DateTime.now();
    final jour = DateFormatter.toApiFormat(aujourdhui);
    double? ca, marge, credits;
    String? erreurVentes;
    CompteursPresence? equipe;
    String? erreurEquipe;

    final ventes = ApiService()
        .get(context, AppConstants.dashboardRecapEndpoint, queryParams: {'dtStart': jour, 'dtEnd': jour})
        .then<void>((r) {
      final d = r is Map ? r['data'] : null;
      if (d is Map) {
        num? n(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
        ca = n(d['montantTTC'])?.toDouble() ?? 0;
        marge = n(d['marge'])?.toDouble() ?? 0;
        credits = n(d['montantCredit'])?.toDouble() ?? 0;
      } else {
        // Aucune vente enregistrée (réponse vide de Prestige).
        ca = 0;
        marge = 0;
        credits = 0;
      }
    }).catchError((Object e) {
      erreurVentes = _message(e);
    });

    final presences = () async {
      try {
        final seuil = await ReglagesPresences.charger();
        if (!context.mounted) return;
        final p = await const PresencesApi().presence(context, aujourdhui);
        equipe = CompteursPresence.de(p.lignes, seuil, HorlogePresences.maintenant());
      } catch (e) {
        erreurEquipe = _message(e);
      }
    }();

    await Future.wait([ventes, presences]);
    return ChiffresDuJour(ca: ca, marge: marge, credits: credits, erreurVentes: erreurVentes, equipe: equipe, erreurEquipe: erreurEquipe);
  }
}
