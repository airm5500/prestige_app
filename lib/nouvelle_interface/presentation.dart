// lib/nouvelle_interface/presentation.dart
// Présentation de la nouvelle interface (docs/ANALYSE_PRESTIGE_APP.md §4, recommandation) :
//   A · Tableau de bord (par défaut sur téléphone), B · Compact (automatiquement sur tablette : menu latéral et
//   deux colonnes), C · Guidé (en option).
// Le choix est un réglage d'apparence MÉMORISÉ sur l'appareil, valable pour tous les comptes qui s'y connectent.
// Comme dans prestige_vente_app, seul l'administrateur le change : compte « admin » directement, tout autre compte
// doit saisir le code administrateur (le même que celui qui protège la configuration du serveur).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../widgets/pin_code_dialog.dart';

enum Presentation { automatique, tableauDeBord, compact, guide }

extension PresentationTextes on Presentation {
  String get lettre => switch (this) {
        Presentation.automatique => 'Auto',
        Presentation.tableauDeBord => 'A',
        Presentation.compact => 'B',
        Presentation.guide => 'C',
      };

  String get libelle => switch (this) {
        Presentation.automatique => 'Automatique',
        Presentation.tableauDeBord => 'A · Tableau de bord',
        Presentation.compact => 'B · Compact',
        Presentation.guide => 'C · Guidé',
      };

  String get description => switch (this) {
        Presentation.automatique => 'A sur téléphone, B sur tablette (recommandé)',
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

  static final ValueNotifier<Presentation> choix = ValueNotifier<Presentation>(Presentation.automatique);

  static Future<Presentation> charger() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(cle);
      choix.value = Presentation.values.asNameMap()[v] ?? Presentation.automatique;
    } catch (_) {
      choix.value = Presentation.automatique;
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
