// lib/nouvelle_interface/vague2/commun_vague2.dart
// Éléments propres aux écrans de la vague 2 (Prévisions, Pilotage, Analyse de garde, CA emplacement / famille).
// Les COMPOSANTS de base restent ceux du lot 1 et de la vague 1 (modules/commun.dart, modules/periode.dart,
// composants.dart) : états chargement / vide / erreur (« Droit manquant »), chiffres clés, cartes, tableau dense,
// puces, feuille des filtres, recherche, pagination. Ajouts :
//  - barres horizontales (historique mensuel, tranches horaires, indices saisonniers) : lisibles à toutes les
//    tailles, valeur écrite en clair à droite (la barre seule ne porte aucune information) ;
//  - variation : icône (flèche) + texte (« Hausse +12,5 % ») + couleur, jamais la couleur seule ;
//  - chargement annulable (calculs longs demandés explicitement : indication discrète et bouton « Annuler ») ;
//  - onglets blancs sous la barre bleu nuit.
import 'package:flutter/material.dart';

import '../charte.dart';
import '../modules/commun.dart';
import 'donnees_vague2.dart';

/// Barres horizontales : libellé à gauche, barre proportionnelle, valeur en clair à droite.
class BarresHorizontales extends StatelessWidget {
  final List<(String libelle, double valeur, String texte)> barres;

  /// Indice de la barre mise en avant (pic), ou null.
  final int? enAvant;

  /// Valeur de référence tracée (indice 1,0), ou null.
  final double? reference;
  final double largeurLibelle;
  const BarresHorizontales({super.key, required this.barres, this.enAvant, this.reference, this.largeurLibelle = 92});

  @override
  Widget build(BuildContext context) {
    final max = barres.fold<double>(reference ?? 0, (m, b) => b.$2 > m ? b.$2 : m);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < barres.length; i++)
        Semantics(
          label: '${barres[i].$1} : ${barres[i].$3}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(
                width: largeurLibelle,
                child: Text(barres[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Charte.encre, fontWeight: i == enAvant ? FontWeight.w800 : FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  final f = max <= 0 ? 0.0 : (barres[i].$2 / max).clamp(0.0, 1.0);
                  final repere = reference == null || max <= 0 ? null : (reference! / max).clamp(0.0, 1.0) * c.maxWidth;
                  return SizedBox(
                    height: 16,
                    child: Stack(children: [
                      Container(decoration: BoxDecoration(color: Charte.grisClair, borderRadius: BorderRadius.circular(4))),
                      FractionallySizedBox(
                        widthFactor: f,
                        child: Container(
                            decoration: BoxDecoration(color: i == enAvant ? Charte.ambre : Charte.navy2, borderRadius: BorderRadius.circular(4))),
                      ),
                      if (repere != null) Positioned(left: repere - 1, top: 0, bottom: 0, child: Container(width: 2, color: Charte.encre)),
                    ]),
                  );
                }),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 56),
                child: Text(barres[i].$3,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 13, color: Charte.encre, fontWeight: i == enAvant ? FontWeight.w800 : FontWeight.w600)),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Variation : flèche + texte + couleur (« Hausse +12,5 % »). La flèche suit le SENS RÉEL (hausse / baisse) et le mot
/// « Hausse » / « Baisse » l'écrit (le sens n'est jamais donné par la couleur seule) ; selon [sens], la couleur dit si
/// c'est une bonne nouvelle ; neutre : gris. 3.11.0 (demande du pharmacien) : les mots « favorable » /
/// « défavorable » sont retirés (CA par emplacement et Pilotage) ; la version compacte garde la flèche (et son libellé
/// accessible « Hausse » / « Baisse ») et le pourcentage.
class Variation extends StatelessWidget {
  final double? valeur;
  final String? suffixe;
  final SensIndicateur sens;
  final bool compacte;

  /// Grand format (carte d'évolution du CA par emplacement, 3.11.0).
  final bool grande;
  const Variation(this.valeur, {super.key, this.suffixe, this.sens = SensIndicateur.hausseFavorable, this.compacte = false, this.grande = false});

  @override
  Widget build(BuildContext context) {
    final v = valeur;
    final favorable = variationFavorable(v, sens);
    final couleur = favorable == null ? Charte.gris : (favorable ? Charte.vertTexte : Charte.rougeTexte);
    final (icone, mot) = v == null
        ? (Icons.remove, 'Sans comparaison')
        : v > 0
            ? (Icons.arrow_upward, 'Hausse')
            : v < 0
                ? (Icons.arrow_downward, 'Baisse')
                : (Icons.drag_handle, 'Stable');
    final texte = v == null ? mot : (compacte ? variationTexte(v) : '$mot ${variationTexte(v)}');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icone, size: grande ? 24 : 16, color: couleur, semanticLabel: mot),
      const SizedBox(width: 3),
      Flexible(
        child: Text(suffixe == null ? texte : '$texte $suffixe',
            style: TextStyle(color: couleur, fontSize: grande ? 20 : 13, fontWeight: grande ? FontWeight.w800 : FontWeight.w700)),
      ),
    ]);
  }
}

/// Chargement d'un calcul : texte, et pour un calcul long l'indication « peut prendre un moment » et « Annuler ».
class ChargementAnnulable extends StatelessWidget {
  final String texte;
  final String? indication;
  final VoidCallback? annuler;
  const ChargementAnnulable({super.key = const Key('chargement_annulable'), required this.texte, this.indication, this.annuler});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        EtatChargement(texte: texte),
        if (indication != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(indication!, key: const Key('indication_calcul_long'), textAlign: TextAlign.center, style: const TextStyle(color: Charte.gris, fontSize: 13)),
          ),
        if (annuler != null)
          OutlinedButton.icon(
            key: const Key('bouton_annuler_calcul'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: annuler,
            icon: const Icon(Icons.close),
            label: const Text('Annuler'),
          ),
      ]);
}

/// Onglets blancs (texte bleu nuit, trait ambre) sous la barre bleu nuit.
PreferredSizeWidget ongletsBlancs(TabController controleur, List<String> libelles, {Key? key}) => PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Material(
        color: Charte.blanc,
        child: TabBar(
          key: key,
          controller: controleur,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [for (final l in libelles) Tab(height: 48, text: l)],
        ),
      ),
    );

/// Grille de chiffres clés (2 colonnes sur téléphone, 3 ou 4 sur tablette).
class GrilleChiffres extends StatelessWidget {
  final List<Widget> chiffres;
  const GrilleChiffres(this.chiffres, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final colonnes = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 600 ? 3 : 2);
        final largeur = (c.maxWidth - (colonnes - 1) * 8) / colonnes;
        return Wrap(spacing: 8, runSpacing: 8, children: [for (final t in chiffres) SizedBox(width: largeur, child: t)]);
      });
}

/// Liste de choix dans une feuille (emplacement, famille, grossiste, rayon) : « Tous » + options.
class ChoixListe extends StatelessWidget {
  final String libelle;
  final IconData icone;
  final List<OptionListe>? options;
  final Object? erreur;
  final String valeur;
  final String tous;
  final ValueChanged<String> onChanged;
  const ChoixListe({
    super.key,
    required this.libelle,
    required this.icone,
    required this.options,
    required this.erreur,
    required this.valeur,
    required this.tous,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final o = options ?? const <OptionListe>[];
    final connu = valeur.isEmpty || o.any((x) => x.id == valeur);
    return DropdownButtonFormField<String>(
      value: connu ? valeur : '',
      isExpanded: true,
      decoration: InputDecoration(
        labelText: libelle,
        prefixIcon: Icon(icone),
        helperText: erreur != null ? 'Liste indisponible' : (options == null ? 'Chargement de la liste…' : null),
      ),
      items: [
        DropdownMenuItem(value: '', child: Text(tous)),
        for (final x in o) DropdownMenuItem(value: x.id, child: Text(x.libelle, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: options == null ? null : (v) => onChanged(v ?? ''),
    );
  }
}

/// Résumé d'un choix multiple : « Aucun filtre (tous) », « 1 sélectionné », « 3 sélectionnés », « Tous (12) ».
String resumeChoixMultiple(int choisis, int total) {
  if (choisis == 0) return 'Aucun filtre (tous)';
  if (total > 0 && choisis >= total) return 'Tous ($total)';
  return '$choisis sélectionné${choisis > 1 ? 's' : ''}';
}

/// Choix MULTIPLE dans une feuille (emplacements, familles, grossistes) : en-tête dépliable (libellé + compteur),
/// boutons « Tout » / « Aucun », une case à cocher par option. Aucun coché = aucun filtre.
class ChoixMultiple extends StatefulWidget {
  final String cle;
  final String libelle;
  final IconData icone;
  final List<OptionListe>? options;
  final Object? erreur;
  final List<String> valeurs;
  final ValueChanged<List<String>> onChanged;
  const ChoixMultiple({
    super.key,
    required this.cle,
    required this.libelle,
    required this.icone,
    required this.options,
    required this.erreur,
    required this.valeurs,
    required this.onChanged,
  });

  @override
  State<ChoixMultiple> createState() => _ChoixMultipleState();
}

class _ChoixMultipleState extends State<ChoixMultiple> {
  bool _ouvert = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.options ?? const <OptionListe>[];
    final choisis = widget.valeurs.toSet();
    final nb = o.isEmpty ? choisis.length : o.where((x) => choisis.contains(x.id)).length;
    final aide = widget.erreur != null ? 'Liste indisponible' : (widget.options == null ? 'Chargement de la liste…' : resumeChoixMultiple(nb, o.length));
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Charte.bordureChamp), borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          container: true,
          button: true,
          expanded: _ouvert,
          label: widget.libelle,
          value: aide,
          excludeSemantics: true,
          child: InkWell(
            key: Key('multi_${widget.cle}'),
            onTap: widget.options == null ? null : () => setState(() => _ouvert = !_ouvert),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Icon(widget.icone, color: Charte.gris),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(widget.libelle, style: const TextStyle(color: Charte.encre, fontSize: 15, fontWeight: FontWeight.w600)),
                      Text(aide, key: Key('multi_${widget.cle}_resume'), style: const TextStyle(color: Charte.gris, fontSize: 13)),
                    ]),
                  ),
                  Icon(_ouvert ? Icons.expand_less : Icons.expand_more, color: Charte.navy),
                ]),
              ),
            ),
          ),
        ),
        if (_ouvert && o.isNotEmpty) ...[
          const Divider(height: 1),
          Row(children: [
            TextButton(
              key: Key('multi_${widget.cle}_tout'),
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => widget.onChanged([for (final x in o) x.id]),
              child: const Text('Tout'),
            ),
            TextButton(
              key: Key('multi_${widget.cle}_aucun'),
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              onPressed: () => widget.onChanged(const []),
              child: const Text('Aucun'),
            ),
          ]),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 264),
            child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [
              for (final x in o)
                CheckboxListTile(
                  key: Key('multi_${widget.cle}_${x.id}'),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: choisis.contains(x.id),
                  title: Text(x.libelle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onChanged: (v) => widget.onChanged(v == true ? [...widget.valeurs, x.id] : [for (final i in widget.valeurs) if (i != x.id) i]),
                ),
            ]),
          ),
        ],
      ]),
    );
  }
}
