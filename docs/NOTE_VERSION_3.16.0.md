# Prestige Pharmacien 3.16.0+56 — Retours du pharmacien du 20/11/2026 (lenteurs, adresse par défaut, défilement)

## Numéro de version

**3.16.0+56** : 3.16.0 parce que plusieurs écrans changent de comportement (recherche d'Analyse article, accueil),
56 parce que le numéro de build augmente de 1. Rien n'a encore été publié sur Sunmi (`docs/VERSIONS_SUNMI.md`).

Serveur de référence : `integration/recette-2026-10-29` (5f0ab46f) ; déploiement de l'officine : 76aa5fc1.

## 1. Adresse par défaut

Une configuration **neuve** propose le serveur local `192.168.1.50:8080` (application `prestige`), comme Prestige
Mobile et Prestige Vente (`lib/utils/constants.dart`). Une adresse déjà enregistrée n'est jamais remplacée, même vide
(`IpConfigProvider.loadSettings`) ; une adresse vidée puis enregistrée reste vide (`updateSettings`). L'adresse
distante reste vide par défaut.

## 2. Analyse article plus rapide

Avant : `GET /info?search=<saisie>` à chaque pause de frappe — la route la plus lourde (ventes, achats, inventaire de
chaque article trouvé).

Maintenant (nouvelle interface, `lib/nouvelle_interface/modules/articles_nouveau.dart`, données
`lib/donnees/recherche_produit_donnees.dart`), comme la fiche produit de Prestige Mobile :

- liste par `GET /espace-produit/recherche?q=` (route publique, sans droit, déployée en officine : CIP, nom, EAN,
  « contient », 50 au plus) après un anti-rebond de **300 ms** ; la réponse d'une saisie remplacée est ignorée ;
- repli si la route manque (404) ou est fermée (403) : `GET /vente/search?query=&start=0&limit=30` (la recherche de
  l'écran de vente, session seule), puis `/info` (« commence par », signalé) ;
- au toucher d'un produit : `GET /info?search=<CIP exact>` pour ce **seul** produit, la ligne au CIP exact ;
- cache mémoire court (60 s, `lib/donnees/cache_court.dart`) des listes et des analyses : retaper la même saisie ou
  rouvrir le même produit ne relit rien ; jamais d'erreur gardée ; clé = serveur local ou distant + session (une
  nouvelle connexion ou une adresse modifiée dans la Configuration repart de zéro) ;
- écran fermé pendant la lecture : rien n'est ouvert (la réponse remplit seulement le cache).

La recherche de l'onglet Analyses (3.9.0) profite des mêmes replis et du même cache. L'écran d'origine (ancienne
interface) est inchangé.

**Historique des mouvements** : une ligne par mouvement — « Vente · 12/11/2026 » … « Qté 1234 ». Le libellé et la
date prennent la place restante (« … » seulement s'il le faut, texte agrandi), la quantité garde sa largeur et n'est
jamais coupée ni renvoyée à la ligne (vérifié à 320 et 360 dp, texte ×1 et ×1,3, 1 à 4 chiffres). `LigneDetail`
reçoit l'option `uneLigne` ; toutes les autres lignes de détail gardent leur comportement d'origine.

## 3. État de stock plus rapide

`GET /fichearticle/comparaison` ne part plus dès 1 caractère : **3 au moins** (un CIP ou un EAN complet passe), l'écran
le dit sinon ; anti-rebond 300 ms ; une recherche remplacée est abandonnée et sa réponse jamais affichée. Recherche
vide : seuls les filtres comptent, comme avant.

## 4. Indicateur de défilement

Toutes les listes verticales de l'application (deux interfaces) ont un indicateur **toujours visible** à droite
(`lib/widgets/defilement.dart`, `MaterialApp.scrollBehavior` dans `lib/main.dart`) : Pilotage « À suivre » compris.
Rien sur une liste plus courte que l'écran ni sur une liste horizontale. L'indicateur est dessiné à partir des
notifications de SA liste, sans contrôleur : aucune erreur « ScrollController attached to multiple scroll views »
avec le contrôleur partagé d'un Scaffold ou des onglets. Il ne capte aucun toucher.

## 5. CA crédit plus rapide

`/ca-credit` n'est pas paginé par le serveur (`ErpRessource.caCredis` : `dtStart`, `dtEnd` seulement) → **demande
serveur 67**. En attendant :

- réponse de 256 Ko ou plus décodée et lue **hors du fil de l'interface** (`compute`, `ApiService.getLourd`) ;
- recherche, filtre du tiers payant et chiffres clés calculés **une fois** par changement (mémoïsés), plus à chaque
  image ; la recherche garde son anti-rebond ;
- liste construite à la demande (`ListView.builder`) : seules les cartes à l'écran sont construites, toujours 50 par
  50 (« Afficher plus ») ; tableau inchangé sur tablette ; PDF identique.

## 6. Accueil plus rapide (tableau de bord)

- Les 8 cartes affichées sont lues **en parallèle dès l'ouverture** (avant : au fil du défilement) ; chacune s'affiche
  dès que sa réponse arrive (barre de chargement en attendant), une carte lente ou en erreur ne gêne pas les autres.
- **Mémoire de l'accueil** (gardée le temps de la session) : cache de 2 min → revenir sur l'onglet Accueil affiche tout
  sans attendre ni relire ; une route absente (404) ou refusée (403) est retenue : les replis (tuiles →
  `/recap/dashboard/daily`, fréquentation du pilotage → celle du tableau de bord, valorisation → `/produit/valorisation`)
  partent directement, sans repasser par le 404 et la vérification `/officine` ; une carte « Indisponible sur ce
  serveur » n'est pas relue avant ⟳.
- ⟳ vide la mémoire et relit tout (affluence recalculée : `frais=1`).
- Routes : ce sont déjà celles du tableau de bord web (`TableauBordRessource`, caches serveur de 1 à 15 min). Seule la
  carte TVA lit la statistique générale `api/v3/tvas` : route dédiée demandée (**demande serveur 68**).

## Demandes au serveur

`TRANSMISSION_SERVEUR_2026-11-20_pharmacien.md` (bloc-notes de la session) : demande 67 (pagination et totaux de
`/ca-credit`), demande 68 (`tableau-bord/tva` en cache court). Rien n'est bloquant pour cette version.

## Tests (comme `ci.yml`)

- `test/unitaires/retours_3_16_0_test.dart` : adresse par défaut, cache court, lecture de `/vente/search`, longueur
  minimale de l'État de stock, vue du CA crédit.
- `test/integration/retours_3_16_0_test.dart` : Analyse article (anti-rebond, réponse remplacée, CIP exact, cache,
  replis 404 / 403), État de stock, CA crédit (1 500 ventes), accueil (parallèle, carte lente, mémoire, routes absentes).
- `test/ergonomie/retours_3_16_0_test.dart` : historique sur une ligne (320 / 360 dp × texte 1 / 1,3, 1 à 4 chiffres),
  indicateur de défilement (visible, liste courte, horizontale, contrôleur partagé, application).
- Mis à jour pour le nouveau comportement voulu : `test/lot1_non_regression_test.dart` (Analyse article : liste légère
  puis `/info` au CIP ; mêmes articles, mêmes prix, même fiche), `test/integration/retours_3_9_0_test.dart` (repli
  `/vente/search` avant `/info`), `test/integration/retours_3_15_0_test.dart` (semaines d'affluence déjà lues : mémoire),
  `test/performance/requetes_test.dart` (accueil : les 8 cartes à l'ouverture ; recherche tapée vite : une requête
  `/espace-produit/recherche`), `test/e2e/parcours_lot1_test.dart`, `test/e2e/parcours_nouvelle_interface_test.dart`
  (la recherche publique ne voit pas l'expiration de session : elle se voit au toucher, `/info`),
  `test/e2e/parcours_3_11_1_test.dart` et `test/reseau/retours_3_11_1_test.dart` (retour à « Aujourd'hui » : mémoire,
  route absente retenue), `test/reseau/serveur_lent_test.dart`
  (`/info` lente au toucher : attente visible sur la ligne), `test/integration/serveur_indisponible_test.dart`
  (repli `/vente/search`).
- Indicateur de défilement dessiné SOUS le contenu, couleur du thème (aucune couleur codée en dur :
  `coherence_theme_test.dart`). Mesure du contraste des textes (`test/support/ergonomie.dart`) : l'indicateur est
  masqué pendant la photo de l'écran (un texte coupé au bord droit aurait sinon l'indicateur pour « fond »).
- `test/support/cas_retours_3_15_0.dart` : le bouton « semaine précédente » de l'affluence, construit au bord de
  l'écran selon la date du jour, est amené à l'écran (échec iOS 430 × 932 et iPad déjà présent sur la 3.15.1 à la
  date du 20/11/2026, sans lien avec cette version).
