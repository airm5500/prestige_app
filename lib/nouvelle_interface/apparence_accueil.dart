// lib/nouvelle_interface/apparence_accueil.dart
// Deux réglages d'apparence de l'accueil de la nouvelle interface (3.9.0, complétés en 3.10.0), mémorisés sur
// l'appareil pour tous les comptes :
//  - « Menus de l'accueil » (décision du pharmacien 3.10.0 : « une rubrique par page, mais présente et on valide les
//    3 cas ») — trois dispositions, valeur mémorisée 0 / 1 / 2 :
//      0 = tout sur une page (défaut, comme avant) ;
//      1 = une rubrique par page (famille de menus par page ; même valeur qu'en 3.9.0 « Par pages ») ;
//      2 = 6 tuiles par page (nombre fixe, comme l'ancienne interface) ;
//    pages balayées à gauche / droite, indicateur de page — présentations A et B sur téléphone ; B sur tablette
//    (deux colonnes) et C (cinq questions) restent sur une page, la pagination n'y a pas de sens.
//    MODIFIABLE PAR L'ADMINISTRATEUR OU LE PHARMACIEN SEULEMENT (décision 3.10.0) : compte « admin », ou profil
//    administrateur / pharmacien donné par le serveur (vague1/profil_acces.dart) ; les autres comptes voient le choix,
//    verrouillé, avec l'explication (plus de code administrateur pour ce réglage) ;
//  - « Style des icônes » (3.10.1, décision du pharmacien : P4 PAR DÉFAUT ; réglage visible, mêmes droits que
//    « Menus de l'accueil » : administrateur ou pharmacien ; migration : un style jamais choisi passe en P4, un style
//    choisi explicitement est gardé) : Actuel (style d'origine) ; P1 couleur par famille (pastille douce derrière l'icône) ; P2 tuiles teintées
//    (fond de tuile teinté par famille, icône colorée) ; P3 icônes colorées sur fond blanc et en-têtes de famille
//    colorés ; P4 icônes illustrées (3.10.0 : vraies icônes en couleur, Fluent Emoji de Microsoft, licence MIT,
//    icones_illustrees.dart). P1 à P4 marquent aussi l'onglet actif de la barre du bas.
//    Captures : docs/maquettes/propositions_couleurs/.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'charte.dart';
import 'menus.dart';
import 'presentation.dart';
import 'vague1/profil_acces.dart';

/// Disposition des menus de l'accueil (valeur mémorisée 0 / 1 / 2 ; 1 = « Par pages » de la 3.9.0).
enum AffichageMenus {
  unePage(0, 'Tout sur une page', 'Tous les menus à la suite (comme aujourd\'hui)'),
  parRubrique(1, 'Une rubrique par page', 'Une famille de menus par page : balayez à gauche ou à droite'),
  parSix(2, '6 tuiles par page', 'Six menus par page, comme l\'ancienne interface : balayez à gauche ou à droite');

  final int valeur;
  final String libelle;
  final String description;
  const AffichageMenus(this.valeur, this.libelle, this.description);

  /// Valeur mémorisée → disposition ; toute valeur inconnue (ou absente) → « Tout sur une page » (défaut).
  static AffichageMenus depuis(int? v) => values.where((a) => a.valeur == v).firstOrNull ?? unePage;

  /// Menus répartis en pages (rubrique ou 6 tuiles).
  bool get parPages => this != unePage;
}

/// Nombre de menus par page en disposition « 6 tuiles par page ».
const menusParPage = 6;

/// Style des icônes (propositions visuelles ; « Actuel » par défaut).
enum StyleIcones {
  actuel('Actuel', 'Icônes bleu nuit sur pastille bleu clair (style d\'origine)'),
  p1('P1 · Couleur par famille', 'Pastille de couleur douce derrière chaque icône'),
  p2('P2 · Tuiles teintées', 'Fond de tuile légèrement teinté, icône colorée'),
  p3('P3 · Icônes colorées', 'Icônes colorées sur fond blanc, en-têtes de famille colorés'),
  p4('P4 · Icônes illustrées', 'Vraies icônes en couleur pour chaque menu (Fluent Emoji, Microsoft, licence MIT)');

  final String libelle;
  final String description;
  const StyleIcones(this.libelle, this.description);

  /// Icônes illustrées (images) à la place des icônes Material.
  bool get illustre => this == p4;
}

/// Couleurs d'une famille : icône (foncée), pastille (douce), fond de tuile (très clair).
class Teinte {
  final Color icone;
  final Color pastille;
  final Color tuile;
  const Teinte(this.icone, this.pastille, this.tuile);
}

/// Couleurs de chaque famille (Charte) ; « Alertes » a sa propre teinte.
const teinteAlertes = Teinte(Charte.familleAlertes, Charte.familleAlertesPastille, Charte.familleAlertesTuile);

Teinte teinteFamille(Famille f) => switch (f) {
      Famille.ventes => const Teinte(Charte.familleVentes, Charte.familleVentesPastille, Charte.familleVentesTuile),
      Famille.credits => const Teinte(Charte.familleCredits, Charte.familleCreditsPastille, Charte.familleCreditsTuile),
      Famille.analyses => const Teinte(Charte.familleAnalyses, Charte.familleAnalysesPastille, Charte.familleAnalysesTuile),
      Famille.stock => const Teinte(Charte.familleStock, Charte.familleStockPastille, Charte.familleStockTuile),
      Famille.fournisseurs => const Teinte(Charte.familleFournisseurs, Charte.familleFournisseursPastille, Charte.familleFournisseursTuile),
      Famille.equipe => const Teinte(Charte.familleEquipe, Charte.familleEquipePastille, Charte.familleEquipeTuile),
    };

/// Teinte d'un menu (sa famille ; « Alertes » en rouge).
Teinte teinteMenu(MenuModule m) => m.titre == 'Alertes' ? teinteAlertes : teinteFamille(m.famille);

/// Apparence d'une icône de menu selon le style : couleur de l'icône, fond de sa pastille, fond de la tuile / ligne.
class ApparenceIcone {
  final Color icone;
  final Color pastille;
  final Color fond;
  const ApparenceIcone({required this.icone, required this.pastille, required this.fond});

  /// Style « Actuel » : bleu nuit sur bleu clair, tuile blanche (inchangé).
  static const actuelle = ApparenceIcone(icone: Charte.navy, pastille: Charte.bleuClair, fond: Charte.blanc);

  static ApparenceIcone de(StyleIcones s, Teinte t) => switch (s) {
        StyleIcones.actuel => actuelle,
        StyleIcones.p1 => ApparenceIcone(icone: t.icone, pastille: t.pastille, fond: Charte.blanc),
        StyleIcones.p2 => ApparenceIcone(icone: t.icone, pastille: Charte.blanc, fond: t.tuile),
        StyleIcones.p3 => ApparenceIcone(icone: t.icone, pastille: Charte.blanc, fond: Charte.blanc),
        // P4 : l'image illustrée remplace l'icône ; sa couleur ne sert qu'au repli (image absente).
        StyleIcones.p4 => const ApparenceIcone(icone: Charte.navy, pastille: Charte.blanc, fond: Charte.blanc),
      };

  static ApparenceIcone pourMenu(StyleIcones s, MenuModule m) => de(s, teinteMenu(m));
}

/// Couleur des en-têtes de famille (P3 seulement ; sinon null = gris d'origine).
Color? couleurEnTeteFamille(StyleIcones s, Famille f) => s == StyleIcones.p3 ? teinteFamille(f).icone : null;

class ApparenceAccueilPrefs {
  ApparenceAccueilPrefs._();

  static const cleAffichage = 'affichage_menus_accueil_v1';
  static const cleStyle = 'style_icones_v1';

  static final ValueNotifier<AffichageMenus> affichage = ValueNotifier(AffichageMenus.unePage);
  /// Style par défaut (décision du pharmacien, 3.10.1) : P4 « icônes illustrées ».
  static const styleParDefaut = StyleIcones.p4;

  static final ValueNotifier<StyleIcones> style = ValueNotifier(styleParDefaut);

  /// Les deux réglages ensemble (reconstruire l'accueil quand l'un change).
  static Listenable get ecoute => Listenable.merge([affichage, style]);

  static Future<void> charger() async {
    try {
      final p = await SharedPreferences.getInstance();
      affichage.value = AffichageMenus.depuis(p.getInt(cleAffichage));
      style.value = styleDepuis(p.getString(cleStyle));
    } catch (_) {
      affichage.value = AffichageMenus.unePage;
      style.value = styleParDefaut;
    }
  }

  /// Migration 3.10.1 : aucun style mémorisé (jamais choisi) ou valeur inconnue → P4, le nouveau défaut ; un style
  /// CHOISI explicitement (« actuel », « p1 »… mémorisé) est gardé. Rien n'est écrit : le choix reste « non fait »
  /// tant que l'utilisateur ne touche pas le réglage.
  static StyleIcones styleDepuis(String? v) => StyleIcones.values.asNameMap()[v] ?? styleParDefaut;

  /// Valeurs par défaut (tests).
  static void reinitialiser() {
    affichage.value = AffichageMenus.unePage;
    style.value = styleParDefaut;
  }

  /// « Menus de l'accueil » : modifiable par l'administrateur (compte « admin ») ou un profil administrateur /
  /// pharmacien (décision du pharmacien, 3.10.0). Aucun code administrateur ne le déverrouille pour les autres.
  static bool peutChangerAffichage(BuildContext context) =>
      PresentationPrefs.estAdministrateur(context) || ProfilAcces.responsable;

  /// Explication montrée aux autres comptes.
  static const explicationAffichageVerrouille =
      'Réservé à l\'administrateur ou au pharmacien : ce réglage n\'est pas modifiable avec ce compte.';

  static Future<bool> changerAffichage(BuildContext context, AffichageMenus a) async {
    if (a == affichage.value) return true;
    if (!peutChangerAffichage(context)) return false;
    affichage.value = a;
    try {
      await (await SharedPreferences.getInstance()).setInt(cleAffichage, a.valeur);
    } catch (_) {}
    return true;
  }

  /// Style des icônes (3.10.1 : réglage visible, mêmes droits que « Menus de l'accueil » : administrateur ou
  /// pharmacien). Le choix est mémorisé, même s'il est égal au défaut (choix explicite gardé à l'avenir).
  static Future<bool> changerStyle(BuildContext context, StyleIcones s) async {
    if (!peutChangerAffichage(context)) return false;
    if (s == style.value) {
      try {
        await (await SharedPreferences.getInstance()).setString(cleStyle, s.name);
      } catch (_) {}
      return true;
    }
    style.value = s;
    try {
      await (await SharedPreferences.getInstance()).setString(cleStyle, s.name);
    } catch (_) {}
    return true;
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Menus par pages
// ---------------------------------------------------------------------------------------------------------------

/// Une page de menus : titre (famille), couleur facultative du titre, contenu défilant.
class PageMenus {
  final String titre;
  final Color? couleur;
  final Widget contenu;
  const PageMenus(this.titre, this.contenu, {this.couleur});
}

/// Menus par pages : en-tête « ‹ Titre · 2 / 6 › » (boutons 48 dp libellés), pages balayées à gauche / droite,
/// indicateur de page (points) en bas, comme l'ancienne interface.
class PagesMenus extends StatefulWidget {
  final List<PageMenus> pages;
  const PagesMenus({super.key = const Key('pages_menus'), required this.pages});

  @override
  State<PagesMenus> createState() => _PagesMenusState();
}

class _PagesMenusState extends State<PagesMenus> {
  final _controleur = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _aller(int i) {
    if (i < 0 || i >= widget.pages.length) return;
    _controleur.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.pages.length;
    if (n == 0) return const SizedBox.shrink();
    final page = _page.clamp(0, n - 1);
    final p = widget.pages[page];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Row(children: [
          IconButton(
            key: const Key('page_menus_precedente'),
            tooltip: 'Page précédente',
            onPressed: page > 0 ? () => _aller(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              label: 'Page ${page + 1} sur $n : ${p.titre}',
              excludeSemantics: true,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: p.titre.toUpperCase(), style: TextStyle(color: p.couleur ?? Charte.gris, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  TextSpan(text: '  ${page + 1} / $n', style: const TextStyle(color: Charte.gris, fontWeight: FontWeight.w600)),
                ]),
                key: const Key('page_menus_titre'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          IconButton(
            key: const Key('page_menus_suivante'),
            tooltip: 'Page suivante',
            onPressed: page < n - 1 ? () => _aller(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
      ),
      Expanded(
        child: PageView.builder(
          key: const Key('pages_menus_defilement'),
          controller: _controleur,
          itemCount: n,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) => widget.pages[i].contenu,
        ),
      ),
      ExcludeSemantics(
        child: Padding(
          key: const Key('indicateur_pages'),
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < n; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: i == page ? 24 : 8,
                decoration: BoxDecoration(
                  color: i == page ? (widget.pages[i].couleur ?? Charte.navy) : Charte.bordure,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}
