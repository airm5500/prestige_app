// Unitaires des décisions du pharmacien et de la réponse du serveur appliquées en 3.10.0 (logique pure, sans écran
// ni serveur) :
//  1. P4 « icônes illustrées » : une icône pour CHAQUE menu et chaque onglet, fichiers embarqués présents (PNG
//     144 × 144, poids total borné), licence MIT de Microsoft embarquée ; défaut toujours « Actuel » ;
//  2. « Menus de l'accueil » en trois dispositions (0 tout sur une page, 1 une rubrique par page, 2 six tuiles par
//     page) : valeurs, lecture, paquets de 6 dans l'ordre des familles, titres ;
//  3. « Menus de l'accueil » réservé à l'administrateur ou au pharmacien (profil « dashboard » ou rôle) ;
//  4. Pointage BL par grossiste ou par groupe : jamais « ALL » (= tous les grossistes) envoyé, montant par grossiste
//     d'un groupe (serveur, calcul sur les pièces, ou rien) ;
//  5. réponse du serveur : rôle à la connexion (serveur récent), `enCoursAJour` des Prévisions, `detailMobile` du CA
//     Global (même règle que le Détail CA).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/models/ca_global_model.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/icones_illustrees.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/donnees_fictives.dart';

/// Largeur et hauteur d'un PNG (en-tête IHDR).
(int, int) taillePng(Uint8List o) {
  expect(o.sublist(1, 4), 'PNG'.codeUnits, reason: 'signature PNG');
  final d = ByteData.sublistView(o);
  return (d.getUint32(16), d.getUint32(20));
}

PieceBl piece(String type, double montant, {String grossisteId = '', String grossiste = ''}) =>
    PieceBl(type: type, id: '$type$montant', montantHt: type == 'BL' ? montant : -montant, grossisteId: grossisteId, grossiste: grossiste);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApparenceAccueilPrefs.reinitialiser();
    ProfilAcces.utilisateur.value = null;
  });
  tearDown(() => ProfilAcces.utilisateur.value = null);

  group('1 · P4 « icônes illustrées »', () {
    test('une icône pour chaque menu de la nouvelle interface et chaque onglet de la barre du bas', () {
      for (final m in menusModules) {
        expect(illustrationMenu(m.titre), isNotNull, reason: m.titre);
      }
      for (final o in OngletAccueil.values) {
        expect(illustrationOnglet(o.name), isNotNull, reason: o.name);
      }
      // Pas d'icône orpheline : chaque entrée correspond à un menu existant.
      final titres = {for (final m in menusModules) m.titre};
      expect(illustrationsMenus.keys.where((t) => !titres.contains(t)), isEmpty);
      expect(illustrationMenu('Menu inconnu'), isNull);
    });

    test('dans une même famille, chaque menu a sa propre icône', () {
      for (final f in Famille.values) {
        final icones = [for (final m in deLaFamille(menusModules, f)) illustrationsMenus[m.titre]];
        expect(icones.toSet().length, icones.length, reason: f.libelle);
      }
    });

    test('fichiers EMBARQUÉS : présents, PNG 144 × 144, déclarés dans pubspec.yaml, poids total < 1 Mo', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- $dossierIconesIllustrees'));
      var total = 0;
      for (final n in {...illustrationsMenus.values, ...illustrationsOnglets.values}) {
        final f = File(iconeIllustree(n));
        expect(f.existsSync(), isTrue, reason: f.path);
        final o = f.readAsBytesSync();
        expect(taillePng(o), (144, 144), reason: f.path);
        total += o.length;
      }
      expect(total, lessThan(1024 * 1024), reason: 'poids de l\'application');
    });

    test('licence MIT de Microsoft embarquée avec les icônes', () {
      final l = File(licenceIconesIllustrees).readAsStringSync();
      expect(l, contains('MIT License'));
      expect(l, contains('Copyright (c) Microsoft Corporation'));
      expect(File('docs/ICONES_ILLUSTREES.md').readAsStringSync(), contains('MIT'));
    });

    test('aucun téléchargement : pas d\'adresse internet dans le code des icônes', () {
      final code = File('lib/nouvelle_interface/icones_illustrees.dart').readAsStringSync();
      expect(code, isNot(contains('http')));
      expect(code, contains('Image.asset'));
    });

    test('P4 ajouté au réglage, défaut toujours « Actuel » ; seul P4 est illustré', () async {
      expect(StyleIcones.values, [StyleIcones.actuel, StyleIcones.p1, StyleIcones.p2, StyleIcones.p3, StyleIcones.p4]);
      expect([for (final s in StyleIcones.values) if (s.illustre) s], [StyleIcones.p4]);
      await ApparenceAccueilPrefs.charger();
      expect(ApparenceAccueilPrefs.style.value, StyleIcones.actuel);
      SharedPreferences.setMockInitialValues({ApparenceAccueilPrefs.cleStyle: 'p4'});
      await ApparenceAccueilPrefs.charger();
      expect(ApparenceAccueilPrefs.style.value, StyleIcones.p4);
      // P4 : tuile et pastille blanches (l'image remplace l'icône).
      final a = ApparenceIcone.pourMenu(StyleIcones.p4, menusModules.first);
      expect([a.pastille, a.fond], [Charte.blanc, Charte.blanc]);
      expect(couleurEnTeteFamille(StyleIcones.p4, Famille.ventes), isNull);
    });
  });

  group('2 · « Menus de l\'accueil » : trois dispositions', () {
    test('valeurs 0 / 1 / 2 ; défaut et valeurs inconnues = tout sur une page ; 1 garde le sens de la 3.9.0', () {
      expect([for (final a in AffichageMenus.values) a.valeur], [0, 1, 2]);
      expect(AffichageMenus.depuis(0), AffichageMenus.unePage);
      expect(AffichageMenus.depuis(1), AffichageMenus.parRubrique);
      expect(AffichageMenus.depuis(2), AffichageMenus.parSix);
      for (final v in [null, 3, -1, 99]) {
        expect(AffichageMenus.depuis(v), AffichageMenus.unePage, reason: '$v');
      }
      expect(AffichageMenus.unePage.parPages, isFalse);
      expect(AffichageMenus.parRubrique.parPages, isTrue);
      expect(AffichageMenus.parSix.parPages, isTrue);
      expect(menusParPage, 6);
    });

    test('lecture au lancement : 2 → 6 tuiles par page', () async {
      SharedPreferences.setMockInitialValues({ApparenceAccueilPrefs.cleAffichage: 2});
      await ApparenceAccueilPrefs.charger();
      expect(ApparenceAccueilPrefs.affichage.value, AffichageMenus.parSix);
    });

    test('paquets de 6 : tous les menus, une seule fois, dans l\'ordre des familles ; dernier paquet incomplet', () {
      final menus = [...menusModules]..shuffle();
      final paquets = paquetsDeMenus(menus);
      expect(paquets.length, (menus.length / 6).ceil());
      for (final p in paquets.take(paquets.length - 1)) {
        expect(p.length, 6);
      }
      expect(paquets.last.length, inInclusiveRange(1, 6));
      final aplati = paquets.expand((p) => p).toList();
      expect(aplati.toSet(), menus.toSet());
      expect(aplati.length, menus.length);
      final rangs = [for (final m in aplati) Famille.values.indexOf(m.famille)];
      expect(rangs, [...rangs]..sort(), reason: 'familles dans l\'ordre de la page unique');
      expect(paquetsDeMenus(const []), isEmpty);
    });

    test('titre d\'une page = familles présentes ; couleur seulement pour une famille seule (P3)', () {
      final ventes = deLaFamille(menusModules, Famille.ventes).take(2).toList();
      final credits = deLaFamille(menusModules, Famille.credits).take(1).toList();
      expect(titrePaquet(ventes), 'Ventes & caisse');
      expect(titrePaquet([...ventes, ...credits]), 'Ventes & caisse · Crédits & clients');
      expect(couleurPaquet(StyleIcones.p3, ventes), teinteFamille(Famille.ventes).icone);
      expect(couleurPaquet(StyleIcones.p3, [...ventes, ...credits]), isNull);
      expect(couleurPaquet(StyleIcones.actuel, ventes), isNull);
    });
  });

  group('3 · réservé à l\'administrateur ou au pharmacien', () {
    AppUser u({String type = '', Map<String, String>? role}) =>
        AppUser.fromJson({...DonneesFictives.utilisateur(), 'xtypeuser': type, if (role != null) 'role': role});

    test('profil « dashboard » ou rôle pharmacien / administrateur = responsable ; caissier non', () {
      expect(ProfilAcces.estResponsable(u(type: 'dashboard')), isTrue);
      for (final r in ['PHARMACIEN', 'ADMINISTRATEUR', 'SUPER_ADMINISTRATEUR', 'SYSTEME']) {
        expect(ProfilAcces.estResponsable(u(type: 'mainmenumanager', role: {'code': r, 'libelle': r})), isTrue, reason: r);
      }
      expect(ProfilAcces.estResponsable(u(type: 'mainmenumanager', role: {'code': 'AUTRE', 'libelle': 'Caissier'})), isFalse);
      expect(ProfilAcces.estResponsable(u(type: 'mainmenumanager')), isFalse);
      expect(ProfilAcces.estResponsable(null), isFalse);
    });

    test('explication montrée aux autres comptes', () {
      expect(ApparenceAccueilPrefs.explicationAffichageVerrouille, contains('administrateur ou au pharmacien'));
    });
  });

  group('4 · Pointage BL : par grossiste ou par groupe, jamais « tous les grossistes »', () {
    final d = DateTime(2026, 10, 1), f = DateTime(2026, 10, 15);

    test('« ALL » (entrée « Tous » du serveur) n\'est pas un choix : rien n\'est demandé, ni envoyé', () {
      expect(FiltresPointage(debut: d, fin: f).complet, isFalse);
      expect(FiltresPointage(grossiste: 'ALL', debut: d, fin: f).complet, isFalse);
      expect(FiltresPointage(groupe: 'all', debut: d, fin: f).complet, isFalse);
      expect(FiltresPointage(grossiste: '  ', groupe: ' ', debut: d, fin: f).complet, isFalse);
      final g = FiltresPointage(grossiste: 'ALL', groupe: 'GR1', debut: d, fin: f);
      expect(g.complet, isTrue);
      expect(g.parGroupe, isTrue);
      expect(g.parametres['grossiste'], '');
      expect(g.parametres['groupe'], 'GR1');
      final h = FiltresPointage(grossiste: 'G1', groupe: 'GR1', debut: d, fin: f);
      expect(h.parGroupe, isFalse);
      expect([h.parametres['grossiste'], h.parametres['groupe']], ['G1', ''], reason: 'le grossiste prime');
      for (final x in [g, h]) {
        expect(x.parametres.values.map((v) => v.toUpperCase()), isNot(contains('ALL')));
      }
    });

    test('montant par grossiste fourni par le serveur (« parGrossiste ») : repris tel quel, avoirs négatifs', () {
      final p = PointageBl.depuis({
        'data': [],
        'totalBl': 300,
        'totalAvoirs': -20,
        'net': 280,
        'parGrossiste': [
          {'grossisteId': 'G1', 'libelle': 'COPHARMED', 'totalBl': 200, 'totalAvoirs': -20, 'pieces': 3},
          {'grossisteId': 'G2', 'libelle': 'LABOREX', 'totalBl': 100, 'totalAvoirs': 5, 'pieces': 1},
          'illisible',
        ],
      });
      final r = p.detailGroupe(toutesLesPieces: false)!;
      expect(r.$2, SourceDetailGroupe.serveur);
      expect([for (final m in r.$1) (m.libelle, m.net)], [('COPHARMED', 180), ('LABOREX', 95)]);
      expect(r.$1.fold<double>(0, (s, m) => s + m.totalAvoirs), -25);
      // Conservé après un pointage.
      expect(p.avec(p.pieces, deltaPointes: 1).parGrossisteServeur, hasLength(2));
    });

    test('sans « parGrossiste » : calculé sur les pièces si TOUTES portent leur grossiste et état « Toutes »', () {
      final p = PointageBl(pieces: [
        piece('BL', 100, grossisteId: 'G1', grossiste: 'COPHARMED'),
        piece('RETOUR', 10, grossisteId: 'G1', grossiste: 'COPHARMED'),
        piece('BL', 300, grossisteId: 'G2', grossiste: 'LABOREX'),
        piece('RECEPTION', 5, grossisteId: 'G2'),
      ], totalBl: 400, totalAvoirs: -15, net: 385);
      final r = p.detailGroupe(toutesLesPieces: true)!;
      expect(r.$2, SourceDetailGroupe.pieces);
      expect([for (final m in r.$1) (m.grossisteId, m.libelle, m.net, m.pieces)], [('G2', 'LABOREX', 295, 2), ('G1', 'COPHARMED', 90, 2)]);
      expect(r.$1.fold<double>(0, (s, m) => s + m.net), p.net, reason: 'Σ = net du groupe');
      expect(p.detailGroupe(toutesLesPieces: false), isNull, reason: 'état filtré : détail partiel refusé');
    });

    test('serveur actuel (pièces sans grossiste) : aucun détail inventé', () {
      final p = PointageBl(pieces: [piece('BL', 100), piece('BL', 50, grossisteId: 'G1')]);
      expect(p.detailGroupe(toutesLesPieces: true), isNull);
      expect(const PointageBl(pieces: []).detailGroupe(toutesLesPieces: true), isNull);
    });

    test('lecture tolérante du grossiste d\'une pièce', () {
      expect(PieceBl.depuis({'type': 'BL', 'id': '1', 'grossisteId': 'G1', 'grossiste': 'COPHARMED'}).grossiste, 'COPHARMED');
      expect(PieceBl.depuis({'type': 'BL', 'id': '1', 'lgGROSSISTEID': 'G9'}).grossisteId, 'G9');
      expect(PieceBl.depuis({'type': 'BL', 'id': '1'}).grossisteId, '');
    });
  });

  group('5 · réponse du serveur (avec repli)', () {
    test('rôle à la connexion : lu, mémorisable, signe d\'un serveur récent ; absent = serveur ancien', () {
      final recent = AppUser.fromJson({...DonneesFictives.utilisateur(), 'role': {'code': 'pharmacien', 'libelle': 'Pharmacien'}});
      expect([recent.roleCode, recent.roleLibelle], ['PHARMACIEN', 'Pharmacien']);
      ProfilAcces.utilisateur.value = recent;
      expect(ProfilAcces.serveurRecent, isTrue);
      final ancien = AppUser.fromJson(DonneesFictives.utilisateur());
      expect([ancien.roleCode, ancien.roleLibelle], ['', '']);
      ProfilAcces.utilisateur.value = ancien;
      expect(ProfilAcces.serveurRecent, isFalse);
      ProfilAcces.utilisateur.value = null;
      expect(ProfilAcces.serveurRecent, isFalse);
      // Format inattendu : ignoré.
      expect(AppUser.fromJson({...DonneesFictives.utilisateur(), 'role': 'PHARMACIEN'}).roleCode, '');
    });

    test('Prévisions : « enCoursAJour » lu s\'il existe, vide sinon', () {
      expect(TableauPrevisions.depuis({'calcule': true, 'enCoursAJour': '15/10/2026 08:12'}).enCoursAJour, '15/10/2026 08:12');
      expect(TableauPrevisions.depuis({'calcule': true}).enCoursAJour, '');
    });

    test('CA Global : « detailMobile » cumulé par opérateur ; absent ou incomplet → rien', () {
      CaGlobal jour(double mobile, [List<Map<String, Object?>>? detail]) =>
          CaGlobal.fromJson({'totMobile': mobile, if (detail != null) 'detailMobile': detail});
      final l = [
        jour(3000, [
          {'modeId': 'OM', 'libelle': 'Orange Money', 'montant': 2000},
          {'modeId': 'WAVE', 'libelle': 'Wave', 'montant': 1000},
        ]),
        jour(0, []),
        jour(500, [
          {'modeId': 'OM', 'libelle': 'Orange Money', 'montant': 500},
        ]),
      ];
      final d = CaGlobalDonnees.detailMobile(l)!;
      expect([for (final o in d) (o.libelle, o.montant)], [('Orange Money', 2500), ('Wave', 1000)]);
      expect(CaGlobalDonnees.detailMobile([jour(3000), jour(0)]), isNull, reason: 'serveur ancien');
      expect(CaGlobalDonnees.detailMobile([l.first, jour(800)]), isNull, reason: 'un jour sans détail : non fiable');
      expect(CaGlobalDonnees.detailMobile(const []), isNull);
    });
  });
}
