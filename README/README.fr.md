| [🇰🇷 한국어](README.md) | [🇺🇸 English](README.en.md) | [🇯🇵 日本語](README.ja.md) | [🇨🇳 简体中文](README.zh-Hans.md) | [🇹🇼 繁體中文](README.zh-Hant.md) | [🇻🇳 Tiếng Việt](README.vi.md) | [🇫🇷 Français](README.fr.md) | [🇩🇪 Deutsch](README.de.md) | [🇪🇸 Español](README.es.md) | [🇵🇹 Português](README.pt.md) | [🇹🇭 ไทย](README.th.md) | [🇸🇦 العربية](README.ar.md) |
|---|---|---|---|---|---|---|---|---|---|---|---|

<p align="center">
  <img src="../Assets.xcassets/MoaIMF_icon.png" width="128" height="128" alt="Icône MoaIMF">
</p>

<h1 align="center">MoaIMF</h1>

<p align="center">
  <strong>Initial. Medial. Final. Composed.</strong><br>
  Une app de barre des menus macOS qui normalise en sécurité les noms de fichiers Unicode décomposés vers NFC
</p>

<p align="center">
  <a href="#présentation">Présentation</a> ·
  <a href="#utilisation">Utilisation</a> ·
  <a href="#installation-et-build">Installation et build</a> ·
  <a href="#sécurité-et-confidentialité">Sécurité</a> ·
  <a href="#développement">Développement</a>
</p>

## Présentation

MoaIMF est une app macOS de barre des menus qui normalise les noms de fichiers et de dossiers sélectionnés par l’utilisateur vers Unicode NFC. Son nom évoque l’assemblage des parties initiale, médiane et finale d’une syllabe hangul en une forme composée.

Sur macOS, les noms de fichiers coréens peuvent être enregistrés sous une forme décomposée proche de NFD après être passés par des systèmes de fichiers, apps, outils de téléchargement, outils de décompression, disques externes, NAS ou services de synchronisation. Finder peut afficher `한글.txt`, tandis qu’Alfred, le terminal ou certains scripts voient `ㅎㅏㄴㄱㅡㄹ.txt` et ne retrouvent pas le fichier.

MoaIMF n’est pas un script de nettoyage ponctuel. C’est un utilitaire local qui surveille en continu les dossiers autorisés par l’utilisateur et corrige les problèmes de noms pour les fichiers nouvellement créés ou téléchargés.

## Captures d’écran

Écran principal de l’app. Pendant la surveillance, l’icône de la barre des menus passe par `ㅎ`, `ㅏ`, `ㄴ`, `한`. Quand la surveillance est en pause, l’icône reste sur `ㅎ`.

<table>
  <tr>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_ko.gif" alt="Animation coréenne de la barre des menus MoaIMF" width="100%"></kbd>
    </td>
    <td align="center" width="50%">
      <kbd><img src="../Screenshots/MoaIMF_main_en.png" alt="Écran anglais de la barre des menus MoaIMF" width="100%"></kbd>
    </td>
  </tr>
</table>

### Dossiers surveillés

<kbd><img src="../Screenshots/MoaIMF_monitoring_folders_en.png" alt="Réglages des dossiers surveillés" width="100%"></kbd>

Les réglages commencent avec `Downloads` comme dossier par défaut. Les boutons `+` et `-` ajoutent ou retirent des dossiers. Chaque dossier peut être activé ou désactivé indépendamment, et un dossier dont l’autorisation a expiré peut être sélectionné de nouveau.

### Exceptions de stabilité des téléchargements

<kbd><img src="../Screenshots/MoaIMF_exceptions_en.png" alt="Exceptions de stabilité des téléchargements" width="100%"></kbd>

Un fichier en cours de téléchargement peut ne pas encore avoir son nom final, et sa taille ou sa date de modification peut encore changer. MoaIMF fournit des règles verrouillées pour `.crdownload`, `.download`, `.part`, `.partial`, `.tmp`, et permet d’ajouter des règles personnalisées.

### Historique récent

<kbd><img src="../Screenshots/MoaIMF_recent_history_en.png" alt="Historique récent" width="100%"></kbd>

L’historique peut être consulté pour aujourd’hui, 7 jours, 30 jours ou toute la période, puis filtré par renommage, conflit, autorisation ou erreur. La recherche compare aussi des variantes normalisées afin de traiter les différences NFC/NFD comme une même saisie.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/history.jsonl
```

### À propos

<kbd><img src="../Screenshots/MoaIMF_about_en.png" alt="À propos de MoaIMF" width="100%"></kbd>

La fenêtre About affiche le nom de l’app, la version, une courte description et les informations de copyright. L’image illustre la combinaison de jamo décomposés en caractère composé, comme `ㅎㅏㄴ -> 한`.

## Fonctionnalités

- Voir l’état de surveillance depuis la barre des menus, mettre en pause, reprendre et quitter
- Utiliser Downloads comme emplacement surveillé par défaut
- Ajouter et retirer plusieurs dossiers avec `+` et `-`
- Parcourir récursivement les dossiers surveillés
- Accéder uniquement aux dossiers choisis par l’utilisateur via des security-scoped bookmarks
- Détecter les nouveaux fichiers et changements avec FSEvents
- Attendre la stabilisation de la taille et de la date de modification avant traitement
- Ne jamais écraser automatiquement en cas de conflit possible
- Enregistrer renommages, conflits, autorisations, déconnexions et erreurs dans l’historique
- Aucune communication serveur, connexion de compte ou télémétrie

## Fonctionnement

MoaIMF ne modifie pas le contenu des fichiers. L’app ne traite que la forme de normalisation Unicode des noms de fichiers et de dossiers.

Le flux est simple : l’utilisateur choisit un dossier, l’app enregistre l’autorisation via bookmark, FSEvents signale les changements, le service de scan vérifie les exceptions et la stabilité, calcule le nom cible NFC, vérifie les conflits et l’identité du fichier, exécute le rename, puis enregistre le résultat.

Cette structure évite de fusionner arbitrairement des fichiers en conflit ou de créer automatiquement des noms comme `-1`, `copy` ou `복사본`. Les cas qui demandent une décision de l’utilisateur restent dans l’historique et les notifications.

## Utilisation

1. Lancez `MoaIMF.app`; l’icône apparaît dans la barre des menus.
2. Ouvrez `Watched Folder Settings...` et ajoutez les dossiers à surveiller.
3. Choisissez `Normalize Existing Items` ou `Watch New Items Only`.
4. Utilisez `Pause Watching` et `Resume Watching` pour suspendre ou reprendre.
5. Utilisez `Scan All Now` ou `Scan Now` pour lancer un scan manuel.
6. Choisissez la langue dans le menu `Language`.
7. Activez `Launch at Login` si vous voulez lancer MoaIMF à la connexion.
8. Sélectionnez `Quit MoaIMF` pour quitter sans laisser de daemon ou helper.

Les langues fournies sont des traductions IA destinées à faciliter l’utilisation. Signalez les erreurs ou demandes de nouvelles langues via `Issues`.

## Installation et build

MoaIMF suppose actuellement une installation depuis les sources. Aucun paquet signé Developer ID et notarized par Apple n’est encore fourni.

```sh
git clone https://github.com/charliehotel/MoaIMF.git
cd MoaIMF
scripts/check.sh
open .build/MoaIMF.app
```

Pré-requis : macOS 13 Ventura ou ultérieur, Xcode 16 ou Command Line Tools compatibles, Swift 6 toolchain, Git. Pour construire uniquement le bundle :

```sh
scripts/build-app.sh
```

## Données locales

MoaIMF stocke son état et l’historique dans Application Support à l’intérieur du conteneur sandbox macOS de l’app.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

Fichiers principaux : `watched-folders.json`, `stability-rules.json`, `history.jsonl`, `recovery/`. Certains réglages sont aussi stockés dans `UserDefaults`.

## Sécurité et confidentialité

MoaIMF change uniquement les noms. Il ne lit ni ne modifie le contenu des fichiers, n’accède qu’aux dossiers sélectionnés, ne suit pas les liens symboliques, ne scanne pas l’intérieur des packages comme `.app` ou `.photoslibrary`, vérifie les conflits et fonctionne entièrement en local. Pas de réseau, compte, analytics ni télémétrie.

## Limites

MoaIMF ne change pas le stockage des noms de fichiers à l’échelle de macOS, ne force pas toutes les apps à écrire en NFC, ne fusionne pas les conflits, ne reconstruit pas directement les index Spotlight ou Alfred, et se concentre pour l’instant sur les builds depuis les sources.

## Désinstallation

1. Désactivez `Launch at Login`.
2. Sélectionnez `Quit MoaIMF`.
3. Supprimez `MoaIMF.app`.
4. Pour supprimer l’état local, supprimez le dossier Application Support de MoaIMF dans le conteneur de l’app.

```text
~/Library/Containers/<app bundle identifier>/Data/Library/Application Support/MoaIMF/
```

Cette opération ne reconvertit pas les noms déjà passés en NFC vers NFD.

## Développement

Le projet utilise Swift Package Manager.

```sh
xcrun swift-format lint --strict --recursive Sources Tests Package.swift
swift test
swift build
scripts/build-app.sh
```

- [Spécification v0.1](../docs/superpowers/specs/2026-06-21-moaimf-v0.1-design.md)
- [Plan d’implémentation v0.1](../docs/superpowers/plans/2026-06-21-moaimf-v0.1.md)
- [Guide de contribution](../CONTRIBUTING.md)
- [Politique de sécurité](../SECURITY.md)

## Licence

MoaIMF est distribué sous [MIT License](../LICENSE).
