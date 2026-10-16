// Retours du pharmacien (3.11.0), parties pures : sélecteur de période (Aujourd'hui, Hier, Personnaliser visibles ;
// autres périodes dans le sélecteur), période du Pilotage, temps de saisie des BL, évolution des ventes par rapport à
// la veille, référence des suggestions, migration vers le tableau de bord, menus réunis et « Evolution Stock » dans la
// Valorisation, classeur .xls accepté.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:prestige_app/donnees/analyse_bl_donnees.dart';
import 'package:prestige_app/models/bon_livraison_stat_model.dart';
import 'package:prestige_app/models/suggestion_model.dart';
import 'package:prestige_app/models/tableau_bord_achats_ventes_model.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/menus.dart';
import 'package:prestige_app/nouvelle_interface/modules/periode.dart';
import 'package:prestige_app/nouvelle_interface/modules/suggestions_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/tableau_analyses_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppUser utilisateur(String type) => AppUser.fromJson({'str_LOGIN': 'fictif', 'xtypeuser': type});

void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  group('Sélecteur de période', () {
    test('Aujourd\'hui, Hier, Personnaliser visibles ; 7 jours, Ce mois, Mois dernier dans « Autres périodes »', () {
      expect(SelecteurPeriode.visibles, [PeriodeRapide.aujourdhui, PeriodeRapide.hier, PeriodeRapide.personnalisee]);
      expect(SelecteurPeriode.autres, [PeriodeRapide.septJours, PeriodeRapide.ceMois, PeriodeRapide.moisDernier]);
      expect({...SelecteurPeriode.visibles, ...SelecteurPeriode.autres}, PeriodeRapide.values.toSet(), reason: 'aucune période perdue');
    });
  });

  group('Pilotage', () {
    test('période regardée lue dans « 01/10/2026 -> 16/10/2026 » (format du serveur) ou « du … au … »', () {
      expect(bornesPeriodePilotage('01/10/2026 -> 16/10/2026'), (DateTime(2026, 10, 1), DateTime(2026, 10, 16)));
      expect(bornesPeriodePilotage('du 01/09/2026 au 14/09/2026'), (DateTime(2026, 9, 1), DateTime(2026, 9, 14)));
      expect(bornesPeriodePilotage(''), isNull);
      expect(bornesPeriodePilotage('16/10/2026 -> 01/10/2026'), isNull, reason: 'fin avant le début');
    });

    test('courbe des 7 derniers jours : marge et nombre de ventes ; jours du plus ancien à aujourd\'hui', () {
      expect(ApiPilotage.clesCourbeSeptJours, {'marge', 'nbVentes'});
      final j = Periode7.jours(DateTime(2026, 3, 2, 18));
      expect(j.first, DateTime(2026, 2, 24));
      expect(j.last, DateTime(2026, 3, 2));
      expect(j, hasLength(7));
    });

    test('lignes « CA par emplacement » : libellé « (non renseigné) » = ligne sans emplacement', () {
      final r = RepartitionPilotage.depuis({'libelle': '(non renseigné)', 'ca': '1200', 'marge': 300, 'ventes': 2, 'part': 12.5});
      expect((r.sansLibelle, r.ca, r.part), (true, 1200, 12.5));
      expect(RepartitionPilotage.depuis({'libelle': 'RAYON A'}).sansLibelle, isFalse);
    });
  });

  group('Analyse des saisies de BL : temps de saisie', () {
    BonLivraisonStat bl(String creation, String? cloture, {String statut = 'is_Closed'}) => BonLivraisonStat.fromJson(
        {'strREFLIVRAISON': 'BL', 'dtDATELIVRAISON': creation, 'dtCREATED': creation, 'dtUPDATED': cloture, 'strSTATUT': statut, 'fournisseurLibelle': 'G'});

    test('création → clôture des BL CLÔTURÉS ; non clôturé, date manquante ou négative : rien', () {
      expect(bl('14/10/2026 08:00', '14/10/2026 08:25').tempsSaisie, const Duration(minutes: 25));
      expect(bl('14/10/2026 08:00', '14/10/2026 08:25', statut: 'enable').tempsSaisie, isNull);
      expect(bl('14/10/2026 08:00', null).tempsSaisie, isNull);
      expect(bl('14/10/2026 08:00', '14/10/2026 07:00').tempsSaisie, isNull);
    });

    test('moyenne des BL retenus ; plus de 24 h écartés et comptés à part', () {
      final r = AnalyseSaisiesBl.tempsSaisieMoyen([
        bl('14/10/2026 08:00', '14/10/2026 08:20'),
        bl('14/10/2026 09:00', '14/10/2026 09:40'),
        bl('13/10/2026 18:00', '15/10/2026 09:00'), // laissé ouvert
        bl('14/10/2026 10:00', null),
      ]);
      expect((r.moyenne, r.retenus, r.ecartes), (const Duration(minutes: 30), 2, 1));
      expect(AnalyseSaisiesBl.tempsSaisieMoyen(const []).moyenne, isNull);
      expect(AnalyseSaisiesBl.duree(const Duration(seconds: 30)), '< 1 min');
      expect(AnalyseSaisiesBl.duree(const Duration(minutes: 12)), '12 min');
      expect(AnalyseSaisiesBl.duree(const Duration(hours: 1, minutes: 5)), '1 h 05');
    });
  });

  group('Tableau : Analyses, jour par jour', () {
    TableauBordAchatsVentes j(int jour, double vente) => TableauBordAchatsVentes(dateMvt: DateTime(2026, 10, jour), montantAchat: 10, montantVente: vente);

    test('évolution des ventes : par rapport à la veille ; jour précédent de la liste nommé s\'il n\'est pas la veille', () {
      final l = [j(10, 100), j(11, 150), j(13, 75), j(14, 0)];
      expect(evolutionVeille(l, 0), isNull, reason: 'premier jour');
      expect(evolutionVeille(l, 1), (50.0, 'veille'));
      expect(evolutionVeille(l, 2), (-50.0, '11/10'), reason: 'dimanche fermé : comparé au samedi');
      expect(evolutionVeille([j(1, 0), j(2, 10)], 1), isNull, reason: 'veille sans vente : pas de pourcentage');
    });
  });

  test('Suggestions : « Créée le … · Réf. … » sur une ligne', () {
    final s = Suggestion(id: 'S', name: 'SUGG-01', status: 'pending', grossiste: 'G', dtCreated: DateTime(2026, 10, 12));
    expect(referenceSuggestion(s), 'Créée le 12-10-2026 · Réf. SUGG-01');
  });

  group('Tableau de bord par défaut (migration de la 3.11.0)', () {
    test('un choix d\'avant la 3.11.0 passe UNE fois au tableau de bord ; un choix fait ensuite est gardé', () async {
      SharedPreferences.setMockInitialValues({PresentationPrefs.cle: 'tableauDeBord'});
      expect(await PresentationPrefs.charger(), Presentation.tableauPrestige);
      await PresentationPrefs.enregistrer(Presentation.compact);
      expect(await PresentationPrefs.charger(), Presentation.compact);
    });

    test('appareil neuf : tableau de bord ; valeur inconnue : tableau de bord', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await PresentationPrefs.charger(), Presentation.tableauPrestige);
      SharedPreferences.setMockInitialValues({PresentationPrefs.cleMigration: true, PresentationPrefs.cle: 'inconnue'});
      expect(await PresentationPrefs.charger(), Presentation.tableauPrestige);
    });

    test('A, B, C et Automatique restent proposés', () {
      expect(Presentation.values, containsAll([Presentation.tableauDeBord, Presentation.compact, Presentation.guide, Presentation.automatique]));
      expect(Presentation.tableauPrestige.libelle, 'Tableau de bord');
    });
  });

  group('Menus', () {
    tearDown(() => ProfilAcces.utilisateur.value = null);

    test('« Evolution Stock » : dans la Valorisation pour le responsable, menu gardé pour les autres profils', () {
      ProfilAcces.utilisateur.value = utilisateur('dashboard');
      final r = menusAutorises().map((m) => m.titre);
      expect(r, contains('Valorisation'));
      expect(r, isNot(contains('Evolution Stock')));
      ProfilAcces.utilisateur.value = utilisateur('mainmenumanager');
      final a = menusAutorises().map((m) => m.titre);
      expect(a, contains('Evolution Stock'));
      expect(a, isNot(contains('Valorisation')));
    });

    test('menus réunis absents de la nouvelle interface ; Balance et Sur-stocks réservés au responsable', () {
      expect(menusModules.map((m) => m.titre), isNot(containsAll(menusFusionnes)));
      expect(menusRetiresNouvelle, containsAll(menusFusionnes));
      ProfilAcces.utilisateur.value = utilisateur('mainmenumanager');
      expect(menusAutorises().map((m) => m.titre), isNot(contains('Balance vente / caisse')));
      expect(menusAutorises().map((m) => m.titre), isNot(contains('Sur-stocks')));
    });
  });

  test('téléchargement : classeur .xls (OLE) du web accepté, comme le .xlsx ; faux classeur refusé', () {
    final api = ApiService();
    http.Response r(List<int> o) => http.Response.bytes(o, 200, headers: {'content-type': 'application/vnd.ms-excel'});
    expect(api.lireFichier(r([0xD0, 0xCF, 0x11, 0xE0, 1, 2])).octets.length, 6);
    expect(api.lireFichier(r(Uint8List.fromList('PK\x03\x04'.codeUnits))).octets.length, 4);
    expect(() => api.lireFichier(r('texte'.codeUnits)), throwsA(isA<ApiLoadException>()));
  });
}
