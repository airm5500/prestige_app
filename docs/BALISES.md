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
git push origin --tags
```

En plus de ces balises, l'interrupteur **Nouvelle interface** (`lib/interface_version.dart`) permettra,
à partir de l'étape 3, de revenir à l'accueil et à la configuration d'origine sans réinstaller.

| Balise | SHA | État |
|---|---|---|
| `avant-etape-0` | `65a31b488489f5f690ce0aeac7cd2bea1f7b7a0a` | `master` d'origine « version 2.3 » (13/07/2026) : application telle qu'installée chez le pharmacien. |
