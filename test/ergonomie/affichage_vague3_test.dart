// Ergonomie et cohérence des écrans de la vague 3 (nouvelle interface) : Pointage BL (invitation, pièces et totaux,
// saisie du N° de séquence et refus, droit manquant, aucune pièce), Avis (liste, feuille des filtres, analyse, détail
// avec et sans le droit de traiter, droit manquant), Rappels traitement (liste, sélection et barre « Marquer »,
// confirmation, feuille des filtres, analyse, liste vide, droit manquant), aux 5 tailles (téléphones 360×640 et
// 411×891 dp, Sunmi 720×1440 et 1080×1920 px, tablette 1920×1200 px) × texte 1,0 et 1,3. AUCUN écart toléré :
// débordement, exception de rendu, cible tactile < 48 dp ou sans libellé, contraste insuffisant.
// Cohérence (une taille) : barres bleu nuit, textes en Lato, aucune zone à l'ancien style.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague3/avis_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/pointage_vague3.dart';
import 'package:prestige_app/nouvelle_interface/vague3/rappels_vague3.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/cas_affichage_nouvelle.dart';
import '../support/donnees_vague3.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';
import 'affichage_vague1_test.dart' show responsable, toucherCle, puis;
import 'affichage_vague2_test.dart' show toucherApresDefilement;
import 'coherence_nouvelle_interface_test.dart' show ecartsAncienStyle;

CasAffichage cas(String nom, Widget Function() ecran,
        {Presentation p = Presentation.automatique, void Function(FauxServeurPrestige)? donnees, Future<void> Function(WidgetTester)? ensuite}) =>
    CasAffichage('Vague 3 · $nom', enNouvelle(ecranConnecte(ecran), p: p, donnees: responsable(p, donnees), ensuite: ensuite));

/// Saisit [texte] dans le champ [cle].
Future<void> Function(WidgetTester) saisir(String cle, String texte) => (tester) async {
      await tester.enterText(find.byKey(Key(cle)), texte);
      await tester.pump(const Duration(milliseconds: 300));
    };

const refusPointage = {'success': false, 'msg': 'Vous n\'avez pas le droit d\'accéder au pointage des BL.', 'interdit': true};
const refusAvis = {'success': false, 'msg': 'Vous n\'avez pas le droit d\'effectuer cette action.', 'interdit': true};
const refusRappels = {'success': false, 'msg': 'Vous n\'avez pas accès aux rappels de traitement.'};
final droits = DroitsAvis.depuis(DonneesVague3.droits());
final droitsLecture = DroitsAvis.depuis(DonneesVague3.droits(repondre: false));
const grossiste = DonneesVague3.grossiste;

final casVague3 = <CasAffichage>[
  cas('Pointage BL · choisir un grossiste', () => const PointageBlScreen()),
  cas('Pointage BL · pièces et totaux', () => const PointageBlScreen(grossisteInitial: grossiste)),
  cas('Pointage BL · saisie du N° de séquence', () => const PointageBlScreen(grossisteInitial: grossiste),
      ensuite: toucherApresDefilement('sequence_BL:BL-TEST-1', 'defilement_pointage')),
  cas('Pointage BL · N° de séquence refusé', () => const PointageBlScreen(grossisteInitial: grossiste),
      ensuite: puis([
        toucherApresDefilement('sequence_BL:BL-TEST-1', 'defilement_pointage'),
        saisir('saisie_pointage', 'S#12-TROP-LONG-POUR-LE-SERVEUR'),
        toucherCle('saisie_enregistrer'),
      ])),
  cas('Pointage BL · référence d\'avoir', () => const PointageBlScreen(grossisteInitial: grossiste),
      ensuite: toucherApresDefilement('avoir_RETOUR:RET-TEST-1', 'defilement_pointage')),
  cas('Pointage BL · aucune pièce', () => const PointageBlScreen(grossisteInitial: grossiste),
      donnees: (s) => s.quand('/pointage-bl', ReponseFausse.json({'success': true, 'data': <Object>[], 'total': 0}), methode: 'GET')),
  cas('Pointage BL · droit manquant', () => const PointageBlScreen(grossisteInitial: grossiste),
      donnees: (s) => s.quand('/pointage-bl', ReponseFausse.json(refusPointage), methode: 'GET')),
  cas('Avis · liste', () => const AvisScreen()),
  cas('Avis · feuille des filtres', () => const AvisScreen(), ensuite: toucherCle('bouton_filtres', attendre: const Duration(seconds: 2))),
  cas('Avis · analyse', () => const AvisScreen(ongletInitial: 1)),
  cas('Avis · détail à traiter', () => AvisDetailScreen(id: 'AVIS-TEST-1', droits: droits)),
  cas('Avis · détail sans le droit de traiter', () => AvisDetailScreen(id: 'AVIS-TEST-4', droits: droitsLecture)),
  cas('Avis · droit manquant', () => const AvisScreen(), donnees: (s) => s.quand('/avis-clients/droits', ReponseFausse.json(refusAvis), methode: 'GET')),
  cas('Avis · aucun avis', () => const AvisScreen(),
      donnees: (s) => s.quand('/avis-clients/liste', ReponseFausse.json({'success': true, 'total': 0, 'data': <Object>[]}), methode: 'GET')),
  cas('Rappels traitement · liste', () => const RappelsScreen()),
  cas('Rappels traitement · deux rappels choisis', () => const RappelsScreen(),
      ensuite: puis([toucherCle('choisir_RAP-TEST-1'), toucherCle('choisir_RAP-TEST-2')])),
  cas('Rappels traitement · confirmation « Marquer »', () => const RappelsScreen(),
      ensuite: puis([toucherCle('choisir_RAP-TEST-1'), toucherCle('marquer_PREPARE')])),
  cas('Rappels traitement · feuille des filtres', () => const RappelsScreen(), ensuite: toucherCle('bouton_filtres')),
  cas('Rappels traitement · analyse', () => const RappelsScreen(ongletInitial: 1)),
  cas('Rappels traitement · aucun rappel', () => const RappelsScreen(),
      donnees: (s) => s.quand('/rappels-habitude/liste', ReponseFausse.json({'success': true, 'total': 0, 'data': <Object>[]}), methode: 'GET')),
  cas('Rappels traitement · droit manquant', () => const RappelsScreen(),
      donnees: (s) => s.quand('/rappels-habitude/liste', ReponseFausse.json(refusRappels), methode: 'GET')),
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

  tearDown(() {
    ProfilAcces.utilisateur.value = null;
    expect(requetesInterditesVague3(serveur), isEmpty);
  });

  for (final c in casVague3) {
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
    for (final c in casVague3) {
      testWidgets(c.nom, (tester) async {
        simulerAppareil(tester, profilsAppareils[1], 1.0);
        await c.ouvrir(tester, serveur);
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
