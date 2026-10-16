// lib/screens/splash_screen.dart

// 3.11.0 (décision du pharmacien) : nouvelle interface — écran de chargement de « Prestige Pharmacien » sur le modèle
// fourni (anneau de progression autour de la croix verte, nom de l'application et de la pharmacie, UNE ligne d'étape
// « Étape n sur 4 · adresse du serveur », version en bas). Étapes : 1 lecture des réglages, 2 vérification de la
// licence, 3 connexion au serveur, 4 ouverture. L'ancienne interface garde son écran.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../interface_version.dart';
import '../nouvelle_interface/charte.dart';
import '../providers/ip_config_provider.dart';
import '../version_app.dart';

/// Étape du chargement affichée (une seule ligne).
enum EtapeChargement {
  reglages('Lecture des réglages…'),
  licence('Vérification de la licence…'),
  serveur('Connexion au serveur…'),
  ouverture('Ouverture de Prestige Pharmacien…');

  final String texte;
  const EtapeChargement(this.texte);

  int get numero => index + 1;
  static int get total => values.length;
}

class SplashScreen extends StatelessWidget {
  final EtapeChargement etape;
  const SplashScreen({super.key, this.etape = EtapeChargement.reglages});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (InterfaceVersion.nouvelle(context)) return ChargementPrestige(etape: etape);

    return Scaffold(
      backgroundColor: theme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // CORRECTION: Remplacement de l'icône par votre logo
            // Assurez-vous que le chemin 'assets/icons/icon.png' est correct
            // et que l'asset est bien déclaré dans votre pubspec.yaml
            Image.asset(
              'assets/icons/icon.png',
              width: 120,
              height: 120,
            ),
            const SizedBox(height: 24),
            Text(
              'Prestige',
              style: GoogleFonts.lato(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 60.0),
              child: LinearProgressIndicator(
                backgroundColor: theme.colorScheme.secondary,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Écran de chargement de la nouvelle interface (modèle du pharmacien).
class ChargementPrestige extends StatefulWidget {
  final EtapeChargement etape;
  const ChargementPrestige({super.key, required this.etape});

  @override
  State<ChargementPrestige> createState() => _ChargementPrestigeState();
}

class _ChargementPrestigeState extends State<ChargementPrestige> {
  String? _pharmacie;

  @override
  void initState() {
    super.initState();
    // Nom de la pharmacie connu d'une connexion précédente (aucune requête : rien n'est encore vérifié).
    SharedPreferences.getInstance().then((p) {
      final n = p.getString('officine_name');
      if (mounted && n != null && n.trim().isNotEmpty) setState(() => _pharmacie = n.trim());
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.etape;
    String? adresse;
    try {
      final ip = context.watch<IpConfigProvider>();
      if (ip.isAppConfigured) adresse = '${ip.useLocalIp ? ip.localIp : ip.remoteIp}:${ip.port}';
    } catch (_) {}
    const vert = Charte.vert;
    const vertPale = Charte.chargementAnneauFond;
    final progression = e.numero / EtapeChargement.total;
    return Scaffold(
      key: const Key('ecran_chargement'),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Charte.chargementFondHaut, Charte.chargementFondBas]),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight, minWidth: c.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const SizedBox(height: 8),
                    Column(children: [
                      // Anneau de progression autour de la croix.
                      Semantics(
                        label: 'Chargement, étape ${e.numero} sur ${EtapeChargement.total}',
                        child: SizedBox(
                          width: 128,
                          height: 128,
                          child: Stack(alignment: Alignment.center, children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progression),
                              duration: const Duration(milliseconds: 600),
                              builder: (_, v, __) => SizedBox(
                                width: 128,
                                height: 128,
                                child: CircularProgressIndicator(
                                  key: const Key('chargement_anneau'),
                                  value: v,
                                  strokeWidth: 7,
                                  backgroundColor: vertPale,
                                  color: vert,
                                ),
                              ),
                            ),
                            Container(
                              width: 104,
                              height: 104,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Center(child: _Croix(couleur: vert, taille: 60)),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('Prestige Pharmacien',
                          key: const Key('chargement_titre'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w800, color: Charte.navy)),
                      if (_pharmacie != null) ...[
                        const SizedBox(height: 4),
                        Text(_pharmacie!,
                            key: const Key('chargement_pharmacie'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, color: Charte.grisTexte, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                    Column(children: [
                      const SizedBox(height: 32),
                      // Étapes en traits : faites (vert), en cours (vert clair), à venir (gris).
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        for (var i = 1; i <= EtapeChargement.total; i++)
                          Container(
                            width: 28,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i < e.numero ? vert : (i == e.numero ? vert.withValues(alpha: 0.55) : vertPale),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 14),
                      Text(e.texte,
                          key: const Key('chargement_etape'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Charte.encre)),
                      const SizedBox(height: 6),
                      Text('Étape ${e.numero} sur ${EtapeChargement.total}${adresse == null ? '' : ' · $adresse'}',
                          key: const Key('chargement_detail'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: Charte.grisTexte)),
                      const SizedBox(height: 28),
                      const VersionAffichee(couleur: Charte.grisTexte, taille: 12.5),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Croix de pharmacie (deux barres arrondies).
class _Croix extends StatelessWidget {
  final Color couleur;
  final double taille;
  const _Croix({required this.couleur, required this.taille});

  @override
  Widget build(BuildContext context) {
    final epaisseur = taille * 0.34;
    final barre = BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(epaisseur * 0.28));
    return SizedBox(
      width: taille,
      height: taille,
      child: Stack(alignment: Alignment.center, children: [
        Container(width: epaisseur, height: taille, decoration: barre),
        Container(width: taille, height: epaisseur, decoration: barre),
      ]),
    );
  }
}
