// Polices réelles pour les tests d'affichage.
//
// Par défaut, flutter_test dessine chaque caractère comme un carré de 1 em (police « FlutterTest ») : un texte y
// est 1,5 à 2 fois plus large que sur un téléphone, et les tests de débordement donneraient de fausses alertes.
// On charge donc Roboto, fournie avec le SDK Flutter (bin/cache/artifacts/material_fonts, présente sur la CI),
// sous les noms de famille utilisés par l'application :
//  - « Lato_regular », « Lato_700 », … : noms donnés par google_fonts (GoogleFonts.lato) ; Lato est téléchargée à
//    l'exécution, et un téléphone hors ligne au premier lancement affiche… Roboto (police système Android) ;
//  - « Roboto » : police par défaut de Material sur Android.
// Roboto et Lato ont des chasses proches ; Roboto est précisément ce qu'affiche un téléphone sans Lato.
import 'dart:io';

import 'package:flutter/services.dart';

bool _chargees = false;

/// Dossier des polices Material du SDK Flutter.
String dossierPolicesSdk() {
  final racine = Platform.environment['FLUTTER_ROOT'];
  final candidats = <String>[
    if (racine != null) '$racine/bin/cache/artifacts/material_fonts',
    // flutter_tester : <FLUTTER_ROOT>/bin/cache/artifacts/engine/<plateforme>/flutter_tester
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
  ];
  for (final c in candidats) {
    if (File('$c/Roboto-Regular.ttf').existsSync()) return c;
  }
  throw StateError('Polices Roboto du SDK Flutter introuvables (cherchées dans : ${candidats.join(', ')})');
}

/// Charge les polices réelles (une seule fois par fichier de test).
Future<void> chargerPolicesReelles() async {
  if (_chargees) return;
  final dossier = dossierPolicesSdk();
  ByteData octets(String nom) => ByteData.sublistView(File('$dossier/$nom').readAsBytesSync());

  const graisses = {100: 'Thin', 300: 'Light', 400: 'Regular', 500: 'Medium', 700: 'Bold', 900: 'Black'};
  final roboto = FontLoader('Roboto');
  for (final e in graisses.entries) {
    roboto.addFont(Future.value(octets('Roboto-${e.value}.ttf')));
    roboto.addFont(Future.value(octets(e.key == 400 ? 'Roboto-Italic.ttf' : 'Roboto-${e.value}Italic.ttf')));
  }
  await roboto.load();

  // Noms google_fonts : « Lato_regular », « Lato_italic », « Lato_700 », « Lato_700italic »…
  for (final e in graisses.entries) {
    final droit = e.key == 400 ? 'Lato_regular' : 'Lato_${e.key}';
    final italique = e.key == 400 ? 'Lato_italic' : 'Lato_${e.key}italic';
    await (FontLoader(droit)..addFont(Future.value(octets('Roboto-${e.value}.ttf')))).load();
    await (FontLoader(italique)..addFont(Future.value(octets(e.key == 400 ? 'Roboto-Italic.ttf' : 'Roboto-${e.value}Italic.ttf')))).load();
  }
  _chargees = true;
}
