# Prestige Pharmacien 3.7.0+36 — taille de l'écran

Nouveau réglage **« Taille de l'écran »** (Automatique / Compact / Très compact), repris tel quel de Prestige
Inventaire et de Prestige Mobile, pour les petits terminaux Sunmi (V2s 5,45″, V3). Détails : `docs/TAILLE_ECRAN.md`.

## Numéro de version

**3.7.0+36** (3.7.0 = nouveauté ; 36 = +1 par rapport à 35). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## Ce qui change

- **Où** : nouvelle interface, **Réglages › Apparence** (sous la présentation) ; ancienne interface,
  **Configuration** (écran « Configuration IP »).
- **Choix** : *Automatique* (taille définie par Android ; **Compact appliqué d'office sur un petit écran** : côté
  long < 740 dp ou côté court < 340 dp, ex. Sunmi V2s 360 × 720 dp, V3 360 × 640 dp — les réglages affichent alors
  « Automatique (Compact appliqué sur cet écran) ») ; *Compact* (tout 10 % plus petit) ; *Très compact* (20 %).
  Un choix manuel l'emporte toujours.
- **Protégé** par le code administrateur (même fenêtre que la configuration du serveur).
- **Appliqué au prochain lancement** ; la fenêtre qui suit le choix propose « Plus tard » ou « Relancer
  maintenant » (retour à l'accueil, **la session reste ouverte**).

## Ce qui ne change pas

- **Téléphones courants** (1080 × 2400) et **tablettes** : rien ne change en Automatique.
- **PDF et impressions** (ticket Z, Suivi Péremption, Évolution du stock) : mise en page A4 indépendante de l'écran ;
  le graphique exporté a la même image quelle que soit la taille.
- Session (cookie), licence, déconnexion automatique, barre du bas (3 ou 4 onglets), menu latéral de la tablette,
  graphiques, calendriers, feuilles du bas : vérifiés aux trois tailles.

## Tests

- Nouveaux : `test/unitaires/taille_ecran_test.dart`, `test/ergonomie/taille_ecran_test.dart`,
  `test/e2e/parcours_taille_ecran_test.dart`.
- Adaptés (justification dans `docs/TAILLE_ECRAN.md` § 4) : les profils Sunmi 720 × 1440, Sunmi 1080 × 1920 et
  téléphone 360 × 640 dp des tests d'ergonomie sont désormais en Compact automatique ; cibles tactiles exigées à
  48 dp **de l'interface** et contraste mesuré à la résolution de l'interface (`test/support/contraste_interface.dart`,
  avec un témoin qui refuse toujours un texte trop pâle). Aucune autre attente modifiée.
- `flutter analyze` : aucune nouvelle remarque.

## À vérifier sur un Sunmi V2s

1. Réglages › Apparence : « Automatique (Compact appliqué sur cet écran) » affiché ; l'accueil tient sans défilement
   horizontal.
2. Choisir *Très compact* → code administrateur → « Relancer maintenant » : retour à l'accueil, toujours connecté.
3. Exporter un PDF (Récap de caisse) : page A4 inchangée.
