// lib/interface_version.dart
// Interrupteur « Nouvelle interface » (retour arrière sans réinstaller), même principe que dans
// prestige_vente_app : un ValueNotifier + une clé dans les préférences.
//
// Étape 3 : la nouvelle interface (lib/nouvelle_interface/, charte bleu nuit / ambre) est celle PAR DÉFAUT pour
// tous. L'ancienne reste intacte et disponible : réglage « Nouvelle interface » dans les Réglages (nouvelle
// interface) et dans la Configuration IP (ancienne interface). Le choix est mémorisé sur l'appareil et prend
// effet immédiatement (thème, accueil, écrans de démarrage).
//
// Les écrans qui existent dans les deux versions (connexion, configuration, licence, serveur injoignable,
// démarrage) lisent la version par [InterfaceVersion.nouvelle] : elle vient de [InterfaceScope], posé par
// l'application (main.dart). Sans application autour (écran monté seul par un test), c'est l'ancienne version.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'nouvelle_interface/accueil_nouveau.dart';
import 'nouvelle_interface/presentation.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';

class InterfaceVersion {
  InterfaceVersion._();

  /// Clé des préférences (même nom que dans prestige_vente_app).
  static const cle = 'interface_nouvelle_version_v1';

  /// Valeur tant que le pharmacien n'a rien choisi : nouvelle interface.
  static const parDefaut = true;

  /// Version choisie.
  static final ValueNotifier<bool> useNew = ValueNotifier<bool>(parDefaut);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      useNew.value = prefs.getBool(cle) ?? parDefaut;
    } catch (_) {}
    await PresentationPrefs.charger();
  }

  static Future<void> setNew(bool value) async {
    useNew.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(cle, value);
    } catch (_) {}
  }

  /// Version affichée dans [context] (ancienne si aucun [InterfaceScope] au-dessus).
  static bool nouvelle(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InterfaceScope>()?.nouvelle ?? false;

  /// Écran d'accueil : nouvel accueil si [nouvelle] (par défaut : le choix mémorisé).
  static Widget home({bool? nouvelle}) => (nouvelle ?? useNew.value) ? const AccueilNouveau() : const HomeScreen();

  /// Configuration du serveur : même écran, présenté selon la version de l'interface.
  static Widget settings() => const SettingsScreen();
}

/// Version de l'interface pour tout le sous-arbre (posé par l'application au-dessus du navigateur).
class InterfaceScope extends InheritedWidget {
  final bool nouvelle;
  const InterfaceScope({super.key, required this.nouvelle, required super.child});

  @override
  bool updateShouldNotify(InterfaceScope oldWidget) => oldWidget.nouvelle != nouvelle;
}

/// Réglage « Nouvelle interface », affiché dans les Réglages (nouvelle interface) et la Configuration IP.
class InterfaceVersionTile extends StatelessWidget {
  const InterfaceVersionTile({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: InterfaceVersion.useNew,
        builder: (context, isNew, _) => SwitchListTile(
          key: const Key('interrupteur_nouvelle_interface'),
          title: const Text('Nouvelle interface'),
          subtitle: Text(isNew
              ? 'Désactivez pour revenir à l\'ancienne interface (choix mémorisé sur ce téléphone).'
              : 'Ancienne interface utilisée. Activez pour passer à la nouvelle.'),
          value: isNew,
          onChanged: (v) => InterfaceVersion.setNew(v),
        ),
      );
}
