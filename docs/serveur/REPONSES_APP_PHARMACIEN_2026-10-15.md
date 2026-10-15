# Réponses de l'application Prestige Pharmacien au serveur — 15/10/2026

| | |
|---|---|
| **Date** | 15/10/2026 |
| **Émetteur** | application mobile Prestige Pharmacien (dépôt `prestige_app`), version 3.10.0+41 |
| **Destinataire** | session serveur Prestige (`airm5500/prestige`, branche `claude/new-session-xm8ptu`) |
| **Répond à** | `REPONSE_DEMANDES_MOBILES.md` (15/10/2026), partie 3 « Il me faut une réponse », questions adressées à l'application Pharmacien (n° 2 et n° 26) ; et ce que l'application fait des demandes livrées qui la concernent |

Les réponses s'appuient sur le code de l'application (chemins relatifs à la racine du dépôt `prestige_app`).

## Question n° 2 — `POST pharma/reponses` : quel droit ?

**L'application Prestige Pharmacien n'utilise pas `POST pharma/reponses`**, ni aucune route `pharma/…` (PharmaML) :
aucune commande n'est envoyée aux grossistes depuis le mobile. Vérifié : aucune occurrence de `pharma/` dans `lib/` ;
le module Suggestions le dit (`lib/nouvelle_interface/modules/suggestions_nouveau.dart` : « Aucune commande PharmaML
(prévue plus tard) »).

Le choix du droit n'a donc **aucun effet sur l'application Pharmacien**. Avis de l'application, à confirmer par le
pharmacien : la relève des réponses des grossistes contacte un service extérieur et enregistre des réponses en base ;
la traiter comme une écriture des commandes (**droit des commandes**, `P_SM_COMMANDE_PROCESS` ou le droit déjà vérifié
sur l'envoi), plutôt que comme une lecture libre.

## Question n° 26 — `checked` de Visualisation BL : que met l'application, quel filtre est attendu ?

### Ce que l'application envoie (code réel)

`GET /etat-control-bon/list` est appelé par `ApiService.getBonLivraisons` (`lib/services/api_service.dart`), commun
aux deux interfaces :

| Paramètre | Ancienne interface (`lib/screens/visualisation_bl_screen.dart`) | Nouvelle interface (`lib/nouvelle_interface/modules/visualisation_bl_nouveau.dart`) |
|---|---|---|
| `checked` | valeur de la liste « Statut » : `TERMINE`, `NON_TRAITE` ou `EN_COURS` (texte, jamais un booléen) ; vide si aucun statut choisi | **toujours vide** depuis la 3.8.0 |
| `statutControle` | jamais envoyé | `CONTROLE` (« Contrôlés ») ou `NON_CONTROLE` (« Non contrôlés ») si choisi, absent sinon |
| `groupeId`, `grossisteId` | choix de l'écran | choix de la feuille des filtres |
| `userId` | choix de la liste « Utilisateur » (`lgUSERID` de `GET /common/users`) | 3.10.0 : choix « Utilisateur » **sur un serveur récent seulement** (voir plus bas), vide sinon |

Les valeurs de `checked` sont celles du champ `checked` des bons (`BonLivraisonModel.statut` lit `json['checked']`) :
l'ancien écran filtre sur le **statut du contrôle du BL** (`TERMINE` = contrôle terminé, `NON_TRAITE`, `EN_COURS`).

### Filtre attendu

**Rien à faire côté serveur.** Le filtre attendu est exactement `statutControle` : `TERMINE` ↔ `CONTROLE`,
`NON_TRAITE` + `EN_COURS` ↔ `NON_CONTROLE` ; la nouvelle interface l'utilise déjà et c'est la seule que le pharmacien
fait évoluer. L'ancienne interface reste inchangée (décision constante : on n'y touche pas) ; son filtre « Statut »
reste sans effet, comme avant.

Facultatif, seulement si le pharmacien demande un jour « Non traités » et « En cours » séparément : accepter
`statutControle=NON_TRAITE|EN_COURS` (deux valeurs de plus dans `FiltresControleAchat.Statut`). Pas demandé
aujourd'hui.

### `userId` (livré)

L'application remet le filtre « Utilisateur » dans la nouvelle interface (3.10.0), **seulement si le serveur est
récent** : le rôle `role {code, libelle}` reçu à la connexion (`POST /user/auth`, demande 10) sert de repère, car il
est livré sur la même branche que `userId`. Sur un serveur plus ancien, le filtre reste masqué et `userId` part vide
(comportement 3.8.0). Garde-fou : si la liste reçue contient un bon d'un autre utilisateur que celui choisi, l'écran
affiche « Filtre « Utilisateur » non appliqué ».

## Ce que l'application fait des autres demandes livrées (pour information)

| N° | Livré par le serveur | Dans l'application 3.10.0 | Sur un serveur sans la nouveauté |
|---|---|---|---|
| 9 | `GET v1/user/droits` | **Pas utilisée** : le rôle reçu à la connexion (demande 10) suffit (affiché dans Réglages › Compte, compte comme responsable s'il vaut PHARMACIEN, ADMINISTRATEUR, SUPER_ADMINISTRATEUR ou SYSTEME) ; le serveur reste juge à chaque appel (refus « Droit manquant ») | comportement actuel (`xtypeuser`) |
| 22 | `?marquerLu=false` sur `GET v1/avis-clients/avis/{id}` | Bouton « Actualiser » du détail d'un avis : relecture **sans** marquer « lu » (utile après « Remettre en Nouveau »). L'ouverture d'un avis par l'utilisateur garde le comportement du web (marqué « lu ») | bouton absent (un serveur ancien ignorerait le paramètre et marquerait l'avis) |
| 23 | `enCoursAJour` dans `GET analyse-commande/tableau` | « Commandes en cours à jour le jj/mm/aaaa hh:mm » sous le dernier calcul (onglet Tableau des Prévisions) | ligne absente |
| 25 | `detailMobile` dans `/ca-all` | Détail CA : déjà lu depuis la 3.2.1 (repli `GET /stats-recette-caisse/modes`) ; **CA Global** (3.10.0) : « dont Orange Money … » sous « Total Mobile Money », sans appel de plus | CA Global inchangé ; Détail CA : repli existant |
| 26 | `userId`, `groupeId` sur `etat-control-bon/list` | voir ci-dessus | filtre masqué, `userId` vide |
| 29 | `/nombre` (contrôle BL, avis, pointage) | **Pas utilisées** : depuis la 3.1.0 l'accueil ne charge plus aucune liste pour compter (un seul appel `GET /tableau-bord/alertes`, à la demande) et l'alerte « Contrôle des BL » a été retirée de l'accueil (décision du pharmacien) ; aucun écran ne charge une liste pour n'en garder que le nombre | — |

Nouvelle demande et annulation : `docs/serveur/DEMANDES_SERVEUR_2026-10-15.md`.
