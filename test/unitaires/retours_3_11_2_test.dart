// Retour du pharmacien (3.11.2) : Détail CA, « Jour par jour » — évolution du Total par rapport au jour précédent
// de la liste (au dixième ; rien pour le premier jour ni après un jour à 0).
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/ca_comptant_model.dart';
import 'package:prestige_app/nouvelle_interface/modules/detail_ca_nouveau.dart';

CaComptant jour(int j, double especes) => CaComptant.fromJson({'mvtDate': '202610${j.toString().padLeft(2, '0')}', 'totEsp': especes});

void main() {
  test('évolution du Total : vs le jour précédent de la liste ; premier jour et lendemain d\'un jour à 0 : rien', () {
    final l = [jour(12, 684500), jour(13, 808000), jour(14, 660150), jour(15, 0), jour(16, 100000), jour(17, 100000)];
    expect([for (var i = 0; i < l.length; i++) evolutionTotalJour(l, i)], [null, 18.0, -18.3, -100.0, null, 0.0]);
    expect(evolutionTotalJour(l, 99), isNull);
  });
}
