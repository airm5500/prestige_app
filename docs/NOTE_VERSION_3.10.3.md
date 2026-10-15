# Prestige Pharmacien 3.10.3+44 — « Serveur injoignable » et « Serveur indisponible », deux cas distincts

## Numéro de version

**3.10.3+44** (3.10.3 = correction ; 44 = +1 par rapport à 43). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## Retour du pharmacien sur la 3.10.2

Il distingue DEUX cas, à afficher différemment (deux interfaces ; connexion, démarrage, modules) :

| Cas | Situations | Message |
|---|---|---|
| **1. Serveur injoignable** | Wi-Fi bon mais serveur injoignable : réseau absent, hôte inaccessible, **connexion refusée** (PC serveur éteint ou Payara arrêté), délai dépassé à la connexion | « **Serveur injoignable. Vérifiez le Wi-Fi et que le PC serveur est allumé.** » |
| **2. Serveur indisponible** | Le serveur répond mais Prestige n'est pas déployé : 404 de Payara (page HTML ou vide), 502 / 503 / 504 | « **Serveur indisponible : Prestige est en cours de démarrage ou de redéploiement. Veuillez réessayer dans un instant.** » |

**Correction de la 3.10.2** : la connexion refusée était classée « Serveur indisponible » ; elle revient au cas 1
(et les deux tests adaptés en 3.10.2, `integration/services_test.dart` et `reseau/coupures_reprise_test.dart`, attendent
de nouveau « Serveur injoignable »).

**Inchangés** : mot de passe faux (message du serveur), erreur 500 (« Erreur du serveur »), réponse illisible,
certificat HTTPS refusé, 404 MÉTIER d'un module (élément introuvable).

## Comment l'application reconnaît le cas 2

- **502 / 503 / 504** : sur toute route.
- **404 d'une route toujours présente** (connexion `/user/auth`, `/officine`, `/licence/find`) : Prestige n'est pas
  déployé.
- **404 d'une autre route** : il peut s'agir d'une réponse métier, d'une route absente d'un serveur plus ancien… ou de
  Prestige pas déployé. Sur ce 404 SEULEMENT, l'application lit `GET /officine` (une requête) : `/officine` en 404 ou
  502 / 503 / 504 → cas 2 ; `/officine` répond → le 404 d'origine est gardé. **Aucune requête de plus en fonctionnement
  normal.**
- Conséquence voulue par le pharmacien : quand l'application décide « serveur ancien » sur un 404 (recherche
  « contient » de l'onglet Analyses : repli « commence par » sur `/info`), elle ne le conclut plus si Prestige n'est pas
  déployé — elle affiche « Serveur indisponible ».

## Où

- **Connexion** (deux interfaces) : cas 1 et cas 2 comme ci-dessus (délai dépassé → cas 1).
- **Démarrage** (écran du serveur) : « Le serveur ne répond pas » + cas 1 ; « Serveur indisponible » + cas 2 (et
  « Si cela dure, vérifiez le nom de l'application et le port »). La licence n'est jamais mise en cause.
- **Modules** : titre « Serveur injoignable » (cas 1, message avec le Wi-Fi et le PC serveur) ou « Serveur
  indisponible » (cas 2), « Réessayer ». Un module long qui dépasse son délai garde « Le serveur ne répond pas — met trop
  de temps à répondre » (le serveur est joignable, le calcul est long).
- **Alertes de l'accueil A** : mêmes messages.

## Tests

- Mis à jour et complétés : `unitaires/serveur_indisponible_test.dart` (messages exacts, quels échecs relèvent du cas 2),
  `integration/serveur_indisponible_test.dart` (connexion ; modules : 404 + `/officine` qui répond → 404 d'origine et
  UNE vérification ; 404 + `/officine` en 404 ou 503 → cas 2 ; 503 → cas 2 sans vérification ; fonctionnement normal :
  aucune requête `/officine` ; recherche : repli « serveur ancien » seulement sur un vrai 404),
  `reseau/serveur_indisponible_test.dart` (connexion refusée, Wi-Fi coupé, délai → cas 1 ; démarrage en 503 → cas 2 ;
  module pendant un redéploiement → cas 2 puis Réessayer), `e2e/parcours_serveur_indisponible_test.dart` (vrai port fermé
  → cas 1), ergonomie (« Démarrage · serveur indisponible », « Module · serveur indisponible (redéploiement) », deux
  interfaces, 5 tailles × 2 échelles), performance (`requetes_test.dart` : une requête, aucune relance).
- Mis à jour (règle changée par le pharmacien) : `integration/services_test.dart` (connexion refusée → cas 1 ; 404
  d'`/officine` → cas 2, 404 d'une route de module → refus 404), `reseau/coupures_reprise_test.dart`,
  `unitaires/utilitaires_test.dart` (nouveau texte du cas 1), `licence_lancement_test.dart` (titre « Serveur
  indisponible »).
- `flutter analyze` : 44 remarques, aucune nouvelle.
