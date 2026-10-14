// ERGONOMIE — Taille de l'écran (3.7.0, docs/TAILLE_ECRAN.md), application ENTIÈRE (applicationPrestige →
// RacineTailleEcran → MaterialApp, comme main()), faux serveur Prestige en mémoire, polices réelles.
//
// 1. Sunmi V2s 720×1440 px (360 × 720 dp) aux 3 tailles : Automatique (Compact appliqué d'office : 400 dp vus par
//    l'interface), Compact (400 dp, texte 1,0 et 1,3), Très compact (450 dp, texte 1,0 et 1,3) — écrans principaux
//    de la nouvelle interface (connexion A / B, accueil A / B / C, barre du bas à 3 et à 4 onglets, onglets
//    Analyses / Équipe / Pilotage, Réglages, Tous les menus, modules avec graphiques fl_chart, feuilles du bas,
//    menus Exporter, calendrier) : l'interface remplit exactement l'écran réel (rien de coupé, pas de bande vide),
//    aucun débordement ni exception, cibles ≥ 48 dp DE L'INTERFACE, libellés, contraste. Mêmes tolérances que
//    ergonomie/affichage_nouvelle_interface_test.dart (aucune sur les écrans propres à la nouvelle interface).
// 2. Autres appareils en Automatique : Sunmi V3 360 × 640 dp → Compact (400 dp) ; téléphones 1080 × 2400 et
//    tablette 1920 × 1200 : RIEN ne change (aucune réduction, menu latéral de la tablette inchangé).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/rapport_activite_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/services/api_service.dart';
import 'package:prestige_app/ui/taille_ecran.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/cas_affichage_nouvelle.dart';
import '../support/ecarts_connus.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';
import 'affichage_vague2_test.dart' show casVague2;

const _v2s = ProfilAppareil('Sunmi V2s 720×1440 px', Size(720, 1440), 2.0);
const _v3 = ProfilAppareil('Sunmi V3 1080×1920 px ×3', Size(1080, 1920), 3.0);
const _telephone = ProfilAppareil('Téléphone 1080×2400 px ×2,625', Size(1080, 2400), 2.625);
const _samsung = ProfilAppareil('Téléphone 1080×2400 px ×3', Size(1080, 2400), 3.0);
const _tablette = ProfilAppareil('Tablette 1920×1200 px', Size(1920, 1200), 1.5);

/// Écrans principaux de la nouvelle interface (noms des cas de support/cas_affichage_nouvelle.dart et de la vague 2).
const _principaux = <String>[
  'Connexion A',
  'Connexion B',
  'Accueil A',
  'Accueil B',
  'Accueil C',
  'Onglet Analyses',
  'Onglet Équipe',
  'Réglages (bouton engrenage)',
  'Tous les menus (C)',
  'Lot 1 · Rapport d\'Activité rempli',
  'Lot 1 · Suivi Crédit filtres',
  'Lot 1 · Suivi Péremption menu Exporter',
  'Lot 2 · Évolution stock remplie',
  'Lot 3 · Analyses rempli',
  'Lot 3 · Analyses valeur au toucher',
  'Lot 3 · Stat TVA rempli',
  'Lot 4 · Récap de caisse rempli',
  'Lot 4 · Récap de caisse menu Exporter',
  'Vague 2 · Accueil A avec onglet Pilotage',
  'Vague 2 · Pilotage · synthèse',
];

/// Calendrier (sélecteur de période commun, « Personnalisée ») ouvert depuis le Rapport d'Activité.
final _calendrier = CasAffichage(
  'Calendrier (période personnalisée)',
  enNouvelle(ecranConnecte(() => const RapportActiviteNouveau()), donnees: donneesLot1, ensuite: (tester) async {
    await tester.ensureVisible(find.byKey(const Key('periode_personnalisee')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('periode_personnalisee')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
  }),
);

/// Cases des jours du calendrier de Material (showDateRangePicker) : leur hauteur est fixée par Flutter, à toutes
/// les tailles (aussi sur un téléphone 1080 × 2400 sans réduction : voir le test « calendrier … taille normale »).
bool _jourDuCalendrier(String ecart) =>
    ecart.startsWith('cible tactile < 48 dp : « ') && RegExp(r'« (Date de \S+\s*:\s*)?\d+, \S+\s\d+\s\S+\s\d{4}').hasMatch(ecart);

final _communsNouvelle = ecartsConnusCommuns.keys.where((k) => !k.contains('2EBF91')).toList();
bool _toleree(String ecran, String ecart) =>
    _communsNouvelle.any(ecart.contains) || (ecartsConnus[ecran] ?? const []).any(ecart.startsWith);

/// L'interface remplit exactement l'écran réel : rien de coupé à droite ni en bas, pas de bande vide.
List<String> _remplitEcran(WidgetTester tester) {
  final reel = tester.view.physicalSize / tester.view.devicePixelRatio;
  final r = tester.getRect(find.byType(Navigator).first);
  if (r.left.abs() + r.top.abs() > 0.01 || (r.width - reel.width).abs() > 0.01 || (r.height - reel.height).abs() > 0.01) {
    return ['interface $r ≠ écran réel $reel'];
  }
  return const [];
}

/// Taille vue par l'interface (MediaQuery sous la racine).
Size _surface(WidgetTester tester) => MediaQuery.sizeOf(tester.element(find.byType(Navigator).first));

void main() {
  final serveur = FauxServeurPrestige();
  final tous = [...casAffichageNouvelle, ...casVague2];
  final cas = [for (final n in _principaux) tous.firstWhere((c) => c.nom == n, orElse: () => throw StateError('cas inconnu : $n')), _calendrier];

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
    tailleEcranPreparee = TailleEcran.automatique;
    TailleEcranReglage.reinitialiser();
  });

  /// Rend [c] sur [profil] avec la taille [reglage] ; renvoie les écarts non tolérés et vérifie la surface vue.
  Future<void> rendre(WidgetTester tester, CasAffichage c, ProfilAppareil profil, TailleEcran reglage, double echelle) async {
    simulerAppareil(tester, profil, echelle);
    tailleEcranPreparee = reglage;
    final semantique = tester.ensureSemantics();
    final ecarts = <String>[];
    ecarts.addAll(await releverErreurs(() => c.ouvrir(tester, serveur)));
    final facteur = TailleEcranReglage.effective(reglage, profil.dp).facteur;
    expect(TailleEcranReglage.active.value, reglage);
    final vue = _surface(tester);
    expect(vue.width, closeTo(profil.dp.width / facteur, 0.01), reason: '${c.nom} : largeur vue par l\'interface');
    expect(vue.height, closeTo(profil.dp.height / facteur, 0.01), reason: '${c.nom} : hauteur vue par l\'interface');
    ecarts.addAll(_remplitEcran(tester));
    ecarts.addAll(await evaluerAccessibilite(tester));
    semantique.dispose();
    ecarts.addAll(await releverErreurs(() async {
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    }));
    final propre = !modulesOuEtats.contains(c.nom);
    final nouveaux = ecarts.toSet().where((e) => (propre || !_toleree(c.nom, e)) && !(c == _calendrier && _jourDuCalendrier(e))).toList();
    expect(nouveaux, isEmpty, reason: '${c.nom} · $profil · ${reglage.libelle} · texte ×$echelle :\n${nouveaux.join('\n')}');
  }

  // ---------------------------------------------------------------------------
  // 1. Écrans principaux sur Sunmi V2s aux trois tailles
  // ---------------------------------------------------------------------------
  final configurations = <(TailleEcran, double)>[
    (TailleEcran.automatique, 1.0),
    (TailleEcran.compact, 1.0),
    (TailleEcran.compact, 1.3),
    (TailleEcran.tresCompact, 1.0),
    (TailleEcran.tresCompact, 1.3),
  ];
  for (final (reglage, echelle) in configurations) {
    final largeur = _v2s.dp.width / TailleEcranReglage.effective(reglage, _v2s.dp).facteur;
    group('Sunmi V2s · ${reglage.libelle} · texte ×$echelle', () {
      for (final c in cas) {
        testWidgets('${c.nom} : ${largeur.toStringAsFixed(0)} dp de large, rien de coupé ni débordé', (tester) async {
          await rendre(tester, c, _v2s, reglage, echelle);
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Témoin : le contraste mesuré dans l'interface réduite repère toujours un texte trop pâle
  // ---------------------------------------------------------------------------
  for (final reglage in [TailleEcran.compact, TailleEcran.tresCompact]) {
    testWidgets('témoin ${reglage.libelle} : gris #5F6368 sur blanc accepté, gris #BDBDBD sur blanc refusé', (tester) async {
      simulerAppareil(tester, _v2s, 1.0);
      TailleEcranReglage.enregistree = reglage;
      TailleEcranReglage.appliquerMaintenant();
      final semantique = tester.ensureSemantics();
      Future<List<String>> ecarts(Color couleur) async {
        await tester.pumpWidget(RacineTailleEcran(
          child: MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(child: Text('Serveur local · Pharmacie', style: TextStyle(fontSize: 13, color: couleur))),
            ),
          ),
        ));
        return evaluerAccessibilite(tester, guides: {'contraste du texte insuffisant'});
      }

      expect(await ecarts(const Color(0xFF5F6368)), isEmpty, reason: '6,0:1');
      expect(await ecarts(const Color(0xFFBDBDBD)), hasLength(1), reason: '1,8:1');
      semantique.dispose();
    });
  }

  // ---------------------------------------------------------------------------
  // 2. Autres appareils en Automatique
  // ---------------------------------------------------------------------------
  group('Automatique sur les autres appareils', () {
    final accueilA = tous.firstWhere((c) => c.nom == 'Accueil A');
    final pilotage = tous.firstWhere((c) => c.nom == 'Vague 2 · Accueil A avec onglet Pilotage');

    testWidgets('Sunmi V3 360 × 640 dp : Compact appliqué (400 dp vus), accueil A sans écart', (tester) async {
      await rendre(tester, accueilA, _v3, TailleEcran.automatique, 1.0);
    });

    for (final profil in [_telephone, _samsung]) {
      testWidgets('$profil : rien ne change (aucune réduction), barre du bas à 4 onglets sans écart', (tester) async {
        expect(TailleEcranReglage.petitEcran(profil.dp), isFalse);
        await rendre(tester, pilotage, profil, TailleEcran.automatique, 1.0);
      });
    }

    testWidgets('calendrier sur un téléphone 1080 × 2400 à la taille normale : cases des jours déjà < 48 dp (Material)',
        (tester) async {
      simulerAppareil(tester, _telephone, 1.0);
      final semantique = tester.ensureSemantics();
      await _calendrier.ouvrir(tester, serveur);
      expect(facteurEcran(tester), 1.0);
      final cibles = await evaluerAccessibilite(tester, guides: {'cible tactile < 48 dp'});
      semantique.dispose();
      expect(cibles.where(_jourDuCalendrier), isNotEmpty, reason: 'grille du calendrier de Flutter, indépendante du réglage');
      expect(cibles.where((e) => !_jourDuCalendrier(e)), isEmpty);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    });

    testWidgets('tablette 1920 × 1200 : rien ne change, menu latéral (B) au lieu de la barre du bas', (tester) async {
      simulerAppareil(tester, _tablette, 1.0);
      preparerNouvelle(serveur, p: Presentation.automatique);
      donneesAccueil(serveur);
      serveur.controlerSession = false;
      await lancerApplication(tester, accueil: const AccueilNouveau());
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(_surface(tester), const Size(1280, 800));
      expect(_remplitEcran(tester), isEmpty);
      expect(find.byKey(const Key('barre_accueil')), findsNothing, reason: 'tablette : menu latéral');
      expect(find.byKey(const Key('defilement_menus')), findsOneWidget, reason: 'présentation B automatique');
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 2));
    });
  });
}
