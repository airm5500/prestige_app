// lib/nouvelle_interface/charte.dart
// Charte de la NOUVELLE interface (même charte que prestige_vente_app, voir docs/ANALYSE_PRESTIGE_APP.md §4 et
// docs/maquettes/prestige_app_maquettes.html) : bleu Prestige #003366, ambre #F59E0B pour l'action principale,
// fond #F2F4F8, cartes blanches arrondies, texte #14213D, gris #5B6B82, statuts vert / ambre / rouge toujours
// accompagnés d'un libellé.
//
// Seul fichier de la nouvelle interface où les couleurs sont écrites en dur : les écrans utilisent [Charte] ou
// le thème [themeNouvelleInterface]. Le thème couvre TOUS les composants Material (barres, boutons, cartes,
// champs, dialogues, feuilles du bas, barres de navigation, menus, sélecteurs de date…) : aucune teinte lavande
// par défaut de Material 3 ne reste, y compris dans les écrans des modules d'origine, qui prennent le thème.
// L'ancienne interface garde son thème (main.dart), inchangé.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class Charte {
  Charte._();

  // --- Couleurs de marque ---
  static const navy = Color(0xFF003366);
  static const navy2 = Color(0xFF0B4A80);
  static const ambre = Color(0xFFF59E0B);

  /// Texte sur l'ambre : contraste 8,6:1 (le blanc sur ambre ne fait que 2,1:1).
  static const surAmbre = Color(0xFF1F1300);

  // --- Fonds, textes, traits ---
  static const page = Color(0xFFF2F4F8);
  static const blanc = Color(0xFFFFFFFF);
  static const encre = Color(0xFF14213D);

  /// Texte secondaire : 5,6:1 sur blanc, 5,1:1 sur le fond de page.
  static const gris = Color(0xFF5B6B82);
  static const ligne = Color(0xFFE3E8EF);
  static const bordure = Color(0xFFC5D0DE);
  static const bordureChamp = Color(0xFFD3DBE6);

  /// Texte secondaire dans l'en-tête bleu (8,5:1 sur le bleu).
  static const enteteGris = Color(0xFFC9D6E8);

  /// Fond translucide des pastilles et tuiles de l'en-tête bleu.
  static const enteteVoile = Color(0x24FFFFFF);
  static const ombre = Color(0x1414213D);

  // --- Statuts (fond clair + texte foncé : toujours ≥ 4,5:1) ---
  static const vert = Color(0xFF16A34A);
  static const vertVif = Color(0xFF22C55E);
  static const vertClair = Color(0xFFE6F4EA);
  static const vertTexte = Color(0xFF166534);
  static const ambreClair = Color(0xFFFFF4E0);
  static const ambreBord = Color(0xFFF5D08A);
  static const ambreTexte = Color(0xFF9A3412);
  static const rouge = Color(0xFFDC2626);
  static const rougeVif = Color(0xFFEF4444);
  static const rougeClair = Color(0xFFFDECEC);
  static const rougeBord = Color(0xFFF5B5B5);
  static const rougeTexte = Color(0xFF991B1B);
  static const bleu = Color(0xFF2563EB);
  static const bleuClair = Color(0xFFE3ECF7);
  static const grisClair = Color(0xFFEEF1F5);
  static const grisTexte = Color(0xFF475569);

  // Carte d'affluence du tableau de bord (3.15.0) : deux dégradés, clair (chiffre à l'encre) puis foncé (chiffre
  // blanc) ; contraste ≥ 4,5 sur toute l'échelle.
  static const affluenceClair1 = Color(0xFFDDF1F7);
  static const affluenceClair2 = Color(0xFF7CC3D6);
  static const affluenceFonce1 = Color(0xFF1A7590);
  static const affluenceFonce2 = Color(0xFF0B4F63);
  static const vertHeure = Color(0xFF86EFAC);

  // 3.11.0 : bouton de déconnexion de l'en-tête de Prestige web (header.css, « .hdr-logout ») et écran de chargement
  // de Prestige Pharmacien (modèle du pharmacien : fond clair vert → bleu, anneau vert sur fond vert pâle).
  static const rougeDeconnexion = Color(0xFFE74C3C);
  static const ombreDeconnexion = Color(0x73E74C3C);
  static const chargementAnneauFond = Color(0xFFD1EDDB);
  static const chargementFondHaut = Color(0xFFF1F8F3);
  static const chargementFondBas = Color(0xFFE6EEF7);

  // --- Couleurs par famille de menus (PROPOSITIONS de style des icônes P1 / P2 / P3, 3.9.0 ; le style « Actuel »,
  //     par défaut, ne les utilise pas). Pour chaque famille : icône (foncée), pastille (douce), fond de tuile (très
  //     clair). Icône sur pastille, sur fond de tuile et sur blanc : contraste ≥ 4,5:1 (vérifié par les tests). ---
  static const familleVentes = Color(0xFF0B6B4A);
  static const familleVentesPastille = Color(0xFFDDF3E8);
  static const familleVentesTuile = Color(0xFFF1FAF5);
  static const familleCredits = Color(0xFF9A3412);
  static const familleCreditsPastille = Color(0xFFFFEDD5);
  static const familleCreditsTuile = Color(0xFFFFF8F0);
  static const familleAnalyses = Color(0xFF4338CA);
  static const familleAnalysesPastille = Color(0xFFE0E7FF);
  static const familleAnalysesTuile = Color(0xFFF3F5FF);
  static const familleStock = Color(0xFF0B6A63);
  static const familleStockPastille = Color(0xFFD5F2EE);
  static const familleStockTuile = Color(0xFFF0FAF8);
  static const familleFournisseurs = Color(0xFF1D4ED8);
  static const familleFournisseursPastille = Color(0xFFDBEAFE);
  static const familleFournisseursTuile = Color(0xFFF1F6FF);
  static const familleEquipe = Color(0xFFB42350);
  static const familleEquipePastille = Color(0xFFFDE7EC);
  static const familleEquipeTuile = Color(0xFFFEF4F6);
  static const familleAlertes = Color(0xFFB91C1C);
  static const familleAlertesPastille = Color(0xFFFEE2E2);
  static const familleAlertesTuile = Color(0xFFFFF4F4);
}

/// Thème complet de la nouvelle interface.
ThemeData themeNouvelleInterface(BuildContext context) {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Charte.navy,
    onPrimary: Charte.blanc,
    primaryContainer: Charte.bleuClair,
    onPrimaryContainer: Charte.navy,
    secondary: Charte.ambre,
    onSecondary: Charte.surAmbre,
    secondaryContainer: Charte.ambreClair,
    onSecondaryContainer: Charte.ambreTexte,
    tertiary: Charte.navy2,
    onTertiary: Charte.blanc,
    tertiaryContainer: Charte.bleuClair,
    onTertiaryContainer: Charte.navy,
    error: Charte.rougeTexte,
    onError: Charte.blanc,
    errorContainer: Charte.rougeClair,
    onErrorContainer: Charte.rougeTexte,
    surface: Charte.blanc,
    onSurface: Charte.encre,
    onSurfaceVariant: Charte.gris,
    surfaceDim: Charte.ligne,
    surfaceBright: Charte.blanc,
    surfaceContainerLowest: Charte.blanc,
    surfaceContainerLow: Charte.blanc,
    surfaceContainer: Charte.page,
    surfaceContainerHigh: Charte.grisClair,
    surfaceContainerHighest: Charte.ligne,
    outline: Charte.bordure,
    outlineVariant: Charte.ligne,
    shadow: Charte.encre,
    scrim: Charte.encre,
    inverseSurface: Charte.encre,
    onInverseSurface: Charte.blanc,
    inversePrimary: Charte.ambre,
    surfaceTint: Colors.transparent,
  );

  // Même base que le thème d'origine (main.dart) : le passage d'une interface à l'autre s'anime sans heurt.
  final textTheme = GoogleFonts.latoTextTheme(Theme.of(context).textTheme).apply(
    bodyColor: Charte.encre,
    displayColor: Charte.encre,
  );
  bool sel(Set<WidgetState> s) => s.contains(WidgetState.selected);
  final rond12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  OutlineInputBorder bord(Color c, [double w = 1.5]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    primaryColor: Charte.navy,
    primaryColorDark: Charte.navy,
    primaryColorLight: Charte.bleuClair,
    scaffoldBackgroundColor: Charte.page,
    canvasColor: Charte.blanc,
    cardColor: Charte.blanc,
    dividerColor: Charte.ligne,
    disabledColor: Charte.gris,
    hintColor: Charte.gris,
    textTheme: textTheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    iconTheme: const IconThemeData(color: Charte.encre),
    appBarTheme: AppBarTheme(
      // En-tête bleu nuit aux coins inférieurs arrondis (NavyHeader de vente_app) pour toutes les barres.
      backgroundColor: Charte.navy,
      foregroundColor: Charte.blanc,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(22))),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: GoogleFonts.lato(color: Charte.blanc, fontSize: 20, fontWeight: FontWeight.bold),
      toolbarTextStyle: GoogleFonts.lato(color: Charte.blanc, fontSize: 14),
      iconTheme: const IconThemeData(color: Charte.blanc),
      actionsIconTheme: const IconThemeData(color: Charte.blanc),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      // Action principale : ambre, texte presque noir (8,6:1). Mêmes marges que l'ancienne interface.
      style: ElevatedButton.styleFrom(
        backgroundColor: Charte.ambre,
        foregroundColor: Charte.surAmbre,
        disabledBackgroundColor: Charte.ligne,
        disabledForegroundColor: Charte.gris,
        iconColor: Charte.surAmbre,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.w700),
        shape: rond12,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Charte.navy,
        foregroundColor: Charte.blanc,
        disabledBackgroundColor: Charte.ligne,
        disabledForegroundColor: Charte.gris,
        textStyle: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700),
        shape: rond12,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Charte.navy,
        side: const BorderSide(color: Charte.navy, width: 1.5),
        textStyle: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w700),
        shape: rond12,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Charte.navy, textStyle: GoogleFonts.lato(fontWeight: FontWeight.w700)),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Charte.ambre,
      foregroundColor: Charte.surAmbre,
      elevation: 2,
    ),
    cardTheme: CardThemeData(
      color: Charte.blanc,
      surfaceTintColor: Colors.transparent,
      shadowColor: Charte.ombre,
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Charte.blanc,
      border: bord(Charte.bordureChamp),
      enabledBorder: bord(Charte.bordureChamp),
      disabledBorder: bord(Charte.ligne),
      focusedBorder: bord(Charte.navy, 2),
      errorBorder: bord(Charte.rouge),
      focusedErrorBorder: bord(Charte.rouge, 2),
      labelStyle: const TextStyle(color: Charte.gris),
      floatingLabelStyle: const TextStyle(color: Charte.navy, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: Charte.gris),
      helperStyle: const TextStyle(color: Charte.gris),
      errorStyle: const TextStyle(color: Charte.rougeTexte, fontWeight: FontWeight.w600),
      prefixIconColor: Charte.gris,
      suffixIconColor: Charte.gris,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Charte.blanc,
      selectedColor: Charte.navy,
      disabledColor: Charte.grisClair,
      checkmarkColor: Charte.blanc,
      labelStyle: GoogleFonts.lato(color: Charte.navy, fontWeight: FontWeight.w600, fontSize: 13),
      secondaryLabelStyle: GoogleFonts.lato(color: Charte.blanc, fontWeight: FontWeight.w600, fontSize: 13),
      side: const BorderSide(color: Charte.bordure),
      shape: const StadiumBorder(),
      surfaceTintColor: Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Charte.navy,
      unselectedLabelColor: Charte.gris,
      indicatorColor: Charte.ambre,
      dividerColor: Charte.ligne,
    ),
    navigationBarTheme: NavigationBarThemeData(
      // Barre blanche sans ombre (maquette) : elle se détache du fond gris de la page.
      backgroundColor: Charte.blanc,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      // Onglet actif : icône et libellé bleus en gras, sans pastille (maquette).
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: sel(s) ? Charte.navy : Charte.gris, size: 24)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.lato(
          fontSize: 12, fontWeight: sel(s) ? FontWeight.w700 : FontWeight.w500, color: sel(s) ? Charte.navy : Charte.gris)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Charte.blanc,
      indicatorColor: Charte.bleuClair,
      selectedIconTheme: const IconThemeData(color: Charte.navy),
      unselectedIconTheme: const IconThemeData(color: Charte.gris),
      selectedLabelTextStyle: GoogleFonts.lato(color: Charte.navy, fontWeight: FontWeight.w700, fontSize: 12),
      unselectedLabelTextStyle: GoogleFonts.lato(color: Charte.gris, fontSize: 12),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Charte.blanc,
      selectedItemColor: Charte.navy,
      unselectedItemColor: Charte.gris,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Charte.blanc,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      titleTextStyle: GoogleFonts.lato(color: Charte.navy, fontSize: 20, fontWeight: FontWeight.bold),
      contentTextStyle: GoogleFonts.lato(color: Charte.encre, fontSize: 15),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Charte.blanc,
      modalBackgroundColor: Charte.blanc,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: Charte.bordure,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Charte.blanc,
      surfaceTintColor: Colors.transparent,
      iconColor: Charte.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Charte.blanc),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    dropdownMenuTheme: const DropdownMenuThemeData(
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Charte.blanc),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Charte.encre,
      contentTextStyle: GoogleFonts.lato(color: Charte.blanc, fontSize: 14),
      actionTextColor: Charte.ambre,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Charte.navy,
      linearTrackColor: Charte.ligne,
      circularTrackColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.blanc : Charte.gris),
      trackColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.navy : Charte.ligne),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.navy : Charte.gris),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.navy : Colors.transparent),
      checkColor: const WidgetStatePropertyAll(Charte.blanc),
      side: const BorderSide(color: Charte.gris, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.navy : Charte.gris)),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.navy : Charte.blanc),
        foregroundColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.blanc : Charte.navy),
        iconColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.blanc : Charte.navy),
        side: const WidgetStatePropertyAll(BorderSide(color: Charte.bordure)),
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Charte.navy, textColor: Charte.encre),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: Charte.navy,
      collapsedIconColor: Charte.gris,
      textColor: Charte.navy,
      collapsedTextColor: Charte.encre,
    ),
    dividerTheme: const DividerThemeData(color: Charte.ligne, thickness: 1),
    badgeTheme: const BadgeThemeData(backgroundColor: Charte.rouge, textColor: Charte.blanc),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: Charte.encre, borderRadius: BorderRadius.all(Radius.circular(8))),
      textStyle: TextStyle(color: Charte.blanc),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Charte.blanc,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: Charte.navy,
      headerForegroundColor: Charte.blanc,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      dayForegroundColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.blanc : Charte.encre),
      dayBackgroundColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.navy : Colors.transparent),
      yearForegroundColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.blanc : Charte.encre),
      yearBackgroundColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.navy : Colors.transparent),
      todayForegroundColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.blanc : Charte.navy),
      todayBackgroundColor: WidgetStateProperty.resolveWith((s) => sel(s) ? Charte.navy : Colors.transparent),
      todayBorder: const BorderSide(color: Charte.ambre, width: 1.5),
      cancelButtonStyle: TextButton.styleFrom(foregroundColor: Charte.navy),
      confirmButtonStyle: TextButton.styleFrom(foregroundColor: Charte.navy),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: Charte.blanc,
      dialBackgroundColor: Charte.grisClair,
      dialHandColor: Charte.navy,
      hourMinuteColor: WidgetStateColor.resolveWith((s) => sel(s) ? Charte.bleuClair : Charte.grisClair),
      hourMinuteTextColor: WidgetStateColor.resolveWith((s) => sel(s) ? Charte.navy : Charte.encre),
      dayPeriodColor: Charte.bleuClair,
      entryModeIconColor: Charte.navy,
      cancelButtonStyle: TextButton.styleFrom(foregroundColor: Charte.navy),
      confirmButtonStyle: TextButton.styleFrom(foregroundColor: Charte.navy),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: Charte.navy,
      selectionColor: Charte.bleuClair,
      selectionHandleColor: Charte.navy,
    ),
  );
}
