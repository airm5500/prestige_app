// lib/presences/export_fichier.dart
// Après un téléchargement (Excel, PDF) : le fichier est écrit dans le dossier temporaire de l'application (aucune
// permission de stockage à demander), puis le pharmacien choisit « Partager » (WhatsApp, e-mail, Drive… via
// share_plus) ou « Ouvrir » (application du téléphone via open_file). Ces deux paquets sont déjà dans le projet.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../plateforme/capacites.dart';
import '../services/api_service.dart';

class ExportFichier {
  ExportFichier._();

  /// Écrit le fichier et renvoie son chemin (remplaçable dans les tests).
  static Future<String> Function(FichierTelecharge f) enregistrer = _enregistrer;

  /// Partage (remplaçable dans les tests).
  static Future<void> Function(String chemin, String type, String sujet) partager = _partager;

  /// Ouverture (remplaçable dans les tests) ; renvoie un message d'échec ou null.
  static Future<String?> Function(String chemin, String type) ouvrir = _ouvrir;

  static Future<String> _enregistrer(FichierTelecharge f) async {
    final dossier = Directory('${(await getTemporaryDirectory()).path}/presences');
    if (!await dossier.exists()) await dossier.create(recursive: true);
    final fichier = File('${dossier.path}/${f.nom}');
    await fichier.writeAsBytes(f.octets, flush: true);
    return fichier.path;
  }

  /// Point d'ancrage de la fenêtre de partage (iPad, 3.12.0 : sans lui, elle ne s'ouvre pas) : le centre de l'écran
  /// qui a demandé l'export, relevé par [proposer].
  static Rect? ancrage;

  static Future<void> _partager(String chemin, String type, String sujet) async {
    await Share.shareXFiles([XFile(chemin, mimeType: type)], subject: sujet, sharePositionOrigin: Capacites.actuelles.partageAncre ? ancrage : null);
  }

  /// Centre (1 × 1) de la zone de [context], ou null si elle n'est pas encore mesurée.
  static Rect? ancrageDe(BuildContext context) {
    final r = context.findRenderObject();
    if (r is! RenderBox || !r.hasSize) return null;
    return Rect.fromCenter(center: r.localToGlobal(r.size.center(Offset.zero)), width: 1, height: 1);
  }

  static Future<String?> _ouvrir(String chemin, String type) async {
    final r = await OpenFile.open(chemin, type: type);
    return r.type == ResultType.done ? null : 'Aucune application pour ouvrir ce fichier : utilisez « Partager ».';
  }

  /// Enregistre [f] puis propose Partager / Ouvrir.
  static Future<void> proposer(BuildContext context, FichierTelecharge f, {required String sujet}) async {
    final String chemin;
    try {
      chemin = await enregistrer(f);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'enregistrer le fichier sur le téléphone (espace plein ?).'), backgroundColor: Colors.red));
      }
      return;
    }
    if (!context.mounted) return;
    ancrage = ancrageDe(context);
    final type = f.type.split(';').first.trim();
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(f.nom.endsWith('.pdf') ? Icons.picture_as_pdf_outlined : Icons.table_view_outlined),
            title: Text(f.nom, key: const Key('presences_export_nom')),
            subtitle: Text('Fichier prêt (${(f.octets.length / 1024).toStringAsFixed(1)} Ko)'),
          ),
          const Divider(height: 1),
          ListTile(
            key: const Key('presences_export_partager'),
            leading: const Icon(Icons.share_outlined),
            title: const Text('Partager'),
            subtitle: const Text('WhatsApp, e-mail, Drive…'),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await partager(chemin, type, sujet);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partage impossible.'), backgroundColor: Colors.red));
                }
              }
            },
          ),
          ListTile(
            key: const Key('presences_export_ouvrir'),
            leading: const Icon(Icons.open_in_new),
            title: const Text('Ouvrir'),
            onTap: () async {
              Navigator.pop(ctx);
              String? erreur;
              try {
                erreur = await ouvrir(chemin, type);
              } catch (_) {
                erreur = 'Ouverture impossible : utilisez « Partager ».';
              }
              if (erreur != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erreur), backgroundColor: Colors.orange));
              }
            },
          ),
        ]),
      ),
    );
  }
}
