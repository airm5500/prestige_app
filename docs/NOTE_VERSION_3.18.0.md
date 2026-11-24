# Prestige Pharmacien 3.18.0+60 — mode démonstration

## Numéro de version

**3.18.0+60** : 3.18.0 parce qu'une fonction nouvelle est ajoutée (mode démonstration), 60 parce que le numéro de build
augmente de 1. Rien n'a encore été publié sur Sunmi (`docs/VERSIONS_SUNMI.md`).

## 1. Pourquoi

L'application va être publiée sur Google Play (`com.dici.prestige_app`) et App Store / TestFlight. Elle se connecte au
serveur Prestige de la pharmacie sur le réseau local (192.168.1.50:8080) : les examinateurs des magasins ne peuvent pas
y accéder. Le mode démonstration permet d'explorer toute l'application sans serveur ni identifiant, avec des données
FICTIVES.

## 2. Entrer et sortir

- Bouton **« Essayer la démonstration »** (libellé exact, cité dans la fiche Google Play) :
  - en tête du **premier écran d'une installation neuve** (Configuration IP), encadré « Pas encore de serveur Prestige ? » :
    **un seul toucher**, sans défiler, même à 320 dp avec le texte ×1,3 ;
  - sous « Se connecter » sur l'écran de connexion (nouvelle interface, celle par défaut) ;
  - sur l'écran « Serveur injoignable » (adresse enregistrée mais serveur hors de portée).
- Bandeau permanent et discret en haut de tous les écrans : **« Démonstration — données fictives »** et l'action
  **« Quitter la démonstration »**. Le bouton de déconnexion de l'accueil quitte aussi la démonstration.
- À la sortie : retour à l'écran de connexion (ou à la configuration pour une installation neuve, ou à « Serveur
  injoignable »), avec l'état réel intact.

## 3. Ce que montre la démonstration

Profil « responsable » (tous les menus) de la « PHARMACIE DE DÉMONSTRATION » : accueil / tableau de bord (chiffres du
jour, évolution du mois, cartes), onglets Analyses, Équipe et Pilotage, et chaque menu : Détail CA, CA Crédit (+ Suivi
crédit), CA Global, Récap de caisse, Rapport d'activité, Fichier journal, Marge, Analyse saisies BL, Tableaux analyses et
ratios, Stat TVA, Analyse Article, Suivi 20/80, Suivi péremption, Valorisation (+ évolution), Ajustements, Achats
fournisseurs (+ contrôle), Retours fournisseurs, Suggestions, Annulation ventes, État de stock, Visualisation BL,
Présences, Alertes, Retraits et abandons, Ventes modifiées, Prévisions, Analyse de garde, CA emplacement / famille,
Balance vente / caisse, Sur-stocks, Péremptions courtes, Pointage BL, Avis, Rappels traitement.

- Données : les jeux de données fictifs des tests, déplacés dans `lib/demo/donnees/` (aucun nom de marque, patient,
  client ou employé réel ; aucune clé ni secret), plus un catalogue de démonstration : « para » → PARACÉTAMOL FICTIF
  500MG / 1000MG / SIROP, « doli » → DOLIFICTIF 500MG / 1000MG / 150MG…
- Dates : les données sont écrites pour une journée de référence (14/10/2026) ; le client de démonstration ramène les
  dates des requêtes à cette journée et décale celles des réponses vers aujourd'hui : le tableau de bord montre
  toujours « aujourd'hui », « hier »… Horloge fixe dans les tests : résultats déterministes.

## 4. Ce qui est refusé (« Indisponible en démonstration »)

Toute écriture vers le serveur est refusée AVANT envoi, avec le message « Indisponible en démonstration » (et l'écran
reste utilisable) : POST (sauf connexion, déconnexion et lecture du ticket Z), PUT, DELETE, actions envoyées en GET
(annulation de vente, mise en attente d'une suggestion, enregistrement de licence, création d'inventaire), et
téléchargements PDF / Excel produits par le serveur. Le code administrateur n'est pas demandé en démonstration (rien
ne peut être enregistré). La licence de l'officine n'est jamais vérifiée avec le serveur fictif.

## 5. Étanchéité avec la vraie session (`lib/demo/mode_demo.dart`)

- Préférences : magasin **en mémoire** pendant la démonstration (seuls les réglages d'affichage sont recopiés) ; le
  magasin réel (adresse du serveur, identifiant mémorisé, nom de l'officine, caches, routes retenues) n'est ni lu ni
  modifié et il est rebranché à la sortie.
- Stockage sécurisé (cookie de session, mot de passe mémorisé, code administrateur) : coffre en mémoire.
- Client HTTP : client en mémoire du serveur de démonstration (aucune socket ; adresse affichée
  `demo.prestige.invalid`, domaine réservé qui ne se résout jamais) ; le client réel est remis à la sortie.
- Caches courts : empreinte de session renouvelée à l'entrée et à la sortie ; alertes et routes retenues oubliées.
- Aucune requête n'est journalisée (ni recherche, ni adresse).
- Application fermée pendant la démonstration : rien n'a été écrit, tout est comme avant au lancement suivant.
- iOS : même code, même comportement (testé sur iPhone SE et iPad).

Seul accès réseau possible, inchangé et indépendant de la démonstration : le téléchargement de la police Lato par
`google_fonts` au premier affichage (aucune donnée envoyée).

## 6. Fichiers

- `lib/demo/mode_demo.dart` (entrée, sortie, écritures refusées), `lib/demo/serveur_demo.dart` (serveur et catalogue de
  démonstration, dates), `lib/demo/serveur_fictif.dart` (cœur du faux serveur, partagé avec les tests),
  `lib/demo/widgets_demo.dart` (bouton, bandeau), `lib/demo/donnees/` (données fictives).
- Branchements : `lib/main.dart` (bandeau, accueil direct en démonstration), `lib/services/api_service.dart` (refus
  des écritures, session fictive), `lib/providers/auth_provider.dart`, `lib/providers/licence_provider.dart`,
  `lib/services/stockage_securise.dart`, `lib/widgets/pin_code_dialog.dart`, écrans de connexion, de configuration et
  « serveur injoignable ».
- Dépendance directe ajoutée (déjà présente, transitive) : `shared_preferences_platform_interface`.

## 7. Étapes pour les examinateurs (Google Play « Accès à l'appli », App Store « Notes pour l'examen »)

1. Installer et ouvrir l'application.
2. Sur le premier écran (« Configuration IP »), toucher **« Essayer la démonstration »** (encadré en haut de l'écran).
   Aucun identifiant n'est nécessaire.
3. L'accueil de la « PHARMACIE DE DÉMONSTRATION » s'affiche avec le bandeau « Démonstration — données fictives » ;
   toutes les rubriques sont accessibles (barre du bas : Accueil, Analyses, Équipe, Pilotage ; « Tous les menus »).
4. Pour quitter : « Quitter la démonstration » dans le bandeau.

(Si une adresse de serveur a déjà été enregistrée, le même bouton est sur l'écran de connexion et sur l'écran
« Serveur injoignable ».)

## 8. Tests

- `test/unitaires/demo_test.dart` : dates, refus des écritures, catalogue fictif, aucune marque ni secret.
- `test/e2e/parcours_demo_test.dart` : installation neuve → 1 toucher → chaque rubrique → aucune requête → sortie
  intacte ; écritures et exports refusés ; téléphone configuré (vraie connexion après la sortie) ; iOS.
- `test/ergonomie/demo_test.dart` : 320 / 360 / 411 dp, Sunmi, tablette × texte 1 / 1,3, serveur injoignable.
- Captures : `test/captures_3_18_0_test.dart` → `docs/maquettes/captures_3_18_0/`.
