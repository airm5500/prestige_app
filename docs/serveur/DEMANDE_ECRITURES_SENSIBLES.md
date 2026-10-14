# Demande à la session serveur : sécuriser les écritures sensibles avant leur ouverture sur mobile

**Source.** Analyse du serveur Prestige, branche `claude/new-session-xm8ptu` (commit `a5c52c9`), faite pour les
nouveaux menus de Prestige Pharmacien (`prestige_app`). Chemins relatifs à la racine du serveur, routes sous
`/prestige/api/v1`.

**Pourquoi cette demande.** Le pharmacien veut retrouver sur son téléphone une partie des menus du poste. La vague 1
(valorisation, alertes, retraits et abandons, ventes modifiées) est livrée côté application, **en lecture seule**.
Les vagues suivantes contiennent des **écritures** : stock (ajustement, retour fournisseur), engagement financier
et envoi réel au grossiste (commande PharmaML), créations d'inventaires et de gardes. Aujourd'hui, sur ces routes :

- **aucun droit n'est vérifié par le serveur** : seule la session l'est (`AuthenticationFilter`,
  `SessionObligatoireFilter`). Le poste web masque les boutons selon les droits, mais une application mobile, un
  script ou un simple rejeu d'URL n'est pas arrêté ;
- certaines écritures ne sont **pas idempotentes** : un double appui, une perte de réseau suivie d'un nouvel envoi
  ou une reprise de l'application peuvent appliquer deux fois la même opération ;
- l'application mobile n'a **aucun moyen de connaître les droits** de la session : elle ne peut que tenter l'appel
  et interpréter le refus.

Sur un téléphone (réseau instable, renvois automatiques, appareil perdu ou prêté), ces trous deviennent des
risques réels. L'application ajoutera ses propres gardes (confirmation, verrou anti-double envoi, menus réservés),
mais **seul le serveur peut garantir** qu'une opération n'est faite qu'une fois et par un compte autorisé. Nous
demandons donc les correctifs ci-dessous **avant** d'ouvrir ces écritures sur mobile. Tant qu'ils ne sont pas
livrés, l'application ne propose aucune de ces écritures.

Conventions de réponse demandées pour tous les points (déjà utilisées ailleurs dans l'API) :

| Cas | Réponse |
|---|---|
| Session absente ou expirée | HTTP 401, ou `{success:false, msg:"Veuillez vous connecter"}` |
| Droit manquant | HTTP 403 **ou** `{success:false, interdit:true, msg:"…"}` (jamais 401 : le mobile déconnecterait l'utilisateur) |
| Opération refusée par l'état de l'objet | `{success:false, code:"ETAT", msg:"…"}` (HTTP 409 accepté) |
| Rejeu d'une opération déjà faite (`X-Client-Ref` connu) | la **même** réponse que la première fois, sans rien refaire |

---

## 1. Ajustement de stock (`rest/AjustementRessource.java`, `MvtProduitServiceImpl` l. 585-870 et 1116)

**Constats.**
- `PUT /ajustement/{id}` (clôture, qui écrit le stock) : `cloreAjustement` ne vérifie pas le statut. Un second
  appel (double appui, renvoi réseau) recalcule le « stock après » à partir du stock courant et **ré-applique**
  l'ajustement : le stock est corrigé deux fois.
- `DELETE /ajustement/{id}` (annulation) : `annulerAjustement` supprime l'ajustement et ses lignes **même s'il est
  déjà clôturé**, sans restaurer le stock ; l'historique est perdu alors que le stock reste modifié.
- Aucun droit vérifié sur `creeation`, `add/item`, `item/{id}` (PUT, DELETE), `PUT /{id}`, `DELETE /{id}`. Le web
  masque l'annulation selon `ACTIONDELETEAJUSTEMENT` (030920172) côté interface seulement.

**Demandes.**
1. **Clôture** : refuser si le statut n'est pas « en cours » (`{success:false, code:"ETAT", msg:"Ajustement déjà
   clôturé"}`) ; le contrôle et le passage au statut clôturé dans la **même transaction**, avec verrou sur la ligne
   (`SELECT … FOR UPDATE` ou version optimiste) pour que deux clôtures simultanées ne passent pas toutes les deux.
2. **Annulation** : refuser l'annulation d'un ajustement clôturé (préféré) ; à défaut, la transformer en
   contre-ajustement qui restaure le stock et garde l'historique (mouvements inverses tracés).
3. **Droits vérifiés côté serveur** : création, ajout / modification / suppression de ligne et clôture → droit de
   faire un ajustement (celui qui donne accès au menu « Ajustement ») ; annulation → `ACTIONDELETEAJUSTEMENT`.
4. **Idempotence** : accepter l'en-tête `X-Client-Ref` (comme `POST /retourfournisseur/new` avec
   `MobileClientRefService`) sur `POST /ajustement/creeation` et `PUT /ajustement/{id}` : une seconde requête avec
   la même référence renvoie la réponse de la première sans rien refaire.
5. Préciser dans la réponse de clôture l'emplacement dont le stock a été ajusté (aujourd'hui celui du **créateur**,
   pas de celui qui clôture) pour que le mobile puisse l'afficher.

## 2. Commande PharmaML depuis une suggestion (`rest/SuggestionPharmaMlRessource.java`, `PharmaMlServiceImpl` l. 138)

**Constats.** `POST /suggestion-pharmaml/{id}/envoi` (et la variante synchrone `POST /suggestion-pharmaml/{id}`)
crée au besoin une commande (`creerCommandeDepuisSuggestion`) et **envoie réellement** le message CSRP au grossiste.
C'est un **engagement financier** ; seule la session est vérifiée. Les protections existantes (`attenteEnCours`,
`dejaRepondue`, reprise de la commande créée) évitent le doublon d'envoi, pas l'envoi par un compte non autorisé.

**Demandes.**
1. **Droit vérifié** sur l'aperçu (`GET /suggestion-pharmaml/{id}`), l'envoi (les deux variantes), la récupération
   des réponses (`POST /pharma/reponses`) : le droit de passer commande (celui du menu commandes / PharmaML).
   Refus en 403 ou `interdit:true`.
2. Refuser l'envoi d'une suggestion déjà « commandée » avec `code:"ETAT"` (aujourd'hui géré par `dejaRepondue`
   dans certains cas seulement : à garantir pour tous).
3. Accepter `X-Client-Ref` sur l'envoi : même jeton renvoyé pour la même référence.

## 3. Validation d'un retour fournisseur (`POST /produit/validerretourfour`, `MvtProduitServiceImpl.validerRetourFournisseur` l. 1136)

**Constats.** La validation **sort le stock** (quantités retournées ou acceptées par le grossiste). Les lignes
déjà validées sont exclues (un double appel ne retire pas deux fois : bien), mais **aucun droit** n'est vérifié,
ni sur la validation, ni sur `POST /retourfournisseur/new`, `add-item`, `update-item`, `remove-item`,
`PUT /retourfournisseur/full-bl/{id}`.

**Demandes.**
1. **Droit vérifié** sur la création / modification du retour et, séparément, sur la **validation** (droit de
   valider un retour fournisseur), refus 403 ou `interdit:true`.
2. Refuser la validation d'un retour déjà validé avec `code:"ETAT"` (au lieu d'un succès vide).
3. Accepter `X-Client-Ref` sur la validation (déjà fait pour la création).

## 4. Autres écritures sans droit vérifié

| Route | Effet | Droit à vérifier (menu actuel) |
|---|---|---|
| `POST /gardes`, `DELETE /gardes/{id}`, `POST /gardes/supprimer` | gardes enregistrées | `P_SM_GESTION_GARDES` |
| `POST /gardes/{id}/inventaire`, `POST /gardes/{id}/suggestion` | crée un inventaire / une suggestion | `P_SM_GESTION_GARDES` (+ droit inventaire / suggestion) |
| `POST /ca-zone-geo/detail/inventaire` | crée un inventaire réserve | `P_SM_CA_ZONE_GEO` (+ droit inventaire) |
| `POST /vente-suppressions/create-inventaire` | crée un inventaire | `P_SM_SUPPRESSIONS_VENTE` (+ droit inventaire) |
| `POST /ventes-modifiees/create-inventaire` | crée un inventaire | `P_SM_VENTES_MODIFIEES` (+ droit inventaire) |

Demande : vérifier ces droits côté serveur (refus 403 ou `interdit:true`). Les routes de **lecture** de ces menus
(`/gardes/*` en GET, `/ca-zone-geo`, `/vente-suppressions`, `/ventes-modifiees`) ne vérifient pas non plus le droit du
menu : le faire aussi est souhaitable, ce sont des données de type « mouchard » (activité des employés). L'application
réserve déjà ces menus à l'administrateur et au pharmacien (profil `xtypeuser = "dashboard"` de `/user/auth`) et
affiche « Droit manquant : … » sans déconnecter si le serveur refuse.

## 5. Route « mes droits » générale

**Constat.** Il n'existe que des routes par module (`/avis-clients/droits`, `/pharma/droits`, `/rh/droits`,
`/fichearticle/privileges-boutons`). Pour savoir quels menus afficher, le mobile doit appeler chaque route et
interpréter les refus, ce qui multiplie les appels et donne des menus qui échouent à l'ouverture.

**Demande.**

```
GET /api/v1/user/droits
→ {"success": true, "profil": "dashboard", "droits": ["P_SM_POINTAGE_BL", "P_SM_PILOTAGE", "ACTIONDELETEAJUSTEMENT", …]}
```

- liste des privilèges de la **session** (`USER_LIST_PRIVILEGE`, déjà chargée à la connexion par `AccountResource`),
  sous leur nom technique ; `profil` = la valeur `xtypeuser` de la connexion ;
- lecture seule, légère (aucune requête : tout est en session), 401 si la session a expiré ;
- l'application l'appellera une fois après la connexion et masquera les menus et boutons non autorisés (le serveur
  restant juge à chaque appel).

## 6. `GET /avis-clients/avis/{id}` modifie le statut de l'avis

**Constat.** Lire un avis le fait passer de NOUVEAU à LU : un GET qui écrit. Sur mobile, une simple prévisualisation,
un rechargement ou un préchargement marquerait des avis comme lus sans que personne ne les ait lus.

**Demande.** Paramètre `marquerLu` (par défaut `true` pour ne rien changer au poste web) :
`GET /avis-clients/avis/{id}?marquerLu=false` rend l'avis sans modifier son statut ; le mobile marquera lu par un
appel explicite (`POST /avis-clients/avis/{id}/traiter` avec `{statut:"LU"}`, ou une route dédiée).

## 7. Routes de comptage légères

Rappel et complément de `docs/serveur/ROUTES_DE_COMPTAGE.md` : l'accueil du pharmacien compte des alertes **à la
demande**. Depuis la vague 1, l'appel unique `GET /tableau-bord/alertes` remplace le comptage des péremptions ;
il reste :

```
GET /api/v1/etat-control-bon/nombre?dtStart=&dtEnd=&groupeId=     → {"success":true, "nombre":7}
GET /api/v1/fichearticle/perimes/nombre?nbreMois=&…                → {"success":true, "nombre":3}   (si l'écran Suivi Péremption garde sa propre définition)
```

Et, pour les menus suivants : `GET /rappels-habitude/compteur` existe déjà ; même principe souhaité pour les avis
clients nouveaux (`GET /avis-clients/nombre?statut=NOUVEAU`) et les BL non pointés
(`GET /pointage-bl/nombre?etat=NON_POINTES&du=&au=`). Exigences : `SELECT COUNT(*)` seul, mêmes filtres et même
session que la route de liste, mêmes réponses d'erreur.

## 8. Prévisions : les lectures réécrivent la colonne « en cours de commande » (`rafraichirEnCours`)

**Constat** (version 3.2.1+30 de l'application, branche `claude/new-session-xm8ptu`). La mise à jour de la colonne
« en cours » de `t_prevision_produit` n'est **pas** une route appelée par l'application : c'est le serveur qui la
fait **à l'intérieur des routes de lecture**. `PrevisionCommandeServiceImpl.rafraichirEnCours(emplacement)` est appelé
au début de `tableau()` (`GET /analyse-commande/tableau`), `previsions()` (`GET /analyse-commande/previsions`, donc
**à chaque page « Afficher plus »**), `toutes()` (exports), `produit()` (`GET /analyse-commande/produit/{id}`) et
`analyser()` (`GET /analyse-commande/analyse`). À chaque appel : relecture de toutes les commandes en cours
(`enCoursCommandes()`), lecture de toutes les lignes de prévision de l'emplacement, puis un `UPDATE` par produit
dont l'en-cours a changé (avec recalcul de la quantité recommandée et de la couverture). Le poste web fait de même :
l'application ne peut pas l'éviter, elle peut seulement éviter les appels inutiles (ce qu'elle fait déjà : aucune
lecture à l'ouverture des onglets secondaires, pages à la demande).

**Demande.** Ne refaire ce rafraîchissement que s'il n'a pas déjà été fait récemment :

- mémoriser par emplacement l'heure du dernier rafraîchissement (champ en mémoire du service ou colonne
  `dt_EN_COURS` dans `t_prevision_calcul`) et **ne rien faire s'il date de moins de X minutes** (paramètre
  `KEY_PREVISION_EN_COURS_MINUTES`, 15 par défaut, 0 = comportement actuel) ;
- le refaire de toute façon après une écriture qui change les en-cours (création / réception / suppression d'une
  commande : on peut simplement remettre l'heure mémorisée à zéro à ces endroits) ;
- exposer cette heure dans `GET /analyse-commande/tableau` (`"enCoursAJour": "14/10/2026 09:42"`) : l'écran
  pourra afficher « En cours de commande mis à jour à 09:42 » ;
- éventuellement `?rafraichir=1` pour forcer le rafraîchissement (bouton ⟳ de l'écran).

Lecture seule pour l'application : aucun changement de format de réponse n'est nécessaire, la demande est
rétrocompatible.

---

**Côté application, une fois ces points livrés** : la vague « écritures » (ajustement, retour fournisseur, commande
PharmaML) sera développée avec confirmation explicite, verrou anti-double envoi et `X-Client-Ref` généré par
opération ; les tests d'intégration couvriront les refus `ETAT`, 403 / `interdit`, et le rejeu d'une même référence.
