// Ergonomie et cohérence des écrans de la vague 1 (nouvelle interface) : chaque écran et ses états (rempli, vide,
// erreur, droit manquant, onglets, détail, feuille de choix) et l'accueil A / B / C d'un compte administrateur /
// pharmacien, aux 5 tailles (téléphones 360×640 et 411×891 dp, Sunmi 720×1440 et 1080×1920 px, tablette
// 1920×1200 px) × texte 1,0 et 1,3. AUCUN écart toléré (écrans propres à la nouvelle interface) : débordement,
// exception de rendu, cible tactile < 48 dp ou sans libellé, contraste insuffisant.
// Cohérence (une taille) : barres bleu nuit, textes en Lato, aucune zone à l'ancien style (couleurs d'origine,
// lavande Material).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/alertes_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/journaux_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague1/valorisation_vague1.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/utils/constants.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/cas_affichage_nouvelle.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import 'coherence_nouvelle_interface_test.dart' show ecartsAncienStyle;
import '../support/polices.dart';

/// Compte administrateur / pharmacien déjà connu de l'appareil (profil « dashboard ») : nouveaux menus visibles.
void Function(FauxServeurPrestige) responsable(Presentation p, [void Function(FauxServeurPrestige)? donnees]) => (s) {
      preparerTelephone(s, nouvelle: true, presentation: p, autres: {AppConstants.userDataKey: jsonEncode(DonneesFictives.utilisateur())});
      donneesAccueilVague1(s);
      listesCommunesVague1(s);
      donnees?.call(s);
    };

void donneesAccueilVague1(FauxServeurPrestige s) {
  s.quand('/recap/dashboard', ReponseFausse.json(DonneesFictives.recapDuJour()), methode: 'GET');
  s.route('/rh/presence', (r) => ReponseFausse.json(DonneesFictives.presenceEquipe(r.parametres['jour'] ?? '2026-10-13')), methode: 'GET');
}

Future<void> Function(WidgetTester) toucherCle(String cle, {Duration attendre = const Duration(milliseconds: 1500)}) => (tester) async {
      final f = find.byKey(Key(cle));
      await tester.ensureVisible(f.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(f.first);
      for (var i = 0; i < attendre.inMilliseconds ~/ 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    };

Future<void> Function(WidgetTester) toucherTexte(String texte) => (tester) async {
      await tester.tap(find.text(texte).first);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    };

Future<void> Function(WidgetTester) puis(List<Future<void> Function(WidgetTester)> etapes) => (tester) async {
      for (final e in etapes) {
        await e(tester);
      }
    };

final hier = DateTime.now().subtract(const Duration(days: 1));

CasAffichage cas(String nom, Widget Function() ecran,
        {Presentation p = Presentation.automatique, void Function(FauxServeurPrestige)? donnees, Future<void> Function(WidgetTester)? ensuite}) =>
    CasAffichage('Vague 1 · $nom', enNouvelle(ecranConnecte(ecran), p: p, donnees: responsable(p, donnees), ensuite: ensuite));

final casVague1 = <CasAffichage>[
  cas('Accueil A (responsable)', () => const AccueilNouveau(), p: Presentation.tableauDeBord),
  cas('Accueil A · alertes comptées', () => const AccueilNouveau(),
      p: Presentation.tableauDeBord, ensuite: compterAlertes(['alerte_peremption_nombre', 'alerte_ruptures_nombre', 'alerte_toutes_resume'])),
  cas('Accueil B (responsable)', () => const AccueilNouveau(), p: Presentation.compact),
  cas('Accueil C (responsable)', () => const AccueilNouveau(), p: Presentation.guide),
  cas('Tous les menus C (responsable)', () => const TousLesMenusScreen(), p: Presentation.guide),
  cas('Valorisation (aujourd\'hui)', () => const ValorisationVague1()),
  cas('Valorisation · onglet Total', () => const ValorisationVague1(), ensuite: toucherTexte('Total')),
  cas('Valorisation · regroupement Famille', () => const ValorisationVague1(modeInitial: ModeValorisation.famille)),
  cas('Valorisation · choix des familles', () => const ValorisationVague1(modeInitial: ModeValorisation.famille),
      ensuite: toucherCle('valorisation_choix')),
  cas('Valorisation · date passée calculée', () => ValorisationVague1(dateInitiale: hier), ensuite: toucherCle('valorisation_calculer')),
  cas('Valorisation · relevé indisponible', () => ValorisationVague1(dateInitiale: hier),
      donnees: (s) => s.quand('/produit/valorisation', ReponseFausse.json(DonneesVague1.valorisationProduit(releve: false))),
      ensuite: toucherCle('valorisation_calculer')),
  cas('Valorisation · droit manquant', () => const ValorisationVague1(),
      donnees: (s) => s.quand('/tableau-bord/valorisation', ReponseFausse.json({'success': false, 'interdit': true}))),
  cas('Alertes · invitation', () => const AlertesScreen()),
  cas('Alertes · comptées', () => const AlertesScreen(), ensuite: toucherCle('alertes_compter')),
  cas('Alertes · erreur du serveur', () => const AlertesScreen(),
      donnees: (s) => s.quand('/tableau-bord/alertes', ReponseFausse.erreurServeur()), ensuite: toucherCle('alertes_compter')),
  cas('Alertes · droit manquant', () => const AlertesScreen(),
      donnees: (s) => s.quand('/tableau-bord/alertes', ReponseFausse.json({'success': false, 'msg': 'Accès refusé.'})),
      ensuite: toucherCle('alertes_compter')),
  cas('Liste · ruptures', () => const AlerteListeScreen(type: TypeAlerte.ruptures)),
  cas('Liste · péremptions', () => const AlerteListeScreen(type: TypeAlerte.peremptions)),
  cas('Liste · entrés jamais vendus', () => const AlerteListeScreen(type: TypeAlerte.nonVendus)),
  cas('Liste · vide', () => const AlerteListeScreen(type: TypeAlerte.negatifs),
      donnees: (s) => s.quand('/tableau-bord/alertes/liste', ReponseFausse.json({'type': 'negatifs', 'data': <Object>[]}))),
  cas('Retraits et abandons', () => const RetraitsAbandonsScreen()),
  cas('Retraits et abandons · vide', () => const RetraitsAbandonsScreen(),
      donnees: (s) => s.quand('/vente-suppressions', ReponseFausse.json({'total': 0, 'results': <Object>[]}))),
  cas('Retraits et abandons · serveur injoignable', () => const RetraitsAbandonsScreen(), donnees: (s) => s.coupe = true),
  cas('Ventes modifiées', () => const VentesModifieesScreen()),
  cas('Ventes modifiées · droit manquant', () => const VentesModifieesScreen(),
      donnees: (s) => s.quand('/ventes-modifiees', ReponseFausse.json({'success': false, 'interdit': true}))),
  cas('Ventes modifiées · détail', () => VenteModifieeDetailScreen(vente: VenteModifiee.depuis(Map<String, dynamic>.from(DonneesVague1.ventesModifiees().first)))),
  cas('Ventes modifiées · détail sans lignes', () => VenteModifieeDetailScreen(vente: VenteModifiee.depuis(Map<String, dynamic>.from(DonneesVague1.ventesModifiees()[1])))),
];

void main() {
  final serveur = FauxServeurPrestige();

  setUpAll(() async {
    await chargerPolicesReelles();
    await serveur.demarrer(); // seulement pour connaître un port ; les requêtes passent « en mémoire »
  });
  tearDownAll(serveur.arreter);

  setUp(() {
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..coupe = false;
    preparerTelephone(serveur, nouvelle: true);
    ApiService.client = serveur.clientMemoire();
  });

  tearDown(() => ProfilAcces.utilisateur.value = null);

  for (final c in casVague1) {
    group('Ergonomie · ${c.nom}', () {
      for (final profil in profilsAppareils) {
        for (final echelle in echellesTexte) {
          testWidgets('$profil · texte ×$echelle', (tester) async {
            simulerAppareil(tester, profil, echelle);
            final semantique = tester.ensureSemantics();
            final ecarts = <String>[];
            ecarts.addAll(await releverErreurs(() => c.ouvrir(tester, serveur)));
            ecarts.addAll(await evaluerAccessibilite(tester));
            semantique.dispose();
            ecarts.addAll(await releverErreurs(() async {
              await tester.pump(const Duration(seconds: 3));
              await tester.pumpWidget(const SizedBox());
              await tester.pump(const Duration(minutes: 2));
            }));
            expect(ecarts.toSet(), isEmpty, reason: '${c.nom} · $profil · texte ×$echelle :\n${ecarts.toSet().join('\n')}');
          });
        }
      }
    });
  }

  group('Cohérence (charte bleu nuit / ambre, Lato, aucun ancien style)', () {
    for (final c in casVague1) {
      testWidgets(c.nom, (tester) async {
        simulerAppareil(tester, profilsAppareils[1], 1.0);
        await c.ouvrir(tester, serveur);
        if (c.nom.contains('Accueil A') || c.nom.contains('Accueil B')) {
          expect(find.text('Retraits et abandons'), findsWidgets, reason: 'nouveaux menus visibles pour le responsable');
        }
        final ecarts = <String>[];
        for (final barre in find.byType(AppBar).evaluate()) {
          final m = find.descendant(of: find.byWidget(barre.widget), matching: find.byType(Material)).evaluate().first.widget as Material;
          if (m.color != Charte.navy) ecarts.add('barre de couleur ${m.color} (attendu bleu nuit)');
        }
        for (final e in find.byType(RichText).evaluate()) {
          void visiter(InlineSpan s, String? herite) {
            final famille = s.style?.fontFamily ?? herite;
            if (s is TextSpan) {
              if ((s.text ?? '').trim().isNotEmpty && !(famille ?? '').startsWith('Lato') && famille != 'MaterialIcons') {
                ecarts.add('texte en police « $famille » : « ${s.text!.trim()} »');
              }
              for (final enfant in s.children ?? const <InlineSpan>[]) {
                visiter(enfant, famille);
              }
            }
          }

          visiter((e.widget as RichText).text, null);
        }
        ecarts.addAll(ecartsAncienStyle(tester));
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(minutes: 2));
        expect(ecarts.toSet(), isEmpty, reason: '${c.nom} :\n${ecarts.toSet().join('\n')}');
      });
    }
  });
}
