# Prestige Pharmacien 3.11.1+46 — Retours du pharmacien sur la 3.11.0

## Numéro de version

**3.11.1+46** (3.11.1 = retours ; 46 = +1 par rapport à 45). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`). Nouvelle interface seulement ; l'ancienne est inchangée. **Aucune demande au serveur.**

## 1. Tableau de bord — fréquentation horaire

- **Part du CA** : sous chaque tranche, « 9,8 % du CA » = part de la tranche dans le chiffre d'affaires de la journée
  (le serveur envoie déjà le CA par heure, `caH`, avec les ventes).
- **Écart avec la veille** entre parenthèses : flèche, signe et couleur — vert « (↑ +3) » pour une hausse, rouge
  « (↓ −12) » pour une baisse, gris « (= 0) » si égal ; rien si la veille n'est pas connue. C'est l'écart du **nombre
  de ventes** (le nombre affiché au bout de la barre). La couleur n'est jamais seule : flèche et signe l'accompagnent.
  Repli « semaine » (serveur sans le Pilotage) : comparé à la semaine précédente, comme avant.
- **Choix de la tranche** (le plus simple proposé) :
  - **« Par heure » / « Par 2 h »** (deux puces) ;
  - **plage d'heures** (menu) : « Heures d'ouverture » (par défaut : de la première à la dernière heure avec une
    vente, ce jour ou la veille — comme en 3.11.0), « De 7 h à 22 h », « Toute la journée ».
  - Les tranches de 2 h partent du début de la plage (07-09 h, 09-11 h…), la dernière est coupée à la fin de la plage.
  - Choix **mémorisé** sur l'appareil ; le changer ne relit rien (0 requête).
- La veille est dans la **même réponse** que le jour choisi : **aucune requête de plus** (mesuré).

## 2. Tableau de bord — chiffres du jour

- Puces **Aujourd'hui / Hier / Personnaliser** (un jour au calendrier), comme la fréquentation :
  `GET /tableau-bord/tuiles?date=<jour>` — **une requête par changement**, l'évolution « CA vs la veille » est dans la
  réponse (0 requête de plus).
- « Achats du jour » devient « Achats » pour un autre jour.
- Serveur ancien (sans `/tableau-bord/tuiles`) : aujourd'hui → ancienne route du tableau de bord web (inchangé) ; un
  autre jour → « Indisponible sur ce serveur » (l'ancienne route ne connaît qu'aujourd'hui ; elle n'est pas appelée).
- Une réponse arrivée en retard (serveur lent) n'écrase jamais les chiffres du jour choisi ensuite (test réseau).

## 3. CA par emplacement — jour par jour

- Chaque jour affiche son **% d'évolution par rapport au jour précédent** : flèche, signe, vert en hausse, rouge en
  baisse, gris si stable ; **sur la même ligne, même hauteur** qu'une ligne sans évolution (mesuré au dixième de dp :
  téléphone et Sunmi, texte ×1 et ×1,3).
- Une légende sous « Total par tranche » dit ce que mesure le % : « par rapport au jour précédent » en vue jour par
  jour (granularité JOUR du serveur), « par rapport à la tranche précédente » sinon.
- Le serveur envoie déjà cette évolution (`e_<jour>`, `evolutionsTranches`) ; l'application l'affichait en 3.11.0
  pour les lignes et le total. **Ajout** : quand un serveur ne l'envoie pas, l'application la calcule de la même façon
  (au dixième). Pas d'évolution pour le premier jour ni pour le lendemain d'un jour sans vente (dimanche fermé) :
  le serveur ne la donne pas (division par zéro), l'application non plus. *À confirmer avec le pharmacien si « vue
  jour par jour » désignait un autre écran.*

## 4. Balance vente / caisse — graphiques

- Onglet **Balance** : **camembert** « Répartition du chiffre d'affaires », au choix **par mode de paiement** ou **par
  type de vente** (COMPTANT / CRÉDIT) ; le % est écrit dans les parts assez grandes ; **légende** : couleur, libellé,
  montant et %. Remplace la liste « Part dans le chiffre d'affaires » (mêmes chiffres). Aucune requête de plus.
- Onglet **Évolution par mode** : **barres empilées**, une barre par période, une couleur par mode ; légende : total
  de chaque mode et sa part ; touché : le détail de la période. Les cartes par période restent dessous.
- Couleurs : celles de la charte (aucune couleur nouvelle), dans un ordre fixe.

## 5. Sélecteur de période (décision du pharmacien)

Dans **tous les menus** qui l'utilisent (même composant) : **trois boutons** [Aujourd'hui ▾] [Hier] [Personnaliser].
Le premier ouvre **juste en dessous** un menu : Aujourd'hui (en tête, pour y revenir), 7 jours, Ce mois, Mois dernier
(l'ordre d'avant). Un raccourci choisi donne son nom au bouton (« Ce mois ▾ »), qui reste en surbrillance. Le bouton
« Autres périodes » est retiré. Personnaliser est inchangé (calendrier). Mêmes périodes, **mêmes requêtes** (une par
choix, mesuré). Les tests qui touchaient « Aujourd'hui » passent par le menu.

## 5 bis. Correction relevée par la CI

Écran de chargement (3.11.0) : la ligne « Étape n sur 4 · adresse:port » en gris sur le bas du dégradé avait un
contraste de 4,41:1 sur Sunmi 1080 × 1920 (attendu 4,5:1 ; la longueur de l'adresse change la position du texte, d'où
un écart vu sur la CI seulement). Les trois textes gris de l'écran passent au gris foncé de la charte (`grisTexte`).

## 6. Mesures (faux serveur en mémoire, local)

| Mesure | Valeur |
|---|---|
| Tableau de bord, ouverture : requêtes | 7 (inchangé ; veille de la fréquentation et des chiffres : 0 de plus) |
| Chiffres d'hier : requêtes | 1 |
| Fréquentation 1 h / 2 h / plage : requêtes | 0 |
| Pire image (jour, tranches, plage) | 123 ms téléphone, 50 ms Sunmi (seuil 600) |
| Balance, camembert modes ↔ type de vente : requêtes | 0 |
| Balance, pire image (camembert, barres) | 72 ms (seuil 1 500) |
| Sélecteur de période, « Ce mois » : requêtes du Détail CA | 1 (comme avant) |

## 7. Tests

- Unitaires : `test/unitaires/retours_3_11_1_test.dart` (tranches, parts, écarts, plages, évolution calculée, parts
  des graphiques) ; `retours_3_11_0_test.dart` mis à jour (sélecteur).
- Intégration : `test/integration/retours_3_11_1_test.dart` (tuiles?date=, repli ancien serveur, caH, évolution
  calculée identique à celle du serveur) ; `retours_3_11_0_test.dart` mis à jour.
- Bout en bout : `test/e2e/parcours_3_11_1_test.dart`.
- Ergonomie : `test/ergonomie/retours_3_11_1_test.dart` (hauteur des lignes jour par jour, couleurs, flèches, signes)
  et les écrans de `test/support/cas_retours_3_11_1.dart` aux 5 tailles × 2 échelles.
- Performance : `test/performance/retours_3_11_1_test.dart`. Réseau : `test/reseau/retours_3_11_1_test.dart`.

## 8. Captures (téléphone 411 dp et Sunmi 360 dp)

`docs/maquettes/captures_3_11_1/` (`telephone_*.png`, `sunmi_*.png`), produites par
`CAPTURES_3_11=1 flutter test test/captures_3_11_1_test.dart --update-goldens` :

01 chiffres d'aujourd'hui · 02 chiffres d'hier · 03 fréquentation par heure · 04 menu des plages · 05 fréquentation
par 2 h, de 7 h à 22 h · 06 CA par emplacement jour par jour · 07 le même, texte ×1,3 · 08 Balance, camembert par
mode · 09 camembert par type de vente · 10 barres de l'évolution par mode · 11 sélecteur de période · 12 son menu
ouvert · 13 « Ce mois ▾ ».
