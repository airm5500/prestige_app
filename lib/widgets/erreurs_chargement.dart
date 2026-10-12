// lib/widgets/erreurs_chargement.dart
// Bandeaux communs : échec de chargement (≠ liste vide). Mêmes widgets et mêmes textes que
// prestige_vente_app (lib/widgets/sync_status.dart), aux couleurs de l'application du pharmacien.
import 'package:flutter/material.dart';

const _encre = Color(0xFF14213D);
const _gris = Color(0xFF5B6B82);

/// Échec de chargement : message clair et bouton « Réessayer ».
class LoadErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const LoadErrorBanner({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5C2C2)),
        ),
        child: Row(children: [
          Icon(Icons.cloud_off, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: Colors.red.shade900, fontSize: 13))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ]),
      );
}

/// Écran entier quand rien n'a pu être chargé (au lieu de « aucun résultat »).
class LoadErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const LoadErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off, size: 56, color: Colors.red.shade400),
            const SizedBox(height: 12),
            const Text('Chargement impossible', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _encre)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _gris)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
          ]),
        ),
      );
}
