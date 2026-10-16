// Réponses du pharmacien sur la vague 2 (version 3.2.1+30), parties pures :
//  - Pilotage : table des sens (une hausse est-elle favorable ?) pour TOUTES les clés de tuiles du serveur
//    (PilotageService : synthese, asuivre, marge, achats, caisse, stock, qualité, KPI) ; flèche = sens réel,
//    couleur selon le sens de l'indicateur ; neutre gris ; 3.11.0 : plus de texte « favorable / défavorable » ;
//  - Analyse de garde : pages de 100, borne ;
//  - CA emplacement / famille : choix multiple envoyé « id1,id2 » comme le web, tout coché = aucun filtre, compteur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/vague2/commun_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/pilotage_vague2.dart';

void main() {
  group('Pilotage : table des sens', () {
    test('hausse favorable : ventes, marge, ratio, rotation, encaissements', () {
      for (final c in ['caTTC', 'caHT', 'ca', 'marge', 'tauxMarge', 'nbVentes', 'panier', 'evolPanier', 'ratioVA', 'ratio', 'ecart', 'rotation', 'encaisse', 'tpRegle']) {
        expect(sensIndicateur(c), SensIndicateur.hausseFavorable, reason: c);
      }
    });

    test('hausse défavorable (couleurs inversées) : ruptures, stock négatif, dormant, péremptions, crédits, remises, annulations, anomalies', () {
      for (final c in [
        'tauxRupture', 'ruptures', 'rupturesVendus', 'sousSeuil', 'negatifs', 'dormant', 'peremption', 'margeNegative', 'rateesACommander',
        'remises', 'tauxRemise', 'credit', 'annulees', 'sansPrix', 'sansRayon', 'sansSeuil',
      ]) {
        expect(sensIndicateur(c), SensIndicateur.hausseDefavorable, reason: c);
      }
    });

    test('neutres (achats, valeur du stock, part tiers payant…) et clé inconnue : sans jugement', () {
      for (final c in ['achats', 'achatTTC', 'achat', 'nbBons', 'achatMoyen', 'coutAchat', 'tiersPayant', 'partTiersPayant', 'tpFacture', 'valeurAchat', 'valeurVente', 'frequentation', 'inconnue', '']) {
        expect(sensIndicateur(c), SensIndicateur.neutre, reason: c);
      }
    });

    test('variationFavorable : la flèche suit le sens réel, le jugement dépend de l\'indicateur', () {
      expect(variationFavorable(8.5, SensIndicateur.hausseFavorable), isTrue);
      expect(variationFavorable(-3, SensIndicateur.hausseFavorable), isFalse);
      expect(variationFavorable(40, SensIndicateur.hausseDefavorable), isFalse, reason: 'taux de rupture en hausse : mauvais');
      expect(variationFavorable(-12, SensIndicateur.hausseDefavorable), isTrue, reason: 'ruptures en baisse : bon');
      expect(variationFavorable(5, SensIndicateur.neutre), isNull);
      expect(variationFavorable(0, SensIndicateur.hausseFavorable), isNull);
      expect(variationFavorable(null, SensIndicateur.hausseDefavorable), isNull);
    });

    Future<(IconData, String, Color)> rendu(WidgetTester tester, TuilePilotage t) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 220, child: TuileIndicateur(t)))));
      final v = find.byKey(Key('variation_${t.cle}'));
      final icone = tester.widget<Icon>(find.descendant(of: v, matching: find.byType(Icon)));
      final texte = tester.widget<Text>(find.descendant(of: v, matching: find.byType(Text)));
      return (icone.icon!, texte.data!, texte.style!.color!);
    }

    testWidgets('tuiles : taux de rupture en hausse = flèche ↑ en rouge ; CA en hausse = ↑ en vert ; 3.11.0 : sans « favorable / défavorable »', (tester) async {
      final (i1, t1, c1) = await rendu(tester, const TuilePilotage(cle: 'tauxRupture', libelle: 'Taux de rupture', valeur: 4.2, unite: '%', reference: 3, variation: 40));
      expect(i1, Icons.arrow_upward);
      expect(t1, isNot(contains('favorable')));
      expect(c1, Charte.rougeTexte);
      final (i2, t2, c2) = await rendu(tester, const TuilePilotage(cle: 'caTTC', libelle: 'CA', valeur: 10, unite: 'FCFA', reference: 9, variation: 11.1));
      expect(i2, Icons.arrow_upward);
      expect(t2, isNot(contains('favorable')));
      expect(c2, Charte.vertTexte);
      final (i3, t3, c3) = await rendu(tester, const TuilePilotage(cle: 'ruptures', libelle: 'Ruptures', valeur: 5, reference: 8, variation: -37.5));
      expect(i3, Icons.arrow_downward);
      expect(t3, isNot(contains('favorable')));
      expect(c3, Charte.vertTexte);
      final (i4, t4, c4) = await rendu(tester, const TuilePilotage(cle: 'achats', libelle: 'Achats', valeur: 12, unite: 'FCFA', reference: 11, variation: 9.1));
      expect(i4, Icons.arrow_upward);
      expect(t4, isNot(contains('favorable')));
      expect(c4, Charte.gris);
    });
  });

  group('Analyse de garde : pages de 100', () {
    test('limite 100 par défaut, bornée (1 à 100) ; synthèse seule : limit=1', () {
      expect(ApiGardes.taillePage, 100);
      expect(ApiGardes.parametresRapport()['limit'], '100');
      expect(ApiGardes.parametresRapport(limit: 1)['limit'], '1');
      expect(ApiGardes.parametresRapport(limit: 5000)['limit'], '100');
      expect(ApiGardes.parametresRapport(limit: 0)['limit'], '1', reason: 'jamais 0 : le serveur rendrait TOUT');
    });
  });

  group('CA emplacement / famille : choix multiple', () {
    test('identifiants séparés par des virgules (format du web), sans doublon ni vide', () {
      const f = FiltresCa(zones: ['Z1', 'Z3'], familles: ['F2'], grossistes: ['G1', 'G2', 'G1', ' ']);
      expect(f.parametres, {'typePeriode': 'TROIS_SEMAINES', 'regroupement': 'ZONE', 'zoneId': 'Z1,Z3', 'familleId': 'F2', 'grossisteId': 'G1,G2'});
      expect(f.actifs, 3);
      expect(const FiltresCa().parametres['zoneId'], '');
    });

    test('tout coché = aucun filtre ; partiel gardé ; liste inconnue : gardé tel quel', () {
      expect(FiltresCa.normaliser(['Z1', 'Z2'], ['Z1', 'Z2']), isEmpty);
      expect(FiltresCa.normaliser(['Z2', 'Z1', 'Z2'], ['Z1', 'Z2', 'Z3']), ['Z2', 'Z1']);
      expect(FiltresCa.normaliser(['Z1'], null), ['Z1']);
      expect(FiltresCa.normaliser(const [], ['Z1']), isEmpty);
    });

    test('compteur', () {
      expect(resumeChoixMultiple(0, 5), 'Aucun filtre (tous)');
      expect(resumeChoixMultiple(1, 5), '1 sélectionné');
      expect(resumeChoixMultiple(3, 5), '3 sélectionnés');
      expect(resumeChoixMultiple(5, 5), 'Tous (5)');
    });
  });
}
