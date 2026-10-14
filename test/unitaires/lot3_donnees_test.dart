// Calculs PARTAGÉS du lot 3 (lib/donnees/tableau_bord_donnees.dart, lib/donnees/analyses_ventes_donnees.dart) :
// ratio ventes / achats et norme 1,51 (achat normé, vente normée, position), cumul mensuel, tri des jours, filtre
// local de marge (7 opérateurs), nombre d'articles du 20/80, parts du TTC, cumul et CA net du CA Global, recherche
// locale du CA Crédit ; abréviations des axes de graphique.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/donnees/tableau_bord_donnees.dart';
import 'package:prestige_app/models/ca_credit_model.dart';
import 'package:prestige_app/models/ca_global_model.dart';
import 'package:prestige_app/models/marge_produit_vendu_model.dart';
import 'package:prestige_app/models/stat_tva_model.dart';
import 'package:prestige_app/models/tableau_bord_achats_ventes_model.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun_lot3.dart';
import 'package:prestige_app/utils/constants.dart';

TableauBordAchatsVentes ligne(String? d, double a, double v) =>
    TableauBordAchatsVentes.fromJson({'dateMvt': d, 'montantAchat': a, 'montantVente': v});

MargeProduitVendu produit(int pct) => MargeProduitVendu(code: 'C$pct', libelle: 'P$pct', montantAchat: 0, montantVente: 0, montantMarge: 0, margePourcentage: pct);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('Tableau de bord : ratio et norme', () {
    test('norme 1,51 conservée, ratio ventes / achats (0 sans achat)', () {
      expect(TableauBord.norme, 1.51);
      expect(TableauBord.norme, AppConstants.ratioNormeVenteAchat);
      expect(TableauBord.ratio(100000, 151000), 1.51);
      expect(TableauBord.ratio(0, 5000), 0);
      expect(ligne('01/10/2026', 200, 300).ratio, TableauBord.ratio(200, 300));
    });

    test('position : sans achat, ≥ norme (pile 1,51 compris), sous la norme', () {
      expect(TableauBord.position(0), PositionNorme.sansAchat);
      expect(TableauBord.position(1.51), PositionNorme.conforme);
      expect(TableauBord.position(2), PositionNorme.conforme);
      expect(TableauBord.position(1.5099), PositionNorme.sousLaNorme);
      expect(libelleNorme(PositionNorme.conforme).$1, '≥ norme');
      expect(libelleNorme(PositionNorme.sousLaNorme).$1, '< norme');
    });

    test('achat normé = vente / 1,51 ; vente normée = achat × 1,51 ; rien pour 0, négatif ou vide', () {
      expect(TableauBord.achatNorme(151000), closeTo(100000, 1e-6));
      expect(TableauBord.venteNormee(100000), closeTo(151000, 1e-6));
      expect(TableauBord.achatNorme(0), isNull);
      expect(TableauBord.achatNorme(null), isNull);
      expect(TableauBord.venteNormee(-5), isNull);
    });

    test('lecture : liste attendue, sinon null ; tri par date, dates absentes à la fin', () {
      expect(TableauBord.lire({'data': []}), isNull);
      final l = TableauBord.lire([
        {'dateMvt': '03/10/2026', 'montantAchat': 1, 'montantVente': 2},
        {'dateMvt': null, 'montantAchat': 1, 'montantVente': 2},
        {'dateMvt': '01/10/2026', 'montantAchat': 1, 'montantVente': 2},
      ])!;
      expect([for (final x in TableauBord.trier(l)) x.dateMvt?.day], [1, 3, null]);
      expect([for (final x in l) x.dateMvt?.day], [3, null, 1], reason: 'ordre du serveur gardé pour les Ratios');
    });

    test('ratios mensuels : cumul par mois (lignes datées), mois croissants, année en cours', () {
      final m = TableauBord.mensuels([
        ligne('05/09/2026', 100, 160),
        ligne('02/08/2026', 200, 300),
        ligne(null, 999, 999),
        ligne('20/09/2026', 300, 440),
      ]);
      expect([for (final x in m) x.month], [8, 9]);
      expect(m[1].totalAchats, 400);
      expect(m[1].totalVentes, 600);
      expect(m[1].ratio, 1.5);
      expect(m[0].monthName, 'août');
      final (debut, fin) = TableauBord.anneeEnCours(DateTime(2026, 10, 14, 9));
      expect(debut, DateTime(2026, 1, 1));
      expect(fin, DateTime(2026, 10, 14, 9));
    });
  });

  group('Marge Produits Vendus : filtre local d\'origine', () {
    final l = [for (final p in [-2, 9, 10, 11, 20]) produit(p)];
    List<int> f(OperateurMarge op, String v) => [for (final p in MargeDonnees.filtrer(l, op, v)) p.margePourcentage];

    test('7 opérateurs', () {
      expect(f(OperateurMarge.egal, '10'), [10]);
      expect(f(OperateurMarge.superieur, '10'), [11, 20]);
      expect(f(OperateurMarge.inferieur, '10'), [-2, 9]);
      expect(f(OperateurMarge.superieurEgal, '10'), [10, 11, 20]);
      expect(f(OperateurMarge.inferieurEgal, '-2'), [-2]);
      expect(f(OperateurMarge.different, '10'), [-2, 9, 11, 20]);
      expect(f(OperateurMarge.environ, '10'), [9, 10, 11]);
    });

    test('valeur vide ou non entière : aucun filtre', () {
      expect(f(OperateurMarge.superieur, ''), hasLength(5));
      expect(f(OperateurMarge.superieur, '-'), hasLength(5));
      expect(OperateurMarge.de('~='), OperateurMarge.environ);
      expect(OperateurMarge.de('?'), OperateurMarge.egal);
    });
  });

  test('Suivi 20/80 : nombre d\'articles de 1 à 9 999, sinon 50 ; paramètres fixes d\'origine', () {
    expect(Suivi2080Donnees.limite('80'), 80);
    expect(Suivi2080Donnees.limite(''), 50);
    expect(Suivi2080Donnees.limite('0'), 50);
    expect(Suivi2080Donnees.limite('10000'), 50);
    expect(Suivi2080Donnees.parametres(DateTime(2026, 10, 1), DateTime(2026, 10, 14), 50), {
      'dtStart': '2026-10-01', 'dtEnd': '2026-10-14', 'limit': '50', 'codeFamile': '', 'codeRayon': '', 'codeGrossiste': '', 'qtyOrCa': 'false',
      'page': '1', 'start': '0',
    });
  });

  test('Stat TVA : totaux et parts du TTC (vides si TTC nul), types de vente', () {
    final l = [
      StatTva(totalTva: 0, totalTtc: 750, taux: 0, totalHt: 750, montantUg: 0),
      StatTva(totalTva: 45, totalTtc: 250, taux: 18, totalHt: 205, montantUg: 0),
    ];
    expect(StatTvaDonnees.totalTtc(l), 1000);
    expect(StatTvaDonnees.parts(l), [75, 25]);
    expect(StatTvaDonnees.parts([StatTva(totalTva: 0, totalTtc: 0, taux: 0, totalHt: 0, montantUg: 0)]), isEmpty);
    expect([for (final t in TypeVente.values) t.valeur], ['TOUT', 'VNO', 'VO']);
  });

  test('CA Global : tri, cumul, CA brut et net (brut − remise)', () {
    final l = CaGlobalDonnees.lire([
      {'mvtDate': '20261014', 'totEsp': 100, 'montantCredit': 50, 'remiseSurCA': 10},
      {'mvtDate': '20261012', 'totEsp': 200, 'totMobile': 30, 'remiseSurCA': 5},
    ])!;
    expect([for (final x in l) x.mvtDate!.day], [12, 14]);
    final c = CaGlobalDonnees.cumul(l);
    expect(c.totalCa, 380);
    expect(CaGlobalDonnees.net(c), 365);
    expect(CaGlobalDonnees.cumul(const <CaGlobal>[]).totalCa, 0);
    expect([for (final (libelle, _) in CaGlobalDonnees.modes(c)) libelle].first, 'Total Espèces');
  });

  test('CA Crédit : recherche locale sur client, ayant droit, facture, tiers payant (sans casse)', () {
    CaCredit c(String client, String ayant, String fac, String tp) => CaCredit(
        ayantDroitName: ayant, clientId: '', clientName: client, montant: 1, numFacturation: fac, tiersPayantId: '', tiersPayantLibelle: tp);
    final l = [c('ALPHA', 'ALPHA', 'F-1', 'ASSUR'), c('BETA', 'ENFANT', 'F-2', 'MUTUELLE')];
    expect(CaCreditDonnees.filtrer(l, '').length, 2);
    expect([for (final x in CaCreditDonnees.filtrer(l, 'enfant')) x.clientName], ['BETA']);
    expect([for (final x in CaCreditDonnees.filtrer(l, 'f-1')) x.clientName], ['ALPHA']);
    expect([for (final x in CaCreditDonnees.filtrer(l, 'mutu')) x.clientName], ['BETA']);
  });

  test('graphiques : montants abrégés, ratio et pourcentage à la française', () {
    expect(montantCourt(850), '850');
    expect(montantCourt(12400), '12 k');
    expect(montantCourt(1250000), '1,3 M');
    expect(montantCourt(-3000), '-3 k');
    expect(formaterRatio(1.5), '1,50');
    expect(formaterPourcent(33.73), '33,7 %');
  });
}
