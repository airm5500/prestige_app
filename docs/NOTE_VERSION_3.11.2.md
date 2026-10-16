# Prestige Pharmacien 3.11.2+47 — Détail CA : évolution du Total jour par jour

## Numéro de version

**3.11.2+47** (3.11.2 = retour ; 47 = +1 par rapport à 46). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`). Nouvelle interface seulement ; l'ancienne est inchangée. **Aucune demande au serveur.**

## Précision du pharmacien

Le « jour par jour » visé par le retour 3 de la 3.11.1 est celui du **Détail CA** (section « JOUR PAR JOUR » en bas
de l'écran : une carte par jour, « 12/10/2026 · Espèces … Crédit … Mobile … Carte … · Total 684 500 F »). Ce qui a été
fait en 3.11.1 sur le CA par emplacement (aussi demandé auparavant) est **gardé**.

## Ce qui change

- Sous le **Total** de chaque carte jour, à droite : l'**évolution du Total par rapport au jour précédent de la
  liste** — « ↑ +18,0 % » en vert (hausse), « ↓ −18,3 % » en rouge (baisse), « = 0,0 % » en gris (égal) ; flèche et
  signe toujours, jamais la couleur seule.
- **Rien** pour le premier jour de la liste ni pour le lendemain d'un jour à 0 (pas de pourcentage possible).
- Calcul au dixième, sur les lignes déjà lues : **aucune requête de plus**.
- **La carte ne grandit pas** : la colonne de droite (« Total », montant, %) reste moins haute que celle de gauche
  (date et deux lignes de montants par mode) ; vérifié sur chaque carte de l'écran, téléphone et Sunmi, texte ×1 et
  ×1,3 (`test/ergonomie/retours_3_11_2_test.dart`). Le % est sur une seule ligne, réduit s'il manque de place.
- Tablette (tableau) : inchangée.

## Tests

- Unitaires : `test/unitaires/retours_3_11_2_test.dart` (évolution, premier jour, jour à 0, égalité).
- Ergonomie : `test/ergonomie/retours_3_11_2_test.dart` (hauteur, couleurs, flèches, signes) et le cas
  « 3.11.2 · Détail CA · jour par jour » aux 5 tailles × 2 échelles.
- Bout en bout : `test/e2e/parcours_3_11_2_test.dart` (application entière, valeurs affichées, aucune requête de plus).
- Toute la suite lancée en local avec **exactement** les commandes de `.github/workflows/ci.yml` (mêmes options,
  `-j 1` pour la performance, rapports JSON) avant le push.

## Captures avant / après (téléphone 411 dp et Sunmi 360 dp, texte ×1 et ×1,3)

`docs/maquettes/captures_3_11_2/` : `<appareil>_avant_texte_<échelle>.png` (3.11.1) et
`<appareil>_apres_texte_<échelle>.png` (3.11.2), produites par
`CAPTURES_3_11=1 PHASE=avant|apres flutter test test/captures_3_11_2_test.dart --update-goldens`. Les cartes ont la
même hauteur avant et après.
