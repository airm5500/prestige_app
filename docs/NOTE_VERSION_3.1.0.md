# Prestige Pharmacien 3.1.0+28 — lot 1 et vague 1 des nouveaux menus

Cette version réunit deux livraisons de la nouvelle interface :

- **lot 1** (`NOTE_VERSION_LOT1.md`) : six modules refaits (Rapport d'Activité, Détail CA, Analyse Article, Fiche
  Article, Suivi Péremption, Suivi Crédit), bouton Réglages en haut à droite, « Fournisseurs » retiré de la
  nouvelle interface ;
- **vague 1** (`NOTE_VERSION_VAGUE1.md`) : Valorisation (Rayon / Réserve / Total), Alertes, Retraits et abandons,
  Ventes modifiées, réservés à l'administrateur et au pharmacien.

L'**ancienne interface ne change pas**.

## Numéro de version

- Nouvelle version : **3.1.0+28** (3.1.0 = nouvelles fonctions ; 28 = numéro de livraison, +1 par rapport à 27).
- La version s'affiche, discrète, **en bas de l'écran de connexion** et **dans les Réglages**, dans les deux
  interfaces : « Version 3.1.0+28 ». Elle est lue dans l'application installée (rien n'est recopié à la main).
- Prestige Pharmacien **n'a pas encore été publié sur le magasin Sunmi** (`docs/VERSIONS_SUNMI.md`).

### Règle des versions (permanente)

1. Le numéro n'est écrit **qu'à un seul endroit** : `pubspec.yaml` (`version: X.Y.Z+N`). Android le reprend tel
   quel (aucun numéro en dur dans Gradle).
2. **X.Y.Z n'est jamais inférieur** à la dernière version publiée sur Sunmi, et **N est toujours strictement
   supérieur** au numéro publié (sinon le magasin refuse la mise à jour).
3. **Chaque livraison augmente N d'au moins 1**, même un APK de test.

Après chaque publication sur Sunmi, on note la version dans `docs/VERSIONS_SUNMI.md` ; un test vérifie ensuite
automatiquement les règles 1 et 2 (`test/non_regression/version_sunmi_test.dart`).

## Vos réponses, appliquées dans cette version

### Lot 1

1. **« Ce mois »** s'arrête à aujourd'hui : gardé.
2. **Période limitée à 3 ans** (au lieu de 366 jours) partout où le sélecteur de période commun s'applique :
   Rapport d'Activité, Détail CA, Suivi Crédit, Retraits et abandons, Ventes modifiées. Au-delà : « Période trop
   longue (3 ans au maximum). » (Présences garde sa propre limite d'un an, inchangée.)
3. **Suivi Péremption : période en mois.** Côté serveur, le « nombre de mois » veut déjà dire « lots qui périment
   d'ici N mois, à partir d'aujourd'hui » (et, vide, « lots déjà périmés »). Il est donc présenté comme la période,
   en tête de l'écran : **Déjà périmés · 1 · 3 · 6 · 12 · 24 mois · Autre…** (saisie contrôlée, 0 à 120), avec les
   dates en clair (« Lots qui périment du 14/10/2026 au 14/04/2027 »). À l'ouverture : « Déjà périmés », comme
   l'écran d'origine (mêmes chiffres, vérifié par le test de non-régression des données).
4. **Suivi Crédit** : filtre par type de tiers payant et totaux gardés.
5. « Fournisseurs » en dernière position dans l'ancienne interface après personnalisation : rien à faire.

### Vague 1

1. **Accueil A : « Ruptures de stock » remplace « Contrôle des bons de livraison ».** Tout le bloc « À surveiller »
   vient d'**un seul appel** (`/tableau-bord/alertes`) : n'importe quel ⟳ actualise péremption et ruptures
   ensemble. Toucher « Ruptures de stock » ouvre la liste des produits à zéro. L'accueil n'interroge plus l'état
   des contrôles de BL ; le module **Etat Contrôle Achat** est inchangé.
2. **Péremption de l'accueil** : lots qui périment dans les N prochains mois, hors lots déjà périmés
   (« Périment dans 6 mois (hors lots déjà périmés) ») ; touchée, elle ouvre la liste de ces lots.
3. **Valorisation réservée** à l'administrateur et au pharmacien dans la nouvelle interface (l'ancienne interface
   est inchangée).
4. **Réglages des alertes sur le mobile** : écran Alertes › bouton « Réglages des alertes ». Champs contrôlés :
   péremption 1 à 24 mois, ruptures / ordonnances à renouveler / suggestions 1 à 90 jours, produits non vendus
   1 à 365 jours ; bouton **« Valeurs par défaut »** (celles du web : 6 mois, 7, 7, 2 et 30 jours). Les réglages
   sont **enregistrés sur le téléphone, pour ce serveur et ce compte**. Enregistrer ne lance aucun comptage :
   touchez ⟳ ensuite. Les comptages et les listes utilisent ces valeurs.
   *Choix : rien n'est écrit sur le serveur.* La préférence web (`/preferences/tableau-bord`) est un seul bloc qui
   contient aussi la disposition du tableau de bord web ; la réécrire depuis le mobile pourrait effacer un
   changement fait entre-temps sur le web.
5. **« Personnaliser l'accueil »** ne propose plus les menus réservés (Valorisation, Alertes, Retraits et
   abandons, Ventes modifiées) à un compte non autorisé.

## Même aspect partout

Les nouveaux menus de la vague 1 utilisent maintenant **les mêmes éléments que les modules du lot 1** : même
sélecteur de période (Aujourd'hui · Hier · 7 jours · Ce mois · Mois dernier · Personnalisée), même calendrier,
mêmes messages de chargement, d'absence de données et d'erreur (dont « Droit manquant », sans « Réessayer »), mêmes
cartes et tableau sur tablette, même feuille du bas pour les filtres (bouton « Filtres » de la barre : type,
utilisateur ; choix des familles / emplacements / grossistes de la Valorisation), même champ de recherche. Les
données et les appels au serveur ne changent pas.

## Tests

Tous les tests du lot 1 et de la vague 1 passent, plus : test des versions (`test/non_regression/`), affichage de
la version (`test/version_affichee_test.dart`), bornes des réglages des alertes, paramètres transmis au serveur,
parcours « réglage → ⟳ → valeurs utilisées », période en mois du Suivi Péremption, période de 3 ans.
