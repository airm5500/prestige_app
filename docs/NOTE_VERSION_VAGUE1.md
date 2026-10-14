# Vague 1 des nouveaux menus du pharmacien (lecture seule)

> **Mise à jour 3.1.0+28** : fusionnée avec le lot 1, mêmes composants que le lot 1 (période, états, filtres dans une feuille du bas, tableau), réponses aux 5 questions appliquées (Ruptures sur l'accueil A, Valorisation réservée, réglages des alertes sur le mobile, personnalisation filtrée) : voir `NOTE_VERSION_3.1.0.md`.

Branche `claude/vague1-menus` (partie de `claude/presences`, à fusionner avec le lot 1). Nouvelle interface seulement :
l'ancienne interface est inchangée. Routes **existantes** du serveur Prestige (`claude/new-session-xm8ptu`), aucune
écriture.

## Visibilité

Nouveaux menus (**Alertes**, **Retraits et abandons**, **Ventes modifiées**, carte « Toutes les alertes » de
l'accueil A) : **administrateur et pharmacien** seulement, c.-à-d. `xtypeuser == "dashboard"` dans la réponse de
`POST /user/auth` (le serveur le donne à l'administrateur « 00 », au super-administrateur, à l'administrateur et au
pharmacien). `AppUser.typeUser` le garde, `ProfilAcces` (`lib/nouvelle_interface/vague1/profil_acces.dart`) le publie
et `menusVisibles` filtre les menus marqués `responsables: true`. Le menu existant **Valorisation** reste visible
pour tous (il est seulement enrichi).

Le serveur ne vérifie aucun droit sur ces routes (session seulement). Si un refus arrive quand même
(`success:false`, `interdit:true`, 403), l'écran affiche « Droit manquant : consulter … » **sans déconnecter** ;
`success:false` avec `erreur:true` (calcul en échec côté serveur) est une erreur du serveur ; 401 /
« Veuillez vous connecter » ramène à la connexion (mécanisme existant).

## Menus

| Menu | Routes | Comportement |
|---|---|---|
| Valorisation (mis à jour) | aujourd'hui : `GET /tableau-bord/valorisation?frais=0` (⟳ : `frais=1`) ; date passée ou regroupement : `GET /produit/valorisation?mode=&dtStart=&lgFAMILLEARTICLEID=` / `lgZONEGEOID` / `lgGROSSISTEID` ; listes `/common/famillearticles`, `/common/rayons`, `/common/grossiste` | Onglets Rayon / Réserve / Total : achat, vente, écart, marge % (écart / vente, comme le web), produits dormants. Aujourd'hui chargé à l'ouverture (léger) ; date passée ou regroupement seulement sur « Calculer ». Date jamais future. « Relevé indisponible » si `releveDisponible:false`. Accès à « Évolution du stock » (bouton de la barre). |
| Alertes | `GET /tableau-bord/alertes?per=6&rup=7&ren=7&sug=2&nv=30` ; `GET /tableau-bord/alertes/liste?type=…&per=6&rup=7&nv=30&limite=500` | **Aucun appel automatique** : ⟳ ou « Compter les alertes ». Résultat et heure mémorisés (serveur + compte). Cartes : ruptures, péremptions, stocks négatifs, entrés jamais vendus, réassort du rayon (listes) ; suggestions non commandées → module Suggestions ; suggestions de réserve, ordonnances à renouveler, avoirs → nombre seul. Listes filtrables, tableau sur tablette. |
| Retraits et abandons | `GET /vente-suppressions` (clé `results`), `/common/users` | Période (aujourd'hui par défaut, raccourcis, début ≤ fin, jamais future, 366 jours au plus), type, utilisateur, recherche avec anti-rebond ; pages de 50 (« Afficher plus ») ; cartes / tableau. Pas de « Créer inventaire ». |
| Ventes modifiées | `GET /ventes-modifiees` (clé `results`) | Mêmes filtres + type (Tous / Produits / Infos / Date) ; détail avec les lignes avant → après. |

Une réponse arrivée après un changement de filtre est ignorée (le paquet `http` utilisé par `ApiService` ne permet
pas d'interrompre la requête elle-même).

## Où sont les alertes (proposition)

- **Accueil A** (« À surveiller ») : l'alerte « Produits proches de la péremption » est désormais lue dans **le même
  appel** `/tableau-bord/alertes` (même ⟳, mêmes états, même mémoire que l'écran Alertes ; libellé « Lots qui
  périment d'ici 6 mois » car l'appel ne compte pas les lots déjà périmés que liste le module Suivi Péremption ;
  touchée, elle ouvre la liste de ces lots). En dessous, la carte **« Toutes les alertes »** résume le dernier
  comptage (« 8 alertes à surveiller · il y a 5 min ») et ouvre l'écran Alertes.
- **Contrôle des bons de livraison** : `/tableau-bord/alertes` ne compte pas les BL contrôlés ; cette alerte garde
  donc sa route (`/etat-control-bon/list-annuelle`) et son propre ⟳ (voir la question 1).
- **Accueil B et C** : menu « Alertes » (famille Stock ; question C « Que dois-je commander ? »), donc aussi dans la
  recherche de menu (B) et le menu de la tablette.
- **Pas d'onglet dans la barre du bas** : elle reste Accueil · Analyses · Équipe (+ Pilotage prévu). Un 5ᵉ onglet
  serait serré sur les petits téléphones, et un onglet laisse croire à des données « en direct » alors que les
  alertes ne sont comptées qu'à la demande. L'accueil A les montre déjà en tête.

## Tests

- `test/unitaires/vague1_test.dart` (40) : lecture tolérante des 4 formats, refus, paramètres, périodes, visibilité.
- `test/integration/vague1_api_test.dart` (20) : faux serveur en HTTP réel — succès, vide, `success:false`,
  `interdit`, 403, 401, 500, délai, alertes sans appel automatique, double appui, mémoire.
- `test/e2e/parcours_vague1_test.dart` (9) : chaque menu ouvert, filtré, refermé (A, B, C, tablette) ; droit
  manquant ; session expirée ; profil `mainmenumanager` → menus absents.
- `test/ergonomie/affichage_vague1_test.dart` (297) : 27 états × 5 tailles × texte 1,0 / 1,3 sans aucun écart ;
  cohérence de la charte.
- Tests existants adaptés au nouvel appel des alertes (`unitaires/alertes_accueil_test.dart`,
  `integration/alertes_accueil_test.dart`, `e2e/parcours_nouvelle_interface_test.dart`,
  `support/cas_affichage_nouvelle.dart`) sans affaiblir leurs attentes.
- Captures : `CAPTURES_VAGUE1=1 flutter test test/vague1_captures_test.dart --update-goldens` →
  `docs/maquettes/captures_vague1/`.

## Questions

1. Contrôle des BL sur l'accueil A : le garder sur sa route (actuel), ou le remplacer par « Ruptures de stock » du
   même appel (un seul ⟳ pour tout « À surveiller ») ?
2. L'alerte péremption de l'accueil ouvre la liste des lots < 6 mois ; préférez-vous le module Suivi Péremption
   (qui compte aussi les lots déjà périmés, nombre différent) ?
3. Valorisation : la garder visible pour tous les comptes (comme avant) ou la réserver aussi au pharmacien ?
4. Réglages des alertes (6 mois, 7 jours…) : les rendre modifiables sur mobile (le web les enregistre par compte via
   `PUT /preferences/...`) ?
5. « Personnaliser l'accueil » liste encore les nouveaux menus pour un compte non autorisé (ils restent masqués
   sur l'accueil) : à filtrer aussi ?
