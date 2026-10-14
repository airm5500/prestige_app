// Retours du pharmacien appliqués en 3.8.0 : écrans de la NOUVELLE interface contre le faux serveur (client en
// mémoire, horloge simulée, écran très haut pour que toutes les lignes soient construites), paramètres transmis
// vérifiés requête par requête :
//  - A1 Visualisation BL : statut dans « statutControle » (lu par le serveur), « checked » vide, utilisateur plus
//    proposé (userId vide), groupe transmis ; total du serveur après son filtre ;
//  - A3 Suivi Ajustements : pages de 100 (start=0, 100, 200 ; mêmes filtres), serveur sans « total » = 100 premiers
//    et avertissement, page suivante en échec = message et liste gardée ;
//  - B2 Ratios mensuels : 12 derniers mois glissants en UNE requête (période sur deux années), cumul par mois ET
//    année, norme 1,51 ;
//  - B3 Suivi 20/80 : classement par quantité (vingtType=QTY, tri par quantité), retour au chiffre d'affaires =
//    requête d'origine ;
//  - B4 Exports PDF (Stat TVA, Marge, CA Crédit) : chaque chiffre et chaque ligne de l'écran se retrouvent tels quels
//    dans le PDF, filtres repris, aucune requête, rien à exporter sans donnée ;
//  - C2 Rappels : « Actualiser la liste » = confirmation, UN POST /rappels-habitude/actualiser, relecture de la
//    liste et du compteur ; annulation = aucun envoi ; refus « déjà en cours » affiché ; aucun envoi de message ;
//  - C3 Avis : « Remettre en Nouveau » (droit « répondre ») = UN POST traiter {statut: NOUVEAU, note gardée} après
//    confirmation ; absent sans le droit ou pour un avis déjà nouveau.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_pdf.dart';
import 'package:prestige_app/nouvelle_interface/composants.dart';
import 'package:prestige_app/nouvelle_interface/modules/ajustements_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/commun.dart';
import 'package:prestige_app/nouvelle_interface/modules/marge_produits_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/stat_tva_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/suivi_2080_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_ratios_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/visualisation_bl_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/vague3/avis_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/rappels_vague3.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/donnees_lot2.dart';
import '../support/donnees_lot3.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

final serveur = FauxServeurPrestige();

Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
  for (var i = 0; i < fois; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> monter(WidgetTester tester, Widget Function() ecran, {double hauteur = 30000}) async {
  tester.view.devicePixelRatio = 2.625;
  tester.view.physicalSize = Size(411 * 2.625, hauteur * 2.625);
  addTearDown(tester.view.reset);
  preparerTelephone(serveur, nouvelle: true);
  ApiService.client = serveur.clientMemoire();
  serveur.oublierRequetes();
  await ecranConnecte(ecran)(tester, serveur);
  await pomper(tester);
}

Future<void> demonter(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 2));
}

Future<void> toucher(WidgetTester tester, Finder f, [int fois = 8]) async {
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(f.first);
  await pomper(tester, fois);
}

Future<void> filtrer(WidgetTester tester, Future<void> Function() reglages) async {
  await toucher(tester, find.byKey(const Key('bouton_filtres')), 6);
  await reglages();
  await toucher(tester, find.byKey(const Key('filtres_appliquer')));
}

Future<void> choisirDansListe(WidgetTester tester, Finder liste, String option) async {
  await toucher(tester, liste, 5);
  await tester.tap(find.text(option).hitTestable().last);
  await pomper(tester, 8);
}

String chiffre(String id) => (find.byKey(Key('chiffre_$id')).evaluate().single.widget as Text).data!;

List<(String, String)> chiffres() => [
      for (final e in find.byType(ChiffreCle).evaluate()) ((e.widget as ChiffreCle).libelle, (e.widget as ChiffreCle).valeur),
    ];

int cartes() => find.byType(CarteLigne).evaluate().length;

List<Map<String, String>> params(String route) => [for (final r in serveur.recues(route)) r.parametres];

/// Ajustements fictifs paginés comme le serveur (start / limit, « total ») ; [avecTotal] = false : serveur sans total.
ReponseFausse ajustementsPour(RequeteRecue r, {required int nombre, bool avecTotal = true}) {
  final start = int.tryParse(r.parametres['start'] ?? '0') ?? 0, limit = int.tryParse(r.parametres['limit'] ?? '100') ?? 100;
  final fin = (start + limit).clamp(0, nombre);
  return ReponseFausse.json({
    'data': [
      for (var i = start + 1; i <= fin; i++)
        {'lgAJUSTEMENTID': 'AJU-$i', 'description': 'AJUSTEMENT FICTIF N$i', 'userFullName': 'EMPLOYE Fictif ${i % 3}', 'dtUPDATED': '13/10/2026', 'heure': '10:15'},
    ],
    if (avecTotal) 'total': nombre,
  });
}

/// Capture des PDF produits (aucun dialogue du système en test).
List<(ContenuAnalysePdf, String)> capturerPdf() {
  final sorties = <(ContenuAnalysePdf, String)>[];
  final avant = AnalysesPdf.sortie;
  AnalysesPdf.sortie = (c, nom) async => sorties.add((c, nom));
  addTearDown(() => AnalysesPdf.sortie = avant);
  return sorties;
}

String jour(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);

  setUp(() {
    serveur
      ..installerRoutesParDefaut()
      ..coupe = false;
    donneesLot2(serveur);
    donneesLot3(serveur);
  });

  group('A1 · Visualisation BL : filtre de statut lu par le serveur', () {
    const route = '/etat-control-bon/list';

    testWidgets('ouverture : requête d\'origine (sans statutControle) ; « Contrôlés » → statutControle=CONTROLE, checked vide',
        (tester) async {
      await monter(tester, () => const VisualisationBlNouveau());
      expect(params(route).single.containsKey('statutControle'), isFalse, reason: 'sans filtre : requête inchangée');
      expect(params(route).single, containsPair('checked', ''));
      expect(chiffre('total_bl'), '${DonneesLot2.bonsLivraison}');

      await filtrer(tester, () async {
        expect(find.byKey(const Key('filtre_utilisateur')), findsNothing);
        expect(find.text('Filtre par utilisateur : proposé quand le serveur Prestige le prendra en compte.'), findsOneWidget);
        expect(find.byKey(const Key('filtre_statut_TERMINE')), findsNothing, reason: 'anciens statuts (ignorés) plus proposés');
        await toucher(tester, find.byKey(const Key('filtre_statut_CONTROLE')), 3);
      });
      final p = params(route).last;
      expect(p, containsPair('statutControle', 'CONTROLE'));
      expect(p, containsPair('checked', ''));
      expect(p, containsPair('userId', ''));
      expect(chiffre('total_bl'), '7', reason: '7 bons TERMINE sur 23 (filtre du serveur, total juste)');
      expect(find.text('Contrôle : Contrôlés'), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('« Non contrôlés » + groupe : statutControle=NON_CONTROLE et groupeId transmis ; retrait = requête d\'origine',
        (tester) async {
      await monter(tester, () => const VisualisationBlNouveau());
      final ouverture = params(route).single;
      await filtrer(tester, () async {
        await toucher(tester, find.byKey(const Key('filtre_statut_NON_CONTROLE')), 3);
        await choisirDansListe(tester, find.byKey(const Key('filtre_groupe')), 'GROUPE FICTIF B');
      });
      final p = params(route).last;
      expect(p, containsPair('statutControle', 'NON_CONTROLE'));
      expect(p, containsPair('groupeId', '2'));
      expect(chiffre('total_bl'), '16');
      await toucher(tester, find.byKey(const Key('filtres_retirer')));
      expect(params(route).last, ouverture, reason: 'filtres retirés : exactement la requête d\'ouverture');
      await demonter(tester);
    });
  });

  group('A3 · Suivi Ajustements : « Afficher plus » au-delà de 100', () {
    const route = AppConstants.ajustementEndpoint;

    testWidgets('serveur qui pagine : 100, puis 200 (start=100, mêmes filtres), puis 230 ; plus rien ensuite', (tester) async {
      serveur.route(route, (r) => ajustementsPour(r, nombre: 230), methode: 'GET');
      await monter(tester, () => const AjustementsNouveau());
      expect(params(route).single, {
        'dtStart': jour(DateTime.now()),
        'dtEnd': jour(DateTime.now()),
        'typeFiltre': '',
        'page': '1',
        'start': '0',
        'limit': '100',
      }, reason: 'première page = requête d\'origine');
      expect(cartes(), 100);
      expect(chiffre('ajustements'), '230');
      expect(find.text('100 lignes affichées sur 230'), findsOneWidget);
      expect(find.text('Afficher plus (130)'), findsOneWidget);

      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      final l = params(route);
      expect(l, hasLength(2));
      expect(l[1], {...l[0], 'page': '2', 'start': '100'}, reason: 'mêmes filtres, page suivante');
      expect(cartes(), 200);
      expect(find.text('AJUSTEMENT FICTIF N101'), findsOneWidget);

      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(params(route).last, containsPair('start', '200'));
      expect(cartes(), 230);
      expect(find.byKey(const Key('bouton_afficher_plus')), findsNothing);
      expect(find.text('230 lignes affichées sur 230'), findsOneWidget);
      expect(params(route), hasLength(3), reason: 'aucune requête de trop');
      await demonter(tester);
    });

    testWidgets('filtre motif puis page suivante : le motif est repris ; changer de filtre repart de la première page', (tester) async {
      serveur.route(route, (r) => ajustementsPour(r, nombre: 150), methode: 'GET');
      await monter(tester, () => const AjustementsNouveau());
      await filtrer(tester, () => choisirDansListe(tester, find.byKey(const Key('filtre_motif')), 'CASSE'));
      expect(params(route).last, containsPair('typeFiltre', 'TYP-CASSE'));
      expect(params(route).last, containsPair('start', '0'));
      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(params(route).last, containsPair('typeFiltre', 'TYP-CASSE'));
      expect(params(route).last, containsPair('start', '100'));
      expect(cartes(), 150);
      await demonter(tester);
    });

    testWidgets('serveur SANS total : les 100 premiers comme avant, avertissement, aucune autre requête', (tester) async {
      serveur.route(route, (r) => ajustementsPour(r, nombre: 230, avecTotal: false), methode: 'GET');
      await monter(tester, () => const AjustementsNouveau());
      expect(cartes(), 100);
      expect(find.byKey(const Key('ajustements_limite')), findsOneWidget);
      expect(find.byKey(const Key('bouton_afficher_plus')), findsNothing);
      expect(params(route), hasLength(1));
      await demonter(tester);
    });

    testWidgets('page suivante en échec : message, ajustements gardés, « Afficher plus » de nouveau possible', (tester) async {
      serveur.route(
          route,
          (r) => r.parametres['start'] == '100' && serveur.recues(route).length == 2
              ? ReponseFausse.erreurServeur()
              : ajustementsPour(r, nombre: 130),
          methode: 'GET');
      await monter(tester, () => const AjustementsNouveau());
      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(cartes(), 100);
      expect(find.byType(SnackBar), findsOneWidget);
      await pomper(tester, 50);
      await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
      expect(cartes(), 130);
      await demonter(tester);
    });

    testWidgets('100 ajustements ou moins : écran comme avant (pas de pied de pagination)', (tester) async {
      await monter(tester, () => const AjustementsNouveau());
      expect(chiffre('ajustements'), '2');
      expect(find.byType(PiedPagination), findsNothing);
      await demonter(tester);
    });
  });

  group('B2 · Ratios mensuels : 12 derniers mois glissants', () {
    testWidgets('UNE requête du 1er du mois d\'il y a 11 mois à aujourd\'hui ; mois de deux années distincts', (tester) async {
      serveur.quand(
          AppConstants.tableauBordAchatsVentesEndpoint,
          ReponseFausse.json([
            // Même mois (octobre) sur deux années : ne doivent pas se confondre.
            {'dateMvt': '15/10/2025', 'montantAchat': 100000, 'montantVente': 120000},
            {'dateMvt': '20/11/2025', 'montantAchat': 100000, 'montantVente': 160000},
            {'dateMvt': '03/01/2026', 'montantAchat': 200000, 'montantVente': 300000},
            {'dateMvt': '05/10/2026', 'montantAchat': 100000, 'montantVente': 151000},
          ]),
          methode: 'GET');
      await monter(tester, () => RatiosMensuelsNouveau(maintenant: () => DateTime(2026, 10, 14)));
      expect(params(AppConstants.tableauBordAchatsVentesEndpoint).single, {'dtStart': '2025-11-01', 'dtEnd': '2026-10-14'},
          reason: 'période à cheval sur deux années, une seule requête');
      expect(find.text('Ratios des 12 derniers mois'), findsOneWidget);
      expect(find.text('Du 01/11/2025 à aujourd\'hui (12 mois glissants)'), findsOneWidget);
      final titres = [for (final e in find.byType(CarteLigne).evaluate()) (e.widget as CarteLigne).titre];
      expect(titres, ['Octobre 2025', 'Novembre 2025', 'Janvier 2026', 'Octobre 2026'], reason: 'ordre chronologique, mois ET année');
      expect(chiffre('mois_norme'), '2 / 4', reason: '1,20 et 1,50 sous la norme 1,51 ; 1,60 et 1,51 conformes');
      await demonter(tester);
    });
  });

  group('B3 · Suivi 20/80 : classement par quantité', () {
    const route = AppConstants.suivi2080Endpoint;

    testWidgets('défaut chiffre d\'affaires (requête d\'origine) ; « Quantité » → vingtType=QTY, tri par quantité ; retour CA',
        (tester) async {
      serveur.route(route, (r) {
        // Le serveur classe lui-même par quantité avec vingtType=QTY ; l'ordre CA met la quantité dans le désordre.
        final qty = r.parametres['vingtType'] == 'QTY';
        final l = [
          {'intCIP': 'C1', 'strNAME': 'ARTICLE FORT CA', 'intPRICE': 500000, 'intQUANTITY': 10, 'intQUANTITYSERVED': 3},
          {'intCIP': 'C2', 'strNAME': 'ARTICLE MOYEN', 'intPRICE': 300000, 'intQUANTITY': 400, 'intQUANTITYSERVED': 3},
          {'intCIP': 'C3', 'strNAME': 'ARTICLE FORTE QTE', 'intPRICE': 100000, 'intQUANTITY': 900, 'intQUANTITYSERVED': 3},
        ];
        return ReponseFausse.json({'data': qty ? l.reversed.toList() : l, 'total': 3});
      }, methode: 'GET');
      await monter(tester, () => const Suivi2080Nouveau());
      final ouverture = params(route).single;
      expect(ouverture.containsKey('vingtType'), isFalse, reason: 'chiffre d\'affaires : requête inchangée');
      expect(ouverture, containsPair('qtyOrCa', 'false'));
      List<String> titres() => [for (final e in find.byType(CarteLigne).evaluate()) (e.widget as CarteLigne).titre];
      expect(titres(), ['1. ARTICLE FORT CA', '2. ARTICLE MOYEN', '3. ARTICLE FORTE QTE']);

      await toucher(tester, find.byKey(const Key('classement_quantite')));
      expect(params(route).last, {...ouverture, 'vingtType': 'QTY'});
      expect(titres(), ['1. ARTICLE FORTE QTE', '2. ARTICLE MOYEN', '3. ARTICLE FORT CA']);
      expect(find.text('ARTICLES (PAR QUANTITÉ VENDUE)'), findsOneWidget);
      expect(chiffre('quantite'), formaterNombre(1310));
      expect(chiffre('montant'), formaterMontant(900000), reason: 'mêmes totaux');

      await toucher(tester, find.byKey(const Key('classement_chiffreAffaires')));
      expect(params(route).last, ouverture, reason: 'retour au chiffre d\'affaires : requête d\'origine');
      expect(params(route), hasLength(3));
      await demonter(tester);
    });

    testWidgets('serveur qui ignorerait vingtType : l\'application trie elle-même par quantité', (tester) async {
      await monter(tester, () => const Suivi2080Nouveau());
      // Données par défaut : rendues dans l'ordre du chiffre d'affaires quel que soit vingtType.
      await toucher(tester, find.byKey(const Key('classement_quantite')));
      final q = [
        for (final e in find.byType(CarteLigne).evaluate()) int.parse((e.widget as CarteLigne).valeur!.replaceAll(RegExp(r'\D'), '')),
      ];
      expect(q, isNotEmpty);
      for (var i = 1; i < q.length; i++) {
        expect(q[i] <= q[i - 1], isTrue, reason: 'quantités décroissantes');
      }
      await demonter(tester);
    });
  });

  group('B4 · Exports PDF (Stat TVA, Marge, CA Crédit) : textes identiques à l\'écran', () {
    testWidgets('Stat TVA : chiffres, lignes et total de l\'écran dans le PDF ; type de vente repris ; aucune requête', (tester) async {
      final sorties = capturerPdf();
      await monter(tester, () => const StatTvaNouveau());
      await filtrer(tester, () => toucher(tester, find.byKey(const Key('filtre_type_vno')), 3));
      final ecran = chiffres();
      final requetes = serveur.requetes.length;
      await toucher(tester, find.byKey(const Key('menu_exports')));
      await toucher(tester, find.text('PDF des statistiques TVA'));
      expect(serveur.requetes, hasLength(requetes), reason: 'export sans requête');
      final (c, nom) = sorties.single;
      expect(nom, 'Stat_TVA_${jour(DateTime.now())}');
      expect(c.titre, 'Statistiques TVA');
      expect(c.chiffres, ecran);
      expect(c.filtres, [('Type de vente', 'Vente Non-Ordonnancée')]);
      final cellules = [for (final e in find.byType(CarteLigne).evaluate()) (e.widget as CarteLigne).valeur];
      expect([for (final l in c.lignes) l[3]], cellules, reason: 'TTC de chaque taux = valeur des cartes');
      expect(c.total!.first, 'Total');
      expect(c.total![3], chiffre('ttc'));
      final pdf = String.fromCharCodes(await AnalysesPdf.octets(c, compresser: false));
      for (final mot in ['Statistiques TVA', pdfTexte(chiffre('ttc')), 'Vente Non-Ordonnanc']) {
        expect(pdf, contains(mot.split(' ').first), reason: mot);
      }
      await demonter(tester);
    });

    testWidgets('Marge : TOUTES les lignes filtrées (au-delà des 50 construites), chiffres et total de l\'écran', (tester) async {
      final sorties = capturerPdf();
      await monter(tester, () => const MargeProduitsNouveau());
      await filtrer(tester, () async {
        await toucher(tester, find.byKey(const Key('filtre_operateur_superieur')), 3);
        await tester.enterText(find.byKey(const Key('filtre_marge')), '40');
        await pomper(tester, 3);
      });
      final ecran = chiffres();
      await toucher(tester, find.byKey(const Key('menu_exports')));
      await toucher(tester, find.text('PDF des marges'));
      final (c, _) = sorties.single;
      expect(c.chiffres.take(4), ecran, reason: 'mêmes chiffres clés, mêmes valeurs');
      expect(c.chiffres.last, ('Produits vendus (sans filtre)', formaterNombre(DonneesLot3.produitsMarge)));
      expect(c.filtres, [('Marge', '> 40 %')]);
      expect(c.lignes, hasLength(24), reason: 'produits retenus par le filtre (24, comme l\'écran)');
      expect(c.total![4], chiffre('marge'));
      await demonter(tester);
    });

    testWidgets('Marge sans filtre : toutes les lignes vendues (plus de 50) dans le PDF', (tester) async {
      final sorties = capturerPdf();
      await monter(tester, () => const MargeProduitsNouveau());
      expect(cartes(), lessThan(DonneesLot3.produitsMarge), reason: '50 construites à l\'écran');
      await toucher(tester, find.byKey(const Key('menu_exports')));
      await toucher(tester, find.text('PDF des marges'));
      expect(sorties.single.$1.lignes, hasLength(DonneesLot3.produitsMarge));
      expect(sorties.single.$1.filtres, isEmpty);
      expect(sorties.single.$1.texte, contains('Filtres : aucun'));
      await demonter(tester);
    });

    testWidgets('CA Crédit : recherche reprise, lignes et total de l\'écran ; rien à exporter sans donnée', (tester) async {
      final sorties = capturerPdf();
      await monter(tester, () => const CaCreditNouveau());
      await tester.enterText(find.byKey(const Key('champ_recherche')), 'beta');
      await pomper(tester, 8);
      final ecran = chiffres();
      final valeurs = [for (final e in find.byType(CarteLigne).evaluate()) (e.widget as CarteLigne).valeur];
      await toucher(tester, find.byKey(const Key('menu_exports')));
      await toucher(tester, find.text('PDF des ventes à crédit'));
      final (c, _) = sorties.single;
      expect(c.chiffres.take(4), ecran, reason: 'mêmes chiffres clés, mêmes valeurs');
      expect(c.filtres, [('Recherche', 'beta')]);
      expect([for (final l in c.lignes) l.last], valeurs);
      expect(c.total!.last, chiffre('montant'));
      await demonter(tester);

      serveur.quand('/ca-credit', ReponseFausse.json(const <Object>[]), methode: 'GET');
      await monter(tester, () => const CaCreditNouveau());
      await toucher(tester, find.byKey(const Key('menu_exports')));
      await toucher(tester, find.text('PDF des ventes à crédit'));
      expect(sorties, hasLength(1), reason: 'aucun PDF sans donnée');
      expect(find.text('Aucune donnée à exporter'), findsOneWidget);
      await demonter(tester);
    });
  });

  group('C2 · Rappels : « Actualiser la liste » à la demande', () {
    testWidgets('confirmation puis UN appel, relecture de la liste et du compteur ; aucun envoi de message', (tester) async {
      await monter(tester, () => const RappelsScreen());
      expect(actualisationsRecues(serveur), isEmpty, reason: 'jamais à l\'ouverture');
      expect(find.text('25 rappels à préparer au total'), findsOneWidget);
      final listes = serveur.recues(ApiRappels.routeListe).length;

      // « Non » : rien n'est envoyé.
      await toucher(tester, find.byKey(const Key('rappels_recalculer')));
      expect(find.textContaining('peut prendre du temps'), findsOneWidget);
      await toucher(tester, find.byKey(const Key('confirmer_non')));
      expect(actualisationsRecues(serveur), isEmpty);

      // « Oui » : un POST (corps vide, sans « jour »), puis relecture.
      await toucher(tester, find.byKey(const Key('rappels_recalculer')));
      await toucher(tester, find.byKey(const Key('confirmer_oui')));
      final a = actualisationsRecues(serveur);
      expect(a, hasLength(1));
      expect(a.single.methode, 'POST');
      expect(a.single.parametres, isEmpty);
      expect(find.text('Liste actualisée : 2 nouveaux rappels, 1 racheté.'), findsOneWidget);
      expect(serveur.recues(ApiRappels.routeListe).length, listes + 1, reason: 'liste relue');
      expect(find.text('27 rappels à préparer au total'), findsOneWidget, reason: 'compteur relu');
      expect(requetesInterditesVague3(serveur), isEmpty, reason: 'aucun envoi');
      await demonter(tester);
    });

    testWidgets('double appui pendant le calcul : un seul appel ; indicateur affiché ; bouton revenu ensuite', (tester) async {
      serveur.route(ApiRappels.routeActualiser, (_) => ReponseFausse.json(resultatActualisation).apres(const Duration(seconds: 8)), methode: 'POST');
      await monter(tester, () => const RappelsScreen());
      await toucher(tester, find.byKey(const Key('rappels_recalculer')));
      await toucher(tester, find.byKey(const Key('confirmer_oui')), 3);
      expect(find.byKey(const Key('rappels_actualisation_en_cours')), findsOneWidget);
      expect(find.byKey(const Key('rappels_recalculer')), findsNothing, reason: 'bouton remplacé : aucun second appel possible');
      expect(tester.widget<IconButton>(find.byKey(const Key('rappels_actualiser'))).onPressed, isNull, reason: 'recharger bloqué');
      await pomper(tester, 100);
      expect(actualisationsRecues(serveur), hasLength(1));
      expect(find.byKey(const Key('rappels_recalculer')), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('refus « déjà en cours » du serveur : message affiché, liste inchangée (pas de relecture)', (tester) async {
      serveur.quand(ApiRappels.routeActualiser,
          ReponseFausse.json({'success': false, 'msg': refusActualisationEnCours, 'message': refusActualisationEnCours}), methode: 'POST');
      await monter(tester, () => const RappelsScreen());
      final listes = serveur.recues(ApiRappels.routeListe).length;
      await toucher(tester, find.byKey(const Key('rappels_recalculer')));
      await toucher(tester, find.byKey(const Key('confirmer_oui')));
      expect(find.text('Liste non actualisée : $refusActualisationEnCours'), findsOneWidget);
      expect(serveur.recues(ApiRappels.routeListe).length, listes);
      expect(find.byKey(const Key('rappels_recalculer')), findsOneWidget);
      await demonter(tester);
    });

    testWidgets('erreur du serveur : message, rien d\'autre', (tester) async {
      serveur.quand(ApiRappels.routeActualiser, ReponseFausse.erreurServeur(), methode: 'POST');
      await monter(tester, () => const RappelsScreen());
      await toucher(tester, find.byKey(const Key('rappels_recalculer')));
      await toucher(tester, find.byKey(const Key('confirmer_oui')));
      expect(find.textContaining('Liste non actualisée'), findsOneWidget);
      expect(actualisationsRecues(serveur), hasLength(1));
      await demonter(tester);
    });
  });

  group('C3 · Avis : « Remettre en Nouveau »', () {
    const droits = DroitsAvis(repondre: true);

    testWidgets('avis traité : confirmation puis UN POST traiter {NOUVEAU, note interne gardée} ; bouton disparu', (tester) async {
      await monter(tester, () => const AvisDetailScreen(id: 'AVIS-TEST-4', droits: droits));
      expect(find.byKey(const Key('avis_remettre_nouveau')), findsOneWidget);
      final route = ApiAvis.routeTraiter('AVIS-TEST-4');

      await toucher(tester, find.byKey(const Key('avis_remettre_nouveau')));
      await toucher(tester, find.byKey(const Key('confirmer_non')));
      expect(serveur.recues(route), isEmpty, reason: '« Non » : rien n\'est envoyé');

      await toucher(tester, find.byKey(const Key('avis_remettre_nouveau')));
      await toucher(tester, find.byKey(const Key('confirmer_oui')));
      final r = serveur.recues(route);
      expect(r, hasLength(1));
      expect(r.single.json, {'statut': 'NOUVEAU', 'noteInterne': 'Client rappelé (fictif).'});
      expect(find.text('Avis remis en « Nouveau ».'), findsOneWidget);
      expect(find.byKey(const Key('avis_remettre_nouveau')), findsNothing, reason: 'avis redevenu nouveau');
      expect(etatVague3.avis[3]['statut'], 'NOUVEAU');
      expect(etatVague3.avis[3]['noteInterne'], 'Client rappelé (fictif).');
      await demonter(tester);
    });

    testWidgets('double appui : un seul envoi', (tester) async {
      serveur.route(ApiAvis.routeTraiter('AVIS-TEST-6'),
          (r) => ReponseFausse.json({'success': true, 'data': {...DonneesVague3.avis(6), 'statut': 'NOUVEAU'}}).apres(const Duration(seconds: 3)),
          methode: 'POST');
      await monter(tester, () => const AvisDetailScreen(id: 'AVIS-TEST-6', droits: droits));
      await toucher(tester, find.byKey(const Key('avis_remettre_nouveau')));
      await toucher(tester, find.byKey(const Key('confirmer_oui')), 2);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('avis_remettre_nouveau'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('avis_remettre_nouveau')), warnIfMissed: false);
      await pomper(tester, 50);
      expect(serveur.recues(ApiAvis.routeTraiter('AVIS-TEST-6')), hasLength(1));
      await demonter(tester);
    });

    testWidgets('sans le droit « répondre » : bouton absent ; avis nouveau ouvert = lu → bouton présent', (tester) async {
      await monter(tester, () => const AvisDetailScreen(id: 'AVIS-TEST-4', droits: DroitsAvis()));
      expect(find.byKey(const Key('avis_remettre_nouveau')), findsNothing);
      await demonter(tester);
      // AVIS-TEST-1 est nouveau ; l'ouvrir le marque lu (serveur) : on peut alors le remettre en Nouveau.
      await monter(tester, () => const AvisDetailScreen(id: 'AVIS-TEST-1', droits: droits));
      expect(find.byKey(const Key('avis_remettre_nouveau')), findsOneWidget);
      await demonter(tester);
    });
  });
}
