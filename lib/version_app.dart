// lib/version_app.dart
// Version de l'application lue À L'EXÉCUTION dans le paquet installé (package_info_plus) :
// versionName / versionCode Android, eux-mêmes repris par Gradle de `version: X.Y.Z+N` de pubspec.yaml.
// Source unique : pubspec.yaml (voir docs/VERSIONS_SUNMI.md) — aucune constante de version dans le code.
// Même composant que Prestige Inventaire et Prestige Vente (dépôts frères).
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionApp {
  VersionApp._();

  static String? _version;
  static String? _build;

  /// Lit la version du paquet installé (main() l'appelle avant runApp). Sans plateforme (tests sans
  /// `PackageInfo.setMockInitialValues`) : la version reste inconnue (« ? »), sans erreur.
  static Future<String> charger() async {
    try {
      final p = await PackageInfo.fromPlatform();
      _version = p.version;
      _build = p.buildNumber;
    } catch (_) {}
    return complete;
  }

  /// X.Y.Z (versionName), « ? » tant qu'elle n'a pas été lue.
  static String get version => _version == null || _version!.isEmpty ? '?' : _version!;

  /// X.Y.Z+N (versionName + versionCode), affichée à l'écran.
  static String get complete => version == '?' || (_build ?? '').isEmpty ? version : '$version+$_build';

  /// Tests : oublie la version lue.
  @visibleForTesting
  static void oublier() {
    _version = null;
    _build = null;
  }
}

/// « Version X.Y.Z+N » discret (bas de l'écran de connexion, Réglages), lu à l'exécution.
class VersionAffichee extends StatefulWidget {
  final Color? couleur;
  final double taille;

  /// Texte avant / après la version (ex. « · Assistance : … » dans le pied de connexion).
  final String Function(String version)? format;
  final TextAlign textAlign;
  const VersionAffichee({super.key, this.couleur, this.taille = 12, this.format, this.textAlign = TextAlign.center});

  @override
  State<VersionAffichee> createState() => _VersionAfficheeState();
}

class _VersionAfficheeState extends State<VersionAffichee> {
  late final Future<String> _lecture = VersionApp.charger();

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
        future: _lecture,
        initialData: VersionApp.complete,
        builder: (context, s) {
          final v = 'Version ${s.data ?? VersionApp.complete}';
          return Text(
            widget.format?.call(v) ?? v,
            key: const Key('version_app'),
            textAlign: widget.textAlign,
            style: TextStyle(fontSize: widget.taille, fontWeight: FontWeight.w600, color: widget.couleur ?? Theme.of(context).colorScheme.onSurface),
          );
        },
      );
}
