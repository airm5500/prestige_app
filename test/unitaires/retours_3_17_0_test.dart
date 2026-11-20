// Réponse du serveur aux demandes 67 et 68 (3.17.0), logique seule (données fictives) :
//  - /ca-credit : réponse OBJET (serveur à jour, avec limit) → page ; LISTE (serveur ancien) → liste ; autre forme →
//    null ; paramètres d'une page (start, limit, query / tiersPayant seulement s'ils sont donnés) ; délai propre à la
//    route (≥ 45 s) ; mode retenu par source ;
//  - /tableau-bord/tva : { taux, ht, tva, ttc } → mêmes lignes que la Stat TVA ; forme inattendue → null.
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/models/stat_tva_model.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/donnees_3_17_0.dart';
import '../support/donnees_lot3.dart';
import '../support/grandes_donnees.dart';

void main() {
  group('67 · /ca-credit', () {
    test('liste (serveur ancien) → mode liste, mêmes ventes que la 3.16.0', () {
      final r = CaCreditDonnees.lireReponse(DonneesLot3.caCredit());
      expect(r, isNotNull);
      expect(r!.pagine, isFalse);
      expect(r.liste!.map((c) => c.numFacturation), CaCreditDonnees.lire(DonneesLot3.caCredit())!.map((c) => c.numFacturation));
    });

    test('objet (serveur à jour) → page : totaux de toutes les lignes, tiers payants de la période, lignes de la page', () {
      final lignes = GrandesDonnees.caCredit(130);
      final r = CaCreditDonnees.lireReponse(Donnees3170.caCredit(lignes, {'start': '0', 'limit': '50'}));
      expect(r!.pagine, isTrue);
      final p = r.page!;
      expect(p.total, 130);
      expect(p.data, hasLength(50));
      expect(p.montant, lignes.fold<num>(0, (s, o) => s + (o['montant'] as num)));
      expect(p.clients, 130);
      expect(p.tiersPayants, hasLength(9));
      // Ordre du serveur : date décroissante.
      expect(p.data.first.mvtDate!.isBefore(p.data.last.mvtDate!) , isFalse);
    });

    test('limit=0 : totaux seuls ; au-delà du total : page vide', () {
      final lignes = GrandesDonnees.caCredit(20);
      final zero = CaCreditDonnees.lireReponse(Donnees3170.caCredit(lignes, {'limit': '0'}))!.page!;
      expect(zero.total, 20);
      expect(zero.data, isEmpty);
      final loin = CaCreditDonnees.lireReponse(Donnees3170.caCredit(lignes, {'start': '50', 'limit': '50'}))!.page!;
      expect(loin.total, 20);
      expect(loin.data, isEmpty);
    });

    test('forme inattendue → null', () {
      expect(CaCreditDonnees.lireReponse({'success': false, 'msg': 'x'}), isNull);
      expect(CaCreditDonnees.lireReponse({'total': '3', 'data': []}), isNull);
      expect(CaCreditDonnees.lireReponse({'total': 3, 'data': 'x'}), isNull);
      expect(CaCreditDonnees.lireReponse({'total': 1, 'data': ['pas un objet']}), isNull);
      expect(CaCreditDonnees.lireReponse('texte'), isNull);
      expect(CaCreditDonnees.lireReponse(null), isNull);
    });

    test('champs facultatifs de la page absents : valeurs neutres', () {
      final p = PageCaCredit.lire({'total': 0, 'data': []})!;
      expect(p.montant, 0);
      expect(p.clients, 0);
      expect(p.tiersPayants, isEmpty);
    });

    test('paramètres : start, limit ; query et tiersPayant seulement s\'ils sont donnés (libellé envoyé tel quel)', () {
      final d = DateTime(2026, 10, 1), f = DateTime(2026, 10, 21);
      expect(CaCreditDonnees.parametresPage(d, f), {...CaCreditDonnees.parametres(d, f), 'start': '0', 'limit': '50'});
      expect(CaCreditDonnees.parametresPage(d, f, start: 100, query: 'FAC', tiersPayant: Donnees3170.tiersEspace),
          {...CaCreditDonnees.parametres(d, f), 'start': '100', 'limit': '50', 'query': 'FAC', 'tiersPayant': Donnees3170.tiersEspace});
      expect(CaCreditDonnees.taillePage, 50);
    });

    test('délai d\'attente propre à la route : au moins 45 s (première page de 12 à 16 s), sans changer les autres', () {
      expect(CaCreditDonnees.delai, greaterThanOrEqualTo(const Duration(seconds: 45)));
      expect(ApiService.delaiGet, const Duration(seconds: 45));
    });

    test('mode retenu par source (serveur et session), oublié sur demande', () {
      CaCreditDonnees.oublierModes();
      expect(CaCreditDonnees.modeConnu('local|1'), isNull);
      CaCreditDonnees.noterMode('local|1', false);
      CaCreditDonnees.noterMode('distant|1', true);
      expect(CaCreditDonnees.modeConnu('local|1'), isFalse);
      expect(CaCreditDonnees.modeConnu('distant|1'), isTrue);
      expect(CaCreditDonnees.modeConnu('local|2'), isNull, reason: 'autre session : à détecter de nouveau');
      CaCreditDonnees.oublierModes();
      expect(CaCreditDonnees.modeConnu('local|1'), isNull);
    });

    test('faux serveur à jour : pages bout à bout = liste filtrée triée ; libellé entouré d\'espaces trouvé', () {
      final lignes = GrandesDonnees.caCredit(137);
      final vues = <String>[];
      for (var start = 0; start < 200; start += 50) {
        final p = PageCaCredit.lire(Donnees3170.caCredit(lignes, {'start': '$start', 'limit': '50', 'query': 'fictif 1'}))!;
        vues.addAll(p.data.map((c) => c.numFacturation));
      }
      expect(vues, [for (final o in Donnees3170.trier(Donnees3170.filtrer(lignes, 'fictif 1', null))) o['numFacturation']]);
      final e = PageCaCredit.lire(Donnees3170.caCredit(Donnees3170.ventesAvecEspace(), {'limit': '50', 'tiersPayant': Donnees3170.tiersEspace.trim()}))!;
      expect(e.total, 1);
    });
  });

  group('68 · /tableau-bord/tva', () {
    test('{ taux, ht, tva, ttc } → mêmes lignes (HT, TVA, TTC par taux) que /api/v3/tvas TOUT', () {
      final nouvelle = ApiTableauBord.lireTva(Map<String, dynamic>.from(Donnees3170.tva()))!;
      final ancienne = StatTvaDonnees.lire(DonneesLot3.statTva('TOUT'))!;
      String l(StatTva t) => '${t.taux}|${t.totalHt}|${t.totalTva}|${t.totalTtc}';
      expect(nouvelle.map(l), ancienne.map(l));
      expect(StatTvaDonnees.totalTtc(nouvelle), StatTvaDonnees.totalTtc(ancienne));
    });

    test('aucune vente : liste vide (carte « Aucune vente ce mois-ci »)', () {
      expect(ApiTableauBord.lireTva({'success': true, 'data': []}), isEmpty);
    });

    test('forme inattendue → null (repli sur /api/v3/tvas)', () {
      expect(ApiTableauBord.lireTva({'success': true}), isNull);
      expect(ApiTableauBord.lireTva({'data': 'x'}), isNull);
      expect(ApiTableauBord.lireTva({'data': ['x']}), isNull);
      expect(ApiTableauBord.lireTva({'data': [{'taux': 18, 'ht': 1, 'tva': 1}]}), isNull, reason: 'ttc absent');
      expect(ApiTableauBord.lireTva({'data': [{'TAUX': 18, 'Total HT': 1, 'Total TVA': 1, 'Total TTC': 2}]}), isNull, reason: 'format de /tvas');
      expect(ApiTableauBord.lireTva({'data': [{'taux': '18', 'ht': 1, 'tva': 1, 'ttc': 2}]}), isNull);
    });

    test('route', () => expect(ApiTableauBord.routeTva, '/tableau-bord/tva'));
  });
}
