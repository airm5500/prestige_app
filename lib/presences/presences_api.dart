// lib/presences/presences_api.dart
// Appels du module « Présences » : routes RH EXISTANTES de Prestige (RhRessource.java, @Path("v1/rh")), avec la
// session cookie de l'application. Aucune modification du serveur.
//
// Règles d'erreur (mêmes que l'étape 1, via ApiService) : serveur injoignable / trop lent / erreur 5xx / session
// expirée (retour à la connexion) / réponse illisible ; en plus :
//  - droit manquant : Prestige répond 200 {success:false, msg:"Vous n'avez pas accès aux ressources humaines."}
//    → NatureErreur.droit avec un message clair (droit P_SM_RH) ;
//  - route absente (404) : « non disponible sur cette version du serveur » ;
//  - exports : Prestige répond 401 aussi bien sans session que sans droit → on vérifie /rh/droits pour
//    distinguer (session expirée → reconnexion ; droit manquant → message).
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'presences_modeles.dart';

class PresencesApi {
  const PresencesApi();

  static const messageDroit =
      'Accès refusé : ce compte n\'a pas le droit « Ressources humaines » (P_SM_RH) dans Prestige. '
      'Demandez à l\'administrateur de l\'ajouter à votre profil.';
  static const messageNonDisponible =
      'Fonction non disponible sur cette version du serveur Prestige (module RH absent). Mettez Prestige à jour.';

  /// Les échecs d'ApiService, précisés pour le module.
  static ApiLoadException _preciser(ApiLoadException e) {
    if (e.nature == NatureErreur.refus && e.code == 404) {
      return const ApiLoadException(messageNonDisponible, nature: NatureErreur.refus, code: 404);
    }
    if (e.nature == NatureErreur.droit) return const ApiLoadException(messageDroit, nature: NatureErreur.droit, code: 403);
    return e;
  }

  /// Réponse JSON {success:true,…} ; refus de Prestige (success:false) → exception avec le message du serveur.
  static Map<String, dynamic> _objet(dynamic r) {
    if (r == null) return <String, dynamic>{};
    if (r is! Map) throw const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse);
    final m = Map<String, dynamic>.from(r);
    if (m['success'] == false) {
      final msg = '${m['msg'] ?? m['message'] ?? ''}'.trim();
      if (msg.toLowerCase().contains('ressources humaines')) {
        throw const ApiLoadException(messageDroit, nature: NatureErreur.droit, code: 200);
      }
      throw ApiLoadException(msg.isEmpty ? 'Le serveur a refusé la demande.' : msg, nature: NatureErreur.refus, code: 200);
    }
    return m;
  }

  static List<Map<String, dynamic>> _liste(Object? data, String quoi) {
    if (data == null) return const [];
    if (data is! List) throw ApiLoadException('Réponse inattendue du serveur pour $quoi.', nature: NatureErreur.reponse);
    try {
      return [for (final e in data) Map<String, dynamic>.from(e as Map)];
    } catch (_) {
      throw ApiLoadException('Données illisibles ($quoi).', nature: NatureErreur.reponse);
    }
  }

  static Future<T> _appel<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on ApiLoadException catch (e) {
      throw _preciser(e);
    }
  }

  /// GET /rh/presence?jour=AAAA-MM-JJ.
  Future<PresenceDuJour> presence(BuildContext context, DateTime jour) => _appel(() async {
        final r = _objet(await ApiService().get(context, '/rh/presence', queryParams: {'jour': jourCle(jour)}));
        try {
          return PresenceDuJour(
            jour: jourSeul(jour),
            lignes: [for (final e in _liste(r['data'], 'la présence')) PresenceJour.fromJson(e)],
            pointages: [for (final e in _liste(r['pointages'], 'les pointages')) PointageJour.fromJson(e)],
          );
        } on ApiLoadException {
          rethrow;
        } catch (_) {
          throw const ApiLoadException('Données de présence illisibles.', nature: NatureErreur.reponse);
        }
      });

  /// GET /rh/tableau?du=&au=[&employeId=] (période déjà bornée à 366 jours).
  Future<TableauPeriode> tableau(BuildContext context, PeriodePresence periode, {String? employeId}) => _appel(() async {
        final r = _objet(await ApiService().get(context, '/rh/tableau', queryParams: {
          ...periode.parametres,
          if (employeId != null && employeId.isNotEmpty) 'employeId': employeId,
        }));
        DateTime lire(Object? v, DateTime defaut) => DateTime.tryParse('${v ?? ''}') ?? defaut;
        return TableauPeriode(
          du: lire(r['du'], periode.du),
          au: lire(r['au'], periode.au),
          lignes: [for (final e in _liste(r['data'], 'le tableau')) TableauLigne.fromJson(e)],
        );
      });

  /// Export du tableau : Excel (résumé ou détaillé, une ligne par employé et par jour) ou PDF.
  Future<FichierTelecharge> exporter(BuildContext context, PeriodePresence periode, FormatExport format, {String? employeId}) =>
      _appel(() async {
        final api = ApiService();
        final params = {
          ...periode.parametres,
          if (employeId != null && employeId.isNotEmpty) 'employeId': employeId,
          if (format == FormatExport.excelDetaille) 'detail': 'true',
        };
        final suffixe = '${jourCle(periode.du)}_${jourCle(periode.au)}';
        try {
          final f = await api.getBytes(context, format == FormatExport.pdf ? '/rh/tableau/pdf' : '/rh/tableau/excel',
              queryParams: params, nomParDefaut: format.nomParDefaut, ambigu401: true);
          // Nom explicite (le serveur renvoie toujours le même nom) : « presences_2026-10-01_2026-10-13.xlsx ».
          return FichierTelecharge(f.octets, '${format.prefixe}_$suffixe.${format.extension}', f.type);
        } on ApiLoadException catch (e) {
          if (e.code != 401 || e.nature != NatureErreur.refus || !context.mounted) rethrow;
          // 401 ambigu : session expirée (droits → « Veuillez vous connecter » → reconnexion) ou droit manquant.
          _objet(await api.get(context, '/rh/droits'));
          rethrow;
        }
      });

  /// GET /rh/mobile/code : QR de pointage du moment.
  Future<CodePointageMoment> codePointage(BuildContext context) => _appel(() async {
        final r = _objet(await ApiService().get(context, '/rh/mobile/code'));
        final c = CodePointageMoment.fromJson(r);
        if (c.code.isEmpty) throw const ApiLoadException('Le serveur n\'a pas renvoyé de code.', nature: NatureErreur.reponse);
        return c;
      });

  /// GET /rh/mobile/terminaux.
  Future<List<TerminalMobile>> terminaux(BuildContext context) => _appel(() async {
        final r = _objet(await ApiService().get(context, '/rh/mobile/terminaux'));
        return [for (final e in _liste(r['data'], 'les téléphones')) TerminalMobile.fromJson(e)];
      });

  /// POST /rh/mobile/terminaux/{id}/retirer|reactiver → message du serveur.
  Future<String> changerTerminal(BuildContext context, String id, {required bool reactiver}) => _appel(() async {
        final r = _objet(await ApiService().post(context, '/rh/mobile/terminaux/${Uri.encodeComponent(id)}/${reactiver ? 'reactiver' : 'retirer'}', {}));
        final m = '${r['message'] ?? r['msg'] ?? ''}'.trim();
        return m.isNotEmpty ? m : (reactiver ? 'Téléphone réactivé.' : 'Téléphone retiré.');
      });
}

/// Formats d'export du tableau.
enum FormatExport { excel, excelDetaille, pdf }

extension FormatExportInfo on FormatExport {
  String get libelle => switch (this) {
        FormatExport.excel => 'Excel',
        FormatExport.excelDetaille => 'Excel détaillé',
        FormatExport.pdf => 'PDF',
      };
  String get extension => this == FormatExport.pdf ? 'pdf' : 'xlsx';
  String get prefixe => switch (this) {
        FormatExport.excel => 'tableau_presences',
        FormatExport.excelDetaille => 'presences_detail',
        FormatExport.pdf => 'tableau_presences',
      };
  String get nomParDefaut => '$prefixe.$extension';
  String get typeMime => this == FormatExport.pdf ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
}
