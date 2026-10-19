// Synchronisation avec le serveur (branche claude/new-session-xm8ptu, tête 965a4d1b) — 3.14.1.
// Pointage BL par groupe (demande 45, fe6cdf45) : la réponse est construite EXACTEMENT comme
// PointageBLService.liste(…, parGrossiste) du serveur (chaque pièce porte grossisteId et grossiste ; « parGrossiste »
// = un total par grossiste du groupe ayant au moins une pièce, sur TOUTES les pièces de la période quel que soit
// l'état : grossisteId, libelle, totalBl, totalAvoirs (négatif), net, pieces, pointes, nonPointes, trié par libellé).
// L'application : montant de chaque grossiste, et (3.14.1) ses pièces pointées / à pointer ; avec l'état « À pointer »,
// le détail reste celui de toute la période (serveur), pas un calcul sur les pièces filtrées.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart' show formaterMontant;
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';

import '../support/donnees_vague1.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';
import 'retours_3_10_0_test.dart' show demonter, monter, serveur;

Finder cle(String k) => find.byKey(Key(k));

/// Pièces d'un groupe de deux grossistes (BL, avoir, réception ; pointées ou non).
List<Map<String, Object?>> piecesDuGroupe() => [
      {...DonneesVague3.piece('BL', 'BL-A1', 'BLA-1', 200000, pointeLe: '12/10/2026 09:00', pointePar: 'Fictif'), 'grossisteId': 'G-A', 'grossiste': 'ALPHA FICTIF'},
      {...DonneesVague3.piece('BL', 'BL-A2', 'BLA-2', 50000), 'grossisteId': 'G-A', 'grossiste': 'ALPHA FICTIF'},
      {...DonneesVague3.piece('RETOUR', 'AV-A1', 'AVA-1', 20000), 'grossisteId': 'G-A', 'grossiste': 'ALPHA FICTIF'},
      {...DonneesVague3.piece('BL', 'BL-B1', 'BLB-1', 100000), 'grossisteId': 'G-B', 'grossiste': 'BETA FICTIF'},
      {...DonneesVague3.piece('RECEPTION', 'RC-B1', 'RCB-1', 10000), 'grossisteId': 'G-B', 'grossiste': 'BETA FICTIF'},
    ];

/// Réponse de GET /pointage-bl comme le serveur (PointageBLService.liste et totauxParGrossiste).
Map<String, Object?> reponseServeur(Map<String, String> p) {
  final etat = p['etat'] ?? 'TOUS';
  final toutes = piecesDuGroupe();
  num bl = 0, avoirs = 0;
  var pointes = 0, nonPointes = 0;
  final data = <Map<String, Object?>>[];
  for (final x in toutes) {
    final pointe = (x['pointeLe'] as String).isNotEmpty, reception = x['type'] == 'RECEPTION';
    final ht = (x['montantHt'] as num).abs();
    if (x['type'] == 'BL') {
      bl += ht;
    } else {
      avoirs -= ht;
    }
    if (!reception) pointe ? pointes++ : nonPointes++;
    if (etat == 'POINTES' && !pointe || etat == 'NON_POINTES' && (pointe || reception)) continue;
    data.add({...x, 'pointe': pointe});
  }
  final sortie = <String, Object?>{
    'success': true, 'data': data, 'total': data.length, 'totalBl': bl, 'totalAvoirs': avoirs, 'net': bl + avoirs,
    'pointes': pointes, 'nonPointes': nonPointes,
  };
  if ((p['groupe'] ?? '').isNotEmpty) {
    final t = <String, List<num>>{}, libelles = <String, String>{};
    for (final x in toutes) {
      final v = t.putIfAbsent(x['grossisteId']! as String, () => [0, 0, 0, 0, 0]);
      libelles[x['grossisteId']! as String] = x['grossiste']! as String;
      final ht = (x['montantHt'] as num).abs();
      x['type'] == 'BL' ? v[0] += ht : v[1] -= ht;
      v[2]++;
      if (x['type'] != 'RECEPTION') v[(x['pointeLe'] as String).isNotEmpty ? 3 : 4]++;
    }
    final ids = t.keys.toList()..sort((a, b) => libelles[a]!.compareTo(libelles[b]!));
    sortie['parGrossiste'] = [
      for (final id in ids)
        {'grossisteId': id, 'libelle': libelles[id], 'totalBl': t[id]![0], 'totalAvoirs': t[id]![1], 'net': t[id]![0] + t[id]![1],
          'pieces': t[id]![2], 'pointes': t[id]![3], 'nonPointes': t[id]![4]},
    ];
  }
  return sortie;
}

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);
  setUp(() {
    serveur
      ..installerRoutesParDefaut()
      ..coupe = false;
    listesCommunesVague1(serveur);
    serveur.route(ApiPointage.route, (r) => ReponseFausse.json(reponseServeur(r.parametres)), methode: 'GET');
  });

  testWidgets('par groupe, format réel du serveur : montant et pièces pointées / à pointer de chaque grossiste', (tester) async {
    await monter(tester, () => const PointageBlScreen(), prefs: {DernierCriterePointage.cle: 'groupe:${DonneesVague3.groupe}'});
    final r = serveur.recues(ApiPointage.route).last.parametres;
    expect(r['groupe'], DonneesVague3.groupe);
    expect(r['grossiste'] ?? '', isEmpty);
    expect(cle('pointage_detail_groupe_absent'), findsNothing);
    final a = find.descendant(of: cle('pointage_grossiste_du_groupe_G-A'), matching: find.byType(Text));
    expect(find.descendant(of: cle('pointage_grossiste_du_groupe_G-A'), matching: find.text('ALPHA FICTIF')), findsOneWidget);
    expect(find.descendant(of: cle('pointage_grossiste_du_groupe_G-A'), matching: find.text(formaterMontant(230000))), findsOneWidget,
        reason: '200 000 + 50 000 − 20 000');
    expect(a, findsWidgets);
    expect(tester.widget<Text>(cle('pointage_compteurs_grossiste_G-A')).data, '3 pièces · 1 pointée · 2 à pointer');
    expect(tester.widget<Text>(cle('pointage_compteurs_grossiste_G-B')).data, '2 pièces · 0 pointée · 1 à pointer',
        reason: 'la réception compte comme pièce, ni pointée ni à pointer (comme le serveur)');
    expect(tester.getTopLeft(cle('pointage_grossiste_du_groupe_G-A')).dy, lessThan(tester.getTopLeft(cle('pointage_grossiste_du_groupe_G-B')).dy),
        reason: 'ordre du serveur (libellé)');
    await demonter(tester);
  });

  test('lecture du format réel : champs du serveur, avoirs négatifs, compteurs', () {
    final d = PointageBl.depuis(reponseServeur({'groupe': 'GRP', 'etat': 'NON_POINTES'}));
    final detail = d.detailGroupe(toutesLesPieces: false)!;
    expect(detail.$2, SourceDetailGroupe.serveur, reason: 'état filtré : le détail du serveur porte sur toute la période');
    final a = detail.$1.firstWhere((m) => m.grossisteId == 'G-A');
    expect((a.totalBl, a.totalAvoirs, a.net, a.pieces, a.pointes, a.nonPointes), (250000.0, -20000.0, 230000.0, 3, 1, 2));
    expect(d.pieces.every((p) => p.grossisteId.isNotEmpty && p.grossiste.isNotEmpty), isTrue);
    // Serveur sans compteurs par grossiste : null (rien d'affiché), pas 0.
    final ancien = MontantGrossiste.depuis({'grossisteId': 'G', 'libelle': 'X', 'totalBl': 1, 'totalAvoirs': 0, 'net': 1, 'pieces': 1});
    expect((ancien.pointes, ancien.nonPointes), (null, null));
  });
}
