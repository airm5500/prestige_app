// Sélecteur de période commun des modules refaits (lib/nouvelle_interface/modules/periode.dart) : périodes rapides
// calculées au jour près (changements de mois et d'année compris) et contrôles des dates d'une période
// personnalisée (début ≤ fin, rien dans le futur, pas avant 2000, 366 jours au plus). Paramètres envoyés au
// serveur au format d'origine (dtStart / dtEnd en yyyy-MM-dd).
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prestige_app/nouvelle_interface/modules/periode.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  final maintenant = DateTime(2026, 10, 14, 15, 42);
  DateTime j(int a, int m, int d) => DateTime(a, m, d);

  group('Périodes rapides', () {
    test('Aujourd\'hui, Hier, 7 jours, Ce mois, Mois dernier (dates sans heure)', () {
      final attendu = {
        PeriodeRapide.aujourdhui: (j(2026, 10, 14), j(2026, 10, 14)),
        PeriodeRapide.hier: (j(2026, 10, 13), j(2026, 10, 13)),
        PeriodeRapide.septJours: (j(2026, 10, 8), j(2026, 10, 14)),
        PeriodeRapide.ceMois: (j(2026, 10, 1), j(2026, 10, 14)),
        PeriodeRapide.moisDernier: (j(2026, 9, 1), j(2026, 9, 30)),
      };
      attendu.forEach((choix, dates) {
        final p = Periode.rapide(choix, maintenant);
        expect((p.debut, p.fin), dates, reason: choix.libelle);
        expect(p.choix, choix);
        expect(ControlePeriode.erreur(p.debut, p.fin, maintenant), isNull, reason: '${choix.libelle} acceptée');
      });
      expect(Periode.rapide(PeriodeRapide.septJours, maintenant).nombreJours, 7);
    });

    test('changements de mois et d\'année : 1er janvier, 1er mars, année bissextile', () {
      final nouvelAn = DateTime(2027, 1, 1, 8);
      expect(Periode.rapide(PeriodeRapide.hier, nouvelAn).debut, j(2026, 12, 31));
      expect(Periode.rapide(PeriodeRapide.septJours, nouvelAn).debut, j(2026, 12, 26));
      final md = Periode.rapide(PeriodeRapide.moisDernier, nouvelAn);
      expect((md.debut, md.fin), (j(2026, 12, 1), j(2026, 12, 31)));
      expect(Periode.rapide(PeriodeRapide.ceMois, nouvelAn).debut, j(2027, 1, 1));
      final mars = DateTime(2028, 3, 1);
      final fevrier = Periode.rapide(PeriodeRapide.moisDernier, mars);
      expect((fevrier.debut, fevrier.fin), (j(2028, 2, 1), j(2028, 2, 29)), reason: '2028 est bissextile');
      expect(Periode.rapide(PeriodeRapide.moisDernier, DateTime(2027, 3, 31)).fin, j(2027, 2, 28));
    });

    test('paramètres envoyés : dtStart / dtEnd au format d\'origine, résumé lisible', () {
      final p = Periode.rapide(PeriodeRapide.septJours, maintenant);
      expect(p.parametres, {'dtStart': '2026-10-08', 'dtEnd': '2026-10-14'});
      expect(p.resume, '7 jours · du 08/10/2026 au 14/10/2026');
      expect(Periode.rapide(PeriodeRapide.aujourdhui, maintenant).resume, 'Aujourd\'hui · 14/10/2026');
    });
  });

  group('Contrôles des dates (période personnalisée)', () {
    test('période correcte acceptée (même jour, bornes incluses, 366 jours)', () {
      expect(ControlePeriode.erreur(j(2026, 10, 1), j(2026, 10, 1), maintenant), isNull);
      expect(ControlePeriode.erreur(j(2026, 1, 1), maintenant, maintenant), isNull, reason: 'jusqu\'à aujourd\'hui (heure ignorée)');
      expect(ControlePeriode.erreur(j(2025, 10, 14), j(2026, 10, 14), maintenant), isNull, reason: '366 jours');
      final p = Periode.personnalisee(DateTime(2026, 9, 3, 18), DateTime(2026, 9, 10, 7), maintenant)!;
      expect((p.debut, p.fin, p.choix), (j(2026, 9, 3), j(2026, 9, 10), PeriodeRapide.personnalisee));
    });

    test('début après la fin : refusé', () {
      expect(ControlePeriode.erreur(j(2026, 10, 10), j(2026, 10, 9), maintenant), 'La date de début doit précéder la date de fin.');
      expect(Periode.personnalisee(j(2026, 10, 10), j(2026, 10, 9), maintenant), isNull);
    });

    test('dates dans le futur : refusées (fin ou début après aujourd\'hui)', () {
      expect(ControlePeriode.erreur(j(2026, 10, 1), j(2026, 10, 15), maintenant), 'La période ne peut pas être dans le futur.');
      expect(ControlePeriode.erreur(j(2026, 11, 1), j(2026, 11, 2), maintenant), 'La période ne peut pas être dans le futur.');
      expect(Periode.personnalisee(j(2026, 10, 14), j(2026, 12, 31), maintenant), isNull);
    });

    test('bornes raisonnables : pas avant le 01/01/2000, 366 jours au plus', () {
      expect(ControlePeriode.erreur(j(1999, 12, 31), j(2000, 1, 5), maintenant), 'Date trop ancienne (avant le 01/01/2000).');
      expect(ControlePeriode.erreur(j(2000, 1, 1), j(2000, 1, 5), maintenant), isNull);
      expect(ControlePeriode.erreur(j(2025, 10, 13), j(2026, 10, 14), maintenant), 'Période trop longue (366 jours au plus).');
      expect(ControlePeriode.erreur(j(2010, 1, 1), j(2026, 1, 1), maintenant), 'Période trop longue (366 jours au plus).');
    });
  });
}
