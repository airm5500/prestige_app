// lib/presences/presences_widgets.dart
// Petits éléments communs aux écrans « Présences » (dans le style actuel de l'application : AppBar sombre,
// cartes blanches arrondies). La refonte visuelle complète viendra à l'étape 3.
import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'presences_modeles.dart';

const couleurPrincipale = Color(0xFF0A2E3E);
const couleurEncre = Color(0xFF14213D);
const couleurGris = Color(0xFF5B6B82);
const couleurRetard = Color(0xFFB45309);
const couleurAbsent = Color(0xFFB91C1C);
const couleurPresent = Color(0xFF15803D);

/// Largeur à partir de laquelle on passe en mise en page « tablette » (deux colonnes).
const largeurTablette = 720.0;

bool estTablette(BuildContext context) => MediaQuery.sizeOf(context).width >= largeurTablette;

/// Message d'un échec (jamais de détail technique).
String messageErreur(Object e) => e is ApiLoadException ? e.message : 'Erreur inattendue. Réessayez.';

Color couleurStatut(StatutPresence s) => switch (s) {
      StatutPresence.absent => couleurAbsent,
      StatutPresence.enRetard => couleurRetard,
      StatutPresence.anomalie => const Color(0xFF9F1239),
      StatutPresence.partiTot => const Color(0xFFA16207),
      StatutPresence.attendu => const Color(0xFF475569),
      StatutPresence.present => couleurPresent,
      StatutPresence.conge => const Color(0xFF6B7280),
      StatutPresence.repos => const Color(0xFF6B7280),
    };

/// Pastille de statut (« En retard +75 min », « Absent »…).
class PastilleStatut extends StatelessWidget {
  final StatutPresence statut;
  final String? complement;
  const PastilleStatut(this.statut, {super.key, this.complement});

  @override
  Widget build(BuildContext context) {
    final c = couleurStatut(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withAlpha(28), borderRadius: BorderRadius.circular(20)),
      child: Text(
        complement == null ? statut.libelle : '${statut.libelle} $complement',
        style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

/// Tuile de compteur (en-tête des écrans).
class TuileCompteur extends StatelessWidget {
  final String libelle;
  final String valeur;
  final Color couleur;
  final String? detail;
  const TuileCompteur({super.key, required this.libelle, required this.valeur, this.couleur = couleurPrincipale, this.detail});

  @override
  Widget build(BuildContext context) => _Bordee(
        rayon: 12,
        bande: couleur,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(libelle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: couleurGris)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valeur, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: couleur)),
          ),
          if (detail != null) Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: couleurGris)),
        ]),
      );
}

/// Fond blanc arrondi, ombre légère et bande de couleur à gauche (une bordure d'un seul côté ne peut pas être
/// arrondie : la bande est découpée par l'arrondi).
class _Bordee extends StatelessWidget {
  final double rayon;
  final Color? bande;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Widget child;
  const _Bordee({required this.rayon, required this.child, this.bande, this.padding = EdgeInsets.zero, this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(rayon);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 7, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: bande == null ? null : BoxDecoration(border: Border(left: BorderSide(color: bande!, width: 4))),
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Rangée de tuiles : 4 de front (2 × 2 sous 360 px).
class RangeeTuiles extends StatelessWidget {
  final List<Widget> tuiles;
  const RangeeTuiles(this.tuiles, {super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final parLigne = c.maxWidth < 380 ? 2 : tuiles.length;
        final lignes = <Widget>[];
        for (var i = 0; i < tuiles.length; i += parLigne) {
          final morceau = tuiles.sublist(i, (i + parLigne).clamp(0, tuiles.length));
          lignes.add(Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Row(children: [
              for (var j = 0; j < morceau.length; j++) ...[
                if (j > 0) const SizedBox(width: 8),
                Expanded(child: morceau[j]),
              ],
            ]),
          ));
        }
        return Column(children: lignes);
      });
}

/// Carte blanche arrondie (style des écrans actuels).
class CartePresence extends StatelessWidget {
  final Widget child;
  final Color? bande;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const CartePresence({super.key, required this.child, this.bande, this.onTap, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) => _Bordee(rayon: 14, bande: bande, padding: padding, onTap: onTap, child: child);
}

/// Deux colonnes sur tablette, une sur téléphone.
List<Widget> enColonnes(List<Widget> cartes, bool deux, {double espace = 8}) {
  if (!deux) {
    return [for (var i = 0; i < cartes.length; i++) Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : espace), child: cartes[i])];
  }
  return [
    for (var i = 0; i < cartes.length; i += 2)
      Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : espace),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: cartes[i]),
          SizedBox(width: espace),
          Expanded(child: i + 1 < cartes.length ? cartes[i + 1] : const SizedBox()),
        ]),
      ),
  ];
}

/// Titre de section.
class TitreSection extends StatelessWidget {
  final String texte;
  const TitreSection(this.texte, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
        child: Text(texte.toUpperCase(),
            style: const TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: couleurGris)),
      );
}

/// Icône de la source d'un pointage.
IconData iconeSource(String source) => switch (source.trim().toUpperCase()) {
      'MOBILE' => Icons.phone_android,
      'POINTEUSE' => Icons.fingerprint,
      'MANUEL' => Icons.edit_note,
      _ => Icons.help_outline,
    };

/// QR code dessiné localement (paquet « barcode », déjà présent via « pdf ») : aucun service extérieur.
class QrCodeDessin extends StatelessWidget {
  final String contenu;
  final double taille;
  const QrCodeDessin(this.contenu, {super.key, this.taille = 220});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'QR code de pointage',
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(taille * 0.06),
          child: CustomPaint(size: Size.square(taille), painter: _QrPeintre(contenu)),
        ),
      );
}

class _QrPeintre extends CustomPainter {
  final String contenu;
  _QrPeintre(this.contenu);

  @override
  void paint(Canvas canvas, Size size) {
    final noir = Paint()..color = Colors.black;
    final Iterable<BarcodeElement> elements;
    try {
      elements = Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium).make(contenu, width: size.width, height: size.height);
    } catch (_) {
      return;
    }
    for (final e in elements) {
      if (e is BarcodeBar && e.black) {
        // +0,5 px : pas de fines lignes blanches entre les modules.
        canvas.drawRect(Rect.fromLTWH(e.left, e.top, e.width + 0.5, e.height + 0.5), noir);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPeintre old) => old.contenu != contenu;
}

/// Échec de chargement dans une liste défilante : mêmes textes que [LoadErrorView] (« Chargement impossible »,
/// raison, « Réessayer »), sans hauteur imposée (un long message ne cache jamais le bouton).
class BlocErreur extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const BlocErreur({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: Column(children: [
          Icon(Icons.cloud_off, size: 56, color: Colors.red.shade400),
          const SizedBox(height: 12),
          const Text('Chargement impossible', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: couleurEncre)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: couleurGris)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ]),
      );
}
