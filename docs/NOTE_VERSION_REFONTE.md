# Prestige Pharmacien 3.0.0 — nouvelle interface (étape 3)

L'application change d'apparence : **même charte que Prestige Vente** (bleu nuit, bouton principal ambre,
en-têtes bleus arrondis, cartes blanches). **Les données, les menus et les calculs ne changent pas** : chaque
écran lit les mêmes informations sur le même serveur Prestige qu'avant.

Captures de l'application (téléphone 1080 × 2400) : `docs/maquettes/captures_refonte/`

| Fichier | Écran |
|---|---|
| `1_connexion.png` | Connexion : état du serveur en tête, bouton « Se connecter » |
| `2_accueil_A_tableau_de_bord.png` | Accueil A : chiffres du jour, alertes, menus par familles |
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
- Les alertes « À surveiller » ouvrent Suivi Péremption et Etat Contrôle Achat ; elles n'affichent pas encore de
  nombre (prévu dans une prochaine version).
