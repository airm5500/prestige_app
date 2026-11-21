// lib/donnees/routes_serveur.dart
// 3.17.1 — routes ANNONCÉES par le serveur et route de la carte TVA absente, retenues sur l'appareil pour chaque
// serveur (adresse active), afin de ne plus essayer à chaque session une route que le serveur n'a pas.
//
// Contrat serveur (retour du 20/11 sur les demandes 67 et 68, commit serveur 58db6a4e, intégration 63e9c10c, pas
// encore déployé en officine) : GET v1/tableau-bord/version → { success, version, routes: ["tva", "ca-credit"] } :
//  - « tva » : GET v1/tableau-bord/tva existe ;
//  - « ca-credit » : GET v1/ca-credit est paginé (start, limit, query, tiersPayant) et renvoie luLe et
//    tiersPayantsRetenus ;
//  - pas de « routes » : serveur antérieur (le déployé 76aa5fc1, ou le 67/68 initial 8dd9c9be) → mécanisme 3.17.0
//    (un essai de /tableau-bord/tva, repli /api/v3/tvas).
// Aucun appel de plus au premier contact avec un serveur : /tableau-bord/version n'est lue qu'APRÈS un succès de
// /tableau-bord/tva (serveur récent), une fois, en arrière-plan ; sa réponse sert aux sessions suivantes. Un 404 de
// /tableau-bord/tva est retenu [dureeAbsence] : les sessions suivantes de la journée lisent directement /api/v3/tvas
// (⟳ de l'accueil réessaie la route). Rien de nominatif n'est gardé : l'adresse du serveur et des noms de routes.
//
// 3.17.2 — tableau-bord/version exige une session (réponse du serveur du 21/11) : sans session, elle répond 200
// { success: false, msg: <message de déconnexion> }, sans version ni routes. Seule une réponse « success: true » sans
// « routes » signifie « serveur antérieur » (retenu [dureeAbsence]). success false, réponse qui n'est pas un objet,
// « routes » de forme inattendue, erreur réseau, 401, 403, 5xx, délai : réponse INCONNUE, rien n'est enregistré ni
// changé ; la lecture est refaite à la session suivante (après reconnexion), jamais deux fois dans la même session.
// « Veuillez vous connecter » déclenche, comme pour les autres routes du tableau de bord, le retour à la connexion
// (ApiService._handleResponse → surSessionExpiree).
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/ip_config_provider.dart';
import '../services/api_service.dart';

/// État retenu pour un serveur.
@immutable
class EtatRoutes {
  /// Routes annoncées par /tableau-bord/version (null : jamais lues, ou serveur qui n'en annonce pas).
  final Set<String>? annoncees;

  /// Dernière réponse de /tableau-bord/version SANS « routes » (serveur antérieur).
  final DateTime? sansRoutesLe;

  /// Dernier 404 de /tableau-bord/tva.
  final DateTime? tvaAbsenteLe;
  const EtatRoutes({this.annoncees, this.sansRoutesLe, this.tvaAbsenteLe});

  static const vide = EtatRoutes();

  /// Le serveur annonce ses routes et [route] n'en fait pas partie.
  bool nonAnnoncee(String route) => annoncees != null && !annoncees!.contains(route);

  /// Le serveur annonce [route].
  bool annoncee(String route) => annoncees?.contains(route) ?? false;

  /// /tableau-bord/tva a répondu 404 il y a moins de [RoutesServeur.dureeAbsence].
  bool tvaAbsenteRecente(DateTime maintenant) => tvaAbsenteLe != null && maintenant.difference(tvaAbsenteLe!) < RoutesServeur.dureeAbsence;

  /// /tableau-bord/version a répondu sans routes il y a moins de [RoutesServeur.dureeAbsence].
  bool sansRoutesRecent(DateTime maintenant) => sansRoutesLe != null && maintenant.difference(sansRoutesLe!) < RoutesServeur.dureeAbsence;

  Map<String, Object?> versJson() => {
        if (annoncees != null) 'routes': annoncees!.toList()..sort(),
        if (sansRoutesLe != null) 'sansRoutesLe': sansRoutesLe!.millisecondsSinceEpoch,
        if (tvaAbsenteLe != null) 'tvaAbsenteLe': tvaAbsenteLe!.millisecondsSinceEpoch,
      };

  static EtatRoutes deJson(Object? j) {
    if (j is! Map) return vide;
    DateTime? date(Object? v) => v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    final r = j['routes'];
    return EtatRoutes(
      annoncees: r is List ? {for (final x in r) if (x is String) x} : null,
      sansRoutesLe: date(j['sansRoutesLe']),
      tvaAbsenteLe: date(j['tvaAbsenteLe']),
    );
  }
}

/// 3.17.2 : nature d'une réponse de /tableau-bord/version.
enum NatureVersion {
  /// success true avec une liste « routes ».
  annoncees,

  /// success true sans « routes » : serveur antérieur.
  anterieur,

  /// success false (session expirée), réponse qui n'est pas un objet, « routes » illisible : rien n'est conclu.
  inconnue,
}

@immutable
class ReponseVersion {
  final NatureVersion nature;

  /// Routes annoncées (seulement pour [NatureVersion.annoncees]).
  final Set<String>? routes;
  const ReponseVersion.annoncees(Set<String> this.routes) : nature = NatureVersion.annoncees;
  const ReponseVersion.anterieur()
      : nature = NatureVersion.anterieur,
        routes = null;
  const ReponseVersion.inconnue()
      : nature = NatureVersion.inconnue,
        routes = null;
}

class RoutesServeur {
  RoutesServeur._();

  /// Route qui annonce les routes du serveur.
  static const route = '/tableau-bord/version';

  /// Noms annoncés (contrat serveur).
  static const tva = 'tva';
  static const caCredit = 'ca-credit';

  /// Clé des préférences : { « racine du serveur » : EtatRoutes }.
  static const cle = 'routes_serveur_v1';

  /// Durée pendant laquelle un 404 de /tableau-bord/tva (ou une version sans routes) est retenu.
  static const dureeAbsence = Duration(hours: 24);

  /// Horloge (tests).
  static DateTime Function() horloge = DateTime.now;

  /// Serveur actif (racine « http(s)://hôte:port/application » du mode local / distant).
  static String serveur(BuildContext context) => Provider.of<IpConfigProvider>(context, listen: false).racineServeur;

  static Future<Map<String, Object?>> _tout(SharedPreferences p) async {
    try {
      final j = jsonDecode(p.getString(cle) ?? '{}');
      return j is Map ? Map<String, Object?>.from(j) : {};
    } catch (_) {
      return {};
    }
  }

  /// État retenu pour [serveur] (vide si rien, ou préférences illisibles).
  static Future<EtatRoutes> etat(String serveur) async {
    try {
      return EtatRoutes.deJson((await _tout(await SharedPreferences.getInstance()))[serveur]);
    } catch (_) {
      return EtatRoutes.vide;
    }
  }

  static Future<void> _modifier(String serveur, EtatRoutes Function(EtatRoutes e) changer) async {
    try {
      final p = await SharedPreferences.getInstance();
      final tout = await _tout(p);
      final e = changer(EtatRoutes.deJson(tout[serveur]));
      final j = e.versJson();
      if (j.isEmpty) {
        tout.remove(serveur);
      } else {
        tout[serveur] = j;
      }
      await p.setString(cle, jsonEncode(tout));
    } catch (_) {
      // Rien n'est retenu : le mécanisme 3.17.0 (un essai par session) s'applique.
    }
  }

  /// /tableau-bord/tva a répondu 404 (route absente).
  static Future<void> noterTvaAbsente(String serveur) => _modifier(
      serveur, (e) => EtatRoutes(annoncees: e.annoncees?.difference({tva}), sansRoutesLe: e.sansRoutesLe, tvaAbsenteLe: horloge()));

  /// /tableau-bord/tva a répondu : l'absence retenue est oubliée.
  static Future<void> oublierTvaAbsente(String serveur) =>
      _modifier(serveur, (e) => EtatRoutes(annoncees: e.annoncees, sansRoutesLe: e.sansRoutesLe));

  /// Réponse de /tableau-bord/version : la liste « routes » (noms non vides), null sans liste. Ne dit PAS à elle seule
  /// si le serveur est antérieur : voir [lireVersion] (3.17.2).
  static Set<String>? lireRoutes(Object? j) {
    if (j is! Map || j['routes'] is! List) return null;
    return {
      for (final x in j['routes'] as List)
        if (x is String && x.trim().isNotEmpty) x.trim()
    };
  }

  /// 3.17.2 : nature d'une réponse de /tableau-bord/version (voir [ReponseVersion]).
  static ReponseVersion lireVersion(Object? j) {
    if (j is! Map || j['success'] != true) return const ReponseVersion.inconnue();
    if (j['routes'] == null) return const ReponseVersion.anterieur();
    final routes = lireRoutes(j);
    return routes == null ? const ReponseVersion.inconnue() : ReponseVersion.annoncees(routes);
  }

  /// Lectures de /tableau-bord/version de cette session (une seule par source : serveur et session).
  static final _lectures = <String, Future<Set<String>?>>{};

  /// Tests : oublie les lectures de la session.
  static void oublierSession() => _lectures.clear();

  /// GET /tableau-bord/version, une fois par session et par serveur ; une réponse CONNUE est retenue pour [serveur]
  /// (routes annoncées, ou serveur antérieur : success true sans routes). Réponse inconnue (success false — session
  /// expirée —, forme inattendue) ou échec (404, 401, 403, 5xx, réseau, délai) : rien n'est retenu ni changé, null ;
  /// nouvel essai à la session suivante.
  static Future<Set<String>?> lire(BuildContext context, String source, String serveur) {
    return _lectures.putIfAbsent(source, () async {
      try {
        final r = lireVersion(await ApiService().get(context, route));
        final routes = r.routes;
        switch (r.nature) {
          case NatureVersion.inconnue:
            return null;
          case NatureVersion.anterieur:
            await _modifier(serveur, (e) => EtatRoutes(sansRoutesLe: horloge(), tvaAbsenteLe: e.tvaAbsenteLe));
          case NatureVersion.annoncees:
            await _modifier(serveur, (e) => EtatRoutes(annoncees: routes, tvaAbsenteLe: routes!.contains(tva) ? null : e.tvaAbsenteLe));
        }
        return routes;
      } catch (_) {
        return null;
      }
    });
  }
}
