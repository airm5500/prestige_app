// lib/nouvelle_interface/composants.dart
// Éléments visuels de la nouvelle interface, repris des maquettes (docs/maquettes/prestige_app_maquettes.html) et
// de prestige_vente_app (lib/widgets/presentation_style.dart) : en-tête bleu arrondi, chiffres clés, pastilles,
// cartes à bande de couleur, tuiles et lignes de menu, grandes questions (présentation C), message d'erreur.
// Toutes les zones touchables font au moins 48 dp et portent un libellé.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'charte.dart';
import 'icones_illustrees.dart';

/// En-tête bleu nuit aux coins inférieurs arrondis (NavyHeader de vente_app), sous la barre d'état.
class EnTeteNavy extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final List<Widget> actions;
  final List<Widget> enfants;
  final bool arrondi;

  /// Ajoute la flèche de retour quand l'écran peut revenir en arrière.
  final bool retour;
  const EnTeteNavy({
    super.key,
    required this.titre,
    this.sousTitre,
    this.actions = const [],
    this.enfants = const [],
    this.arrondi = true,
    this.retour = true,
  });

  @override
  Widget build(BuildContext context) {
    final peutRevenir = retour && Navigator.of(context).canPop();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: BoxDecoration(
          color: Charte.navy,
          borderRadius: arrondi ? const BorderRadius.vertical(bottom: Radius.circular(22)) : null,
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                if (peutRevenir)
                  IconButton(
                    tooltip: 'Retour',
                    icon: const Icon(Icons.arrow_back, color: Charte.blanc),
                    onPressed: () => Navigator.of(context).maybePop(),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(titre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Charte.blanc, fontSize: 20, fontWeight: FontWeight.bold)),
                      if (sousTitre != null)
                        Text(sousTitre!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Charte.enteteGris, fontSize: 13)),
                    ]),
                  ),
                ),
                ...actions,
              ]),
              for (final e in enfants) Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), child: e),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Barre blanche (présentation B) : titre bleu, sous-titre gris, actions.
class BarreBlanche extends StatelessWidget {
  final String titre;
  final Widget? sousTitre;
  final List<Widget> actions;
  const BarreBlanche({super.key, required this.titre, this.sousTitre, this.actions = const []});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Container(
          decoration: const BoxDecoration(color: Charte.blanc, border: Border(bottom: BorderSide(color: Charte.ligne))),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(titre, style: const TextStyle(color: Charte.navy, fontSize: 19, fontWeight: FontWeight.bold)),
                    if (sousTitre != null) DefaultTextStyle.merge(style: const TextStyle(color: Charte.gris, fontSize: 13), child: sousTitre!),
                  ]),
                ),
                ...actions,
              ]),
            ),
          ),
        ),
      );
}

/// Point coloré (état du serveur).
class Point extends StatelessWidget {
  final Color couleur;
  const Point(this.couleur, {super.key});

  @override
  Widget build(BuildContext context) =>
      Container(width: 9, height: 9, decoration: BoxDecoration(color: couleur, shape: BoxShape.circle));
}

/// Pastille de l'en-tête bleu (« ● Serveur local », « Aujourd'hui »). Touchable si [onTap] (≥ 48 dp de haut).
class PastilleEntete extends StatelessWidget {
  final String texte;
  final Color? point;
  final IconData? icone;
  final VoidCallback? onTap;
  final String? infobulle;
  final bool ambre;
  const PastilleEntete(this.texte, {super.key, this.point, this.icone, this.onTap, this.infobulle, this.ambre = false});

  @override
  Widget build(BuildContext context) {
    final fg = ambre ? Charte.surAmbre : Charte.blanc;
    final contenu = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: ambre ? Charte.ambre : Charte.enteteVoile, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (point != null) ...[Point(point!), const SizedBox(width: 6)],
        Flexible(
          child: Text(texte,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        if (icone != null) ...[const SizedBox(width: 4), Icon(icone, size: 16, color: fg)],
      ]),
    );
    if (onTap == null) return contenu;
    final bouton = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Center(widthFactor: 1, child: contenu)),
      ),
    );
    return infobulle == null ? bouton : Tooltip(message: infobulle!, child: bouton);
  }
}

/// Chiffre clé dans l'en-tête bleu (maquette A : CA, marge, crédits, équipe). [enAvant] : tuile ambre.
class TuileKpi extends StatelessWidget {
  final String libelle;
  final String valeur;
  final String? detail;
  final bool enAvant;
  final bool detailPositif;
  const TuileKpi({super.key, required this.libelle, required this.valeur, this.detail, this.enAvant = false, this.detailPositif = false});

  @override
  Widget build(BuildContext context) {
    final fg = enAvant ? Charte.surAmbre : Charte.blanc;
    final secondaire = enAvant ? Charte.surAmbre : Charte.enteteGris;
    // Une tuile = une annonce (libellé, valeur, détail) pour le lecteur d'écran.
    return MergeSemantics(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: enAvant ? Charte.ambre : Charte.enteteVoile, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(libelle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondaire, fontSize: 12)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(valeur, maxLines: 1, style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        if (detail != null)
          Text(detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: detailPositif && !enAvant ? Charte.vertHeure : secondaire,
                  fontSize: 11.5,
                  fontWeight: detailPositif ? FontWeight.bold : FontWeight.normal)),
      ]),
    ));
  }
}

/// Grille de chiffres clés (2 colonnes sur téléphone, 4 sur tablette).
class GrilleKpi extends StatelessWidget {
  final List<Widget> tuiles;
  const GrilleKpi(this.tuiles, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final colonnes = c.maxWidth >= 640 ? 4 : 2;
        final largeur = (c.maxWidth - (colonnes - 1) * 8) / colonnes;
        return Wrap(spacing: 8, runSpacing: 8, children: [for (final t in tuiles) SizedBox(width: largeur, child: t)]);
      });
}

/// Titre de section en petites capitales grises (« À SURVEILLER », « VENTES »).
/// [couleur] (style d'icônes P3, 3.9.0) : titre de cette couleur précédé d'une barre de la même couleur.
class TitreSection extends StatelessWidget {
  final String texte;
  final EdgeInsets marge;
  final Color? couleur;
  const TitreSection(this.texte, {super.key, this.marge = const EdgeInsets.fromLTRB(4, 14, 4, 6), this.couleur});

  @override
  Widget build(BuildContext context) {
    final titre = Semantics(
      header: true,
      child: Text(texte.toUpperCase(),
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: couleur ?? Charte.gris)),
    );
    return Padding(
      padding: marge,
      child: couleur == null
          ? titre
          : Row(children: [
              Container(width: 4, height: 16, decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Expanded(child: titre),
            ]),
    );
  }
}

/// Carte blanche arrondie, avec bande de couleur à gauche (gravité, ancienneté) et action facultative.
class CarteBande extends StatelessWidget {
  final Widget child;
  final Color? bande;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const CarteBande({super.key, required this.child, this.bande, this.onTap, this.padding = const EdgeInsets.fromLTRB(14, 12, 12, 12)});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (bande != null) Container(width: 5, color: bande),
                Expanded(child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Padding(padding: padding, child: child))),
              ]),
            ),
          ),
        ),
      );
}

enum Ton { vert, ambre, rouge, bleu, gris }

/// Étiquette de statut (fond clair, texte foncé ≥ 4,5:1) : « À l'heure », « +22 min », « Absent »…
class Etiquette extends StatelessWidget {
  final String texte;
  final Ton ton;
  const Etiquette(this.texte, {super.key, this.ton = Ton.bleu});

  static (Color, Color) couleurs(Ton t) => switch (t) {
        Ton.vert => (Charte.vertClair, Charte.vertTexte),
        Ton.ambre => (Charte.ambreClair, Charte.ambreTexte),
        Ton.rouge => (Charte.rougeClair, Charte.rougeTexte),
        Ton.bleu => (Charte.bleuClair, Charte.navy),
        Ton.gris => (Charte.grisClair, Charte.grisTexte),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = couleurs(ton);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(texte, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

/// Icône sur pastille bleu clair (lignes de menu, tuiles).
class IconeMenu extends StatelessWidget {
  final IconData icone;
  final double taille;
  final Color fond;
  final Color couleur;

  /// Icône illustrée (style P4, chemin de l'image) : montrée à la place de l'icône, sans pastille ; [icone] sert de
  /// repli si l'image manque.
  final String? illustration;
  const IconeMenu(this.icone, {super.key, this.taille = 36, this.fond = Charte.bleuClair, this.couleur = Charte.navy, this.illustration});

  @override
  Widget build(BuildContext context) {
    final image = illustration;
    if (image != null) return IconeIllustree(image, taille: taille, repli: icone, couleurRepli: couleur);
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(taille * 0.3)),
      child: Icon(icone, color: couleur, size: taille * 0.55),
    );
  }
}

/// Tuile de menu (présentation A) : icône et titre sur carte blanche. [couleurIcone], [fondIcone], [fond] : style
/// des icônes choisi (apparence_accueil.dart ; par défaut, l'apparence d'origine).
class TuileMenu extends StatelessWidget {
  final IconData icone;
  final String titre;
  final VoidCallback onTap;
  final Color couleurIcone;
  final Color fondIcone;
  final Color fond;

  /// Icône illustrée (style P4) ; null : icône Material.
  final String? illustration;
  const TuileMenu(
      {super.key,
      required this.icone,
      required this.titre,
      required this.onTap,
      this.couleurIcone = Charte.navy,
      this.fondIcone = Charte.bleuClair,
      this.fond = Charte.blanc,
      this.illustration});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconeMenu(icone, fond: fondIcone, couleur: couleurIcone, illustration: illustration),
                  const SizedBox(height: 6),
                  Text(titre,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Charte.encre)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Grille de tuiles (3 colonnes sur téléphone, plus sur grand écran), hauteur libre (grande police).
class GrilleTuiles extends StatelessWidget {
  final List<Widget> tuiles;
  const GrilleTuiles(this.tuiles, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final colonnes = (c.maxWidth / 112).floor().clamp(2, 6);
        final largeur = (c.maxWidth - (colonnes - 1) * 8) / colonnes;
        return Wrap(spacing: 8, runSpacing: 8, children: [for (final t in tuiles) SizedBox(width: largeur, child: t)]);
      });
}

/// Ligne de menu (présentation B) : icône, titre, sous-titre, chevron.
class LigneMenu extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String? sousTitre;
  final VoidCallback onTap;
  final Widget? fin;

  /// Style des icônes choisi (apparence_accueil.dart ; par défaut, l'apparence d'origine).
  final Color couleurIcone;
  final Color fondIcone;
  final Color fond;

  /// Icône illustrée (style P4) ; null : icône Material.
  final String? illustration;
  const LigneMenu(
      {super.key,
      required this.icone,
      required this.titre,
      this.sousTitre,
      required this.onTap,
      this.fin,
      this.couleurIcone = Charte.navy,
      this.fondIcone = Charte.bleuClair,
      this.fond = Charte.blanc,
      this.illustration});

  @override
  Widget build(BuildContext context) => Material(
        color: fond,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Charte.grisClair))),
            child: Row(children: [
              IconeMenu(icone, taille: 34, fond: fondIcone, couleur: couleurIcone, illustration: illustration),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Charte.encre)),
                  if (sousTitre != null) Text(sousTitre!, style: const TextStyle(fontSize: 12.5, color: Charte.gris)),
                ]),
              ),
              fin ?? const Icon(Icons.chevron_right, color: Charte.gris),
            ]),
          ),
        ),
      );
}

/// Grande carte-question (présentation C) : icône sur fond coloré, titre, explication.
class GrandeCarte extends StatelessWidget {
  final IconData icone;
  final Color fond;
  final String titre;
  final String? sousTitre;
  final VoidCallback onTap;
  const GrandeCarte({super.key, required this.icone, required this.fond, required this.titre, this.sousTitre, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                IconeMenu(icone, taille: 46, fond: fond),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Charte.encre)),
                    if (sousTitre != null) Text(sousTitre!, style: const TextStyle(fontSize: 13, color: Charte.gris)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Charte.gris),
              ]),
            ),
          ),
        ),
      );
}

/// Encadré d'erreur (fond rouge clair) ou d'avertissement (fond ambre clair).
class Encadre extends StatelessWidget {
  final String? titre;
  final String texte;
  final IconData icone;
  final bool avertissement;

  /// Clé du titre (tests), annoncé par le lecteur d'écran à chaque changement.
  final Key? cleTitre;
  const Encadre({super.key, this.titre, required this.texte, this.icone = Icons.cloud_off, this.avertissement = false, this.cleTitre});

  @override
  Widget build(BuildContext context) {
    final fond = avertissement ? Charte.ambreClair : Charte.rougeClair;
    final bord = avertissement ? Charte.ambreBord : Charte.rougeBord;
    final fg = avertissement ? Charte.ambreTexte : Charte.rougeTexte;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(12), border: Border.all(color: bord)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, color: fg, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (titre != null)
              Semantics(liveRegion: true, child: Text(titre!, key: cleTitre, style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.bold))),
            Text(texte, style: TextStyle(color: fg, fontSize: 13.5, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

/// Carte de section (réglages, formulaires) : titre bleu et contenu.
class CarteSection extends StatelessWidget {
  final String? titre;
  final IconData? icone;
  final List<Widget> enfants;
  final EdgeInsets padding;
  const CarteSection({super.key, this.titre, this.icone, required this.enfants, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14)});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Charte.blanc,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Charte.ombre, blurRadius: 4, offset: Offset(0, 1))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (titre != null)
              Padding(
                padding: EdgeInsets.fromLTRB(padding.left < 8 ? 16 : 0, 0, padding.right < 8 ? 16 : 0, 8),
                child: Row(children: [
                  if (icone != null) ...[Icon(icone, color: Charte.navy, size: 20), const SizedBox(width: 8)],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(titre!, style: const TextStyle(color: Charte.navy, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
            ...enfants,
          ]),
        ),
      );
}

/// Montant lisible : « 1 245 300 F » (espaces insécables).
String formaterMontant(num? v) {
  if (v == null) return '—';
  final entier = v.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < entier.length; i++) {
    if (i > 0 && (entier.length - i) % 3 == 0) b.write(' ');
    b.write(entier[i]);
  }
  return '${v < 0 ? '-' : ''}$b F';
}

/// Date du jour lisible : « lundi 12 octobre ».
String dateLisible(DateTime d) {
  const jours = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
  const mois = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
  return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';
}
