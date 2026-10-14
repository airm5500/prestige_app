// Ergonomie et cohérence des écrans de la vague 2 (nouvelle interface) : Prévisions (3 onglets, détail, équivalents,
// analyse), onglet Pilotage de la barre du bas (synthèse, comparaison, À suivre, confirmation du contrôle, droit
// manquant), Analyse de garde (liste, synthèse, produits, vendeurs), CA emplacement / famille (comparatif, feuille
// des filtres, 3 ans en cours de calcul, détail), aux 5 tailles (téléphones 360×640 et 411×891 dp, Sunmi
// 720×1440 et 1080×1920 px, tablette 1920×1200 px) × texte 1,0 et 1,3. AUCUN écart toléré : débordement,
// exception de rendu, cible tactile < 48 dp ou sans libellé, contraste insuffisant.
// Cohérence (une taille) : barres bleu nuit, textes en Lato, aucune zone à l'ancien style.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/charte.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague2/ca_zone_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/donnees_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/garde_vague2.dart';
import 'package:prestige_app/nouvelle_interface/vague2/previsions_vague2.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/cas_affichage_nouvelle.dart';
import '../support/donnees_vague2.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';
import 'affichage_vague1_test.dart' show responsable, toucherCle, puis;
import 'coherence_nouvelle_interface_test.dart' show ecartsAncienStyle;

Future<void> Function(WidgetTester) ongletAccueil(String nom) => (tester) async {
      await ouvrirOnglet(tester, nom);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    };

/// Onglet interne d'un écran (TabBar), rendu visible puis touché.
Future<void> Function(WidgetTester) ongletEcran(String nom) => (tester) async {
      final cible = find.descendant(of: find.byType(TabBar), matching: find.text(nom)).first;
      await tester.ensureVisible(cible);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(cible);
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    };

/// Fait défiler [defilement] jusqu'à construire [cle] (liste paresseuse), puis la touche.
Future<void> Function(WidgetTester) toucherApresDefilement(String cle, String defilement) => (tester) async {
      final f = find.byKey(Key(cle));
      final s = find.descendant(of: find.byKey(Key(defilement)), matching: find.byType(Scrollable)).first;
      for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
        await tester.drag(s, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await toucherCle(cle)(tester);
    };

CasAffichage cas(String nom, Widget Function() ecran,
        {Presentation p = Presentation.automatique, void Function(FauxServeurPrestige)? donnees, Future<void> Function(WidgetTester)? ensuite}) =>
    CasAffichage('Vague 2 · $nom', enNouvelle(ecranConnecte(ecran), p: p, donnees: responsable(p, donnees), ensuite: ensuite));

const refusPrevisions = {'success': false, 'msg': 'Vous n\'avez pas accès à l\'analyse des commandes.'};
final element = ElementAAnalyser.depuis(Map<String, dynamic>.from((DonneesVague2.aAnalyser()['data']! as List).first as Map));
final garde = Garde.depuis(Map<String, dynamic>.from(DonneesVague2.garde('GARDE-TEST-1', 'Garde du 05/09', '2026-09-05 20:00', '2026-09-06 08:00')));
final comparatif = ComparatifCa.depuis(Map<String, dynamic>.from(DonneesVague2.caZone({'typePeriode': 'TROIS_MOIS', 'regroupement': 'ZONE_FAMILLE'})));

final casVague2 = <CasAffichage>[
  cas('Accueil A avec onglet Pilotage', () => const AccueilNouveau(), p: Presentation.tableauDeBord),
  cas('Pilotage · synthèse', () => const AccueilNouveau(), p: Presentation.tableauDeBord, ensuite: ongletAccueil('Pilotage')),
  cas('Pilotage · comparaison au mois précédent', () => const AccueilNouveau(),
      p: Presentation.tableauDeBord, ensuite: puis([ongletAccueil('Pilotage'), toucherCle('axe_VS_M1')])),
  cas('Pilotage · À suivre', () => const AccueilNouveau(), p: Presentation.tableauDeBord, ensuite: puis([ongletAccueil('Pilotage'), ongletEcran('À suivre')])),
  cas('Pilotage · confirmation du contrôle', () => const AccueilNouveau(),
      p: Presentation.tableauDeBord, ensuite: puis([ongletAccueil('Pilotage'), toucherApresDefilement('pilotage_controler', 'defilement_pilotage')])),
  cas('Pilotage · droit manquant', () => const AccueilNouveau(),
      p: Presentation.tableauDeBord,
      donnees: (s) => s.quand('/pilotage/onglet/synthese', ReponseFausse.json({'success': false, 'message': 'Votre profil ne donne pas accès au pilotage.'})),
      ensuite: ongletAccueil('Pilotage')),
  cas('Pilotage · menu latéral (B)', () => const AccueilNouveau(), p: Presentation.compact),
  cas('Prévisions · liste', () => const PrevisionsScreen()),
  cas('Prévisions · feuille des filtres', () => const PrevisionsScreen(), ensuite: toucherCle('bouton_filtres')),
  cas('Prévisions · pas encore calculées', () => const PrevisionsScreen(),
      donnees: (s) => s.quand('/analyse-commande/tableau', ReponseFausse.json({'success': true, 'calcule': false}))),
  cas('Prévisions · droit manquant', () => const PrevisionsScreen(),
      donnees: (s) => s
        ..quand('/analyse-commande/tableau', ReponseFausse.json(refusPrevisions))
        ..quand('/analyse-commande/previsions', ReponseFausse.json(refusPrevisions))),
  cas('Prévisions · serveur injoignable', () => const PrevisionsScreen(), donnees: (s) => s.coupe = true),
  cas('Prévisions · détail produit', () => const DetailPrevisionScreen(id: 'PRD-PREV-2')),
  cas('Prévisions · équivalents', () => const DetailPrevisionScreen(id: 'PRD-PREV-2'), ensuite: toucherApresDefilement('bouton_equivalents', 'defilement_detail_prevision')),
  cas('Prévisions · suggestions et commandes', () => const PrevisionsScreen(ongletInitial: 1)),
  cas('Prévisions · analyse d\'une suggestion', () => AnalyseSuggestionScreen(element: element)),
  cas('Prévisions · demande (invitation)', () => const PrevisionsScreen(ongletInitial: 2)),
  cas('Prévisions · demande 24 mois calculée', () => const PrevisionsScreen(ongletInitial: 2),
      ensuite: puis([toucherCle('demande_mois_24'), toucherCle('demande_calculer')])),
  cas('Prévisions · demande 36 mois en cours (annulable)', () => const PrevisionsScreen(ongletInitial: 2),
      donnees: (s) => s.quand('/analyse-commande/demande', ReponseFausse.json(DonneesVague2.demande(36)).apres(const Duration(seconds: 30))),
      ensuite: puis([toucherCle('demande_mois_36'), toucherCle('demande_calculer')])),
  cas('Analyse de garde · liste', () => const AnalyseGardeScreen()),
  cas('Analyse de garde · aucune garde', () => const AnalyseGardeScreen(),
      donnees: (s) => s.quand('/gardes', ReponseFausse.json({'success': true, 'total': 0, 'data': <Object>[]}))),
  cas('Analyse de garde · synthèse', () => GardeDetailScreen(garde: garde)),
  cas('Analyse de garde · produits', () => GardeDetailScreen(garde: garde), ensuite: ongletEcran('Produits')),
  cas('Analyse de garde · vendeurs', () => GardeDetailScreen(garde: garde), ensuite: ongletEcran('Vendeurs')),
  cas('CA emplacement / famille · 3 semaines', () => const CaZoneScreen()),
  cas('CA emplacement / famille · emplacement et famille, 3 mois',
      () => const CaZoneScreen(filtresInitiaux: FiltresCa(type: TypePeriodeCa.troisMois, regroupement: RegroupementCa.zoneFamille))),
  cas('CA emplacement / famille · feuille des filtres', () => const CaZoneScreen(), ensuite: toucherCle('bouton_filtres', attendre: const Duration(seconds: 2))),
  cas('CA emplacement / famille · 3 ans en cours', () => const CaZoneScreen(filtresInitiaux: FiltresCa(type: TypePeriodeCa.troisAns)),
      donnees: (s) => s.route('/ca-zone-geo', (r) => ReponseFausse.json(DonneesVague2.caZone(r.parametres)).apres(const Duration(seconds: 30)), methode: 'GET')),
  cas('CA emplacement / famille · erreur du serveur', () => const CaZoneScreen(),
      donnees: (s) => s.quand('/ca-zone-geo', ReponseFausse.json({'success': false, 'msg': 'Le calcul du chiffre d\'affaires a échoué'}))),
  cas('CA emplacement / famille · détail d\'une ligne',
      () => CaLigneDetailScreen(
          filtres: const FiltresCa(type: TypePeriodeCa.troisMois, regroupement: RegroupementCa.zoneFamille),
          ligne: comparatif.lignes.first,
          tranches: comparatif.tranches)),
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
    expect(requetesInterdites(serveur), isEmpty);
  });

  for (final c in casVague2) {
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
    for (final c in casVague2) {
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
