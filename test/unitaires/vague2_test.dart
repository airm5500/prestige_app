// Unitaires de la vague 2 (lib/nouvelle_interface/vague2/donnees_vague2.dart) : lecture TOLÉRANTE des quatre
// formats (Prévisions, Pilotage, Analyse de garde, CA emplacement / famille, dont les colonnes dynamiques
// t_<cle> / q_<cle> / e_<cle>), classement des refus (droit manquant / erreur du serveur / demande refusée),
// contrôles des saisies (période libre et personnalisée, mois de l'analyse de la demande, tranches horaires, classe),
// routes interdites, mise en forme (valeur avec unité, variation), onglets de la barre du bas.
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/donnees_vague2.dart';

TypeMatcher<ApiLoadException> nature(NatureErreur n) => isA<ApiLoadException>().having((e) => e.nature, 'nature', n);

void main() {
  group('Réponses : refus et erreurs distincts', () {
    test('succès : carte rendue ; vide : carte vide ; autre chose qu\'un objet : réponse illisible', () {
      expect(lireReponseVague2({'success': true, 'x': 1}, 'quoi')['x'], 1);
      expect(lireReponseVague2(null, 'quoi'), isEmpty);
      expect(() => lireReponseVague2([1, 2], 'quoi'), throwsA(nature(NatureErreur.reponse)));
    });

    test('« Vous n\'avez pas accès… », interdit:true, message vide → Droit manquant', () {
      expect(() => lireReponseVague2({'success': false, 'msg': 'Vous n\'avez pas accès à l\'analyse des commandes.'}, 'les prévisions'),
          throwsA(nature(NatureErreur.droit).having((e) => e.message, 'message', startsWith('Droit manquant : consulter les prévisions.'))));
      expect(() => lireReponseVague2({'success': false, 'message': 'Votre profil ne donne pas accès au pilotage de l\'officine.'}, 'le pilotage'),
          throwsA(nature(NatureErreur.droit)));
      expect(() => lireReponseVague2({'interdit': true}, 'x'), throwsA(nature(NatureErreur.droit)));
      expect(() => lireReponseVague2({'success': false}, 'x'), throwsA(nature(NatureErreur.droit)));
    });

    test('calcul en échec côté serveur → erreur du serveur ; message métier → demande refusée (message du serveur)', () {
      expect(() => lireReponseVague2({'success': false, 'message': 'Les chiffres n\'ont pas pu être rassemblés.'}, 'le pilotage'),
          throwsA(nature(NatureErreur.serveur)));
      expect(() => lireReponseVague2({'success': false, 'msg': 'Le calcul du chiffre d\'affaires a échoué'}, 'x'), throwsA(nature(NatureErreur.serveur)));
      expect(() => lireReponseVague2({'success': false, 'erreur': true}, 'x'), throwsA(nature(NatureErreur.serveur)));
      expect(() => lireReponseVague2({'success': false, 'msg': 'Cette garde n\'existe plus.'}, 'x'),
          throwsA(nature(NatureErreur.refus).having((e) => e.message, 'message', 'Cette garde n\'existe plus.')));
    });

    test('routes interdites : écritures, recalculs, créations (y compris d\'une garde) ; lectures autorisées', () {
      for (final r in routesInterditesTestees) {
        expect(routeInterditeVague2(r), isTrue, reason: r);
      }
      expect(routeInterditeVague2('/gardes/X/inventaire?y=1'), isTrue);
      for (final r in [
        '/analyse-commande/previsions',
        '/analyse-commande/analyse',
        '/analyse-commande/demande',
        '/pilotage/onglet/synthese',
        '/pilotage/controler',
        '/gardes',
        '/gardes/GARDE-TEST-1/rapport',
        '/ca-zone-geo',
        '/ca-zone-geo/detail',
      ]) {
        expect(routeInterditeVague2(r), isFalse, reason: r);
      }
    });
  });

  group('Prévisions', () {
    test('tableau : chiffres, nulls tolérés, « calcule » absent déduit', () {
      final t = TableauPrevisions.depuis(DonneesVague2.tableau());
      expect(t.calcule, isTrue);
      expect(t.aCommander, 42);
      expect(t.valeurACommander, 1250000);
      expect(t.tauxRupture, 4.2);
      expect(t.methodes.first, ('MOYENNE', 300, 74));
      final v = TableauPrevisions.depuis({'success': true, 'calcule': false});
      expect(v.calcule, isFalse);
      final texte = TableauPrevisions.depuis({'produits': '1 240', 'fiabilite': null, 'couvertureMoyenne': 'null', 'tauxRupture': '4,5'});
      expect(texte.calcule, isTrue);
      expect(texte.produits, 1240);
      expect(texte.fiabilite, isNull);
      expect(texte.couvertureMoyenne, isNull);
      expect(texte.tauxRupture, 4.5);
    });

    test('ligne : couverture null « — », méthode lisible, valeur absente = recommandé × PAF', () {
      final l = LignePrevision.depuis(DonneesVague2.lignePrevision(5));
      expect(l.couverture, isNull);
      expect(l.couvertureTexte, '—');
      expect(l.methodeLibelle, 'Moyenne 3 mois');
      expect(LignePrevision.depuis({'recommande': '3', 'paf': 1000.0}).valeur, 3000);
      expect(MethodePrevision.libelleDe('HOLT_WINTERS'), 'Tendance + saison');
      expect(MethodePrevision.libelleDe('INCONNUE'), 'INCONNUE');
    });

    test('filtres : paramètres exacts (pages de 25) ; nombre de filtres de la feuille', () {
      const f = FiltresPrevisions(filtre: FiltrePrevision.aCommander, methode: MethodePrevision.saison, recherche: '  doli ');
      expect(f.parametres(25, ApiPrevisions.taillePage),
          {'filtre': 'ACOMMANDER', 'query': 'doli', 'methode': 'SAISON', 'stock': '', 'start': '25', 'limit': '25'});
      expect(f.actifs, 1);
      expect(const FiltresPrevisions().parametres(0, 25)['filtre'], '');
    });

    test('détail produit : historique mensuel, méthodes comparées, détail du calcul', () {
      final d = DetailPrevision.depuis(DonneesVague2.produit(2));
      expect(d.historique, hasLength(6));
      expect(d.historique.first, ('avr. 26', 10));
      expect(d.methodes.where((m) => m.$3).single.$1, 'SAISON');
      expect(d.besoin, 6.5);
      expect(d.couvertureVoulue, 15);
      expect(d.rayon, 3);
      expect(DetailPrevision.depuis({'id': 'X'}).historique, isEmpty);
    });

    test('analyse : résumé, alertes graves, écart déduit, alertes en texte simple tolérées', () {
      final a = AnalyseSuggestion.depuis(DonneesVague2.analyse('SUGGESTION'));
      expect(a.nombreLignes, 3);
      expect(a.lignesAlerte, 2);
      expect(a.lignes.first.grave, isTrue);
      expect(a.lignes[1].couverture, isNull);
      final l = LigneAnalysee.depuis({'quantite': 5, 'recommande': 8, 'alertes': ['Texte seul', 3]});
      expect(l.ecart, -3);
      expect(l.alertes, [('Texte seul', false)]);
      final sansResume = AnalyseSuggestion.depuis({'data': [{'alertes': [{'texte': 'a'}]}, {}]});
      expect(sansResume.nombreLignes, 2);
      expect(sansResume.lignesAlerte, 1);
    });

    test('demande : matrice année × mois (null hors fenêtre), indices complétés à 12, tendance facultative', () {
      final d = DemandeSaisonniere.depuis(DonneesVague2.demande(12));
      expect(d.annees.first.mois.take(9), everyElement(isNull));
      expect(d.annees.first.mois[11], 520);
      expect(d.pic, 12);
      expect(d.tendanceEvolution, isNull);
      expect(DemandeSaisonniere.depuis(DonneesVague2.demande(24)).tendanceEvolution, 9.5);
      final court = DemandeSaisonniere.depuis({'indices': [1.2, 'x'], 'pic': null});
      expect(court.indices, hasLength(12));
      expect(court.indices[1], 0);
      expect(court.vide, isTrue);
      expect(nomMois(12), 'décembre');
      expect(nomMois(13), '—');
    });

    test('demande : 12, 24 ou 36 mois seulement ; recherche coupée à 100 ; délai long au-delà de 12 mois', () {
      expect(ApiPrevisions.parametresDemande(24, ' x ', 'R1'), {'mois': '24', 'query': 'x', 'rayonId': 'R1'});
      expect(() => ApiPrevisions.parametresDemande(18, '', ''), throwsArgumentError);
      expect(ApiPrevisions.parametresDemande(12, 'a' * 150, '')['query'], hasLength(100));
      expect(ApiPrevisions.delaiDemande(12), ApiVague2.delaiNormal);
      expect(ApiPrevisions.delaiDemande(36), ApiVague2.delaiLong);
      expect(ApiVague2.delaiLong, lessThanOrEqualTo(const Duration(minutes: 2)), reason: 'délai borné');
    });
  });

  group('Pilotage', () {
    test('tuiles : valeur, unité, référence, variation ; tuile sans référence ; alerte', () {
      final d = DonneesPilotage.depuis(DonneesVague2.synthese('VS_M1'));
      expect(d.libelleReference, 'septembre 2026');
      final ca = d.tuiles.first;
      expect(ca.valeurTexte, '${grouperMilliers(18450000)} F');
      expect(ca.variation, closeTo(8.5, 0.05));
      expect(ca.referenceTexte, '${grouperMilliers(17000000)} F');
      expect(d.tuiles.firstWhere((t) => t.cle == 'ratioVA').valeurTexte, '1,54');
      final m = DonneesPilotage.depuis(DonneesVague2.synthese('MOIS'));
      expect(m.tuiles.first.reference, isNull);
      expect(m.tuiles.first.variation, isNull);
      final s = DonneesPilotage.depuis(DonneesVague2.aSuivre('MOIS'));
      expect(s.tuiles.first.alerte, isTrue);
      expect(s.alertes.first.critique, isTrue);
      expect(s.margeNegative.single.paf, 2000);
      expect(DonneesPilotage.depuis({}).tuiles, isEmpty);
    });

    test('valeur avec unité, variation en clair', () {
      expect(valeurAvecUnite(-1500, 'FCFA'), '-${grouperMilliers(1500)} F');
      expect(valeurAvecUnite(12.345, '%'), '12,3 %');
      expect(valeurAvecUnite(3, ''), '3');
      expect(valeurAvecUnite(2.5, 'j'), '2,5 j');
      expect(variationTexte(12.34), '+12,3 %');
      expect(variationTexte(-3), '−3,0 %');
      expect(variationTexte(null), '—');
    });

    test('axe personnalisé : dates obligatoires et contrôlées (3 ans au plus, rien dans le futur)', () {
      final now = DateTime(2026, 10, 14);
      const perso = AxePilotage('PERSO', 'Période personnalisée');
      expect(ApiPilotage.erreurAxe(const ChoixAxe(perso), now), isNotNull);
      expect(ApiPilotage.erreurAxe(ChoixAxe(perso, debut: DateTime(2026, 10, 1), fin: DateTime(2026, 10, 15)), now), contains('futur'));
      expect(ApiPilotage.erreurAxe(ChoixAxe(perso, debut: DateTime(2022, 1, 1), fin: DateTime(2026, 10, 1)), now), contains('3 ans'));
      final ok = ChoixAxe(perso, debut: DateTime(2026, 9, 1), fin: DateTime(2026, 9, 30));
      expect(ApiPilotage.erreurAxe(ok, now), isNull);
      expect(ok.parametres, {'axe': 'PERSO', 'dtStart': '2026-09-01', 'dtEnd': '2026-09-30'});
      expect(const ChoixAxe(AxePilotage('VS_N1', '')).parametres, {'axe': 'VS_N1'});
    });
  });

  group('Analyse de garde', () {
    test('garde : dates lisibles, durée calculée si absente', () {
      final g = Garde.depuis(DonneesVague2.garde('G', '', '2026-09-05 20:00', '2026-09-06 08:00'));
      expect(g.debutLisible, '05/09/2026 20:00');
      expect(g.titre, 'Garde du 05/09/2026 20:00');
      expect(Garde.depuis({'dureeMinutes': 750}).duree, '12 h 30');
    });

    test('rapport : KPI, tranches, ABC, résumé ; « indicateurs » si « kpi » absent', () {
      final r = RapportGarde.depuis(DonneesVague2.rapport({'start': '0', 'limit': '100'}));
      expect(r.kpi.montant, 410000);
      expect(r.kpi.caMobile, 85000);
      expect(r.tranches, hasLength(6));
      expect(r.abc, hasLength(100));
      expect(r.totalFiltre, 130);
      expect(r.resume.first.classe, 'A');
      expect(RapportGarde.depuis({'indicateurs': {'ventes': 4}}).kpi.ventes, 4);
    });

    test('paramètres du rapport contrôlés (heures 1 à 4, classe A / B / C)', () {
      expect(ApiGardes.parametresRapport(heures: 3, tri: TriGarde.marge, classe: 'B', start: 100),
          {'heures': '3', 'tri': 'marge', 'classe': 'B', 'start': '100', 'limit': '100'});
      expect(() => ApiGardes.parametresRapport(heures: 7), throwsArgumentError);
      expect(() => ApiGardes.parametresRapport(classe: 'D'), throwsArgumentError);
    });
  });

  group('CA emplacement / famille : colonnes dynamiques', () {
    test('tranches du serveur ; t_ / q_ / e_ lues par tranche ; évolution null de la première', () {
      final c = ComparatifCa.depuis(DonneesVague2.caZone({'typePeriode': 'TROIS_SEMAINES', 'regroupement': 'ZONE'}));
      expect(c.tranches.map((t) => t.cle), ['2026-W39', '2026-W40', '2026-W41', '2026-W42']);
      expect(c.tranches.last.enCours, isTrue);
      final l = c.lignes.first;
      expect(l.de('2026-W39').montant, 100000);
      expect(l.de('2026-W40').quantite, 110);
      expect(l.de('2026-W39').evolution, isNull);
      expect(l.de('2026-W40').evolution, 10.0);
      expect(l.de('inconnue').montant, 0);
      expect(c.totauxTranches['2026-W39'], 160000);
      expect(c.evolutionsTranches['2026-W39'], isNull);
      expect(c.evolutionGenerale, 18.2);
      expect(l.titre(RegroupementCa.zone), 'RAYON A');
    });

    test('tranches absentes : déduites des colonnes t_<cle> ; totaux calculés ; nombres en texte', () {
      final c = ComparatifCa.depuis({
        'data': [
          {'zone': 'Z', 'famille': 'F', 't_2026-02': '1 000', 't_2026-01': 500, 'q_2026-01': '5', 'e_2026-02': '100,0', 'total': 1500},
        ],
      });
      expect(c.tranches.map((t) => t.cle), ['2026-01', '2026-02']);
      expect(c.lignes.single.de('2026-02').montant, 1000);
      expect(c.lignes.single.de('2026-02').evolution, 100.0);
      expect(c.totauxTranches, {'2026-01': 500, '2026-02': 1000});
      expect(c.totalGeneral, 1500);
      expect(c.lignes.single.titre(RegroupementCa.zoneFamille), 'Z · F');
      expect(const LigneCa().titre(RegroupementCa.famille), '(sans famille)');
    });

    test('filtres : paramètres exacts ; période libre contrôlée ; 3 ans = calcul long', () {
      final now = DateTime(2026, 10, 14);
      const f = FiltresCa(regroupement: RegroupementCa.famille, zones: ['ZONE-TEST-1']);
      expect(f.parametres, {'typePeriode': 'TROIS_SEMAINES', 'regroupement': 'FAMILLE', 'zoneId': 'ZONE-TEST-1', 'familleId': '', 'grossisteId': ''});
      expect(f.erreur(now), isNull);
      expect(f.long, isFalse);
      expect(const FiltresCa(type: TypePeriodeCa.troisAns).long, isTrue);
      expect(const FiltresCa(type: TypePeriodeCa.libre).erreur(now), isNotNull);
      final libre = FiltresCa(type: TypePeriodeCa.libre, debut: DateTime(2026, 9, 1), fin: DateTime(2026, 9, 30));
      expect(libre.erreur(now), isNull);
      expect(libre.parametres['dtStart'], '2026-09-01');
      expect(FiltresCa(type: TypePeriodeCa.libre, debut: DateTime(2026, 9, 1), fin: DateTime(2026, 8, 1)).erreur(now), isNotNull);
      expect(FiltresCa(type: TypePeriodeCa.libre, debut: DateTime(2020, 1, 1), fin: DateTime(2026, 8, 1)).erreur(now), contains('3 ans'));
      expect(FiltresCa(type: TypePeriodeCa.libre, debut: DateTime(2024, 1, 1), fin: DateTime(2026, 1, 1)).long, isTrue);
      expect(ApiCaZone.delai(const FiltresCa(type: TypePeriodeCa.troisAns)), ApiVague2.delaiLong);
    });

    test('détail d\'une ligne : identifiants selon le regroupement', () {
      const l = LigneCa(zoneId: 'Z1', familleId: 'F1');
      expect(ApiCaZone.parametresDetail(const FiltresCa(), l)['ligneZoneId'], 'Z1');
      expect(ApiCaZone.parametresDetail(const FiltresCa(), l)['ligneFamilleId'], '');
      expect(ApiCaZone.parametresDetail(const FiltresCa(regroupement: RegroupementCa.famille), l)['ligneZoneId'], '');
      expect(ApiCaZone.parametresDetail(const FiltresCa(regroupement: RegroupementCa.zoneFamille), l)['ligneFamilleId'], 'F1');
    });
  });

  test('barre du bas : 3 onglets, 4 avec Pilotage pour l\'administrateur et le pharmacien', () {
    expect(ongletsAccueil(responsable: false), [OngletAccueil.accueil, OngletAccueil.analyses, OngletAccueil.equipe]);
    expect(ongletsAccueil(responsable: true).last, OngletAccueil.pilotage);
  });
}
