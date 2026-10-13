# Balises de retour arrière (prestige_app)

Avant chaque étape de la refonte, le commit de départ est noté ici. Pour revenir à l'état d'avant une
étape, sans rien perdre de l'historique :

```bash
# Voir l'état d'une balise
git checkout <SHA>

# Construire l'APK de cet état (sur une branche dédiée)
git checkout -b retour-<nom> <SHA>
flutter build apk --release
```

Les balises git (`git tag`) correspondantes peuvent être posées par la personne qui pousse le dépôt :

```bash
git tag avant-etape-0 65a31b488489f5f690ce0aeac7cd2bea1f7b7a0a
git tag avant-etape-1 c1dc8a1d4d06e76561cd696a98533b1b76393b40
git push origin --tags
```

En plus de ces balises, l'interrupteur **Nouvelle interface** (`lib/interface_version.dart`) permettra,
à partir de l'étape 3, de revenir à l'accueil et à la configuration d'origine sans réinstaller.

| Balise | SHA | État |
|---|---|---|
| `avant-etape-0` | `65a31b488489f5f690ce0aeac7cd2bea1f7b7a0a` | `master` d'origine « version 2.3 » (13/07/2026) : application telle qu'installée chez le pharmacien. |
| `avant-etape-1` | `c1dc8a1d4d06e76561cd696a98533b1b76393b40` | Étape 0 faite (test réparé, CI, version unique 2.3.0+23, interrupteur d'interface) : écrans et comportement identiques à l'origine. |

Commits de l'étape 1 (branche `claude/robustesse-securite`, version 2.4.0+24) : un commit par sous-étape
(1a stockage sûr, 1b journaux, 1c code administrateur, 1d erreurs réseau, 1e licence / serveur injoignable,
1f annulation, 1g saisies, 1h HTTPS, 1i signature documentée). Chaque sous-étape peut être annulée seule avec
`git revert <SHA>` (voir `git log --oneline avant-etape-1..`).
