// Messages de résultat (barre du bas, messageResultat) : le DERNIER message s'affiche aussitôt, même si un autre
// attendait déjà son tour. Défaut révélé par la CI (3.10.1, parcours Suggestions du lot 2) : avec
// hideCurrentSnackBar, un message en file (succès précédent) passait devant le nouveau (erreur) et le cachait 4 s.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun_lot2.dart';

void main() {
  testWidgets('A affiché, B demandé pendant la sortie de A, puis C (erreur) : C s\'affiche, B jamais', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }))));
    final vus = <String>{};
    Future<void> pomper(int fois) async {
      for (var i = 0; i < fois; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        for (final t in ['A', 'B', 'C']) {
          if (find.text(t).evaluate().isNotEmpty) vus.add(t);
        }
      }
    }

    messageResultat(ctx, 'A');
    await tester.pump();
    await pomper(20);
    messageResultat(ctx, 'B');
    await pomper(1);
    messageResultat(ctx, 'C', echec: true);
    await pomper(8); // sortie de A (250 ms), puis C
    expect(find.text('C'), findsOneWidget);
    expect(find.text('B'), findsNothing);
    await pomper(100);
    expect(vus.contains('B'), isFalse, reason: 'message périmé jamais affiché');
  });

  testWidgets('deux messages à la suite : le second remplace le premier sans attendre sa durée', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }))));
    messageResultat(ctx, 'Premier');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    messageResultat(ctx, 'Second', echec: true);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Second'), findsOneWidget);
    expect(find.text('Premier'), findsNothing);
  });
}
