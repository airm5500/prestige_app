// lib/donnees/fichier_journal_donnees.dart
// Fichier Journal (actions des utilisateurs, LECTURE SEULE), logique COMMUNE aux deux interfaces :
//  - opérations (filtre) : GET /common/log-filtres → « data » (strDESCRIPTION, order) ;
//  - utilisateurs (filtre) : GET /common/users (sans paramètre, comme l'écran d'origine) → « data » (fullName, lgUSERID) ;
//  - journal : GET /common/logs?dtStart=&dtEnd=&criteria=&userId=&limit=200 → « data » (criteria : « order » de
//    l'opération, -1 = toutes ; userId vide = tous). L'écran d'ORIGINE demande 200 actions au plus (inchangé).
//  - nouvelle interface (3.6.1) : mêmes filtres, pages de 50 (start=0, 50, 100… & limit=50). Le serveur Prestige
//    pagine (LogServiceImpl : setFirstResult(start) / setMaxResults(limit)) et rend « total » (nombre d'actions
//    correspondant aux filtres). Réponse sans « total » = serveur qui ne pagine pas : l'application affiche ce
//    qu'elle a reçu, 50 par 50, sans autre requête, et prévient que d'autres actions peuvent manquer.
import 'package:flutter/widgets.dart';

import '../models/fichier_journal_model.dart';
import '../models/log_filtre_model.dart';
import '../models/log_user_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/date_formatter.dart';

class JournalDonnees {
  JournalDonnees._();

  /// Nombre maximal d'actions demandées (valeur d'origine).
  static const limite = 200;

  static Map<String, String> parametres({required DateTime debut, required DateTime fin, LogFiltre? operation, LogUser? utilisateur}) => {
        'dtStart': DateFormatter.toApiFormat(debut),
        'dtEnd': DateFormatter.toApiFormat(fin),
        'criteria': operation?.order.toString() ?? '-1',
        'userId': utilisateur?.lgUserID ?? '',
        'limit': '$limite',
      };

  /// Actions demandées par page dans la nouvelle interface.
  static const taillePage = 50;

  /// Paramètres d'une page (nouvelle interface) : mêmes filtres que [parametres], `start` et `limit=50`.
  static Map<String, String> parametresPage({required DateTime debut, required DateTime fin, LogFiltre? operation, LogUser? utilisateur, required int start}) => {
        ...parametres(debut: debut, fin: fin, operation: operation, utilisateur: utilisateur)..remove('limit'),
        'start': '$start',
        'limit': '$taillePage',
      };

  /// Page lue : actions et « total » du serveur (null si le serveur ne l'indique pas). Réponse illisible : null.
  static PageJournal? lirePage(dynamic data) {
    final actions = lireActions(data);
    if (actions == null) return null;
    final t = (data as Map)['total'];
    final total = t is num ? t.toInt() : (t is String ? int.tryParse(t.trim()) : null);
    return PageJournal(actions, total == null || total < 0 ? null : total);
  }

  static Future<PageJournal> page(BuildContext context,
          {required DateTime debut, required DateTime fin, LogFiltre? operation, LogUser? utilisateur, required int start, VoidCallback? onSessionInvalid}) async =>
      lirePage(await ApiService().get(context, AppConstants.fichierJournalEndpoint,
          queryParams: parametresPage(debut: debut, fin: fin, operation: operation, utilisateur: utilisateur, start: start),
          onSessionInvalid: onSessionInvalid)) ??
      const PageJournal([], 0);

  static List<T>? _data<T>(dynamic data, T Function(Map<String, dynamic>) lire) =>
      data is Map && data['data'] is List ? (data['data'] as List).map((i) => lire(Map<String, dynamic>.from(i as Map))).toList() : null;

  static List<LogFiltre>? lireOperations(dynamic data) => _data(data, LogFiltre.fromJson);
  static List<LogUser>? lireUtilisateurs(dynamic data) => _data(data, LogUser.fromJson);
  static List<FichierJournal>? lireActions(dynamic data) => _data(data, FichierJournal.fromJson);

  static Future<List<LogFiltre>?> operations(BuildContext context, {VoidCallback? onSessionInvalid}) async =>
      lireOperations(await ApiService().get(context, AppConstants.logFiltresEndpoint, onSessionInvalid: onSessionInvalid));

  static Future<List<LogUser>?> utilisateurs(BuildContext context, {VoidCallback? onSessionInvalid}) async =>
      lireUtilisateurs(await ApiService().get(context, AppConstants.logUsersEndpoint, onSessionInvalid: onSessionInvalid));

  static Future<List<FichierJournal>?> actions(BuildContext context,
          {required DateTime debut, required DateTime fin, LogFiltre? operation, LogUser? utilisateur, VoidCallback? onSessionInvalid}) async =>
      lireActions(await ApiService().get(context, AppConstants.fichierJournalEndpoint,
          queryParams: parametres(debut: debut, fin: fin, operation: operation, utilisateur: utilisateur), onSessionInvalid: onSessionInvalid));

  /// Recherche LOCALE (nouvelle interface, aucune requête) : description, type d'action ou utilisateur.
  static List<FichierJournal> filtrer(List<FichierJournal> actions, String recherche) {
    final q = recherche.toLowerCase();
    if (q.isEmpty) return actions;
    return [
      for (final a in actions)
        if (a.description.toLowerCase().contains(q) || a.typeLog.toLowerCase().contains(q) || a.userFullName.toLowerCase().contains(q)) a,
    ];
  }
}

/// Une page du journal : [actions] reçues et [total] annoncé par le serveur (null : serveur sans pagination).
class PageJournal {
  final List<FichierJournal> actions;
  final int? total;
  const PageJournal(this.actions, this.total);

  /// Le serveur pagine-t-il (total annoncé) ?
  bool get paginee => total != null;
}
