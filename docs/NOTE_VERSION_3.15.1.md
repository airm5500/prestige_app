# Prestige Pharmacien 3.15.1+55 — Péremptions courtes : droit annoncé par le serveur (demande 55)

## Numéro de version

**3.15.1+55** : 3.15.1 parce que c'est un complément de la 3.15.0, 55 parce que le numéro de build augmente de 1. Rien n'a encore été publié sur Sunmi (`docs/VERSIONS_SUNMI.md`).

Serveur de référence : branche `claude/new-session-xm8ptu`, commit a30b33d9 (demandes mobiles 53, 54 et 55).

## Ce que le serveur fait maintenant

J'ai vérifié dans `ReceptionMobileRessource.peremptionsCourtes` que `GET v1/reception/peremptions-courtes` renvoie désormais `{success, total, valeur, peutChangerStatut, data}`.

- `peutChangerStatut` est un booléen. Il vaut vrai si la session a le droit P_BL_MOBILE_ACCEPTER_PEREMPTION_COURTE (`Droits.a`).
- Le serveur ne l'ajoute qu'aux réponses qui contiennent la liste.
- `PUT …/{id}/statut` refuse toujours sans ce droit (403, « Droit manquant »).

## Ce que fait l'application (`lib/nouvelle_interface/vague4/peremptions_courtes_vague4.dart`)

| `peutChangerStatut` | Comportement |
|---|---|
| `false` | Le statut est en lecture seule **dès l'ouverture**. Toucher le statut n'ouvre aucun choix et n'envoie aucune requête. Une ligne explique : « Statut en lecture seule : ce compte n'a pas le droit de le changer ». |
| `true` | Le changement est proposé, comme en 3.15.0 : un seul PUT par choix. |
| absent (serveur plus ancien) | Même comportement qu'en 3.15.0 : le changement est proposé. Si le serveur refuse (403), l'application affiche « Droit manquant », le statut reste inchangé et le changement n'est plus proposé sur cet écran. |

**Refus malgré `true`.** Le droit peut être retiré entre la lecture de la liste et le changement. Le refus 403 reste donc géré : message, statut inchangé, puis changement masqué.

**Relecture de la liste.** La valeur est relue à chaque lecture de la liste : ⟳, période ou filtres. Un droit accordé entre-temps se voit donc sans fermer l'écran.

**Lecture tolérante.** Le texte « true » ou « false » est accepté comme le booléen.

## Tests (comme `ci.yml`)

- `test/integration/retours_3_15_1_test.dart` couvre :
  - `false` : lecture seule, aucune feuille de choix, aucun PUT ;
  - `true` : un PUT ;
  - champ absent : 403, « Droit manquant », puis changement masqué ;
  - `false` puis `true` après ⟳ ;
  - « false » envoyé en texte.
- `test/integration/retours_3_15_0_test.dart` couvre le 403 malgré `true`.
- Faux serveur (`test/support/donnees_vague4.dart`) : `peutChangerStatut` vaut `true` par défaut, comme le serveur actuel. On peut aussi le mettre à `false` ou le retirer.
- Ergonomie : nouveau cas « statut en lecture seule » (`test/support/cas_retours_3_15_0.dart`).

## Ce qui reste à faire

Rien pour cette demande. La liste n'est toujours pas paginée par le serveur, voir la 3.15.0.
