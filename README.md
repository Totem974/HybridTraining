# Hybrid 5/3/1

Hybrid 5/3/1 est une application Flutter locale de programmation et de suivi
d'entraînement 5/3/1. Android est la plateforme prioritaire.

La Base0 fournit une tranche locale complète : onboarding, choix kg/lb,
planification 3 ou 4 jours, cycle Original 5/3/1 + First Set Last, séance guidée,
AMRAP, repos, notes, records, historique, calcul de plaques et modification des
Training Max. L'interface suit la maquette locale validée par le propriétaire.

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
flutter test integration_test -d <identifiant-appareil> --flavor dev
```

Compiler les deux APK de contrôle :

```powershell
flutter build apk --debug --flavor dev -t lib/main_dev.dart
flutter build apk --debug --flavor prod -t lib/main_prod.dart
```

Les APK sont produits dans `build\app\outputs\flutter-apk\`.

## Données locales et sauvegarde

La base SQLite est stockée dans l'espace privé de chaque flavor Android. Dev et
prod ont donc des données séparées. Désinstaller l'application ou effacer son
stockage Android supprime cette base.

Le format de sauvegarde JSON versionné et le pipeline d'import sont préparés,
mais l'écran d'export n'est pas encore présent. Il n'existe donc pas encore de
procédure de sauvegarde grand public.

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
- [catalogue Forever](docs/program-specifications/forever-catalog.md) ;
- [import historique](docs/migration/legacy-json-import.md) ;
- [matrice des écrans](docs/product/reference-screen-matrix.md).

## Limites Base0

- seul Original 5/3/1 + First Set Last est automatisé ;
- échauffement et assistance attendent la validation de leurs règles exactes ;
- pas encore d'écran d'export/import ni de notifications locales ;
- les statistiques avancées et graphiques restent informatifs ;
- la bibliothèque expose les programmes indexés, mais seul Original + FSL est activable ;
- le sélecteur anglais n'est pas encore exposé ;
- l'import de l'ancienne application attend un export anonymisé.

## Java utilisé par Android

Gradle exige Java 17 ou plus récent. Dans Android Studio, sélectionner le JDK
embarqué (`jbr`) dans **Settings > Build Tools > Gradle > Gradle JDK**. Une
session PowerShell configurée sur Java 8 ne peut pas exécuter le test Android.
