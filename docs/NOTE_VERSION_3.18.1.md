# Prestige Pharmacien 3.18.1+61 — heure du serveur fausse : le refus 423 du serveur est affiché tel quel

## Numéro de version

**3.18.1+61** : 3.18.1 parce qu'il s'agit d'une adaptation de la 3.18.0 au nouveau refus du serveur (aucun écran
nouveau), 61 parce que le numéro de build augmente de 1. Rien n'a encore été publié sur Sunmi (`docs/VERSIONS_SUNMI.md`).

## 1. Le nouveau refus du serveur (branche serveur `plan/24112026`, lue en lecture seule)

Quand l'heure du serveur est fausse, le serveur refuse **toute écriture** (POST / PUT / DELETE / PATCH), sauf la
connexion (`v1/user/auth`, `v1/user/auth-badge`), la déconnexion (`v1/user/logout`) et les routes `v1/horloge/*`, avec
**HTTP 423** :

```json
{"success": false, "horlogeBloquee": true, "msg": "Opération refusée : l'heure du serveur est fausse. ..."}
```

Les lectures (GET) restent permises. Rien n'est enregistré. Seuls l'administrateur ou la tâche Windows du serveur
remettent l'heure : l'application ne propose aucun contournement.

En 3.18.0, ce 423 donnait « Le serveur a refusé la demande (code 423). » (message de l'application, pas celui du
serveur) ; l'interface d'origine pouvait aussi afficher « erreur inconnue » faute de message.

## 2. Ce qui change

- `lib/services/api_service.dart` (traitement d'erreur central, `_handleResponse`) : HTTP 423 →
  `ApiLoadException.horloge(msg)` : demande refusée (`NatureErreur.refus`, code 423, `horlogeBloquee: true`), message
  = `msg` du serveur **tel quel** (sans message lisible : « Opération refusée par le serveur (code 423). »). Ni panne,
  ni « serveur injoignable », ni « erreur du serveur », ni retour à la connexion. **Aucune relance automatique** : une
  requête par action de l'utilisateur. Journal (versions de développement) : « Écriture refusée HTTP 423 (heure du
  serveur fausse) », jamais le message ni le corps.
- `lib/nouvelle_interface/modules/commun.dart` (`DiagnosticErreur`) : titre « Heure du serveur fausse », message du
  serveur.
- Écritures concernées et texte affiché (message du serveur après le préfixe existant de l'écran) :
  - Pointage BL — pointer / dépointer, N° de séquence, référence d'avoir (PUT) : « Non enregistré : <message> » (la
    pièce revient à son état d'avant) ;
  - Avis clients — traiter, remettre en « Nouveau » (POST) : « Traitement non enregistré : <message> » / « Avis non
    remis en Nouveau : <message> » ;
  - Rappels traitement — marquer (POST) : « Rappels non marqués : <message> » ; actualiser (POST) : <message> ;
    « Racheté » refusé ainsi n'est jamais pris pour un serveur antérieur ;
  - Péremptions courtes — statut (PUT) : « Statut non enregistré : <message> » ;
  - Suggestions — quantité (POST), retrait d'un article et suppression (DELETE) : « Quantité non enregistrée sur le
    serveur : <message> », « Article non supprimé : <message> », « Suggestion non supprimée : <message> » (deux
    interfaces) ;
  - Présences — retirer / réactiver un téléphone (POST) : <message> ;
  - Ticket Z / récap de caisse (lu en POST `/caisse/fetch-tickez`, donc refusé aussi) : écran d'erreur « Heure du
    serveur fausse » avec le message (nouvelle interface), message seul (interface d'origine).
  Les routes d'action lues en GET (annulation d'une vente, mise en attente d'une suggestion…) ne sont pas refusées par
  le serveur. Connexion et déconnexion ne sont jamais refusées.
- **Écran de connexion** (deux interfaces) : `GET /api/v1/horloge/public`, sans session, lu UNE fois à l'affichage
  (et au changement Local / Distant), jamais en boucle :
  - `{"etat": "BLOQUE", "serveur": "24/11/2026 20:52"}` → bandeau d'information « L'heure du serveur est fausse (heure du
    serveur : 24/11/2026 20:52) : le serveur refuse les enregistrements (validations, pointages, avis…) tant qu'elle
    n'est pas remise. La consultation reste possible. » ; la connexion reste possible ;
  - `OK`, `REGULARISATION` (écritures permises) : rien ;
  - ancien serveur (**404**), autre réponse, page HTML, serveur injoignable, délai dépassé : rien.
- **Mode démonstration** : inchangé (écritures refusées avant envoi, « Indisponible en démonstration ») ; aucune
  lecture de `horloge/public`.

## 3. Routes « aussi » du serveur

`vente/update-created-date`, `reglement/reglementdiffere(-all)`, `vente/rappel/{id}`, `ventestats/remove/{id}`,
`ventestats/update/{id}/is_Trash` : **non utilisées** par l'application, rien à changer.

## 4. Tests

- `test/reseau/horloge_bloquee_test.dart` : chaque écriture ci-dessus contre le faux serveur en HTTP réel (423 → message
  tel quel, une requête, session gardée, la même action passe quand l'heure est remise, journal sans le message), 423
  sans message, `horloge/public` (BLOQUE / OK / REGULARISATION / 404 / 401 / 500 / HTML / JSON inattendu / injoignable
  / démonstration) ;
- `test/e2e/parcours_horloge_test.dart` : bandeau de connexion (deux interfaces), Pointage BL refusé, suggestion de
  l'interface d'origine refusée.

Performance : le plafond de requêtes au démarrage (jusqu'à l'écran de connexion) passe de 2 à 3
(`Seuils.demarrageRequetes`) : licence, officine et la lecture unique de `horloge/public` ;
`test/performance/demarrage_test.dart` vérifie qu'il n'y a rien d'autre. Les tests de bout en bout qui contrôlent la
session envoyée excluent cette route publique (comme `/licence`, `/user/auth`, `/officine`). Aucun autre plafond ne change.
