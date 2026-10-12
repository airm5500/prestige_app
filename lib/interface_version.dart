// lib/interface_version.dart
// Interrupteur « Nouvelle interface » (retour arrière sans réinstaller), même principe que dans
// prestige_vente_app : un ValueNotifier + une clé dans les préférences.
//
// Étape 0 : l'interrupteur est en place mais la nouvelle interface n'existe pas encore (étape 3) :
// les deux positions ouvrent les écrans d'origine, INCHANGÉS. Valeur par défaut : `false` (ancienne
// interface) ; elle passera à `true` quand la nouvelle interface sera validée par le pharmacien.
// Le réglage [InterfaceVersionTile] sera ajouté dans la Configuration (ancienne et nouvelle) à l'étape 3 ;
// il n'est pas affiché aujourd'hui pour ne pas proposer un bouton sans effet.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

class InterfaceVersion {
  InterfaceVersion._();

  /// Clé des préférences (même nom que dans prestige_vente_app).
  static const cle = 'interface_nouvelle_version_v1';

  /// Valeur tant que le pharmacien n'a rien choisi.
  static const parDefaut = false;

  /// Version choisie.
  static final ValueNotifier<bool> useNew = ValueNotifier<bool>(parDefaut);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      useNew.value = prefs.getBool(cle) ?? parDefaut;
    } catch (_) {}
  }

  static Future<void> setNew(bool value) async {
    useNew.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(cle, value);
    } catch (_) {}
  }

  /// Écran d'accueil (étape 3 : nouvel accueil quand [useNew] est vrai).
  static Widget home() => const HomeScreen();

  /// Configuration du serveur (étape 3 : nouveaux réglages quand [useNew] est vrai).
  static Widget settings() => const SettingsScreen();
}

/// Réglage à afficher dans la Configuration (ancienne et nouvelle) à partir de l'étape 3.
class InterfaceVersionTile extends StatelessWidget {
  const InterfaceVersionTile({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: InterfaceVersion.useNew,
        builder: (context, isNew, _) => SwitchListTile(
          title: const Text('Nouvelle interface'),
          subtitle: Text(isNew
              ? 'Désactivez pour revenir à l\'accueil et à la configuration d\'origine (effet au prochain retour à l\'accueil).'
              : 'Accueil et configuration d\'origine utilisés.'),
          value: isNew,
          onChanged: (v) => InterfaceVersion.setNew(v),
        ),
      );
}
