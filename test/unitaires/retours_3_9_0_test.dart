// Unitaires des retours du pharmacien appliqués en 3.9.0 (logique pure, sans écran ni serveur) :
//  1. Suivi 20/80 « Tous » : topN ABSENT (= tous pour le serveur), limit 9 999, aucune coupe côté appli ; l'écran
//     d'origine ne peut pas demander « tous » (inchangé : 50 par défaut) ;
//  2. « Fiche Article » retiré de la nouvelle interface ; l'ordre mémorisé (commun aux deux interfaces) le garde ;
//  3. recherche de produit « contient » : paramètres, lecture tolérante, CIP EXACT pour le détail ;
//  4. Pointage BL : dernier grossiste (ou groupe) mémorisé ;
//  5. « Menus de l'accueil » 0 / 1 : lecture, défaut, changement (compte « admin ») ;
//  6. « Style des icônes » : défaut « Actuel », palette par famille (contrastes ≥ 4,5:1), onglets colorés.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/donnees/recherche_produit_donnees.dart';
import 'package:prestige_app/models/analyse_article_model.dart';
import 'package:prestige_app/models/suivi_20_80_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/apparence_accueil.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/providers/home_settings_provider.dart';
import 'package:prestige_app/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contraste(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

Suivi2080 article(String cip, int montant) => Suivi2080(cip: cip, libelle: cip, montant: montant, quantiteVendue: 1, stock: 0);

AnalyseArticle analyse(String cip) => AnalyseArticle(codeCip: cip, libelle: 'ARTICLE $cip', moyenne: 0, prixAchat: 0, prixVente: 0, quantiteVendue: 0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApparenceAccueilPrefs.reinitialiser();
  });

  group('1 · Suivi 20/80 : « Tous »', () {
    final d = DateTime(2026, 10, 1), f = DateTime(2026, 10, 15);

    test('Tous : topN absent (= tous pour le serveur), limit 9 999, autres paramètres inchangés', () {
      final p = Suivi2080Donnees.parametres(d, f, Suivi2080Donnees.tous);
      expect(p.containsKey('topN'), isFalse);
      expect(p['limit'], '9999');
      final avec50 = Suivi2080Donnees.parametres(d, f, 50);
      expect({...p}..remove('limit'), {...avec50}..remove('limit')..remove('topN'));
      expect(Suivi2080Donnees.parametres(d, f, Suivi2080Donnees.tous, critere: CritereVingt.quantite)['vingtType'], 'QTY');
    });

    test('un nombre choisi : topN toujours envoyé (défaut 50 inchangé)', () {
      expect(Suivi2080Donnees.limiteParDefaut, 50);
      expect(Suivi2080Donnees.parametres(d, f, 50)['topN'], '50');
      expect(Suivi2080Donnees.parametres(d, f, 1)['topN'], '1');
    });

    test('Tous : aucune coupe côté application ; champ « 0 » de l\'écran d\'origine = 50 (pas « tous »)', () {
      final l = [for (var i = 0; i < 300; i++) article('A$i', 1000 - i)];
      expect(Suivi2080Donnees.garder(l, Suivi2080Donnees.tous), same(l));
      expect(Suivi2080Donnees.limite('0'), 50);
      expect(Suivi2080Donnees.limite(''), 50);
    });
  });

  group('2 · « Fiche Article » retiré de la nouvelle interface', () {
    test('absent des menus (A, B, C, recherche, personnalisation) ; Analyse Article présent', () {
      final titres = [for (final m in menusModules) m.titre];
      expect(titres, isNot(contains('Fiche Article')));
      expect(titres, contains('Analyse Article'));
      expect(menusRetiresNouvelle, containsAll(['Fiche Article', 'Fournisseurs']));
      expect([for (final m in menusModules) if (m.ecran() is FicheArticleNouveau) m], isEmpty);
      expect(menusModules, hasLength(35));
    });

    test('ordre et menus masqués mémorisés : « Fiche Article » ignoré par la nouvelle interface, sans erreur', () async {
      SharedPreferences.setMockInitialValues({
        'feature_order_key': ['Fiche Article', 'Suivi 20/80', 'Analyse Article'],
        'disabled_features_key': ['Fiche Article'],
      });
      final r = HomeSettingsProvider();
      await r.loadSettings();
      final visibles = [for (final m in menusVisibles(r)) m.titre];
      expect(visibles.take(2), ['Suivi 20/80', 'Analyse Article'], reason: 'ordre gardé pour les autres menus');
      expect(visibles, isNot(contains('Fiche Article')));
    });

    test('enregistrer l\'ordre depuis la nouvelle interface : « Fiche Article » et « Fournisseurs » gardent leur place', () {
      final ancien = ['Détail CA', 'Fiche Article', 'Analyse Article', 'Fournisseurs', 'Suivi 20/80'];
      final nouveau = ['Analyse Article', 'Détail CA', 'Suivi 20/80'];
      expect(HomeSettingsProvider.fusionnerOrdre(ancien, nouveau), ['Analyse Article', 'Fiche Article', 'Détail CA', 'Fournisseurs', 'Suivi 20/80']);
      expect(HomeSettingsProvider.fusionnerOrdre(const [], nouveau), nouveau, reason: 'rien de mémorisé');
      expect(HomeSettingsProvider.fusionnerOrdre(nouveau, ['Suivi 20/80', 'Détail CA', 'Analyse Article']), ['Suivi 20/80', 'Détail CA', 'Analyse Article'],
          reason: 'ancienne interface (tous les menus proposés) : ordre inchangé');
    });
  });

  group('3 · Recherche de produit « contient »', () {
    test('route et paramètres : /espace-produit/recherche?q= (texte nettoyé), 2 caractères au moins', () {
      expect(RechercheProduit.route, AppConstants.rechercheProduitEndpoint);
      expect(RechercheProduit.route, '/espace-produit/recherche');
      expect(RechercheProduit.parametres('  500mg '), {'q': '500mg'});
      expect(RechercheProduit.assezLong('a'), isFalse);
      expect(RechercheProduit.assezLong(' a '), isFalse);
      expect(RechercheProduit.assezLong('ab'), isTrue);
      expect(RechercheProduit.assezLong('12'), isTrue);
    });

    test('lecture tolérante : {data:[…]} ou liste, lignes sans CIP ou sans nom écartées, nombres en texte', () {
      final l = RechercheProduit.lire({
        'total': 4,
        'data': [
          {'cip': '9990001', 'designation': 'PARAFICTIF 500MG', 'emplacement': 'RAYON A', 'prixVente': 1200, 'stockRayon': 3, 'stockTotal': 23},
          {'cip': '', 'designation': 'SANS CIP'},
          {'cip': '9990003', 'designation': ''},
          {'cip': '9990004', 'designation': 'TEXTE', 'prixVente': '850', 'stockRayon': '4', 'emplacement': ''},
          'illisible',
        ],
      });
      expect([for (final p in l) p.cip], ['9990001', '9990004']);
      expect(l.first.stockTotal, 23);
      expect(l.last.prixVente, 850);
      expect(l.last.stockTotal, 4, reason: 'sans stockTotal : stock rayon');
      expect(l.last.emplacement, isNull);
      expect(RechercheProduit.lire([
        {'cip': '1', 'designation': 'X'}
      ]), hasLength(1));
      expect(RechercheProduit.lire(null), isEmpty);
      expect(RechercheProduit.lire({'success': false}), isEmpty);
    });

    test('détail : l\'article de /info dont le CIP est EXACTEMENT celui choisi (pas un CIP qui commence pareil)', () {
      final articles = [analyse('99900012'), analyse('9990001'), analyse('99900013')];
      expect(RechercheProduit.choisirParCip(articles, '9990001')!.codeCip, '9990001');
      expect(RechercheProduit.choisirParCip(articles, ' 9990001 ')!.codeCip, '9990001');
      expect(RechercheProduit.choisirParCip([analyse('99900012')], '9990001'), isNull);
    });

    test('limite de 50 du serveur signalée seulement en mode « contient »', () {
      final cinquante = [for (var i = 0; i < 50; i++) ProduitTrouve(cip: '$i', designation: 'P$i')];
      expect(ResultatRechercheProduit(cinquante, contient: true).limiteAtteinte, isTrue);
      expect(ResultatRechercheProduit(cinquante.take(49).toList(), contient: true).limiteAtteinte, isFalse);
      expect(ResultatRechercheProduit(cinquante, contient: false).limiteAtteinte, isFalse);
    });

    test('repli (serveur ancien) : le produit porte déjà son analyse', () {
      final p = ProduitTrouve.deAnalyse(analyse('9990001'));
      expect(p.analyse, isNotNull);
      expect(p.cip, '9990001');
    });
  });

  group('4 · Pointage BL : dernier grossiste (ou groupe) utilisé', () {
    FiltresPointage f({String grossiste = '', String groupe = ''}) =>
        FiltresPointage(grossiste: grossiste, groupe: groupe, debut: DateTime(2026, 10, 1), fin: DateTime(2026, 10, 15));

    test('codage : grossiste prioritaire, groupe sinon, rien sans critère', () {
      expect(DernierCriterePointage.encoder(f(grossiste: 'G1', groupe: 'GR')), 'grossiste:G1');
      expect(DernierCriterePointage.encoder(f(groupe: 'GR')), 'groupe:GR');
      expect(DernierCriterePointage.encoder(f()), isNull);
      expect(DernierCriterePointage.decoder('grossiste:G1'), ('G1', ''));
      expect(DernierCriterePointage.decoder('groupe:GR'), ('', 'GR'));
      for (final v in ['', 'grossiste:', ':G1', 'autre:X', 'G1']) {
        expect(DernierCriterePointage.decoder(v), isNull, reason: v);
      }
    });

    test('enregistré puis relu ; oublié ; une recherche sans critère n\'efface rien', () async {
      expect(await DernierCriterePointage.lire(), isNull);
      await DernierCriterePointage.enregistrer(f(grossiste: 'G2'));
      expect(await DernierCriterePointage.lire(), ('G2', ''));
      await DernierCriterePointage.enregistrer(f());
      expect(await DernierCriterePointage.lire(), ('G2', ''));
      await DernierCriterePointage.enregistrer(f(groupe: 'GR1'));
      expect(await DernierCriterePointage.lire(), ('', 'GR1'));
      await DernierCriterePointage.oublier();
      expect(await DernierCriterePointage.lire(), isNull);
    });
  });

  group('5 · « Menus de l\'accueil » : sur une page (0, défaut) / par pages (1)', () {
    test('valeurs 0 / 1, tout le reste = sur une page', () {
      expect(AffichageMenus.unePage.valeur, 0);
      expect(AffichageMenus.parPages.valeur, 1);
      expect(AffichageMenus.depuis(1), AffichageMenus.parPages);
      for (final v in [0, null, 2, -1]) {
        expect(AffichageMenus.depuis(v), AffichageMenus.unePage, reason: '$v');
      }
    });

    test('lecture au lancement : défaut « sur une page » et « Actuel » ; valeurs mémorisées reprises', () async {
      await ApparenceAccueilPrefs.charger();
      expect(ApparenceAccueilPrefs.affichage.value, AffichageMenus.unePage);
      expect(ApparenceAccueilPrefs.style.value, StyleIcones.actuel);
      SharedPreferences.setMockInitialValues({ApparenceAccueilPrefs.cleAffichage: 1, ApparenceAccueilPrefs.cleStyle: 'p2'});
      await ApparenceAccueilPrefs.charger();
      expect(ApparenceAccueilPrefs.affichage.value, AffichageMenus.parPages);
      expect(ApparenceAccueilPrefs.style.value, StyleIcones.p2);
      SharedPreferences.setMockInitialValues({ApparenceAccueilPrefs.cleAffichage: 7, ApparenceAccueilPrefs.cleStyle: 'inconnu'});
      await ApparenceAccueilPrefs.charger();
      expect(ApparenceAccueilPrefs.affichage.value, AffichageMenus.unePage);
      expect(ApparenceAccueilPrefs.style.value, StyleIcones.actuel);
    });
  });

  group('6 · Style des icônes (propositions)', () {
    test('« Actuel » par défaut = apparence d\'origine (bleu nuit sur bleu clair, tuile blanche)', () {
      expect(StyleIcones.values.first, StyleIcones.actuel);
      for (final f in Famille.values) {
        final a = ApparenceIcone.de(StyleIcones.actuel, teinteFamille(f));
        expect([a.icone, a.pastille, a.fond], [Charte.navy, Charte.bleuClair, Charte.blanc]);
        expect(couleurEnTeteFamille(StyleIcones.actuel, f), isNull);
      }
    });

    test('une couleur différente par famille ; « Alertes » en rouge', () {
      final couleurs = {for (final f in Famille.values) teinteFamille(f).icone};
      expect(couleurs, hasLength(Famille.values.length));
      expect(couleurs, isNot(contains(Charte.familleAlertes)));
      expect(teinteMenu(menusModules.firstWhere((m) => m.titre == 'Alertes')).icone, Charte.familleAlertes);
      expect(teinteMenu(menusModules.firstWhere((m) => m.titre == 'Détail CA')).icone, Charte.familleVentes);
    });

    test('contrastes ≥ 4,5:1 : icône sur pastille, sur tuile teintée et sur blanc ; textes sur tuile teintée', () {
      for (final t in [for (final f in Famille.values) teinteFamille(f), teinteAlertes]) {
        expect(contraste(t.icone, t.pastille), greaterThanOrEqualTo(4.5), reason: '${t.icone} / pastille');
        expect(contraste(t.icone, t.tuile), greaterThanOrEqualTo(4.5), reason: '${t.icone} / tuile');
        expect(contraste(t.icone, Charte.blanc), greaterThanOrEqualTo(4.5), reason: '${t.icone} / blanc');
        expect(contraste(t.icone, Charte.page), greaterThanOrEqualTo(4.5), reason: '${t.icone} / fond de page (en-têtes P3)');
        expect(contraste(Charte.encre, t.tuile), greaterThanOrEqualTo(4.5));
        expect(contraste(Charte.gris, t.tuile), greaterThanOrEqualTo(4.5));
      }
    });

    test('P1 pastille douce, P2 tuile teintée, P3 icône sur blanc et en-têtes colorés', () {
      final t = teinteFamille(Famille.stock);
      final p1 = ApparenceIcone.de(StyleIcones.p1, t), p2 = ApparenceIcone.de(StyleIcones.p2, t), p3 = ApparenceIcone.de(StyleIcones.p3, t);
      expect([p1.icone, p1.pastille, p1.fond], [t.icone, t.pastille, Charte.blanc]);
      expect([p2.icone, p2.pastille, p2.fond], [t.icone, Charte.blanc, t.tuile]);
      expect([p3.icone, p3.pastille, p3.fond], [t.icone, Charte.blanc, Charte.blanc]);
      expect(couleurEnTeteFamille(StyleIcones.p1, Famille.stock), isNull);
      expect(couleurEnTeteFamille(StyleIcones.p2, Famille.stock), isNull);
      expect(couleurEnTeteFamille(StyleIcones.p3, Famille.stock), t.icone);
    });

    test('barre du bas : une couleur par onglet, lisible sur son indicateur et sur blanc', () {
      final couleurs = {for (final o in OngletAccueil.values) teinteOnglet(o).icone};
      expect(couleurs, hasLength(OngletAccueil.values.length));
      for (final o in OngletAccueil.values) {
        expect(contraste(teinteOnglet(o).icone, teinteOnglet(o).pastille), greaterThanOrEqualTo(4.5), reason: o.name);
        expect(contraste(teinteOnglet(o).icone, Charte.blanc), greaterThanOrEqualTo(4.5), reason: o.name);
      }
    });
  });
}
