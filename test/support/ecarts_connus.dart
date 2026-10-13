// Écarts d'ergonomie CONNUS (dette relevée le 13/10/2026), partagés par les tests d'affichage de l'ancienne
// interface (ergonomie/affichage_ecrans_test.dart) et de la nouvelle (ergonomie/affichage_nouvelle_interface_test.dart).
// Ces listes ne doivent que DIMINUER : ne jamais y ajouter un écart pour faire passer un écran nouveau ou modifié.
// La nouvelle interface ne tolère que les écarts propres à l'écran d'un module d'origine ([ecartsConnus]) et les
// deux libellés du sélecteur de période commun ; jamais celui du bouton vert (#2EBF91), ni aucun sur ses écrans à elle.

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
};

