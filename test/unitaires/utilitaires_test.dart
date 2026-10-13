// Tests unitaires de la logique pure (sans écran ni serveur) : dates, licence, modèles, messages d'erreur.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prestige_app/models/licence_model.dart';
import 'package:prestige_app/models/officine_model.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/services/journal_app.dart';
import 'package:prestige_app/utils/date_formatter.dart';

String jour(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  setUpAll(() async {
    JournalApp.actif = false;
    await initializeDateFormatting('fr_FR');
  });

  group('DateFormatter', () {
    test('formats d\'affichage et d\'API', () {
      final d = DateTime(2026, 3, 7);
      expect(DateFormatter.toDisplayFormat(d), '07-03-2026');
      expect(DateFormatter.toApiFormat(d), '2026-03-07');
      expect(DateFormatter.toApiYYYYMMDDFormat(d), '20260307');
    });

    test('lecture des dates du serveur ; date illisible → null (jamais d\'exception)', () {
      expect(DateFormatter.parseApiDateString('20261013'), DateTime(2026, 10, 13));
      expect(DateFormatter.parseApiDateString('2026-10-13'), isNull);
      expect(DateFormatter.parseApiDateString('2026AB13'), isNull);
      expect(DateFormatter.parseApiDateString(null), isNull);
      expect(DateFormatter.parseDDMMYYYY('13/10/2026'), DateTime(2026, 10, 13));
      expect(DateFormatter.parseDDMMYYYY('pas une date'), isNull);
      expect(DateFormatter.parseDDMMYYYY(''), isNull);
      expect(DateFormatter.parseDDMMYYYYHHMM('13/10/2026 08:05'), DateTime(2026, 10, 13, 8, 5));
      expect(DateFormatter.parseIsoDateTime('2026-10-13T08:05:00'), DateTime(2026, 10, 13, 8, 5));
      expect(DateFormatter.parseIsoDateTime('13/10/2026'), isNull);
    });

    test('durée d\'inactivité lisible (message de session expirée)', () {
      expect(DateFormatter.formatDuration(const Duration(seconds: 30)), 'moins d\'une minute');
      expect(DateFormatter.formatDuration(const Duration(minutes: 59)), '59 minute(s)');
      expect(DateFormatter.formatDuration(const Duration(hours: 2)), '2 heure(s)');
      expect(DateFormatter.formatDuration(const Duration(hours: 1, minutes: 5)), '1h05');
    });
  });

  group('Licence', () {
    LicenceModel licence(String fin) => LicenceModel.fromJson({'id': 'L', 'typeLicence': 'ANNUELLE', 'dateStart': '2026-01-01', 'dateEnd': fin});

    test('jours restants et validité (le jour d\'échéance est encore valide)', () {
      final aujourdHui = DateTime.now();
      expect(licence(jour(aujourdHui)).daysRemaining, 0);
      expect(licence(jour(aujourdHui)).isValid, isTrue);
      expect(licence(jour(aujourdHui.add(const Duration(days: 10)))).daysRemaining, 10);
      expect(licence(jour(aujourdHui.subtract(const Duration(days: 1)))).isValid, isFalse);
    });

    test('date de fin absente ou illisible : 0 jour (jamais d\'exception)', () {
      expect(licence('').expiryDate, isNull);
      expect(licence('').daysRemaining, 0);
      expect(licence('31/12/2099').expiryDate, isNull);
    });

    test('lecture tolérante : champs absents ou numériques', () {
      final l = LicenceModel.fromJson({'id': 12});
      expect(l.id, '12');
      expect(l.dateEnd, '');
    });

    test('LicenceLookup : seul un échec de connexion est un « problème de connexion »', () {
      expect(const LicenceLookup.noLicence().isConnectionProblem, isFalse);
      expect(LicenceLookup.found(licence('2099-12-31')).isConnectionProblem, isFalse);
      expect(const LicenceLookup.failure(LicenceIssue.unreachable, 'x').isConnectionProblem, isTrue);
    });
  });

  group('Modèles', () {
    test('utilisateur : valeurs par défaut et nom complet', () {
      final u = AppUser.fromJson({'str_FIRST_NAME': 'Docteur', 'str_LAST_NAME': 'Fictif'});
      expect(u.fullName, 'Docteur Fictif');
      expect(u.login, '');
      expect(u.officineName, 'Pharmacie');
      expect(AppUser.fromJson({}).fullName, 'Utilisateur ');
    });

    test('officine : valeurs par défaut', () {
      final o = Officine.fromJson({});
      expect(o.nomComplet, 'Pharmacie');
      expect(o.fullName, 'Utilisateur');
      expect(Officine.fromJson({'nomComplet': 'Pharmacie Fictive'}).nomComplet, 'Pharmacie Fictive');
    });
  });

  group('ApiLoadException.pour : message précisé par ce qui n\'a pas été chargé', () {
    test('réseau, délai, serveur', () {
      expect(const ApiLoadException(ApiLoadException.messageReseau).pour('rayons').message,
          'Serveur injoignable (rayons non chargés). Vérifiez le Wi-Fi ou les données mobiles puis réessayez.');
      expect(const ApiLoadException(ApiLoadException.messageDelai, nature: NatureErreur.delai).pour('articles').message,
          contains('(articles non chargés)'));
      final e = const ApiLoadException('x', nature: NatureErreur.serveur, code: 503).pour('articles');
      expect(e.message, 'Erreur du serveur (code 503) lors du chargement des articles.');
      expect(e.code, 503);
    });

    test('session, droit, refus, réponse : message inchangé (déjà précis)', () {
      for (final n in [NatureErreur.session, NatureErreur.droit, NatureErreur.refus, NatureErreur.reponse]) {
        final e = ApiLoadException('message d\'origine', nature: n);
        expect(identical(e.pour('articles'), e), isTrue, reason: '$n');
      }
    });

    test('message réseau personnalisé (certificat HTTPS) conservé', () {
      expect(const ApiLoadException(ApiLoadException.messageCertificat).pour('rayons').message, ApiLoadException.messageCertificat);
    });
  });
}
