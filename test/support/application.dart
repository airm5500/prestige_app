// Outils pour monter l'application ENTIÈRE dans `flutter test` (sans émulateur) contre le faux serveur Prestige.
//
// Deux modes :
//  - réseau réel (tests e2e) : [utiliserReseauReel] puis [lancerApplication] ; l'application parle au faux
//    serveur HTTP local (127.0.0.1) par l'adresse saisie dans ses préférences, exactement comme sur un téléphone.
//    Les attentes passent par [attendreQue] / [attendreTexte], qui laissent avancer à la fois l'horloge simulée
//    de flutter_test (minuteries de l'application) et le temps réel (réponses du serveur) ;
//  - en mémoire (ergonomie) : `ApiService.client = serveur.clientMemoire()`, mêmes routes sans socket.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:prestige_app/interface_version.dart';
import 'package:prestige_app/main.dart';
import 'package:prestige_app/nouvelle_interface/alertes_accueil.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/services/pin_securise.dart';
import 'package:prestige_app/ui/taille_ecran.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faux_serveur_prestige.dart';

/// flutter_test remplace HttpClient par un faux qui répond toujours 400 : on le retire pour joindre le faux
/// serveur local, et l'application reçoit un client HTTP neuf.
void utiliserReseauReel() {
  HttpOverrides.global = null;
  ApiService.client = http.Client();
}

/// À appeler en tearDown : ferme le client (aucune connexion ni minuterie ne reste ouverte).
void restaurerClient() {
  ApiService.client.close();
  ApiService.client = http.Client();
}

/// Taille de l'écran enregistrée sur le téléphone préparé par [preparerTelephone] (tests de la taille de l'écran,
/// docs/TAILLE_ECRAN.md) ; à remettre à Automatique en fin de test.
TailleEcran tailleEcranPreparee = TailleEcran.automatique;

/// Préférences et stockage sûr d'un téléphone déjà configuré pour viser [serveur].
/// [nouvelle] : version de l'interface (les tests écrits pour l'interface d'origine la demandent explicitement :
/// la nouvelle interface est celle par défaut) ; [presentation] : présentation A / B / C de la nouvelle interface.
void preparerTelephone(FauxServeurPrestige serveur,
    {Map<String, Object> autres = const {},
    bool nouvelle = false,
    Presentation presentation = Presentation.automatique,
    AffichageMenus affichageMenus = AffichageMenus.unePage,
    StyleIcones? styleIcones = StyleIcones.actuel}) {
  InterfaceVersion.useNew.value = nouvelle;
  // Taille de l'écran : [tailleEcranPreparee] (Automatique par défaut : Compact d'office sur les petits écrans),
  // enregistrée et appliquée comme après un lancement (main() la lit avant runApp).
  TailleEcranReglage.reinitialiser();
  TailleEcranReglage.enregistree = tailleEcranPreparee;
  TailleEcranReglage.appliquerMaintenant();
  PresentationPrefs.choix.value = presentation;
  // Réglages d'apparence de l'accueil (3.9.0) : valeurs par défaut, sauf demande du test (ils sont lus au lancement).
  ApparenceAccueilPrefs.reinitialiser();
  ApparenceAccueilPrefs.affichage.value = affichageMenus;
  // Style des icônes : null = jamais choisi (nouveau défaut P4, 3.10.1) ; sinon choix explicite mémorisé.
  ApparenceAccueilPrefs.style.value = styleIcones ?? ApparenceAccueilPrefs.styleParDefaut;
  // Nombres des alertes de l'accueil A : rien de compté ni de mémorisé d'un test à l'autre.
  AlertesAccueil.instance.oublier();
  AlertesAccueil.maintenant = DateTime.now;
  AlertesAccueil.delaiMax = AlertesAccueil.delaiParDefaut;
  SharedPreferences.setMockInitialValues(serveur.preferencesApp(autres: {
    InterfaceVersion.cle: nouvelle,
    if (tailleEcranPreparee != TailleEcran.automatique) TailleEcranReglage.cle: tailleEcranPreparee.name,
    PresentationPrefs.cle: presentation.name,
    // Téléphone déjà passé à la 3.11.0 : la présentation demandée par le test est gardée (la migration vers le
    // tableau de bord a ses propres tests).
    if (!autres.containsKey(PresentationPrefs.cleMigration)) PresentationPrefs.cleMigration: true,
    if (affichageMenus != AffichageMenus.unePage) ApparenceAccueilPrefs.cleAffichage: affichageMenus.valeur,
    if (styleIcones != null) ApparenceAccueilPrefs.cleStyle: styleIcones.name,
    ...autres,
  }));
  FlutterSecureStorage.setMockInitialValues({});
  CodeAdmin.instance = CodeAdmin(iterations: 1000);
  JournalApp.actif = false;
}

/// Monte l'application réelle (providers + thème + parcours de démarrage de main.dart).
Future<void> lancerApplication(WidgetTester tester, {Widget? accueil}) async {
  await tester.pumpWidget(applicationPrestige(accueil: accueil));
}

/// Laisse avancer l'horloge simulée et le temps réel jusqu'à ce que [condition] soit vraie.
Future<void> attendreQue(WidgetTester tester, bool Function() condition,
    {String raison = 'condition', Duration maxReel = const Duration(seconds: 20)}) async {
  final chrono = Stopwatch()..start();
  while (!condition()) {
    if (chrono.elapsed > maxReel) {
      fail('Attente trop longue : $raison');
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Attend qu'au moins un widget corresponde à [finder].
Future<void> attendreWidget(WidgetTester tester, Finder finder) =>
    attendreQue(tester, () => finder.evaluate().isNotEmpty, raison: finder.toString());

/// Attend l'affichage de [texte] (texte exact).
Future<void> attendreTexte(WidgetTester tester, String texte) => attendreWidget(tester, find.text(texte));

/// Quelques tours (réseau + horloge) pour laisser les requêtes en cours se terminer.
Future<void> stabiliser(WidgetTester tester, {int tours = 10}) async {
  for (var i = 0; i < tours; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Fin de test : démonte l'application, laisse finir les requêtes et épuise les minuteries (délais réseau).
Future<void> terminer(WidgetTester tester) async {
  // AuthProvider garde l'écran de démarrage au moins 2,5 s : on le laisse finir avant de démonter.
  await stabiliser(tester);
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox());
  await stabiliser(tester);
  ApiService.client.close();
  await tester.pump(const Duration(minutes: 2));
}

/// Erreurs Flutter (débordements, exceptions de rendu…) relevées pendant [action], au lieu d'échouer à la
/// première : chaque entrée donne le message court et l'emplacement dans lib/ (fichier:ligne) quand il est connu.
Future<List<String>> releverErreurs(Future<void> Function() action) async {
  final erreurs = <String>[];
  final precedent = FlutterError.onError;
  FlutterError.onError = (details) => erreurs.add(resumerErreur(details));
  try {
    await action();
  } finally {
    FlutterError.onError = precedent;
  }
  return erreurs;
}

/// « A RenderFlex overflowed by 13 pixels on the right. (lib/screens/ca_global_screen.dart:120:16) ».
String resumerErreur(FlutterErrorDetails details) {
  final texte = details.toString();
  final lieu = RegExp(r'file://[^\s]*?/(lib/[^\s:]+:\d+:\d+)').firstMatch(texte)?.group(1);
  final court = details.exceptionAsString().split('\n').first;
  return lieu == null ? court : '$court ($lieu)';
}

/// 3.11.0 : choisit une période du sélecteur déroulant « Autres périodes » (7 jours, Ce mois, Mois dernier) :
/// ouvre le sélecteur, puis touche la période (clé `periode_<nom>`).
Future<void> choisirAutrePeriode(WidgetTester tester, String nom) async {
  await tester.ensureVisible(find.byKey(const Key('periode_autres')).first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.byKey(const Key('periode_autres')).first);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
  await tester.tap(find.byKey(Key('periode_$nom')).last);
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}
