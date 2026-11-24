// lib/demo/widgets_demo.dart
// Mode démonstration (3.18.0) : bouton « Essayer la démonstration » (premier écran d'une installation neuve,
// connexion, serveur injoignable, licence) et bandeau permanent « Démonstration — données fictives » avec l'action
// « Quitter la démonstration ».
import 'package:flutter/material.dart';

import 'mode_demo.dart';

/// Bouton « Essayer la démonstration » : un seul toucher, aucun identifiant.
class BoutonDemo extends StatelessWidget {
  /// Couleur du texte et du contour (fond foncé : blanc).
  final Color? couleur;

  const BoutonDemo({super.key, this.couleur});

  static const cle = Key('essayer_demonstration');

  @override
  Widget build(BuildContext context) {
    final c = couleur ?? Theme.of(context).colorScheme.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: OutlinedButton.icon(
          key: cle,
          style: OutlinedButton.styleFrom(
            foregroundColor: c,
            side: BorderSide(color: c, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text(ModeDemo.libelleBouton, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          onPressed: () => ModeDemo.entrer(context),
        ),
      ),
    ]);
  }
}

/// Encadré « Pas encore de serveur Prestige ? » + bouton, en tête de la première configuration (installation neuve).
class CarteDemo extends StatelessWidget {
  const CarteDemo({super.key});

  static const fond = Color(0xFFFFF6DD);
  static const bord = Color(0xFFE9C46A);
  static const encre = Color(0xFF3D2E00);
  static const texte = Color(0xFF5B4A12);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('carte_demonstration'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(14), border: Border.all(color: bord)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Pas encore de serveur Prestige ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: encre)),
        Text('Découvrez l\'application avec des données fictives.', style: TextStyle(fontSize: 13.5, color: texte)),
        SizedBox(height: 10),
        BoutonDemo(couleur: encre),
      ]),
    );
  }
}

/// Cadre de l'application (MaterialApp.builder) : bandeau de démonstration au-dessus de tous les écrans quand la
/// démonstration est ouverte. Structure identique avec ou sans démonstration (le navigateur n'est jamais recréé).
class CadreDemo extends StatelessWidget {
  final Widget child;
  const CadreDemo({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ModeDemo.actif,
      builder: (context, demo, _) {
        final mq = MediaQuery.of(context);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (demo) const BandeauDemo(),
          Expanded(
            key: const ValueKey('cadre_application'),
            // Le bandeau occupe déjà la barre d'état : les écrans n'ont plus de marge haute à réserver.
            child: MediaQuery(data: demo ? mq.removePadding(removeTop: true) : mq, child: child),
          ),
        ]);
      },
    );
  }
}

/// Bandeau permanent et discret : « Démonstration — données fictives » + « Quitter la démonstration ».
class BandeauDemo extends StatelessWidget {
  const BandeauDemo({super.key});

  static const fond = Color(0xFF3D2E00);
  static const texte = Color(0xFFFFE08A);

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('bandeau_demonstration'),
      color: fond,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
          child: Row(children: [
            const Icon(Icons.science_outlined, size: 16, color: texte),
            const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                header: true,
                child: const Text(ModeDemo.libelleBandeau, style: TextStyle(color: texte, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: TextButton(
                key: const Key('quitter_demonstration'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: ModeDemo.quitter,
                child: const Text(ModeDemo.libelleQuitter,
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: Colors.white)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
