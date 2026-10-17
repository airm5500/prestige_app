// lib/plateforme/capacites.dart
// 3.12.0 — CAPACITÉS DE L'APPAREIL (Android / iOS), en un seul endroit testable.
//
// Prestige Pharmacien est né sur Android (téléphones et terminaux Sunmi). Sur iPhone et iPad, quelques fonctions n'ont
// pas de sens ou se font autrement ; elles sont décidées ICI, jamais dispersées dans les écrans :
//  - réglage « Taille de l'écran » (réduction de toute l'interface pour les petits Sunmi) : Android seulement ; sur iOS
//    l'interface garde la taille du système (pas de réduction automatique sur l'iPhone SE) et le réglage est masqué ;
//  - export CSV d'une suggestion : dossier Téléchargements sur Android ; sur iOS, dossier de l'application, visible
//    dans l'app Fichiers (« Sur mon iPhone / iPad › Prestige Pharmacien », Info.plist : UIFileSharingEnabled) ;
//  - partage d'un fichier : sur iPad, la fenêtre de partage doit être ancrée à un point de l'écran (sinon elle ne
//    s'ouvre pas) ;
//  - impression / PDF (package printing : fenêtre d'impression du système, AirPrint sur iOS), ouverture de fichier,
//    stockage sécurisé (Keychain sur iOS) : disponibles partout, rien à masquer.
// Android : comportement strictement inchangé.
//
// Le système est lu sur [defaultTargetPlatform] (iOS sur un iPhone / iPad) ; les tests le changent avec
// debugDefaultTargetPlatformOverride, ou fixent [Capacites.forcees].
import 'package:flutter/foundation.dart';

enum SystemeAppareil { android, ios, autre }

class Capacites {
  final SystemeAppareil systeme;
  const Capacites(this.systeme);

  /// Tests : capacités imposées (null : celles de la plateforme).
  @visibleForTesting
  static Capacites? forcees;

  static Capacites get actuelles =>
      forcees ??
      Capacites(switch (defaultTargetPlatform) {
        TargetPlatform.android => SystemeAppareil.android,
        TargetPlatform.iOS => SystemeAppareil.ios,
        _ => SystemeAppareil.autre,
      });

  bool get ios => systeme == SystemeAppareil.ios;

  /// Réglage « Taille de l'écran » et réduction automatique sur petit écran (terminaux Sunmi) : Android seulement.
  bool get reglageTailleEcran => !ios;

  /// Où l'export CSV d'une suggestion est écrit, tel que dit au pharmacien.
  String get emplacementExport => ios ? 'l\'app Fichiers (Sur mon iPhone / iPad › Prestige Pharmacien)' : 'Téléchargements';

  /// La fenêtre de partage doit être ancrée (iPad).
  bool get partageAncre => ios;
}
