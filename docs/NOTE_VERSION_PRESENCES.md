# Prestige Pharmacien — module « Présences » (étape 2)

Nouveau menu **« Présences »** sur l'accueil : voir qui est là, qui est en retard ou absent, aujourd'hui et
hier, sur une période, et afficher le QR code de pointage sur une tablette. **Rien d'autre ne change** : les
menus, les écrans et les réglages existants sont identiques (la nouvelle présentation de l'accueil viendra à
l'étape 3).

Captures de l'application : `docs/maquettes/apercus/app_presences_*.png` (jour, hier, période, fiche employé
sur téléphone ; jour et pointage sur tablette).

## Avant de commencer (prérequis Prestige)

- Le **serveur Prestige** doit contenir le module RH (routes `/api/v1/rh/…`, version avec « Pointage présence »).
  Sinon, l'application affiche : « Fonction non disponible sur cette version du serveur Prestige ».
- Votre compte doit avoir le droit **« Ressources humaines » (P_SM_RH)** dans Prestige. Sinon : « Accès refusé :
  ce compte n'a pas le droit Ressources humaines (P_SM_RH)… » — à ajouter dans Prestige, profil de l'utilisateur.
- Les données viennent de Prestige : **employés et planning** saisis dans Prestige (menu RH), **pointages** faits
  avec Prestige Vente (menu « Pointage présence », téléphone + QR code), la pointeuse (import) ou la saisie
  manuelle. L'application du pharmacien **lit** ces données ; elle ne corrige pas de pointage (cela se fait dans
  Prestige, menu RH).

## Où le trouver

Accueil → menu **Présences** (ajouté **à la fin** pour ne pas déplacer vos menus : il est sur la dernière page).
Pour le mettre en premier : icône ✏️ « Personnaliser l'accueil », faire glisser « Présences » en haut.

Trois onglets en bas (sur tablette : à gauche) : **Jour**, **Période**, **Pointage**. En haut à droite :
**Actualiser** et **Réglages** (seuil de retard).

## 1. Jour : présence d'aujourd'hui et d'hier

- En tête : **Aujourd'hui** / **Hier** ; le bouton avec la date ouvre le calendrier pour un autre jour.
- Les compteurs : **Présents** (arrivés / attendus), **Retards** (et minutes cumulées), **Absents**, **Anomalies**.
- La liste met **les absents et les retards en premier**, puis les anomalies, les départs anticipés, les présents,
  les congés.
- Pour chaque employé : heure prévue, arrivée, départ, durée, les pointages (« 08:02↑ 17:01↓ » : ↑ arrivée,
  ↓ départ) et les anomalies en clair : « Arrivée sans départ », « Départ sans arrivée », « Pointage en double »,
  « Deux arrivées de suite », « A pointé pendant un congé », « Pointé hors planning », « Journée anormalement
  longue ».
- Aujourd'hui, une personne arrivée et pas encore partie n'est **pas** une anomalie (la journée continue) ; une
  personne attendue dont l'heure + le seuil n'est pas encore passée est « Attendu », pas « Absent ».
- **Rechercher** : tapez une partie du nom ou du matricule.
- **Actualiser** : tirez la liste vers le bas, ou touchez ↻ (pas d'actualisation automatique, pour ménager le
  serveur).

## 2. Fiche employé (toucher un nom)

- Les pointages du jour, un par ligne, avec leur **source** : téléphone, pointeuse ou saisie manuelle (et le
  motif de la saisie).
- La **synthèse sur une période** (mois en cours par défaut ; Semaine, Mois dernier ou Personnalisé) : jours
  présents / prévus, retards, présence, heures sup., absences, départs anticipés, anomalies à vérifier.

## 3. Période : tableau et exports

- Semaine, Mois, Mois dernier ou Personnalisé (**366 jours au plus**, jamais dans le futur ; une période trop
  longue est raccourcie avec un message).
- Une ligne par employé ; la toucher ouvre sa fiche.
- **Excel**, **Excel détaillé** (une ligne par employé et par jour) ou **PDF** : le fichier est téléchargé, puis
  **Partager** (WhatsApp, e-mail, Drive…) ou **Ouvrir**. Si le serveur ne peut pas produire le fichier, un message
  l'indique ; rien n'est partagé.

## 4. Pointage : QR code et téléphones

- Le **QR code du moment** change chaque minute ; un compte à rebours indique le prochain changement et
  l'application va chercher le nouveau code toute seule. Le code en lettres (ex. « WPY X5V ») peut être saisi à la
  main dans Prestige Vente.
- **Plein écran** : pour une **tablette posée au comptoir** que les employés scannent avec Prestige Vente. Conseil :
  brancher la tablette et régler sa mise en veille sur « jamais » (réglage Android), sinon l'écran s'éteint.
  Si le réseau coupe, le dernier code est grisé « Code périmé » et l'application réessaie toutes les 10 secondes.
- **Téléphones enregistrés** : **Retirer** (le téléphone est déconnecté tout de suite, l'employé devra se
  reconnecter) ou **Réactiver**. Chaque action demande une confirmation.

## 5. Réglages : seuil de retard

- Réglages (icône en haut à droite) → **Seuil de retard** : **60 minutes par défaut**, de 0 à 480.
- Un employé est « En retard » si son arrivée dépasse l'heure prévue **de plus** que ce seuil
  (seuil 60 : arrivée prévue 08:00, arrivée 09:00 → à l'heure ; 09:01 → en retard).
- Ce réglage ne change que l'**affichage sur ce téléphone** : Prestige garde sa propre tolérance
  (KEY_RH_TOLERANCE_RETARD) pour ses calculs, le tableau sur période et les exports.

## Quand quelque chose ne va pas

Mêmes règles que la version 2.4.0 : une panne n'est jamais affichée comme « aucun employé ».
- « Chargement impossible » + raison (serveur injoignable, serveur trop lent, erreur du serveur) + **Réessayer**.
- Session expirée : retour à l'écran de connexion.
- Droit P_SM_RH manquant ou module RH absent du serveur : message clair (voir « Avant de commencer »).
- « Aucun employé attendu ni pointé ce jour-là » : le serveur a bien répondu, il n'y a rien ce jour-là (pas de
  planning, pas de pointage).

## Comment tester (10 minutes)

1. Se connecter, ouvrir **Présences** (dernière page de l'accueil) : la présence d'aujourd'hui s'affiche.
2. Toucher **Hier** puis **Aujourd'hui** ; choisir une date dans le calendrier.
3. Toucher un employé : ses pointages avec leur source, puis la synthèse du mois.
4. **Période** → **Excel** → **Partager** vers soi-même (e-mail ou WhatsApp) et ouvrir le fichier.
5. **Pointage** : le QR change chaque minute ; **Plein écran** puis ✕. Scanner le QR avec Prestige Vente.
6. **Réglages** : mettre 15 minutes, revenir : les retards de plus de 15 minutes apparaissent.
7. Couper le Wi-Fi, toucher ↻ : « Serveur injoignable » avec Réessayer ; remettre le Wi-Fi, Réessayer.

## Pour l'équipe technique

- Code : `lib/presences/` (modèles et règles testés à part dans `presences_modeles.dart`) ; téléchargement binaire
  `ApiService.getBytes` (fichier vide, page HTML à la place du fichier ou signature incorrecte refusés).
- Routes **existantes** uniquement (`RhRessource.java`) : `GET /rh/presence`, `/rh/tableau`, `/rh/tableau/excel`
  (`detail=true`), `/rh/tableau/pdf`, `/rh/mobile/code`, `/rh/mobile/terminaux`, `POST
  /rh/mobile/terminaux/{id}/retirer|reactiver`, et `/rh/droits` seulement pour distinguer un 401 des exports
  (Prestige répond 401 aussi bien sans session que sans droit). Aucune modification du serveur.
- QR dessiné dans l'application (paquet `barcode`, déjà présent via `pdf`) : aucun service extérieur.
- Tests : `test/presences_*.dart` sur de vraies réponses du serveur de test (`test/fixtures/presences/`) ;
  `presences_serveur_reel_test.dart` s'exécute contre un vrai serveur s'il répond (sinon sauté) ;
  captures : `CAPTURES_PRESENCES=1 flutter test test/presences_captures_test.dart --update-goldens`.
