# Prestige Pharmacien 3.8.0+37 — réponses du pharmacien (lots 2 et 3, vague 3, taille de l'écran)

Réponses aux questions des notes 3.3.0 (lot 2, **A**), 3.5.0 (lot 3, **B**), 3.4.0 (vague 3, **C**) et 3.7.0 (taille de
l'écran, **D**). Tout se passe dans la **nouvelle interface** ; l'**ancienne interface ne change pas** (Visualisation BL
d'origine : toujours `checked` ; Configuration : code administrateur toujours demandé pour la taille de l'écran).

Chaque point a été vérifié dans le serveur Prestige (branche `claude/new-session-xm8ptu` à jour, commit `d80bd11`).

## Numéro de version

**3.8.0+37** (3.8.0 = nouveautés ; 37 = +1 par rapport à 36). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## Réponses du pharmacien

| # | Question | Décision | Dans l'application |
|---|---|---|---|
| A1 | Filtres de Visualisation BL sans effet | Statut lu par le serveur ; groupe / utilisateur selon le serveur | **Fait** (ci-dessous) ; demande serveur pour `userId` |
| A2 | Choix multiples | Pas sur mobile pour ces écrans | **Rien à faire** |
| A3 | Suivi Ajustements limité à 100 | « Afficher plus » | **Fait** (le serveur pagine déjà) |
| A4 | Évolution du stock à l'ouverture | « Ce mois » | **Fait** |
| A5 | Passage automatique « en cours » des Suggestions | Garder | **Rien à faire** |
| B1 | Tableau : Analyses à l'ouverture | « Ce mois » | **Fait** |
| B2 | Ratios mensuels | 12 derniers mois glissants | **Fait** (norme 1,51 conservée) |
| B3 | Suivi 20/80 par quantité | Choix CA / quantité sur la vue | **Fait** (le serveur sait classer par quantité) |
| B4 | Exports | PDF Stat TVA, Marge, CA Crédit | **Fait** |
| C1 | « Racheté » à la main | — | **Rien à faire** |
| C2 | Actualisation des rappels | Bouton « Actualiser la liste » à la demande | **Fait** |
| C3 | « Remettre en Nouveau » plus visible | Oui | **Fait** |
| C4 | Réponse au client, envoi des rappels | Plus tard | **À venir** (rien dans cette version) |
| C5 | Rapprochement du relevé PDF | — | **Rien à faire** |
| D1 | Code pour la taille de l'écran | Comme la présentation | **Fait** : « admin » sans code |

## A1 — Visualisation BL : le filtre que le serveur lit vraiment

Vérifié dans `EtatControlBonResource.list` : le serveur lit `statutControle` (`TOUS` / `CONTROLE` / `NON_CONTROLE`,
filtré **avant** la pagination : le « Total BL » est juste), `groupeId` (un groupe remplace le grossiste par les
grossistes du groupe) ; il **ignore** `checked` et `userId`.

- **Statut → « Contrôle »** dans la feuille des filtres : *Tous* · *Contrôlés* (contrôle terminé) · *Non contrôlés*
  (non traités ou en cours), envoyé dans **`statutControle`** ; `checked` part vide. Sans choix, la requête est
  **exactement celle d'avant** (aucun paramètre ajouté). Étiquette « Contrôle : Non contrôlés ».
- **Groupe** : gardé (le serveur le lit). Mention sous le champ : « Un groupe choisi remplace le grossiste ».
- **Utilisateur : masqué.** Solution retenue parce qu'elle est la plus claire : un filtre qui ne filtre rien laisserait
  croire, par exemple, qu'un employé a saisi tous les BL de la journée. Une ligne discrète en italique dans la feuille
  l'explique : « Filtre par utilisateur : proposé quand le serveur Prestige le prendra en compte. » `userId` est
  toujours envoyé, vide (comme avant sans choix) ; la liste des utilisateurs reste chargée (mêmes appels qu'avant).
- **Demande au serveur** : `docs/serveur/DEMANDE_FILTRES_LISTES.md`, section 1 (paramètre `userId`, filtré avant la
  pagination ; `groupeId` et `statutControle` déjà lus : rien à demander pour eux).

## A3 — Suivi Ajustements : « Afficher plus » au-delà de 100

Vérifié dans `AjustementRessource` → `MouvementProduitImpl.ajsutements` : `setFirstResult(start)` /
`setMaxResults(limit)` et `total`. **Le serveur pagine déjà** : aucune demande au serveur.

- Première page : **la requête d'origine** (`page=1&start=0&limit=100`, mêmes dates, même motif).
- « **Afficher plus (130)** » en bas : page suivante (`start=100`, puis `200`…, `page=2`, `3`…) avec **exactement les
  filtres de la première page**. Pied « 100 lignes affichées sur 230 ». Le chiffre « Ajustements » donne le total du
  serveur (« 100 chargés » dessous tant que tout n'est pas là).
- Page suivante en échec : message, les ajustements chargés restent, « Afficher plus » peut être retouché.
- Serveur sans `total` (version plus ancienne) : les 100 premiers comme avant, avec l'avertissement « Limite du
  serveur atteinte ». 100 ajustements ou moins : écran inchangé.

## A4 et B1 — Ouverture sur « Ce mois »

**Évolution du stock** et **Tableau : Analyses** s'ouvrent sur « Ce mois » (du 1er du mois à aujourd'hui). Les autres
périodes restent au choix. Le 1er du mois, la période ne compte qu'un jour (Tableau : Analyses affiche alors son
encadré « choisissez une période plus longue »).

## B2 — Ratios des 12 derniers mois

Le bouton « Ratios des 12 derniers mois » (et l'icône de la barre) ouvre les ratios du **1er jour du mois d'il y a
11 mois jusqu'à aujourd'hui** (le mois en cours compte, jusqu'à aujourd'hui). Le 14/10/2026 : du 01/11/2025 au
14/10/2026. Vérifié dans `ErpServiceImpl.getCaAchatVente` : la route compare des dates complètes
(`DATE(…) BETWEEN dtStart AND dtEnd`) — une période **à cheval sur deux années** passe en **une seule requête**
(pas de double appel). Mêmes calculs (cumul par mois, ratio = ventes / achats, **norme 1,51**), mais cumul par mois
**et année** : octobre 2025 et octobre 2026 ne se mélangent jamais. Mois écrits « Novembre 2025 » ; ligne de total
« 12 mois ». L'écran d'origine garde l'année en cours.

## B3 — Suivi 20/80 : classement par chiffre d'affaires ou par quantité

Puces **« Classer par : Chiffre d'affaires · Quantité »** sous la période. Défaut : **chiffre d'affaires**, requête
**identique** à avant. Vérifié dans `FamilleArticleRessource.vingtQuatreVingt` : le serveur lit **`vingtType`**
(`CA`, `QTY`, `MARGE`) ; `QTY` appelle la procédure `analyse_20_80_par_quantite` (articles classés par quantité
décroissante). Par quantité, l'application ajoute donc `vingtType=QTY` **et** trie la liste reçue par quantité vendue
décroissante (tri stable : sans effet si le serveur l'a fait ; protège d'un serveur plus ancien qui ignorerait
`vingtType`). Par quantité : rang, carte et « Part qté » portent sur la quantité ; le montant reste affiché.

## B4 — Exports PDF : Stat TVA, Marge Produits Vendus, CA Crédit

Menu **« Exporter »** (barre de l'écran) → « PDF des statistiques TVA » / « PDF des marges » / « PDF des ventes à
crédit ». Même style que le PDF du ticket Z : **A4**, en-tête bleu nuit avec le **nom de l'officine** et le titre,
**période**, **filtres** appliqués (type de vente ; marge et recherche ; recherche et tiers payant — « aucun » sinon),
date d'impression, **chiffres clés** en cartes, puis le **détail** en tableau (en-tête répété sur chaque page) avec sa
**ligne de total** ; pied « Page x / y ». Les montants sont **les textes de l'écran** (aucun recalcul, aucune
requête) ; **toutes** les lignes retenues par les filtres partent dans le PDF, pas seulement les 50 construites à
l'écran (Marge : jusqu'à 9 999 produits, sur plusieurs pages). Quand un filtre réduit la liste, une carte de plus
rappelle le nombre sans filtre (« Produits vendus (sans filtre) »). Impression ou partage par le dialogue du système
(`printing`), police intégrée (hors ligne). Rien à exporter : « Aucune donnée à exporter ». Fichiers :
`Stat_TVA_2026-10-14.pdf`, `Marge_produits_vendus_…`, `CA_credit_…` (`…_<début>_au_<fin>` pour une période).

## C2 — Rappels traitement : « Actualiser la liste »

Le serveur ne recalcule pas tout seul : bouton **« Actualiser la liste »** en haut de l'onglet Liste.

- **Confirmation** : « Le serveur recalcule les rappels sur un an de ventes : cela peut prendre du temps (plusieurs
  minutes). Aucun message n'est envoyé au client. » — « Non » : rien n'est envoyé.
- « Oui » : **un seul** `POST /rappels-habitude/actualiser` (sans `jour` : aujourd'hui) ; le bouton laisse la place à
  l'indicateur « Actualisation en cours… (calcul sur un an de ventes) » (un second appui est impossible ; « Recharger »
  est bloqué pendant le calcul). Délai d'attente : 5 minutes.
- Succès : « Liste actualisée : 2 nouveaux rappels, 1 racheté. », puis **relecture de la liste et du compteur**.
- **Refus « déjà en cours »** (le serveur n'accepte qu'un calcul à la fois) : son message s'affiche (« Une
  actualisation est déjà en cours : la liste sera à jour dans un instant. »), rien d'autre. Délai dépassé : « Le
  serveur ne répond pas. Le calcul continue peut-être sur le serveur : rechargez la liste dans quelques minutes. »
- **Aucun envoi de message** (SMS / WhatsApp) : inchangé, toujours refusé avant envoi.
- L'icône ⟳ de la barre s'appelle désormais « Recharger » (elle relit la liste, sans recalcul).
- `/rappels-habitude/actualiser` est **retirée de la liste des routes interdites** (`routesInterditesVague3`) : le
  pharmacien l'a demandée. Tests adaptés en conséquence (voir « Tests »).

## C3 — Avis : « Remettre en Nouveau »

Dans le détail d'un avis **Lu** ou **Traité**, bouton visible **« Remettre en Nouveau »**, **seulement avec le droit
« Répondre aux avis »** (`droits.repondre`). Confirmation légère (« Cet avis apparaîtra de nouveau comme non lu pour
toute l'équipe. La note interne est gardée. »), puis **un seul** `POST /avis-clients/avis/{id}/traiter`
`{statut: NOUVEAU, noteInterne}`. Vérifié dans `AvisClientService.traiter` : `NOUVEAU` est accepté ; comme le serveur
réécrit la note interne à chaque traitement, l'application renvoie **la note enregistrée** (elle n'est pas effacée ;
une modification non enregistrée du champ reste dans le champ). La liste prend le nouveau statut sans requête.
Rappel : rouvrir l'avis le marque de nouveau « Lu » (comportement du serveur).

## C4 — À venir

**Réponse aux avis** (WhatsApp / e-mail) et **envoi des rappels** (SMS / WhatsApp) : prévus dans une prochaine version
(avec confirmation renforcée et journal des envois). **Rien n'est ouvert dans cette version** : ces routes restent
refusées par l'application avant tout envoi.

## D1 — Taille de l'écran : « admin » sans code

Comme pour la présentation A / B / C : dans Réglages › Apparence, le compte **« admin »** change la taille de
l'écran **sans code** (pas de cadenas ; sous-titre « Pour tous les comptes de ce téléphone ») ; les autres comptes
saisissent le code administrateur. Ancienne interface (Configuration) : code toujours demandé (inchangé).
`docs/TAILLE_ECRAN.md` mis à jour.

## Captures (données fictives)

Captures des écrans modifiés régénérées (icône « Exporter » dans la barre de Stat TVA, Marge et CA Crédit, bouton
« Ratios des 12 derniers mois », bouton « Actualiser la liste », etc.) ; nouvelles captures :

- `docs/maquettes/captures_lot2/` : `3b_visualisation_bl_filtres.png` (Contrôle, groupe, mention utilisateur),
  `3d_visualisation_bl_non_controles.png`, `6_evolution_stock.png` (« Ce mois »),
  `8c_suivi_ajustements_100_sur_230.png`, `8d_suivi_ajustements_afficher_plus.png`.
- `docs/maquettes/captures_lot3/` : `1_analyses.png` (« Ce mois »), `2c_ratios_mensuels.png` (12 derniers mois),
  `3_suivi_2080.png`, `3d_suivi_2080_par_quantite.png`, `4d_stat_tva_exporter.png`, `5d_marge_exporter.png`,
  `6c_ca_credit_exporter.png`, PDF d'exemple `4e_stat_tva_exemple.pdf`, `5e_marge_exemple.pdf`,
  `6d_ca_credit_exemple.pdf` et leurs aperçus `4e_stat_tva_pdf.png`, `5e_marge_pdf.png`, `6d_ca_credit_pdf.png`.
- `docs/maquettes/captures_vague3/` : `7_avis_detail_traiter.png`, `10_rappels_liste.png` (bouton « Actualiser la
  liste »), `17_avis_remettre_en_nouveau.png`, `18_avis_confirmation_remettre_en_nouveau.png`,
  `19_rappels_confirmation_actualiser.png`, `20_rappels_actualisation_en_cours.png`, `21_rappels_liste_actualisee.png`.

## Tests

- Nouveaux : `test/unitaires/retours_3_8_0_test.dart` (statuts, pages d'ajustements, 12 mois glissants et passage
  d'année, cumul mois + année = calcul d'origine sur une année, classement par quantité, texte et PDF A4 multi-pages,
  résultat de l'actualisation) ; `test/integration/retours_3_8_0_test.dart` (écrans contre le faux serveur,
  **paramètres transmis vérifiés** : `statutControle` / `checked` vide / `userId` vide / `groupeId`, pages
  `start` 0-100-200 avec les mêmes filtres, une requête 2025-11-01 → 2026-10-14, `vingtType=QTY`, PDF = textes de
  l'écran sans requête, un seul POST d'actualisation, refus « déjà en cours », un seul POST « Remettre en Nouveau »).
- Bout en bout : `e2e/parcours_lot2_test.dart` (statut « Non contrôlés » → `statutControle`, total 16 ; Évolution sur
  « Ce mois »), `e2e/parcours_lot3_test.dart` (Analyses sur « Ce mois », 12 derniers mois, 20/80 par quantité puis
  retour, menu Exporter présent pour TVA / Marge / CA Crédit et PDF du CA Crédit filtré), `e2e/parcours_vague3_test.dart`
  (Actualiser la liste, Remettre en Nouveau), `e2e/parcours_taille_ecran_test.dart` (« admin » sans code ; ancienne
  interface : code demandé même pour « admin »).
- Ergonomie et cohérence, 5 tailles × texte 1,0 / 1,3, sans écart toléré : Visualisation BL filtrée, Ajustements
  100 sur 230 et limite du serveur, 20/80 par quantité, menus Exporter (TVA, Marge, CA Crédit), confirmation et
  calcul en cours de l'actualisation, détail traité et confirmation « Remettre en Nouveau », réglage de la taille pour
  l'administrateur ; les écrans existants modifiés (feuille des filtres de Visualisation BL, Ratios mensuels, liste
  des rappels, détail d'un avis) sont rendus par leurs cas existants.
- **Non-régression des données** : mêmes requêtes et mêmes chiffres qu'avant pour les mêmes paramètres. Seules
  attentes adaptées, avec justification dans le test :
  - `lot2_non_regression_test.dart` : Visualisation BL filtrée par statut — la nouvelle interface envoie
    `statutControle=CONTROLE` et `checked` vide au lieu de `checked=TERMINE` (A1) ; tous les autres paramètres
    restent identiques. Évolution du stock : ouverture sur « Ce mois » (A4) ; même requête et mêmes points pour
    « Aujourd'hui ».
  - `lot3_non_regression_test.dart` : Tableau : Analyses s'ouvre sur « Ce mois » (B1), comparaison faite sur
    « Aujourd'hui » (mêmes requêtes, mêmes points) ; Ratios mensuels sur 12 mois glissants (B2), mêmes ratios pour les
    mois communs.
  - `e2e/parcours_lot2_test.dart`, `e2e/parcours_lot3_test.dart` : mêmes changements de période et de paramètre.
  - Vague 3 : `/rappels-habitude/actualiser` n'est plus dans `routesInterditesVague3` (C2, décision du pharmacien).
    `unitaires/vague3_test.dart` la classe désormais parmi les routes autorisées ; `integration/vague3_api_test.dart`
    teste le refus avant envoi sur `/rappels-habitude/sms` à sa place ; pour ne rien affaiblir, chaque test des
    fichiers vague 3 vérifie toujours qu'**aucune actualisation** n'est reçue sans « Actualiser la liste »
    (`actualisationsRecues`, dans le `tearDown`).
  - Faux serveur : `/etat-control-bon/list` filtre `statutControle` comme le vrai ; `/ajustement` rend `total`
    comme le vrai.
- `flutter analyze` : aucune nouvelle remarque (44, comme avant).

## Questions pour le pharmacien

1. **Suivi 20/80, « Nombre d'articles »** : en vérifiant B3, nous avons vu que le serveur limite le nombre d'articles
   avec le paramètre `topN` et **ignore `limit`**, que les deux interfaces envoient depuis l'origine. Sur le serveur
   actuel, ce réglage (50 par défaut) est donc **sans effet** : tous les articles du 20/80 sont affichés. Faut-il
   envoyer `topN` (le nombre choisi serait alors vraiment appliqué), ou retirer ce réglage ?
2. **Visualisation BL, « Non contrôlés »** : le serveur regroupe « Non traité » et « En cours ». Ce regroupement vous
   convient-il, ou faut-il demander au serveur deux statuts séparés ?
3. **Actualiser la liste des rappels** : souhaitez-vous ce bouton réservé à l'administrateur et au pharmacien (comme
   aujourd'hui, avec le droit « Rappels de traitement »), ou à un droit plus restreint côté serveur (calcul lourd) ?
4. **Exports PDF** : faut-il aussi un export CSV (tableur) de la Marge et du CA Crédit ?
