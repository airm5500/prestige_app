# Prestige Pharmacien 3.6.1+35 — retours du pharmacien sur le lot 4

Réponses aux cinq questions de la note 3.6.0 (`NOTE_VERSION_3.6.0.md`). Seuls deux points changent : le **Fichier
Journal** s'affiche par 50 avec « Afficher plus », et le **Récap de caisse** s'exporte en **PDF**. L'**ancienne
interface ne change pas** (Fichier Journal d'origine : toujours 200 actions au plus, aucun export du ticket Z).

## Numéro de version

**3.6.1+35** (3.6.1 = retouches de 3.6.0 ; 35 = +1 par rapport à 34). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## Réponses du pharmacien

| # | Question | Décision | Dans l'application |
|---|---|---|---|
| 1 | Code administrateur pour l'annulation | Demandé seulement aux comptes ni administrateur ni pharmacien | **Rien à changer.** Confirmé par les tests existants : `e2e/parcours_lot4_test.dart` (« compte non responsable → code administrateur demandé ») et `lot4_non_regression_test.dart` (profil `dashboard` : annulation sans code). |
| 2 | Totaux en tête du Récap de caisse | Garder les totaux actuels | **Rien à changer** (caissiers, espèces, total VNO/VO, nombre de totaux). |
| 3 | Fichier Journal limité à 200 | Afficher par 50 avec « Afficher plus » | **Fait**, voir ci-dessous. |
| 4 | Ouverture des Achats Fourn. | « Aujourd'hui » comme avant | **Rien à changer.** |
| 5 | Exports | PDF du ticket Z | **Fait**, voir ci-dessous. |

## Fichier Journal : par 50, « Afficher plus »

**Vérifié dans le serveur Prestige** (`CommonRessource.logs`, `GET /common/logs` ; `LogServiceImpl.logs`) : la route
lit `start` et `limit` (`setFirstResult(start)` / `setMaxResults(limit)`, tri par date décroissante) et rend
**`total`** = nombre d'actions qui correspondent aux filtres. **Le serveur pagine déjà** : aucune demande au serveur
n'est nécessaire (rien ajouté dans `docs/serveur/`).

- L'écran demande **50 actions** à l'ouverture : mêmes filtres qu'avant (`dtStart`, `dtEnd`, `criteria`, `userId`)
  avec `start=0&limit=50`.
- **« Afficher plus (N) »** en bas de la liste demande la page suivante (`start=50`, puis `100`…) **avec exactement
  les mêmes filtres** que la première page ; les actions s'ajoutent à la suite. Le pied indique « 50 lignes affichées
  sur 120 ». Le bouton disparaît quand tout est chargé.
- Le chiffre **Actions** donne le total annoncé par le serveur (« 50 chargées » dessous tant que tout n'est pas là).
- Changer de période ou de filtre repart de la première page. La recherche reste **locale** (sur les actions chargées,
  aucune requête).
- Page suivante en échec : message, les actions déjà chargées restent, « Afficher plus » peut être retouché.
- **Avertissement gardé** : si un serveur ne rend pas de `total` (version sans pagination), l'application affiche ce
  qu'elle a reçu 50 par 50 **sans aucune autre requête** et prévient « Limite du serveur atteinte : d'autres actions
  peuvent manquer ».

## Récap de caisse : export PDF du ticket Z

Menu **« Exporter » → « PDF du ticket Z »** (barre de l'écran, comme Suivi Péremption). Le PDF reprend **exactement**
ce qui est affiché, **sans recalcul ni nouvelle requête** :

- A4, en-tête bleu nuit avec le **nom de l'officine** et « Récapitulatif de caisse (ticket Z) » ;
- **période** (« Aujourd'hui · 14/10/2026 »…), **caissier** et **heures** du récapitulatif affiché, date d'impression ;
- **chiffres en tête** (caissiers, espèces, total VNO/VO, nombre de totaux) ;
- **totaux globaux**, puis **un bloc par caissier** (modes, puis totaux en gras) ; négatifs en rouge avec le signe « - » ;
- pied de page « Page x / y ».

Impression ou partage par le dialogue du système (paquet `printing`, comme les autres exports PDF). Police intégrée au
PDF : fonctionne **hors ligne**. Rien à exporter (chargement, erreur, période vide) : message « Aucune donnée à
exporter ». Fichier : `Ticket_Z_2026-10-14.pdf` (ou `Ticket_Z_<début>_au_<fin>`).

## Captures (données fictives)

`docs/maquettes/captures_lot4/` : `1d_recap_caisse_exporter.png` (menu Exporter), `1e_recap_caisse_pdf.png` (aperçu du
PDF, `1e_ticket_z_exemple.pdf`), `3d_journal_50_sur_120.png`, `3e_journal_100_sur_120.png`,
`3f_journal_limite_serveur.png` (remplace `3d_journal_limite_200.png`) ; Récap mis à jour (icône Exporter dans la barre).

## Tests

- `test/integration/lot4_retours_test.dart` : pages de 50 (50 → 100 → 130, mêmes filtres, aucune requête de trop,
  recherche locale), serveur sans `total` (50 par 50 côté appli, **une seule requête**, avertissement), page suivante en
  échec ; PDF : **chaque ligne et chaque chiffre de l'écran retrouvés à l'identique** dans le texte du PDF, aucune
  requête, rien à exporter sans donnée.
- `test/unitaires/lot4_donnees_test.dart` : paramètres et lecture des pages (`total` nombre, texte ou absent), texte du
  PDF ligne par ligne, caractères compatibles, nom du fichier, PDF A4 contenant tous les mots (officine, montants…).
- `test/e2e/parcours_lot4_test.dart` : Journal 50 puis 100 (puis filtre : `criteria=4`, `start=0` puis `50`) ;
  Récap : Exporter → PDF (mêmes chiffres que l'écran, officine, filtre caissier repris). Les autres modules du lot 4
  gardent « pas de menu Exporter ».
- `test/lot4_non_regression_test.dart` : l'écran d'origine envoie toujours `limit=200` ; le nouvel écran envoie les
  **mêmes filtres** avec `start=0&limit=50` et affiche les mêmes actions.
- Ergonomie et cohérence : nouveaux états (Récap menu Exporter, Journal 50 / 100 sur 120, limite du serveur) aux
  5 tailles × texte 1,0 / 1,3, sans aucun écart toléré.
