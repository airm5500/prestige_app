// Session renouvelée à la connexion (serveur Prestige, audit du 12/10) : seul le JSESSIONID de la réponse de
// connexion doit être gardé, même si l'en-tête Set-Cookie contient plusieurs cookies.
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/services/api_service.dart';

void main() {
  test('JSESSIONID extrait même s\'il n\'est pas le premier cookie', () {
    expect(ApiService.extraireCookieSession('autre=1; Path=/, JSESSIONID=nouveau; Path=/prestige; HttpOnly'),
        'JSESSIONID=nouveau');
  });
  test('cas simple inchangé', () {
    expect(ApiService.extraireCookieSession('JSESSIONID=abc; Path=/prestige; HttpOnly'), 'JSESSIONID=abc');
    expect(ApiService.extraireCookieSession('JSESSIONID=abc'), 'JSESSIONID=abc');
  });
  test('sans JSESSIONID : premier cookie (comportement d\'origine)', () {
    expect(ApiService.extraireCookieSession('SESSION=x; Path=/'), 'SESSION=x');
  });
}
