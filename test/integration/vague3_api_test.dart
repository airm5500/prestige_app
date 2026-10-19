// Intégration de la vague 3 (lib/nouvelle_interface/vague3/donnees_vague3.dart) contre le faux serveur Prestige joint
// en HTTP RÉEL, avec la session de la connexion :
//  - routes, méthodes, paramètres et corps exacts (Pointage BL, Avis, Rappels traitement) ;
//  - succès, success:false (refus métier), interdit:true / « pas accès » / 403 (Droit manquant), 401 (retour à la
//    connexion), 500, délai borné (45 s en lecture, 20 s en écriture), serveur arrêté ;
//  - saisies refusées AVANT envoi (séquence, avoir, note interne, statut, sélection) : aucune requête ;
//  - AUCUNE route d'envoi, de réglages ou d'actualisation jamais appelée (requetesInterditesVague3) ;
//  - données des clients et de santé jamais écrites dans le journal.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/providers/auth_provider.dart';
import 'package:prestige_app/providers/licence_provider.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';

import '../outils/contexte_api.dart';
import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';

final serveur = FauxServeurPrestige();

typedef App = ({BuildContext ctx, AuthProvider auth});

Future<App> connecte(WidgetTester tester) async {
  final auth = AuthProvider();
  final ctx = await monterAvecProviders(tester, auth: auth, licence: LicenceProvider());
  await tester.runAsync(() => auth.login(ctx, DonneesFictives.identifiant, DonneesFictives.motDePasse, false));
  await tester.pump();
  expect(auth.isLoggedIn, isTrue);
  serveur.oublierRequetes();
  return (ctx: ctx, auth: auth);
}

Future<(T?, Object?)> essayer<T>(WidgetTester tester, Future<T> Function() appel) async {
  T? r;
  Object? e;
  await tester.runAsync(() async {
    try {
      r = await appel();
    } catch (x) {
      e = x;
    }
  });
  await tester.pump();
  return (r, e);
}

TypeMatcher<ApiLoadException> nature(NatureErreur n) => isA<ApiLoadException>().having((e) => e.nature, 'nature', n);

final debut = DateTime(2026, 10, 1), fin = DateTime(2026, 10, 14);
FiltresPointage get filtres => FiltresPointage(grossiste: DonneesVague3.grossiste, debut: debut, fin: fin);

Future<PieceBl> piece(WidgetTester tester, App app, String cle) async {
  final (l, _) = await essayer(tester, () => ApiPointage.liste(app.ctx, filtres));
  return l!.pieces.firstWhere((p) => p.cle == cle);
}

void main() {
  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerTelephone(serveur, nouvelle: true);
    listesCommunesVague1(serveur);
    await ApiService().clearSessionCookie();
  });

  tearDown(() async {
    expect(requetesInterditesVague3(serveur), isEmpty, reason: 'aucune route d\'envoi, de réglages ni d\'actualisation');
    // 3.8.0 : l'actualisation est autorisée à la demande seulement ; aucun test de ce fichier ne la demande.
    expect(actualisationsRecues(serveur), isEmpty, reason: 'aucune actualisation');
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..reponseSansSession = ((_) => ReponseFausse.sessionExpiree())
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
  });

  group('Pointage BL', () {
    testWidgets('listes, liste (paramètres exacts, session), totaux ; groupe envoyé sans grossiste ; critère manquant refusé sans requête',
        (tester) async {
      final app = await connecte(tester);
      final (g, _) = await essayer(tester, () => ApiPointage.grossistes(app.ctx));
      expect(g!.map((o) => o.id), ['GRO-TEST-1', 'GRO-TEST-2'], reason: '« Tous » (ALL) retiré');
      final (gr, _) = await essayer(tester, () => ApiPointage.groupes(app.ctx));
      expect(gr!.first.libelle, 'GROUPE FICTIF');
      final (l, _) = await essayer(tester, () => ApiPointage.liste(app.ctx, filtres));
      expect(l!.pieces, hasLength(5));
      expect((l.pointes, l.nonPointes), (1, 3));
      final r = serveur.recues(ApiPointage.route).single;
      expect(r.methode, 'GET');
      expect(r.sessionEnvoyee, serveur.derniereSession);
      expect(r.parametres, {'grossiste': 'GRO-TEST-1', 'groupe': '', 'du': '2026-10-01', 'au': '2026-10-14', 'etat': 'TOUS'});
      await essayer(tester, () => ApiPointage.liste(app.ctx, filtres.copie(grossiste: '', groupe: DonneesVague3.groupe, etat: EtatPointage.nonPointes)));
      expect(serveur.recues(ApiPointage.route).last.parametres, containsPair('groupe', 'GRP-TEST-1'));
      expect(serveur.recues(ApiPointage.route).last.parametres['etat'], 'NON_POINTES');
      final avant = serveur.requetes.length;
      final (_, e) = await essayer(tester, () => ApiPointage.liste(app.ctx, filtres.copie(grossiste: '')));
      expect(e, nature(NatureErreur.refus));
      expect(serveur.requetes, hasLength(avant));
    });

    testWidgets('pointer / dépointer : PUT /pointage-bl/pointer/{type}/{id}?pointe= ; la relecture le montre', (tester) async {
      final app = await connecte(tester);
      final bl = await piece(tester, app, 'BL:BL-TEST-1');
      await essayer(tester, () => ApiPointage.pointer(app.ctx, bl, true));
      final r = serveur.recues('/pointage-bl/pointer/BL/BL-TEST-1').single;
      expect(r.methode, 'PUT');
      expect(r.parametres, {'pointe': 'true'});
      expect((await piece(tester, app, 'BL:BL-TEST-1')).pointe, isTrue);
      final retour = await piece(tester, app, 'RETOUR:RET-TEST-1');
      await essayer(tester, () => ApiPointage.pointer(app.ctx, retour, true));
      expect(serveur.recues('/pointage-bl/pointer/RETOUR/RET-TEST-1').single.methode, 'PUT');
      await essayer(tester, () => ApiPointage.pointer(app.ctx, bl, false));
      expect(serveur.recues('/pointage-bl/pointer/BL/BL-TEST-1').last.parametres['pointe'], 'false');
      expect((await piece(tester, app, 'BL:BL-TEST-1')).pointe, isFalse);
    });

    testWidgets('pièce non pointable (manquants) : refusée sans requête', (tester) async {
      final app = await connecte(tester);
      final reception = await piece(tester, app, 'RECEPTION:BL-TEST-1');
      final avant = serveur.requetes.length;
      final (_, e) = await essayer(tester, () => ApiPointage.pointer(app.ctx, reception, true));
      expect(e, nature(NatureErreur.refus));
      final (_, e2) = await essayer(tester, () => ApiPointage.sequence(app.ctx, reception, 'S1'));
      expect(e2, nature(NatureErreur.refus));
      expect(serveur.requetes, hasLength(avant));
    });

    testWidgets('séquence et avoir : valeur nettoyée envoyée ; saisie invalide refusée SANS requête ; refus du serveur = message', (tester) async {
      final app = await connecte(tester);
      final bl = await piece(tester, app, 'BL:BL-TEST-3');
      await essayer(tester, () => ApiPointage.sequence(app.ctx, bl, '  S-2026/7 '));
      expect(serveur.recues('/pointage-bl/sequence/BL-TEST-3').single.parametres, {'valeur': 'S-2026/7'});
      final avant = serveur.requetes.length;
      for (final ko in ['S#1', '123456789012345678901']) {
        final (_, e) = await essayer(tester, () => ApiPointage.sequence(app.ctx, bl, ko));
        expect(e, nature(NatureErreur.refus).having((x) => x.message, 'message', ControlePointage.messageSequence));
      }
      final retour = await piece(tester, app, 'RETOUR:RET-TEST-1');
      final (_, e) = await essayer(tester, () => ApiPointage.referenceAvoir(app.ctx, retour, 'A' * 41));
      expect(e, nature(NatureErreur.refus));
      expect(serveur.requetes.length, avant + 1, reason: 'seule la relecture de la liste est partie');
      await essayer(tester, () => ApiPointage.referenceAvoir(app.ctx, retour, 'VRI 683562 2'));
      expect(serveur.recues('/pointage-bl/avoir/RET-TEST-1').single.parametres['valeur'], 'VRI 683562 2');
      // Le serveur refuse (pièce disparue entre-temps) : demande refusée avec son message.
      serveur.quand('/pointage-bl/sequence/BL-TEST-3', ReponseFausse.json({'success': false, 'msg': 'BL introuvable.'}), methode: 'PUT');
      final (_, e3) = await essayer(tester, () => ApiPointage.sequence(app.ctx, bl, 'S9'));
      expect(e3, nature(NatureErreur.refus).having((x) => x.message, 'message', 'BL introuvable.'));
    });

    testWidgets('droit manquant (interdit:true) en lecture et en écriture ; 500 ; 401 → connexion', (tester) async {
      final app = await connecte(tester);
      final bl = await piece(tester, app, 'BL:BL-TEST-3');
      const refus = {'success': false, 'msg': 'Vous n\'avez pas le droit d\'accéder au pointage des BL.', 'interdit': true};
      serveur.quand(ApiPointage.route, ReponseFausse.json(refus), methode: 'GET');
      final (_, e) = await essayer(tester, () => ApiPointage.liste(app.ctx, filtres));
      expect(e, nature(NatureErreur.droit).having((x) => x.message, 'message', startsWith('Droit manquant : consulter le pointage des BL.')));
      serveur.quand('/pointage-bl/pointer/BL/BL-TEST-3', ReponseFausse.json(refus), methode: 'PUT');
      final (_, e2) = await essayer(tester, () => ApiPointage.pointer(app.ctx, bl, true));
      expect(e2, nature(NatureErreur.droit).having((x) => x.message, 'message', startsWith('Droit manquant : pointer les BL.')));
      serveur.quand('/pointage-bl/pointer/BL/BL-TEST-3', ReponseFausse.erreurServeur(), methode: 'PUT');
      final (_, e3) = await essayer(tester, () => ApiPointage.pointer(app.ctx, bl, true));
      expect(e3, nature(NatureErreur.serveur));
      expect('$e3', isNot(contains('NullPointer')));
      serveur.expirerSessions();
      final (_, e4) = await essayer(tester, () => ApiPointage.pointer(app.ctx, bl, true));
      expect(e4, nature(NatureErreur.session));
      expect(app.auth.isLoggedIn, isFalse);
    });

    testWidgets('écriture sans réponse : délai borné (20 s) ; serveur arrêté : injoignable', (tester) async {
      final app = await connecte(tester);
      final bl = await piece(tester, app, 'BL:BL-TEST-3');
      serveur.quand('/pointage-bl/pointer/BL/BL-TEST-3', ReponseFausse.sansReponse(), methode: 'PUT');
      Object? erreur;
      () async {
        try {
          await ApiPointage.pointer(app.ctx, bl, true);
        } catch (e) {
          erreur = e;
        }
      }();
      await stabiliser(tester, tours: 4);
      await tester.pump(ApiService.delaiPost + const Duration(seconds: 1));
      await stabiliser(tester, tours: 4);
      expect(erreur, nature(NatureErreur.delai));
      await tester.runAsync(serveur.arreter);
      final (_, e) = await essayer(tester, () => ApiPointage.pointer(app.ctx, bl, true));
      expect(e, nature(NatureErreur.reseau));
    });
  });

  group('Avis', () {
    testWidgets('droits, liste (paramètres exacts, page 2 start=50), analyse : AUCUN détail demandé', (tester) async {
      final app = await connecte(tester);
      final (d, _) = await essayer(tester, () => ApiAvis.droits(app.ctx));
      expect(d!.repondre, isTrue);
      final f = FiltresAvis.parDefaut(DateTime(2026, 10, 14));
      final (p, _) = await essayer(tester, () => ApiAvis.liste(app.ctx, f));
      expect(p!.lignes, hasLength(50));
      expect(p.total, DonneesVague3.nombreAvis);
      expect(serveur.recues(ApiAvis.routeListe).single.parametres['limit'], '50');
      final (p2, _) = await essayer(tester, () => ApiAvis.liste(app.ctx, f, start: 50));
      expect(p2!.lignes, hasLength(10));
      expect(serveur.recues(ApiAvis.routeListe).last.parametres['start'], '50');
      final (a, _) = await essayer(tester, () => ApiAvis.analyse(app.ctx, f.debut, f.fin));
      expect(a!.synthese.nombre, 60);
      expect(serveur.recues(ApiAvis.routeAnalyse).single.parametres, {'du': '2026-09-15', 'au': '2026-10-14'});
      expect(detailsAvisDemandes(serveur), isEmpty, reason: 'lire la liste ou l\'analyse ne marque aucun avis « lu »');
      expect(etatVague3.avis.where((x) => x['statut'] == 'NOUVEAU'), hasLength(3));
    });

    testWidgets('ouvrir un avis (appel explicite) : GET /avis-clients/avis/{id}, le serveur le passe LU', (tester) async {
      final app = await connecte(tester);
      final (a, _) = await essayer(tester, () => ApiAvis.ouvrir(app.ctx, 'AVIS-TEST-1'));
      expect(a!.statut, StatutAvis.lu);
      expect(a.memeAppareil, 1);
      expect(detailsAvisDemandes(serveur).single.chemin, '/avis-clients/avis/AVIS-TEST-1');
      serveur.quand('/avis-clients/avis/AVIS-TEST-2', ReponseFausse.json({'success': false, 'msg': 'Avis introuvable.'}), methode: 'GET');
      final (_, e) = await essayer(tester, () => ApiAvis.ouvrir(app.ctx, 'AVIS-TEST-2'));
      expect(e, nature(NatureErreur.refus).having((x) => x.message, 'message', 'Avis introuvable.'));
    });

    testWidgets('traiter : POST {statut, noteInterne nettoyée} ; note trop longue refusée sans requête ; droit manquant', (tester) async {
      final app = await connecte(tester);
      final (a, _) = await essayer(tester, () => ApiAvis.traiter(app.ctx, 'AVIS-TEST-2', StatutAvis.traite, '  Rappelé <i>par</i> téléphone  '));
      expect(a!.statut, StatutAvis.traite);
      final r = serveur.recues(ApiAvis.routeTraiter('AVIS-TEST-2')).single;
      expect(r.methode, 'POST');
      expect(r.json, {'statut': 'TRAITE', 'noteInterne': 'Rappelé par téléphone'});
      final avant = serveur.requetes.length;
      final (_, e) = await essayer(tester, () => ApiAvis.traiter(app.ctx, 'AVIS-TEST-2', StatutAvis.lu, 'x' * 1501));
      expect(e, nature(NatureErreur.refus));
      expect(serveur.requetes, hasLength(avant));
      serveur.quand(ApiAvis.routeTraiter('AVIS-TEST-2'),
          ReponseFausse.json({'success': false, 'msg': 'Vous n\'avez pas le droit d\'effectuer cette action.', 'interdit': true}), methode: 'POST');
      final (_, e2) = await essayer(tester, () => ApiAvis.traiter(app.ctx, 'AVIS-TEST-2', StatutAvis.lu, ''));
      expect(e2, nature(NatureErreur.droit).having((x) => x.message, 'message', startsWith('Droit manquant : traiter les avis clients.')));
    });

    testWidgets('lecture refusée (interdit:true), 403, 500, délai 45 s', (tester) async {
      final app = await connecte(tester);
      serveur.quand(ApiAvis.routeDroits,
          ReponseFausse.json({'success': false, 'msg': 'Vous n\'avez pas le droit d\'effectuer cette action.', 'interdit': true}), methode: 'GET');
      final (_, e) = await essayer(tester, () => ApiAvis.droits(app.ctx));
      expect(e, nature(NatureErreur.droit).having((x) => x.message, 'message', startsWith('Droit manquant : consulter les avis clients.')));
      serveur.quand(ApiAvis.routeListe, ReponseFausse.json({'success': false}, statut: 403), methode: 'GET');
      final (_, e2) = await essayer(tester, () => ApiAvis.liste(app.ctx, FiltresAvis.parDefaut(DateTime(2026, 10, 14))));
      expect(e2, nature(NatureErreur.droit).having((x) => x.message, 'message', startsWith('Droit manquant')));
      serveur.quand(ApiAvis.routeAnalyse, ReponseFausse.erreurServeur(), methode: 'GET');
      final (_, e3) = await essayer(tester, () => ApiAvis.analyse(app.ctx, debut, fin));
      expect(e3, nature(NatureErreur.serveur));
      serveur.quand(ApiAvis.routeAnalyse, ReponseFausse.sansReponse(), methode: 'GET');
      Object? erreur;
      () async {
        try {
          await ApiAvis.analyse(app.ctx, debut, fin);
        } catch (x) {
          erreur = x;
        }
      }();
      await stabiliser(tester, tours: 4);
      await tester.pump(ApiService.delaiGet + const Duration(seconds: 1));
      await stabiliser(tester, tours: 4);
      expect(erreur, nature(NatureErreur.delai));
    });
  });

  group('Rappels traitement', () {
    testWidgets('liste (À préparer par défaut, non paginée), compteur, analyse 6 mois', (tester) async {
      final app = await connecte(tester);
      final now = DateTime(2026, 10, 14);
      final (l, _) = await essayer(tester, () => ApiRappels.liste(app.ctx, const FiltresRappels(), now));
      expect(l, hasLength(25));
      expect(serveur.recues(ApiRappels.routeListe).single.parametres, {'statut': 'A_PREPARER', 'query': '', 'dtStart': '', 'dtEnd': ''});
      final (n, _) = await essayer(tester, () => ApiRappels.compteur(app.ctx));
      expect(n, 25);
      final (d, f) = DureeAnalyseRappels.sixMois.bornes(now);
      final (a, _) = await essayer(tester, () => ApiRappels.analyse(app.ctx, d, f));
      expect(a!.total.total, 120);
      expect(serveur.recues(ApiRappels.routeAnalyse).single.parametres, {'dtStart': '2026-05-01', 'dtEnd': '2026-10-14'});
    });

    testWidgets('marquer : POST ?statut= {ids} une fois ; « Racheté » envoyé (3.14.0) ; sélection vide refusée sans requête', (tester) async {
      final app = await connecte(tester);
      final (n, _) = await essayer(tester, () => ApiRappels.marquer(app.ctx, ['RAP-TEST-1', 'RAP-TEST-2', 'RAP-TEST-1'], StatutRappel.prepare));
      expect(n, 2);
      final r = serveur.recues(ApiRappels.routeMarquer).single;
      expect(r.methode, 'POST');
      expect(r.parametres, {'statut': 'PREPARE'});
      expect(r.json, {'ids': ['RAP-TEST-1', 'RAP-TEST-2']});
      expect(etatVague3.rappels.first['statut'], 'PREPARE');
      // 3.14.0 : « Racheté » se marque à la main (serveur du 19/10/2026).
      final (n2, _) = await essayer(tester, () => ApiRappels.marquer(app.ctx, ['RAP-TEST-3'], StatutRappel.achete));
      expect(n2, 1);
      expect(serveur.recues(ApiRappels.routeMarquer).last.parametres, {'statut': 'ACHETE'});
      expect(etatVague3.rappels.firstWhere((x) => x['id'] == 'RAP-TEST-3')['statut'], 'ACHETE');
      // Serveur plus ancien : refus « Statut inconnu. » traduit en message clair.
      etatVague3.serveurAncienRappels = true;
      final (_, e) = await essayer(tester, () => ApiRappels.marquer(app.ctx, ['RAP-TEST-4'], StatutRappel.achete));
      expect(e, isA<ApiLoadException>().having((x) => x.message, 'message', StatutRappel.messageServeurAncien));
      final avant = serveur.requetes.length;
      final (_, e2) = await essayer(tester, () => ApiRappels.marquer(app.ctx, const [], StatutRappel.ecarte));
      expect(e2, nature(NatureErreur.refus));
      expect(serveur.requetes, hasLength(avant));
    });

    testWidgets('« Vous n\'avez pas accès aux rappels » → Droit manquant ; 500 ; 401', (tester) async {
      final app = await connecte(tester);
      const refus = {'success': false, 'msg': 'Vous n\'avez pas accès aux rappels de traitement.', 'message': 'Vous n\'avez pas accès aux rappels de traitement.'};
      serveur.quand(ApiRappels.routeListe, ReponseFausse.json(refus), methode: 'GET');
      final (_, e) = await essayer(tester, () => ApiRappels.liste(app.ctx, const FiltresRappels(), DateTime(2026, 10, 14)));
      expect(e, nature(NatureErreur.droit).having((x) => x.message, 'message', startsWith('Droit manquant : consulter les rappels de traitement.')));
      serveur.quand(ApiRappels.routeMarquer, ReponseFausse.json(refus), methode: 'POST');
      final (_, e2) = await essayer(tester, () => ApiRappels.marquer(app.ctx, ['RAP-TEST-1'], StatutRappel.ecarte));
      expect(e2, nature(NatureErreur.droit).having((x) => x.message, 'message', startsWith('Droit manquant : marquer les rappels de traitement.')));
      serveur.quand(ApiRappels.routeMarquer, ReponseFausse.erreurServeur(), methode: 'POST');
      final (_, e3) = await essayer(tester, () => ApiRappels.marquer(app.ctx, ['RAP-TEST-1'], StatutRappel.ecarte));
      expect(e3, nature(NatureErreur.serveur));
      serveur.expirerSessions();
      final (_, e4) = await essayer(tester, () => ApiRappels.compteur(app.ctx));
      expect(e4, nature(NatureErreur.session));
      expect(app.auth.isLoggedIn, isFalse);
    });
  });

  group('Routes interdites et journal', () {
    testWidgets('appel direct d\'une route interdite : refusé AVANT envoi', (tester) async {
      final app = await connecte(tester);
      // 3.8.0 (C2) : « /rappels-habitude/actualiser » retirée de cette liste (autorisée à la demande, voir
      // integration/retours_3_8_0_test.dart) ; les envois et les secrets restent refusés avant envoi.
      for (final r in ['/rappels-habitude/envoyer', '/rappels-habitude/sms', '/avis-clients/avis/AVIS-TEST-1/repondre', '/avis-clients/reglages/regenerer']) {
        final (_, e) = await essayer(tester, () => ApiVague3.post(app.ctx, r, const {}, 'x'));
        expect(e, nature(NatureErreur.refus), reason: r);
        final (_, e2) = await essayer(tester, () => ApiVague3.get(app.ctx, r, const {}, 'x'));
        expect(e2, nature(NatureErreur.refus), reason: r);
      }
      expect(serveur.requetes, isEmpty);
    });

    testWidgets('journal : ni nom, ni téléphone, ni e-mail, ni traitement, ni recherche', (tester) async {
      final lignes = <String>[];
      final sortie = JournalApp.sortie, actif = JournalApp.actif;
      JournalApp.sortie = lignes.add;
      JournalApp.actif = true;
      addTearDown(() {
        JournalApp.sortie = sortie;
        JournalApp.actif = actif;
      });
      final app = await connecte(tester);
      final now = DateTime(2026, 10, 14);
      await essayer(tester, () => ApiAvis.liste(app.ctx, FiltresAvis.parDefaut(now).copie(contient: 'CLIENT FICTIF')));
      await essayer(tester, () => ApiAvis.ouvrir(app.ctx, 'AVIS-TEST-1'));
      await essayer(tester, () => ApiAvis.traiter(app.ctx, 'AVIS-TEST-1', StatutAvis.traite, 'Note interne fictive confidentielle'));
      await essayer(tester, () => ApiRappels.liste(app.ctx, const FiltresRappels(recherche: 'PATIENT FICTIF'), now));
      await essayer(tester, () => ApiRappels.marquer(app.ctx, ['RAP-TEST-1'], StatutRappel.prepare));
      final bl = await piece(tester, app, 'BL:BL-TEST-3');
      await essayer(tester, () => ApiPointage.sequence(app.ctx, bl, 'SEQ-SECRETE'));
      expect(lignes, isNotEmpty, reason: 'le journal a bien été capturé');
      final tout = lignes.join('\n');
      for (final interdit in ['CLIENT FICTIF', 'PATIENT FICTIF', '00 00 00', '00 11 22', 'exemple.invalid', 'TRAITEMENT FICTIF', 'confidentielle', 'SEQ-SECRETE', 'query=', 'contient=']) {
        expect(tout, isNot(contains(interdit)), reason: interdit);
      }
    });
  });
}
