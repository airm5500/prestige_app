// Alertes de l'accueil A comptées à la demande (lib/nouvelle_interface/alertes_accueil.dart) : logique pure.
//  - comptage : lots en péremption lus dans l'appel unique des alertes du tableau de bord (vague 1, même nombre que
//    l'écran Alertes) ; « Total Bons » que montre l'écran Etat Contrôle Achat pour la même réponse du serveur ;
//  - formatage du moment : « à 14:32 », « il y a X min », « il y a X h », « le 12/10 à 14:32 » ;
//  - unités (« 1 lot », « 12 lots ») et causes d'échec distinctes.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/alertes_accueil.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';

void main() {
  group('Péremption : lots de l\'appel unique des alertes (GET /tableau-bord/alertes)', () {
    test('nombre = « peremptions.lots » (lots qui périment d\'ici 6 mois)', () {
      expect(AlertesTableauDeBord(DonneesVague1.alertes()).peremptionsLots, DonneesFictives.lotsPerimes);
      expect(AlertesTableauDeBord({'peremptions': {'produits': 40, 'lots': 57, 'mois': 6}}).peremptionsLots, 57);
    });

    test('bloc absent, réponse vide ou illisible : 0 (jamais une erreur)', () {
      expect(AlertesTableauDeBord({}).peremptionsLots, 0);
      expect(AlertesTableauDeBord(DonneesFictives.listeVide()).peremptionsLots, 0);
      expect(AlertesTableauDeBord({'peremptions': 'beaucoup'}).peremptionsLots, 0);
    });

    test('nombre en texte ou décimal accepté (« 1 245 », 12.0)', () {
      expect(AlertesTableauDeBord({'peremptions': {'lots': '1 245'}}).peremptionsLots, 1245);
      expect(AlertesTableauDeBord({'peremptions': {'lots': 12.0}}).peremptionsLots, 12);
    });

    test('même libellé que l\'écran Alertes', () {
      expect(TypeAlerte.peremptions.titre, 'Produits proches de la péremption');
      expect(AlertesTableauDeBord(DonneesVague1.alertes()).alerte(TypeAlerte.peremptions).detail, startsWith('Lots qui périment d\'ici 6 mois'));
    });
  });

  group('Comptage Etat Contrôle Achat', () {
    test('« Total Bons » de metaData (ligne affichée par l\'écran)', () {
      expect(compterBonsControle(DonneesFictives.etatControleAchat()), DonneesFictives.bonsControles);
    });

    test('sans metaData : somme de la colonne « Nb Bons »', () {
      final j = DonneesFictives.etatControleAchat()..remove('metaData');
      expect(compterBonsControle(j), 7);
    });

    test('aucune ligne (l\'écran affiche « Aucune donnée ») : 0, même si metaData est présent', () {
      expect(compterBonsControle({'data': <Object>[], 'metaData': {'totalNbreBon': 0}}), 0);
      expect(compterBonsControle(DonneesFictives.listeVide()), 0);
    });

    test('réponse vide ou inattendue : 0', () {
      expect(compterBonsControle(null), 0);
      expect(compterBonsControle(const <Object>[]), 0);
    });

    test('données illisibles : échec « réponse » (jamais un faux 0)', () {
      expect(
          () => compterBonsControle({
                'data': [
                  {'nbreBon': 'beaucoup'}
                ],
                'metaData': {'totalNbreBon': 'beaucoup'},
              }),
          throwsA(isA<ApiLoadException>().having((e) => e.nature, 'nature', NatureErreur.reponse)));
    });
  });

  group('Moment du comptage', () {
    final le = DateTime(2026, 10, 14, 14, 32, 10);

    test('moins d\'une minute : « à 14:32 »', () {
      expect(momentComptage(le, le), 'à 14:32');
      expect(momentComptage(le, le.add(const Duration(seconds: 59))), 'à 14:32');
    });

    test('heure avec zéros : « à 08:05 »', () => expect(momentComptage(DateTime(2026, 10, 14, 8, 5), DateTime(2026, 10, 14, 8, 5, 30)), 'à 08:05'));

    test('de 1 à 59 minutes : « il y a X min »', () {
      expect(momentComptage(le, le.add(const Duration(minutes: 1))), 'il y a 1 min');
      expect(momentComptage(le, le.add(const Duration(minutes: 12, seconds: 40))), 'il y a 12 min');
      expect(momentComptage(le, le.add(const Duration(minutes: 59, seconds: 59))), 'il y a 59 min');
    });

    test('le même jour, au-delà d\'une heure : « il y a X h (à 14:32) »', () {
      expect(momentComptage(le, le.add(const Duration(hours: 1))), 'il y a 1 h (à 14:32)');
      expect(momentComptage(le, le.add(const Duration(hours: 3, minutes: 50))), 'il y a 3 h (à 14:32)');
    });

    test('un autre jour : « le 14/10 à 14:32 »', () {
      expect(momentComptage(le, DateTime(2026, 10, 15, 0, 10)), 'le 14/10 à 14:32');
      expect(momentComptage(DateTime(2026, 1, 2, 9, 0), DateTime(2026, 10, 14)), 'le 02/01 à 09:00');
    });

    test('horloge du téléphone reculée (moment dans le futur) : heure seule', () {
      expect(momentComptage(le, le.subtract(const Duration(minutes: 5))), 'à 14:32');
    });
  });

  group('Unités et échecs', () {
    test('« 0 lot », « 1 lot », « 12 lots », « 1 245 bons »', () {
      expect(AlerteAccueil.peremption.nombre(0), '0 lot');
      expect(AlerteAccueil.peremption.nombre(1), '1 lot');
      expect(AlerteAccueil.peremption.nombre(12), '12 lots');
      expect(AlerteAccueil.controleAchat.nombre(1245), '1 245 bons');
    });

    test('libellés accessibles distincts des deux boutons ⟳', () {
      expect(AlerteAccueil.peremption.libelleBouton, contains('péremption'));
      expect(AlerteAccueil.controleAchat.libelleBouton, contains('bons de livraison'));
    });

    test('causes distinctes : injoignable, délai, session, serveur (avec code), droit, autre', () {
      EchecComptage de(Object e) => EchecComptage.depuis(e);
      expect(de(const ApiLoadException(ApiLoadException.messageReseau)).cause, CauseEchec.injoignable);
      expect(de(const ApiLoadException(ApiLoadException.messageDelai, nature: NatureErreur.delai)).cause, CauseEchec.delai);
      expect(de(TimeoutException('borne')).cause, CauseEchec.delai);
      expect(de(const ApiLoadException(ApiLoadException.messageSession, nature: NatureErreur.session, code: 401)).cause, CauseEchec.session);
      final serveur = de(const ApiLoadException('x', nature: NatureErreur.serveur, code: 503));
      expect(serveur.cause, CauseEchec.serveur);
      expect(serveur.message, 'Erreur du serveur (code 503).');
      expect(de(const ApiLoadException(ApiLoadException.messageDroit, nature: NatureErreur.droit, code: 403)).cause, CauseEchec.droit);
      expect(de(const ApiLoadException('x', nature: NatureErreur.reponse)).cause, CauseEchec.autre);
      expect(de(StateError('inattendu')).cause, CauseEchec.autre);
      // Messages tous différents (le pharmacien sait quoi faire).
      final messages = {
        for (final e in [
          const ApiLoadException(ApiLoadException.messageReseau),
          TimeoutException('borne'),
          const ApiLoadException('', nature: NatureErreur.session),
          const ApiLoadException('', nature: NatureErreur.serveur, code: 500),
        ])
          de(e).message
      };
      expect(messages, hasLength(4));
    });

    test('mémoire : aller-retour JSON ; entrée illisible ignorée', () {
      final c = ComptageAlerte(42, DateTime(2026, 10, 14, 14, 32));
      final r = ComptageAlerte.depuisJson(c.versJson())!;
      expect(r.nombre, 42);
      expect(r.le, c.le);
      expect(ComptageAlerte.depuisJson({'n': 'x'}), isNull);
      expect(ComptageAlerte.depuisJson(null), isNull);
    });
  });
}
