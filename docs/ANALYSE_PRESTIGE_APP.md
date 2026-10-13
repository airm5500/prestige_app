# Prestige Pharmacien (`prestige_app`) : analyse, module Présences et refonte

> Analyse **en lecture seule** du dépôt `airm5500/prestige_app` (branche `master`, dernier commit `65a31b4 « version 2.3 »` du 13/07/2026).
> Rien n'a été modifié dans ce dépôt. Côté serveur, seules les routes **déjà existantes** de Prestige (branche `claude/new-session-xm8ptu`) sont utilisées.
> Maquettes : `prestige_app_maquettes.html` · Aperçus : `apercus/1_connexion.png` … `apercus/6_presences_tablette_qr.png`.

---

## 1. Ce que fait l'application aujourd'hui

### 1.1 En bref
L'application du pharmacien sert à **consulter** l'activité de l'officine depuis un téléphone : chiffre d'affaires, caisse, crédits, stock, achats fournisseurs, analyses et ratios. Elle ne vend pas (c'est le rôle de `prestige_vente_app`). Les seules actions qui modifient des données sont : l'annulation d'une vente, les suggestions de commande (quantités, suppression) et l'enregistrement de la licence.

### 1.2 Fiche technique

| Élément | Constat |
|---|---|
| Flutter / Dart | `pubspec.yaml` : SDK `>=3.0.0 <4.0.0` ; `pubspec.lock` exige **Dart ≥ 3.8 et Flutter ≥ 3.29** (`.metadata` : canal stable, révision `b25305a8`). |
| Versions affichées | 3 numéros différents : `pubspec.yaml:6` = **1.5.0**, `android/app/build.gradle:29` = **2.3.0** (forcé), titre de l'accueil `home_screen.dart:135` = « Prestige Mobile - **v3** ». |
| Gestion d'état | `provider` : `IpConfigProvider`, `AuthProvider`, `HomeSettingsProvider`, `LicenceProvider`, `ApiService` (singleton) — `main.dart:24-31`. Les écrans utilisent un mixin commun `BaseScreenLogic` (`ui_helpers/base_screen_logic.dart`, 28 écrans sur 41). |
| Client HTTP | paquet `http`, singleton `services/api_service.dart` ; délais 20 s (POST) / 45 s (GET) ; base `http://<ip>:<port>/<app>/api/v1` (+ `api/v3` pour la TVA). **HTTP en clair uniquement** (aucune option HTTPS). |
| Authentification | **Session à cookie** : `POST /user/auth {login, password}` ; le cookie `Set-Cookie` (JSESSIONID) est conservé et renvoyé (`api_service.dart:87-93`, `51-59`). Pas de jeton. Session expirée détectée par HTTP 401 ou message « Veuillez vous connecter » (`api_service.dart:168-187`). |
| Démarrage | Configuration IP → vérification licence (`GET /licence/find`) → connexion → accueil (`main.dart:224-276`). Déconnexion automatique après N minutes en arrière-plan (défaut 30, `auth_provider.dart:55-78`). |
| Thème actuel | Material 3, police Lato (google_fonts), bleu pétrole `#0A2E3E` / `#164B62`, vert `#2EBF91` pour les boutons, fond `#F5F7FA` (`main.dart:42-46`). **Différent** de la charte refondue de `prestige_vente_app` (bleu `#003366` + ambre `#F59E0B`). |
| Accueil | 27 menus en grille 2 colonnes, **pages de 6 tuiles** à faire défiler (`home_screen.dart:72-102`, `125`, `245`) ; ordre et masquage personnalisables (`personalize_home_screen.dart`). |
| Exports | PDF/impression (`printing`) dans Suivi péremption et Évolution stock ; CSV dans Suggestions et Retours fournisseurs (`csv`, `share_plus`). |
| Tests | 1 seul test (`test/widget_test.dart`) — **il ne peut pas passer** : il ne fournit que `IpConfigProvider` alors que l'application lit `AuthProvider` dès le démarrage (`main.dart:147`). Nom resté « Counter increments smoke test ». |
| CI | **Aucune** (pas de dossier `.github/`). README d'origine Flutter (« A new Flutter project »). |
| Android | `applicationId = "com.example.prestige_app"` (`build.gradle:24`), version **release signée avec la clé de debug** (`build.gradle:42`), trafic en clair autorisé partout (`network_security_config.xml:3`). |

### 1.3 Écrans et menus (27 menus + écrans techniques)

| Famille (proposée) | Menu actuel | Ce qu'il montre | Route serveur (`/api/v1`) |
|---|---|---|---|
| Ventes & caisse | Détail CA | CA comptant/crédit par mode de paiement, camembert | `GET /ca-all?dtStart&dtEnd` |
| | CA Crédit | CA à crédit par tiers payant | `GET /ca-credit` |
| | CA Global | CA global sur période | `GET /ca-all` |
| | Récap de caisse (ticket Z) | Récapitulatif par caissier et horaire | `GET /common/users`, `POST /caisse/fetch-tickez` |
| | Rapport d'activité | CA, marge, TVA, achats, règlements, crédits | `GET /recap/dashboard`, `/recap/credits`, `/recap/credits/totaux`, `/recap/reglements` |
| | Annulation ventes | Recherche d'une vente puis annulation | `GET /ventestats`, `/ventestats/find-one/{id}`, **`GET /vente/annulation/{id}`** (modifie !) |
| | Stat TVA | TVA par taux | `GET /api/v3/tvas` |
| | Marge produits vendus | Marge par produit | `GET /datareporting/margeproduitsvendus` |
| Crédits | Suivi crédit | Restes à payer par client / tiers | `GET /recap/credits` |
| Analyses | Tableau : Analyses | Choix de période puis Évolution achats / ventes / comparative (fl_chart) | `GET /ws/ca-achats-ventes` |
| | Tableau : Ratios | Ratio vente/achat (norme 1,51), ratios mensuels | `GET /ws/ca-achats-ventes` |
| | Analyse Article | Ventes et stock d'un article (graphique) | `GET /info` |
| | Suivi 20/80 | Articles qui font 80 % du CA | `GET /statfamillearticle/vingtQuatreVingt` |
| Stock | Fiche Article | Recherche d'un produit | `GET /checkproduit` |
| | État de Stock | Stock par rayon / grossiste / seuil | `GET /common/rayons`, `/common/grossiste`, `/fichearticle/comparaison` |
| | Suivi Péremption | Produits périmés ou proches + PDF | `GET /fichearticle/perimes` |
| | Évolution Stock | Valorisation dans le temps + PDF | `GET /valorisation/all` |
| | Valorisation | Valeur du stock | `GET /valorisation` |
| | Suivi Ajustements | Ajustements et détail | `GET /common/type-ajustements`, `/ajustement`, `/ajustement/items` |
| Fournisseurs | Fournisseurs | Liste | `GET /fournisseurs` |
| | Achats Fourn. | Achats par fournisseur | `GET /achats-fournisseurs` |
| | Retours Fournisseurs | Retours + détail + avoirs, CSV | `GET /grossiste/all`, `/produit/retours-data`, `/retourfournisseur/retours-items`, `/avoirs-fournisseurs` |
| | Suggestions | Suggestions de commande, quantités, CSV | `GET /suggestion/list`, `/suggestion/set-pending/{id}`, `/suggestion/list/items`, `/suggestion/amount/{id}` ; `POST /suggestion/item/update-qte-cmde` ; `DELETE /suggestion/item/{id}`, `/suggestion/suggestion/{id}` |
| | État Contrôle Achat | Contrôle annuel des BL | `GET /groupegrossiste`, `/etat-control-bon/list-annuelle` |
| | Analyse Saisies BL | Saisies BL par opérateur | `GET /etat-control-bon/list` |
| | Visualisation BL | Liste BL filtrable (grossiste, groupe, opérateur, statut) | `GET /common/grossiste`, `/groupegrossiste`, `/common/users`, `/etat-control-bon/list` |
| Équipe (partiel) | Fichier Journal | Journal des actions par utilisateur | `GET /common/log-filtres`, `/common/users`, `/common/logs` |
| Technique | Connexion, Configuration IP, Licence, Personnaliser l'accueil, Splash | — | `POST /user/auth`, `POST /user/logout`, `GET /officine`, `GET /licence/find`, `GET /licence/save/{clé}`, `HEAD /<app>` (test) |

---

## 2. Problèmes constatés (avec preuves)

### 2.1 Sécurité
| # | Problème | Preuve | Risque |
|---|---|---|---|
| S1 | **Mot de passe enregistré en clair** dans les préférences du téléphone quand « Rester connecté » est coché, puis re-rempli automatiquement. | `auth_provider.dart:176`, `login_screen.dart:83`, `constants.dart:14` | Un téléphone perdu ou sauvegardé (backup Android) donne le mot de passe de l'administrateur. |
| S2 | **Cookie de session en clair** dans les préférences. | `api_service.dart:58` | Vol de session tant qu'elle est valide côté serveur. |
| S3 | **HTTP en clair** obligatoire (y compris en mode « Distant » sur Internet) ; trafic clair autorisé pour tous les domaines. | `api_service.dart:36,127`, `ip_config_provider.dart:288-294`, `network_security_config.xml:3` | Identifiants et chiffres de l'officine lisibles sur le réseau (Wi-Fi public, 4G). |
| S4 | **Journaux trop bavards** : toutes les URL, la réponse brute du serveur en cas d'erreur, la liste des rayons. | `api_service.dart:82,110,134,150,194,215` | Données dans `logcat` (visibles par un câble USB / outils). |
| S5 | **Configuration du serveur accessible sans code** depuis l'écran de connexion. | `login_screen.dart:207`, `home_screen.dart:153` | Quelqu'un peut rediriger l'application vers un faux serveur et récupérer le mot de passe. |
| S6 | Release signée avec la clé debug, identifiant `com.example`. | `build.gradle:24,42` | Mise à jour impossible proprement sur le Play Store ; application facilement imitable. |
| S7 | Le menu est le même pour tous les comptes : aucun droit n'est lu côté application (le serveur bloque, mais l'utilisateur voit des écrans vides ou des erreurs). | `user_model.dart` (aucun privilège), `home_screen.dart:72-102` | Confusion ; « Annulation ventes » visible par tous. |

### 2.2 Robustesse : les pannes ressemblent à des listes vides
| # | Problème | Preuve |
|---|---|---|
| R1 | Les erreurs réseau sont **avalées** et transformées en liste vide / `null` dans `ApiService`. | `api_service.dart:234-238` (rayons), `266-269` (grossistes), `368-371` (péremption), `462-465` (BL), `476-478` (groupes), `495-497` (utilisateurs) |
| R2 | L'écran affiche alors « Aucun Bon de Livraison trouvé », « Aucun résultat trouvé », « Aucun produit périmé… » alors que le serveur n'a pas répondu. | `visualisation_bl_screen.dart:155-157` + `427` ; `etat_stock_screen.dart:402` ; `suivi_peremption_screen.dart:91-93` + `336` |
| R3 | **Serveur injoignable ⇒ « licence introuvable »** : toute erreur de `/licence/find` met le statut `notFound` et bloque l'application sur l'écran d'enregistrement de licence. | `api_service.dart:388-392`, `licence_provider.dart:32-38`, `main.dart:254-257` |
| R4 | Les exceptions sont ré-emballées : « Session invalide » devient « Une erreur inconnue est survenue: Exception: Session invalide… » ; le dépassement de délai (TimeoutException) n'est traité que pour DELETE. | `api_service.dart:96-99`, `115-118`, `139-142` (comparer `161-162`) |
| R5 | La session n'est jamais restaurée au redémarrage (cookie conservé mais `_isLoggedIn` reste faux) : il faut toujours se reconnecter, d'où l'usage de « mot de passe mémorisé ». | `auth_provider.dart:42-53`, `153-159` |
| R6 | Une action qui modifie (annulation de vente) passe par un **GET** sans motif ; un rechargement ou un double appui peut la rejouer. | `annulation_vente_screen.dart:106` |
| R7 | Les polices Lato sont téléchargées à l'exécution (google_fonts) : premier lancement hors ligne ⇒ police de secours. | `main.dart:48`, `pubspec.yaml` (`google_fonts`) |

### 2.3 Contrôles de saisie
- Configuration : l'IP n'est contrôlée que « non vide » (pas de format), l'IP distante pas du tout (`settings_screen.dart:225-230`).
- Le mot de passe est **rogné** (`trim()`) avant envoi : un mot de passe qui commence/finit par un espace ne marche pas (`login_screen.dart:106`).
- Validation `value!.isEmpty` (pas de `trim`) pour l'identifiant.

### 2.4 Ergonomie et présentation
- 27 menus en pages de 6 tuiles : il faut se souvenir de la page (`home_screen.dart:125`). Pas de recherche, pas de familles.
- Carte « Bienvenue » et bandeau licence affiché dès 365 jours restants (`home_screen.dart:181`) : place perdue, aucun chiffre du jour.
- Message de déconnexion familier avec émoji (« …sans venir me consulter 😢 », `auth_provider.dart:73`).
- Couleurs codées en dur écran par écran (`Colors.green`, `Color(0xff68737d)`…), aucune palette commune.
- **Tablette** : aucune adaptation (`crossAxisCount: 2` fixe, aucun `LayoutBuilder`/`MediaQuery` dans `lib/`).
- Charte différente de `prestige_vente_app` : deux applications du même éditeur qui ne se ressemblent pas.

---

## 3. Pointage et RH : ce qui existe, ce qui est proposé

### 3.1 Aujourd'hui
- **Dans `prestige_app` : rien** sur le personnel (aucun écran, aucune route `/rh/…`). Le seul écran « équipe » est le Fichier Journal (actions des utilisateurs).
- **Côté serveur Prestige : tout existe déjà** (`src/main/java/rest/RhRessource.java`, `@Path("v1/rh")`) : employés, planning, équipes, absences, import pointeuse, présence du jour, tableau, exports Excel/PDF, QR code de pointage, téléphones enregistrés. Accès réservé au droit **`P_SM_RH`**, via **la même session cookie** que `/user/auth` (`RhRessource.java:47-63`) : `prestige_app` peut donc les appeler sans nouvelle connexion.
- **Capture** : déjà faite dans `prestige_vente_app` (menu « Pointage présence » : boutons Arrivée/Départ + scan du QR, routes `/api/v1/mobile/…` à jeton, voir `docs/NOTE_VERSION_POINTAGE_PRESENCE.md`), ainsi que par la pointeuse (import) et la saisie manuelle dans Prestige.

**Partage des rôles proposé** : les téléphones/terminaux **capturent** (vente_app) ; Prestige (poste) et `prestige_app` **traitent et analysent**. `prestige_app` reste en **lecture** (pas de correction de pointage depuis le téléphone), sauf la gestion des téléphones (retirer/réactiver), à valider (question 6).

### 3.2 Routes serveur utilisées (existantes, aucune modification serveur)

| Besoin | Route | Réponse utile |
|---|---|---|
| Savoir si le compte a le droit RH (afficher/masquer le module) | `GET /rh/droits` | `success:true` si `P_SM_RH` ; sinon `success:false, msg:"Vous n'avez pas accès aux ressources humaines."` |
| Présence du jour | `GET /rh/presence?jour=AAAA-MM-JJ` | `data[]` (une ligne par employé : `employe, matricule, prevu, entree, sortie, minutesPrevues, minutesPresence, retard, departAnticipe, heuresSup, absence, anomalies, pointages`) + `pointages[]` bruts (`horodatage, sens, source, motif`) |
| Tableau sur une période | `GET /rh/tableau?du=&au=&employeId=` | `data[]` par employé : `joursPrevus, joursPresents, joursAbsenceJustifiee, absencesNonJustifiees, retards, minutesRetard, departsAnticipes, minutesPrevues, minutesPresence, heuresSup, anomalies` ; période bornée à 366 jours, défaut = début du mois |
| Exports | `GET /rh/tableau/excel?du=&au=&employeId=&detail=true|false`, `GET /rh/tableau/pdf?du=&au=&employeId=` | fichiers .xlsx / .pdf |
| Liste des employés (filtre) | `GET /rh/employes?query=&inactifs=false` | |
| Absences / congés (affichage) | `GET /rh/absences?du=&au=&employeId=&statut=` | |
| QR code du moment (écran de pointage) | `GET /rh/mobile/code` | `contenu` (texte du QR), `code`, `resteSec`, `periodeSec` (60), `actif`, `qr`, `gps`, `rayon` |
| Téléphones enregistrés | `GET /rh/mobile/terminaux` ; `POST /rh/mobile/terminaux/{id}/retirer|reactiver` ; `POST /rh/mobile/deconnecter-tous` | |
| Édition PDF d'un onglet | `GET /rh/edition/presence/pdf?jour=` (et autres onglets) | |

Anomalies renvoyées par le serveur (`AnalysePresence.java`) et leur libellé proposé : `ABSENT` « Absent », `DOUBLON` « Pointage en double », `DEUX_ENTREES` « Deux entrées », `SORTIE_SANS_ENTREE` « Départ sans arrivée », `ENTREE_SANS_SORTIE` « Arrivée sans départ », `POINTAGE_EN_CONGE` « Pointé pendant un congé », `HORS_PLANNING` « Hors planning », `JOURNEE_LONGUE` « Journée anormalement longue ».

### 3.3 Écrans du module « Présences » (aperçus `5_presences_telephone.png`, `6_presences_tablette_qr.png`)
1. **Présence du jour** : compteurs (présents / prévus, retards et minutes cumulées), barre À l'heure / En retard / Absent / Congé, liste triée (absents et retards d'abord) avec source du pointage (téléphone, pointeuse, saisie). Sélecteur de jour, actualisation par glissement (pas d'actualisation automatique pour ménager le serveur ; à valider).
2. **Tableau sur une période** : puces Semaine / Mois / Mois dernier / Personnalisé, filtre employé ; colonnes jours présents/prévus, retards (nombre et durée), heures, heures sup., anomalies ; boutons **Excel**, **Excel détaillé**, **PDF** (téléchargés puis partagés via `share_plus`/`open_file`, déjà dans le projet).
3. **Fiche employé** : totaux de la période, anomalies à vérifier en tête, puis les jours (données de l'export détaillé ou de `/rh/presence` jour par jour — à arbitrer, question 4).
4. **Pointage & téléphones** (tablette ou téléphone, droit RH) : QR code du moment rafraîchi selon `resteSec` (mode plein écran pour une tablette posée au comptoir), réglages lus (QR/GPS/rayon), liste des téléphones avec Retirer / Réactiver (avec confirmation) et « Déconnecter tous ».
5. **Accueil** : tuile « Équipe présente 9/11 · 2 retards » si droit RH.

À ajouter dans `ApiService` : une méthode de **téléchargement binaire** (`getBytes`) pour Excel/PDF (aujourd'hui tout est décodé en JSON, `api_service.dart:168-197`) et la reconnaissance du refus `success:false` de `/rh/*` comme « droit manquant » (distinct de « session expirée »).

---

## 4. Refonte du design : trois propositions (même charte que `prestige_vente_app`)

Charte commune : bleu Prestige **`#003366`**, ambre **`#F59E0B`** pour l'action principale, fond `#F2F4F8`, cartes blanches arrondies (14 px), texte `#14213D`, gris `#5B6B82`, statuts vert / ambre / rouge toujours accompagnés d'un libellé. Barre du bas : Accueil · Analyses · Équipe · Réglages. Menus rangés par familles sur une seule page (comme validé pour vente_app).

| | **A — Tableau de bord** | **B — Compact** | **C — Guidé** |
|---|---|---|---|
| Idée | Les chiffres du jour en tête (CA, marge, crédits, équipe), alertes cliquables (péremptions, BL non contrôlés), familles de menus en tuiles | Barre blanche, recherche de menu, listes et **tableaux denses** triables | « Que voulez-vous savoir ? » : 5 questions métier, réponses en phrases, détail ensuite |
| Connexion | En-tête bleu + état du serveur, bouton ambre | Formulaire seul, erreurs sous le champ | Assistant « serveur injoignable » (réessai, bascule local/distant) |
| Listes | Cartes avec bande de couleur (ancienneté, gravité), total en tête et en pied | Tableau (colonnes complètes sur tablette) | Mêmes cartes, filtres posés en questions |
| Analyses | Chiffre clé + comparaison, graphique à une seule échelle, répartition libellée | Tableau groupable (jour / mode / vendeur) | « Vous avez vendu 14,86 millions F, +6,4 % » |
| Présences | Présence du jour (retards d'abord) | Tableau période + exports | Fiche employé et anomalies en phrases |
| Pour qui | **Le pharmacien titulaire** | Gérant, comptable, tablette au bureau | Adjoint, remplaçant occasionnel |

Les états d'erreur sont communs aux trois : panne réseau (avec Réessayer et « mode Local »), session expirée, droit manquant, et « aucune donnée » — chacun son message (aperçu `3_liste_suivi_credit.png`, téléphone de droite).

**Recommandation : A par défaut**, B proposée comme présentation des listes et automatiquement sur tablette (menu latéral, deux colonnes), C en option pour les comptes non administrateurs. Comme dans vente_app, le choix A/B/C est un réglage d'apparence mémorisé, que seul l'administrateur peut changer pour les autres comptes.

---

## 5. Plan par étapes, sans régression

### 5.1 Filet de sécurité
- **Interrupteur « Nouvelle interface »** (copie du `InterfaceVersion` de vente_app : `ValueNotifier` + clé `interface_nouvelle_version_v1` dans les préférences, vrai par défaut une fois validé). Éteint : accueil, connexion et réglages d'origine, **intacts**. Réglage visible dans l'ancienne et la nouvelle configuration.
- **Écrans métier conservés** : les 27 écrans actuels restent et sont ouverts depuis le nouvel accueil ; ils ne sont restylés qu'ensuite, un par un, derrière le même interrupteur (ou par thème : l'ancien thème est gardé dans `theme_legacy.dart`).
- **Mêmes clés de stockage** (`local_ip`, `port_key`, ordre et menus masqués de l'accueil…) : aucun réglage perdu ; l'ordre personnalisé est repris dans les familles.
- **Balises git** avant chaque étape (`avant-etape-1`, …) et note de version par étape (comme `docs/BALISES_INTERFACE.md` dans vente_app).
- **Tests** : réparer le test existant (fournir tous les providers), puis tests unitaires `ApiService` (erreur réseau ≠ liste vide, 401, refus RH), tests de widgets par écran nouveau (états chargement / erreur / vide / données, largeur téléphone 360 px et tablette 1024 px), et un **CI GitHub Actions** `flutter analyze` + `flutter test` + build APK.

### 5.2 Étapes et estimation

| Étape | Contenu | Risque | Estimation |
|---|---|---|---|
| 0 | Socle : CI, test réparé, versions alignées (une seule source : `pubspec.yaml`), interrupteur de version, palette `Pal` partagée | Nul (aucun écran changé) | 1 j |
| 1 | **Robustesse & sécurité** sans changer l'apparence : erreurs réseau affichées (plus de listes vides trompeuses), licence ≠ panne réseau, timeouts, journaux réduits (`kDebugMode`), mot de passe plus stocké (identifiant seulement), cookie et éventuel secret dans `flutter_secure_storage`, configuration protégée par code, contrôle du format IP/port | Faible ; corrige des comportements | 2-3 j |
| 2 | **Module Présences** (4 écrans + tuile accueil + téléchargements Excel/PDF), visible seulement si `/rh/droits` répond oui | Nul pour l'existant (ajout) | 3-4 j |
| 3 | **Nouvelle connexion + nouvel accueil** (A/B/C, familles, chiffres du jour via `/recap/dashboard`, alertes), derrière l'interrupteur | Faible (ancien accueil intact) | 3-4 j |
| 4 | Restyle des listes (Suivi crédit, péremption, BL, stock…) et des analyses, écran par écran ; tablette (menu latéral) | Moyen → un écran à la fois, interrupteur | 5-8 j |
| 5 | Préparation publication : `applicationId` définitif, clé de signature release, HTTPS en mode distant (si le serveur l'offre, question 8) | Moyen (dépend de l'hébergement) | 1-2 j |

Total indicatif : **15 à 22 jours**, livrable étape par étape ; chaque étape est utilisable seule et réversible (interrupteur ou balise).

---

## 6. Questions à valider

1. Le module **Présences** dans `prestige_app` : uniquement pour les comptes ayant le droit `P_SM_RH` (masqué sinon) — d'accord ?
2. Écrans prioritaires : Présence du jour + Tableau période + exports d'abord, Fiche employé et Pointage & téléphones ensuite — d'accord ?
3. Le pharmacien doit-il pouvoir **corriger** un pointage depuis le téléphone ? (Proposé : non, lecture seule ; corrections dans Prestige, menu RH. Des routes `POST /rh/pointages` existent si besoin.)
4. Fiche employé : se contenter des totaux + anomalies (léger), ou afficher le détail jour par jour (plus d'appels serveur) ?
5. Une **tablette au comptoir** affichant le QR code du moment en plein écran depuis `prestige_app` — souhaité ? (Sinon le QR reste affiché sur le poste Prestige.)
6. **Retirer / réactiver** un téléphone et « Déconnecter tous » depuis `prestige_app` : autorisé, ou réservé au poste Prestige ?
7. Seuils d'alerte : retard compté à partir de combien de minutes ? Faut-il une notification (ex. « 2 absents à 9 h ») ou seulement l'affichage ?
8. Le mode **Distant** passe-t-il par Internet ? Si oui, peut-on mettre le serveur en **HTTPS** (certificat) ? C'est la correction la plus importante côté sécurité.
9. « Rester connecté » : accepter de ne plus mémoriser le mot de passe (identifiant seulement, et éventuellement déverrouillage par empreinte) ?
10. Présentation : **A par défaut** pour le pharmacien, B sur tablette, C en option — d'accord ? Le choix est-il réservé à l'administrateur comme dans vente_app ?
11. Chiffres du jour sur l'accueil (CA, marge, crédits, équipe) : lesquels garder ? Période par défaut « Aujourd'hui » ?
12. Ordre de réalisation : Robustesse/sécurité (étape 1) → Présences (2) → Accueil (3) → restyle (4) — d'accord, ou Présences en premier ?
13. Nom de l'application : « Prestige Pharmacien » (à la place de « Prestige Mobile - v3 ») et un seul numéro de version — d'accord ?
