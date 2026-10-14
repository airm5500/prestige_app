// Captures PNG RÉELLES des modules refaits du lot 4 (« le reste »), pour la note de version. Lancées seulement à la
// demande (sinon sautées, pour ne pas dépendre des polices de la machine) :
//   CAPTURES_LOT4=1 flutter test test/lot4_captures_test.dart --update-goldens
// Fichiers produits : docs/maquettes/captures_lot4/*.png, téléphone 1080 × 2400 px (411 × 914 dp), plus des
// captures tablette 1920 × 1200 px (tableau dense). Même mécanisme que lot3_captures_test.dart.
// 3.6.1 : menu « Exporter » du Récap de caisse et PDF du ticket Z produit (1e_ticket_z_exemple.pdf, données fictives ;
// son aperçu PNG 1e_recap_caisse_pdf.png est tiré de ce PDF hors test), pages du journal (50 puis 100 sur 120),
// avertissement d'un serveur sans pagination.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/recap_caisse_pdf.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/services/api_service.dart';

import 'support/catalogue_ecrans.dart';
import 'support/donnees_lot4.dart';
import 'support/faux_serveur_prestige.dart';
import 'support/nouvelle_interface.dart';
import 'support/polices.dart';

final _actif = Platform.environment['CAPTURES_LOT4'] == '1';

Future<void> _chargerIcones() async {
  final dossier = dossierPolicesSdk();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(File('$dossier/MaterialIcons-Regular.otf').readAsBytesSync()))))
      .load();
}

void main() {
  final serveur = FauxServeurPrestige();

  setUpAll(() async {
    if (!_actif) return;
    await chargerPolicesReelles();
    await _chargerIcones();
    await serveur.demarrer();
  });
  tearDownAll(serveur.arreter);

  Future<void> preparer() async {
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..coupe = false;
    donneesAccueil(serveur);
    donneesLot4(serveur);
    preparerNouvelle(serveur, p: Presentation.automatique);
    ApiService.client = serveur.clientMemoire();
  }

  Future<void> appareil(WidgetTester tester, {bool tablette = false}) async {
    tester.view.devicePixelRatio = tablette ? 1.5 : 2.625;
    tester.view.physicalSize = tablette ? const Size(1920, 1200) : const Size(1080, 2400);
    addTearDown(tester.view.reset);
  }

  Future<void> pomper(WidgetTester tester, [int fois = 10]) async {
    for (var i = 0; i < fois; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> photo(WidgetTester tester, String nom) async {
    await pomper(tester, 6);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../docs/maquettes/captures_lot4/$nom.png'));
  }

  Future<void> fin(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
  }

  Future<void> ouvrir(WidgetTester tester, String tuile) async {
    final m = modulesLot4.firstWhere((x) => x.tuile == tuile);
    Navigator.of(tester.element(find.byType(AccueilNouveau))).push(MaterialPageRoute<void>(builder: (_) => m.nouveau()));
    await pomper(tester, 20);
  }

  Future<void> retour(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await pomper(tester, 6);
  }

  Future<void> toucher(WidgetTester tester, Finder f, [int fois = 8]) async {
    await tester.ensureVisible(f.first);
    await pomper(tester, 2);
    await tester.tap(f.first);
    await pomper(tester, fois);
  }

  Future<void> rechercher(WidgetTester tester, String texte) async {
    await tester.enterText(find.byKey(const Key('champ_recherche')), texte);
    await pomper(tester, 8);
    FocusManager.instance.primaryFocus?.unfocus();
    await pomper(tester, 3);
  }

  /// Amène [f] dans l'écran (liste [defilement]).
  Future<void> amener(WidgetTester tester, Finder f, {String defilement = 'defilement_module', double alignement = 0.12}) async {
    final s = find.descendant(of: find.byKey(Key(defilement)), matching: find.byType(Scrollable)).first;
    for (var i = 0; i < 40 && f.evaluate().isEmpty; i++) {
      await tester.drag(s, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await Scrollable.ensureVisible(tester.element(f.first), alignment: alignement);
    await pomper(tester, 3);
  }

  void profil(String type) => ProfilAcces.utilisateur.value = AppUser.fromJson({'str_USER_ID': 'USR-CAPTURE', 'str_LOGIN': 'capture', 'xtypeuser': type});

  testWidgets('captures des modules du lot 4', (tester) async {
    debugDisableShadows = false;
    await preparer();
    await appareil(tester);
    await connecterEnMemoire(tester);

    // 1. Récap de caisse : chiffres, totaux globaux, caissiers ; filtres (caissier, heures).
    await ouvrir(tester, 'Récap de caisse');
    await photo(tester, '1_recap_caisse');
    await amener(tester, find.byKey(const Key('caissier_${DonneesLot4.caissier1}')));
    await photo(tester, '1b_recap_caisse_caissiers');
    await toucher(tester, find.byKey(const Key('bouton_filtres')));
    await photo(tester, '1c_recap_caisse_filtres');
    await retour(tester);
    await toucher(tester, find.byKey(const Key('menu_exports')));
    await photo(tester, '1d_recap_caisse_exporter');
    final avant = RecapCaissePdf.sortie;
    ContenuTicketZ? contenu;
    RecapCaissePdf.sortie = (c, _) async => contenu = c;
    await toucher(tester, find.text('PDF du ticket Z'));
    RecapCaissePdf.sortie = avant;
    await tester.runAsync(() async =>
        File('docs/maquettes/captures_lot4/1e_ticket_z_exemple.pdf').writeAsBytesSync(await RecapCaissePdf.octets(contenu!)));
    await retour(tester);

    // 2. Achats fournisseurs : liste, filtre, détail, récapitulatif.
    await ouvrir(tester, 'Achats Fourn.');
    await photo(tester, '2_achats');
    await toucher(tester, find.byKey(const Key('bouton_filtres')));
    await photo(tester, '2b_achats_filtres');
    await retour(tester);
    await toucher(tester, find.text(DonneesLot4.fournisseurB));
    await photo(tester, '2c_achats_detail');
    await retour(tester);
    await toucher(tester, find.byKey(const Key('achats_recap')));
    await photo(tester, '2d_achats_recapitulatif');
    await retour(tester);
    await retour(tester);

    // 3. Fichier Journal : liste, filtres, détail ; pages de 50 ; serveur sans pagination.
    await ouvrir(tester, 'Fichier Journal');
    await photo(tester, '3_journal');
    await toucher(tester, find.byKey(const Key('bouton_filtres')));
    await photo(tester, '3b_journal_filtres');
    await retour(tester);
    await toucher(tester, find.text('Action fictive N2'));
    await photo(tester, '3c_journal_detail');
    await retour(tester);
    await retour(tester);
    // Pages de 50 : « Afficher plus » demande la page suivante au serveur.
    serveur.route('/common/logs', (r) => DonneesLot4.journalPour(r, nombre: 120), methode: 'GET');
    await ouvrir(tester, 'Fichier Journal');
    await amener(tester, find.byKey(const Key('bouton_afficher_plus')), alignement: 0.8);
    await photo(tester, '3d_journal_50_sur_120');
    await toucher(tester, find.byKey(const Key('bouton_afficher_plus')));
    await amener(tester, find.byKey(const Key('bouton_afficher_plus')), alignement: 0.8);
    await photo(tester, '3e_journal_100_sur_120');
    await retour(tester);
    // Serveur sans pagination (pas de « total ») : avertissement gardé.
    serveur.route('/common/logs', (r) => DonneesLot4.journalPour(r, nombre: 200, avecTotal: false), methode: 'GET');
    await ouvrir(tester, 'Fichier Journal');
    await photo(tester, '3f_journal_limite_serveur');
    await retour(tester);

    // 4. Annulation : recherche, détail, confirmation (vide puis complète), code administrateur, vente annulée.
    await ouvrir(tester, 'Annulation Ventes');
    await photo(tester, '4_annulation_accueil');
    await rechercher(tester, '261013');
    await photo(tester, '4b_annulation_recherche');
    await toucher(tester, find.byKey(const Key('vente_${DonneesLot4.idA}')), 12);
    await photo(tester, '4c_annulation_detail');
    await amener(tester, find.byKey(const Key('bouton_annuler_vente')), defilement: 'defilement_detail', alignement: 0.6);
    await photo(tester, '4d_annulation_detail_bas');
    profil('mainmenumanager');
    await toucher(tester, find.byKey(const Key('bouton_annuler_vente')));
    await photo(tester, '4e_annulation_confirmation_vide');
    await tester.enterText(find.byKey(const Key('confirmation_saisie')), 'ANNULER');
    await pomper(tester, 4);
    FocusManager.instance.primaryFocus?.unfocus();
    await pomper(tester, 4);
    await photo(tester, '4f_annulation_confirmation_complete');
    await toucher(tester, find.byKey(const Key('confirmation_oui')));
    await photo(tester, '4g_annulation_code_administrateur');
    await toucher(tester, find.text('Annuler'));
    profil('dashboard');
    await amener(tester, find.byKey(const Key('bouton_annuler_vente')), defilement: 'defilement_detail', alignement: 0.6);
    await toucher(tester, find.byKey(const Key('bouton_annuler_vente')));
    await tester.enterText(find.byKey(const Key('confirmation_saisie')), DonneesLot4.refA);
    await pomper(tester, 4);
    await toucher(tester, find.byKey(const Key('confirmation_oui')), 15);
    await amener(tester, find.byKey(const Key('resultat_annulation')), defilement: 'defilement_detail', alignement: 0.5);
    await photo(tester, '4h_annulation_vente_annulee');
    await retour(tester);
    await pomper(tester, 10);
    await photo(tester, '4i_annulation_liste_relue');
    await retour(tester);

    // 5. Droit manquant (Fichier Journal).
    serveur.quand('/common/logs', ReponseFausse.texte('Interdit', statut: 403), methode: 'GET');
    await ouvrir(tester, 'Fichier Journal');
    await photo(tester, '5_droit_manquant');
    await retour(tester);
    await fin(tester);

    // 6. Tablette : Achats (tableau dense avec total), Récap de caisse (totaux en tableau, caissiers sur deux colonnes).
    await preparer();
    await appareil(tester, tablette: true);
    await connecterEnMemoire(tester);
    await ouvrir(tester, 'Achats Fourn.');
    await photo(tester, '6_tablette_achats');
    await retour(tester);
    await ouvrir(tester, 'Récap de caisse');
    await photo(tester, '6b_tablette_recap_caisse');
    await retour(tester);
    profil('dashboard');
    await ouvrir(tester, 'Annulation Ventes');
    await rechercher(tester, '261013');
    await toucher(tester, find.text(DonneesLot4.refA), 12);
    await photo(tester, '6c_tablette_annulation_detail');
    await fin(tester);
    debugDisableShadows = true;
  }, skip: !_actif);
}
