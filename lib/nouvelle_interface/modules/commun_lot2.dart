// lib/nouvelle_interface/modules/commun_lot2.dart
// Briques communes aux modules refaits du lot 2 (achats et stock), en plus de commun.dart et periode.dart :
// confirmation avant une écriture, message de résultat, étiquettes des filtres actifs avec « Retirer les filtres ».
import 'package:flutter/material.dart';

import '../charte.dart';
import '../composants.dart';

/// Demande confirmation (« Non » / [oui]) ; vrai seulement si l'utilisateur confirme.
Future<bool> confirmer(BuildContext context, {required String titre, required String texte, String oui = 'Oui, Supprimer'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titre),
      content: Text(texte),
      actions: [
        TextButton(key: const Key('confirmer_non'), onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Non')),
        TextButton(key: const Key('confirmer_oui'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(oui)),
      ],
    ),
  );
  return r == true;
}

/// Message de résultat d'une action (vert : réussi ; rouge : échec), lisible et sans code technique.
void messageResultat(BuildContext context, String texte, {bool echec = false}) {
  final m = ScaffoldMessenger.of(context);
  // Le DERNIER message l'emporte : la file est vidée (clearSnackBars), pas seulement le message affiché. Avec
  // hideCurrentSnackBar, un message déjà en attente (succès d'un envoi précédent, en file pendant la sortie d'un
  // autre) passait AVANT le nouveau et le cachait 4 s (défaut révélé par la CI, 3.10.1 : « Quantité invalide » d'une
  // suggestion masquée par « Quantité enregistrée »).
  m.clearSnackBars();
  m.showSnackBar(SnackBar(
    backgroundColor: echec ? Charte.rougeTexte : Charte.vertTexte,
    content: Row(children: [
      Icon(echec ? Icons.error_outline : Icons.check_circle_outline, color: Charte.blanc),
      const SizedBox(width: 10),
      Expanded(child: Text(texte, style: const TextStyle(color: Charte.blanc))),
    ]),
  ));
}

/// Filtres actifs sous la période : une étiquette par filtre et « Retirer les filtres ».
class EtiquettesFiltres extends StatelessWidget {
  final List<String> etiquettes;
  final VoidCallback onRetirer;
  const EtiquettesFiltres({super.key, required this.etiquettes, required this.onRetirer});

  @override
  Widget build(BuildContext context) => etiquettes.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final e in etiquettes) Etiquette(e),
            TextButton(key: const Key('filtres_retirer'), onPressed: onRetirer, child: const Text('Retirer les filtres')),
          ]),
        );
}

/// Libellé de liste indisponible / en chargement dans la feuille des filtres.
String? aideListe(Object? erreur, bool chargee) => erreur != null ? 'Liste indisponible' : (chargee ? null : 'Chargement de la liste…');
