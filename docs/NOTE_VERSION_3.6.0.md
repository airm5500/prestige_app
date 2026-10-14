# Prestige Pharmacien 3.6.0+34 — refonte module par module, lot 4 (« le reste »)

Les quatre derniers modules encore à l'ancienne mise en page dans la nouvelle interface ont leur **nouvel écran** :
**Récap de caisse (ticket Z), Achats Fourn., Fichier Journal, Annulation Ventes**. Même méthode que les lots 1 à 3
(`NOTE_VERSION_LOT1.md`, `NOTE_VERSION_3.3.0.md`, `NOTE_VERSION_3.5.0.md`) : **les données ne changent pas** (mêmes
routes du serveur Prestige, mêmes paramètres, mêmes calculs, **même requête d'annulation**). La lecture et les calculs
sont partagés par l'écran d'origine et le nouvel écran (`lib/donnees/recap_caisse_donnees.dart`,
`achats_fournisseurs_donnees.dart`, `fichier_journal_donnees.dart`, `annulation_vente_donnees.dart`), et un test
compare, module par module, les requêtes envoyées (corps du POST compris) et les chiffres affichés.

L'**ancienne interface garde ses écrans** (aucun changement visible).

**Liste vérifiée** dans les menus de la nouvelle interface (`lib/nouvelle_interface/menus.dart`, accueils A / B / C,
onglets) : plus aucun module n'ouvre un écran de l'ancienne mise en page, hormis **Présences** (déjà refait). Le lien
« Fichier Journal » de l'onglet **Équipe** ouvre lui aussi le nouvel écran. Restent des écrans communs aux deux
interfaces qui ne sont pas des modules : Configuration du serveur, Personnaliser l'accueil, dialogue du code
administrateur.

## Numéro de version

**3.6.0+34** (3.6.0 = nouveaux écrans ; 34 = +1 par rapport à 33). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

Captures (données fictives) : `docs/maquettes/captures_lot4/` — téléphone 1080 × 2400 px, tablette 1920 × 1200 px.

| Fichier | Écran |
|---|---|
| `1_recap_caisse.png`, `1b_…_caissiers.png`, `1c_…_filtres.png` | Récap de caisse : chiffres, totaux globaux, un bloc par caissier, filtres (caissier, heures) |
| `2_achats.png`, `2b_…_filtres.png`, `2c_…_detail.png`, `2d_…_recapitulatif.png` | Achats Fourn. : liste, filtre fournisseur, détail d'un achat, « Récap Achat » |
| `3_journal.png`, `3b_…_filtres.png`, `3c_…_detail.png`, `3d_…_limite_200.png` | Fichier Journal : actions, filtres, détail, avertissement « 200 actions au plus » |
| `4_annulation_accueil.png` … `4i_annulation_liste_relue.png` | Annulation : recherche, détail de la vente, confirmation vide puis complète, code administrateur, vente annulée, liste relue |
| `5_droit_manquant.png` | « Droit manquant » (sans « Réessayer ») |
| `6_tablette_achats.png`, `6b_tablette_recap_caisse.png`, `6c_tablette_annulation_detail.png` | Tablette : tableau dense avec total, totaux en tableau et caissiers sur deux colonnes, lignes de la vente |

## Ce qui change pour vous (commun aux 4 modules)

- **Chiffres clés en cartes** en haut de chaque module.
- **Sélecteur de période commun** (Aujourd'hui · Hier · 7 jours · Ce mois · Mois dernier · Personnalisée, **3 ans au
  plus**), avec les dates par défaut d'origine (**aujourd'hui** partout). Récap, Achats et Journal se chargent **dès
  l'ouverture** : plus de bouton « Rechercher » / « Afficher les Achats ». L'annulation attend un numéro de vente,
  comme avant.
- **Filtres dans la feuille du bas** (bouton ☰, pastille, étiquettes et « Retirer les filtres ») : caissier et heures
  (Récap), fournisseur (Achats, local), opération et utilisateur (Journal, envoyés au serveur comme avant).
- **Exports** : aucun de ces écrans n'en avait ; il n'y a donc pas de menu « Exporter » (vérifié par les tests).
- **Cartes** sur téléphone, **tableau dense** sur tablette (ligne de total pour les achats), **détail en feuille**.
- **États clairs** : chargement, vide, *Serveur injoignable*, *Le serveur ne répond pas*, *Erreur du serveur* (avec
  « Réessayer »), *Session expirée* (retour à la connexion), **Droit manquant** (sans « Réessayer »).
- **Recherche contrôlée** (longueur, caractères, 0,5 s après la frappe) : achats et journal (locale, **aucune
  requête**), numéro de vente (annulation).

## Module par module

### Récap de caisse (ticket Z)
Même `POST /caisse/fetch-tickez` (`description: ALL`, dates, heures 00:00 → 23:59, `userId`, mêmes formats) et même
liste des caissiers (`GET /common/users?limit=9999`). Les montants sont ceux **calculés et formatés par le serveur**,
affichés tels quels (aucun recalcul). Chiffres : caissiers, espèces (« TOTAL ESP »), total VNO/VO, nombre de totaux ;
totaux globaux, puis un bloc par caissier (modes, puis totaux en gras ; négatifs en rouge **et** avec le signe « - »).
Heures dans la feuille des filtres ; sur une seule journée, l'heure de début doit précéder l'heure de fin (refus
expliqué, rien n'est envoyé).

### Achats Fourn.
Mêmes `GET /fournisseurs` et `GET /achats-fournisseurs?dtStart=&dtEnd=`. Recherche (fournisseur, N° de BL, N° de
commande) et filtre fournisseur **locaux**, même règle. **« Récap Achat »** (icône de la barre) : mêmes totaux HT / TVA /
TTC, par fournisseur ou pour le fournisseur choisi, **sur tous les achats de la période** (comme l'origine). Chiffres :
TTC, HT, TVA, achats (et fournisseurs) affichés. Les listes longues sont construites 50 par 50 (« Afficher plus »,
sans requête).

### Fichier Journal
Mêmes `GET /common/log-filtres`, `GET /common/users`, `GET /common/logs` (`criteria` = opération, -1 = toutes ;
`userId` ; `limit=200`). Chiffres : actions, utilisateurs, types d'action ; **avertissement quand les 200 actions
du serveur sont atteintes** (d'autres peuvent manquer). Recherche locale (description, type, utilisateur), détail
d'une action en feuille.

### Annulation Ventes — écriture irréversible, sécurité renforcée

**Requête inchangée** : `GET /vente/annulation/{id}`, entourée des mêmes relectures que l'étape 1f (déroulé partagé
avec l'ancien écran, `AnnulationVente.executer`) :

| Étape | Ce que fait l'application |
|---|---|
| Recherche | `GET /ventestats` (numéro obligatoire, 50 ventes au plus), comme avant |
| **Détail d'abord** | La vente s'ouvre en page : référence, date et heure, **client**, vendeur, type, montant, ticket, **lignes** (produit, quantité, prix, montant). Le bouton « Annuler cette vente » n'existe **que là**, seulement une fois le détail chargé et si la vente n'est pas déjà annulée. Détail en échec → aucune action possible. |
| **Confirmation renforcée** | Récapitulatif (référence, date, client, articles, montant) et avertissement « définitive », puis **saisie de la référence de la vente ou du mot ANNULER** : le bouton « Annuler la vente » reste **désactivé** tant que la saisie n'est pas complète. « Ne pas annuler » : **rien n'est envoyé** (pas même une relecture), message « Annulation abandonnée ». |
| **Code administrateur** | Si le compte n'est **ni administrateur ni pharmacien** (profil `xtypeuser` ≠ `dashboard` reçu à la connexion, `ProfilAcces`), le code administrateur des zones protégées est demandé (même dialogue, mêmes règles anti-force brute). Code refusé ou annulé → rien n'est envoyé. |
| **Anti double envoi** | Verrou pris dès l'appui (avant la confirmation) ; double appui sur la validation = une seule fermeture ; pendant l'envoi, le bouton devient « Annulation en cours… » et le retour est refusé. **Un seul GET.** |
| Relectures | Avant l'envoi (déjà annulée → aucun envoi), après l'envoi (résultat vérifié). Sans réponse du serveur, **jamais de renvoi automatique** : l'état réel est relu et annoncé. |
| Résultat | Message vert / rouge et encadré sur la page (« Vente annulée », « Annulation refusée : <message du serveur> »…), étiquette « Annulée », liste relue au retour. |
| Journal | Seulement l'issue (« Annulation de vente : annulee ») : ni référence, ni client, ni montant. |

Le serveur reste juge du droit (`P_BT_ANNULER_VENTE`). La route étant un **GET qui modifie**, une demande est faite au
serveur : `docs/serveur/DEMANDE_ECRITURES_SENSIBLES.md`, **point 9** (POST, contrôle de droit en 403 / `interdit`,
idempotence avec `X-Client-Ref`).

## Différences de comportement à connaître

- Récap, Achats et Journal se chargent à l'ouverture sur « Aujourd'hui » au lieu d'attendre un bouton.
- Le choix de mois des Achats (année en cours seulement) est remplacé par le sélecteur commun (« Mois dernier »
  envoie les mêmes dates).
- Les filtres s'appliquent par « Appliquer » dans la feuille (avant : à chaque changement).
- Annulation : il faut ouvrir la vente (plus de bouton « Annuler » directement dans la liste) ; un compte non
  responsable doit saisir le code administrateur.
- Les montants sont affichés « 118 000 F » (avant : « 118.000 FCFA »).

## Tests

- `test/lot4_non_regression_test.dart` : écran d'origine et nouvel écran contre le même faux serveur — même corps
  POST du ticket Z (jour, caissier), mêmes montants ; mêmes achats, recherche / filtre / récapitulatif locaux, mois
  dernier ; mêmes paramètres et actions du journal ; **même recherche, même détail, même requête d'annulation et
  mêmes relectures** ; aucune requête tant que la confirmation n'est pas complète ni après « Ne pas annuler ».
- `test/e2e/parcours_lot4_test.dart` (application entière, HTTP réel) : chaque module ouvert depuis l'accueil (et le
  Journal par l'onglet Équipe), période, filtres, détail, récapitulatif, pas de menu Exporter, retour ; annulation :
  « Ne pas annuler » = aucun envoi, **double appui = un seul envoi**, retour refusé pendant l'envoi, **compte non
  autorisé → code demandé** (refusé : aucun envoi ; accepté : un envoi), refus du serveur, détail en échec, journal
  sans donnée sensible ; 500 + Réessayer, droit manquant, serveur injoignable ; **session expirée pendant
  l'annulation** → connexion avec message, rien d'annulé.
- `test/unitaires/lot4_donnees_test.dart` : corps du ticket Z, filtres, récapitulatif, paramètres, confirmation
  renforcée, client du détail.
- Ergonomie et cohérence : les 4 nouveaux écrans et 22 états (remplis, filtres, détails, récapitulatif, limite de
  200, détail de vente, confirmation vide / complète, code administrateur, vente annulée, erreurs ;
  `test/support/cas_lot4.dart`) aux 5 tailles × texte 1,0 / 1,3, **sans aucun écart toléré** ; charte bleu nuit / ambre.
- Écrans d'origine : leurs tests existants (dont `annulation_vente_test.dart`, étape 1f) passent sans modification.

## Questions pour le pharmacien

1. **Code administrateur pour l'annulation** : il est demandé aux comptes qui ne sont ni administrateur ni pharmacien.
   Faut-il le demander à **tout le monde** (y compris vous), ou au contraire réserver le menu aux seuls responsables ?
2. **Récap de caisse** : quels totaux voulez-vous voir en tête (aujourd'hui : espèces et total VNO/VO) ? Mobile Money
   cumulé, chèques, différé ?
3. **Fichier Journal limité à 200 actions** par le serveur : faut-il une pagination (« Afficher plus ») côté serveur ?
4. **Achats Fourn.** : ouverture sur « Aujourd'hui » (origine) ou « Ce mois » ?
5. **Exports** : aucun de ces écrans n'en avait ; voulez-vous un PDF du ticket Z ou un CSV des achats ?
