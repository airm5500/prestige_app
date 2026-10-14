// Unitaires des retours du pharmacien appliqués en 3.8.0 (logique pure, sans écran ni serveur) :
// statut de la Visualisation BL lu par le serveur, paramètres et lecture des pages d'ajustements, 12 derniers mois
// glissants des Ratios mensuels (passage d'année, cumul par mois ET année, norme 1,51), classement 20/80 par
// quantité, texte et PDF des exports d'analyses, résultat de l'actualisation des rappels, route d'actualisation
// autorisée (les envois restent interdits).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prestige_app/donnees/ajustements_donnees.dart';
import 'package:prestige_app/donnees/analyses_pdf.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/donnees/tableau_bord_donnees.dart';
import 'package:prestige_app/donnees/visualisation_bl_donnees.dart';
import 'package:prestige_app/models/suivi_20_80_model.dart';
import 'package:prestige_app/models/tableau_bord_achats_ventes_model.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';

TableauBordAchatsVentes ligne(DateTime? d, double achat, double vente) =>
    TableauBordAchatsVentes(dateMvt: d, montantAchat: achat, montantVente: vente);

Suivi2080 article(String cip, int montant, int qte) => Suivi2080(cip: cip, libelle: cip, montant: montant, quantiteVendue: qte, stock: 0);

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('A1 · Visualisation BL', () {
    test('statuts du filtre = valeurs lues par le serveur (FiltresControleAchat.Statut)', () {
      expect(VisualisationBl.statutsControle.keys, ['CONTROLE', 'NON_CONTROLE']);
      expect(VisualisationBl.statuts.keys, ['TERMINE', 'NON_TRAITE', 'EN_COURS'], reason: 'écran d\'origine : inchangé');
    });
  });

  group('A3 · Ajustements par pages de 100', () {
    final d = DateTime(2026, 10, 1), f = DateTime(2026, 10, 14);
    test('première page = paramètres d\'origine ; pages suivantes : mêmes filtres, start et page', () {
      expect(Ajustements.parametresPage(d, f, start: 0), Ajustements.parametres(d, f));
      expect(Ajustements.parametresPage(d, f, typeId: 'TYP-1', start: 100),
          {'dtStart': '2026-10-01', 'dtEnd': '2026-10-14', 'typeFiltre': 'TYP-1', 'page': '2', 'start': '100', 'limit': '100'});
      expect(Ajustements.parametresPage(d, f, start: 200)['page'], '3');
    });

    test('lecture d\'une page : total nombre, texte, absent ou illisible', () {
      final data = [
        {'lgAJUSTEMENTID': 'A1', 'description': 'X'},
      ];
      expect(Ajustements.lirePage({'data': data, 'total': 230})!.total, 230);
      expect(Ajustements.lirePage({'data': data, 'total': '230'})!.total, 230);
      expect(Ajustements.lirePage({'data': data})!.total, isNull, reason: 'serveur sans total');
      expect(Ajustements.lirePage({'data': data, 'total': -1})!.total, isNull);
      expect(Ajustements.lirePage({'data': data})!.ajustements.single.lgAJUSTEMENTID, 'A1');
      expect(Ajustements.lirePage('pas une carte'), isNull);
    });
  });

  group('B2 · Ratios des 12 derniers mois', () {
    test('période : 1er jour du mois d\'il y a 11 mois → aujourd\'hui, passage d\'année compris', () {
      expect(TableauBord.douzeDerniersMois(DateTime(2026, 10, 14, 9, 30)), (DateTime(2025, 11, 1), DateTime(2026, 10, 14)));
      expect(TableauBord.douzeDerniersMois(DateTime(2026, 1, 3)), (DateTime(2025, 2, 1), DateTime(2026, 1, 3)));
      expect(TableauBord.douzeDerniersMois(DateTime(2026, 12, 31)), (DateTime(2026, 1, 1), DateTime(2026, 12, 31)));
      expect(TableauBord.parametres(DateTime(2025, 11, 1), DateTime(2026, 10, 14)), {'dtStart': '2025-11-01', 'dtEnd': '2026-10-14'});
    });

    test('cumul par mois ET année, ordre chronologique, même ratio et même norme 1,51', () {
      final m = TableauBord.mensuelsParAnnee([
        ligne(DateTime(2026, 10, 5), 100, 151),
        ligne(DateTime(2025, 10, 15), 100, 120),
        ligne(DateTime(2025, 11, 2), 50, 80),
        ligne(DateTime(2025, 11, 20), 50, 80),
        ligne(null, 999, 999),
      ]);
      expect([for (final x in m) x.moisAnnee], ['octobre 2025', 'novembre 2025', 'octobre 2026']);
      expect(m[1].totalAchats, 100);
      expect(m[1].totalVentes, 160);
      expect(m[1].ratio, closeTo(1.6, 1e-9));
      expect(TableauBord.position(m[0].ratio), PositionNorme.sousLaNorme);
      expect(TableauBord.position(m[2].ratio), PositionNorme.conforme, reason: '1,51 = norme');
      expect(TableauBord.norme, 1.51);
    });

    test('mêmes données sur une seule année : mêmes cumuls que le calcul d\'origine', () {
      final l = [ligne(DateTime(2026, 8, 2), 100, 153), ligne(DateTime(2026, 9, 1), 200, 290), ligne(DateTime(2026, 8, 30), 10, 10)];
      final a = TableauBord.mensuels(l), b = TableauBord.mensuelsParAnnee(l);
      expect([for (final x in b) (x.month, x.totalAchats, x.totalVentes, x.ratio)], [for (final x in a) (x.month, x.totalAchats, x.totalVentes, x.ratio)]);
    });
  });

  group('B3 · Suivi 20/80 par quantité', () {
    final d = DateTime(2026, 10, 1), f = DateTime(2026, 10, 14);
    test('chiffre d\'affaires : paramètres d\'origine ; quantité : + vingtType=QTY', () {
      final ca = Suivi2080Donnees.parametres(d, f, 50);
      expect(ca.containsKey('vingtType'), isFalse);
      expect(Suivi2080Donnees.parametres(d, f, 50, critere: CritereVingt.quantite), {...ca, 'vingtType': 'QTY'});
    });

    test('classement : CA = ordre du serveur ; quantité = décroissante, stable à égalité', () {
      final l = [article('A', 900, 5), article('B', 500, 40), article('C', 300, 5), article('D', 100, 60)];
      expect(Suivi2080Donnees.classer(l, CritereVingt.chiffreAffaires), same(l));
      expect([for (final a in Suivi2080Donnees.classer(l, CritereVingt.quantite)) a.cip], ['D', 'B', 'A', 'C']);
      expect(Suivi2080Donnees.montantTotal(Suivi2080Donnees.classer(l, CritereVingt.quantite)), Suivi2080Donnees.montantTotal(l));
    });
  });

  group('B4 · PDF des analyses', () {
    const c = ContenuAnalysePdf(
      officine: 'PHARMACIE FICTIVE',
      titre: 'Statistiques TVA',
      periode: 'Aujourd\'hui · 14/10/2026',
      filtres: [('Type de vente', 'Vente Non-Ordonnancée')],
      imprimeLe: '14/10/2026 à 09:05',
      chiffres: [('Total TTC', '1 749 000 F')],
      titreDetail: 'Par taux',
      colonnes: ['Taux', 'TTC'],
      droite: {1},
      lignes: [
        ['18 %', '590 000 F'],
        ['0 %', '1 159 000 F'],
      ],
      total: ['Total', '1 749 000 F'],
    );

    test('texte dans l\'ordre du document', () {
      expect(c.texte, [
        'PHARMACIE FICTIVE',
        'Statistiques TVA',
        'Période : Aujourd\'hui · 14/10/2026',
        'Type de vente : Vente Non-Ordonnancée',
        'Imprimé le 14/10/2026 à 09:05',
        'Total TTC : 1 749 000 F',
        'Par taux',
        'Taux | TTC',
        '18 % | 590 000 F',
        '0 % | 1 159 000 F',
        'Total | 1 749 000 F',
      ]);
      expect(ContenuAnalysePdf.horodatage(DateTime(2026, 10, 4, 7, 3)), '04/10/2026 à 07:03');
    });

    test('nom du fichier', () {
      expect(AnalysesPdf.nom('Stat_TVA', DateTime(2026, 10, 14), DateTime(2026, 10, 14)), 'Stat_TVA_2026-10-14');
      expect(AnalysesPdf.nom('CA_credit', DateTime(2026, 10, 1), DateTime(2026, 10, 14)), 'CA_credit_2026-10-01_au_2026-10-14');
    });

    test('PDF A4 contenant officine, titre, filtres, montants et total ; plusieurs pages pour une longue liste', () async {
      final o = latin1.decode(await AnalysesPdf.octets(c, compresser: false));
      expect(o, startsWith('%PDF'));
      expect(o, contains('MediaBox[0 0 595.27559 841.88976]'), reason: 'A4');
      for (final mot in ['PHARMACIE', 'FICTIVE', 'Statistiques', 'Ordonnanc', '590', '749', 'Total']) {
        expect(o, contains(mot), reason: mot);
      }
      final long = ContenuAnalysePdf(
        officine: 'P',
        titre: 'Marge Produits Vendus',
        periode: 'p',
        filtres: const [],
        imprimeLe: 'i',
        chiffres: const [],
        titreDetail: 'Produits',
        colonnes: const ['CIP', 'Produit'],
        lignes: [for (var i = 0; i < 300; i++) ['C$i', 'PRODUIT $i']],
      );
      expect(long.texte, contains('Filtres : aucun'));
      final p = latin1.decode(await AnalysesPdf.octets(long, compresser: false));
      expect(RegExp(r'/Type\s*/Page\b').allMatches(p).length, greaterThan(1), reason: 'plusieurs pages');
    });
  });

  group('C2 · Actualisation des rappels', () {
    test('route autorisée (à la demande) ; envois, réglages et réponses toujours interdits', () {
      expect(routeInterditeVague3(ApiRappels.routeActualiser), isFalse);
      for (final r in ['/rappels-habitude/envoyer', '/rappels-habitude/sms', '/avis-clients/avis/A/repondre', '/avis-clients/reglages']) {
        expect(routeInterditeVague3(r), isTrue, reason: r);
      }
      expect(ApiRappels.delaiActualisation, const Duration(minutes: 5));
    });

    test('résultat lu de façon tolérante et message', () {
      final r = ResultatActualisation.depuis({'success': true, 'inscrits': '4', 'achetes': 2, 'habitudes': 40});
      expect((r.inscrits, r.rachetes, r.habitudes), (4, 2, 40));
      expect(r.message, 'Liste actualisée : 4 nouveaux rappels, 2 rachetés.');
      expect(ResultatActualisation.depuis(const {}).message, 'Liste actualisée : 0 nouveau rappel, 0 racheté.');
    });
  });
}
