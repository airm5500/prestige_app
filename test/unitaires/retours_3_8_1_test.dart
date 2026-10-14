// Unitaires des décisions du pharmacien appliquées en 3.8.1 (logique pure, sans écran ni serveur) :
//  - Suivi 20/80, « Nombre d'articles » (correction) : le serveur lit « topN » (FamilleArticleRessource.vingtQuatreVingt,
//    Integer ; absent ou ≤ 0 = tous) et ignore « limit » : les paramètres portent topN = nombre choisi, limit est
//    gardé ; l'application ne garde que les N premiers si le serveur en renvoie plus ;
//  - Rappels traitement, « Actualiser la liste » : réservé aux responsables (administrateur et pharmacien) — le seul
//    accès à l'écran est le menu « Rappels traitement », réservé.
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/models/suivi_20_80_model.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague3/rappels_vague3.dart';
import 'package:prestige_app/providers/home_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Suivi2080 article(String cip, int montant, int qte) => Suivi2080(cip: cip, libelle: cip, montant: montant, quantiteVendue: qte, stock: 0);

AppUser utilisateur(String type) => AppUser(userId: 'U', firstName: 'Test', lastName: 'Fictif', login: 'test', officineName: 'P', typeUser: type);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Suivi 20/80 : « topN » (lu par le serveur) en plus de « limit »', () {
    final d = DateTime(2026, 10, 1), f = DateTime(2026, 10, 14);

    test('topN = nombre choisi, limit gardé (même valeur), autres paramètres inchangés', () {
      expect(Suivi2080Donnees.parametres(d, f, 50), {
        'dtStart': '2026-10-01', 'dtEnd': '2026-10-14', 'limit': '50', 'topN': '50', 'codeFamile': '', 'codeRayon': '',
        'codeGrossiste': '', 'qtyOrCa': 'false', 'page': '1', 'start': '0',
      });
      expect(Suivi2080Donnees.parametres(d, f, 80), allOf(containsPair('topN', '80'), containsPair('limit', '80')));
      expect(Suivi2080Donnees.parametres(d, f, 9999)['topN'], '9999');
      expect(Suivi2080Donnees.parametres(d, f, 20, critere: CritereVingt.quantite),
          {...Suivi2080Donnees.parametres(d, f, 20), 'vingtType': 'QTY'});
    });

    test('jamais topN vide ni 0 (le serveur rendrait tous les articles) : champ vide ou 0 → 50', () {
      for (final t in ['', '0', '10000', null]) {
        expect(Suivi2080Donnees.parametres(d, f, Suivi2080Donnees.limite(t))['topN'], '50', reason: '« $t »');
      }
    });

    test('garder : les N premiers si le serveur en renvoie plus ; sinon la liste telle quelle', () {
      final l = [for (var i = 1; i <= 120; i++) article('A$i', 1000 - i, i)];
      expect([for (final a in Suivi2080Donnees.garder(l, 50)) a.cip], [for (var i = 1; i <= 50; i++) 'A$i'], reason: 'ordre gardé');
      expect(Suivi2080Donnees.garder(l, 120), same(l));
      expect(Suivi2080Donnees.garder(l, 9999), same(l), reason: '« tous » : comportement d\'avant');
      expect(Suivi2080Donnees.garder(const [], 50), isEmpty);
    });

    test('par quantité : les N premiers APRÈS le tri par quantité (comme le serveur, topN après classement)', () {
      final l = [article('A', 500, 1), article('B', 400, 9), article('C', 300, 5), article('D', 200, 7)];
      final deux = Suivi2080Donnees.garder(Suivi2080Donnees.classer(l, CritereVingt.quantite), 2);
      expect([for (final a in deux) a.cip], ['B', 'D']);
    });
  });

  group('Rappels traitement : « Actualiser la liste » réservé aux responsables', () {
    tearDown(() => ProfilAcces.utilisateur.value = null);

    test('le seul menu qui ouvre l\'écran des rappels est réservé (administrateur et pharmacien)', () {
      final rappels = [for (final m in menusModules) if (m.ecran() is RappelsScreen) m];
      expect(rappels, hasLength(1), reason: 'aucun autre accès à l\'écran (donc au bouton)');
      expect(rappels.single.responsables, isTrue);
    });

    test('autre profil : menu absent de l\'accueil, de la recherche et de « Personnaliser l\'accueil »', () {
      final reglages = HomeSettingsProvider();
      for (final type in ['mainmenumanager', 'vendeur', '']) {
        ProfilAcces.utilisateur.value = utilisateur(type);
        expect([for (final m in menusAutorises()) m.titre], isNot(contains('Rappels traitement')), reason: type);
        expect([for (final m in menusVisibles(reglages)) m.titre], isNot(contains('Rappels traitement')), reason: type);
      }
      ProfilAcces.utilisateur.value = null;
      expect([for (final m in menusAutorises()) m.titre], isNot(contains('Rappels traitement')), reason: 'personne de connecté');
    });

    test('administrateur et pharmacien (profil « dashboard ») : menu proposé', () {
      ProfilAcces.utilisateur.value = utilisateur('dashboard');
      expect([for (final m in menusAutorises()) m.titre], contains('Rappels traitement'));
      expect([for (final m in menusVisibles(HomeSettingsProvider())) m.titre], contains('Rappels traitement'));
    });
  });
}
