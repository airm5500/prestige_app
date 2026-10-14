// Unitaires de la vague 3 (lib/nouvelle_interface/vague3/donnees_vague3.dart) : lecture TOLÉRANTE des réponses
// (pointage, avis, droits, analyse des avis, rappels, analyse des rappels), refus distincts (droit manquant / demande
// refusée / réponse illisible), contrôles des saisies IDENTIQUES au serveur (N° de séquence, référence d'avoir, note
// interne nettoyée comme Texte.libre, période d'un an du pointage, statuts « marquables »), routes interdites (envois,
// réglages, actualisation), paramètres envoyés, menus réservés.
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/donnees_vague3.dart';

TypeMatcher<ApiLoadException> nature(NatureErreur n) => isA<ApiLoadException>().having((e) => e.nature, 'nature', n);

AppUser utilisateur(String type) =>
    AppUser(userId: 'U', firstName: 'Prénom', lastName: 'Nom', login: 'x', officineName: 'Officine', typeUser: type);

void main() {
  group('Réponses : refus et erreurs distincts', () {
    test('succès rendu ; vide → carte vide ; autre chose qu\'un objet → réponse illisible', () {
      expect(lireReponseVague3({'success': true, 'x': 1}, 'a')['x'], 1);
      expect(lireReponseVague3(null, 'a'), isEmpty);
      expect(() => lireReponseVague3([1], 'a'), throwsA(nature(NatureErreur.reponse)));
    });

    test('interdit:true (pointage, avis), « Vous n\'avez pas accès » (rappels), message vide → Droit manquant', () {
      expect(
          () => lireReponseVague3(
              {'success': false, 'msg': 'Vous n\'avez pas le droit d\'accéder au pointage des BL.', 'interdit': true}, 'consulter le pointage des BL'),
          throwsA(nature(NatureErreur.droit).having((e) => e.message, 'message', startsWith('Droit manquant : consulter le pointage des BL.'))));
      expect(() => lireReponseVague3({'success': false, 'msg': 'Vous n\'avez pas accès aux rappels de traitement.'}, 'x'),
          throwsA(nature(NatureErreur.droit)));
      expect(() => lireReponseVague3({'success': false}, 'x'), throwsA(nature(NatureErreur.droit)));
    });

    test('refus métier → demande refusée avec le message du serveur', () {
      for (final m in ['Pièce introuvable.', 'Statut inconnu.', 'Choisissez un grossiste ou un groupe de grossistes.', 'Période trop longue : un an au plus.']) {
        expect(() => lireReponseVague3({'success': false, 'msg': m}, 'x'), throwsA(nature(NatureErreur.refus).having((e) => e.message, 'message', m)));
      }
    });
  });

  group('Routes interdites (aucun envoi, aucun secret, aucun recalcul)', () {
    test('envoi de rappels, SMS, réglages / affiche / jeton, réponse au client, relevé PDF', () {
      for (final r in [
        '/rappels-habitude/envoyer',
        '/rappels-habitude/envoyer?canal=SMS',
        '/rappels-habitude/sms',
        '/avis-clients/reglages',
        '/avis-clients/reglages/regenerer',
        '/avis-clients/affiche',
        '/avis-clients/avis/AVIS-1/repondre',
        '/pointage-bl/releve',
        '/pointage-bl/releve/R1/pointer',
        '/pointage-bl/modele',
      ]) {
        expect(routeInterditeVague3(r), isTrue, reason: r);
      }
    });

    test('routes autorisées', () {
      // 3.8.0 (C2, demande du pharmacien) : l'actualisation des rappels n'est plus interdite ; elle n'est appelée qu'à
      // la demande (bouton « Actualiser la liste » + confirmation), ce que vérifient l'intégration et le parcours.
      expect(routeInterditeVague3('/rappels-habitude/actualiser'), isFalse);
      for (final r in [
        '/pointage-bl',
        '/pointage-bl/pointer/BL/1',
        '/pointage-bl/sequence/1',
        '/pointage-bl/avoir/1',
        '/avis-clients/droits',
        '/avis-clients/liste',
        '/avis-clients/analyse',
        '/avis-clients/avis/AVIS-1',
        '/avis-clients/avis/AVIS-1/traiter',
        '/rappels-habitude/liste',
        '/rappels-habitude/compteur',
        '/rappels-habitude/analyse',
        '/rappels-habitude/marquer',
      ]) {
        expect(routeInterditeVague3(r), isFalse, reason: r);
      }
    });

    test('la liste testée par le faux serveur couvre celle de l\'application', () {
      for (final r in routesInterditesVague3) {
        expect(routesInterditesVague3Testees.any((t) => t == r || t.startsWith('$r/')), isTrue, reason: r);
      }
    });
  });

  group('Pointage BL', () {
    test('lecture : pièces, montants signés, pointable seulement BL / RETOUR, totaux du serveur', () {
      final p = PointageBl.depuis({
        'success': true,
        'data': [...DonneesVague3.piecesInitiales(), 'pas un objet'],
        'totalBl': '525500',
        'totalAvoirs': -36500,
        'net': 489000,
        'pointes': 1,
        'nonPointes': 3,
      });
      expect(p.pieces, hasLength(5));
      expect(p.totalBl, 525500);
      expect(p.net, 489000);
      final retour = p.pieces.firstWhere((x) => x.estRetour);
      expect(retour.montantHt, -32000);
      expect(retour.libelleType, 'Avoir (retour)');
      expect(retour.avoirModifiable, isTrue);
      expect(retour.sequenceModifiable, isFalse);
      final reception = p.pieces.firstWhere((x) => x.type == 'RECEPTION');
      expect(reception.pointable, isFalse);
      expect(reception.sequenceModifiable, isFalse);
      expect(reception.avoirModifiable, isFalse);
      // Un « pointable:true » sur une pièce RECEPTION est ignoré (le serveur refuserait ce type).
      expect(PieceBl.depuis({'type': 'RECEPTION', 'id': 'X', 'pointable': true}).pointable, isFalse);
      final bl = p.pieces.first;
      expect(bl.sequenceModifiable, isTrue);
      expect(bl.controleEcarts, 2);
      expect(PointageBl.depuis({}).pieces, isEmpty);
      expect(() => PointageBl.depuis({'data': 'x'}), throwsA(nature(NatureErreur.reponse)));
    });

    test('compteurs après un pointage optimiste (et retour)', () {
      final p = PointageBl.depuis({'data': DonneesVague3.piecesInitiales(), 'pointes': 1, 'nonPointes': 3});
      final apres = p.avec(p.pieces, deltaPointes: 1);
      expect((apres.pointes, apres.nonPointes), (2, 2));
      final retour = apres.avec(p.pieces, deltaPointes: -1);
      expect((retour.pointes, retour.nonPointes), (1, 3));
    });

    test('N° de séquence : contrôle identique au serveur ([A-Za-z0-9 ./-]{1,20}, vide accepté)', () {
      for (final ok in ['', '   ', 'S-12', 'A1/B2.C3 4', '12345678901234567890', '  ABC  ']) {
        expect(ControlePointage.erreurSequence(ok), isNull, reason: ok);
      }
      for (final ko in ['123456789012345678901', 'S#12', 'é12', 'A_B', 'S;12', 'N°5']) {
        expect(ControlePointage.erreurSequence(ko), ControlePointage.messageSequence, reason: ko);
      }
      expect(ControlePointage.nettoyer('  S-12 '), 'S-12');
    });

    test('Référence d\'avoir : 40 caractères au plus, mêmes caractères', () {
      expect(ControlePointage.erreurAvoir('VRI 683562 2'), isNull);
      expect(ControlePointage.erreurAvoir('A' * 40), isNull);
      expect(ControlePointage.erreurAvoir('A' * 41), ControlePointage.messageAvoir);
      expect(ControlePointage.erreurAvoir('AV#1'), ControlePointage.messageAvoir);
    });

    test('Période : un an au plus comme le serveur (début + 1 an ≥ fin), pas de futur, début ≤ fin', () {
      final now = DateTime(2026, 10, 14);
      expect(ControlePointage.erreurPeriode(DateTime(2025, 10, 14), DateTime(2026, 10, 14), now), isNull);
      expect(ControlePointage.erreurPeriode(DateTime(2025, 10, 13), DateTime(2026, 10, 14), now), 'Période trop longue : un an au plus.');
      expect(ControlePointage.erreurPeriode(DateTime(2026, 10, 2), DateTime(2026, 10, 1), now), isNotNull);
      expect(ControlePointage.erreurPeriode(DateTime(2026, 10, 1), DateTime(2026, 10, 15), now), isNotNull);
    });

    test('paramètres : grossiste OU groupe, dates aaaa-mm-jj, état', () {
      final f = FiltresPointage(grossiste: 'G1', groupe: 'GRP', debut: DateTime(2026, 10, 1), fin: DateTime(2026, 10, 14), etat: EtatPointage.nonPointes);
      expect(f.parametres, {'grossiste': 'G1', 'groupe': '', 'du': '2026-10-01', 'au': '2026-10-14', 'etat': 'NON_POINTES'});
      expect(f.copie(grossiste: '').parametres['groupe'], 'GRP');
      expect(FiltresPointage(debut: DateTime(2026), fin: DateTime(2026)).complet, isFalse);
    });
  });

  group('Avis', () {
    test('droits, avis (statut, critères, coordonnées affichables), page', () {
      final d = DroitsAvis.depuis(DonneesVague3.droits(repondre: false));
      expect(d.repondre, isFalse);
      expect(d.criteres['ATTENTE'], 'Temps d\'attente');
      expect(d.themes, contains('Prix'));
      expect(DroitsAvis.depuis({}).repondre, isFalse, reason: 'droit absent = pas de traitement');
      final a = Avis.depuis(Map<String, dynamic>.from(DonneesVague3.avis(1)));
      expect(a.statut, StatutAvis.nouveau);
      expect(a.note, 2);
      expect(a.negatif, isTrue);
      expect(a.criteres, {'ATTENTE': 'MOINS'});
      expect(a.nom, 'CLIENT FICTIF 1');
      expect(Avis.depuis({'id': 'X', 'note': 9}).note, 5);
      expect(a.avecStatut(StatutAvis.lu).statut, StatutAvis.lu);
    });

    test('note interne : nettoyée COMME le serveur (Texte.libre) et 1500 caractères au plus', () {
      // Comme Java : la tabulation est un caractère de contrôle (\p{Cntrl}) retiré AVANT la réduction des espaces.
      expect(ControleAvis.nettoyerNoteInterne('  Client <b>rappelé</b>\r\n\r\n\r\n\r\nle   12\t/10  '), 'Client rappelé \n\nle 12/10');
      expect(ControleAvis.nettoyerNoteInterne('A${String.fromCharCode(0x200B)}B${String.fromCharCode(0x202E)}C${String.fromCharCode(7)}'), 'ABC');
      expect(ControleAvis.nettoyerNoteInterne('   '), '');
      expect(ControleAvis.nettoyerNoteInterne('x' * 1600), hasLength(1500));
      expect(ControleAvis.erreurNoteInterne('x' * 1500), isNull);
      expect(ControleAvis.erreurNoteInterne('x' * 1501), isNotNull);
    });

    test('mot-clé : un mot, 40 caractères au plus', () {
      expect(ControleAvis.erreurMotCle(''), isNull);
      expect(ControleAvis.erreurMotCle('attente'), isNull);
      expect(ControleAvis.erreurMotCle('deux mots'), isNotNull);
      expect(ControleAvis.erreurMotCle('a' * 41), isNotNull);
    });

    test('filtres : paramètres exacts du web (30 derniers jours, pages de 50, tri), filtres actifs et étiquettes', () {
      final f = FiltresAvis.parDefaut(DateTime(2026, 10, 14, 16));
      expect(f.parametres(), {
        'du': '2026-09-15',
        'au': '2026-10-14',
        'note': '',
        'statut': '',
        'contient': '',
        'motCle': '',
        'employe': '',
        'theme': '',
        'reponse': '',
        'tri': 'DATE_DESC',
        'start': '0',
        'limit': '50',
      });
      final g = f.copie(note: NoteAvis.negatif, statut: FiltreStatutAvis.nonTraites, reponseAttendue: true, tri: TriAvis.notesBasses, employe: 'k', libelleEmploye: 'Vendeur');
      expect(g.parametres(start: 50)['start'], '50');
      expect(g.parametres()['note'], 'NEGATIF');
      expect(g.parametres()['statut'], 'NON_TRAITE');
      expect(g.parametres()['reponse'], 'ATTENDUE');
      expect(g.parametres()['tri'], 'NOTE_ASC');
      expect(g.actifs, 4);
      expect(g.etiquettes, contains('Employé : Vendeur'));
      expect(g.sansFiltres().actifs, 0);
      expect(g.sansFiltres().tri, TriAvis.notesBasses);
    });

    test('analyse : synthèse, répartition, critères (satisfaction null), alertes et leur filtre', () {
      final a = AnalyseAvis.depuis(DonneesVague3.analyseAvis());
      expect(a.synthese.nombre, 60);
      expect(a.synthese.precedentMoyenne, 3.4);
      expect(a.repartition.first, (5, 12, 20.0));
      expect(a.criteres.last.satisfaction, isNull);
      expect(a.alertes.first.haute, isTrue);
      expect(a.alertes.first.filtre, {'note': 'NEGATIF', 'statut': 'NON_TRAITE'});
      expect(a.alertes.last.filtre, isNull);
      expect(a.employes.single.cle, 'vendeur fictif');
      expect(a.faibles, hasLength(2));
      expect(AnalyseAvis.depuis({}).synthese.nombre, 0);
    });
  });

  group('Rappels traitement', () {
    test('lecture : statut, date d\'envoi (millisecondes), retard', () {
      final r = Rappel.depuis(Map<String, dynamic>.from(DonneesVague3.rappel(10)));
      expect(r.statut, StatutRappel.aPreparer);
      expect(r.envoi, DateTime(2026, 10, 2, 9, 30));
      expect(r.enRetard(DateTime(2026, 10, 14)), isTrue);
      expect(r.enRetard(DateTime(2026, 10, 5)), isFalse);
      expect(Rappel.depuis({'id': 'x', 'envoi': null}).envoi, isNull);
      expect(Rappel.depuis({'id': 'x', 'statut': 'ACHETE'}).statut, StatutRappel.achete);
    });

    test('paramètres : statut À préparer par défaut, recherche, dates prévues (passées ou futures)', () {
      final now = DateTime(2026, 10, 14, 11);
      expect(const FiltresRappels().parametres(now), {'statut': 'A_PREPARER', 'query': '', 'dtStart': '', 'dtEnd': ''});
      expect(const FiltresRappels(prevu: PrevuRappel.enRetard).parametres(now)['dtEnd'], '2026-10-13');
      final sept = const FiltresRappels(statut: FiltreStatutRappel.enCours, recherche: 'fictif', prevu: PrevuRappel.septJours).parametres(now);
      expect(sept, {'statut': '', 'query': 'fictif', 'dtStart': '2026-10-14', 'dtEnd': '2026-10-20'});
      expect(const FiltresRappels(statut: FiltreStatutRappel.tous).parametres(now)['statut'], 'TOUS');
    });

    test('statuts « marquables » = ceux du serveur (Racheté exclu) ; sélection contrôlée', () {
      expect(StatutRappel.marquables.map((s) => s.code), ['PREPARE', 'ECARTE', 'A_PREPARER']);
      expect(StatutRappel.marquables, isNot(contains(StatutRappel.achete)));
      expect(ControleRappels.erreurSelection(0), isNotNull);
      expect(ControleRappels.erreurSelection(1), isNull);
      expect(ControleRappels.erreurSelection(2001), isNotNull);
    });

    test('analyse : totaux, canaux, mois lisibles ; durée par défaut = 6 mois comme le serveur', () {
      final a = AnalyseRappels.depuis(DonneesVague3.analyseRappels('2026-05-01', '2026-10-14'));
      expect(a.total.efficacite, 60.0);
      expect(a.total.canaux['SMS'], 30);
      expect(a.mois.first.moisLisible, '05/2026');
      final (d, f) = DureeAnalyseRappels.sixMois.bornes(DateTime(2026, 10, 14, 9));
      expect((d, f), (DateTime(2026, 5, 1), DateTime(2026, 10, 14)));
      expect(DureeAnalyseRappels.douzeMois.bornes(DateTime(2026, 3, 3)).$1, DateTime(2025, 4, 1));
    });
  });

  group('Menus réservés', () {
    tearDown(() => ProfilAcces.utilisateur.value = null);

    test('Pointage BL, Avis, Rappels traitement : réservés, absents pour un autre profil', () {
      const nouveaux = ['Pointage BL', 'Avis', 'Rappels traitement'];
      for (final n in nouveaux) {
        expect(menusModules.singleWhere((m) => m.titre == n).responsables, isTrue, reason: n);
      }
      ProfilAcces.utilisateur.value = utilisateur('mainmenumanager');
      expect([for (final m in menusAutorises()) m.titre], isNot(anyElement(isIn(nouveaux))));
      ProfilAcces.utilisateur.value = utilisateur('dashboard');
      expect([for (final m in menusAutorises()) m.titre], containsAll(nouveaux));
    });
  });
}
