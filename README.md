# Hybrid 5/3/1

Hybrid 5/3/1 est une application Flutter locale de programmation et de suivi
d'entraînement 5/3/1. Android est la plateforme prioritaire.

Base0 est en cours de construction. Les flavors Android, les identifiants et la
fondation Flutter fonctionnent. Le profil, la base locale et les séances ne sont pas
encore disponibles dans cette première étape.

## Prérequis Windows

- Windows 11 ;
- Android Studio avec les plugins Flutter et Dart ;
- Flutter stable ;
- un téléphone Android avec le débogage USB activé, ou un émulateur ;
- Git pour Windows.

Sur le poste principal, Flutter est installé dans `D:\SDK\flutter`.

Si la commande `flutter` n'est pas reconnue après l'installation, fermer puis
rouvrir Android Studio et PowerShell.

## Ouvrir le projet dans Android Studio

1. Ouvrir Android Studio.
2. Choisir **Open** et sélectionner `D:\GitHub\HybridTraining`.
3. Ne pas utiliser **New Project from Existing Sources**.
4. Si Android Studio demande le SDK Flutter, sélectionner `D:\SDK\flutter`.
5. Attendre la fin de l'indexation et de la récupération des dépendances.

## Préparer le projet

Dans PowerShell, depuis `D:\GitHub\HybridTraining` :

```powershell
flutter pub get
```

## Choisir un appareil Android

1. Activer les options développeur et le débogage USB sur le téléphone.
2. Brancher le téléphone et accepter l'autorisation affichée.
3. Vérifier la détection avec `flutter devices`.

Le téléphone doit apparaître avec la plateforme `android`.

## Lancer la version de développement

La version recommandée pendant le développement est identifiable par le nom
« Hybrid 5/3/1 Dev » et peut cohabiter avec la production :

```powershell
flutter run --flavor dev -t lib/main_dev.dart
```

Dans Android Studio, choisir **Hybrid 5/3/1 Dev** puis cliquer sur Run.

## Lancer la version de production en mode debug

```powershell
flutter run --flavor prod -t lib/main_prod.dart
```

Dans Android Studio, choisir **Hybrid 5/3/1 Prod**.

## Vérifier la qualité

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Compiler les deux APK de contrôle :

```powershell
flutter build apk --debug --flavor dev -t lib/main_dev.dart
flutter build apk --debug --flavor prod -t lib/main_prod.dart
```

Les APK sont produits dans `build\app\outputs\flutter-apk\`.

## Données locales et sauvegarde

La persistance Base0 n'est pas encore implémentée. L'écran actuel ne conserve donc
aucune donnée d'entraînement. La future base SQLite sera stockée dans l'espace privé
de chaque flavor Android : dev et prod auront des données séparées.

La sauvegarde JSON sera ajoutée avec validation et version de format. Tant que cette
fonction n'existe pas, ne considérer aucune donnée de développement comme
sauvegardée.

Les références locales sous `.SOURCE/` ne sont pas des données de l'application et
ne doivent jamais être ajoutées à Git.

## Problèmes courants

### `flutter` n'est pas reconnu

Redémarrer Android Studio et PowerShell, puis vérifier :

```powershell
D:\SDK\flutter\bin\flutter.bat --version
```

### Le téléphone n'apparaît pas

- vérifier le câble USB ;
- activer le débogage USB ;
- accepter l'ordinateur sur le téléphone ;
- installer le pilote USB du fabricant si nécessaire ;
- relancer `flutter devices`.

### Le premier build est long

Le premier lancement télécharge et initialise Gradle, le NDK et CMake. Les
compilations suivantes sont nettement plus rapides.

### Android Studio demande un SDK Flutter

Utiliser `D:\SDK\flutter`, sans ajouter `\bin` dans ce champ.

## Documentation technique

- [audit du dépôt](docs/audit/base0-repository-audit.md) ;
- [architecture](docs/architecture/overview.md) ;
- [dépendances](docs/architecture/dependencies.md) ;
- [matériaux de référence](docs/reference-materials.md).
