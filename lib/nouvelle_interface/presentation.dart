// lib/nouvelle_interface/presentation.dart
// Présentation de la nouvelle interface (docs/ANALYSE_PRESTIGE_APP.md §4, recommandation) :
//   A · Tableau de bord (par défaut sur téléphone), B · Compact (automatiquement sur tablette : menu latéral et
//   deux colonnes), C · Guidé (en option).
// 3.11.0 (décision du pharmacien) : le TABLEAU DE BORD (vague4/tableau_bord_vague4.dart, inspiré de celui de
// Prestige web) devient l'accueil par défaut de TOUS les appareils : à la première ouverture de la 3.11.0, le choix
// passe une fois au tableau de bord (migration [PresentationPrefs.cleMigration]) ; A, B, C et « Automatique » restent
// proposés dans les Réglages et un choix fait ensuite est gardé.
// Le choix est un réglage d'apparence MÉMORISÉ sur l'appareil, valable pour tous les comptes qui s'y connectent.
// Comme dans prestige_vente_app, seul l'administrateur le change : compte « admin » directement, tout autre compte
// doit saisir le code administrateur (le même que celui qui protège la configuration du serveur).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../widgets/pin_code_dialog.dart';

enum Presentation { tableauPrestige, automatique, tableauDeBord, compact, guide }

extension PresentationTextes on Presentation {
  String get lettre => switch (this) {
        Presentation.tableauPrestige => 'TB',
        Presentation.automatique => 'Auto',
        Presentation.tableauDeBord => 'A',
        Presentation.compact => 'B',
        Presentation.guide => 'C',
      };

  String get libelle => switch (this) {
        Presentation.tableauPrestige => 'Tableau de bord',
        Presentation.automatique => 'Automatique',
        Presentation.tableauDeBord => 'A · Chiffres du jour et menus',
        Presentation.compact => 'B · Compact',
        Presentation.guide => 'C · Guidé',
      };

  String get description => switch (this) {
        Presentation.tableauPrestige => 'Comme Prestige : chiffres du jour, évolution, fréquentation, valorisation… (par défaut)',
        Presentation.automatique => 'A sur téléphone, B sur tablette',
        Presentation.tableauDeBord => 'Chiffres du jour, alertes, menus par familles',
        Presentation.compact => 'Listes denses avec recherche ; menu latéral sur tablette',
        Presentation.guide => 'Cinq questions simples, gros boutons',
      };
}

/// Largeur (dp, côté le plus court) à partir de laquelle l'appareil est une tablette.
const largeurTabletteDp = 600.0;

bool estTabletteNouvelle(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= largeurTabletteDp;

class PresentationPrefs {
  PresentationPrefs._();

  /// Clé des préférences (appareil).
  static const cle = 'presentation_accueil_v1';

  /// Migration de la 3.11.0 : présente (vraie) une fois le tableau de bord installé comme accueil.
  static const cleMigration = 'presentation_tableau_bord_3_11_0';

  /// Présentation par défaut (appareil sans choix) : le tableau de bord.
  static const parDefaut = Presentation.tableauPrestige;

  static final ValueNotifier<Presentation> choix = ValueNotifier<Presentation>(parDefaut);

  static Future<Presentation> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(cleMigration) != true) {
        // Première ouverture de la 3.11.0 : le tableau de bord devient l'accueil, quel que soit le choix précédent
        // (décision du pharmacien) ; un choix fait ensuite dans les Réglages est respecté.
        await prefs.setString(cle, parDefaut.name);
        await prefs.setBool(cleMigration, true);
      }
      choix.value = Presentation.values.asNameMap()[prefs.getString(cle)] ?? parDefaut;
    } catch (_) {
      choix.value = parDefaut;
    }
    return choix.value;
  }

  static Future<void> enregistrer(Presentation p) async {
    choix.value = p;
    try {
      await (await SharedPreferences.getInstance()).setString(cle, p.name);
    } catch (_) {}
  }

  /// Présentation réellement affichée : « Automatique » → B sur tablette, A sur téléphone.
  static Presentation effective(Presentation p, {required bool tablette}) =>
      p != Presentation.automatique ? p : (tablette ? Presentation.compact : Presentation.tableauDeBord);

  /// Le compte connecté est l'administrateur (même règle que prestige_vente_app : identifiant « admin »).
  static bool estAdministrateur(BuildContext context) {
    try {
      return Provider.of<AuthProvider>(context, listen: false).user?.login.toLowerCase() == 'admin';
    } catch (_) {
      return false;
    }
  }

  /// Change la présentation pour tous les comptes de l'appareil : directement pour l'administrateur, après le
  /// code administrateur pour les autres comptes. Renvoie vrai si le choix est enregistré.
  static Future<bool> changer(BuildContext context, Presentation p) async {
    if (p == choix.value) return true;
    if (!estAdministrateur(context)) {
      if (!await PinCodeDialog.show(context)) return false;
    }
    await enregistrer(p);
    return true;
  }
}
