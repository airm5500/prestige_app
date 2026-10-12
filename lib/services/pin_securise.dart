// lib/services/pin_securise.dart
// Codes PIN jamais gardés en clair : empreinte salée PBKDF2-HMAC-SHA256 (RFC 8018), 120 000 itérations,
// sel aléatoire de 16 octets (Random.secure) tiré sur l'appareil pour chaque code, comparaison en temps constant.
//
// - [EmpreintePin] : calcul / vérification d'une empreinte (« pbkdf2-sha256$iter$sel$hash », base64).
//   Sert au PIN administrateur ([CodeAdmin]).
// - [CodeAdmin] : PIN administrateur, qui protège la configuration du serveur ouverte SANS être connecté
//   (écran de connexion, licence, serveur injoignable). Une fois connecté, le pharmacien a tous les droits
//   (pas de code). Empreinte dans le stockage sécurisé Android (flutter_secure_storage, même schéma que
//   [IdentifiantsSecurises]). Copie de prestige_vente_app : l'application du pharmacien n'avait aucun code ;
//   la clé en clair `admin_pin_code` n'est donc lue que par sécurité (migration : empreinte écrite, relue,
//   vérifiée, puis clé en clair SUPPRIMÉE).
//   Stockage sûr en échec : ancien fonctionnement conservé (clé en clair) et nouvel essai au prochain accès.
//   Anti-force brute : après 5 erreurs, attente progressive (30 s, 1 min, 5 min, 15 min, 30 min, 1 h)
//   gardée dans les préférences (compteur et échéance, aucun code).
//   PIN par défaut « 1234 » : accepté une seule fois pour ouvrir le changement obligatoire du code.
//
// SHA-256 implémenté ici (aucune dépendance ajoutée) : états HMAC intérieur / extérieur précalculés,
// 2 compressions par itération sans allocation. Vérifié par les vecteurs de test RFC 7914 / hashlib.
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journal_app.dart';
import 'stockage_securise.dart';

// ---------------------------------------------------------------------------
// PBKDF2-HMAC-SHA256
// ---------------------------------------------------------------------------

class Pbkdf2Sha256 {
  Pbkdf2Sha256._();

  static const _m = 0xFFFFFFFF;

  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static const List<int> _h0 = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];

  static int _rotr(int x, int n) => ((x >>> n) | (x << (32 - n))) & _m;

  /// Compresse le bloc w[0..15] dans l'état h (w est utilisé comme tableau de travail de 64 mots).
  static void _compresser(Uint32List h, Uint32List w) {
    for (var t = 16; t < 64; t++) {
      final x = w[t - 15], y = w[t - 2];
      final s0 = _rotr(x, 7) ^ _rotr(x, 18) ^ (x >>> 3);
      final s1 = _rotr(y, 17) ^ _rotr(y, 19) ^ (y >>> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & _m;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var t = 0; t < 64; t++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ ((~e & _m) & g);
      final t1 = (hh + s1 + ch + _k[t] + w[t]) & _m;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & _m;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & _m;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _m;
    }
    h[0] = (h[0] + a) & _m;
    h[1] = (h[1] + b) & _m;
    h[2] = (h[2] + c) & _m;
    h[3] = (h[3] + d) & _m;
    h[4] = (h[4] + e) & _m;
    h[5] = (h[5] + f) & _m;
    h[6] = (h[6] + g) & _m;
    h[7] = (h[7] + hh) & _m;
  }

  /// Hache [data] en partant de l'état [etat] après [dejaTraites] octets (multiple de 64).
  static Uint32List _hacherDepuis(List<int> etat, int dejaTraites, List<int> data) {
    final h = Uint32List.fromList(etat);
    final total = dejaTraites + data.length;
    final longueur = ((data.length + 9 + 63) ~/ 64) * 64;
    final buf = Uint8List(longueur)..setAll(0, data);
    buf[data.length] = 0x80;
    final bits = total * 8;
    for (var i = 0; i < 8; i++) {
      buf[longueur - 1 - i] = (bits >> (8 * i)) & 0xFF;
    }
    final w = Uint32List(64);
    for (var off = 0; off < longueur; off += 64) {
      for (var i = 0; i < 16; i++) {
        final p = off + i * 4;
        w[i] = (buf[p] << 24) | (buf[p + 1] << 16) | (buf[p + 2] << 8) | buf[p + 3];
      }
      _compresser(h, w);
    }
    return h;
  }

  static Uint8List _octets(Uint32List mots) {
    final out = Uint8List(mots.length * 4);
    for (var i = 0; i < mots.length; i++) {
      out[i * 4] = (mots[i] >>> 24) & 0xFF;
      out[i * 4 + 1] = (mots[i] >>> 16) & 0xFF;
      out[i * 4 + 2] = (mots[i] >>> 8) & 0xFF;
      out[i * 4 + 3] = mots[i] & 0xFF;
    }
    return out;
  }

  /// SHA-256 (utilitaire, et clés HMAC de plus de 64 octets).
  static Uint8List sha256(List<int> data) => _octets(_hacherDepuis(_h0, 0, data));

  /// Clé dérivée PBKDF2-HMAC-SHA256 de [longueur] octets.
  static Uint8List deriver(List<int> secret, List<int> sel, int iterations, int longueur) {
    if (iterations < 1 || longueur < 1) throw ArgumentError('itérations et longueur doivent être positives');
    var cle = secret.length > 64 ? sha256(secret) : secret;
    final k0 = Uint8List(64)..setAll(0, cle);
    // États après le bloc ipad / opad (précalculés une fois).
    final interieur = Uint32List.fromList(_h0);
    final exterieur = Uint32List.fromList(_h0);
    final w = Uint32List(64);
    for (final (etat, pad) in [(interieur, 0x36), (exterieur, 0x5c)]) {
      for (var i = 0; i < 16; i++) {
        w[i] = ((k0[i * 4] ^ pad) << 24) | ((k0[i * 4 + 1] ^ pad) << 16) | ((k0[i * 4 + 2] ^ pad) << 8) | (k0[i * 4 + 3] ^ pad);
      }
      _compresser(etat, w);
    }
    cle = const [];

    final out = Uint8List(longueur);
    final blocs = (longueur + 31) ~/ 32;
    final u = Uint32List(8);
    final t = Uint32List(8);
    final h = Uint32List(8);
    for (var bloc = 1; bloc <= blocs; bloc++) {
      // U1 = HMAC(P, S || INT(bloc))
      final message = [...sel, (bloc >>> 24) & 0xFF, (bloc >>> 16) & 0xFF, (bloc >>> 8) & 0xFF, bloc & 0xFF];
      final dedans = _hacherDepuis(interieur, 64, message);
      final u1 = _hacherDepuis(exterieur, 64, _octets(dedans));
      u.setAll(0, u1);
      t.setAll(0, u1);
      // Itérations suivantes : message de 32 octets = un seul bloc, rembourrage fixe (96 octets au total).
      for (var j = 1; j < iterations; j++) {
        h.setAll(0, interieur);
        w.setAll(0, u);
        w[8] = 0x80000000;
        for (var i = 9; i < 15; i++) {
          w[i] = 0;
        }
        w[15] = (64 + 32) * 8;
        _compresser(h, w);
        w.setAll(0, h);
        w[8] = 0x80000000;
        for (var i = 9; i < 15; i++) {
          w[i] = 0;
        }
        w[15] = (64 + 32) * 8;
        h.setAll(0, exterieur);
        _compresser(h, w);
        for (var i = 0; i < 8; i++) {
          u[i] = h[i];
          t[i] ^= h[i];
        }
      }
      final octets = _octets(t);
      final debut = (bloc - 1) * 32;
      for (var i = 0; i < 32 && debut + i < longueur; i++) {
        out[debut + i] = octets[i];
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// Empreinte d'un code PIN
// ---------------------------------------------------------------------------

class EmpreintePin {
  EmpreintePin._();

  static const prefixe = 'pbkdf2-sha256';
  static const iterationsParDefaut = 120000;
  static const longueurSel = 16;
  static const longueurHash = 32;

  /// Bornes acceptées à la lecture (empreinte abîmée ou forgée : refusée sans calcul démesuré).
  static const _iterationsMax = 5000000;

  static final Random _alea = Random.secure();

  /// Empreinte salée de [pin] : « pbkdf2-sha256$<itérations>$<sel base64>$<hash base64> ».
  static String creer(String pin, {int iterations = iterationsParDefaut, Random? alea}) {
    final r = alea ?? _alea;
    final sel = Uint8List.fromList(List.generate(longueurSel, (_) => r.nextInt(256)));
    final hash = Pbkdf2Sha256.deriver(utf8.encode(pin), sel, iterations, longueurHash);
    return '$prefixe\$$iterations\$${base64Encode(sel)}\$${base64Encode(hash)}';
  }

  /// La valeur est une empreinte (et non un ancien code en clair).
  static bool estEmpreinte(String? v) => v != null && v.startsWith('$prefixe\$');

  /// Vérifie [saisie] contre une empreinte. Empreinte illisible : `false`.
  static bool verifier(String saisie, String empreinte) {
    final p = empreinte.split('\$');
    if (p.length != 4 || p[0] != prefixe) return false;
    final iterations = int.tryParse(p[1]);
    if (iterations == null || iterations < 1 || iterations > _iterationsMax) return false;
    final Uint8List sel, attendu;
    try {
      sel = base64Decode(p[2]);
      attendu = base64Decode(p[3]);
    } catch (_) {
      return false;
    }
    if (attendu.isEmpty || attendu.length > 64) return false;
    final calcule = Pbkdf2Sha256.deriver(utf8.encode(saisie), sel, iterations, attendu.length);
    return egauxTempsConstant(calcule, attendu);
  }

  /// Vérifie [saisie] contre une valeur gardée : empreinte, ou ancien code en clair (migration en cours,
  /// stockage en mémoire des tests). Comparaison en temps constant dans les deux cas.
  static bool correspond(String saisie, String? garde) {
    if (garde == null || garde.isEmpty) return false;
    if (estEmpreinte(garde)) return verifier(saisie, garde);
    return egauxTempsConstant(utf8.encode(saisie), utf8.encode(garde));
  }

  /// Empreinte de la valeur gardée (inchangée si c'est déjà une empreinte).
  static String securiser(String garde) => estEmpreinte(garde) ? garde : creer(garde);

  /// Comparaison dont la durée ne dépend pas de la position de la première différence.
  static bool egauxTempsConstant(List<int> a, List<int> b) {
    final n = max(a.length, b.length);
    var diff = a.length ^ b.length;
    for (var i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      diff |= x ^ y;
    }
    return diff == 0;
  }
}

// ---------------------------------------------------------------------------
// Règles d'un nouveau PIN administrateur
// ---------------------------------------------------------------------------

class ReglesPin {
  ReglesPin._();

  static const longueurMin = 4;
  static const longueurMax = 8;

  /// Motif de refus d'un nouveau PIN, ou `null` s'il est accepté.
  static String? refus(String pin) {
    if (!RegExp('^\\d{$longueurMin,$longueurMax}\$').hasMatch(pin)) {
      return 'Le code doit compter de $longueurMin à $longueurMax chiffres.';
    }
    if (pin == CodeAdmin.codeParDefaut) return 'Le code par défaut n\'est pas autorisé.';
    if (pin.split('').toSet().length == 1) return 'Code trop simple (chiffres tous identiques).';
    final d = pin.codeUnits.map((c) => c - 48).toList();
    bool suite(int pas) {
      for (var i = 1; i < d.length; i++) {
        if (d[i] != (d[i - 1] + pas) % 10) return false;
      }
      return true;
    }

    if (suite(1) || suite(-1 + 10)) return 'Code trop simple (suite de chiffres).';
    // Motif répété (1212, 123123, 2580 2580…).
    for (var l = 1; l <= pin.length ~/ 2; l++) {
      if (pin.length % l == 0 && pin == pin.substring(0, l) * (pin.length ~/ l)) {
        return 'Code trop simple (motif répété).';
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// PIN administrateur
// ---------------------------------------------------------------------------

/// Résultat d'une vérification du PIN administrateur.
enum VerificationPin {
  /// Code correct.
  accepte,

  /// Code par défaut correct : n'ouvre que le changement obligatoire du code.
  changementObligatoire,

  /// Code incorrect.
  refuse,

  /// Trop d'erreurs : attente en cours (voir [CodeAdmin.attenteRestante]).
  bloque,

  /// Stockage sécurisé illisible : impossible de vérifier.
  indisponible,
}

class CodeAdmin {
  /// Ancienne clé en clair (SharedPreferences) : lue seulement pour la migration / le repli.
  static const cleClaire = 'admin_pin_code';

  /// Clé de l'empreinte dans le stockage sécurisé.
  static const cleSure = 'admin_pin_empreinte_v1';

  /// Compteur d'erreurs et fin de l'attente (préférences : aucun code).
  static const cleEchecs = 'admin_pin_echecs_v1';
  static const cleBlocage = 'admin_pin_blocage_v1';

  static const codeParDefaut = '1234';

  /// Erreurs tolérées avant la première attente.
  static const erreursAvantAttente = 5;

  /// Attentes successives (la dernière se répète).
  static const attentes = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
  ];

  static const delai = Duration(seconds: 5);

  final CoffreIdentifiants coffre;
  final DateTime Function() horloge;

  /// Itérations PBKDF2 des nouvelles empreintes (réduites seulement dans certains tests).
  final int iterations;

  CodeAdmin({CoffreIdentifiants? coffre, DateTime Function()? horloge, int? iterations})
      : coffre = coffre ?? const CoffreIdentifiantsSecurise(),
        horloge = horloge ?? DateTime.now,
        iterations = iterations ?? EmpreintePin.iterationsParDefaut;

  /// Instance de l'appli (remplaçable dans les tests).
  static CodeAdmin instance = CodeAdmin();

  bool _migre = false;
  Future<bool>? _migrationEnCours;

  /// Migre l'ancien PIN en clair vers une empreinte du stockage sûr. Renvoie `true` si plus aucun PIN
  /// n'est en clair. N'échoue jamais (échec : clé en clair gardée, échec journalisé, nouvel essai plus tard).
  Future<bool> migrer() {
    if (_migre) return Future.value(true);
    return _migrationEnCours ??= _migrer().whenComplete(() => _migrationEnCours = null);
  }

  Future<bool> _migrer() async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return false;
    }
    final clair = prefs.getString(cleClaire);
    if (clair == null) {
      _migre = true;
      return true;
    }
    if (!await _ecrireEmpreinte(clair, 'Migration du code administrateur vers le stockage sécurisé')) return false;
    await prefs.remove(cleClaire);
    _migre = true;
    _noter('Code administrateur déplacé dans le stockage sécurisé (empreinte)', null);
    return true;
  }

  /// Écrit l'empreinte de [pin], la relit et la vérifie. `false` si le stockage sûr a échoué.
  Future<bool> _ecrireEmpreinte(String pin, String action) async {
    try {
      final empreinte = EmpreintePin.creer(pin, iterations: iterations);
      await coffre.ecrire(cleSure, empreinte).timeout(delai);
      final relu = await coffre.lire(cleSure).timeout(delai);
      if (relu != empreinte || !EmpreintePin.verifier(pin, relu!)) throw const _RelectureDifferente();
      return true;
    } catch (e) {
      _noterEchec(action, e);
      return false;
    }
  }

  /// Temps d'attente restant avant un nouvel essai (`null` si aucun).
  Future<Duration?> attenteRestante() async {
    try {
      final fin = (await SharedPreferences.getInstance()).getInt(cleBlocage);
      if (fin == null) return null;
      final reste = DateTime.fromMillisecondsSinceEpoch(fin).difference(horloge());
      return reste > Duration.zero ? reste : null;
    } catch (_) {
      return null;
    }
  }

  /// Vérifie le PIN saisi (anti-force brute compris).
  Future<VerificationPin> verifier(String saisie) async {
    if (await attenteRestante() != null) return VerificationPin.bloque;
    await migrer();
    final prefs = await SharedPreferences.getInstance();
    bool ok;
    // Clé en clair encore présente = stockage sûr en échec : c'est elle la référence.
    final clair = prefs.getString(cleClaire);
    if (clair != null) {
      ok = EmpreintePin.correspond(saisie, clair);
    } else {
      String? empreinte;
      try {
        empreinte = await coffre.lire(cleSure).timeout(delai);
      } catch (e) {
        _noterEchec('Lecture du code administrateur', e);
        return VerificationPin.indisponible;
      }
      ok = empreinte == null
          ? EmpreintePin.egauxTempsConstant(utf8.encode(saisie), utf8.encode(codeParDefaut))
          : EmpreintePin.verifier(saisie, empreinte);
    }
    if (!ok) {
      await _echec(prefs);
      return await attenteRestante() != null ? VerificationPin.bloque : VerificationPin.refuse;
    }
    await prefs.remove(cleEchecs);
    await prefs.remove(cleBlocage);
    return saisie == codeParDefaut ? VerificationPin.changementObligatoire : VerificationPin.accepte;
  }

  Future<void> _echec(SharedPreferences prefs) async {
    final n = (prefs.getInt(cleEchecs) ?? 0) + 1;
    await prefs.setInt(cleEchecs, n);
    if (n >= erreursAvantAttente) {
      final attente = attentes[min(n - erreursAvantAttente, attentes.length - 1)];
      await prefs.setInt(cleBlocage, horloge().add(attente).millisecondsSinceEpoch);
      _noter('Code administrateur : $n erreurs', 'attente de ${formaterAttente(attente)}');
    }
  }

  /// Enregistre un nouveau PIN (règles de [ReglesPin]). Renvoie le motif de refus, ou `null` si enregistré.
  /// Stockage sûr en échec : ancien fonctionnement conservé pour cette fois (clé en clair), migration
  /// au prochain accès.
  Future<String?> definir(String nouveau) async {
    final motif = ReglesPin.refus(nouveau);
    if (motif != null) return motif;
    final prefs = await SharedPreferences.getInstance();
    if (await _ecrireEmpreinte(nouveau, 'Enregistrement du code administrateur')) {
      await prefs.remove(cleClaire);
      _migre = true;
    } else {
      await prefs.setString(cleClaire, nouveau);
      _migre = false;
    }
    await prefs.remove(cleEchecs);
    await prefs.remove(cleBlocage);
    _noter('Code administrateur modifié', null);
    return null;
  }

  static String formaterAttente(Duration d) {
    if (d.inMinutes >= 60) return '${d.inHours} h';
    if (d.inSeconds > 60) {
      final m = (d.inSeconds / 60).ceil();
      return '$m min';
    }
    return d.inSeconds == 60 ? '1 min' : '${d.inSeconds} s';
  }

  void _noter(String action, String? motif) => JournalApp.debug(motif == null ? action : '$action — $motif');

  void _noterEchec(String action, Object e) {
    final motif = e is PlatformException
        ? 'stockage sécurisé indisponible (${e.code})'
        : e is _RelectureDifferente
            ? 'relecture du stockage sécurisé différente'
            : e is TimeoutException
                ? 'stockage sécurisé : délai dépassé'
                : 'stockage sécurisé indisponible (${e.runtimeType})';
    _noter(action, '$motif ; ancien comportement conservé, nouvel essai plus tard');
  }
}

class _RelectureDifferente implements Exception {
  const _RelectureDifferente();
}
