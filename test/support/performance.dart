// Outils des tests de PERFORMANCE (test/performance/) et des tests RÉSEAU (test/reseau/), repris de Prestige
// Inventaire (même structure, mêmes outils, même rapport de livraison).
//
// Principe : chaque mesure est comparée à un SEUIL écrit ici (table [Seuils]) ; au-delà, le test échoue (en local
// comme sur la CI). Chaque mesure est aussi imprimée sur une ligne « PRESTIGE_MESURE {json} », que
// tool/rapport_tests.dart relève dans la sortie JSON de `flutter test` pour l'écrire dans le rapport de tests de
// livraison (résumé du job GitHub + artefact `rapport-tests`).
//
// Temps des images : les tests de widgets tournent en temps SIMULÉ, mais le travail de chaque image (construction,
// mise en page, peinture) est réellement exécuté par le processeur : on chronomètre donc chaque `tester.pump()` avec
// une horloge réelle (Stopwatch, non simulée), image par image ([ChronoImages]). Mode test (JIT, assertions
// actives) : bien plus lent qu'un APK « release ». Les seuils sont des seuils de NON-RÉGRESSION en mode test sur la
// CI Linux, pas des temps d'appareil.
//
// Données : faux serveur Prestige « en mémoire » ([FauxServeurPrestige.clientMemoire]) : mêmes routes, même
// contrôle de session et même journal des requêtes que le serveur HTTP, sans socket, en temps simulé (les délais
// des réponses lentes passent avec `tester.pump`).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/services/api_service.dart';

import 'application.dart';
import 'faux_serveur_prestige.dart';

/// Seuils de performance. Calibrés sur la CI GitHub (ubuntu-latest, `flutter test -j 1`) avec une marge d'environ
/// ×3 sur la mesure la plus lente (temps) et une marge NULLE sur les requêtes (plafond = nombre attendu par le
/// fonctionnement voulu, écrit dans le test). Sur un PC chargé : `flutter test -j 1 test/performance`.
/// Valeurs mesurées et marge : test/README.md (« Seuils de performance »). Un seuil ne se relève qu'avec une
/// justification écrite dans le README (jamais pour faire passer un test).
class Seuils {
  Seuils._();

  // --- Démarrage ---
  /// Lancement de l'application (racine de main.dart, licence lue sur le faux serveur, écran de démarrage gardé
  /// 2,5 s simulées par AuthProvider) jusqu'à l'écran de connexion affiché et immobile, à froid.
  static const demarrageMs = 10000;

  /// Images rendues pendant ce démarrage (16 ms simulées par image : l'écran de démarrage anime son indicateur
  /// pendant 2,5 s, soit ~160 images).
  static const demarrageImages = 240;

  /// Requêtes au démarrage (avant connexion) : la licence et le nom de l'officine (affiché sur l'écran de
  /// connexion, route publique /officine).
  static const demarrageRequetes = 2;

  /// Connexion → accueil de la nouvelle interface affiché (A, B, C, menus par pages), images comprises.
  static const accueilMs = 6000;

  // --- Longues listes : temps de construction d'UNE image (ms, mode test) ---
  /// Ouverture d'un écran sur une longue liste (réponse du faux serveur lue, toutes les cartes construites), à froid.
  static const ouvertureListeMs = 30000;

  /// Pire image (première apparition, défilement à froid).
  static const imageFroideMs = 5000;

  /// PIRE image pendant le défilement d'une longue liste, après un premier passage (code déjà compilé).
  static const imageDefilementMs = 400;

  /// 90 % des images de défilement en dessous (image « courante »).
  static const imageCouranteMs = 150;

  /// « Afficher plus » sur une liste déjà longue (page suivante ajoutée, liste reconstruite) : pire image.
  static const pageSuivanteMs = 20000;

  // --- Graphiques ---
  /// Ouverture d'un écran à graphique sur une longue période (3 ans de points) jusqu'à l'image immobile.
  static const ouvertureGraphiqueMs = 30000;

  /// Changement de vue d'un graphique (Comparée / Achats / Ventes) : pire image.
  static const imageGraphiqueMs = 3000;

  // --- PDF ---
  /// Fabrication des octets d'un PDF (ticket Z, TVA, Marge, CA Crédit, péremption) avec beaucoup de lignes.
  static const pdfMs = 30000;
}

/// Mesure enregistrée (pour le rapport) et comparée à son seuil.
void mesurer(String nom, num valeur, {required num seuil, required String unite, String? detail}) {
  // ignore: avoid_print
  print('PRESTIGE_MESURE ${json.encode({
        'nom': nom,
        'valeur': valeur is double ? double.parse(valeur.toStringAsFixed(1)) : valeur,
        'seuil': seuil,
        'unite': unite,
        if (detail != null) 'detail': detail,
      })}');
  expect(valeur, lessThanOrEqualTo(seuil), reason: '$nom : $valeur $unite > seuil $seuil $unite${detail == null ? '' : ' ($detail)'}');
}

/// Chronomètre chaque image (chaque `pump`) en temps réel.
class ChronoImages {
  final List<double> ms = [];

  Future<void> pump(WidgetTester tester, [Duration? duree]) async {
    final sw = Stopwatch()..start();
    await tester.pump(duree);
    ms.add(sw.elapsedMicroseconds / 1000);
  }

  int get nombre => ms.length;
  double get max => ms.isEmpty ? 0 : ms.reduce((a, b) => a > b ? a : b);
  double get moyenne => ms.isEmpty ? 0 : ms.reduce((a, b) => a + b) / ms.length;

  /// 90e centile.
  double get p90 {
    if (ms.isEmpty) return 0;
    final t = [...ms]..sort();
    return t[((t.length - 1) * 0.9).round()];
  }

  String get resume => '${ms.length} images, moyenne ${moyenne.toStringAsFixed(1)} ms, p90 ${p90.toStringAsFixed(1)} ms, max ${max.toStringAsFixed(1)} ms';
}

int _images = 0;
bool _compteurBranche = false;

/// Nombre d'images rendues depuis le début du fichier de tests (compteur branché au premier appel).
int imagesRendues() {
  if (!_compteurBranche) {
    SchedulerBinding.instance.addPersistentFrameCallback((_) => _images++);
    _compteurBranche = true;
  }
  return _images;
}

/// Zone défilante d'une liste de module ([cle] : « defilement_module », « defilement_detail »…), sinon la plus
/// grande zone défilante affichée.
Finder listeDefilante(WidgetTester tester, {String? cle}) {
  if (cle != null) {
    final f = find.descendant(of: find.byKey(Key(cle)), matching: find.byType(Scrollable));
    if (f.evaluate().isNotEmpty) return f.first;
    final direct = find.byKey(Key(cle));
    if (direct.evaluate().isNotEmpty && tester.widget(direct) is Scrollable) return direct;
  }
  final tous = find.byType(Scrollable).evaluate().where((e) => (e.widget as Scrollable).axisDirection == AxisDirection.down).toList();
  tous.sort((a, b) => (b.size?.height ?? 0).compareTo(a.size?.height ?? 0));
  final cible = tous.first;
  return find.byElementPredicate((e) => identical(e, cible));
}

/// Fait défiler [scrollable] par pas de [pas] dp jusqu'en bas (ou [maxPas] pas), une image chronométrée par pas.
/// Renvoie le nombre de pas effectués.
Future<int> defilerJusquEnBas(WidgetTester tester, Finder scrollable, ChronoImages chrono, {double pas = 120, int maxPas = 3000}) async {
  final etat = tester.state<ScrollableState>(scrollable);
  var n = 0;
  while (n < maxPas && etat.position.pixels < etat.position.maxScrollExtent) {
    etat.position.jumpTo((etat.position.pixels + pas).clamp(0, etat.position.maxScrollExtent));
    await chrono.pump(tester);
    n++;
  }
  return n;
}

/// Remonte en haut de [scrollable] (une image).
Future<void> remonter(WidgetTester tester, Finder scrollable) async {
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pump();
}

/// Deux passages de défilement complets : le 1er à froid, le 2e chronométré image par image contre le budget.
Future<void> deuxPassages(WidgetTester tester, String nom, {int minPas = 20, String? cle}) async {
  final liste = listeDefilante(tester, cle: cle);
  final froid = ChronoImages();
  final pas1 = await defilerJusquEnBas(tester, liste, froid);
  expect(pas1, greaterThanOrEqualTo(minPas), reason: '$nom : la liste doit être longue (pas de défilement : $pas1)');
  await remonter(tester, liste);
  final chaud = ChronoImages();
  await defilerJusquEnBas(tester, liste, chaud);
  mesurer('$nom — pire image, 1er défilement (à froid)', froid.max, seuil: Seuils.imageFroideMs, unite: 'ms', detail: froid.resume);
  mesurer('$nom — pire image, défilement', chaud.max, seuil: Seuils.imageDefilementMs, unite: 'ms', detail: chaud.resume);
  mesurer('$nom — image courante (p90), défilement', chaud.p90, seuil: Seuils.imageCouranteMs, unite: 'ms');
}

/// Pompe l'horloge simulée par pas de [pas] jusqu'à [condition] (au plus [max] pas) ; échoue sinon.
Future<void> pomper(WidgetTester tester, bool Function() condition,
    {String raison = 'condition', int max = 200, Duration pas = const Duration(milliseconds: 100)}) async {
  for (var i = 0; i < max && !condition(); i++) {
    await tester.pump(pas);
  }
  expect(condition(), isTrue, reason: raison);
}

/// Écran [ecran] monté dans l'application (providers, thème, session) contre le faux serveur en mémoire, comme
/// ouvert depuis l'accueil ; renvoie le temps réel jusqu'à ce que [pret] soit vrai et l'écran immobile.
Future<double> ouvrirEcran(WidgetTester tester, FauxServeurPrestige serveur, Widget ecran, {required Finder pret, int maxPas = 300}) async {
  serveur.controlerSession = false;
  final sw = Stopwatch()..start();
  await lancerApplication(tester, accueil: ecran);
  await pomper(tester, () => pret.evaluate().isNotEmpty, raison: 'écran prêt : $pret', max: maxPas);
  await tester.pump(const Duration(milliseconds: 500));
  return sw.elapsedMicroseconds / 1000;
}

/// Fin de test « en mémoire » : démonte l'application et épuise les minuteries.
Future<void> fermerApplication(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

/// Prépare le faux serveur [serveur] « en mémoire » pour un test : routes par défaut, session exigée, client
/// de l'application branché sur lui.
void brancherEnMemoire(FauxServeurPrestige serveur) {
  serveur
    ..installerRoutesParDefaut()
    ..controlerSession = true
    ..coupe = false
    ..oublierRequetes();
  ApiService.client = serveur.clientMemoire();
}

/// Requêtes reçues pendant [action].
Future<List<RequeteRecue>> compter(FauxServeurPrestige s, Future<void> Function() action) async {
  final avant = s.requetes.length;
  await action();
  return s.requetes.sublist(avant);
}

/// « GET /recap/dashboard ×1, GET /rh/presence ×1 » (message des mesures de requêtes).
String detailRequetes(List<RequeteRecue> rs) {
  final par = <String, int>{};
  for (final r in rs) {
    final k = '${r.methode} ${r.chemin}';
    par[k] = (par[k] ?? 0) + 1;
  }
  return par.isEmpty ? 'aucune' : par.entries.map((e) => '${e.key} ×${e.value}').join(', ');
}
