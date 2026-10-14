# Prestige Pharmacien 3.0.0 — nouvelle interface (étape 3)

> **Mise à jour 3.0.0+26** : nombre des alertes de l'accueil A compté à la demande (voir « Alertes à surveiller »).

L'application change d'apparence : **même charte que Prestige Vente** (bleu nuit, bouton principal ambre,
en-têtes bleus arrondis, cartes blanches). **Les données, les menus et les calculs ne changent pas** : chaque
écran lit les mêmes informations sur le même serveur Prestige qu'avant.

Captures de l'application (téléphone 1080 × 2400) : `docs/maquettes/captures_refonte/`

| Fichier | Écran |
|---|---|
| `1_connexion.png` | Connexion : état du serveur en tête, bouton « Se connecter » |
| `2_accueil_A_tableau_de_bord.png` | Accueil A : chiffres du jour, alertes comptées (⟳), menus par familles |
| `3_accueil_B_compact.png` | Accueil B : recherche de menu, liste par familles |
| `4_accueil_C_guide.png` | Accueil C : « Que voulez-vous savoir ? » |
| `5_module_analyse_article.png` | Un module (Analyse Article) dans la nouvelle charte |
| `6_reglages_apparence.png` | Réglages : nouvelle / ancienne interface, présentation A, B, C |
| `7_tablette_B_menu_lateral.png` | Tablette : menu latéral et menus sur deux colonnes |

## Ce qui change pour vous

- **Nouvelle interface par défaut**, pour tous les comptes, dès la mise à jour.
- **Accueil** avec, en bas, quatre onglets : **Accueil · Analyses · Équipe · Réglages**.
- Trois **présentations** de l'accueil :
  - **A · Tableau de bord** (par défaut sur téléphone) : en haut, les chiffres du jour — chiffre d'affaires,
    marge, crédits du jour et équipe présente (avec les retards) —, puis les alertes à surveiller (péremptions,
    contrôle des bons de livraison) et tous les menus rangés par familles sur une seule page (plus besoin de
    tourner les pages de 6 tuiles) ;
  - **B · Compact** (automatique sur tablette) : une liste avec **recherche de menu** ; sur tablette, menu bleu à
    gauche et menus sur deux colonnes ;
  - **C · Guidé** : cinq questions simples (« Combien ai-je vendu ? », « Qui me doit de l'argent ? », « Que
    dois-je commander ? », « Mes fournisseurs », « Mon équipe »), puis les menus correspondants.
- **Tous les écrans** (connexion, licence, serveur injoignable, configuration, chaque module, fenêtres,
  calendriers, barres du bas) passent aux couleurs de la nouvelle charte.
- Le bouton principal est **ambre avec un texte foncé**, bien plus lisible que le blanc sur vert d'avant ; les
  zones à toucher font au moins 48 dp.
- Visualisation BL : les deux dates en haut sont plus faciles à toucher (dans les deux interfaces).

## Réglages (onglet « Réglages »)

- **Nouvelle interface** : désactivez pour **revenir à l'ancienne interface**. L'effet est immédiat (vous restez
  connecté) et le choix est **mémorisé** sur le téléphone. Pour revenir à la nouvelle depuis l'ancienne :
  icône **Configuration IP** de l'accueil, puis « Nouvelle interface » en bas de l'écran.
- **Présentation** : Automatique (A sur téléphone, B sur tablette), A, B ou C. Le choix vaut pour **tous les
  comptes** de ce téléphone et **seul l'administrateur** le change : le compte « admin » directement, tout autre
  compte doit saisir le **code administrateur** (le même que pour la configuration du serveur).
- **Serveur** : mode local / distant, configuration du serveur (adresses, port, délai de déconnexion).
- **Personnaliser l'accueil** : ordre des menus et menus masqués (les mêmes dans les deux interfaces).
- **Compte** : utilisateur, officine, jours de licence restants, déconnexion.

## Ce qui ne change pas

- Les mêmes menus (28), les mêmes données, les mêmes contrôles de saisie.
- Un serveur injoignable n'est **jamais** présenté comme un problème de licence ; une session expirée ramène à la
  connexion avec un message ; une panne réseau affiche « Chargement impossible » avec « Réessayer ».
- L'**ancienne interface** est conservée telle quelle et reste disponible à tout moment.

## Bon à savoir

- Les chiffres du jour de l'accueil A viennent des mêmes calculs que le **Rapport d'Activité** (ventes) et que
  **Présences** (équipe). Si le compte n'a pas le droit Ressources humaines, la tuile « Équipe présente » affiche
  « — Indisponible » ; le reste de l'accueil fonctionne.
- Les alertes « À surveiller » ouvrent Suivi Péremption et Etat Contrôle Achat (voir ci-dessous pour leur nombre).

## Alertes à surveiller : nombre à la demande (3.0.0+26)

Pour ne pas surcharger le serveur, le nombre de chaque alerte n'est compté **que lorsque vous le demandez** :

- chaque alerte a son bouton **⟳ Actualiser** (zone de 48 dp, nommé pour le lecteur d'écran). Tant qu'il n'a pas
  été touché : « Touchez ⟳ pour compter » ;
- pendant le comptage, un petit indicateur tourne **sur l'alerte seulement** (le reste de l'accueil reste utilisable ;
  un second appui est ignoré) ;
- ensuite : le nombre et l'heure, ex. **« 3 lots · à 14:32 »**, **« 7 bons · à 14:32 »** ;
- le dernier résultat est **mémorisé** (pour ce serveur et ce compte, même après redémarrage) et réaffiché au retour
  avec son âge : « il y a 12 min », « il y a 2 h (à 14:32) », « le 13/10 à 14:32 » ;
- **aucun appel automatique** : ni à l'ouverture, ni au retour sur l'accueil, ni quand on actualise les chiffres du
  jour (⟳ de l'en-tête ou en tirant la page), ni en boucle ;
- un comptage dure au plus **20 secondes** ; en cas d'échec, l'alerte l'indique sans toucher au reste :
  « Serveur injoignable. Vérifiez le réseau. », « Le serveur met trop de temps à répondre. », « Erreur du serveur
  (code 500). » ; une **session expirée** ramène à la connexion, comme partout. Le dernier nombre obtenu reste
  affiché avec son heure.

D'où viennent les nombres (mêmes routes et mêmes paramètres que les modules, aucune nouvelle route) :

| Alerte | Nombre | Correspond, dans le module, à… |
|---|---|---|
| Produits proches de la péremption | lots périmés ou proches (« 3 lots ») | la liste de Suivi Péremption à son ouverture (aucun filtre) |
| Contrôle des bons de livraison | bons contrôlés aujourd'hui, tous groupes (« 7 bons ») | « Total Bons » d'Etat Contrôle Achat après « Rechercher » avec ses filtres par défaut (jour, tous les groupes) |

La route du contrôle des bons renvoie toute la liste pour en tirer un nombre : une route de comptage légère est
demandée au serveur (`docs/serveur/ROUTES_DE_COMPTAGE.md`).
