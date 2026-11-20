// Retours du pharmacien pour la 3.16.0 — règles sans écran (données fictives uniquement) :
//  1. adresse par défaut d'une NOUVELLE configuration : 192.168.1.50:8080 (comme Prestige Mobile et Prestige Vente) ;
//     une adresse déjà enregistrée (même vide) n'est jamais remplacée ;
//  2. cache court (lib/donnees/cache_court.dart) : lecture en cours partagée, durée de vie, échec et abandon jamais
//     gardés ; lecture des lignes de /vente/search (repli de la recherche d'articles) ;
//  3. État de stock : 1 ou 2 caractères ne partent pas, 3 et plus (ou un CIP / EAN complet) oui ;
//  5. CA crédit : recherche et filtre calculés une fois (VueCaCredit), mêmes ventes que la recherche d'origine.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/donnees/cache_court.dart';
import 'package:prestige_app/donnees/etat_stock_donnees.dart';
import 'package:prestige_app/donnees/recherche_produit_donnees.dart';
import 'package:prestige_app/models/ca_credit_model.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/providers/ip_config_provider.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<IpConfigProvider> configuration(Map<String, Object> enregistre) async {
  SharedPreferences.setMockInitialValues(enregistre);
  final p = IpConfigProvider(); // relit les réglages (lecture lancée par le constructeur)
  await pumpEventQueue();
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1 · Adresse par défaut', () {
    test('nouvelle configuration : 192.168.1.50:8080, application prestige, non configurée', () async {
      final p = await configuration({});
      expect(p.localIp, '192.168.1.50');
      expect(p.port, '8080');
      expect(p.appName, 'prestige');
      expect(p.isAppConfigured, isFalse);
      expect(p.racineServeur, 'http://192.168.1.50:8080/prestige');
      expect(p.remoteIp, isEmpty, reason: 'aucune adresse distante inventée');
    });

    test('adresse déjà enregistrée : jamais remplacée (adresse, port, adresse vide comprise)', () async {
      final p = await configuration({AppConstants.localIpKey: '10.0.0.7', AppConstants.portKey: '9090', AppConstants.isConfiguredKey: true});
      expect(p.localIp, '10.0.0.7');
      expect(p.port, '9090');
      final vide = await configuration({AppConstants.localIpKey: '', AppConstants.isConfiguredKey: true});
      expect(vide.localIp, isEmpty, reason: 'une adresse vidée volontairement reste vide');
    });

    test('enregistrement : l\'adresse saisie est gardée telle quelle (vide comprise)', () async {
      final p = await configuration({});
      await p.updateSettings('', '', '', 30, '');
      expect(p.localIp, isEmpty);
      expect(p.port, '8080');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConstants.localIpKey), '');
      await p.updateSettings('192.168.1.60', '', '8081', 30, 'prestige');
      expect(prefs.getString(AppConstants.localIpKey), '192.168.1.60');
    });
  });

  group('2 · Cache court', () {
    test('lecture en cours partagée, durée de vie, relecture forcée', () async {
      var t = DateTime(2026, 11, 20, 10);
      final c = CacheCourt<String>(duree: const Duration(seconds: 60), horloge: () => t);
      var n = 0;
      final attente = Completer<String>();
      Future<String> lire() {
        n++;
        return attente.future;
      }

      final a = c.lire('k', lire);
      final b = c.lire('k', lire);
      expect(n, 1, reason: 'une seule requête pour deux lectures');
      attente.complete('v');
      expect(await a, 'v');
      expect(await b, 'v');
      expect(c.connue('k'), 'v');
      t = t.add(const Duration(seconds: 59));
      expect(await c.lire('k', () async => 'w'), 'v');
      t = t.add(const Duration(seconds: 2));
      expect(c.connue('k'), isNull, reason: 'périmée');
      expect(await c.lire('k', () async => 'w'), 'w');
      expect(await c.lire('k', () async => 'x', frais: true), 'x');
    });

    test('échec et lecture abandonnée (null) jamais gardés', () async {
      final c = CacheCourt<String?>(duree: const Duration(minutes: 2));
      await expectLater(c.lire('e', () async => throw StateError('panne')), throwsStateError);
      expect(await c.lire('e', () async => 'ok'), 'ok');
      expect(await c.lire('n', () async => null), isNull);
      expect(c.contient('n'), isFalse);
      expect(await c.lire('n', () async => 'ok'), 'ok');
    });

    test('taille bornée : les plus anciennes entrées partent', () async {
      final c = CacheCourt<int>(duree: const Duration(minutes: 2), maxEntrees: 3);
      for (var i = 0; i < 5; i++) {
        await c.lire('k$i', () async => i);
      }
      expect([for (var i = 0; i < 5; i++) c.contient('k$i')], [false, false, true, true, true]);
    });

    test('lignes de /vente/search (SearchDTO) : CIP, nom, emplacement, prix, stock ; lignes illisibles écartées', () {
      final l = RechercheProduit.lireVente({
        'total': 3,
        'data': [
          {'lgFAMILLEID': 'F1', 'intCIP': '9990001', 'strNAME': 'PARAFICTIF 500MG', 'strLIBELLEE': 'RAYON A', 'intPRICE': 1200, 'intNUMBERAVAILABLE': 8},
          {'intCIP': '', 'strNAME': 'SANS CIP'},
          {'intCIP': '9990002', 'strNAME': 'SIROP FICTIF', 'strLIBELLEE': '', 'intPRICE': '2500', 'intNUMBERAVAILABLE': null},
        ],
      });
      expect(l.map((p) => p.cip), ['9990001', '9990002']);
      expect(l.first.emplacement, 'RAYON A');
      expect(l.first.prixVente, 1200);
      expect(l.first.stockTotal, 8);
      expect(l.last.emplacement, isNull);
      expect(l.last.prixVente, 2500);
      expect(RechercheProduit.parametresVente(' para '), {'query': 'para', 'start': '0', 'limit': '30'});
      final r = ResultatRechercheProduit(List.filled(30, l.first), contient: true, source: SourceRecherche.vente);
      expect(r.limiteAtteinte, isTrue);
      expect(r.maximum, 30);
    });
  });

  group('3 · État de stock : longueur minimale', () {
    test('1 ou 2 caractères ne partent pas ; 3 et plus, CIP ou EAN complet : oui ; vide : filtres seuls', () {
      expect(EtatStock.rechercheTropCourte('a'), isTrue);
      expect(EtatStock.rechercheTropCourte(' do '), isTrue);
      expect(EtatStock.rechercheTropCourte('34'), isTrue);
      expect(EtatStock.rechercheTropCourte('dol'), isFalse);
      expect(EtatStock.rechercheTropCourte('3400936'), isFalse, reason: 'CIP 7');
      expect(EtatStock.rechercheTropCourte('3400930000001'), isFalse, reason: 'EAN 13');
      expect(EtatStock.rechercheTropCourte(''), isFalse, reason: 'recherche vide : seuls les filtres comptent');
      expect(EtatStock.antiRebond, const Duration(milliseconds: 300));
    });
  });

  group('5 · CA crédit : vue calculée une fois', () {
    List<CaCredit> ventes(int n) => [
          for (var i = 1; i <= n; i++)
            CaCredit.fromJson({
              'clientName': 'CLIENT FICTIF ${i % 7}',
              'ayantDroitName': 'AYANT DROIT FICTIF $i',
              'numFacturation': 'FAC-$i',
              'tiersPayantLibelle': 'ASSURANCE FICTIVE ${i % 3}',
              'montant': 1000 + i,
              'mvtDate': '20261101',
            }),
        ];

    test('mêmes ventes que la recherche d\'origine, puis filtre du tiers payant ; chiffres clés', () {
      final l = ventes(300);
      final v = VueCaCredit.calculer(l, 'fictif 3', 'ASSURANCE FICTIVE 1');
      final attendu = [for (final c in CaCreditDonnees.filtrer(l, 'fictif 3')) if (c.tiersPayantLibelle == 'ASSURANCE FICTIVE 1') c];
      expect(v.lignes, attendu);
      expect(v.total, CaCreditDonnees.total(attendu));
      expect(v.clients, {for (final c in attendu) c.clientName}.length);
      expect(v.tiersPayants, 1);
      expect(CaCreditDonnees.lire([
        {'clientName': 'A', 'montant': 5}
      ])!.single.montant, 5);
      expect(CaCreditDonnees.lire({'data': 'inattendu'}), isNull);
    });
  });
}
