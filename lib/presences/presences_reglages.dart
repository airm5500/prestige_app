// lib/presences/presences_reglages.dart
// Réglages du pharmacien pour le module « Présences » : seuil de retard (minutes au-delà de l'heure prévue avant
// de marquer « En retard »). 60 min par défaut, de 0 à 480 min. Rangé dans les préférences du téléphone (ce n'est
// pas un secret) ; n'influe que sur l'AFFICHAGE (le serveur garde sa propre tolérance pour ses calculs et exports).
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReglagesPresences {
  ReglagesPresences._();

  static const cleSeuil = 'presences_seuil_retard_min';
  static const seuilParDefaut = 60;
  static const seuilMin = 0;
  static const seuilMax = 480;

  /// Seuil courant (mis à jour par [charger] et [enregistrerSeuil]).
  static final ValueNotifier<int> seuil = ValueNotifier<int>(seuilParDefaut);

  static Future<int> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(cleSeuil);
      seuil.value = v == null || v < seuilMin || v > seuilMax ? seuilParDefaut : v;
    } catch (_) {
      seuil.value = seuilParDefaut;
    }
    return seuil.value;
  }

  /// Motif de refus de la saisie, ou null si elle est correcte.
  static String? erreurSeuil(String? texte) {
    final t = (texte ?? '').trim();
    if (t.isEmpty) return 'Le seuil est requis.';
    final v = int.tryParse(t);
    if (v == null || v < seuilMin || v > seuilMax) return 'Valeur invalide ($seuilMin à $seuilMax minutes).';
    return null;
  }

  /// Enregistre le seuil (refusé hors bornes).
  static Future<bool> enregistrerSeuil(int minutes) async {
    if (minutes < seuilMin || minutes > seuilMax) return false;
    seuil.value = minutes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(cleSeuil, minutes);
    } catch (_) {}
    return true;
  }
}
