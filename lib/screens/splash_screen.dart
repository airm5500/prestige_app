// lib/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
