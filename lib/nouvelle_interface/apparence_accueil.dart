// lib/nouvelle_interface/apparence_accueil.dart
// Deux réglages d'apparence de l'accueil de la nouvelle interface (3.9.0), mémorisés sur l'appareil pour tous les
// comptes, changés comme la présentation (compte « admin » directement, code administrateur pour les autres) :
//  - « Menus de l'accueil » (demande du pharmacien, valeur 0 / 1) : 0 = sur une page (défaut, comme avant) ;
//    1 = par pages : les menus défilent par pages, une famille par page, avec indicateur de page et balayage
//    gauche / droite (comme l'ancienne interface) — présentations A et B sur téléphone ; B sur tablette (deux
//    colonnes) et C (cinq questions) restent sur une page, la pagination n'y a pas de sens ;
//  - « Style des icônes » (PROPOSITIONS visuelles, réglage caché : visible pour le compte « admin » seulement) :
//    Actuel (défaut, inchangé) ; P1 couleur par famille (pastille douce derrière l'icône) ; P2 tuiles teintées
//    (fond de tuile teinté par famille, icône colorée) ; P3 icônes colorées sur fond blanc et en-têtes de famille
//    colorés. P1 à P3 colorent aussi l'onglet actif de la barre du bas (icône, libellé et indicateur par onglet).
//    Captures : docs/maquettes/propositions_couleurs/. Le choix final revient au pharmacien.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/pin_code_dialog.dart';
import 'charte.dart';
import 'menus.dart';
import 'presentation.dart';

/// Disposition des menus de l'accueil (valeur mémorisée 0 / 1).
enum AffichageMenus {
  unePage(0, 'Sur une page', 'Tous les menus à la suite (comme aujourd\'hui)'),
  parPages(1, 'Par pages', 'Une famille par page : balayez à gauche ou à droite');

  final int valeur;
  final String libelle;
  final String description;
  const AffichageMenus(this.valeur, this.libelle, this.description);

  static AffichageMenus depuis(int? v) => v == 1 ? parPages : unePage;
}

/// Style des icônes (propositions visuelles ; « Actuel » par défaut).
enum StyleIcones {
  actuel('Actuel', 'Icônes bleu nuit sur pastille bleu clair (par défaut)'),
  p1('P1 · Couleur par famille', 'Pastille de couleur douce derrière chaque icône'),
  p2('P2 · Tuiles teintées', 'Fond de tuile légèrement teinté, icône colorée'),
  p3('P3 · Icônes colorées', 'Icônes colorées sur fond blanc, en-têtes de famille colorés');

  final String libelle;
  final String description;
  const StyleIcones(this.libelle, this.description);
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
  static final ValueNotifier<StyleIcones> style = ValueNotifier(StyleIcones.actuel);

  /// Les deux réglages ensemble (reconstruire l'accueil quand l'un change).
  static Listenable get ecoute => Listenable.merge([affichage, style]);

  static Future<void> charger() async {
    try {
      final p = await SharedPreferences.getInstance();
      affichage.value = AffichageMenus.depuis(p.getInt(cleAffichage));
      style.value = StyleIcones.values.asNameMap()[p.getString(cleStyle)] ?? StyleIcones.actuel;
    } catch (_) {
      affichage.value = AffichageMenus.unePage;
      style.value = StyleIcones.actuel;
    }
  }

  /// Valeurs par défaut (tests).
  static void reinitialiser() {
    affichage.value = AffichageMenus.unePage;
    style.value = StyleIcones.actuel;
  }

  /// Même règle que la présentation : compte « admin » directement, code administrateur pour les autres.
  static Future<bool> _autorise(BuildContext context) async =>
      PresentationPrefs.estAdministrateur(context) || await PinCodeDialog.show(context);

  static Future<bool> changerAffichage(BuildContext context, AffichageMenus a) async {
    if (a == affichage.value) return true;
    if (!await _autorise(context)) return false;
    affichage.value = a;
    try {
      await (await SharedPreferences.getInstance()).setInt(cleAffichage, a.valeur);
    } catch (_) {}
    return true;
  }

  /// Style des icônes : réservé au compte « admin » (le réglage n'est pas montré aux autres comptes).
  static Future<bool> changerStyle(BuildContext context, StyleIcones s) async {
    if (s == style.value) return true;
    if (!PresentationPrefs.estAdministrateur(context)) return false;
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
