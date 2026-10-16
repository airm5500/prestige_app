// Vague 1 des nouveaux menus (lib/nouvelle_interface/vague1/) : logique pure.
//  - lecture TOLÉRANTE des 4 formats du serveur : valorisation (tableau de bord et /produit/valorisation), alertes
//    (comptage et listes), retraits et abandons (clé « results »), ventes modifiées (clé « results », lignes) ;
//  - refus du serveur : interdit:true, success:false → « Droit manquant : … » ; success:false + erreur:true → erreur
//    du serveur ;
//  - contrôles : périodes (contrôle COMMUN du lot 1, periode.dart : début ≤ fin, jamais futures, 3 ans au maximum),
//    paramètres envoyés, date de valorisation ;
//  - visibilité par profil : nouveaux menus pour « dashboard » (administrateur, pharmacien) seulement.
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/modules/periode.dart';
import 'package:prestige_app/nouvelle_interface/vague1/commun_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/providers/home_settings_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';

Matcher echecDe(NatureErreur n, {String? contient}) => throwsA(isA<ApiLoadException>()
    .having((e) => e.nature, 'nature', n)
    .having((e) => e.message, 'message', contient == null ? anything : contains(contient)));

AppUser utilisateur(String type) => AppUser(userId: 'U', firstName: 'Test', lastName: 'Fictif', login: 'test', officineName: 'P', typeUser: type);

void main() {
  group('Lecture tolérante', () {
    test('entiers : int, décimal arrondi, texte avec espaces ou virgule, booléen ; sinon 0', () {
      expect(entierTolerant(12), 12);
      expect(entierTolerant(12.6), 13);
      expect(entierTolerant('1 245'), 1245);
      expect(entierTolerant('1 245'), 1245);
      expect(entierTolerant('12,4'), 12);
      expect(entierTolerant('-3'), -3);
      expect(entierTolerant(null), 0);
      expect(entierTolerant('beaucoup'), 0);
      expect(entierTolerant(double.nan), 0);
      expect(entierTolerant({'x': 1}), 0);
      expect(entierTolerant(true), 1);
    });

    test('textes : null et « null » → vide ; nombres rendus en texte', () {
      expect(texteTolerant(null), '');
      expect(texteTolerant('null'), '');
      expect(texteTolerant(' abc '), 'abc');
      expect(texteTolerant(9990001), '9990001');
    });

    test('booléens : true/false, 1/0, « oui »/« non », valeur par défaut', () {
      expect(booleenTolerant(true), isTrue);
      expect(booleenTolerant('false', defaut: true), isFalse);
      expect(booleenTolerant(1), isTrue);
      expect(booleenTolerant('oui'), isTrue);
      expect(booleenTolerant(null, defaut: true), isTrue);
      expect(booleenTolerant('?'), isFalse);
    });

    test('« 2026-10-12 » → « 12/10/2026 » ; vide → « — »', () {
      expect(dateLisibleApi('2026-10-12'), '12/10/2026');
      expect(dateLisibleApi('2026-10-12 08:30:00'), '12/10/2026');
      expect(dateLisibleApi(''), '—');
      expect(dateLisibleApi('12/10/2026'), '12/10/2026');
    });
  });

  group('Refus et erreurs du serveur', () {
    test('corps vide : carte vide (vraie absence de données)', () => expect(lireReponseVague1(null, 'x'), isEmpty));

    test('liste au lieu d\'un objet : « réponse inattendue »', () {
      expect(() => lireReponseVague1(const <Object>[], 'les alertes'), echecDe(NatureErreur.reponse, contient: 'les alertes'));
    });

    test('interdit:true → « Droit manquant : … » (même avec success:true)', () {
      expect(() => lireReponseVague1({'success': true, 'interdit': true}, 'les alertes'),
          echecDe(NatureErreur.droit, contient: 'Droit manquant : consulter les alertes.'));
    });

    test('success:false (refus) → « Droit manquant », message du serveur repris', () {
      expect(() => lireReponseVague1({'success': false, 'msg': 'Vous n\'avez pas accès.'}, 'les ventes modifiées'),
          echecDe(NatureErreur.droit, contient: '(Vous n\'avez pas accès.)'));
    });

    test('success:false + erreur:true (calcul en échec) → erreur du serveur, pas un droit', () {
      expect(() => lireReponseVague1({'success': false, 'erreur': true}, 'les alertes'), echecDe(NatureErreur.serveur, contient: 'pas pu calculer'));
    });

    test('réponse correcte : rendue telle quelle', () {
      expect(lireReponseVague1({'success': true, 'a': 1}, 'x')['a'], 1);
      expect(lireReponseVague1({'total': 0, 'results': []}, 'x'), contains('results'));
    });

    test('mots d\'un message de droit', () {
      expect(estMessageDeDroit('Accès refusé'), isTrue);
      expect(estMessageDeDroit('Vous n\'avez pas le droit'), isTrue);
      expect(estMessageDeDroit('Erreur SQL'), isFalse);
    });
  });

  group('Format 1 : valorisation', () {
    test('tableau de bord : rayon, réserve, total, produits dormants', () {
      final v = Valorisation.depuisTableauDeBord(DonneesVague1.valorisationTableauDeBord());
      expect(v.rayon.achat, DonneesVague1.rayonAchat);
      expect(v.reserve.vente, DonneesVague1.reserveVente);
      expect(v.total.achat, DonneesVague1.rayonAchat + DonneesVague1.reserveAchat);
      expect(v.dormants, 37);
      expect(v.releveDisponible, isTrue);
      expect(v.source, SourceValorisation.tableauDeBord);
    });

    test('tableau de bord : total absent → rayon + réserve ; montants en texte ; blocs absents → 0', () {
      final v = Valorisation.depuisTableauDeBord({
        'rayon': {'achat': '1 000', 'vente': 1500.4},
        'reserve': {'achat': 200, 'vente': '300'},
      });
      expect(v.total.achat, 1200);
      expect(v.total.vente, 1800);
      expect(v.dormants, isNull);
      final vide = Valorisation.depuisTableauDeBord({});
      expect(vide.total.vente, 0);
    });

    test('/produit/valorisation : value = rayon achat, valueTwo = rayon vente, réserve, total (64 bits)', () {
      final v = Valorisation.depuisProduit({
        'data': {
          'value': 3000000000, 'valueTwo': 4500000000, 'reserveValue': 10, 'reserveValueTwo': 20,
          'totalValue': 3000000010, 'totalValueTwo': 4500000020, 'releveDisponible': true,
        },
      }, duJour: false);
      expect(v.rayon.achat, 3000000000, reason: 'au-delà de 2,1 milliards');
      expect(v.rayon.vente, 4500000000);
      expect(v.reserve.achat, 10);
      expect(v.total.vente, 4500000020);
      expect(v.source, SourceValorisation.releve);
    });

    test('/produit/valorisation : sans l\'enveloppe « data » ; total absent → somme ; releveDisponible absent → vrai', () {
      final v = Valorisation.depuisProduit({'value': 100, 'valueTwo': 150, 'reserveValue': 20, 'reserveValueTwo': 30}, duJour: true);
      expect(v.total.achat, 120);
      expect(v.total.vente, 180);
      expect(v.releveDisponible, isTrue);
      expect(v.source, SourceValorisation.calculDuJour);
    });

    test('jour jamais relevé : releveDisponible:false', () {
      expect(Valorisation.depuisProduit(DonneesVague1.valorisationProduit(releve: false), duJour: false).releveDisponible, isFalse);
    });

    test('écart = vente − achat ; marge % = écart / vente (comme l\'écran web) ; vente nulle → marge inconnue', () {
      const v = ValeursStock(800, 1000);
      expect(v.ecart, 200);
      expect(v.margePourcent, 20);
      expect(const ValeursStock(0, 0).margePourcent, isNull);
      expect(const ValeursStock(1200, 1000).margePourcent, -20);
      expect(pourcent(20), '20,0 %');
      expect(pourcent(null), '—');
    });

    test('route : aujourd\'hui sans regroupement → tableau de bord ; sinon /produit/valorisation', () {
      final m = DateTime(2026, 10, 14, 15);
      expect(ApiValorisation.parTableauDeBord(ModeValorisation.simple, DateTime(2026, 10, 14), m), isTrue);
      expect(ApiValorisation.parTableauDeBord(ModeValorisation.simple, DateTime(2026, 10, 13), m), isFalse);
      expect(ApiValorisation.parTableauDeBord(ModeValorisation.famille, DateTime(2026, 10, 14), m), isFalse);
    });

    test('paramètres : mode, date aaaa-mm-jj, identifiants choisis séparés par des virgules (rien si aucun choix)', () {
      expect(ApiValorisation.parametresProduit(ModeValorisation.simple, DateTime(2026, 10, 1), ['x']), {'mode': '0', 'dtStart': '2026-10-01'});
      expect(ApiValorisation.parametresProduit(ModeValorisation.famille, DateTime(2026, 10, 1), ['A', 'B']),
          {'mode': '1', 'dtStart': '2026-10-01', 'lgFAMILLEARTICLEID': 'A,B'});
      expect(ApiValorisation.parametresProduit(ModeValorisation.emplacement, DateTime(2026, 10, 1), []), {'mode': '2', 'dtStart': '2026-10-01'});
      expect(ApiValorisation.parametresProduit(ModeValorisation.grossiste, DateTime(2026, 10, 1), ['G']),
          {'mode': '3', 'dtStart': '2026-10-01', 'lgGROSSISTEID': 'G'});
    });

    test('listes de choix : entrée « Tous » (ALL) retirée, libellé vide → identifiant', () {
      final o = lireOptions(DonneesVague1.familles());
      expect(o.map((e) => e.id), ['FAM-TEST-1', 'FAM-TEST-2']);
      expect(lireOptions([{'id': 'X', 'libelle': ''}]).single.libelle, 'X');
      expect(lireOptions(DonneesVague1.utilisateurs(), champId: 'lgUSERID', champLibelle: 'fullName').first.libelle, DonneesVague1.utilisateur1);
      expect(lireOptions('rien'), isEmpty);
    });
  });

  group('Format 2 : alertes', () {
    final a = AlertesTableauDeBord(DonneesVague1.alertes());

    test('blocs du serveur : ruptures, péremptions, suggestions, renouvellements, avoirs, négatifs, non vendus', () {
      expect(a.ruptures, DonneesVague1.ruptures);
      expect(a.rupturesVenduesRecemment, 4);
      expect(a.peremptionsLots, DonneesFictives.lotsPerimes);
      expect(a.suggestionsReserve, 2);
      expect(a.suggestionsRayon, 1);
      expect(a.suggestionsCommande, 1);
      expect(a.renouvellements, 5);
      expect(a.avoirs, 0);
      expect(a.negatifs, DonneesVague1.negatifs);
      expect(a.nonVendus, DonneesVague1.nonVendus);
      expect(a.toutes, hasLength(TypeAlerte.values.length));
      expect(a.typesAlerte, 8, reason: 'toutes sauf les avoirs (0)');
    });

    test('tolérance : bloc absent → 0 et réglages par défaut ; nombre seul à la place d\'un bloc', () {
      final t = AlertesTableauDeBord({'ruptures': 5, 'avoirs': '3', 'negatifs': null});
      expect(t.ruptures, 5, reason: 'nombre seul accepté à la place du bloc { produits }');
      expect(t.avoirs, 3);
      expect(t.negatifs, 0);
      expect(t.moisPeremption, 6);
      expect(t.joursNonVendus, 30);
      expect(AlertesTableauDeBord({}).typesAlerte, 0);
      expect(AlertesTableauDeBord({'ruptures': {'jours': 7}}).ruptures, 0, reason: 'bloc sans « produits »');
    });

    test('textes : unités au singulier / pluriel, réglages repris dans le détail', () {
      expect(a.alerte(TypeAlerte.ruptures).nombreTexte, '12 produits');
      expect(AlertesTableauDeBord({'avoirs': 1}).alerte(TypeAlerte.avoirs).nombreTexte, '1 vente');
      expect(a.alerte(TypeAlerte.peremptions).detail, contains('6 mois'));
      expect(a.alerte(TypeAlerte.suggestionsCommande).detail, contains('2 jours'));
      expect(AlertesTableauDeBord({'ruptures': {'produits': 1245}}).alerte(TypeAlerte.ruptures).nombreTexte, '1 245 produits');
    });

    test('types listables = types acceptés par /tableau-bord/alertes/liste', () {
      expect([for (final t in TypeAlerte.values) if (t.listable) t.typeListe], ['ruptures', 'peremptions', 'negatifs', 'nonvendus', 'rayon']);
    });

    test('paramètres : comptage per=6&rup=7&ren=7&sug=2&nv=30 ; liste avec mêmes réglages et limite=500', () {
      expect(ReglagesAlertes.parametresComptage, {'per': '6', 'rup': '7', 'ren': '7', 'sug': '2', 'nv': '30'});
      expect(ReglagesAlertes.parametresListe(TypeAlerte.nonVendus), {'type': 'nonvendus', 'per': '6', 'rup': '7', 'nv': '30', 'limite': '500'});
    });

    test('réglages des alertes : bornes (per 1–24 mois, rup / ren / sug 1–90 j, nv 1–365 j), défauts du web', () {
      expect({for (final r in ReglageAlerte.values) r.name: (r.min, r.max, r.defaut)}, {
        'per': (1, 24, 6), 'rup': (1, 90, 7), 'ren': (1, 90, 7), 'sug': (1, 90, 2), 'nv': (1, 365, 30),
      });
      expect(ReglageAlerte.per.erreur('6'), isNull);
      expect(ReglageAlerte.per.erreur('24'), isNull);
      expect(ReglageAlerte.per.erreur('25'), 'Entre 1 et 24 mois.');
      expect(ReglageAlerte.per.erreur('0'), 'Entre 1 et 24 mois.');
      expect(ReglageAlerte.rup.erreur('91'), 'Entre 1 et 90 jours.');
      expect(ReglageAlerte.nv.erreur('365'), isNull);
      expect(ReglageAlerte.nv.erreur('366'), 'Entre 1 et 365 jours.');
      expect(ReglageAlerte.sug.erreur(''), 'Valeur obligatoire.');
      expect(ReglageAlerte.ren.erreur('7j'), 'Nombre entier attendu.');
      expect(() => ValeursAlertes.defaut.avec(ReglageAlerte.per, 30), throwsArgumentError);
      final v = ValeursAlertes.defaut.avec(ReglageAlerte.per, 12).avec(ReglageAlerte.sug, 5);
      expect(v.de(ReglageAlerte.per), 12);
      expect(v.estDefaut, isFalse);
      expect(ValeursAlertes.depuisJson(v.versJson()), v);
      // Mémoire illisible ou hors bornes : valeur par défaut pour ce délai seulement.
      expect(ValeursAlertes.depuisJson({'per': 99, 'rup': 'x', 'nv': 60}).versJson(), {'per': 6, 'rup': 7, 'ren': 7, 'sug': 2, 'nv': 60});
      expect(ValeursAlertes.depuisJson(null), ValeursAlertes.defaut);
    });

    test('lignes de liste : précisions propres à chaque type', () {
      final p = LigneAlerte.depuis(Map<String, dynamic>.from((DonneesVague1.listeAlerte('peremptions')['data'] as List).first as Map));
      expect(p.details(TypeAlerte.peremptions), [('Lot', 'LOT-TEST-1'), ('Péremption', '15/11/2026'), ('Quantité', '2')]);
      final r = LigneAlerte.depuis({'libelle': 'X', 'cip': '1', 'derniereVente': '', 'recent': true, 'grossiste': ''});
      expect(r.details(TypeAlerte.ruptures), [('Dernière vente', '—'), ('Vendu récemment', 'oui')]);
      final n = LigneAlerte.depuis({'libelle': 'X', 'quantite': '-3', 'emplacement': 'RAYON A'});
      expect(n.details(TypeAlerte.negatifs), [('Stock', '-3'), ('Emplacement', 'RAYON A')]);
    });
  });

  group('Formats 3 et 4 : retraits et abandons, ventes modifiées (clé « results »)', () {
    test('page : « results », total du serveur ; clé « data » acceptée ; total absent → nombre de lignes', () {
      final p = lirePage(DonneesVague1.page(DonneesVague1.suppressions(), const {}, 'typeSuppression'), SuppressionVente.depuis, 'x');
      expect(p.lignes, hasLength(5));
      expect(p.total, 5);
      final d = lirePage({'data': [{'id': '1'}]}, SuppressionVente.depuis, 'x');
      expect(d.total, 1);
      expect(lirePage(<String, dynamic>{}, SuppressionVente.depuis, 'x').lignes, isEmpty);
      expect(() => lirePage({'results': 'x'}, SuppressionVente.depuis, 'x'), echecDe(NatureErreur.reponse));
    });

    test('total inférieur aux lignes reçues : corrigé', () {
      expect(lirePage({'total': 0, 'results': [{'id': '1'}, {'id': '2'}]}, SuppressionVente.depuis, 'x').total, 2);
    });

    test('retrait : type, libellés, moment sans les secondes, quantité en texte', () {
      final s = SuppressionVente.depuis({
        'id': 7, 'typeSuppression': 'vente', 'venteRef': 'V1', 'produitCip': 9990001, 'produitLibelle': 'P', 'quantite': '2',
        'userName': 'A', 'origineUserName': 'B', 'date': '14/10/2026', 'heure': '09:12:30',
      });
      expect(s.id, '7');
      expect(s.venteAbandonnee, isTrue);
      expect(s.typeLibelle, 'Vente abandonnée');
      expect(s.produitCip, '9990001');
      expect(s.quantite, 2);
      expect(s.moment, '14/10/2026 à 09:12');
      expect(SuppressionVente.depuis({'typeSuppression': 'PRODUIT'}).typeLibelle, 'Produit retiré');
      expect(SuppressionVente.depuis({}).typeLibelle, 'Suppression');
    });

    test('vente modifiée : lignes avant / après, actions lisibles, écart, libellé de secours', () {
      final v = VenteModifiee.depuis(Map<String, dynamic>.from(DonneesVague1.ventesModifiees().first));
      expect(v.typeLibelle, 'Modification des produits');
      expect(v.lignes, hasLength(2));
      expect(v.lignes.first.actionLibelle, 'Produit retiré');
      expect(v.lignes.first.qteAvant, 1);
      expect(v.lignes.first.qteApres, 0);
      expect(v.lignes[1].actionLibelle, 'Quantité modifiée');
      expect(v.ecart, -1200);
      final sans = VenteModifiee.depuis({'typeModification': 'DATE', 'montantAvant': '', 'lignes': 'x'});
      expect(sans.typeLibelle, 'Modification de la date');
      expect(sans.lignes, isEmpty);
      expect(sans.montantAvant, isNull);
      expect(sans.ecart, isNull);
      expect(LigneModifiee.depuis({'action': 'prix'}).actionLibelle, 'Prix modifié');
      expect(LigneModifiee.depuis({'valeurAvant': 10, 'valeurApres': 5}).montantApres, 5);
    });

    test('paramètres envoyés : start, limit, dates aaaa-mm-jj, utilisateur, recherche rognée, type', () {
      final f = FiltresJournal(debut: DateTime(2026, 10, 1), fin: DateTime(2026, 10, 14), utilisateurId: 'U1', type: 'VENTE', recherche: '  para ');
      expect(f.parametres(50, 50), {
        'start': '50', 'limit': '50', 'dtStart': '2026-10-01', 'dtEnd': '2026-10-14', 'userId': 'U1', 'query': 'para', 'type': 'VENTE',
      });
      expect(f.copie(type: '').parametres(0, 50)['type'], '');
    });
  });

  group('Périodes des journaux : sélecteur et contrôle communs (periode.dart)', () {
    final m = DateTime(2026, 10, 14, 10);

    test('période par défaut des journaux : aujourd\'hui, envoyée au format d\'origine', () {
      final p = Periode.rapide(PeriodeRapide.aujourdhui, m);
      final f = FiltresJournal(debut: p.debut, fin: p.fin);
      expect(f.parametres(0, 50)['dtStart'], '2026-10-14');
      expect(f.parametres(0, 50)['dtEnd'], '2026-10-14');
    });

    test('mêmes refus que le lot 1 : à l\'envers, futur, plus de 3 ans', () {
      expect(ControlePeriode.erreur(DateTime(2026, 10, 10), DateTime(2026, 10, 9), m), contains('précéder'));
      expect(ControlePeriode.erreur(DateTime(2026, 10, 14), DateTime(2026, 10, 15), m), contains('futur'));
      expect(ControlePeriode.erreur(DateTime(2023, 10, 15), DateTime(2026, 10, 14), m), isNull, reason: '3 ans');
      expect(ControlePeriode.erreur(DateTime(2023, 10, 14), DateTime(2026, 10, 14), m), contains('3 ans au maximum'));
    });

    test('raccourcis communs (aujourd\'hui, hier, 7 jours, ce mois, mois dernier) tous valides', () {
      for (final c in PeriodeRapide.values) {
        final p = Periode.rapide(c, m);
        expect(ControlePeriode.erreur(p.debut, p.fin, m), isNull, reason: c.libelle);
      }
    });
  });

  group('Visibilité par profil', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    tearDown(() => ProfilAcces.utilisateur.value = null);

    test('« xtypeuser » lu à la connexion (réponse de /user/auth)', () {
      expect(AppUser.fromJson(DonneesFictives.utilisateur()).typeUser, 'dashboard');
      expect(AppUser.fromJson({'str_LOGIN': 'x'}).typeUser, '');
    });

    test('administrateur et pharmacien (« dashboard ») : oui ; autres profils, profil inconnu, déconnecté : non', () {
      expect(ProfilAcces.estResponsable(utilisateur('dashboard')), isTrue);
      expect(ProfilAcces.estResponsable(utilisateur(' Dashboard ')), isTrue);
      expect(ProfilAcces.estResponsable(utilisateur('mainmenumanager')), isFalse);
      expect(ProfilAcces.estResponsable(utilisateur('')), isFalse);
      expect(ProfilAcces.estResponsable(null), isFalse);
    });

    // Valorisation réservée aussi (décision du pharmacien, 3.1.0) : nouvelle interface seulement.
    const nouveaux = ['Valorisation', 'Alertes', 'Retraits et abandons', 'Ventes modifiées'];

    Future<List<String>> titres() async {
      final reglages = HomeSettingsProvider();
      await reglages.loadSettings();
      return [for (final m in menusVisibles(reglages)) m.titre];
    }

    test('menus : les nouveaux et la Valorisation seulement pour le responsable (nouvelle interface)', () async {
      ProfilAcces.utilisateur.value = utilisateur('dashboard');
      expect(await titres(), containsAll(nouveaux));
      ProfilAcces.utilisateur.value = utilisateur('mainmenumanager');
      final autres = await titres();
      for (final n in nouveaux) {
        expect(autres, isNot(contains(n)), reason: n);
      }
      ProfilAcces.utilisateur.value = null;
      expect(await titres(), isNot(contains('Alertes')));
    });

    test('« Personnaliser l\'accueil » ne propose pas les menus réservés à un compte non autorisé', () {
      ProfilAcces.utilisateur.value = utilisateur('mainmenumanager');
      final proposes = [for (final m in menusAutorises()) m.pourPersonnalisation['title']];
      for (final n in nouveaux) {
        expect(proposes, isNot(contains(n)), reason: n);
      }
      expect(proposes, contains('Suivi Péremption'));
      ProfilAcces.utilisateur.value = utilisateur('dashboard');
      expect([for (final m in menusAutorises()) m.titre], containsAll(nouveaux));
      // 3.11.0 : « Evolution Stock » est dans la Valorisation pour le responsable (seul menu en moins).
      expect(menusAutorises(), hasLength(menusModules.length - 1));
      expect([for (final m in menusAutorises()) m.titre], isNot(contains('Evolution Stock')));
    });

    test('les menus réservés sont marqués « responsables », rangés dans une famille et une question', () {
      for (final n in nouveaux) {
        final m = menusModules.singleWhere((x) => x.titre == n);
        expect(m.responsables, isTrue, reason: n);
      }
      // Vague 2 (3.2.0), 3.11.0 (Balance, Sur-stocks) puis vague 3 (3.4.0), dans l'ordre de la liste.
      expect(menusModules.where((m) => m.responsables).map((m) => m.titre), [
        ...nouveaux,
        'Prévisions', 'Analyse de garde', 'CA emplacement / famille', 'Balance vente / caisse', 'Sur-stocks', 'Pointage BL', 'Avis',
        'Rappels traitement',
      ]);
    });
  });
}
