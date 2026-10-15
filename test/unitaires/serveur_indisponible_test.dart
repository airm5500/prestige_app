// Unitaires (3.10.2, revu en 3.10.3) : les DEUX cas du pharmacien.
//  1. « Serveur injoignable. Vérifiez le Wi-Fi et que le PC serveur est allumé. » : réseau absent, hôte inaccessible,
//     connexion refusée (PC éteint, Payara arrêté) — délai dépassé à la connexion ;
//  2. « Serveur indisponible : Prestige est en cours de démarrage ou de redéploiement… » : le serveur répond sans
//     Prestige (404 de Payara confirmé, 502 / 503 / 504) — [ApiLoadException.nonDeploye] ;
//  - 400, 401, 403, 409, 500, réponse illisible, certificat : ni l'un ni l'autre ; un 404 « brut » (métier) non plus.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:prestige_app/services/api_service.dart';

void main() {
  test('messages exacts demandés par le pharmacien', () {
    expect(ApiLoadException.messageReseau, 'Serveur injoignable. Vérifiez le Wi-Fi et que le PC serveur est allumé.');
    expect(ApiLoadException.messageServeurIndisponible,
        'Serveur indisponible : Prestige est en cours de démarrage ou de redéploiement. Veuillez réessayer dans un instant.');
  });

  test('cas 2 : Prestige pas déployé (404 confirmé, 502, 503, 504)', () {
    for (final c in [404, 502, 503, 504]) {
      final e = ApiLoadException.nonDeploye(c);
      expect(e.serveurIndisponible, isTrue, reason: '$c');
      expect(e.nature, NatureErreur.serveur);
      expect(e.message, ApiLoadException.messageServeurIndisponible);
      expect(e.code, c, reason: 'code gardé pour le diagnostic');
    }
    expect(const ApiLoadException.nonDeploye(503).pour('rayons').message, ApiLoadException.messageServeurIndisponible);
  });

  test('ni cas 2 : connexion refusée (cas 1), 404 brut (métier), 400, 401, 403, 409, 500, délai, illisible, certificat', () {
    for (final e in [
      const ApiLoadException(ApiLoadException.messageReseau, connexionRefusee: true),
      const ApiLoadException(ApiLoadException.messageReseau),
      const ApiLoadException('x', nature: NatureErreur.refus, code: 404),
      const ApiLoadException('x', nature: NatureErreur.refus, code: 400),
      const ApiLoadException('x', nature: NatureErreur.refus, code: 409),
      const ApiLoadException('x', nature: NatureErreur.session, code: 401),
      const ApiLoadException('x', nature: NatureErreur.droit, code: 403),
      const ApiLoadException('x', nature: NatureErreur.serveur, code: 500),
      const ApiLoadException(ApiLoadException.messageDelai, nature: NatureErreur.delai),
      const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse),
      const ApiLoadException(ApiLoadException.messageCertificat),
    ]) {
      expect(e.serveurIndisponible, isFalse, reason: '${e.nature} ${e.code} ${e.message}');
    }
  });

  test('connexion refusée reconnue (codes système et messages) ; Wi-Fi coupé et DNS : non', () {
    for (final c in [111, 61, 10061]) {
      expect(ApiService.connexionRefusee(SocketException('x', osError: OSError('', c))), isTrue, reason: '$c');
    }
    expect(ApiService.connexionRefusee(const SocketException('Connection refused')), isTrue);
    expect(ApiService.connexionRefusee(http.ClientException('Connection refused', Uri.parse('http://127.0.0.1:1/'))), isTrue);
    expect(ApiService.connexionRefusee(const SocketException('Network is unreachable', osError: OSError('Network is unreachable', 101))), isFalse);
    expect(ApiService.connexionRefusee(const SocketException('Failed host lookup: \'serveur.invalid\'')), isFalse);
    expect(ApiService.connexionRefusee(http.ClientException('Connection closed before full header was received')), isFalse);
    expect(ApiService.connexionRefusee(Exception('Connection refused')), isFalse, reason: 'autre type : jamais');
  });

  test('« pour » (liste précisée) : cas 1 avec le nouveau texte, indication gardée', () {
    const e = ApiLoadException(ApiLoadException.messageReseau, connexionRefusee: true);
    expect(e.pour('rayons').message, 'Serveur injoignable (rayons non chargés). Vérifiez le Wi-Fi et que le PC serveur est allumé.');
    expect(e.pour('rayons').connexionRefusee, isTrue);
  });

  test('routes toujours présentes : connexion, officine, licence', () {
    expect(ApiService.routesToujoursPresentes, containsAll(['/user/auth', '/officine', '/licence/find']));
  });
}
