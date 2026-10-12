# HTTPS et trafic en clair (prestige_app)

## Ce que fait l'application (étape 1)

- **Réseau local (mode « Local »)** : inchangé. L'adresse saisie sans protocole (ex. `192.168.1.100`)
  est jointe en **HTTP**, comme avant.
- **Serveur exposé sur Internet (mode « Distant »)** : l'adresse peut désormais être saisie avec son
  protocole, par exemple `https://pharmacie.example.com`. Le port reste celui du champ « Port du Serveur »
  (souvent `443` ou `8181` pour HTTPS). HTTPS n'est **jamais imposé** : `http://…` ou une adresse sans
  protocole restent acceptés.
- Les certificats acceptés sont ceux reconnus par Android (autorités du système). Un certificat
  auto-signé est refusé : le message « Connexion sécurisée (HTTPS) impossible : certificat du serveur
  refusé » s'affiche. Utiliser un certificat reconnu (par exemple Let's Encrypt) sur le serveur.
- Les mêmes clés de stockage sont utilisées (`local_ip`, `remote_ip`) : aucune migration.

## Pourquoi le trafic en clair reste autorisé

`android/app/src/main/res/xml/network_security_config.xml` autorise le HTTP en clair pour tous les
domaines. Le restreindre n'est **pas faisable sans casser le mode local** :

- chaque officine joint son serveur à une **adresse IP locale qui lui est propre** (saisie dans la
  Configuration) ;
- `<domain-config>` d'Android ne sait lister que des **noms de domaine**, pas des plages d'adresses IP
  (`192.168.0.0/16`, `10.0.0.0/8`…) : on ne peut pas dire « clair autorisé seulement sur le réseau local » ;
- interdire le clair par défaut bloquerait donc toutes les installations actuelles en HTTP.

## Recommandation (étape 5)

1. Mettre le serveur Prestige derrière HTTPS pour l'accès **distant** (reverse proxy avec certificat
   reconnu), puis saisir `https://…` comme adresse distante sur chaque téléphone.
2. Quand toutes les officines utilisent HTTPS en distant et un **nom** fixe en local (ex. nom DNS du
   serveur), le clair pourra être limité à ces noms :

   ```xml
   <network-security-config>
       <base-config cleartextTrafficPermitted="false" />
       <domain-config cleartextTrafficPermitted="true">
           <domain includeSubdomains="false">serveur-prestige.local</domain>
       </domain-config>
   </network-security-config>
   ```

   À ne faire qu'après vérification sur chaque officine (sinon l'application ne joint plus le serveur).
