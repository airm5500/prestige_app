// 3.18.0 — mode démonstration (lib/demo/) : dates relatives à aujourd'hui mais déterministes, écritures refusées,
// catalogue et jeux de données FICTIFS (aucune marque réelle, aucune clé), client sans réseau ni journal.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/demo/mode_demo.dart';
import 'package:prestige_app/demo/serveur_demo.dart';
import 'package:prestige_app/utils/constants.dart';

void main() {
  group('dates de la démonstration', () {
    test('décalage des trois formats, valeurs non datées intactes', () {
      expect(ServeurDemo.decalerTexte('2026-10-14', 41), '2026-11-24');
      expect(ServeurDemo.decalerTexte('le 13/10/2026 08:05', 41), 'le 23/11/2026 08:05');
      expect(ServeurDemo.decalerTexte('20261012', 41), '20261122');
      expect(ServeurDemo.decalerTexte('2026-10-15T09:30:00', 41), '2026-11-25T09:30:00');
      expect(ServeurDemo.decalerTexte('9992001', 41), '9992001', reason: 'CIP');
      expect(ServeurDemo.decalerTexte('12500000', 41), '12500000', reason: 'montant de 8 chiffres');
      expect(ServeurDemo.decalerTexte('PARACÉTAMOL FICTIF 500MG', 41), 'PARACÉTAMOL FICTIF 500MG');
      expect(ServeurDemo.decalerTexte(ServeurDemo.decalerTexte('2026-12-31', 41), -41), '2026-12-31');
      expect(ServeurDemo.decalerJson({'a': ['2026-10-14', 3, null]}, -1), {'a': ['2026-10-13', 3, null]});
    });

    test('« aujourd\'hui » de la démonstration = jour de l\'horloge ; même horloge, mêmes réponses', () async {
      Future<String> lire(DateTime t) async {
        final s = ServeurDemo(horloge: () => t);
        final r = await s.client().get(Uri.parse('http://${ModeDemo.adresse}:8080/prestige/api/v1/ca-all?dtStart=${t.toIso8601String().substring(0, 10)}'));
        return r.body;
      }

      final t = DateTime(2026, 11, 24, 10);
      final corps = await lire(t);
      expect(corps, await lire(t));
      final jours = [for (final l in jsonDecode(corps) as List) l['mvtDate']];
      expect(jours, containsAll(['20261124', '20261123', '20261122']), reason: 'aujourd\'hui, hier, avant-hier');
      expect(await lire(DateTime(2027, 3, 2)), contains('20270302'));
    });
  });

  group('écritures', () {
    tearDown(() => ModeDemo.actif.value = false);

    test('hors démonstration : rien n\'est bloqué', () {
      expect(ModeDemo.bloquee('POST', '/suggestion/item/update-qte-cmde'), isFalse);
    });

    test('en démonstration : POST / PUT / DELETE / exports / GET d\'action refusés, lectures permises', () {
      ModeDemo.actif.value = true;
      for (final (m, e) in [
        ('POST', AppConstants.suggestionUpdateQteEndpoint),
        ('POST', '/rh/mobile/terminaux/T1/retirer'),
        ('POST', '/rappels-habitude/actualiser'),
        ('PUT', '/reception/peremptions-courtes/1/statut'),
        ('DELETE', '/suggestion/item/1'),
        ('EXPORT', '/rh/tableau/pdf'),
        ('GET', '${AppConstants.venteAnnulationEndpoint}/V1'),
        ('GET', '${AppConstants.suggestionSetPendingEndpoint}/S1'),
        ('GET', '/surstock/create-inventaire'),
      ]) {
        expect(ModeDemo.bloquee(m, e), isTrue, reason: '$m $e');
      }
      for (final (m, e) in [
        ('GET', '/recap/dashboard'),
        ('GET', '/info'),
        ('POST', AppConstants.authEndpoint),
        ('POST', AppConstants.logoutEndpoint),
        ('POST', '/caisse/fetch-tickez'),
      ]) {
        expect(ModeDemo.bloquee(m, e), isFalse, reason: '$m $e');
      }
    });
  });

  group('données fictives', () {
    test('« para » et « doli » : produits fictifs du catalogue', () async {
      final s = ServeurDemo(horloge: () => DateTime(2026, 11, 24));
      Future<List<String>> chercher(String q) async {
        final r = await s.client().get(Uri.parse('http://${ModeDemo.adresse}/prestige/api/v1/espace-produit/recherche?q=$q'));
        return [for (final l in (jsonDecode(r.body) as Map)['data'] as List) '${l['designation']}'];
      }

      final para = await chercher('para');
      expect(para, contains('PARACÉTAMOL FICTIF 500MG CPR B/16'));
      expect(para.every((l) => l.contains('FICTI')), isTrue);
      final doli = await chercher('doli');
      expect(doli, hasLength(3));
      expect(doli.every((l) => l.contains('FICTIF')), isTrue);
      expect(s.requetes, isEmpty, reason: 'aucune recherche gardée');
    });

    test('aucune marque réelle ni secret dans les données de démonstration', () {
      const marques = ['DOLIPRANE', 'EFFERALGAN', 'DAFALGAN', 'ADVIL', 'NUROFEN', 'CLAMOXYL', 'AUGMENTIN', 'SPASFON', 'SMECTA',
        'VOLTAREN', 'PANADOL', 'FERVEX', 'MAALOX', 'GAVISCON', 'COARTEM', 'NIVAQUINE'];
      final fichiers = Directory('lib/demo').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      expect(fichiers, isNotEmpty);
      for (final f in fichiers) {
        final t = f.readAsStringSync().toUpperCase();
        for (final m in marques) {
          expect(t.contains(m), isFalse, reason: '$m dans ${f.path}');
        }
        expect(RegExp(r'''(api[_-]?key|secret|token|password)['"]?\s*[:=]\s*['"][a-z0-9_-]{12,}''', caseSensitive: false).hasMatch(t), isFalse, reason: f.path);
        expect(t.contains('192.168.'), isFalse, reason: 'adresse réelle dans ${f.path}');
      }
    });
  });
}
