# Prestige Pharmacien 3.9.0+39 — retours du pharmacien sur la nouvelle interface

Six retours, **tous dans la nouvelle interface** ; l'ancienne interface est inchangée (son Suivi 20/80, sa Fiche
Article, son accueil). Vérifié dans le serveur Prestige (lecture seule) : branche `origin/claude/new-session-xm8ptu`
la plus récente (`d1c9b11`, 13/10/2026).

## Numéro de version

**3.9.0+39** (3.9.0 = nouveautés ; 39 = +1 par rapport à 38). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## Résumé

| # | Retour | Dans l'application |
|---|---|---|
| 1 | Suivi 20/80 : choix « Tous » | Interrupteur « Tous les articles » dans la feuille des filtres ; `topN` **absent** (= tous pour le serveur) ; défaut 50 conservé |
| 2 | Fiche Article lente | Menu **retiré** de la nouvelle interface (A, B, C, recherche, personnalisation) ; l'ancienne le garde |
| 3 | Recherche « contient » dans l'onglet Analyses | Zone de recherche en haut de l'onglet → liste → analyse du produit (écran d'Analyse Article) |
| 4 | Pointage BL sans grossiste | **Impossible côté serveur** : explication à l'écran, dernier grossiste (ou groupe) repris, demande au serveur rédigée |
| 5 | Menus paramétrables 0 / 1 | Réglage « Menus de l'accueil » : sur une page (0, défaut) / par pages (1), accueils A et B |
| 6 | Icônes « sans vie » | 3 propositions (P1, P2, P3) dans un réglage caché « Style des icônes » ; **défaut inchangé** ; captures |

## 1 — Suivi 20/80 : « Tous »

- Feuille des filtres : interrupteur **« Tous les articles »** au-dessus du nombre (le champ est alors grisé).
- Requête : **`topN` n'est pas envoyé** (le serveur, `FamilleArticleRessource.vingtQuatreVingt`, lit « absent ou ≤ 0 =
  tous ») ; `limit` part à 9 999 (le serveur l'ignore, inoffensif). Rien n'est coupé côté application.
- Étiquette « Tous les articles » sous la période (✕ pour revenir à 50), chiffre clé « Tous demandés ».
- **Défaut toujours 50** ; « Effacer » revient à 50 ; le classement par quantité reste possible (`vingtType=QTY`).

## 2 — « Fiche Article » retirée de la nouvelle interface

Vérifié : `/checkproduit` (Fiche Article) lit, **pour chaque produit trouvé**, ses informations complémentaires
(dernière vente, dernier achat, inventaire, classe, réserve) : une requête de plus par ligne, d'où la lenteur ; Analyse
Article (`/info`) donne ces informations plus vite.

- Plus de menu « Fiche Article » : accueils A, B, C (questions et « Tous les menus »), recherche de menu,
  « Personnaliser l'accueil ».
- **Il n'y a pas de favoris** dans l'application : seuls l'ordre des menus et les menus masqués sont mémorisés, et ils
  sont **communs aux deux interfaces**. Ils ne sont donc **pas modifiés** : la nouvelle interface ignore simplement
  « Fiche Article » ; et quand on enregistre l'ordre depuis la nouvelle interface, « Fiche Article » (comme
  « Fournisseurs ») **garde sa place** pour l'ancienne (`HomeSettingsProvider.fusionnerOrdre` ; auparavant, ces menus
  partaient en fin de liste dans l'ancienne interface).
- L'ancienne interface garde sa Fiche Article, inchangée.

## 3 — Onglet « Analyses » : recherche de produit « contient »

Vérifié dans le serveur :

- `GET /info?search=` (Analyse Article, `InfoArticleServiceImpl`) **n'a pas de mode « contient »** : le serveur ajoute
  le joker final (CIP ou libellé **commence par**) et ne lit aucun autre paramètre ;
- `GET /espace-produit/recherche?q=` (`EspaceProduitRessource.rechercher`) cherche en mode **« contient »** dans le
  CIP, le nom et l'EAN, dès 2 caractères, **50 résultats au plus**, en une seule requête (rapide), sans donnée d'achat.

Donc : en haut de l'onglet Analyses, une zone **« Rechercher un produit »** (anti-rebond 0,5 s, 2 caractères au moins)
→ liste (nom, CIP, stock, emplacement, prix) par `/espace-produit/recherche` → au toucher, `GET /info?search=<CIP>` et
l'application garde l'article dont le **CIP est exactement** celui touché → **même écran de détail qu'Analyse
Article**. Recherche vide : les menus de l'onglet, comme avant. Au-delà de 50 : « précisez la recherche ».
Sur un serveur plus ancien sans cette route (404) : la recherche passe par `/info` (« commence par ») et l'écran le
dit.

## 4 — Pointage BL : « comment valider une recherche sans grossiste ? »

Vérifié dans `PointageBLRessource.criteres` : grossiste, sinon groupe, sinon **refus « Choisissez un grossiste ou un
groupe de grossistes. »** ; aucun paramètre (vide, absent, `ALL`) ne donne « tous les grossistes ». Une recherche
« tous grossistes » est donc **impossible aujourd'hui**.

- L'écran explique pourquoi le choix est obligatoire (règle du serveur et du web : le pointage se compare au relevé de
  chaque grossiste), rappelle qu'un **groupe de grossistes** en réunit plusieurs ;
- le **dernier grossiste (ou groupe) utilisé est repris** à l'ouverture suivante (mention « Dernier choix utilisé,
  repris automatiquement ») ; un grossiste disparu de la liste est oublié sans requête ;
- demande au serveur (paramètre `tous=true`, grossiste sur chaque pièce, période d'un mois au plus) :
  `docs/serveur/DEMANDE_FILTRES_LISTES.md` §2.

## 5 — « Menus de l'accueil » : sur une page / par pages

Réglages › Apparence › **Menus de l'accueil** (valeur mémorisée 0 / 1 sur l'appareil, pour tous les comptes ; même
règle que la présentation : compte « admin » directement, code administrateur pour les autres) :

- **0 · Sur une page** (défaut) : comme aujourd'hui ;
- **1 · Par pages** : comme l'ancienne interface, les menus défilent par pages — **une famille par page** (A : d'abord
  « À surveiller », licence et alertes) ; balayage gauche / droite, boutons ‹ › (48 dp, libellés) et indicateur de page
  (points) ; titre « VENTES & CAISSE 2 / 7 » annoncé par le lecteur d'écran.
- En pages, l'en-tête bleu de A (chiffres du jour) reste en haut ; s'il dépasse 60 % de l'écran (très grand texte),
  il défile à part, pour que les pages gardent toujours de la place.
- Lecteur d'écran : chaque chiffre clé de l'en-tête est désormais annoncé d'un seul tenant (libellé, valeur, détail).
- Présentations : **A** et **B** sur téléphone. Pendant une recherche de menu (B), les résultats restent sur une page.
  B sur tablette (deux colonnes) et C (cinq questions) restent sur une page : la pagination n'y apporte rien.

## 6 — Propositions de couleurs (embellir, sans changer le défaut)

Réglage **caché** Réglages › Apparence › **Style des icônes**, visible du seul compte « admin » : Actuel (défaut) / P1 /
P2 / P3. Couleur par famille (Ventes vert, Crédits orange, Analyses indigo, Stock sarcelle, Fournisseurs bleu, Équipe
framboise, Alertes rouge) ; chaque couleur d'icône a un **contraste ≥ 4,5:1** sur sa pastille, sa tuile et le blanc.

- **P1 · Couleur par famille** : pastille douce derrière chaque icône, icône colorée ;
- **P2 · Tuiles teintées** : fond de tuile (ou de ligne) légèrement teinté, icône colorée sur pastille blanche ;
- **P3 · Icônes colorées + en-têtes** : icônes colorées sur blanc, en-têtes de famille colorés avec une barre ;
- **barre du bas** (P1 à P3) : icône et libellé de l'onglet actif dans sa couleur, sur un indicateur de même famille.

Captures (téléphone 1080 × 2400) : `docs/maquettes/propositions_couleurs/` — `<style>_1_accueil_A.png`,
`_2_accueil_B.png`, `_3_liste_menus.png`, `_4_barre_du_bas.png` pour `actuel`, `p1`, `p2`, `p3` ; page de comparaison
**`docs/maquettes/propositions_couleurs/index.html`**. Autres captures 3.9.0 : `docs/maquettes/captures_3_9_0/`.

## Tests

- **Nouveaux** : `unitaires/retours_3_9_0_test.dart`, `integration/retours_3_9_0_test.dart` (paramètres transmis),
  `e2e/parcours_retours_3_9_0_test.dart` (application entière), `support/cas_retours_3_9_0.dart` (états rendus par
  l'ergonomie et la cohérence de la nouvelle interface : 3 styles × accueil A, B, onglet Analyses, « Tous les menus »,
  pages, recherche, Pointage, Suivi 20/80, Réglages — 5 tailles × texte 1,0 et 1,3, aucun écart toléré) ;
  `propositions_couleurs_captures_test.dart` (captures à la demande).
- **Mis à jour** (rien d'affaibli) : nombre de menus de la nouvelle interface 36 → 35 (Fiche Article retirée) ;
  parcours lot 1 : Fiche Article n'est plus ouverte depuis la nouvelle interface (test « plus proposée ») ; parcours
  de l'onglet Analyses : le champ d'Analyse Article est désigné précisément (l'onglet a désormais le sien).
- **Plafond de couleurs** de `charte.dart` 31 → 52 : les 21 couleurs des propositions (7 familles × 3), seul fichier
  de palette ; à ramener après le choix du pharmacien. Aucun écran n'en contient.
- `flutter analyze` : aucune nouvelle remarque.

## Questions au pharmacien

1. **Couleurs** : quelle proposition retenir (Actuel, P1, P2, P3, ou un mélange, par exemple P1 + en-têtes de P3) ?
2. **Menus par pages** : une famille par page vous convient-il, ou préférez-vous un nombre fixe de tuiles par page
   (comme l'ancienne interface, 6 par page) ?
3. **Réglage « Menus de l'accueil »** : réservé à l'administrateur (comme la présentation) ou libre pour tous les
   comptes ?
4. **Pointage BL** : la demande « tous les grossistes » (un mois au plus) est-elle à transmettre à l'équipe serveur ?
