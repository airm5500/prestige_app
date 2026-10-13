// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../interface_version.dart';
import '../nouvelle_interface/charte.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (InterfaceVersion.nouvelle(context)) return _nouveau();

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

  /// Nouvelle interface : fond bleu nuit, barre de progression ambre.
  Widget _nouveau() => Scaffold(
        backgroundColor: Charte.navy,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset('assets/icons/icon.png', width: 112, height: 112),
            ),
            const SizedBox(height: 24),
            Text('Prestige', style: GoogleFonts.lato(fontSize: 32, fontWeight: FontWeight.bold, color: Charte.blanc, letterSpacing: 2)),
            Text('Pharmacien', style: GoogleFonts.lato(fontSize: 16, color: Charte.enteteGris, letterSpacing: 1)),
            const SizedBox(height: 80),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 60.0),
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(3)),
                child: LinearProgressIndicator(backgroundColor: Charte.navy2, color: Charte.ambre, minHeight: 5),
              ),
            ),
          ]),
        ),
      );
}
