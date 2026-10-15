// Unitaires (3.10.2) : quand l'application dit « Serveur indisponible, veuillez réessayer. » à la connexion.
//  - 404 (refus), 502 / 503 / 504 (serveur) et connexion refusée = indisponible ;
//  - 401, 403, 400, 500, délai, Wi-Fi coupé, certificat refusé, réponse illisible = autre chose ;
//  - connexion refusée reconnue par le code système (111 / 61 / 10061) ou le message, directement ou enveloppée par
//    le client HTTP ; « Network is unreachable », « Failed host lookup » ne le sont pas.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:prestige_app/services/api_service.dart';

void main() {
  test('message exact demandé par le pharmacien', () {
    expect(ApiLoadException.messageServeurIndisponible, 'Serveur indisponible, veuillez réessayer.');
  });

  test('indisponible : 404, 502, 503, 504, connexion refusée', () {
    expect(const ApiLoadException('x', nature: NatureErreur.refus, code: 404).serveurIndisponible, isTrue);
    for (final c in [502, 503, 504]) {
      expect(ApiLoadException('x', nature: NatureErreur.serveur, code: c).serveurIndisponible, isTrue, reason: '$c');
    }
    expect(const ApiLoadException(ApiLoadException.messageReseau, connexionRefusee: true).serveurIndisponible, isTrue);
  });

  test('pas indisponible : 400, 401, 403, 409, 500, délai, Wi-Fi, certificat, réponse illisible', () {
    for (final e in [
      const ApiLoadException('x', nature: NatureErreur.refus, code: 400),
      const ApiLoadException('x', nature: NatureErreur.refus, code: 409),
      const ApiLoadException('x', nature: NatureErreur.session, code: 401),
      const ApiLoadException('x', nature: NatureErreur.droit, code: 403),
      const ApiLoadException('x', nature: NatureErreur.serveur, code: 500),
      const ApiLoadException(ApiLoadException.messageDelai, nature: NatureErreur.delai),
      const ApiLoadException(ApiLoadException.messageReseau),
      const ApiLoadException(ApiLoadException.messageCertificat),
      const ApiLoadException(ApiLoadException.messageReponse, nature: NatureErreur.reponse),
    ]) {
      expect(e.serveurIndisponible, isFalse, reason: '${e.nature} ${e.code} ${e.message}');
    }
  });

  test('connexion refusée : codes système et messages ; Wi-Fi coupé et DNS : non', () {
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

  test('« pour » (message précisé d\'une liste) garde l\'indication', () {
    const e = ApiLoadException(ApiLoadException.messageReseau, connexionRefusee: true);
    expect(e.pour('rayons').connexionRefusee, isTrue);
  });
}
