// Intégration des retours de la 3.11.1 contre le faux serveur Prestige joint en HTTP RÉEL :
//  - chiffres du tableau de bord pour un jour choisi : GET /tableau-bord/tuiles?date=<jour> (une requête, l'évolution
//    par rapport à la veille est dans la réponse) ; serveur sans cette route : aujourd'hui → /recap/dashboard/daily
//    (inchangé), autre jour → 404 gardé (« Indisponible sur ce serveur »), AUCUN appel à daily ;
//  - fréquentation : CA par heure (caH) lu avec les ventes, la veille dans la MÊME réponse (aucune requête de plus) ;
//  - CA par emplacement jour par jour : évolution du serveur, ou calculée quand il ne l'envoie pas.
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague4/tableau_bord_vague4.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague2.dart';
import '../support/faux_serveur_prestige.dart';
import 'vague4_api_test.dart' show connecte, essayer, serveur;

final aujourdhui = DateTime(2026, 10, 14, 11, 30);

void main() {
  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerTelephone(serveur, nouvelle: true);
    listesCommunesVague1(serveur);
    await ApiService().clearSessionCookie();
  });

  tearDown(() async {
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..reponseSansSession = ((_) => ReponseFausse.sessionExpiree())
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
  });

  testWidgets('chiffres d\'hier : UNE requête tuiles?date=hier, évolution vs la veille lue dans la réponse', (tester) async {
    final app = await connecte(tester);
    final (c, e) = await essayer(tester, () => ApiTableauBord.chiffres(app.ctx, aujourdhui, jour: DateTime(2026, 10, 13)));
    expect(e, isNull);
    expect(serveur.recues(ApiTableauBord.routeTuiles).single.parametres['date'], '2026-10-13');
    expect(c!.evolutionVeille, 13.2);
    expect(serveur.recues(ApiTableauBord.routeDaily), isEmpty);
  });

  testWidgets('serveur sans tuiles : aujourd\'hui → ancienne route ; hier → 404 gardé, aucune autre requête', (tester) async {
    final app = await connecte(tester);
    serveur.quand(ApiTableauBord.routeTuiles, ReponseFausse.introuvable());
    final (c, _) = await essayer(tester, () => ApiTableauBord.chiffres(app.ctx, aujourdhui));
    expect(c!.ancienneRoute, isTrue);
    serveur.oublierRequetes();
    final (c2, e2) = await essayer(tester, () => ApiTableauBord.chiffres(app.ctx, aujourdhui, jour: DateTime(2026, 10, 13)));
    expect(c2, isNull);
    expect(routeAbsente(e2!), isTrue, reason: 'la carte affiche « Indisponible sur ce serveur »');
    expect(serveur.recues(ApiTableauBord.routeDaily), isEmpty, reason: 'l\'ancienne route ne connaît qu\'aujourd\'hui');
  });

  testWidgets('fréquentation : ventes ET CA par heure, la veille dans la même réponse (une seule requête)', (tester) async {
    final app = await connecte(tester);
    final (f, _) = await essayer(tester, () => ApiTableauBord.frequentation(app.ctx, DateTime(2026, 10, 13)));
    expect(serveur.recues(ApiTableauBord.routeFrequentationPilotage), hasLength(1));
    expect(f!.ca, hasLength(24));
    expect(f.ca[8], f.ventes[8] * 9500);
    expect(f.reference, isNotNull);
    final t = f.tranches();
    expect(t.first.partCa, isNotNull);
    expect(t.where((x) => x.ecart! > 0), isNotEmpty);
    expect(t.where((x) => x.ecart! < 0), isNotEmpty);
    // Repli semaine : CA par heure lu aussi.
    serveur.quand(ApiTableauBord.routeFrequentationPilotage, ReponseFausse.introuvable());
    final (s, _) = await essayer(tester, () => ApiTableauBord.frequentation(app.ctx, DateTime(2026, 10, 13)));
    expect(s!.semaine, isTrue);
    expect(s.ca, hasLength(24));
  });

  testWidgets('CA par emplacement jour par jour : évolution du serveur ; serveur qui ne l\'envoie pas → calculée', (tester) async {
    final app = await connecte(tester);
    final f = FiltresCa(type: TypePeriodeCa.libre, debut: DateTime(2026, 10, 8), fin: DateTime(2026, 10, 14));
    final (d, _) = await essayer(tester, () => ApiCaZone.comparatif(app.ctx, f, maintenant: aujourdhui));
    expect(d!.granularite, 'JOUR');
    expect([for (final t in d.tranches) d.evolutionsTranches[t.cle]], [null, 20.0, -25.0, -100.0, null, -15.4, 0.0]);
    // Même réponse sans aucune évolution (serveur plus ancien) : mêmes valeurs, calculées par l'application.
    serveur.route(ApiCaZone.route, (r) {
      final j = DonneesVague2.caZone(r.parametres);
      j.remove('evolutionsTranches');
      for (final l in j['data']! as List) {
        (l as Map).removeWhere((k, _) => '$k'.startsWith('e_'));
      }
      return ReponseFausse.json(j);
    }, methode: 'GET');
    final (d2, _) = await essayer(tester, () => ApiCaZone.comparatif(app.ctx, f, maintenant: aujourdhui));
    expect([for (final t in d2!.tranches) d2.evolutionsTranches[t.cle]], [for (final t in d.tranches) d.evolutionsTranches[t.cle]]);
    expect([for (final t in d2.tranches) d2.lignes.first.de(t.cle).evolution], [for (final t in d.tranches) d.lignes.first.de(t.cle).evolution]);
  });
}
