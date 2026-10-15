# Prestige Pharmacien 3.10.2+43 — « Serveur indisponible » pendant un redéploiement de Prestige

## Numéro de version

**3.10.2+43** (3.10.2 = correction ; 43 = +1 par rapport à 42). Toujours rien de publié sur Sunmi
(`docs/VERSIONS_SUNMI.md`).

## Demande du pharmacien

« Erreur 404 » affichée quand il se connecte pendant un redéploiement de Prestige. Cause : pendant le redéploiement,
le serveur d'applications ne sert plus l'application Prestige et répond **404** à `POST /user/auth` ; l'application
affichait « Le serveur a refusé la demande (code 404). ».

## Ce qui change (deux interfaces, écran de connexion)

« **Serveur indisponible, veuillez réessayer.** » s'affiche, à la place du code, quand la connexion échoue parce que
Prestige est momentanément indisponible :

| Cas | Avant | Maintenant |
|---|---|---|
| 404 de `POST /user/auth` (redéploiement) | « Le serveur a refusé la demande (code 404). » | « Serveur indisponible, veuillez réessayer. » |
| 502 / 503 / 504 (frontal, serveur surchargé ou en redémarrage) | « Erreur du serveur (code 503)… » | « Serveur indisponible, veuillez réessayer. » |
| Connexion refusée (Prestige arrêté, port fermé) | « Serveur injoignable… Vérifiez le Wi-Fi… » | « Serveur indisponible, veuillez réessayer. » |

**Inchangé** (jamais confondu) : mot de passe faux (message du serveur), erreur 500 (« Erreur du serveur »), réponse
illisible, Wi-Fi ou données coupés (« Serveur injoignable… Vérifiez le Wi-Fi », réseau inaccessible ou adresse
introuvable), certificat HTTPS refusé, et tous les **404 métier** des modules (élément introuvable) : la règle ne
s'applique qu'à la connexion. `/officine` lu pendant la connexion reste silencieux en cas d'échec (le dernier nom connu
reste affiché). Aucune relance automatique : un appui = une requête ; le pharmacien réessaie quand il veut.

Au lancement, l'écran « Prestige introuvable à cette adresse » (licence lue en 404) ajoute : « Si Prestige est en cours
de mise à jour (redéploiement), réessayez dans un instant. »

Détail technique : `ApiLoadException.serveurIndisponible` (404, 502, 503, 504, connexion refusée reconnue par le code
système 111 / 61 / 10061 ou le message « Connection refused », directement ou enveloppé par le client HTTP),
appliqué dans `AuthProvider.login`.

## Tests

- **Nouveaux** : `unitaires/serveur_indisponible_test.dart` (quels échecs sont « indisponible », reconnaissance de la
  connexion refusée), `integration/serveur_indisponible_test.dart` (404 / 502 / 503 / 504 : message, pas connecté, une
  seule requête, connexion au réessai ; mot de passe faux, 500, réponse illisible inchangés ; 404 métier inchangé ;
  `/officine` en 404), `e2e/parcours_serveur_indisponible_test.dart` (application entière, vrai réseau : redéploiement
  puis réessai, puis Prestige arrêté avec un vrai port fermé), `reseau/serveur_indisponible_test.dart` (deux
  interfaces, chaque cas, Wi-Fi coupé distinct, vrai port fermé), performance (`requetes_test.dart` : une requête,
  aucune relance en 10 s, message en moins de 600 ms), ergonomie (« Connexion · serveur indisponible » : interface
  d'origine, A et B, 5 tailles × 2 échelles).
- **Mis à jour** (règle changée) : `integration/services_test.dart` et `reseau/coupures_reprise_test.dart` — serveur
  arrêté (connexion refusée) à la connexion : « Serveur indisponible » au lieu de « Serveur injoignable ».
- `flutter analyze` : 44 remarques, aucune nouvelle.
