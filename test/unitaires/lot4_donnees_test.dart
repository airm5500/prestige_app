// Logique PARTAGÉE du lot 4 (lib/donnees/) : corps du ticket Z, lecture tolérante, filtre et récapitulatif des
// achats, paramètres du journal, paramètres et chemins de l'annulation, confirmation renforcée, lecture du détail
// d'une vente (client), sens des issues d'annulation. 3.6.1 : pages de 50 du journal (start / limit, total), contenu
// et octets du PDF du ticket Z (textes de l'écran, aucun recalcul).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/achats_fournisseurs_donnees.dart';
import 'package:prestige_app/donnees/annulation_vente_donnees.dart';
import 'package:prestige_app/donnees/fichier_journal_donnees.dart';
import 'package:prestige_app/donnees/recap_caisse_donnees.dart';
import 'package:prestige_app/donnees/recap_caisse_pdf.dart';
import 'package:prestige_app/models/achat_fournisseur_model.dart';
import 'package:prestige_app/models/fichier_journal_model.dart';
import 'package:prestige_app/models/log_filtre_model.dart';
import 'package:prestige_app/models/log_user_model.dart';
import 'package:prestige_app/models/ticket_z_model.dart';

AchatFournisseur achat(String id, String lib, double ht, double tva, String bl, String cmd) => AchatFournisseur(
    fournisseurId: id, fournisseurLibelle: lib, montantHT: ht, montantTVA: tva, montantTTC: ht + tva, numeroBL: bl, numeroCommade: cmd);

void main() {
  group('Récap de caisse', () {
    test('corps POST d\'origine : dates yyyy-MM-dd, heures HH:mm, ALL par défaut', () {
      expect(RecapCaisse.corps(debut: DateTime(2026, 1, 5), fin: DateTime(2026, 1, 6)), {
        'description': 'ALL',
        'dtStart': '2026-01-05',
        'dtEnd': '2026-01-06',
        'hrStart': '00:00',
        'hrEnd': '23:59',
        'userId': 'ALL',
      });
      expect(
          RecapCaisse.corps(
              debut: DateTime(2026, 1, 5), fin: DateTime(2026, 1, 5), heureDebut: const TimeOfDay(hour: 7, minute: 5), heureFin: const TimeOfDay(hour: 13, minute: 0), userId: 'U1'),
          containsPair('hrStart', '07:05'));
    });

    test('réponse sans « data » = récapitulatif vide ; totaux lus tels quels', () {
      expect(RecapCaisse.estVide(RecapCaisse.lire(null)), isTrue);
      expect(RecapCaisse.estVide(RecapCaisse.lire({'success': true})), isTrue);
      final r = RecapCaisse.lire({
        'data': {
          'datas': [
            {'user': 'A', 'modePaymentAmounts': [], 'totaux': []},
          ],
          'totaux': [
            {'modeLibelle': 'TOTAL ESP', 'montant': '12 000'},
            {'modeLibelle': 'TOTAL (VNO/VO)', 'montant': '-500'},
          ],
        },
      });
      expect(r.datas, hasLength(1));
      expect(RecapCaisse.totalGlobal(r, 'total esp'), '12 000');
      expect(RecapCaisse.totalGlobal(r, 'TOTAL CB'), isNull);
      expect(RecapCaisse.estTotalVnoVo('Total (VNO/VO)'), isTrue);
      expect(RecapCaisse.estNegatif('-500'), isTrue);
    });
  });

  group('Achats fournisseurs', () {
    final achats = [
      achat('A', 'ALPHA', 100, 18, 'BL-1', 'CMD-1'),
      achat('B', 'BETA', 50, 9, 'BL-2', 'CMD-2'),
      achat('A', 'ALPHA', 20, 0, 'BL-3', 'CMD-3'),
    ];

    test('filtre local d\'origine : fournisseur, BL, commande (casse ignorée) et fournisseur choisi', () {
      expect(AchatsFournisseurs.filtrer(achats, 'beta', null), hasLength(1));
      expect(AchatsFournisseurs.filtrer(achats, 'bl-', null), hasLength(3));
      expect(AchatsFournisseurs.filtrer(achats, 'cmd-3', null).single.numeroBL, 'BL-3');
      expect(AchatsFournisseurs.filtrer(achats, '', 'A'), hasLength(2));
      expect(AchatsFournisseurs.filtrer(achats, 'bl-2', 'A'), isEmpty);
    });

    test('récapitulatif : par fournisseur (ordre d\'apparition) ou fournisseur choisi', () {
      final tous = AchatsFournisseurs.recapitulatif(achats);
      expect(tous.keys, ['ALPHA', 'BETA']);
      expect(tous['ALPHA']!.ttc, 138);
      expect(tous['ALPHA']!.nombre, 2);
      final un = AchatsFournisseurs.recapitulatif(achats, fournisseurId: 'B', libelle: 'BETA');
      expect(un.keys, ['BETA']);
      expect(un['BETA']!.tva, 9);
      expect(AchatsFournisseurs.parametres(DateTime(2026, 2, 1), DateTime(2026, 2, 28)), {'dtStart': '2026-02-01', 'dtEnd': '2026-02-28'});
    });
  });

  group('Fichier Journal', () {
    test('paramètres d\'origine : criteria -1 et userId vide par défaut, limite 200', () {
      final d = DateTime(2026, 10, 14);
      expect(JournalDonnees.parametres(debut: d, fin: d), {'dtStart': '2026-10-14', 'dtEnd': '2026-10-14', 'criteria': '-1', 'userId': '', 'limit': '200'});
      expect(
          JournalDonnees.parametres(debut: d, fin: d, operation: LogFiltre(description: 'X', order: 4), utilisateur: LogUser(fullName: 'U', lgUserID: 'U1')),
          containsPair('criteria', '4'));
    });

    test('lecture tolérante et recherche locale', () {
      expect(JournalDonnees.lireActions([]), isNull);
      final l = JournalDonnees.lireActions({
        'data': [
          {'strTYPELOG': 'Vente', 'userFullName': 'ALICE', 'strDESCRIPTION': 'Vente 12'},
          {'strTYPELOG': 'Annulation', 'userFullName': 'BOB', 'strDESCRIPTION': 'Annulation 13'},
        ],
      })!;
      expect(JournalDonnees.filtrer(l, 'bob'), hasLength(1));
      expect(JournalDonnees.filtrer(l, 'vente'), hasLength(1));
      expect(JournalDonnees.filtrer(l, ''), hasLength(2));
      expect(JournalDonnees.filtrer(<FichierJournal>[], 'x'), isEmpty);
    });
  });

  group('Annulation de ventes', () {
    test('paramètres et chemins d\'origine (route d\'annulation inchangée)', () {
      final d = DateTime(2026, 10, 14);
      expect(AnnulationVente.parametres(debut: d, fin: d, recherche: ' 261013 '),
          {'dtStart': '2026-10-14', 'dtEnd': '2026-10-14', 'query': '261013', 'start': '0', 'limit': '50'});
      expect(AnnulationVente.cheminAnnulation('ID-1'), '/vente/annulation/ID-1');
      expect(AnnulationVente.cheminDetail('ID-1'), '/ventestats/find-one/ID-1');
    });

    test('confirmation renforcée : référence exacte ou « ANNULER » seulement', () {
      const ref = '261013_00001';
      for (final ok in ['ANNULER', 'annuler', ' Annuler ', ref, ' 261013_00001 ']) {
        expect(AnnulationVente.confirmationValide(ok, ref), isTrue, reason: ok);
      }
      for (final non in ['', ' ', 'ANNUL', 'ANNULERR', 'OUI', '261013', '261013_00002', '261013_000011']) {
        expect(AnnulationVente.confirmationValide(non, ref), isFalse, reason: non);
      }
      expect(AnnulationVente.confirmationValide('', ''), isFalse, reason: 'référence vide : seul ANNULER vaut');
      expect(AnnulationVente.confirmationValide('ANNULER', ''), isTrue);
    });

    test('détail : client (fullName, sinon prénom + nom), date, état', () {
      final a = AnnulationVente.lireDetail({
        'data': {'strREF': 'R', 'client': {'fullName': 'CLIENT A'}, 'dtCREATED': '13/10/2026', 'bISCANCEL': false, 'items': []},
      })!;
      expect(a.client, 'CLIENT A');
      expect(a.dateVente, '13/10/2026');
      expect(a.annulee, isFalse);
      final b = AnnulationVente.lireDetail({
        'data': {'strREF': 'R', 'client': null, 'strFIRSTNAMECUSTOMER': 'Awa', 'strLASTNAMECUSTOMER': 'KONE'},
      })!;
      expect(b.client, 'Awa KONE');
      expect(b.annulee, isNull);
      expect(AnnulationVente.lireDetail({'data': {'strREF': 'R'}})!.client, '', reason: 'vente sans client');
      expect(AnnulationVente.lireDetail({'data': []}), isNull);
    });

    test('issues : envoyée ou non, vente annulée ou non', () {
      const nonEnvoyee = ResultatAnnulation(IssueAnnulation.nonEnvoyee, '', TonResultat.erreur);
      const deja = ResultatAnnulation(IssueAnnulation.dejaAnnulee, '', TonResultat.neutre);
      const ok = ResultatAnnulation(IssueAnnulation.annulee, '', TonResultat.succes);
      const refus = ResultatAnnulation(IssueAnnulation.refusee, '', TonResultat.erreur);
      expect([nonEnvoyee.envoyee, deja.envoyee, ok.envoyee, refus.envoyee], [false, false, true, true]);
      expect([nonEnvoyee.venteAnnulee, deja.venteAnnulee, ok.venteAnnulee, refus.venteAnnulee], [false, true, true, false]);
    });
  });

  group('Fichier Journal par pages de 50 (3.6.1)', () {
    final d = DateTime(2026, 10, 14);
    test('paramètres : mêmes filtres que l\'origine, start et limit=50', () {
      expect(JournalDonnees.taillePage, 50);
      expect(JournalDonnees.parametresPage(debut: d, fin: d, start: 0),
          {'dtStart': '2026-10-14', 'dtEnd': '2026-10-14', 'criteria': '-1', 'userId': '', 'start': '0', 'limit': '50'});
      final p = JournalDonnees.parametresPage(
          debut: d, fin: d, operation: LogFiltre(description: 'X', order: 4), utilisateur: LogUser(fullName: 'U', lgUserID: 'U1'), start: 100);
      expect(p, {'dtStart': '2026-10-14', 'dtEnd': '2026-10-14', 'criteria': '4', 'userId': 'U1', 'start': '100', 'limit': '50'});
      expect(JournalDonnees.parametres(debut: d, fin: d)['limit'], '200', reason: 'écran d\'origine inchangé');
    });

    test('lecture d\'une page : total numérique ou texte, absent = serveur sans pagination', () {
      final data = [
        {'strTYPELOG': 'Vente', 'userFullName': 'A', 'strDESCRIPTION': 'x'},
      ];
      expect(JournalDonnees.lirePage({'total': 120, 'data': data})!.total, 120);
      expect(JournalDonnees.lirePage({'total': '75', 'data': data})!.total, 75);
      expect(JournalDonnees.lirePage({'total': 12.0, 'data': data})!.paginee, isTrue);
      final sans = JournalDonnees.lirePage({'data': data})!;
      expect(sans.total, isNull);
      expect(sans.paginee, isFalse);
      expect(sans.actions, hasLength(1));
      expect(JournalDonnees.lirePage({'total': -1, 'data': data})!.total, isNull);
      expect(JournalDonnees.lirePage([]), isNull);
    });
  });

  group('PDF du ticket Z (3.6.1)', () {
    TicketZAmount m(String l, String v) => TicketZAmount(modeLibelle: l, montant: v);
    final r = TicketZResponse(datas: [
      TicketZUserData(user: 'CAISSIERE FICTIVE', modePaymentAmounts: [m('Espèces', '125 000')], totaux: [m('Total encaissé', '125 000'), m('Sortie', '-1 500')]),
      TicketZUserData(user: 'CAISSIER VIDE', modePaymentAmounts: [], totaux: []),
    ], totauxGlobaux: [
      m('TOTAL ESP', '125 000'),
      m('TOTAL (VNO/VO)', '58 900'),
    ]);
    ContenuTicketZ contenu() => ContenuTicketZ.depuis(r,
        officine: 'Pharmacie Fictive',
        periode: 'Aujourd\'hui · 14/10/2026',
        caissier: 'Tous les utilisateurs',
        heures: 'de 00:00 à 23:59',
        imprimeLe: DateTime(2026, 10, 14, 18, 5),
        chiffres: const [('Caissiers', '2'), ('Espèces', '125 000 F')]);

    test('texte : en-tête, filtres, chiffres, totaux et caissiers, montants de l\'écran (« … F ») sans recalcul', () {
      expect(contenu().lignes, [
        'Pharmacie Fictive',
        'Récapitulatif de caisse (ticket Z)',
        'Période : Aujourd\'hui · 14/10/2026',
        'Caissier : Tous les utilisateurs',
        'Heures : de 00:00 à 23:59',
        'Imprimé le 14/10/2026 à 18:05',
        'Caissiers : 2',
        'Espèces : 125 000 F',
        'Totaux globaux',
        'TOTAL ESP : 125 000 F',
        'TOTAL (VNO/VO) : 58 900 F',
        'CAISSIERE FICTIVE',
        'Espèces : 125 000 F',
        'Total encaissé : 125 000 F',
        'Sortie : -1 500 F',
        'CAISSIER VIDE',
        'Aucun encaissement.',
      ]);
      final c = contenu();
      expect(c.totauxGlobaux[1].gras, isTrue, reason: 'TOTAL (VNO/VO) en gras comme à l\'écran');
      expect(c.caissiers[0].totaux.every((t) => t.gras), isTrue);
      expect(c.caissiers[0].totaux[1].negatif, isTrue, reason: 'négatif en rouge, signe gardé');
      expect(c.caissiers[0].totaux[1].montant, RecapCaisse.montant('-1 500'));
    });

    test('texte compatible avec la police intégrée (Latin-1)', () {
      expect(pdfTexte('Espèces : 1 000 F'), 'Espèces : 1 000 F');
      expect(pdfTexte('Aujourd’hui — 00:00 → 23:59…'), "Aujourd'hui - 00:00 - 23:59...");
      expect(pdfTexte('Prix 5 €'), 'Prix 5 EUR');
      expect(pdfTexte('漢'), '?');
    });

    test('nom du document', () {
      expect(RecapCaissePdf.nom(DateTime(2026, 10, 14), DateTime(2026, 10, 14)), 'Ticket_Z_2026-10-14');
      expect(RecapCaissePdf.nom(DateTime(2026, 10, 1), DateTime(2026, 10, 14)), 'Ticket_Z_2026-10-01_au_2026-10-14');
    });

    test('le PDF A4 contient les textes (officine, totaux, caissiers, montants)', () async {
      final o = await RecapCaissePdf.octets(contenu(), compresser: false);
      final pdf = latin1.decode(o);
      expect(pdf, startsWith('%PDF-'));
      expect(pdf, contains('MediaBox[0 0 595.27559 841.88976]'), reason: 'A4');
      // Le moteur PDF dessine mot par mot : chaque mot de chaque ligne figure dans les flux (le « : » du texte
      // sépare libellé et montant, placés en colonnes dans le PDF).
      for (final ligne in contenu().lignes.where((l) => !l.startsWith('Imprimé'))) {
        for (final mot in pdfTexte(ligne).split(' ').where((m) => m.isNotEmpty && m != ':')) {
          final echappe = mot.replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
          expect(pdf, contains('($echappe)'), reason: 'mot « $mot » de « $ligne »');
        }
      }
    });
  });
}
