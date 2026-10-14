// lib/ui/taille_ecran.dart
// TAILLE DE L'ÉCRAN — module commun aux applications Prestige, repris TEL QUEL de Prestige Inventaire
// (4.13.1) et de Prestige Mobile (4.0.1) dans Prestige Pharmacien 3.7.0. Documentation : docs/TAILLE_ECRAN.md.
//
// But : sur les petits écrans (Sunmi V2s 5,45″ : 720 × 1440 px, densité 2 → 360 × 720 dp ; Sunmi V3 /
// V3H / V3mix 360 × 640 dp), réduire TOUTE l'interface d'un seul réglage, sans retoucher aucun écran :
// chaque écran reçoit plus de place (en dp) et le rendu est réduit d'autant.
//
//   Automatique (défaut) : facteur 1,0 — rien ne change (taille définie par Android) ; SUR UN PETIT
//                          ÉCRAN ([TailleEcranReglage.petitEcran] : côté long < 740 dp ou côté court
//                          < 340 dp, ex. Sunmi V2s 360 × 720 dp), Compact est appliqué d'office ;
//   Compact              : facteur 0,9 — 360 × 720 dp deviennent 400 × 800 dp ;
//   Très compact         : facteur 0,8 — 360 × 720 dp deviennent 450 × 900 dp.
//
// Principe : [EchelleInterface] se place AU-DESSUS de MaterialApp (donc au-dessus du navigateur, des
// fenêtres, des feuilles du bas, des messages et de tous les calques). Il publie une MediaQuery dont la
// taille, les marges système (barre d'état, encoche), le clavier (viewInsets) et la densité sont
// ramenés à l'échelle (devicePixelRatio effectif × facteur), puis réduit le rendu du facteur par une
// transformation (FittedBox). Les touchers suivent la même transformation (aucun décalage), le clavier
// système et la position du curseur restent justes. Le texte reste net : la réduction est appliquée au
// rendu vectoriel, pas à une image.
//
// Ce qui n'est PAS concerné (Prestige Pharmacien) : les PDF et impressions (package printing : pages A4 /
// ticket Z mises en page en points PDF, sans lien avec l'écran ; la fenêtre d'impression est native), les
// fichiers exportés (Présences).
//
// Le réglage est lu UNE fois au lancement ([TailleEcranReglage.charger], dans main()) et appliqué au
// prochain lancement ; [TailleEcranReglage.appliquerMaintenant] l'applique tout de suite (l'interface est
// reconstruite et revient à l'accueil, sans perdre la session : providers gardés au-dessus).
import 'dart:ui' show DisplayFeature;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Taille de l'interface choisie dans les réglages.
enum TailleEcran {
  automatique('Automatique', 1.0),
  compact('Compact', 0.9),
  tresCompact('Très compact', 0.8);

  final String libelle;

  /// Facteur de réduction du rendu (1,0 = inchangé).
  final double facteur;
  const TailleEcran(this.libelle, this.facteur);
}

/// Réglage mémorisé sur l'appareil (clé [cle]) et taille appliquée à la racine ([active]).
class TailleEcranReglage {
  TailleEcranReglage._();

  static const cle = 'taille_ecran_v1';

  /// Taille enregistrée (celle du prochain lancement).
  static TailleEcran enregistree = TailleEcran.automatique;

  /// Taille réellement appliquée à l'interface (lue au lancement).
  static final ValueNotifier<TailleEcran> active = ValueNotifier<TailleEcran>(TailleEcran.automatique);

  /// Différente de la taille appliquée : le changement attend le prochain lancement.
  static bool get enAttente => enregistree != active.value;

  static TailleEcran depuisNom(String? nom) => TailleEcran.values.asNameMap()[nom] ?? TailleEcran.automatique;

  /// À appeler au lancement (avant runApp) : lit le réglage et l'applique.
  static Future<void> charger() async {
    try {
      enregistree = depuisNom((await SharedPreferences.getInstance()).getString(cle));
    } catch (_) {
      enregistree = TailleEcran.automatique;
    }
    active.value = enregistree;
  }

  /// Enregistre [t] (appliqué au prochain lancement).
  static Future<void> enregistrer(TailleEcran t) async {
    enregistree = t;
    try {
      await (await SharedPreferences.getInstance()).setString(cle, t.name);
    } catch (_) {}
  }

  /// « Relancer maintenant » : l'interface est reconstruite à la taille enregistrée.
  static void appliquerMaintenant() => active.value = enregistree;

  // ---------- Automatique sur petit écran ----------

  /// Seuils en taille LOGIQUE (dp), calculés sur l'écran réel (avant toute réduction), indépendants de
  /// l'orientation. Ce qui manque aux petits terminaux, c'est la HAUTEUR (côté long) :
  ///  - Sunmi V2s 720 × 1440 px, densité 2 → 360 × 720 dp (≈ 360 × 672 sans la barre de navigation) :
  ///    petit ; Sunmi V3 / V3H / V3mix 1080 × 1920, ×3 → 360 × 640 dp : petit ;
  ///  - téléphones courants 1080 × 2400 px : 411 × 914 dp (×2,625), 392 × 873 (×2,75) et même
  ///    360 × 800 dp (×3, Samsung), soit 752 dp sans la barre de navigation : taille normale.
  /// Le seuil de largeur seul (< 380 dp) ne convient pas : il prendrait les Samsung 360 × 800 dp.
  static const seuilCoteLong = 740.0;

  /// Écrans très étroits (≤ 320 dp) : petits quelle que soit leur hauteur.
  static const seuilCoteCourt = 340.0;

  /// L'écran de taille logique [ecran] (dp, avant réduction) est-il petit ?
  static bool petitEcran(Size ecran) => !ecran.isEmpty && (ecran.longestSide < seuilCoteLong || ecran.shortestSide < seuilCoteCourt);

  /// Taille réellement appliquée pour le choix [choisie] sur l'écran [ecran] (dp) : Automatique devient
  /// Compact sur un petit écran ; Compact et Très compact (choix manuels) restent prioritaires.
  static TailleEcran effective(TailleEcran choisie, Size ecran) =>
      choisie == TailleEcran.automatique && petitEcran(ecran) ? TailleEcran.compact : choisie;

  /// Taille logique RÉELLE de l'écran (dp), lue sur la vue : la même à l'intérieur de l'interface
  /// réduite (dont la MediaQuery est agrandie).
  static Size ecranReel(BuildContext context) {
    final v = View.maybeOf(context);
    if (v == null) return MediaQuery.maybeSizeOf(context) ?? Size.zero;
    return v.physicalSize / v.devicePixelRatio;
  }

  /// Automatique est-il ramené à Compact sur cet écran ?
  static bool compactAutomatique(BuildContext context) => petitEcran(ecranReel(context));

  /// Tests : retour à l'état initial.
  @visibleForTesting
  static void reinitialiser() {
    enregistree = TailleEcran.automatique;
    active.value = TailleEcran.automatique;
  }
}

/// Réduit toute l'interface [child] du facteur [facteur] (voir l'en-tête du fichier). À placer
/// au-dessus de MaterialApp. Facteur 1,0 : [child] tel quel (aucun widget ajouté).
class EchelleInterface extends StatelessWidget {
  final double facteur;
  final Widget child;
  const EchelleInterface({super.key, required this.facteur, required this.child});

  /// Données d'écran vues par l'interface réduite : tailles et marges divisées par [facteur], densité
  /// multipliée (un dp de l'interface = [facteur] dp réels).
  static MediaQueryData donnees(MediaQueryData mq, double facteur) {
    if (facteur == 1.0) return mq;
    Rect r(Rect b) => Rect.fromLTRB(b.left / facteur, b.top / facteur, b.right / facteur, b.bottom / facteur);
    return mq.copyWith(
      size: mq.size / facteur,
      devicePixelRatio: mq.devicePixelRatio * facteur,
      padding: mq.padding / facteur,
      viewPadding: mq.viewPadding / facteur,
      viewInsets: mq.viewInsets / facteur,
      systemGestureInsets: mq.systemGestureInsets / facteur,
      displayFeatures: [for (final f in mq.displayFeatures) DisplayFeature(bounds: r(f.bounds), type: f.type, state: f.state)],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (facteur == 1.0) return child;
    final mq = MediaQuery.of(context);
    final interne = donnees(mq, facteur);
    return MediaQuery(
      data: interne,
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(width: interne.size.width, height: interne.size.height, child: child),
      ),
    );
  }
}

/// Racine qui applique la taille active ([TailleEcranReglage.active]) : quand elle change
/// (« Relancer maintenant »), toute l'interface sous [child] est reconstruite. Automatique : Compact sur
/// un petit écran ([TailleEcranReglage.effective]).
class RacineTailleEcran extends StatelessWidget {
  final Widget child;
  const RacineTailleEcran({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TailleEcran>(
        valueListenable: TailleEcranReglage.active,
        builder: (context, t, __) => KeyedSubtree(
          key: ValueKey('taille-${t.name}'),
          // Au-dessus de l'interface réduite : la MediaQuery est celle de l'écran réel (suivie).
          child: EchelleInterface(
            facteur: TailleEcranReglage.effective(t, MediaQuery.maybeSizeOf(context) ?? TailleEcranReglage.ecranReel(context)).facteur,
            child: child,
          ),
        ),
      );
}
