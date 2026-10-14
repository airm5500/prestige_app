// Détail Mobile Money du Détail CA (lib/donnees/detail_ca_donnees.dart) : lecture tolérante de
// /stats-recette-caisse/modes (seules les lignes mobile:true, « part » / « partCa » du serveur ignorés), cumul par
// opérateur, tri décroissant, taux (montant / totMobile de /ca-all et montant / Total brut paiements de /ca-all),
// ligne « Autres / écart », champ futur « detailMobile » de /ca-all prioritaire et sans écart.
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/detail_ca_donnees.dart';
import 'package:prestige_app/models/ca_comptant_model.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/donnees_fictives.dart';

OperateurMobile op(String id, String libelle, double montant) => OperateurMobile(modeId: id, libelle: libelle, montant: montant);

void main() {
  group('Lecture de /stats-recette-caisse/modes', () {
    test('seules les lignes mobile:true, triées par montant décroissant', () {
      final ops = DetailCa.lireModes(DonneesFictives.modesPaiement());
      expect(ops.map((o) => o.libelle), ['Orange', 'Wave', 'MTN', 'Moov']);
      expect(ops.map((o) => o.montant), [118500, 71250, 30000, 15250]);
      expect(ops.first.modeId, '7');
    });

    test('formats tolérants : liste seule, data.data, montants en texte, mobile en 1 / "true", libellés variés', () {
      final ops = DetailCa.lireModes([
        {'modeId': 7, 'libelle': 'Orange', 'montant': '12 500', 'mobile': 1},
        {'id': '10', 'str_NAME': 'Wave', 'montant': '7,5', 'mobile': 'true'},
        {'modeId': '19', 'montant': 3000, 'mobile': true},
        {'modeId': '1', 'mode': 'Espèces', 'montant': 900000},
        'illisible',
      ]);
      expect(ops.map((o) => (o.libelle, o.montant)), [('Orange', 12500.0), ('Opérateur 19', 3000.0), ('Wave', 7.5)]);
      final imbrique = DetailCa.lireModes({
        'success': true,
        'data': {
          'data': [
            {'modeId': '8', 'mode': 'Moov', 'montant': 100, 'mobile': true}
          ]
        }
      });
      expect(imbrique.single.libelle, 'Moov');
      expect(DetailCa.lireModes(null), isEmpty);
      expect(DetailCa.lireModes({'success': true}), isEmpty);
    });

    test('refus (success:false) → droit manquant ; format inattendu → erreur de réponse', () {
      expect(() => DetailCa.lireModes({'success': false, 'message': 'Accès refusé'}),
          throwsA(isA<ApiLoadException>().having((e) => e.nature, 'nature', NatureErreur.droit)));
      expect(() => DetailCa.lireModes({'success': true, 'data': 'x'}),
          throwsA(isA<ApiLoadException>().having((e) => e.nature, 'nature', NatureErreur.reponse)));
      expect(() => DetailCa.lireModes('texte'), throwsA(isA<ApiLoadException>()));
    });
  });

  group('Cumul et tri', () {
    test('même identifiant (ou même libellé sans identifiant) cumulé ; montants nuls retirés ; égalité → ordre alphabétique', () {
      final ops = DetailCa.cumulerOperateurs([
        op('7', 'Orange', 100),
        op('10', 'Wave', 300),
        op('7', 'Orange Money', 250),
        op('', 'Djamo', 50),
        op('', 'djamo', 300),
        op('9', 'MTN', 0),
        op('8', 'Moov', 350),
      ]);
      expect(ops.map((o) => (o.libelle, o.montant)), [('Djamo', 350.0), ('Moov', 350.0), ('Orange', 350.0), ('Wave', 300.0)]);
    });
  });

  group('Taux et écart (totaux de référence de /ca-all)', () {
    final d = DetailMobile(
      operateurs: DetailCa.lireModes(DonneesFictives.modesPaiement()),
      totMobile: DonneesFictives.totMobileCa.toDouble(),
      caGlobal: DonneesFictives.totalBrutCa.toDouble(),
      source: SourceDetailMobile.modes,
    );

    test('taux dans le Mobile Money = montant / totMobile ; dans le CA = montant / Total brut paiements', () {
      expect(d.tauxMobile(118500), closeTo(118500 / 237750 * 100, 1e-9));
      expect(d.tauxCa(118500), closeTo(118500 / 2152650 * 100, 1e-9));
      expect(d.tauxMobile(118500)!.toStringAsFixed(1), '49.8');
      expect(d.tauxCa(118500)!.toStringAsFixed(1), '5.5');
    });

    test('écart = totMobile − Σ opérateurs (2 750), positif ou négatif ; nul → aucune ligne', () {
      expect(d.somme, 235000);
      expect(d.ecart, DonneesFictives.ecartMobile);
      expect(d.ecart, 2750);
      final plus = DetailMobile(operateurs: [op('7', 'Orange', 1200)], totMobile: 1000, caGlobal: 5000, source: SourceDetailMobile.modes);
      expect(plus.ecart, -200);
      final juste = DetailMobile(operateurs: [op('7', 'Orange', 1000.2)], totMobile: 1000, caGlobal: 5000, source: SourceDetailMobile.modes);
      expect(juste.ecart, isNull);
    });

    test('totaux nuls : taux absents (pas de division par zéro)', () {
      const z = DetailMobile(operateurs: [], totMobile: 0, caGlobal: 0, source: SourceDetailMobile.modes);
      expect(z.tauxMobile(10), isNull);
      expect(z.tauxCa(10), isNull);
    });
  });

  group('Champ futur « detailMobile » de /ca-all', () {
    test('absent (réponse actuelle) : null → appel complémentaire nécessaire', () {
      expect(DetailCa.detailDepuisCaAll(DetailCa.lire(DonneesFictives.caParJour())), isNull);
      expect(DetailCa.detailDepuisCaAll(const []), isNull);
    });

    test('présent : cumulé sur la période, trié, Σ = totMobile ; aucune ligne d\'écart', () {
      final lignes = DetailCa.lire(DonneesFictives.caParJourAvecDetail());
      final ops = DetailCa.detailDepuisCaAll(lignes)!;
      expect(ops.map((o) => (o.libelle, o.montant)), [('Orange', 120000.0), ('Wave', 80750.0), ('MTN', 37000.0)]);
      final t = DetailCa.cumul(lignes);
      final d = DetailMobile(operateurs: ops, totMobile: t.totMobile, caGlobal: t.totalPaiements, source: SourceDetailMobile.caAll);
      expect(d.somme, t.totMobile);
      expect(d.ecart, isNull);
      // Même un écart (incohérence du serveur) ne produit pas de ligne : même calcul que totMobile.
      final faux = DetailMobile(operateurs: [op('7', 'Orange', 1)], totMobile: 100, caGlobal: 100, source: SourceDetailMobile.caAll);
      expect(faux.ecart, isNull);
    });

    test('incomplet (un jour avec Mobile Money sans le champ) : ignoré → appel complémentaire', () {
      final j = DonneesFictives.caParJourAvecDetail();
      j[1].remove('detailMobile');
      expect(DetailCa.detailDepuisCaAll(DetailCa.lire(j)), isNull);
      // Un jour SANS Mobile Money peut omettre le champ.
      final k = DonneesFictives.caParJourAvecDetail();
      k.add({'mvtDate': '20261011', 'totEsp': 1000, 'totMobile': 0});
      expect(DetailCa.detailDepuisCaAll(DetailCa.lire(k)), hasLength(3));
    });

    test('les chiffres de /ca-all restent identiques avec ou sans le champ (non-régression)', () {
      final a = DetailCa.cumul(DetailCa.lire(DonneesFictives.caParJour()));
      final b = DetailCa.cumul(DetailCa.lire(DonneesFictives.caParJourAvecDetail()));
      expect(b.totalPaiements, a.totalPaiements);
      expect(b.totMobile, a.totMobile);
      expect(a.totalPaiements, DonneesFictives.totalBrutCa);
      expect(DetailCa.repartition(b), DetailCa.repartition(a));
    });
  });
}
