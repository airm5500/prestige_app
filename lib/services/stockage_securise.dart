// lib/services/stockage_securise.dart
// Secrets mémorisés sur le téléphone, gardés dans le stockage sécurisé d'Android
// (flutter_secure_storage, chiffré par le Keystore, exclu des sauvegardes — res/xml/regles_*.xml)
// et non plus en clair dans SharedPreferences. Même règle que prestige_vente_app
// (lib/services/identifiants_securises.dart) :
//
// - [IdentifiantsSecurises.instance] : mot de passe de « Rester connecté » (ancienne clé `saved_password`) ;
// - [CookieSecurise.instance] : cookie de session JSESSIONID (ancienne clé `session_cookie`).
//
// MIGRATION transparente : si l'ancienne clé en clair existe, elle est copiée dans le stockage sûr,
// la copie est relue et vérifiée, puis la clé en clair est SUPPRIMÉE. Si le stockage sûr échoue
// (Keystore indisponible, exception, délai), on garde l'ancien comportement (clé en clair) pour ne rien
// perdre, et on réessaie au lancement suivant. Chaque échec est noté dans le journal de debug —
// jamais la valeur.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'journal_app.dart';

/// Stockage sûr d'une valeur (remplaçable dans les tests pour simuler une panne du Keystore).
abstract class CoffreIdentifiants {
  Future<String?> lire(String cle);
  Future<void> ecrire(String cle, String valeur);
  Future<void> effacer(String cle);
}

/// Stockage sécurisé Android (Keystore) via flutter_secure_storage.
class CoffreIdentifiantsSecurise implements CoffreIdentifiants {
  final FlutterSecureStorage _s;
  const CoffreIdentifiantsSecurise([this._s = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true))]);

  @override
  Future<String?> lire(String cle) => _s.read(key: cle);
  @override
  Future<void> ecrire(String cle, String valeur) => _s.write(key: cle, value: valeur);
  @override
  Future<void> effacer(String cle) => _s.delete(key: cle);
}

/// Un secret mémorisé : stockage sûr, migration de l'ancienne clé en clair, repli sans perte.
class SecretMemorise {
  /// Nom lisible (journal).
  final String nom;

  /// Ancienne clé, en clair dans SharedPreferences (lue seulement pour la migration / le repli).
  final String cleClaire;

  /// Clé dans le stockage sécurisé.
  final String cleSure;

  final CoffreIdentifiants coffre;

  /// Délai au-delà duquel une opération du stockage sûr est considérée en échec.
  static const delai = Duration(seconds: 5);

  SecretMemorise({required this.nom, required this.cleClaire, required this.cleSure, CoffreIdentifiants? coffre})
      : coffre = coffre ?? const CoffreIdentifiantsSecurise();

  /// Migration déjà réussie (ou rien à migrer) pendant ce lancement.
  bool _migre = false;
  Future<bool>? _migrationEnCours;

  /// Migre l'ancienne clé en clair vers le stockage sûr. Renvoie `true` si plus rien n'est en clair.
  /// N'échoue jamais (en cas d'échec, l'ancienne clé est gardée et l'échec journalisé).
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
    try {
      await coffre.ecrire(cleSure, clair).timeout(delai);
      final relu = await coffre.lire(cleSure).timeout(delai);
      if (relu != clair) throw const _RelectureDifferente();
    } catch (e) {
      _noterEchec('Migration du $nom vers le stockage sécurisé', e);
      return false;
    }
    await prefs.remove(cleClaire);
    _migre = true;
    JournalApp.debug('Stockage sécurisé : $nom déplacé (ancienne clé en clair supprimée)');
    return true;
  }

  /// Valeur mémorisée, ou `null` s'il n'y en a pas.
  Future<String?> lire() async {
    await migrer();
    // Clé en clair encore présente = stockage sûr en échec : c'est elle la plus récente.
    try {
      final clair = (await SharedPreferences.getInstance()).getString(cleClaire);
      if (clair != null) return clair;
    } catch (_) {}
    try {
      return await coffre.lire(cleSure).timeout(delai);
    } catch (e) {
      _noterEchec('Lecture du $nom', e);
      return null;
    }
  }

  /// Mémorise la valeur (stockage sûr ; repli en clair si le stockage sûr échoue).
  Future<void> ecrire(String valeur) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await coffre.ecrire(cleSure, valeur).timeout(delai);
      final relu = await coffre.lire(cleSure).timeout(delai);
      if (relu != valeur) throw const _RelectureDifferente();
    } catch (e) {
      _noterEchec('Enregistrement du $nom', e);
      // Ancien comportement gardé pour cette fois ; la migration le déplacera au lancement suivant.
      await prefs.setString(cleClaire, valeur);
      _migre = false;
      return;
    }
    await prefs.remove(cleClaire);
  }

  /// Oublie la valeur partout (stockage sûr ET ancienne clé en clair).
  Future<void> effacer() async {
    try {
      await (await SharedPreferences.getInstance()).remove(cleClaire);
    } catch (_) {}
    try {
      await coffre.effacer(cleSure).timeout(delai);
    } catch (e) {
      _noterEchec('Effacement du $nom', e);
    }
  }

  void _noterEchec(String action, Object e) {
    // Seul le TYPE d'erreur est noté : un message d'exception peut contenir la valeur.
    final motif = e is PlatformException
        ? 'stockage sécurisé indisponible (${e.code})'
        : e is _RelectureDifferente
            ? 'relecture du stockage sécurisé différente'
            : e is TimeoutException
                ? 'stockage sécurisé : délai dépassé'
                : 'stockage sécurisé indisponible (${e.runtimeType})';
    JournalApp.debug('Stockage sécurisé : $action — $motif ; ancien comportement conservé, nouvel essai au prochain lancement');
  }
}

class _RelectureDifferente implements Exception {
  const _RelectureDifferente();
}

/// Mot de passe de « Rester connecté ».
class IdentifiantsSecurises {
  IdentifiantsSecurises._();
  static const cleClaire = 'saved_password';
  static const cleSure = 'connexion_mot_de_passe_v1';

  /// Instance de l'appli (remplaçable dans les tests).
  static SecretMemorise instance = creer();

  static SecretMemorise creer({CoffreIdentifiants? coffre}) =>
      SecretMemorise(nom: 'mot de passe mémorisé', cleClaire: cleClaire, cleSure: cleSure, coffre: coffre);
}

/// Cookie de session (JSESSIONID) renvoyé au serveur à chaque requête.
class CookieSecurise {
  CookieSecurise._();
  static const cleClaire = 'session_cookie';
  static const cleSure = 'session_cookie_v1';

  /// Instance de l'appli (remplaçable dans les tests).
  static SecretMemorise instance = creer();

  static SecretMemorise creer({CoffreIdentifiants? coffre}) =>
      SecretMemorise(nom: 'cookie de session', cleClaire: cleClaire, cleSure: cleSure, coffre: coffre);
}
