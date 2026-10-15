// Outils des tests RÉSEAU (test/reseau/) : écran ouvert par-dessus un accueil (bouton retour utilisable), attente
// d'un serveur lent avec contrôles à chaque pas (indicateur visible, aucun message d'erreur avant le délai de
// l'application), textes d'erreur affichés. Faux serveur « en mémoire » : les délais des réponses passent en temps
// simulé (`tester.pump`), un serveur « lent de 25 s » ne coûte rien en temps réel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'application.dart';
import 'faux_serveur_prestige.dart';

/// Indicateur de chargement (cercle ou barre) affiché.
final indicateur = find.byWidgetPredicate((w) => w is ProgressIndicator);

/// Textes d'erreur qui ne doivent pas apparaître tant que le serveur répond dans les délais de l'application.
Finder erreursAffichees() => find.byWidgetPredicate((w) {
      if (w is! Text) return false;
      final t = (w.data ?? w.textSpan?.toPlainText() ?? '').toLowerCase();
      return t.contains('injoignable') ||
          t.contains('trop de temps') ||
          t.contains('ne répond pas') ||
          t.contains('erreur') ||
          t.contains('impossible') ||
          t.contains('réessayer') ||
          t.contains('indisponible') ||
          t.contains('non enregistrée') ||
          t.contains('certificat');
    });

/// Accueil d'essai : un bouton « Ouvrir » qui pousse [ecran] (comme un menu), pour pouvoir en revenir.
class AccueilEssai extends StatelessWidget {
  final Widget ecran;
  const AccueilEssai(this.ecran, {super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Accueil d\'essai')),
        body: Center(
          child: ElevatedButton(
            key: const Key('essai_ouvrir'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ecran)),
            child: const Text('Ouvrir'),
          ),
        ),
      );
}

/// Monte l'application (providers, thème, session) avec [AccueilEssai] puis ouvre [ecran] (faux serveur en mémoire,
/// session non contrôlée : l'écran est « déjà connecté »).
Future<void> ouvrirDepuisAccueil(WidgetTester tester, FauxServeurPrestige serveur, Widget ecran) async {
  serveur.controlerSession = false;
  await lancerApplication(tester, accueil: AccueilEssai(ecran));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.tap(find.byKey(const Key('essai_ouvrir')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Attend la réponse d'un serveur lent ([delai]) par pas de 250 ms : à chaque pas, [attente] (indicateur par défaut)
/// est visible et aucun message d'erreur n'est affiché ; [pendant] est appelé une fois, à mi-attente (seconde action
/// de l'utilisateur). Puis laisse arriver la réponse et vérifie qu'aucune erreur n'est affichée.
Future<void> attendreServeurLent(WidgetTester tester, Duration delai, String ecran,
    {Finder? attente, Future<void> Function()? pendant, Duration deja = Duration.zero}) async {
  final signe = attente ?? indicateur;
  final fin = delai - deja - const Duration(milliseconds: 250);
  var t = Duration.zero;
  var milieu = false;
  while (t < fin) {
    await tester.pump(const Duration(milliseconds: 250));
    t += const Duration(milliseconds: 250);
    expect(signe, findsWidgets, reason: '$ecran : attente visible à ${(t + deja).inMilliseconds} ms');
    expect(erreursAffichees(), findsNothing,
        reason: '$ecran : aucun message d\'erreur à ${(t + deja).inMilliseconds} ms (serveur lent, pas en panne) : '
            '${erreursAffichees().evaluate().map((e) => (e.widget as Text).data).join(' | ')}');
    if (!milieu && t >= (delai - deja) ~/ 2 && pendant != null) {
      milieu = true;
      await pendant();
    }
  }
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(erreursAffichees(), findsNothing,
      reason: '$ecran : réponse arrivée, aucun message d\'erreur : ${erreursAffichees().evaluate().map((e) => (e.widget as Text).data).join(' | ')}');
}

/// Touche « retour » du téléphone.
Future<void> retourTelephone(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
