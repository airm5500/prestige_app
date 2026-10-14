# Prestige Pharmacien 3.4.0+32 — vague 3 des nouveaux menus (écritures légères)

Trois nouveaux menus, **réservés à l'administrateur et au pharmacien** (profil « dashboard », comme les vagues 1 et
2), dans la nouvelle interface : **Pointage BL**, **Avis**, **Rappels traitement**. Ils écrivent un peu dans Prestige
(pointage, statut d'un avis, statut d'un rappel) ; **le serveur vérifie lui-même le droit** de chaque action et un
refus s'affiche « Droit manquant ».

Décision du pharmacien : **consulter et traiter d'abord. AUCUN message (WhatsApp, SMS, e-mail) ne part du mobile**
dans cette version : pas de « Répondre au client », pas d'envoi de rappels. Ces routes sont refusées par
l'application avant tout envoi, et les tests vérifient qu'elles ne sont jamais appelées.

L'**ancienne interface** et les menus déjà livrés (lots 1 et 2, vagues 1 et 2) ne changent pas.

## Numéro de version

**3.4.0+32** (3.4.0 = nouveaux menus ; 32 = +1 par rapport à 31). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

Captures (données fictives) : `docs/maquettes/captures_vague3/` — téléphone 1080 × 2400 px, tablette 1920 × 1200 px.

| Fichier | Écran |
|---|---|
| `1_pointage_choisir_grossiste.png` | Pointage BL à l'ouverture : choisir un grossiste ou un groupe |
| `2_pointage_pieces_totaux.png`, `3_pointage_piece_pointee.png` | Totaux en cartes, pièces ; une pièce pointée (message vert) |
| `4_pointage_sequence_refusee.png` | N° de séquence refusé (même règle que le serveur), rien n'est envoyé |
| `5_avis_liste.png`, `6_avis_filtres.png` | Avis : liste, feuille des filtres |
| `7_avis_detail_traiter.png`, `8_avis_detail_lecture_seule.png` | Détail d'un avis avec « Traiter » ; sans le droit : lecture seule |
| `9_avis_analyse.png` | Analyse des avis |
| `10_rappels_liste.png`, `11_rappels_selection.png`, `12_rappels_confirmation_marquer.png` | Rappels : liste, deux rappels choisis, confirmation |
| `13_rappels_analyse.png` | Analyse des rappels (6 mois) |
| `14_droit_manquant.png` | « Droit manquant » (sans « Réessayer ») |
| `15_tablette_pointage.png`, `16_tablette_avis_analyse.png` | Tablette |

## Pointage BL (web « pointagebl », droit `P_SM_POINTAGE_BL`)

Onglet « Pointage » du web seulement (le rapprochement avec le relevé PDF reste sur le web).

- **Critères** : un **grossiste OU un groupe** de grossistes (obligatoire, comme le web : rien n'est demandé au
  serveur avant ce choix ; choisir l'un efface l'autre), **période** (« Ce mois » à l'ouverture = début du mois,
  **un an au plus** comme le serveur), **état** Toutes / Non pointées / Pointées.
- **Totaux en cartes** (ceux du serveur) : total BL, avoirs, net HT, pointées, à pointer.
- **Pièces** : type (BL, avoir d'un retour, manquants à la réception), N° BL, date, statut, **montant HT négatif pour
  un avoir**, N° de séquence, référence d'avoir, contrôle fait dans l'application (en rouge **et** en texte s'il y a
  des écarts), « pointée le … par … ». Tablette : deux colonnes.
- **Actions, seulement sur une pièce pointable** (BL et avoir d'un retour ; jamais « manquants à la réception ») :

| Action | Requête | Contrôle avant envoi (identique au serveur) |
|---|---|---|
| Pointer / dépointer | `PUT /pointage-bl/pointer/{BL\|RETOUR}/{id}?pointe=true\|false` | pièce pointable |
| N° de séquence (BL) | `PUT /pointage-bl/sequence/{blId}?valeur=` | vide (efface) ou `[A-Za-z0-9 ./-]`, **20 caractères** au plus |
| Référence d'avoir (retour) | `PUT /pointage-bl/avoir/{retourId}?valeur=` | vide ou `[A-Za-z0-9 ./-]`, **40 caractères** au plus |

- Saisie refusée : le message du serveur (« N° de séquence : 20 caractères au plus (chiffres, lettres, - / .). ») est
  affiché sous le champ et **rien n'est envoyé** ; valeur inchangée : rien n'est envoyé (comme le web).
- **Mise à jour immédiate** (optimiste) : la pièce et les compteurs changent tout de suite ; si le serveur refuse ou ne
  répond pas, **tout revient comme avant** et la cause s'affiche en rouge (« Non enregistré : Erreur du serveur… »).
- **Anti double envoi** : pendant l'envoi, le bouton laisse la place à un indicateur ; un second appui n'envoie rien.

## Avis (web « avisclients », droits `P_SM_AVIS_CLIENTS` et `P_AVIS_REPONDRE`)

- À l'ouverture : `GET /avis-clients/droits` (sans droit de lecture → « Droit manquant ») puis la liste.
- **Onglet « Avis »** : 30 derniers jours (comme le web) avec le sélecteur de période commun, recherche « contient »
  (texte, employé, client), **pages de 50** (« Afficher plus »). Filtres dans la feuille du bas : note (1 ou 2
  étoiles, 4 ou 5 étoiles, 5 … 1 étoile), statut (Nouveaux, Lus, Traités, Non traités), clients qui attendent une
  réponse, mot-clé (un mot, 40 caractères), thème, employé cité (liste tirée de l'analyse de la période, comme le web),
  tri (plus récents, plus anciens, notes basses, notes hautes).
- **⚠ `GET /avis-clients/avis/{id}` ÉCRIT** : le serveur passe un avis « Nouveau » à « Lu ». L'application ne
  l'appelle **que lorsque vous touchez un avis** — jamais en préchargement, jamais pour rafraîchir la liste (au retour,
  la carte prend le statut renvoyé, sans nouvelle requête). Un test le vérifie (aucun détail demandé tant qu'on ne
  touche pas, puis exactement un par avis touché).
- **Détail** : note, date, autres avis du même appareil, critères appréciés / à améliorer, texte, employé cité ;
  client : anonyme, ou nom, téléphone, e-mail et « réponse souhaitée » ; réponse déjà faite depuis le web (lecture).
- **« Traiter »** (seulement si `droits.repondre`) : statut Nouveau / Lu / Traité et **note interne** (non visible du
  client, **1500 caractères**, nettoyée exactement comme le serveur : balises et caractères invisibles retirés,
  espaces réduits), `POST /avis-clients/avis/{id}/traiter {statut, noteInterne}`, **un envoi par appui**, message
  vert / rouge. **Sans le droit, l'action n'existe pas** : statut et note en lecture, avec l'explication.
- **Onglet « Analyse »** (`GET /avis-clients/analyse?du=&au=`) : avis, note moyenne, satisfaits, mécontents,
  nouveaux, négatifs non traités, réponses attendues (avec la période précédente) ; **alertes touchables** (elles
  filtrent la liste : « 23 avis à 1 ou 2 étoiles non traités » → liste filtrée) ; points forts / à améliorer ;
  répartition des notes ; critères ; thèmes ; employés cités (touchables : filtre) ; mots-clés ; évolution.
- **Pas** de « Répondre au client » (WhatsApp / e-mail), **pas** de réglages, d'affiche ni de régénération du jeton
  du QR code (secret). L'écran rappelle : « La réponse au client se fait depuis Prestige (web). »

## Rappels traitement (web « rappelstraitement », droit `P_SM_RAPPELS_HABITUDE`)

- **Onglet « Liste »** : `GET /rappels-habitude/liste?statut=&query=&dtStart=&dtEnd=`, statut **À préparer** à
  l'ouverture (puces : À préparer, À préparer et préparés, Préparés, Écartés, Rachetés, Tous), recherche (client,
  téléphone, produit, CIP), date prévue dans la feuille (toutes, en retard, aujourd'hui, 7 / 30 prochains jours).
  La liste du serveur **n'est pas paginée** (2000 lignes au plus) : elle est affichée de façon **virtualisée** (seules
  les lignes visibles sont construites), fluide même longue. Compteur « N rappels à préparer au total »
  (`GET /rappels-habitude/compteur`).
- Chaque ligne : produit, client et téléphone, statut, « En retard », « Stock 0 », prévu le, fréquence, dernier
  achat, stock, CIP, rappel déjà envoyé (date), « par … ».
- **« Marquer »** : cases à cocher (et « Tout choisir »), barre du bas « N rappels choisis · marquer : **Préparé /
  Écarté / À préparer** », **confirmation** (« Aucun message n'est envoyé au client »), `POST
  /rappels-habitude/marquer?statut= {ids}`, **un envoi par appui**, puis relecture de la liste et du compteur.
- **Onglet « Analyse »** (`GET /rappels-habitude/analyse`, **6 mois** par défaut, 3 ou 12 au choix) : rappels, à
  préparer, préparés, écartés, rachetés, envoyés, **efficacité** (rachetés après un rappel envoyé), canaux, par mois.
- **Pas** d'envoi (`/envoyer`, `/sms`), **pas** d'« Actualiser la liste » (`/actualiser`, recalcul sur un an de
  ventes) : refusés par l'application avant envoi.

## Protections communes

- **Routes interdites** refusées AVANT envoi (`routesInterditesVague3`) : `/rappels-habitude/envoyer`, `/sms`,
  `/actualiser`, `/avis-clients/avis/{id}/repondre`, `/avis-clients/reglages` (et `/regenerer`), `/avis-clients/affiche`,
  `/pointage-bl/releve…`, `/pointage-bl/modele`. Les tests (intégration et bout en bout) vérifient après chaque
  parcours qu'aucune n'a été reçue par le faux serveur.
- **Erreurs distinctes** : Droit manquant (sans « Réessayer », sans déconnexion), demande refusée (message du
  serveur, ex. « Pièce introuvable. »), Erreur du serveur, Le serveur ne répond pas (45 s en lecture, 20 s en
  écriture), Serveur injoignable, Session expirée (retour à la connexion).
- **Données des clients et de santé** (nom, téléphone, e-mail, traitement) : affichées seulement, gardées en mémoire
  le temps de l'écran ; **jamais écrites dans le journal** (le journal ne note que le chemin, sans paramètres ni
  corps : ni recherche, ni note interne, ni N° de séquence — test dédié) **ni sur le disque** (aucune préférence,
  aucun fichier, aucun cache).
- Nouvelles méthodes `ApiService.put` et `ApiService.postAvecParametres` (mêmes contrôles d'erreur que `post`).
- Sélecteur de période commun : contrôle supplémentaire facultatif par écran (un an pour le pointage).

## Tests

- `test/unitaires/vague3_test.dart` : lecture tolérante (pièces, droits, avis, analyse, rappels), refus distincts,
  **contrôles identiques au serveur** (séquence, avoir, période d'un an, note interne nettoyée comme `Texte.libre`,
  statuts « marquables »), routes interdites, paramètres envoyés, menus réservés.
- `test/integration/vague3_api_test.dart` (HTTP réel, faux serveur) : routes, méthodes, paramètres et corps exacts ;
  succès, `success:false`, `interdit:true`, 403, 401, 500, délai, serveur arrêté ; saisies refusées sans requête ;
  détail d'avis jamais demandé par la liste ou l'analyse ; journal sans aucune donnée de client ou de santé.
- `test/e2e/parcours_vague3_test.dart` (application entière) : chaque menu ; pointer / dépointer ; **double appui =
  un envoi** ; **échec → pointage annulé** ; séquence invalide refusée ; avis touché = un détail ; traiter (un envoi) ;
  **sans le droit, « Traiter » absent** ; marquer plusieurs rappels (confirmation, annulation sans envoi) ; droit
  manquant ; tablette ; autre profil sans ces menus.
- `test/ergonomie/affichage_vague3_test.dart` : 21 écrans et états aux 5 tailles × texte 1,0 / 1,3, **sans aucun écart
  toléré**, et cohérence (bleu nuit, Lato, aucun ancien style).
- Captures : `CAPTURES_VAGUE3=1 flutter test test/vague3_captures_test.dart --update-goldens`.

## Questions pour le pharmacien

1. **« Racheté » à la main** : le serveur refuse de marquer un rappel « Racheté » (`marquer` n'accepte que À préparer,
   Préparé, Écarté ; « Racheté » est posé par l'actualisation quand la vente est constatée). Le mobile propose donc
   Préparé / Écarté / À préparer. Faut-il demander au serveur d'accepter « Racheté » ?
2. **Actualisation des rappels** : sans « Actualiser » sur le mobile, la liste dépend du calcul fait sur le web (ou la
   nuit). Est-ce suffisant, ou faut-il une actualisation programmée côté serveur ?
3. **Avis ouverts = lus** : toucher un avis le marque « Lu » pour toute l'équipe (comportement du serveur). Voulez-vous
   un bouton « Remettre en Nouveau » plus visible (c'est déjà possible par « Traiter » → Nouveau) ?
4. **Réponse au client et envoi des rappels** : à ouvrir dans une prochaine vague (avec confirmation renforcée et
   journal des envois) ?
5. **Pointage** : faut-il aussi le rapprochement avec le relevé PDF sur mobile (import d'un PDF depuis le téléphone) ?
