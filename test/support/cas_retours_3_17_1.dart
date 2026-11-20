// Écrans de la 3.17.1 rendus par les tests d'ergonomie (test/ergonomie/affichage_nouvelle_interface_test.dart, toutes
// tailles d'écran et échelles de texte) : fiche de base de l'Analyse Article pendant l'analyse (route /info lente),
// CA crédit du serveur « retour » (tiersPayantsRetenus) avec une recherche.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/donnees/analyses_ventes_donnees.dart';
import 'package:prestige_app/nouvelle_interface/modules/articles_nouveau.dart';
import 'package:prestige_app/nouvelle_interface/modules/ca_credit_nouveau.dart';
import 'package:prestige_app/utils/constants.dart';

import 'cas_affichage.dart';
import 'cas_affichage_nouvelle.dart';
import 'donnees_3_17_1.dart';
import 'donnees_fictives.dart';
import 'faux_serveur_prestige.dart';
import 'grandes_donnees.dart';

final casRetours3171 = <CasAffichage>[
  CasAffichage(
      '3.17.1 · Analyse Article · fiche de base pendant l\'analyse',
      enNouvelle(ecranConnecte(() => const AnalyseArticleNouveau(), recherche: 'PARAFICTIF'),
          donnees: (s) => s.route(AppConstants.infoEndpoint, (r) {
                final rep = ReponseFausse.json(DonneesFictives.articlesAnalyse());
                // Liste (repli /info) immédiate ; analyse au CIP exact lente.
                return r.parametres['search'] == '9990001' ? rep.apres(const Duration(seconds: 60)) : rep;
              }, methode: 'GET'),
          ensuite: toucher(find.text(DonneesFictives.libelleArticle1)))),
  CasAffichage(
      '3.17.1 · CA crédit · recherche (tiers payants retenus)',
      enNouvelle(ecranConnecte(() => const CaCreditNouveau()), donnees: (s) {
        CaCreditDonnees.oublierModes();
        Donnees3171.installer(s, ServeurOfficine.retour, lignes: GrandesDonnees.caCredit(130));
      }, ensuite: (tester) async {
        await tester.enterText(find.byKey(const Key('champ_recherche')), '1');
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      })),
];
