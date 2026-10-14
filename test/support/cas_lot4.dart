// États des modules refaits du LOT 4 (« le reste » : Récap de caisse, Achats Fourn., Fichier Journal, Annulation
// Ventes) rendus par les tests d'ergonomie et de cohérence de la nouvelle interface : écrans remplis, feuilles de
// filtres, détails, récapitulatif, limite du journal, détail d'une vente, confirmation renforcée (vide et complète),
// code administrateur, vente annulée, erreurs. Écrans propres à la nouvelle interface : aucun écart toléré.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/models/user_model.dart';
import 'package:prestige_app/nouvelle_interface/modules/achats_fournisseurs_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/annulation_ventes_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/fichier_journal_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/recap_caisse_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/utils/constants.dart';

import 'cas_affichage.dart';
import 'cas_affichage_nouvelle.dart';
import 'cas_lot2.dart' show puis;
import 'cas_lot3.dart' show defilerPuisToucher;
import 'donnees_lot4.dart';
import 'faux_serveur_prestige.dart';

Future<void> Function(WidgetTester, FauxServeurPrestige) _lot4(Widget Function() ecran,
        {Future<void> Function(WidgetTester)? ensuite, void Function(FauxServeurPrestige)? donnees, String? recherche}) =>
    enNouvelle(ecranConnecte(ecran, recherche: recherche), donnees: (s) {
      donneesLot4(s);
      donnees?.call(s);
    }, ensuite: ensuite);

Future<void> _filtres(WidgetTester tester) => toucher(find.byKey(const Key('bouton_filtres')))(tester);

/// Recherche de la vente A puis ouverture de son détail.
final Future<void> Function(WidgetTester) _ouvrirVenteA =
    defilerPuisToucher(() => find.textContaining(DonneesLot4.refA), attendu: 'defilement_detail');

Future<void> _demanderAnnulation(WidgetTester tester) async {
  await defilerPuisToucher(() => find.byKey(const Key('bouton_annuler_vente')), defilement: 'defilement_detail', attendu: 'confirmation_annulation')(tester);
}

Future<void> _saisirAnnuler(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('confirmation_saisie')), 'ANNULER');
  // Le bouton s'active : sa couleur de texte change en fondu (200 ms), il faut deux images.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Compte connecté de profil [type] : « dashboard » (administrateur, pharmacien) ou autre (code administrateur
/// demandé avant l'annulation).
Future<void> Function(WidgetTester) profil(String type) => (tester) async {
      final avant = ProfilAcces.utilisateur.value;
      ProfilAcces.utilisateur.value = AppUser.fromJson({
        'str_USER_ID': 'USR-TEST-PROFIL',
        'str_FIRST_NAME': 'Profil',
        'str_LAST_NAME': 'Fictif',
        'str_LOGIN': 'profil',
        'xtypeuser': type,
      });
      addTearDown(() => ProfilAcces.utilisateur.value = avant);
    };

/// Vérifie que l'état voulu est rendu : [cle] présente (après défilement de [defilement] s'il le faut).
Future<void> Function(WidgetTester) voir(String cle, {String? defilement}) => (tester) async {
      final f = find.byKey(Key(cle));
      if (defilement != null) {
        final s = find.descendant(of: find.byKey(Key(defilement)), matching: find.byType(Scrollable)).first;
        for (var i = 0; i < 30 && f.evaluate().isEmpty; i++) {
          await tester.drag(s, const Offset(0, -300));
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (f.evaluate().isNotEmpty) await Scrollable.ensureVisible(tester.element(f.first), alignment: 0.3);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(f, findsWidgets, reason: 'état rendu : $cle');
    };

final casLot4 = <CasAffichage>[
  // Récap de caisse
  CasAffichage('Lot 4 · Récap de caisse rempli', _lot4(() => const RecapCaisseNouveau())),
  CasAffichage('Lot 4 · Récap de caisse filtres', _lot4(() => const RecapCaisseNouveau(), ensuite: _filtres)),
  CasAffichage('Lot 4 · Récap de caisse vide',
      _lot4(() => const RecapCaisseNouveau(), donnees: (s) => s.quand('/caisse/fetch-tickez', ReponseFausse.json({'success': true}), methode: 'POST'))),
  // Achats fournisseurs
  CasAffichage('Lot 4 · Achats Fourn. remplis', _lot4(() => const AchatsFournisseursNouveau())),
  CasAffichage('Lot 4 · Achats Fourn. filtres', _lot4(() => const AchatsFournisseursNouveau(), ensuite: _filtres)),
  CasAffichage('Lot 4 · Achats Fourn. récapitulatif',
      _lot4(() => const AchatsFournisseursNouveau(), ensuite: toucher(find.byKey(const Key('achats_recap'))))),
  CasAffichage('Lot 4 · Achats Fourn. détail',
      _lot4(() => const AchatsFournisseursNouveau(), ensuite: defilerPuisToucher(() => find.text(DonneesLot4.fournisseurB), attendu: 'feuille_detail'))),
  CasAffichage('Lot 4 · Achats Fourn. aucun résultat', _lot4(() => const AchatsFournisseursNouveau(), recherche: 'INTROUVABLE')),
  // Fichier Journal
  CasAffichage('Lot 4 · Fichier Journal rempli', _lot4(() => const FichierJournalNouveau())),
  CasAffichage('Lot 4 · Fichier Journal filtres', _lot4(() => const FichierJournalNouveau(), ensuite: _filtres)),
  CasAffichage('Lot 4 · Fichier Journal détail',
      _lot4(() => const FichierJournalNouveau(), ensuite: defilerPuisToucher(() => find.text('Action fictive N2'), attendu: 'feuille_detail'))),
  CasAffichage(
      'Lot 4 · Fichier Journal limite de 200',
      _lot4(() => const FichierJournalNouveau(),
          donnees: (s) => s.route('/common/logs', (r) => ReponseFausse.json(DonneesLot4.journal(criteria: '-1', userId: '', nombre: 200)), methode: 'GET'))),
  // Annulation Ventes
  CasAffichage('Lot 4 · Annulation recherche', _lot4(() => const AnnulationVentesNouveau(), recherche: '261013')),
  CasAffichage('Lot 4 · Annulation détail de la vente', _lot4(() => const AnnulationVentesNouveau(), recherche: '261013', ensuite: _ouvrirVenteA)),
  CasAffichage('Lot 4 · Annulation confirmation vide',
      _lot4(() => const AnnulationVentesNouveau(), recherche: '261013', ensuite: puis([_ouvrirVenteA, _demanderAnnulation, voir('confirmation_saisie')]))),
  CasAffichage('Lot 4 · Annulation confirmation complète',
      _lot4(() => const AnnulationVentesNouveau(), recherche: '261013', ensuite: puis([_ouvrirVenteA, _demanderAnnulation, _saisirAnnuler]))),
  CasAffichage(
      'Lot 4 · Annulation code administrateur',
      _lot4(() => const AnnulationVentesNouveau(),
          recherche: '261013',
          ensuite: puis([profil('mainmenumanager'), _ouvrirVenteA, _demanderAnnulation, _saisirAnnuler, toucher(find.byKey(const Key('confirmation_oui'))), voir('pin_admin_saisie')]))),
  CasAffichage(
      'Lot 4 · Annulation vente annulée',
      _lot4(() => const AnnulationVentesNouveau(),
          recherche: '261013',
          ensuite: puis([profil('dashboard'), _ouvrirVenteA, _demanderAnnulation, _saisirAnnuler, toucher(find.byKey(const Key('confirmation_oui'))),
            voir('resultat_annulation', defilement: 'defilement_detail')]))),
  // Erreurs
  CasAffichage('Lot 4 · droit manquant',
      _lot4(() => const FichierJournalNouveau(), donnees: (s) => s.quand(AppConstants.fichierJournalEndpoint, ReponseFausse.texte('Interdit', statut: 403)))),
  CasAffichage('Lot 4 · erreur du serveur',
      _lot4(() => const RecapCaisseNouveau(), donnees: (s) => s.quand('/caisse/fetch-tickez', ReponseFausse.erreurServeur(), methode: 'POST'))),
  CasAffichage('Lot 4 · serveur injoignable', _lot4(() => const AchatsFournisseursNouveau(), donnees: (s) => s.coupe = true)),
  CasAffichage(
      'Lot 4 · Annulation détail en erreur',
      _lot4(() => const AnnulationVentesNouveau(),
          recherche: '261013',
          donnees: (s) => s.quand('/ventestats/find-one/${DonneesLot4.idA}', ReponseFausse.erreurServeur(), methode: 'GET'),
          ensuite: defilerPuisToucher(() => find.textContaining(DonneesLot4.refA), attendu: 'etat_erreur'))),
];
