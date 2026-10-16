// Retours du pharmacien (3.11.1), parties pures : tranches de la fréquentation horaire (1 h / 2 h, plages, part du CA,
// écart avec la veille), choix d'affichage mémorisé, évolution d'une tranche du CA par emplacement (calculée quand le
// serveur ne l'envoie pas), parts des graphiques de la Balance, libellés courts des périodes.
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague4/donnees_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/graphiques_vague4.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';

List<int> heures(Map<int, int> m) => [for (var h = 0; h < 24; h++) m[h] ?? 0];

void main() {
  group('Fréquentation horaire', () {
    final f = FrequentationJour(
      ventes: heures({8: 10, 9: 6, 10: 4, 12: 5}),
      ca: heures({8: 50000, 9: 25000, 10: 25000, 12: 100000}),
      reference: heures({7: 2, 8: 8, 9: 6, 10: 9}),
      libelle: 'comparé à la veille',
      semaine: false,
    );

    test('heures d\'ouverture : de la première à la dernière heure avec une vente, ce jour OU la veille', () {
      expect(f.bornes(PlageHoraire.ouverture), (7, 13));
      expect(f.bornes(PlageHoraire.septVingtDeux), (7, 22));
      expect(f.bornes(PlageHoraire.journee), (0, 24));
      expect(const FrequentationJour(ventes: [], libelle: '', semaine: false).bornes(PlageHoraire.ouverture), isNull);
    });

    test('par heure : ventes, part du CA de la JOURNÉE, écart avec la veille (signe)', () {
      final t = f.tranches();
      expect(t.map((x) => x.libelle), ['07 h', '08 h', '09 h', '10 h', '11 h', '12 h']);
      final h8 = t[1];
      expect((h8.ventes, h8.ca, h8.ventesReference, h8.ecart), (10, 50000, 8, 2));
      expect(h8.partCa, 25.0, reason: '50 000 sur 200 000');
      expect(t[3].ecart, -5);
      expect(t[2].ecart, 0);
      expect(t.fold<double>(0, (s, x) => s + x.partCa!), closeTo(100, 1e-9));
    });

    test('par 2 h : tranches depuis le début de la plage, la dernière coupée à la fin de la plage', () {
      final t = f.tranches(largeur: 2);
      expect(t.map((x) => x.libelle), ['07-09 h', '09-11 h', '11-13 h']);
      expect(t.map((x) => x.ventes), [10, 10, 5]);
      expect(t.map((x) => x.ecart), [0, -5, 5]);
      final j = f.tranches(largeur: 2, plage: PlageHoraire.septVingtDeux);
      expect(j.first.libelle, '07-09 h');
      expect(j.last.libelle, '21 h', reason: '21 h → 22 h : une heure');
      expect(j.map((x) => x.ventes).reduce((a, b) => a + b), f.totalVentes, reason: 'aucune vente perdue');
    });

    test('sans comparaison : pas d\'écart ; journée sans CA : pas de part', () {
      final s = FrequentationJour(ventes: heures({9: 3}), libelle: '', semaine: true);
      expect(s.tranches().single.ecart, isNull);
      expect(s.tranches().single.partCa, isNull);
    });

    test('choix d\'affichage : « 2:septVingtDeux » ; valeur inconnue → 1 h, heures d\'ouverture', () {
      expect(AffichageFrequentationPrefs.lire('2:septVingtDeux'), (2, PlageHoraire.septVingtDeux));
      expect(AffichageFrequentationPrefs.lire(AffichageFrequentationPrefs.ecrire(1, PlageHoraire.journee)), (1, PlageHoraire.journee));
      expect(AffichageFrequentationPrefs.lire(null), (1, PlageHoraire.ouverture));
      expect(AffichageFrequentationPrefs.lire('7:inconnue'), (1, PlageHoraire.ouverture));
    });
  });

  group('CA par emplacement, jour par jour', () {
    test('évolution par rapport au jour précédent : au dixième, comme le serveur ; rien après un jour sans vente', () {
      expect(evolutionTranche(null, 100), isNull);
      expect(evolutionTranche(0, 100), isNull);
      expect(evolutionTranche(160000, 192000), 20.0);
      expect(evolutionTranche(192000, 144000), -25.0);
      expect(evolutionTranche(3, 4), 33.3);
    });

    test('évolution du serveur (e_<jour>) gardée ; absente, calculée ; totaux aussi', () {
      const tranches = [TrancheCa('J1', 'Lun'), TrancheCa('J2', 'Mar'), TrancheCa('J3', 'Mer')];
      final avec = LigneCa.depuis({'t_J1': 100, 't_J2': 150, 'e_J2': 99.9, 't_J3': 120}, tranches);
      expect(avec.de('J2').evolution, 99.9, reason: 'valeur du serveur');
      expect(avec.de('J3').evolution, -20.0, reason: 'absente : calculée');
      expect(avec.de('J1').evolution, isNull);
      final c = ComparatifCa.depuis({
        'tranches': [for (final t in tranches) {'cle': t.cle, 'libelle': t.libelle}],
        'data': [{'t_J1': 100, 't_J2': 150, 't_J3': 120}],
      });
      expect([for (final t in tranches) c.evolutionsTranches[t.cle]], [null, 50.0, -20.0]);
    });
  });

  group('Graphiques de la Balance', () {
    test('parts en % sur le total des montants positifs', () {
      final p = pourcentages([(libelle: 'Espèces', montant: 300), (libelle: 'Mobile', montant: 100), (libelle: 'Avoir', montant: -50)]);
      expect(p, [75.0, 25.0, 0.0]);
      expect(pourcentages([(libelle: 'Rien', montant: 0)]), [0.0]);
    });

    test('libellé court de l\'axe : sans la précision entre parenthèses, 8 caractères au plus', () {
      PeriodeBalance p(String l) => PeriodeBalance.depuis({'libelle': l});
      expect(p('S39 (21/09-27/09)').libelleCourt, 'S39');
      expect(p('Septembre 2026').libelleCourt, 'Septembr');
      expect(p('2026').libelleCourt, '2026');
    });

    test('couleurs : celles de la charte, dans un ordre fixe, reprises au-delà', () {
      expect(couleurPart(0), couleursParts.first);
      expect(couleurPart(couleursParts.length), couleursParts.first);
    });
  });
}
