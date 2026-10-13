# Prestige Pharmacien — version 2.4.0 (étape 1 : robustesse et sécurité)

Cette version ne change **pas l'apparence** de l'application : mêmes écrans, mêmes menus, même accueil,
mêmes réglages (rien à ressaisir). Elle rend l'application plus sûre et plus claire quand quelque chose
ne va pas.

## Ce qui change pour vous

### 1. Votre mot de passe n'est plus enregistré en clair
- Avec « Rester connecté », le mot de passe est désormais rangé dans le **coffre sécurisé du téléphone**
  (chiffré), comme dans l'application de vente. Le cookie de session aussi.
- Rien à faire : au premier lancement, l'ancien mot de passe mémorisé est déplacé automatiquement dans
  le coffre puis effacé de l'ancien emplacement. L'identifiant et le mot de passe restent pré-remplis.
- Ces informations ne partent plus dans les sauvegardes du téléphone (Google) ni lors d'un transfert
  vers un nouveau téléphone : sur un nouveau téléphone, il faudra saisir le mot de passe une fois.
- Le mot de passe est envoyé **exactement comme vous le tapez** (un espace en fin n'est plus retiré).

### 2. La configuration du serveur est protégée par un code
- Depuis l'écran de **connexion** (roue dentée) ou l'écran de **licence**, la « Configuration IP » demande
  le **code administrateur**.
- **Première fois : le code est 1234.** L'application vous demande alors d'en choisir un nouveau
  (4 à 8 chiffres, pas trop simple : pas 1111, 1234, 1212…). Notez-le.
- Une fois connecté, vous avez tous les droits : depuis l'accueil, la configuration s'ouvre **sans code**.
  Le bouton « Changer le code administrateur » est en bas de la configuration.
- Après 5 codes faux, il faut attendre (30 s, puis plus longtemps).

### 3. Une panne n'est plus confondue avec « aucun résultat »
- Avant, si le serveur ne répondait pas, certains écrans affichaient « Aucun Bon de Livraison trouvé »,
  « Aucun résultat trouvé »… comme s'il n'y avait rien.
- Maintenant, une panne affiche **« Chargement impossible »** avec la raison (serveur injoignable,
  serveur trop lent, erreur du serveur, accès refusé) et un bouton **« Réessayer »**. « Aucun … » ne
  s'affiche que si le serveur a vraiment répondu qu'il n'y a rien.
- Si votre session a expiré, l'application revient à l'écran de connexion avec un message.

### 4. Au démarrage : serveur injoignable ≠ problème de licence
- Avant, un Wi-Fi coupé ou un serveur éteint faisait apparaître « Licence requise ».
- Maintenant : **« Le serveur ne répond pas »** (avec l'adresse utilisée et « La licence n'est pas en
  cause »), un bouton **Réessayer**, un **nouvel essai automatique toutes les 10 secondes**, un bouton pour
  essayer l'autre serveur (local / distant) et la configuration (avec le code).
- L'écran de licence n'apparaît que si le serveur a répondu qu'il n'y a **pas de licence**, ou qu'elle
  est **expirée** (la date d'expiration est indiquée), avec un bouton « Vérifier à nouveau ».

### 5. Annulation d'une vente : plus de double annulation
- La confirmation rappelle le numéro, la date et le montant, et précise que l'annulation est définitive.
- Pendant l'envoi, les boutons « Annuler » sont bloqués : un double appui n'envoie rien de plus.
- Si le réseau coupe pendant l'annulation, l'application **ne renvoie pas** la demande : elle vérifie
  l'état réel de la vente et vous dit si elle est annulée ou non.

### 6. Saisies contrôlées
- Les champs de recherche, quantités, montants, mois, port, etc. refusent les valeurs impossibles
  (trop longues, lettres dans un nombre, port hors limites…) avec un message.

### 7. Serveur distant en HTTPS (si votre serveur le permet)
- L'adresse distante peut être saisie avec `https://` (ex. `https://pharmacie.example.com`). Sans
  rien préciser, l'application continue en HTTP comme avant (réseau de l'officine).

## Comment tester (10 minutes)

1. **Mise à jour** : installer la version 2.4.0 par-dessus l'ancienne. Ouvrir : l'identifiant et le
   mot de passe sont toujours pré-remplis (si « Rester connecté » était coché). Se connecter.
2. **Lectures** : ouvrir Détail CA, État de stock (rechercher un produit), Visualisation BL : les données
   s'affichent comme avant.
3. **Panne** : couper le Wi-Fi (et les données), ouvrir Visualisation BL → « Chargement impossible » +
   « Serveur injoignable » (et non « Aucun Bon de Livraison trouvé »). Remettre le Wi-Fi, toucher
   « Réessayer » → la liste revient.
4. **Démarrage sans serveur** : couper le Wi-Fi, fermer et rouvrir l'application → « Le serveur ne répond
   pas », décompte de 10 s. Remettre le Wi-Fi : l'application continue toute seule vers la connexion.
5. **Code administrateur** : se déconnecter, toucher la roue dentée de l'écran de connexion → code
   demandé. Taper 1234 → choisir un nouveau code → la configuration s'ouvre. Refaire avec le nouveau code.
6. **Annulation** (sur une vente de test) : toucher « Annuler », confirmer, toucher plusieurs fois
   rapidement : une seule annulation, message « Vente annulée avec succès ».

## Si besoin de revenir en arrière
Réinstaller la version précédente reste possible (même identifiant d'application). Les réglages sont
conservés ; seul le mot de passe mémorisé devra être ressaisi une fois.

## Pour l'équipe technique
- Détails : `docs/BALISES.md` (commits et retour arrière), `docs/HTTPS_ET_TRAFIC_EN_CLAIR.md`,
  `docs/SIGNATURE_ET_IDENTIFIANT_ANDROID.md` (l'APK de la CI est signé avec une autre clé debug : pour
  mettre à jour les téléphones existants, construire sur l'ordinateur habituel — voir ce document).
- Tests automatiques : `flutter test` (un fichier par thème), lancés par la CI à chaque envoi.
