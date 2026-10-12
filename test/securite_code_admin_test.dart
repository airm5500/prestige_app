// Étape 1c : la configuration du serveur ouverte SANS être connecté (écran de connexion, écran de licence)
// est protégée par un code administrateur haché (PBKDF2, stockage sécurisé, anti force brute) ; le code
// par défaut 1234 impose son changement. Connecté, le pharmacien a tous les droits : pas de code.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/screens/home_screen.dart';
import 'package:prestige_app/screens/licence_registration_screen.dart';
import 'package:prestige_app/screens/login_screen.dart';
import 'package:prestige_app/services/pin_securise.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/contexte_api.dart';

const _sur = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'local_ip': '10.0.0.5', 'is_app_configured': true});
    FlutterSecureStorage.setMockInitialValues({});
    CodeAdmin.instance = CodeAdmin(iterations: 1000);
  });

  group('Empreinte', () {
    test('PBKDF2-HMAC-SHA256 : vecteur de référence (RFC 7914)', () {
      expect(hex(Pbkdf2Sha256.deriver(utf8.encode('password'), utf8.encode('salt'), 1, 32)),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    });

    test('code jamais en clair, sel différent à chaque fois', () {
      final a = EmpreintePin.creer('4826', iterations: 1000);
      final b = EmpreintePin.creer('4826', iterations: 1000);
      expect(a, isNot(contains('4826')));
      expect(a, isNot(b));
      expect(EmpreintePin.verifier('4826', a), isTrue);
      expect(EmpreintePin.verifier('4827', a), isFalse);
    });
  });

  group('Code administrateur', () {
    test('code par défaut : changement obligatoire ; nouveau code haché dans le stockage sûr', () async {
      final c = CodeAdmin.instance;
      expect(await c.verifier('1234'), VerificationPin.changementObligatoire);
      expect(await c.definir('1234'), isNotNull);
      expect(await c.definir('1111'), isNotNull);
      expect(await c.definir('1234567'), isNotNull);
      expect(await c.definir('4826'), isNull);
      final garde = await _sur.read(key: CodeAdmin.cleSure);
      expect(EmpreintePin.estEmpreinte(garde), isTrue);
      expect(garde, isNot(contains('4826')));
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys()) {
        expect('${prefs.get(k)}', isNot(contains('4826')));
      }
      expect(await c.verifier('4826'), VerificationPin.accepte);
      expect(await c.verifier('1234'), VerificationPin.refuse);
    });

    test('anti force brute : attente après 5 erreurs', () async {
      var maintenant = DateTime(2026, 10, 12, 9);
      final c = CodeAdmin(iterations: 1000, horloge: () => maintenant);
      await c.definir('4826');
      for (var i = 0; i < 4; i++) {
        expect(await c.verifier('0000'), VerificationPin.refuse);
      }
      expect(await c.verifier('0000'), VerificationPin.bloque);
      expect(await c.verifier('4826'), VerificationPin.bloque, reason: 'même le bon code attend');
      maintenant = maintenant.add(const Duration(seconds: 31));
      expect(await c.verifier('4826'), VerificationPin.accepte);
    });
  });

  group('Écrans', () {
    Future<void> saisir(WidgetTester tester, Key cle, String texte) async {
      await tester.enterText(find.byKey(cle), texte);
      await tester.pump();
    }

    testWidgets('connexion → Configuration : code exigé ; mauvais code refusé ; 1234 impose un nouveau code', (tester) async {
      await monterAvecProviders(tester, ecran: const LoginScreen());
      await tester.tap(find.byTooltip('Configuration IP'));
      await tester.pumpAndSettle();
      expect(find.text('Code Administrateur requis :'), findsOneWidget);

      await saisir(tester, const Key('pin_admin_saisie'), '9999');
      await tester.runAsync(() async {
        await tester.tap(find.text('Valider'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.text('Configurer les adresses IP du serveur'), findsNothing);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Configuration IP'));
      await tester.pumpAndSettle();
      await saisir(tester, const Key('pin_admin_saisie'), '1234');
      await tester.runAsync(() async {
        await tester.tap(find.text('Valider'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.text('Changement du code obligatoire'), findsOneWidget);
      await saisir(tester, const Key('pin_admin_nouveau'), '4826');
      await saisir(tester, const Key('pin_admin_confirmation'), '4826');
      await tester.runAsync(() async {
        await tester.tap(find.text('Enregistrer'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();
      expect(find.text('Configurer les adresses IP du serveur'), findsOneWidget);
    });

    testWidgets('licence → Configuration : code exigé', (tester) async {
      await monterAvecProviders(tester, ecran: const LicenceRegistrationScreen());
      await tester.tap(find.byTooltip('Configuration Serveur'));
      await tester.pumpAndSettle();
      expect(find.text('Code Administrateur requis :'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Configurer les adresses IP du serveur'), findsNothing);
    });

    testWidgets('connecté (accueil) → Configuration : pas de code (tous les droits)', (tester) async {
      await monterAvecProviders(tester, ecran: const HomeScreen());
      await tester.tap(find.byTooltip('Configuration IP'));
      await tester.pumpAndSettle();
      expect(find.text('Code Administrateur requis :'), findsNothing);
      expect(find.text('Configurer les adresses IP du serveur'), findsOneWidget);
      expect(find.byKey(const Key('changer_code_admin')), findsOneWidget);
    });
  });
}
