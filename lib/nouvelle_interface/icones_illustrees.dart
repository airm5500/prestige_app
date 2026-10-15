// lib/nouvelle_interface/icones_illustrees.dart
// Proposition P4 « icônes illustrées » (3.10.0, demande du pharmacien : « pourquoi ne pas utiliser des icônes
// réelles ? pour mieux apprécier, c'est une application professionnelle »). Une vraie icône en couleur par menu, par
// onglet de la barre du bas : collection **Fluent Emoji** de Microsoft, style « 3D » (licence MIT, usage commercial
// permis ; texte de la licence : assets/icones_illustrees/LICENCE_FLUENT_EMOJI.txt, enregistré aussi dans les
// licences de l'application ; détail et correspondances : docs/ICONES_ILLUSTREES.md).
//  - EMBARQUÉES dans l'application (assets/icones_illustrees/, 144 × 144 px, ~550 Ko au total) : aucun
//    téléchargement, ni au lancement ni ensuite ; fonctionne sans Internet ;
//  - décodées à la taille affichée (cacheWidth) : peu de mémoire, même sur les terminaux Sunmi ;
//  - une icône manquante ou illisible n'empêche rien : l'icône Material d'origine la remplace ([IconeIllustree]) ;
//  - décoratives pour le lecteur d'écran (le titre du menu est lu, comme avant).
// Réglage « Style des icônes » : P4 s'ajoute à Actuel / P1 / P2 / P3 ; depuis la 3.10.1 (décision du pharmacien), P4
// est le style PAR DÉFAUT et le réglage est visible (administrateur ou pharmacien), apparence_accueil.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dossier des icônes (déclaré dans pubspec.yaml).
const dossierIconesIllustrees = 'assets/icones_illustrees/';

/// Licence de la collection (texte MIT de Microsoft, embarqué).
const licenceIconesIllustrees = '${dossierIconesIllustrees}LICENCE_FLUENT_EMOJI.txt';

/// Chemin de l'icône [nom] (« camion » → assets/icones_illustrees/camion.png).
String iconeIllustree(String nom) => '$dossierIconesIllustrees$nom.png';

/// Icône illustrée de chaque menu (clé : titre du menu, le même que l'ancien accueil). Choix : l'objet que le
/// pharmacien associe à la fonction (camion = livraison, gélule = traitement, sablier = péremption…).
const illustrationsMenus = <String, String>{
  // Ventes & caisse
  'Détail CA': 'sac_argent',
  'CA Global': 'calendrier',
  'Récap de caisse': 'ticket',
  'Rapport d\'Activité': 'presse_papiers',
  'Stat TVA': 'boulier',
  'Annulation Ventes': 'interdit',
  'Retraits et abandons': 'corbeille',
  'Ventes modifiées': 'crayon',
  // Crédits & clients
  'CA Crédit': 'carte_bancaire',
  'Suivi Crédit': 'registre',
  'Avis': 'etoile',
  'Rappels traitement': 'gelule',
  // Analyses
  'Marge Produits Vendus': 'piece',
  'Tableau: Analyses': 'courbe_hausse',
  'Tableau: Ratios': 'balance',
  'Analyse Article': 'loupe',
  'Suivi 20/80': 'trophee',
  'Analyse de garde': 'lune',
  'CA emplacement / famille': 'classeurs',
  // Stock
  'Suivi Péremption': 'sablier',
  'Evolution Stock': 'histogramme',
  'Valorisation': 'diamant',
  'Suivi Ajustements': 'outils',
  'Suggestions': 'ampoule',
  'Etat de Stock': 'colis',
  'Alertes': 'cloche',
  'Prévisions': 'telescope',
  // Fournisseurs & achats
  'Etat Contrôle Achat': 'coche',
  'Analyse Saisies BL': 'memo',
  'Achats Fourn.': 'chariot',
  'Retours Fournisseurs': 'fleche_retour',
  'Visualisation BL': 'camion',
  'Pointage BL': 'case_cochee',
  // Équipe
  'Fichier Journal': 'carnet',
  'Présences': 'badge',
};

/// Icônes des onglets de la barre du bas (clé : nom de l'onglet, OngletAccueil.name).
const illustrationsOnglets = <String, String>{
  'accueil': 'maison',
  'analyses': 'courbe_hausse',
  'equipe': 'equipe',
  'pilotage': 'boussole',
};

/// Chemin de l'icône illustrée du menu [titre] (null : pas d'icône prévue, l'icône Material reste).
String? illustrationMenu(String titre) {
  final n = illustrationsMenus[titre];
  return n == null ? null : iconeIllustree(n);
}

/// Chemin de l'icône illustrée de l'onglet [nom].
String? illustrationOnglet(String nom) {
  final n = illustrationsOnglets[nom];
  return n == null ? null : iconeIllustree(n);
}

/// Icône illustrée de [taille] dp, décodée à la taille affichée. [repli] : icône Material montrée si l'image manque.
/// [attenuee] : onglet inactif de la barre du bas (gris, à demi transparent : l'onglet actif se distingue aussi par
/// son libellé en gras, jamais par la couleur seule).
class IconeIllustree extends StatelessWidget {
  final String chemin;
  final double taille;
  final IconData repli;
  final Color couleurRepli;
  final bool attenuee;
  const IconeIllustree(this.chemin, {super.key, this.taille = 36, required this.repli, required this.couleurRepli, this.attenuee = false});

  /// Gris (luminance) : onglet inactif.
  static const _gris = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0.55, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final cote = (taille * ratio).ceil().clamp(16, 144);
    Widget image = Image.asset(
      chemin,
      width: taille,
      height: taille,
      cacheWidth: cote,
      cacheHeight: cote,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Icon(repli, size: taille * 0.8, color: couleurRepli),
    );
    if (attenuee) image = ColorFiltered(colorFilter: _gris, child: image);
    return SizedBox(width: taille, height: taille, child: image);
  }
}

bool _licenceEnregistree = false;

/// Ajoute la licence MIT des icônes aux licences de l'application (page « Licences » de Flutter). Le texte n'est lu
/// que si la page est ouverte. Sans effet au second appel.
void enregistrerLicenceIcones() {
  if (_licenceEnregistree) return;
  _licenceEnregistree = true;
  LicenseRegistry.addLicense(() async* {
    try {
      final texte = await rootBundle.loadString(licenceIconesIllustrees);
      yield LicenseEntryWithLineBreaks(const ['Fluent Emoji (Microsoft) — icônes illustrées'], texte);
    } catch (_) {
      // Licence illisible : rien à afficher (les icônes restent utilisables).
    }
  });
}
