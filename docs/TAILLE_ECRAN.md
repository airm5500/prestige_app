# Taille de l'écran — `lib/ui/taille_ecran.dart`

*Prestige Pharmacien 3.7.0. Module repris **tel quel** de Prestige Inventaire 4.13.1 et de Prestige Mobile 4.0.1
(même fichier, même logique, mêmes facteurs, même seuil, même clé enregistrée `taille_ecran_v1`) : un seul fichier
Dart, sans autre dépendance que `flutter` et `shared_preferences`. Seul l'en-tête change. Toute évolution doit être
reportée dans les trois applications.*

## 1. Le besoin

Sur les petits terminaux (Sunmi V2s 5,45″ : 720 × 1440 px, densité 2 → **360 × 720 dp** ; Sunmi V3 / V3H / V3mix :
1080 × 1920 px, densité 3 → **360 × 640 dp**), les écrans conçus pour un téléphone de 400 dp manquent de place
(tableaux, graphiques, feuilles des filtres…). Un **réglage unique** réduit toute l'interface, sans retoucher aucun
écran :

| Taille | Facteur | Surface vue par l'application sur un V2s | Effet |
|---|---|---|---|
| **Automatique** (défaut) | 1,0, ou 0,9 sur un petit écran | 400 × 800 dp (Compact appliqué) | taille définie par Android ; **Compact sur un petit écran** |
| **Compact** | 0,9 | 400 × 800 dp | tout est 10 % plus petit |
| **Très compact** | 0,8 | 450 × 900 dp | tout est 20 % plus petit |

### Automatique sur les petits écrans

`TailleEcranReglage.petitEcran(taille)` : écran **petit** si son **côté long < 740 dp** ou son **côté court
< 340 dp**, mesuré sur l'écran réel (avant réduction), quelle que soit l'orientation.
`TailleEcranReglage.effective(choix, taille)` : Automatique → Compact sur un petit écran ; **Compact et Très compact
(choix manuels) restent prioritaires**.

| Appareil | Taille logique | Résultat en Automatique |
|---|---|---|
| Sunmi V2s 720 × 1440, ×2 | 360 × 720 dp | Compact (400 dp vus) |
| Sunmi V3 / V3H / V3mix 1080 × 1920, ×3 ; téléphone 720 × 1280, ×2 | 360 × 640 dp | Compact |
| Sunmi 1080 × 1920, ×2,625 | 411 × 731 dp | Compact |
| Téléphone 1080 × 2400, ×2,625 / ×2,75 | 411 × 914 / 393 × 873 dp | **normale** (rien ne change) |
| Téléphone 1080 × 2400, ×3 (Samsung) | 360 × 800 dp | **normale** |
| Tablettes | 1280 × 800 dp… | **normale** |

Les réglages affichent alors « **Automatique (Compact appliqué sur cet écran)** ».

### Principe

`EchelleInterface` se place **au-dessus de la seule `MaterialApp`** : il publie une `MediaQuery` dont la taille, les
marges système, le clavier et la densité sont ramenés à l'échelle, puis réduit le rendu du facteur (`FittedBox`).
Fenêtres, feuilles du bas, menus, calendriers et messages sont donc réduits avec l'interface ; les touchers suivent la
même transformation ; le texte reste net (rendu vectoriel).

## 2. Dans Prestige Pharmacien

- **Branchement** (`lib/main.dart`) : `await TailleEcranReglage.charger()` avant `runApp` ; `RacineTailleEcran`
  enveloppe la **seule** `MaterialApp` (et le choix nouvelle / ancienne interface), **sous** le `MultiProvider`
  (`AuthProvider` et son cookie de session, `IpConfigProvider`, `LicenceProvider`, `HomeSettingsProvider`,
  `ApiService`) : « Relancer maintenant » reconstruit l'interface **sans perdre la session**.
- **Réglage** (`lib/widgets/taille_ecran_reglage.dart`, `TailleEcranSetting`), dans les **deux interfaces** :
  - nouvelle : **Réglages › Apparence**, sous la présentation ;
  - ancienne : **Configuration** (écran « Configuration IP »), sous « Nouvelle interface ».
- **Code administrateur** : chaque changement passe par `PinCodeDialog.show`, la même fenêtre que les autres zones
  protégées (configuration du serveur, présentation, annulation de vente) ; Annuler ou code faux : rien n'est
  enregistré. Le code est demandé à tous les comptes (réglage de l'appareil, comme dans Prestige Mobile).
- Choix enregistré pour le **prochain lancement** ; la fenêtre qui suit propose « **Plus tard** » ou « **Relancer
  maintenant** » (retour au premier écran — l'accueil si l'on est connecté —, interface reconstruite ; la session
  reste ouverte).

## 3. Compatibilité vérifiée

| Élément | Effet de la réduction | Vérifié par |
|---|---|---|
| **PDF et impressions** (`pdf` / `printing` : ticket Z du Récap de caisse, Suivi Péremption, Évolution du stock) | **Aucun** : pages **A4** mises en page en points PDF, sans lecture de l'écran ni de la densité ; la fenêtre d'impression / de partage est native (hors interface Flutter). Le ticket Z produit est **identique octet pour octet** (hors identifiant et date du document) quelle que soit la taille. | `unitaires/taille_ecran_test.dart` (garde-fou sur les sources, PDF identique) |
| **Graphique d'Évolution du stock exporté** (`RepaintBoundary.toImage(pixelRatio: 3)`) | Image capturée dans le repère du graphique, **avant** la réduction : même taille en pixels (et même PDF) en Automatique, Compact et Très compact. | `unitaires/taille_ecran_test.dart` |
| **Graphiques fl_chart** (Analyses, Évolution du stock, Pilotage) | Réduits avec l'écran, valeur au toucher juste (touchers transformés). | `ergonomie/taille_ecran_test.dart` |
| **Calendriers** (`showDatePicker`, `showDateRangePicker`) | Réduits avec l'interface, sans débordement. Les cases des jours (grille de Material, 38 dp de haut) sont déjà sous 48 dp à la taille normale : non dû au réglage. | `ergonomie/taille_ecran_test.dart` |
| **Feuilles du bas, menus Exporter, fenêtres** | Dans la `MaterialApp` : réduites, positionnées sur l'écran réel. | `ergonomie/taille_ecran_test.dart` |
| **Barre du bas** (3 onglets, 4 avec Pilotage) | Tient sur 400 / 450 dp, cibles ≥ 48 dp de l'interface. | `ergonomie/taille_ecran_test.dart` |
| **Menu latéral tablette** (présentation B, côté court ≥ 600 dp) | Tablette : rien ne change en Automatique. Un V2s en Compact voit 400 dp : reste « téléphone ». | `ergonomie/taille_ecran_test.dart` |
| **Session** (cookie JSESSIONID), **licence** | Gardées à « Relancer maintenant » (providers au-dessus) ; l'accueil reconstruit redemande ses chiffres avec le même cookie, accepté par le serveur. | `e2e/parcours_taille_ecran_test.dart` |
| **Déconnexion automatique** (délai d'inactivité, `AppLifecycleObserver`) | Toujours active après la relance (observateur reconstruit sous la `MaterialApp`). | `e2e/parcours_taille_ecran_test.dart` |
| **Clavier système** | `viewInsets` ramenés à l'échelle : le champ reste posé sur le clavier réel. | `unitaires/taille_ecran_test.dart` |
| **Vues natives** | Aucune dans l'interface (elles ne seraient pas réduites). | `unitaires/taille_ecran_test.dart` |

## 4. Tests

- `test/unitaires/taille_ecran_test.dart` : facteurs, seuil (V2s, V3, Sunmi 1080 × 1920, téléphones 1080 × 2400,
  Samsung 360 × 800 dp, tablettes, limites exactes), choix manuel prioritaire, persistance et valeur abîmée, données
  d'écran, touchers et clavier, PDF / impressions, une seule `MaterialApp` sous la racine.
- `test/ergonomie/taille_ecran_test.dart` : écrans principaux de la nouvelle interface (connexion A / B, accueil
  A / B / C, barre à 3 et 4 onglets, Réglages, Tous les menus, graphiques, feuilles du bas, menus Exporter,
  calendrier) sur V2s en **Automatique**, **Compact** et **Très compact** (texte 1,0 et 1,3) : interface qui remplit
  exactement l'écran, aucun débordement ni exception, cibles, libellés, contraste ; autres appareils en Automatique
  (V3 → Compact ; téléphones 1080 × 2400 et tablette : rien ne change).
- `test/e2e/parcours_taille_ecran_test.dart` : réglage protégé par le code (Annuler, code faux, bon code), « Plus
  tard » = prochain lancement, « Relancer maintenant » garde la session (cookie accepté), déconnexion automatique
  toujours active, ancienne interface (Configuration), téléphone courant inchangé.
- **Tests existants adaptés** (`test/support/ergonomie.dart`) : les profils Sunmi 720 × 1440, Sunmi 1080 × 1920
  (411 × 731 dp) et téléphone 360 × 640 dp des tests d'ergonomie sont désormais en **Compact automatique** (c'est le
  but du réglage). Les attentes ne sont pas affaiblies, elles sont exprimées dans l'interface :
  - cibles tactiles : **48 dp de l'interface** (43,2 dp réels en Compact, 38,4 en Très compact : réduction voulue) ;
  - contraste : même calcul que Flutter, mais sur une photo à **un échantillon par dp de l'interface**
    (`test/support/contraste_interface.dart`) ; la règle de Flutter photographie à un échantillon par dp réel, et un
    texte réduit de 13 → 11,7 dp y est mesuré sur ses bords anticrénelés (1,15:1 pour un gris #5F6368 sur blanc),
    alors que l'appareil a 2 pixels par dp. Un témoin vérifie qu'un gris trop pâle (#BDBDBD) reste refusé.
    Un texte coupé par le bas ou le haut de l'écran (liste arrêtée au milieu d'une ligne, ex. « JOUR PAR JOUR » de
    Tableau : Analyses sur le Sunmi 1080 × 1920 en ×1,3) n'est pas mesuré dans l'interface réduite : seul un morceau
    des lettres est photographié ; il l'est quand il est entier à l'écran.
  Les téléphones 411 × 891 dp et la tablette restent à la taille normale : règles de Flutter telles quelles.
  `test/support/application.dart` remet le réglage à Automatique à chaque téléphone préparé.

## 5. Limites connues

- Une vue native Android ne serait pas réduite (il n'y en a aucune ; un test le vérifie).
- En Très compact, les textes de 12 dp deviennent 9,6 dp réels : à réserver aux petits terminaux.
