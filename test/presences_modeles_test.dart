// Module Présences : règles pures sur de VRAIES réponses du serveur de test (test/fixtures/presences).
// Statut et retard selon le seuil (60 min par défaut, puis un autre seuil), tri (absents et retards en tête),
// aujourd'hui / hier, anomalies traduites en phrases, pointages du jour avec leur source, compteurs, recherche,
// période bornée à 366 jours, QR et téléphones.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/presences/presences_modeles.dart';
import 'package:prestige_app/presences/presences_reglages.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/serveur_presences.dart';

PresenceDuJour lirePresence(String f, DateTime jour) {
  final j = jsonDecode(fixture(f)) as Map<String, dynamic>;
  return PresenceDuJour(
    jour: jour,
    lignes: [for (final e in j['data'] as List) PresenceJour.fromJson(Map<String, dynamic>.from(e as Map))],
    pointages: [for (final e in j['pointages'] as List) PointageJour.fromJson(Map<String, dynamic>.from(e as Map))],
  );
}

void main() {
  // Le 13/10/2026 à 08:46 (heure de l'officine).
  final maintenant = DateTime(2026, 10, 13, 8, 46);
  final aujourdhui = lirePresence('presence_aujourdhui.json', DateTime(2026, 10, 13));
  final hier = lirePresence('presence_hier.json', DateTime(2026, 10, 12));
  PresenceJour de(PresenceDuJour p, String matricule) => p.lignes.firstWhere((l) => l.matricule == matricule);
  const awa = 'TEST-0042', yao = 'TEST-0043';

  group('Lecture des réponses réelles de /rh/presence', () {
    test('lignes et pointages bruts', () {
      expect(aujourdhui.lignes, hasLength(2));
      final a = de(aujourdhui, awa);
      expect(a.employe, 'KONE Awa Test');
      expect(a.prevu, '00:30-09:00');
      expect(a.entree, '00:52');
      expect(a.sortie, '');
      expect(a.retard, 22);
      expect(a.minutesPrevues, 510);
      expect(a.anomalies, ['ENTREE_SANS_SORTIE']);
      expect(a.pointages, '00:52↑');
      expect(a.debutPrevu, 30);
      final h = de(hier, yao);
      expect(h.anomalies, ['DOUBLON', 'ENTREE_SANS_SORTIE']);
      expect(hier.pointages, hasLength(5));
      expect(hier.pointages.first.source, 'MANUEL');
      expect(hier.pointages.first.motif, 'Essai app pharmacien');
    });

    test('réponse vide = vraie absence de données', () {
      final v = lirePresence('presence_vide.json', DateTime(2026, 9, 1));
      expect(v.lignes, isEmpty);
      expect(CompteursPresence.de(v.lignes, 60, maintenant).presents, 0);
    });

    test('champs manquants ou de mauvais type : valeurs neutres, pas de plantage', () {
      final l = PresenceJour.fromJson({'employeId': 'x', 'retard': '12', 'minutesPresence': null, 'anomalies': 'doublon; ABSENT'});
      expect(l.retard, 12);
      expect(l.minutesPresence, 0);
      expect(l.anomalies, ['DOUBLON', 'ABSENT']);
      expect(l.nomAffiche, 'Employé');
    });
  });

  group('Statut et retard selon le seuil du pharmacien', () {
    test('seuil 60 min (défaut) : 22 min de retard → pas « en retard » ; 75 min → en retard', () {
      expect(de(aujourdhui, awa).statut(60, maintenant), StatutPresence.present);
      expect(de(aujourdhui, awa).enRetard(60), isFalse);
      expect(de(hier, awa).minutesRetard, 75);
      expect(de(hier, awa).statut(60, maintenant), StatutPresence.enRetard);
    });

    test('autre seuil (15 min) : 22 min de retard → en retard', () {
      expect(de(aujourdhui, awa).statut(15, maintenant), StatutPresence.enRetard);
      expect(CompteursPresence.de(aujourdhui.lignes, 15, maintenant).retards, 1);
      expect(CompteursPresence.de(aujourdhui.lignes, 15, maintenant).minutesRetard, 22);
    });

    test('seuil 0 : un retard sous la tolérance du serveur (retard=0) est recalculé depuis l\'heure prévue', () {
      // Hier Yao : prévu 08:00, arrivé 08:02 ; le serveur (tolérance 5 min) donne retard = 0.
      final y = de(hier, yao);
      expect(y.retard, 0);
      expect(y.minutesRetard, 2);
      expect(y.enRetard(0), isTrue);
      expect(y.enRetard(60), isFalse);
      // Seuil égal au retard : pas en retard (il faut DÉPASSER l'heure prévue + seuil).
      expect(de(hier, awa).enRetard(75), isFalse);
      expect(de(hier, awa).enRetard(74), isTrue);
    });

    test('absent ; « attendu » tant que l\'heure prévue + seuil n\'est pas passée (aujourd\'hui seulement)', () {
      expect(de(aujourdhui, yao).statut(60, maintenant), StatutPresence.absent);
      expect(de(aujourdhui, yao).statut(60, DateTime(2026, 10, 13, 0, 45)), StatutPresence.attendu);
      expect(de(aujourdhui, yao).statut(30, DateTime(2026, 10, 13, 0, 45)), StatutPresence.absent);
    });

    test('anomalie, parti tôt, congé, repos', () {
      expect(de(hier, yao).statut(60, maintenant), StatutPresence.anomalie);
      expect(const PresenceJour(employeId: 'a', prevu: '08:00-16:00', entree: '08:00', sortie: '15:00', departAnticipe: 60)
          .statut(60, maintenant), StatutPresence.partiTot);
      expect(const PresenceJour(employeId: 'a', prevu: '08:00-16:00', minutesPrevues: 420, absence: 'CONGE').statut(60, maintenant),
          StatutPresence.conge);
      expect(const PresenceJour(employeId: 'a', prevu: 'Repos').statut(60, maintenant), StatutPresence.repos);
      expect(const PresenceJour(employeId: 'a', prevu: 'Garde 20:00-08:00').debutPrevu, 20 * 60);
    });
  });

  group('Anomalies traduites en phrases', () {
    test('tous les codes du serveur (AnalysePresence.java)', () {
      expect(anomalieEnPhrase('ENTREE_SANS_SORTIE'), 'Arrivée sans départ');
      expect(anomalieEnPhrase('SORTIE_SANS_ENTREE'), 'Départ sans arrivée');
      expect(anomalieEnPhrase('DOUBLON'), 'Pointage en double');
      expect(anomalieEnPhrase('DEUX_ENTREES'), 'Deux arrivées de suite');
      expect(anomalieEnPhrase('POINTAGE_EN_CONGE'), 'A pointé pendant un congé');
      expect(anomalieEnPhrase('HORS_PLANNING'), 'Pointé hors planning');
      expect(anomalieEnPhrase('JOURNEE_LONGUE'), 'Journée anormalement longue');
      expect(anomalieEnPhrase('ABSENT'), 'Absent sans justification');
      expect(anomalieEnPhrase('NOUVEAU_CODE'), 'Nouveau code');
    });

    test('hier : « Pointage en double » et « Arrivée sans départ » ; aujourd\'hui « Arrivée sans départ » n\'est pas une anomalie', () {
      expect(de(hier, yao).phrasesAnomalies(maintenant), ['Pointage en double', 'Arrivée sans départ']);
      expect(de(aujourdhui, awa).phrasesAnomalies(maintenant), isEmpty);
      // « Absent » est un statut, pas une anomalie.
      expect(de(aujourdhui, yao).phrasesAnomalies(maintenant), isEmpty);
    });
  });

  group('Tri et compteurs', () {
    test('aujourd\'hui : absent en tête', () {
      final t = trierPresences(aujourdhui.lignes, 60, maintenant);
      expect(t.map((l) => l.matricule), [yao, awa]);
    });

    test('hier : retard en tête, puis anomalie', () {
      final t = trierPresences(hier.lignes, 60, maintenant);
      expect(t.map((l) => l.matricule), [awa, yao]);
    });

    test('ordre complet : absents, retards (plus gros d\'abord), anomalies, départs anticipés, présents, congés, repos', () {
      final lignes = [
        const PresenceJour(employeId: '1', employe: 'Repos', prevu: 'Repos'),
        const PresenceJour(employeId: '2', employe: 'Present', prevu: '08:00-16:00', entree: '08:00'),
        const PresenceJour(employeId: '3', employe: 'Retard90', prevu: '08:00-16:00', entree: '09:30', retard: 90),
        const PresenceJour(employeId: '4', employe: 'Absent', prevu: '08:00-16:00', anomalies: ['ABSENT']),
        const PresenceJour(employeId: '5', employe: 'Retard120', prevu: '08:00-16:00', entree: '10:00', retard: 120),
        const PresenceJour(employeId: '6', employe: 'Conge', prevu: '08:00-16:00', absence: 'CONGE'),
        const PresenceJour(employeId: '7', employe: 'Doublon', prevu: '08:00-16:00', entree: '08:00', anomalies: ['DOUBLON']),
        const PresenceJour(employeId: '8', employe: 'Tot', prevu: '08:00-16:00', entree: '08:00', departAnticipe: 30),
      ];
      final t = trierPresences(lignes, 60, DateTime(2026, 10, 20, 18));
      expect(t.map((l) => l.employe), ['Absent', 'Retard120', 'Retard90', 'Doublon', 'Tot', 'Present', 'Conge', 'Repos']);
    });

    test('compteurs : présents / prévus, retards (cumul), absents, anomalies', () {
      final c = CompteursPresence.de(aujourdhui.lignes, 60, maintenant);
      expect((c.presents, c.prevus, c.retards, c.absents, c.anomalies), (1, 2, 0, 1, 0));
      final h = CompteursPresence.de(hier.lignes, 60, maintenant);
      expect((h.presents, h.prevus, h.retards, h.minutesRetard, h.absents, h.anomalies), (2, 2, 1, 75, 0, 1));
    });

    test('recherche par nom ou matricule, sans accents ni majuscules', () {
      expect(filtrerPresences(aujourdhui.lignes, 'kone').single.matricule, awa);
      expect(filtrerPresences(aujourdhui.lignes, 'YAO brou').single.matricule, yao);
      expect(filtrerPresences(aujourdhui.lignes, '0043').single.matricule, yao);
      expect(filtrerPresences(aujourdhui.lignes, 'koné'), hasLength(1));
      expect(filtrerPresences(aujourdhui.lignes, 'zzz'), isEmpty);
      expect(filtrerPresences(aujourdhui.lignes, '  '), hasLength(2));
    });
  });

  group('Fiche employé : pointages du jour avec leur source', () {
    test('hier, Yao : 08:02 saisie manuelle (motif) puis 08:03 pointeuse', () {
      final p = hier.pointagesDe(de(hier, yao));
      expect(p.map((x) => '${x.heure} ${x.sensLisible} ${sourceLisible(x.source)}'),
          ['08:02 Arrivée Saisie manuelle', '08:03 Arrivée Pointeuse']);
      expect(p.first.motif, 'Essai app pharmacien');
    });

    test('hier, Awa : le pointage du lendemain matin (00:52) n\'est pas mélangé à la journée', () {
      final p = hier.pointagesDe(de(hier, awa));
      expect(p.map((x) => x.heure), ['09:15', '15:20']);
      expect(p.last.sensLisible, 'Départ');
    });

    test('aujourd\'hui, Awa : 00:52 depuis le téléphone', () {
      final p = aujourdhui.pointagesDe(de(aujourdhui, awa));
      expect(p.single.heure, '00:52');
      expect(sourceLisible(p.single.source), 'Téléphone');
    });
  });

  group('Tableau sur une période', () {
    test('lecture réelle de /rh/tableau', () {
      final j = jsonDecode(fixture('tableau.json')) as Map<String, dynamic>;
      final l = [for (final e in j['data'] as List) TableauLigne.fromJson(Map<String, dynamic>.from(e as Map))];
      final a = l.firstWhere((x) => x.matricule == awa);
      expect((a.joursPresents, a.joursPrevus, a.retards, a.minutesRetard, a.departsAnticipes, a.minutesPresence, a.anomalies),
          (2, 2, 2, 97, 1, 365, 1));
      final y = l.firstWhere((x) => x.matricule == yao);
      expect((y.absencesNonJustifiees, y.anomalies, y.absencesJustifieesTexte), (1, 2, '0'));
      expect(TableauLigne.fromJson({'employeId': 'x', 'joursAbsenceJustifiee': 1.5}).absencesJustifieesTexte, '1,5');
    });

    test('période bornée : 366 jours au plus, jamais à l\'envers, jamais dans le futur', () {
      final today = DateTime(2026, 10, 13);
      final ok = PeriodePresence.bornee(DateTime(2026, 10, 1), today, aujourdhui: today);
      expect((ok.du, ok.au, ok.correction), (DateTime(2026, 10, 1), today, null));
      expect(ok.parametres, {'du': '2026-10-01', 'au': '2026-10-13'});

      final longue = PeriodePresence.bornee(DateTime(2024, 1, 1), today, aujourdhui: today);
      expect(longue.au.difference(longue.du).inDays, 366);
      expect(longue.du, DateTime(2025, 10, 12));
      expect(longue.correction, contains('366 jours'));

      final envers = PeriodePresence.bornee(DateTime(2026, 10, 10), DateTime(2026, 10, 1), aujourdhui: today);
      expect((envers.du, envers.au), (DateTime(2026, 10, 1), DateTime(2026, 10, 1)));
      expect(envers.correction, isNotNull);

      final futur = PeriodePresence.bornee(DateTime(2026, 10, 1), DateTime(2026, 12, 31), aujourdhui: today);
      expect(futur.au, today);
      expect(futur.correction, contains('aujourd\'hui'));
    });

    test('périodes prédéfinies', () {
      final today = DateTime(2026, 10, 13); // mardi
      expect(PeriodePresence.semaine(today).du, DateTime(2026, 10, 12));
      expect(PeriodePresence.mois(today).du, DateTime(2026, 10, 1));
      final md = PeriodePresence.moisDernier(today);
      expect((md.du, md.au), (DateTime(2026, 9, 1), DateTime(2026, 9, 30)));
      final janvier = PeriodePresence.moisDernier(DateTime(2026, 1, 5));
      expect((janvier.du, janvier.au), (DateTime(2025, 12, 1), DateTime(2025, 12, 31)));
    });
  });

  group('QR et téléphones', () {
    test('lecture réelle de /rh/mobile/code', () {
      final c = CodePointageMoment.fromJson(jsonDecode(fixture('code.json')) as Map<String, dynamic>);
      expect((c.code, c.contenu, c.resteSec, c.periodeSec, c.actif, c.qrExige, c.gpsExige, c.rayon),
          ('WPYX5V', 'PRESTIGE-POINTAGE:WPYX5V', 13, 60, true, true, false, 150));
      expect(c.codeAffiche, 'WPY X5V');
      // Valeurs absurdes bornées.
      final b = CodePointageMoment.fromJson({'code': 'A', 'resteSec': 999, 'periodeSec': -1});
      expect((b.resteSec, b.periodeSec, b.contenu), (60, 60, 'A'));
    });

    test('lecture réelle de /rh/mobile/terminaux', () {
      final j = jsonDecode(fixture('terminaux.json')) as Map<String, dynamic>;
      final t = [for (final e in j['data'] as List) TerminalMobile.fromJson(Map<String, dynamic>.from(e as Map))];
      expect(t.map((x) => '${x.titre}|${x.appareil}|${x.statutLisible}'),
          ['KONE Awa Test|Samsung A14|Actif', 'BROU Yao Test|Téléphone Yao|Retiré']);
    });
  });

  group('Réglage du seuil de retard', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('60 min par défaut ; 0 à 480 ; valeur hors bornes ignorée', () async {
      expect(await ReglagesPresences.charger(), 60);
      expect(ReglagesPresences.erreurSeuil(''), isNotNull);
      expect(ReglagesPresences.erreurSeuil('abc'), isNotNull);
      expect(ReglagesPresences.erreurSeuil('-1'), isNotNull);
      expect(ReglagesPresences.erreurSeuil('481'), isNotNull);
      expect(ReglagesPresences.erreurSeuil('0'), isNull);
      expect(ReglagesPresences.erreurSeuil('480'), isNull);
      expect(await ReglagesPresences.enregistrerSeuil(481), isFalse);
      expect(await ReglagesPresences.enregistrerSeuil(30), isTrue);
      expect(await ReglagesPresences.charger(), 30);
      SharedPreferences.setMockInitialValues({ReglagesPresences.cleSeuil: 9999});
      expect(await ReglagesPresences.charger(), 60);
    });
  });

  test('durées lisibles', () {
    expect(dureeLisible(0), '0 min');
    expect(dureeLisible(22), '22 min');
    expect(dureeLisible(60), '1 h');
    expect(dureeLisible(97), '1 h 37');
  });
}
