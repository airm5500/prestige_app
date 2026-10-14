// lib/widgets/taille_ecran_reglage.dart
// Réglage « Taille de l'écran » (3.7.0), commun aux deux interfaces : Réglages › Apparence (nouvelle) et
// Configuration (ancienne). Module : lib/ui/taille_ecran.dart (repris de Prestige Inventaire et Prestige Mobile,
// docs/TAILLE_ECRAN.md). Protégé par le code administrateur (même fenêtre PinCodeDialog que les autres zones
// protégées), appliqué au prochain lancement ; la fenêtre qui suit le choix propose « Plus tard » ou « Relancer
// maintenant » (retour à l'accueil, interface reconstruite ; la session — cookie, compte, licence — est gardée :
// les providers sont au-dessus de l'interface réduite).
import 'package:flutter/material.dart';

import '../ui/taille_ecran.dart';
import 'pin_code_dialog.dart';

class TailleEcranSetting extends StatefulWidget {
  /// Code administrateur (défaut : [PinCodeDialog.show]).
  final Future<bool> Function(BuildContext)? verifierPin;

  /// Couleur du texte secondaire (charte de l'interface qui l'affiche).
  final Color? couleurAide;

  /// Marge horizontale des lignes (16 dans les cartes de la nouvelle interface, 4 dans la Configuration).
  final double marge;
  const TailleEcranSetting({super.key, this.verifierPin, this.couleurAide, this.marge = 16});

  static String detail(TailleEcran t) => switch (t) {
        TailleEcran.automatique => 'Taille définie par Android',
        TailleEcran.compact => 'Toute l\'interface 10 % plus petite',
        TailleEcran.tresCompact => 'Toute l\'interface 20 % plus petite (petits terminaux)',
      };

  @override
  State<TailleEcranSetting> createState() => _TailleEcranSettingState();
}

class _TailleEcranSettingState extends State<TailleEcranSetting> {
  Future<void> _changer(TailleEcran t) async {
    if (t == TailleEcranReglage.enregistree) return;
    final ok = await (widget.verifierPin ?? PinCodeDialog.show)(context);
    if (!ok || !mounted) return;
    await TailleEcranReglage.enregistrer(t);
    if (!mounted) return;
    setState(() {});
    final maintenant = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('taille-ecran-relancer'),
        icon: const Icon(Icons.aspect_ratio),
        title: Text('Taille de l\'écran : ${t.libelle}'),
        content: const Text('Appliquée au prochain lancement de l\'application. Vous pouvez aussi relancer l\'affichage '
            'maintenant (retour à l\'accueil ; la session reste ouverte).'),
        actions: [
          TextButton(
            key: const ValueKey('taille-ecran-plus-tard'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            key: const ValueKey('taille-ecran-relancer-maintenant'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Relancer maintenant'),
          ),
        ],
      ),
    );
    if (maintenant == true && mounted) {
      // Retour au premier écran puis interface reconstruite à la nouvelle taille.
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      TailleEcranReglage.appliquerMaintenant();
    }
  }

  @override
  Widget build(BuildContext context) {
    final aide = widget.couleurAide ?? Theme.of(context).hintColor;
    final choisie = TailleEcranReglage.enregistree;
    final marge = EdgeInsets.symmetric(horizontal: widget.marge);
    return Column(
      key: const ValueKey('taille-ecran'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: marge,
          leading: const Icon(Icons.aspect_ratio),
          title: const Text('Taille de l\'écran', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Code administrateur demandé'),
          trailing: const Icon(Icons.lock_outline, size: 18, semanticLabel: 'Réservé à l\'administrateur'),
        ),
        for (final t in TailleEcran.values)
          RadioListTile<TailleEcran>(
            key: ValueKey('taille-ecran-${t.name}'),
            contentPadding: marge,
            value: t,
            groupValue: choisie,
            onChanged: (v) {
              if (v != null) _changer(v);
            },
            title: Text(t.libelle),
            subtitle: Text(TailleEcranSetting.detail(t)),
          ),
        // Automatique sur un petit écran (Sunmi V2s, V3…) : Compact appliqué d'office.
        if (choisie == TailleEcran.automatique && TailleEcranReglage.compactAutomatique(context))
          Padding(
            padding: EdgeInsets.fromLTRB(widget.marge, 4, widget.marge, 2),
            child: const Text('Automatique (Compact appliqué sur cet écran)',
                key: ValueKey('taille-ecran-auto-compact'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(widget.marge, 2, widget.marge, 4),
          child: Text(
            TailleEcranReglage.enAttente
                ? 'Choix enregistré : appliqué au prochain lancement.'
                : 'Pour les petits écrans (Sunmi V2s 5,45″, V3) : Compact et Très compact réduisent toute l\'interface. '
                    'Les PDF et impressions ne sont pas concernés.',
            key: const ValueKey('taille-ecran-aide'),
            style: TextStyle(fontSize: 12.5, color: aide, fontWeight: TailleEcranReglage.enAttente ? FontWeight.w700 : FontWeight.normal),
          ),
        ),
      ],
    );
  }
}
