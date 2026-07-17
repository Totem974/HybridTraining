# Audit du dépôt Base0

Date de l'audit : 17 juillet 2026

Branche auditée : `rebuild/base0-foundation`, créée depuis `kevin` à jour

Commit de départ : `3e6c02d BASE PROJECT`

## Résumé

Le dépôt de départ est un squelette Android natif généré par Android Studio. Il ne
contient pas de projet Flutter et ne contient aucun métier 5/3/1 réutilisable. La
stratégie retenue est de conserver uniquement les éléments d'infrastructure utiles
à l'historique du dépôt, puis de remplacer le squelette Android par un projet
Flutter généré proprement.

Les matériaux de référence sont présents localement dans `.SOURCE/`. Ils sont
strictement en lecture seule, exclus de Git et ne doivent jamais être utilisés
comme source de code à copier.

## État Git vérifié

- dépôt distant : `https://gitea.louconnect.fr/Totem974/HybridTraining` ;
- nom local du remote : `GiTea` ;
- branche de départ réellement présente : `kevin` en minuscules ;
- branche distante : `GiTea/kevin` ;
- `git pull --ff-only GiTea kevin` : `Already up to date` ;
- branche de travail : `rebuild/base0-foundation` ;
- aucun push effectué.

Le compte du bac à sable n'est pas le propriétaire Windows du dépôt. Les commandes
Git de cette session utilisent donc l'option temporaire
`-c safe.directory=D:/GitHub/HybridTraining`. Aucune exception globale n'a été
enregistrée.

## Architecture actuelle

Le dépôt comprend :

- un module Android `app` ;
- des scripts Gradle Wrapper ;
- un catalogue de versions Gradle ;
- des tests Android d'exemple ;
- des ressources et icônes Android Studio génériques.

Éléments configurés :

- Android Gradle Plugin `9.2.1` ;
- Gradle Wrapper `9.4.1` ;
- `applicationId` et namespace `com.example.hybridtraining` ;
- `minSdk 24` ;
- `targetSdk 36` ;
- compatibilité Java déclarée : Java 11 ;
- dépendances : AppCompat, Material Components, JUnit et Espresso.

## Éléments Flutter absents

Les éléments suivants n'existent pas dans la base de départ :

- `pubspec.yaml` et `pubspec.lock` ;
- `analysis_options.yaml` ;
- `lib/` ;
- `test/` et `integration_test/` ;
- répertoires Flutter `android/` et `ios/` ;
- configuration de flavors Flutter ;
- localisation ARB ;
- base de données locale ;
- navigation, état applicatif ou injection de dépendances ;
- scripts qualité Flutter.

## Problèmes identifiés

### Bloquants

1. Le dépôt n'est pas un projet Flutter.
2. Les identifiants Android sont encore ceux du modèle Android Studio.
3. Aucun flavor `dev` ou `prod` n'existe.
4. Le manifeste Android ne déclare aucun point d'entrée applicatif.
5. Flutter et Dart ne sont pas visibles dans le `PATH` du bac à sable Codex.

### Maintenabilité et sécurité

1. Il n'existait ni README utilisateur ni consignes pour les futurs agents.
2. Aucun contrôle automatique ni configuration CI n'est présent.
3. `.SOURCE/` n'était initialement pas ignoré et exposait un risque d'ajout
   accidentel de PDF, APK, fichiers décompilés, captures et données historiques.
4. Les règles Android de sauvegarde sont encore les exemples génériques d'Android
   Studio et devront être définies explicitement.
5. Le terminal expose Java 8 alors que la configuration du projet demande Java 11.
   Android Studio peut utiliser son JDK intégré, mais cette différence devra être
   vérifiée lors de la génération Flutter.

## Matériaux de référence observés

Inventaire de métadonnées uniquement :

- 4 648 fichiers ;
- environ 107,12 Mio ;
- captures d'écran ;
- XAPK et APK divisés ;
- sortie APKTool ;
- trois PDF ;
- ressources et métadonnées de signature historiques.

Aucun code décompilé, certificat, identifiant de facturation, fichier Firebase ou
élément graphique propriétaire ne doit être repris dans la nouvelle application.

## Fichiers à conserver

- historique Git et configuration du remote ;
- `.gitignore`, complété pour protéger les références ;
- Gradle Wrapper jusqu'à la génération du projet Flutter, afin de garder une base
  ouvrable pendant la transition ;
- matériaux `.SOURCE/` uniquement comme références locales non versionnées.

## Fichiers à remplacer

- module Android natif `app/` ;
- scripts Gradle racine du projet Android natif ;
- ressources et tests Android Studio d'exemple ;
- identifiant `com.example.hybridtraining` ;
- règles de sauvegarde Android génériques.

Le remplacement sera effectué par la génération Flutter, pas par une adaptation
progressive du squelette Android natif.

## Stratégie de migration

1. Générer un projet Flutter Android/iOS avec le SDK installé sur le poste.
2. Configurer immédiatement les identifiants et les flavors `dev` et `prod`.
3. Ajouter la structure feature-first et les fondations transversales.
4. Définir le domaine 5/3/1 indépendamment de Flutter et de SQLite.
5. Ajouter la base locale versionnée et les contrats JSON.
6. Construire une tranche verticale minimale, puis seulement étendre le catalogue.
7. Vérifier analyse, tests, compilation des deux flavors et lancement Android.

## Risques

- SDK Flutter inaccessible au processus Codex tant que son chemin n'est pas connu ;
- références protégées ou données personnelles ajoutées accidentellement ;
- règles 5/3/1 ambiguës automatisées sans preuve documentaire ;
- dépendances excessives ou incompatibles ;
- développement d'un catalogue trop large avant validation de la tranche verticale ;
- import historique incorrect en l'absence d'un export JSON anonymisé.

## Commandes réellement vérifiées

```powershell
git status --short
git remote -v
git branch --all
git log --oneline --decorate -n 15
git pull --ff-only GiTea kevin
```

Résultats : dépôt de départ nettoyé, `kevin` à jour et branche
`rebuild/base0-foundation` créée. Flutter, Dart, l'analyse et les tests ne sont pas
encore vérifiables dans le bac à sable, car `flutter` et `dart` n'y sont pas dans le
`PATH`.
