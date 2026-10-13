// Ergonomie et cohérence d'affichage : chaque écran principal est rendu, avec le vrai thème de l'application et
// des polices réelles, sur les appareils du pharmacien (téléphones 360×640 dp et 411×891 dp, terminaux Sunmi
// 720×1440 px et 1080×1920 px, tablette 1920×1200 px) et aux échelles de texte 1,0 et 1,3.
// Échec si : débordement (« RenderFlex overflowed »), exception de rendu, cible tactile < 48 dp, cible tactile
// sans libellé, contraste de texte insuffisant — sauf écarts connus listés dans [ecartsConnus] (à résorber ;
// la liste ne doit que diminuer).
//
// Données : faux serveur Prestige « en mémoire » (mêmes routes que le serveur réseau, sans socket).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prestige_app/services/api_service.dart';

import '../support/application.dart';
import '../support/cas_affichage.dart';
import '../support/ergonomie.dart';
import '../support/faux_serveur_prestige.dart';
import '../support/polices.dart';

/// Écarts connus communs à tous les écrans (thème, widget partagé) : fragment toléré → explication.
/// Relevés le 13/10/2026 à la mise en place de ces tests ; à arbitrer avec le pharmacien (couleurs de marque).
const ecartsConnusCommuns = <String, String>{
  '#FFFFFF / #2EBF91': 'bouton principal du thème (ElevatedButton) : texte blanc sur le vert d\'accent #2EBF91, '
      'contraste 2,3:1 (WCAG : 4,5:1) ; changer la couleur de marque n\'est pas une correction « petite et évidente »',
  'contraste du texte insuffisant : « Date de début: »': 'libellé gris 12 px du sélecteur de période commun',
  'contraste du texte insuffisant : « Date de fin: »': 'libellé gris 12 px du sélecteur de période commun',
};

/// Écarts connus propres à un écran (dette relevée à la mise en place de ces tests, à corriger écran par
/// écran) : écran → début des messages tolérés (sans partie variable : date du jour…). Cette liste ne doit
/// que DIMINUER : ne jamais y ajouter un écart pour faire passer un écran nouveau ou modifié.
const ecartsConnus = <String, List<String>>{
  'Analyse Article': [
    'contraste du texte insuffisant : « Entrez un libellé (2+ car.) ou un code CIP (3+ car.) pour rechercher. »',
  ],
  'Configuration IP (premier lancement)': [
    'contraste du texte insuffisant : « Note: L\'adresse IP locale est requise pour utiliser l\'application. »',
    'contraste du texte insuffisant : « Saisir 0 pour désactiver le délai. »',
  ],
  'Etat de Stock': [
    'contraste du texte insuffisant : « APPLIQUER FILTRES »',
    'contraste du texte insuffisant : « Utilisez la recherche ou les filtres ci-dessus »',
  ],
  'Fiche Article': [
    'contraste du texte insuffisant : « Entrez au moins 3 caractères pour rechercher. »',
  ],
  'Licence requise': [
    'contraste du texte insuffisant : « Le serveur Prestige a bien répondu : aucune licence n\'est enregistrée. Contactez Prestige pour en obtenir une, puis saisissez votre clé de licence pour activer l\'application. »',
  ],
  'Présences': [
    'contraste du texte insuffisant : case à cocher',
  ],
  'Présences · Période': [
    // Résumé de la période (dates du jour) en gris clair.
    'contraste du texte insuffisant : « 01/',
    'contraste du texte insuffisant : « Personnalisé »',
  ],
  'Récap de caisse': [
    // Champs date / heure de 44 dp de haut et bouton « Rechercher » de 45 dp.
    'cible tactile < 48 dp : « Date de début',
    'cible tactile < 48 dp : « Date de fin',
    'cible tactile < 48 dp : « Heure début',
    'cible tactile < 48 dp : « Heure fin',
    'cible tactile < 48 dp : « Rechercher »',
    'contraste du texte insuffisant : « Lancez une recherche pour voir le récapitulatif »',
  ],
  'Suggestions': [
    'contraste du texte insuffisant : « Aucune suggestion de commande disponible. »',
  ],
  'Suivi Péremption': [
    'contraste du texte insuffisant : « 0 »',
    'contraste du texte insuffisant : « Qté Totale »',
    'contraste du texte insuffisant : « Val. Achat »',
    'contraste du texte insuffisant : « Val. Vente »',
  ],
  'Tableau: Ratios': [
    'contraste du texte insuffisant : « Norme Ratio Vente/Achat Cible: 1.51 »',
  ],
  'Visualisation BL': [
    // Puces de date de 39 à 44 dp de haut (libellé = date du jour).
    'cible tactile < 48 dp : « 20',
  ],
};

bool _toleree(String ecran, String ecart) =>
    ecartsConnusCommuns.keys.any(ecart.contains) || (ecartsConnus[ecran] ?? const []).any(ecart.startsWith);

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
    preparerTelephone(serveur);
    ApiService.client = serveur.clientMemoire();
  });

  for (final cas in casAffichage) {
    group(cas.nom, () {
      for (final profil in profilsAppareils) {
        for (final echelle in echellesTexte) {
          testWidgets('$profil · texte ×$echelle', (tester) async {
            simulerAppareil(tester, profil, echelle);
            final semantique = tester.ensureSemantics();
            final ecarts = <String>[];
            ecarts.addAll(await releverErreurs(() => cas.ouvrir(tester, serveur)));
            ecarts.addAll(await evaluerAccessibilite(tester));
            semantique.dispose();
            // Fermeture de l'écran : une erreur ici (dispose) est aussi un défaut. AuthProvider garde son
            // démarrage au moins 2,5 s (créé à la première utilisation) : on le laisse finir avant.
            ecarts.addAll(await releverErreurs(() async {
              await tester.pump(const Duration(seconds: 3));
              await tester.pumpWidget(const SizedBox());
              await tester.pump(const Duration(minutes: 2));
            }));
            final nouveaux = ecarts.toSet().where((e) => !_toleree(cas.nom, e)).toList();
            expect(nouveaux, isEmpty, reason: '${cas.nom} · $profil · texte ×$echelle :\n${nouveaux.join('\n')}');
          });
        }
      }
    });
  }
}
