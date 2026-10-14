// Bout en bout de la vague 3 des nouveaux menus : l'application ENTIÈRE (main.dart) parle en HTTP réel au faux
// serveur Prestige local, dans la nouvelle interface.
//  - Pointage BL : grossiste obligatoire, pointer / dépointer, double appui = UN envoi, échec → la pièce revient
//    (mise à jour optimiste annulée) avec message, N° de séquence invalide refusé sans envoi puis valide envoyé ;
//  - Avis : liste SANS aucun détail demandé, détail seulement au toucher (avis passé « Lu »), traitement (un envoi
//    par appui), analyse et alerte qui filtre la liste ; sans le droit « répondre » : action « Traiter » absente ;
//  - Rappels traitement : choix de plusieurs rappels, « Marquer » avec confirmation (annulation = rien d'envoyé),
//    un envoi, relecture et compteur ; analyse ;
//  - refus du serveur → « Droit manquant » ; tablette ; autre profil : menus absents ;
//  - à la fin de chaque parcours : AUCUNE route d'envoi, de réglages ou d'actualisation reçue.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/nouvelle_interface/accueil_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/presentation.dart';
import 'package:prestige_app/nouvelle_interface/vague1/donnees_vague1.dart';
import 'package:prestige_app/nouvelle_interface/vague1/profil_acces.dart';
import 'package:prestige_app/nouvelle_interface/vague3/donnees_vague3.dart';
import 'package:prestige_app/screens/login_screen.dart';

import '../support/application.dart';
import '../support/donnees_fictives.dart';
import '../support/donnees_vague1.dart';
import '../support/donnees_vague3.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/nouvelle_interface.dart';
import '../support/polices.dart';
import 'parcours_vague2_test.dart' show telephone, tablette, toucher, ouvrirDepuisA, revenirALAccueil, onglet, amenerEnVue;

final serveur = FauxServeurPrestige();

const menusVague3 = <(String, String)>[
  ('Pointage BL', 'Pointage BL'),
  ('Avis', 'Avis'),
  ('Rappels traitement', 'Rappels traitement'),
];

void aucuneRouteInterdite() => expect(requetesInterditesVague3(serveur), isEmpty, reason: 'routes d\'envoi / réglages / actualisation reçues');

Finder cle(String k) => find.byKey(Key(k));

/// Valeur d'un chiffre clé du pointage (la liste est remontée en haut si besoin : liste paresseuse).
Future<String?> chiffre(WidgetTester tester, String id) async {
  final s = find.descendant(of: cle('defilement_pointage'), matching: find.byType(Scrollable)).first;
  for (var i = 0; i < 8 && cle('chiffre_$id').evaluate().isEmpty; i++) {
    await tester.drag(s, const Offset(0, 600));
    await tester.pump(const Duration(milliseconds: 200));
  }
  return tester.widget<Text>(cle('chiffre_$id')).data;
}

Future<void> choisirGrossiste(WidgetTester tester) async {
  await toucher(tester, cle('pointage_grossiste'), defilement: cle('defilement_pointage'));
  await toucher(tester, find.text('GROSSISTE FICTIF').last);
  await attendreWidget(tester, cle('pointage_total'));
}

void main() {
  setUpAll(chargerPolicesReelles);

  setUp(() async {
    await serveur.demarrer();
    serveur.oublierRequetes();
    utiliserReseauReel();
    preparerNouvelle(serveur, p: Presentation.tableauDeBord);
    donneesAccueil(serveur);
    listesCommunesVague1(serveur);
  });

  tearDown(() async {
    aucuneRouteInterdite();
    restaurerClient();
    await serveur.arreter();
    serveur
      ..installerRoutesParDefaut()
      ..controlerSession = true
      ..parDefaut = ((_) => ReponseFausse.json(DonneesFictives.listeVide()));
    ProfilAcces.utilisateur.value = null;
    ReglagesAlertes.oublier();
  });

  testWidgets('Pointage BL : grossiste obligatoire, pointer puis dépointer, compteurs, double appui = un envoi', (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Pointage BL');
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Pointage BL'));
    await attendreWidget(tester, cle('pointage_choisir'));
    expect(serveur.recues(ApiPointage.route), isEmpty, reason: 'rien n\'est demandé sans grossiste');
    await choisirGrossiste(tester);
    final r = serveur.recues(ApiPointage.route).single;
    expect(r.parametres['grossiste'], 'GRO-TEST-1');
    expect(r.parametres['etat'], 'TOUS');
    expect(r.parametres['du'], endsWith('-01'), reason: 'début du mois');
    expect(await chiffre(tester, 'pointees'), '1');
    expect(await chiffre(tester, 'a_pointer'), '3');
    expect(find.textContaining('2 écarts'), findsOneWidget);
    // La pièce « manquants à la réception » n'a aucune action.
    expect(cle('pointer_RECEPTION:BL-TEST-1'), findsNothing);

    // Pointer : mise à jour immédiate, un PUT, message.
    await toucher(tester, cle('pointer_BL:BL-TEST-1'), defilement: cle('defilement_pointage'));
    await attendreQue(tester, () => serveur.recues('/pointage-bl/pointer/BL/BL-TEST-1').isNotEmpty, raison: 'PUT pointer');
    await stabiliser(tester, tours: 6);
    expect(serveur.recues('/pointage-bl/pointer/BL/BL-TEST-1').single.parametres, {'pointe': 'true'});
    expect(await chiffre(tester, 'pointees'), '2');
    expect(find.textContaining('Pièce pointée'), findsOneWidget);
    expect(find.descendant(of: cle('pointer_BL:BL-TEST-1'), matching: find.text('Dépointer')), findsOneWidget);

    // Dépointer.
    await toucher(tester, cle('pointer_BL:BL-TEST-1'), defilement: cle('defilement_pointage'));
    await attendreQue(tester, () => serveur.recues('/pointage-bl/pointer/BL/BL-TEST-1').length == 2, raison: 'PUT dépointer');
    await stabiliser(tester, tours: 6);
    expect(serveur.recues('/pointage-bl/pointer/BL/BL-TEST-1').last.parametres, {'pointe': 'false'});
    expect(await chiffre(tester, 'pointees'), '1');

    // Double appui pendant l'envoi : un seul PUT.
    serveur.route('/pointage-bl/pointer/BL/BL-TEST-3', (_) => ReponseFausse.json({'success': true, 'msg': ''}).apres(const Duration(milliseconds: 800)),
        methode: 'PUT');
    final bouton = cle('pointer_BL:BL-TEST-3');
    await amenerEnVue(tester, bouton, cle('defilement_pointage'));
    // Deux appuis AVANT toute reconstruction (vrai double appui) : le second ne doit rien envoyer.
    await tester.tap(bouton);
    await tester.tap(bouton, warnIfMissed: false);
    await tester.pump();
    expect(bouton, findsNothing, reason: 'le bouton laisse la place à l\'indicateur d\'envoi');
    await attendreQue(tester, () => bouton.evaluate().isNotEmpty, raison: 'fin de l\'envoi');
    await stabiliser(tester, tours: 4);
    expect(serveur.recues('/pointage-bl/pointer/BL/BL-TEST-3'), hasLength(1));
    expect(find.descendant(of: bouton, matching: find.text('Dépointer')), findsOneWidget);
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('Pointage BL : échec du serveur → pointage annulé (la pièce revient) avec message ; séquence invalide refusée sans envoi',
      (tester) async {
    telephone(tester);
    serveur.quand('/pointage-bl/pointer/BL/BL-TEST-3', ReponseFausse.erreurServeur(), methode: 'PUT');
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Pointage BL');
    await choisirGrossiste(tester);
    await toucher(tester, cle('pointer_BL:BL-TEST-3'), defilement: cle('defilement_pointage'));
    await attendreQue(tester, () => serveur.recues('/pointage-bl/pointer/BL/BL-TEST-3').isNotEmpty, raison: 'PUT');
    await attendreWidget(tester, find.textContaining('Non enregistré'));
    await stabiliser(tester, tours: 4);
    expect(find.descendant(of: cle('pointer_BL:BL-TEST-3'), matching: find.text('Pointer')), findsOneWidget, reason: 'retour à « Pointer »');
    expect(await chiffre(tester, 'pointees'), '1', reason: 'compteurs remis comme avant');
    expect(await chiffre(tester, 'a_pointer'), '3');
    expect(find.byType(LoginScreen), findsNothing);

    // N° de séquence : invalide → message sous le champ, rien d'envoyé ; valide → PUT avec la valeur nettoyée.
    await toucher(tester, cle('sequence_BL:BL-TEST-1'), defilement: cle('defilement_pointage'));
    await tester.enterText(cle('saisie_pointage'), 'S#12');
    await toucher(tester, cle('saisie_enregistrer'));
    expect(find.text(ControlePointage.messageSequence), findsOneWidget);
    expect(serveur.recues('/pointage-bl/sequence/BL-TEST-1'), isEmpty);
    await tester.enterText(cle('saisie_pointage'), '123456789012345678901');
    await toucher(tester, cle('saisie_enregistrer'));
    expect(find.text(ControlePointage.messageSequence), findsOneWidget);
    expect(serveur.recues('/pointage-bl/sequence/BL-TEST-1'), isEmpty);
    await tester.enterText(cle('saisie_pointage'), ' S-13 ');
    await toucher(tester, cle('saisie_enregistrer'));
    await attendreQue(tester, () => serveur.recues('/pointage-bl/sequence/BL-TEST-1').isNotEmpty, raison: 'PUT séquence');
    await stabiliser(tester, tours: 6);
    expect(serveur.recues('/pointage-bl/sequence/BL-TEST-1').single.parametres, {'valeur': 'S-13'});
    expect(find.text('N° séq. : S-13'), findsOneWidget);
    // Valeur inchangée : rien n'est envoyé.
    await toucher(tester, cle('sequence_BL:BL-TEST-1'), defilement: cle('defilement_pointage'));
    await toucher(tester, cle('saisie_enregistrer'));
    expect(serveur.recues('/pointage-bl/sequence/BL-TEST-1'), hasLength(1));
    // Référence d'avoir d'un retour.
    await toucher(tester, cle('avoir_RETOUR:RET-TEST-1'), defilement: cle('defilement_pointage'));
    await tester.enterText(cle('saisie_pointage'), 'VRI 683562 2');
    await toucher(tester, cle('saisie_enregistrer'));
    await attendreQue(tester, () => serveur.recues('/pointage-bl/avoir/RET-TEST-1').isNotEmpty, raison: 'PUT avoir');
    expect(serveur.recues('/pointage-bl/avoir/RET-TEST-1').single.parametres, {'valeur': 'VRI 683562 2'});
    await stabiliser(tester, tours: 4);
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('Avis : liste sans aucun détail demandé ; toucher un avis → détail (Lu) ; traiter (un envoi) ; analyse et alerte → liste filtrée',
      (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Avis');
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Avis'));
    await attendreWidget(tester, cle('avis_total'));
    expect(serveur.recues(ApiAvis.routeDroits), hasLength(1));
    expect(serveur.recues(ApiAvis.routeListe).single.parametres['limit'], '50');
    await stabiliser(tester, tours: 10);
    expect(detailsAvisDemandes(serveur), isEmpty, reason: 'aucun préchargement du détail (il marquerait l\'avis « lu »)');
    expect(etatVague3.avis.first['statut'], 'NOUVEAU');

    // Toucher l'avis : UN détail, l'avis passe « Lu ».
    await toucher(tester, cle('avis_AVIS-TEST-1'), defilement: cle('defilement_avis'));
    await attendreWidget(tester, cle('avis_texte'));
    expect(detailsAvisDemandes(serveur).single.chemin, '/avis-clients/avis/AVIS-TEST-1');
    expect(etatVague3.avis.first['statut'], 'LU');
    expect(find.text('CLIENT FICTIF 1'), findsOneWidget);
    expect(find.textContaining('Répondre'), findsNothing, reason: 'pas de réponse au client depuis le mobile');

    // Traiter : statut + note interne, double appui = un POST.
    await toucher(tester, cle('statut_avis_TRAITE'), defilement: cle('defilement_detail_avis'));
    await tester.enterText(cle('note_interne'), 'Rappel fait (fictif)');
    await tester.pump();
    final enregistrer = cle('avis_enregistrer');
    await tester.ensureVisible(enregistrer);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(enregistrer);
    await tester.tap(enregistrer, warnIfMissed: false);
    await attendreQue(tester, () => serveur.recues(ApiAvis.routeTraiter('AVIS-TEST-1')).isNotEmpty, raison: 'POST traiter');
    await attendreWidget(tester, find.textContaining('Traitement enregistré'));
    expect(serveur.recues(ApiAvis.routeTraiter('AVIS-TEST-1')), hasLength(1));
    expect(serveur.recues(ApiAvis.routeTraiter('AVIS-TEST-1')).single.json, {'statut': 'TRAITE', 'noteInterne': 'Rappel fait (fictif)'});

    // Retour : la carte montre « Traité » sans relire le détail.
    await tester.binding.handlePopRoute();
    await stabiliser(tester, tours: 6);
    expect(find.descendant(of: cle('avis_AVIS-TEST-1'), matching: find.text('Traité')), findsOneWidget);
    expect(detailsAvisDemandes(serveur), hasLength(1));

    // Analyse, puis une alerte filtre la liste.
    await onglet(tester, 'Analyse');
    await attendreWidget(tester, cle('chiffre_avis_nombre'));
    await toucher(tester, cle('alerte_avis_0'), defilement: cle('defilement_analyse_avis'));
    await attendreQue(tester, () => serveur.recues(ApiAvis.routeListe).last.parametres['note'] == 'NEGATIF', raison: 'liste filtrée');
    expect(serveur.recues(ApiAvis.routeListe).last.parametres['statut'], 'NON_TRAITE');
    await stabiliser(tester, tours: 6);
    expect(find.text('Note : 1 ou 2 étoiles'), findsOneWidget);
    expect(detailsAvisDemandes(serveur), hasLength(1), reason: 'toujours un seul détail : celui touché');
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('Avis sans le droit « répondre » : détail en lecture, action « Traiter » absente, aucun envoi', (tester) async {
    telephone(tester);
    serveur.quand(ApiAvis.routeDroits, ReponseFausse.json(DonneesVague3.droits(repondre: false)), methode: 'GET');
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Avis');
    await attendreWidget(tester, cle('avis_total'));
    await toucher(tester, cle('avis_AVIS-TEST-2'), defilement: cle('defilement_avis'));
    await attendreWidget(tester, cle('avis_texte'));
    await tester.scrollUntilVisible(cle('avis_traitement_lecture'), 300,
        scrollable: find.descendant(of: cle('defilement_detail_avis'), matching: find.byType(Scrollable)).first);
    expect(cle('avis_traitement_lecture'), findsOneWidget);
    expect(cle('avis_enregistrer'), findsNothing);
    expect(cle('note_interne'), findsNothing);
    expect(find.textContaining('Répondre aux avis'), findsOneWidget);
    expect(serveur.requetes.where((r) => r.chemin.endsWith('/traiter')), isEmpty);
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('Rappels traitement : À préparer à l\'ouverture, choisir plusieurs rappels, « Marquer » confirmé (un envoi), annulation sans envoi, analyse',
      (tester) async {
    telephone(tester);
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Rappels traitement');
    await attendreWidget(tester, find.widgetWithText(AppBar, 'Rappels traitement'));
    await attendreWidget(tester, cle('rappels_total'));
    expect(serveur.recues(ApiRappels.routeListe).single.parametres['statut'], 'A_PREPARER');
    await attendreWidget(tester, cle('rappels_compteur'));
    expect(find.text('25 rappels à préparer au total'), findsOneWidget);
    expect(cle('barre_marquer'), findsNothing);

    // Choisir deux rappels.
    await toucher(tester, cle('choisir_RAP-TEST-1'), defilement: cle('defilement_rappels'));
    await toucher(tester, cle('choisir_RAP-TEST-2'), defilement: cle('defilement_rappels'));
    expect(find.text('2 rappels choisis · marquer :'), findsOneWidget);

    // Annulation : rien n'est envoyé.
    await toucher(tester, cle('marquer_ECARTE'));
    expect(find.textContaining('Aucun message n\'est envoyé'), findsOneWidget);
    await toucher(tester, cle('confirmer_non'));
    expect(serveur.recues(ApiRappels.routeMarquer), isEmpty);

    // Confirmation : un POST avec les deux identifiants, puis relecture et compteur.
    await toucher(tester, cle('marquer_PREPARE'));
    await toucher(tester, cle('confirmer_oui'));
    await attendreQue(tester, () => serveur.recues(ApiRappels.routeMarquer).isNotEmpty, raison: 'POST marquer');
    await attendreWidget(tester, find.textContaining('2 rappels marqués « Préparé »'));
    final r = serveur.recues(ApiRappels.routeMarquer).single;
    expect(r.parametres, {'statut': 'PREPARE'});
    expect((r.json as Map)['ids'], unorderedEquals(['RAP-TEST-1', 'RAP-TEST-2']));
    await attendreQue(tester, () => serveur.recues(ApiRappels.routeListe).length == 2, raison: 'relecture');
    await attendreWidget(tester, find.text('23 rappels à préparer au total'));
    expect(cle('barre_marquer'), findsNothing, reason: 'sélection vidée');
    expect(cle('rappel_RAP-TEST-1'), findsNothing);

    // « Tout choisir » puis « Écarter » annulé : rien d'envoyé.
    await toucher(tester, cle('rappels_tout_choisir'), defilement: cle('defilement_rappels'));
    expect(find.text('23 rappels choisis · marquer :'), findsOneWidget);
    await toucher(tester, cle('marquer_ECARTE'));
    await toucher(tester, cle('confirmer_non'));
    expect(serveur.recues(ApiRappels.routeMarquer), hasLength(1));

    // Analyse : 6 mois.
    await onglet(tester, 'Analyse');
    await attendreWidget(tester, cle('chiffre_efficacite'));
    expect(serveur.recues(ApiRappels.routeAnalyse).single.parametres['dtStart'], endsWith('-01'));
    expect(serveur.requetes.where((x) => x.chemin.contains('envoyer') || x.chemin.contains('actualiser') || x.chemin.endsWith('/sms')), isEmpty);
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('refus du serveur : « Droit manquant » sans « Réessayer » ni déconnexion (pointage, avis, rappels)', (tester) async {
    telephone(tester);
    serveur.quand(ApiPointage.route,
        ReponseFausse.json({'success': false, 'msg': 'Vous n\'avez pas le droit d\'accéder au pointage des BL.', 'interdit': true}), methode: 'GET');
    serveur.quand(ApiAvis.routeDroits,
        ReponseFausse.json({'success': false, 'msg': 'Vous n\'avez pas le droit d\'effectuer cette action.', 'interdit': true}), methode: 'GET');
    serveur.quand(ApiRappels.routeListe, ReponseFausse.json({'success': false, 'msg': 'Vous n\'avez pas accès aux rappels de traitement.'}), methode: 'GET');
    await jusquAccueilNouveau(tester);
    await ouvrirDepuisA(tester, 'Pointage BL');
    await toucher(tester, cle('pointage_grossiste'), defilement: cle('defilement_pointage'));
    await toucher(tester, find.text('GROSSISTE FICTIF').last);
    await attendreWidget(tester, cle('erreur_droit'));
    expect(find.textContaining('Droit manquant : consulter le pointage des BL.'), findsOneWidget);
    expect(cle('bouton_reessayer'), findsNothing);
    await revenirALAccueil(tester);
    await ouvrirDepuisA(tester, 'Avis');
    await attendreWidget(tester, cle('erreur_droit'));
    expect(find.textContaining('Droit manquant : consulter les avis clients.'), findsWidgets);
    expect(serveur.recues(ApiAvis.routeListe), isEmpty);
    await revenirALAccueil(tester);
    await ouvrirDepuisA(tester, 'Rappels traitement');
    await attendreWidget(tester, cle('erreur_droit'));
    expect(find.byType(LoginScreen), findsNothing);
    await revenirALAccueil(tester);
    await terminer(tester);
  });

  testWidgets('tablette (B, menu latéral) : chaque menu de la vague 3 s\'ouvre sans erreur', (tester) async {
    tablette(tester);
    preparerNouvelle(serveur);
    await jusquAccueilNouveau(tester);
    for (final (titre, barre) in menusVague3) {
      final erreurs = await releverErreurs(() async {
        await toucher(tester, find.descendant(of: find.byType(AccueilNouveau), matching: find.text(titre)),
            defilement: find.byKey(const Key('defilement_menus')));
        await stabiliser(tester, tours: 20);
      });
      expect(erreurs, isEmpty, reason: '$titre : ${erreurs.join('\n')}');
      expect(find.widgetWithText(AppBar, barre), findsWidgets);
      await revenirALAccueil(tester);
    }
    expect(detailsAvisDemandes(serveur), isEmpty);
    await terminer(tester);
  });

  testWidgets('autre profil (mainmenumanager) : menus de la vague 3 absents, aucune requête', (tester) async {
    telephone(tester);
    serveur.controlerSession = false;
    serveur.quand(
        '/user/auth',
        ReponseFausse.json({...DonneesFictives.utilisateur(), 'xtypeuser': 'mainmenumanager'},
            entetes: {'set-cookie': 'JSESSIONID=fictif-autre; Path=/prestige; HttpOnly'}),
        methode: 'POST');
    await jusquAccueilNouveau(tester);
    expect(ProfilAcces.responsable, isFalse);
    final defilement = find.byKey(const Key('defilement_accueil'));
    await tester.scrollUntilVisible(find.text('Présences').last, 300, scrollable: find.descendant(of: defilement, matching: find.byType(Scrollable)).first);
    for (final (t, _) in menusVague3) {
      expect(find.descendant(of: find.byType(AccueilNouveau), matching: find.text(t)), findsNothing, reason: t);
    }
    expect(
        serveur.requetes.where((r) => r.chemin.startsWith('/pointage-bl') || r.chemin.startsWith('/avis-clients') || r.chemin.startsWith('/rappels-habitude')),
        isEmpty);
    await terminer(tester);
  });
}
