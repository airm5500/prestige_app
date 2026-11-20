# Prestige Pharmacien 3.17.0+57 — Réponse du serveur aux demandes 67 et 68 (CA crédit paginé, carte TVA)

## Numéro de version

**3.17.0+57** : 3.17.0 parce que l'écran CA crédit et la carte TVA de l'accueil savent utiliser deux nouvelles
réponses du serveur, 57 parce que le numéro de build augmente de 1. Rien n'a encore été publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

Serveur de référence : branche `correctif/demandes67-68-2011` (ef0b1838), **pas encore fusionnée ni déployée en
officine** (la fusion suivra la validation du pharmacien).

## À retenir

**Le gain arrivera avec le déploiement serveur des demandes 67 et 68.** Tant que l'officine garde le serveur actuel,
l'application se comporte exactement comme la 3.16.0 (mêmes écrans, mêmes chiffres, mêmes requêtes une fois le
serveur reconnu). Dès que le serveur est mis à jour, elle en profite d'elle-même, sans réglage.

## 1. CA crédit (demande 67 : `GET v1/ca-credit` paginé et totalisé)

La nouvelle interface demande `GET /ca-credit?dtStart=&dtEnd=&start=0&limit=50` (+ `query`, `tiersPayant` s'ils sont
donnés). Le mode est détecté à la première réponse et retenu pour la session (serveur local / distant et connexion) :

- **réponse objet** `{ total, montant, clients, tiersPayants, data }` (serveur à jour) :
  - chiffres clés (montant, ventes, clients) lus dans l'objet : ils portent sur TOUTES les ventes retenues, pas sur la
    page ; « sur N » quand un filtre est actif ; liste des tiers payants du filtre lue dans l'objet (libellé affiché
    sans les espaces autour, envoyé tel quel) ;
  - pages de 50 : la suivante (`start` = lignes déjà chargées) est demandée d'elle-même près du bas de la liste,
    indicateur dans le pied « n lignes affichées sur N » (« Afficher plus » reste disponible) ; une page vide arrête
    la lecture (période relue entre deux pages) ; une page arrivée pendant un défilement est ajoutée à l'arrêt de la
    liste ;
  - recherche (anti-rebond **300 ms**) et tiers payant envoyés au serveur ; une réponse périmée n'est jamais affichée ;
  - tirer pour rafraîchir : page 0 **sans filtre** (la recherche et le tiers payant sont effacés) : le serveur relit
    alors la base ;
  - PDF : toutes les ventes filtrées en une requête (`limit` = total), mêmes chiffres que l'écran ;
- **réponse liste** (serveur actuel, qui ignore ces paramètres) : comportement 3.16.0 — décodage hors du fil de
  l'interface, recherche et filtre locaux, 50 par 50 sans requête ; les lectures suivantes de la session sont celles
  de la 3.16.0 (`dtStart`, `dtEnd`) ;
- réponse d'une autre forme : « Aucune vente à crédit », comme la 3.16.0.

**Première page lente** (le serveur lit toute la période : 12 à 16 s pour un mois chargé, les pages suivantes
≈ 10 ms) :

- « Lecture de la période… » affiché dès l'ouverture ;
- délai d'attente de **60 s** pour cette route seulement (`CaCreditDonnees.delai` ; les autres routes gardent 45 s) ;
- jamais deux fois la même lecture en parallèle : ⟳ pendant la lecture reprend la lecture en cours ; une recherche ou
  un tiers payant choisi pendant la lecture l'attend, puis UNE seule requête filtrée part (rapide : la période est
  gardée 60 s par le serveur) ; changer de période lit tout de suite la nouvelle (l'ancienne réponse est ignorée).

L'écran d'origine (ancienne interface) est inchangé : il demande toujours la liste.

## 2. Carte « Ventes du mois par taux de TVA » (demande 68 : `GET v1/tableau-bord/tva`)

- `GET /tableau-bord/tva?date=<jour>&frais=0` ; ⟳ → `frais=1` (recalcul) ; réponse `{ success, data : [{ taux, ht,
  tva, ttc }] }` (cache serveur 3 min) ;
- affichage identique : une ligne par taux, part du TTC et montant TTC, total TTC (mêmes montants que
  `api/v3/tvas` TOUT du 1er du mois au jour, vérifié sur les mêmes données) ;
- 404 (serveur actuel) ou 403 : repli sur `api/v3/tvas` comme avant ; la route est retenue pour la session (mémoire
  de l'accueil de la 3.16.0 : plus de 404 avant ⟳). Le 404 de cette route essayée ne déclenche pas la vérification
  `/officine` (`ApiService.routesSondees`). Coût sur le serveur actuel : **une** requête de plus par session (l'essai,
  quelques millisecondes) ; sur un serveur à jour, `api/v3/tvas` (statistique générale, plus lourde) n'est plus lue ;
- forme inattendue : repli pour cette lecture seulement (la route n'est pas retenue).

## Écarts et besoins serveur

`RETOUR_DEMANDES67_68_pharmacien.md` (bloc-notes de la session) : aucun écart bloquant entre la réponse et le code de
la branche serveur ; quelques remarques (période gardée 60 s et pages lues après expiration, nombre de tiers payants
après recherche).

## Tests (comme `ci.yml`)

- `test/unitaires/retours_3_17_0_test.dart` : objet / liste / forme inattendue, paramètres d'une page, délai propre à
  la route, mode retenu par source, faux serveur (pages bout à bout, libellé entouré d'espaces) ; TVA : mêmes lignes
  que `/tvas`, liste vide, formes inattendues.
- `test/integration/retours_3_17_0_test.dart` (faux serveur à jour `test/support/donnees_3_17_0.dart`) : pagination
  complète (bout à bout, dernière page, rien au-delà du total, page vide inattendue), recherche serveur (une requête
  après 300 ms, réponse périmée jamais affichée), tiers payant, tirer pour rafraîchir, PDF, première page lente (pas
  de doublon, indicateur, 50 s acceptées, changement de période), serveur ancien identique à la 3.16.0 (recherche et
  « Afficher plus » locaux, requête 3.16.0 ensuite, forme inattendue) ; TVA : nouvelle route, `frais=1` au ⟳, replis
  404 / 403 retenus, forme inattendue non retenue, mois sans vente.
- `test/ergonomie/retours_3_17_0_test.dart` : CA crédit paginé à 320 / 360 dp × texte 1 / 1,3 (attente lisible,
  chiffres entiers, page suivante) et sur tablette 1280 × 800 (tableau 50 → 130 lignes, total) ; carte TVA à 320 /
  360 dp. Cas « 3.17.0 » ajoutés au rendu complet (`test/support/cas_retours_3_17_0.dart`, 5 tailles × 2 échelles).
- Faux serveur : `/tableau-bord/tva` répond 404 par défaut (serveur déployé en officine) — `test/support/donnees_vague4.dart`.
- Mis à jour pour le nouveau comportement voulu : `test/lot3_non_regression_test.dart` (CA crédit de la nouvelle
  interface : même période, plus `start=0&limit=50`) ; budgets de requêtes de l'accueil sur le serveur actuel
  (`test/performance/requetes_test.dart` 10 → 11, `test/performance/retours_3_11_0_test.dart` et
  `test/performance/ios_test.dart` 8 → 9 : l'essai de `/tableau-bord/tva`).
