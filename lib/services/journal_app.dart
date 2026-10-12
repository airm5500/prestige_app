// lib/services/journal_app.dart
// Journal technique de l'application (logcat). Règles :
// - rien n'est écrit dans une version release (seulement en debug, `kDebugMode`) ;
// - jamais de secret : mot de passe, cookie de session, code PIN, clé de licence ;
// - jamais d'URL complète avec ses paramètres ni de réponse brute du serveur.
import 'package:flutter/foundation.dart';

class JournalApp {
  JournalApp._();

  /// Remplaçable dans les tests pour capturer ce qui serait écrit.
  static void Function(String message) sortie = _sortieParDefaut;

  /// Faux dans les tests pour simuler une version release.
  static bool actif = kDebugMode;

  static void _sortieParDefaut(String m) => debugPrint(m);

  /// Note un message technique court (debug uniquement), après masquage des secrets.
  static void debug(String message) {
    if (!actif) return;
    sortie(masquer(message));
  }

  static final _motifs = <RegExp>[
    // Paramètres d'URL : tout ce qui suit « ? » est retiré.
    RegExp(r'\?[^\s]*'),
    // Cookie de session (JSESSIONID=…), en-têtes Cookie / Set-Cookie.
    RegExp(r'JSESSIONID=[^;\s]*', caseSensitive: false),
    RegExp(r'(set-)?cookie\s*[:=]\s*[^\s,]*', caseSensitive: false),
    // Champs sensibles d'un corps JSON ou d'un formulaire.
    RegExp(r'''["']?(password|motdepasse|mot_de_passe|pwd|pin|licence|cle|key)["']?\s*[:=]\s*["']?[^"',}\s]*''', caseSensitive: false),
    // Chemin de l'enregistrement de licence : la clé fait partie de l'URL.
    RegExp(r'/licence/save/[^\s?]*', caseSensitive: false),
  ];

  /// Retire d'un texte tout ce qui pourrait être un secret ou une donnée de l'officine.
  static String masquer(String texte) {
    var t = texte;
    for (final m in _motifs) {
      t = t.replaceAllMapped(m, (x) {
        final s = x.group(0)!;
        if (s.startsWith('?')) return '?…';
        if (s.toLowerCase().startsWith('/licence/save/')) return '/licence/save/***';
        final i = s.indexOf(RegExp(r'[:=]'));
        return i < 0 ? '***' : '${s.substring(0, i + 1)}***';
      });
    }
    return t;
  }

  /// Décrit une adresse sans ses paramètres : « GET /common/rayons ».
  static String requete(String methode, Uri uri) {
    final chemin = uri.path;
    final i = chemin.indexOf('/api/');
    return '$methode ${i >= 0 ? chemin.substring(i) : chemin}';
  }
}
