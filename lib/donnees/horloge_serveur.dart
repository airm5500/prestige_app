// lib/donnees/horloge_serveur.dart
// 3.18.1 — Heure du serveur fausse (serveur Prestige du 24/11, plan/24112026).
//
// Tant que l'heure du serveur est fausse, le serveur refuse toute écriture (HTTP 423, voir ApiLoadException.horloge).
// Il expose, SANS session, `GET /api/v1/horloge/public` → {"etat": "OK" | "BLOQUE" | "REGULARISATION", "serveur":
// "24/11/2026 20:52"}. L'écran de connexion le lit UNE fois (affichage, changement Local / Distant), jamais en boucle :
//  - BLOQUE : bandeau d'information ;
//  - OK, REGULARISATION (écritures permises) : rien ;
//  - serveur ancien (404), autre réponse, page HTML, injoignable, délai, mode démonstration : rien.
// Aucun contournement n'est proposé : seuls l'administrateur ou la tâche Windows du serveur remettent l'heure.
import 'dart:convert';

import '../demo/mode_demo.dart';
import '../services/api_service.dart';

class HorlogeServeur {
  /// « OK », « BLOQUE » ou « REGULARISATION ».
  final String etat;

  /// Heure du serveur telle qu'il l'affiche (« 24/11/2026 20:52 »), vide si absente.
  final String serveur;
  const HorlogeServeur(this.etat, this.serveur);

  static const route = '/horloge/public';
  static const _etats = {'OK', 'BLOQUE', 'REGULARISATION'};

  bool get bloque => etat == 'BLOQUE';

  /// Texte du bandeau (null : rien à afficher).
  String? get message {
    if (!bloque) return null;
    final heure = serveur.isEmpty ? '' : ' (heure du serveur : $serveur)';
    return 'L\'heure du serveur est fausse$heure : le serveur refuse les enregistrements (validations, pointages, '
        'avis…) tant qu\'elle n\'est pas remise. La consultation reste possible.';
  }

  /// Lit l'état de l'horloge du serveur ([baseApi] : « …/api/v1 »). null pour TOUT autre cas que la réponse attendue.
  /// Ne lève jamais ; aucune requête en mode démonstration.
  static Future<HorlogeServeur?> lire(String baseApi, {Duration delai = const Duration(seconds: 5)}) async {
    if (ModeDemo.actif.value || baseApi.isEmpty) return null;
    try {
      final r = await ApiService.client.get(Uri.parse('$baseApi$route')).timeout(delai);
      if (r.statusCode != 200) return null;
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is! Map) return null;
      final etat = d['etat'];
      if (etat is! String || !_etats.contains(etat)) return null;
      final serveur = d['serveur'];
      return HorlogeServeur(etat, serveur is String ? serveur.trim() : '');
    } catch (_) {
      return null;
    }
  }
}
