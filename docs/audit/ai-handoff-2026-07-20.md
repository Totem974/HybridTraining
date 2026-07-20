# Rapport de passation IA — 20 juillet 2026

## Objet

Ce document permet à une autre IA de reprendre le dépôt sans dépendre de
l'historique de conversation. Il décrit l'état réellement livré et vérifié de
la reconstruction du coeur Forever et de son shell Web de validation.

## État Git autoritatif

- Dépôt : `Totem974/HybridTraining`.
- Branche de référence protégée : `kevin`.
- Branche de travail et de livraison :
  `rebuild/forever-engine-core-20260719`.
- Remote autorisé : `GitHub` ; GiTea reste hors circuit.
- Dernier commit fonctionnel avant ce rapport :
  `a8585df fix: harden imported and terminal workout state`.
- Historique récent :
  - `74968a8 fix: enforce workout and TM chronology integrity` ;
  - `9d16d52 fix: confirm all future session amendments` ;
  - `39f922c fix: preserve terminal workout history` ;
  - `4af5f24 fix: require exact program switch previews`.

Toujours relire `AGENTS.md` avant toute intervention. La phase temporaire gèle
l'UI produit et l'onboarding au profit du domaine Dart pur, de la provenance
des règles et des tests. `.SOURCE/` et `reference/` sont locaux, ignorés et en
lecture seule.

## Fonctionnalités livrées

### Coeur Forever

- Définitions versionnées et compilateur de plans Forever.
- Macro-séries Leader/Anchor et programmes autonomes pris en charge par le
  Core Validation Shell.
- Chronologie stricte des plans, blocs, cycles, séances, résultats et Training
  Max.
- Prévisualisation exacte et confirmation obligatoire des changements futurs.
- Conservation de l'historique des séances terminées, annulées ou abandonnées.
- Reprise cohérente des séances et des repos expirés.
- Journal des mutations dérivé des changements réels et suffisamment complet
  pour reconstruire les performances après une annulation.

### Persistance et imports

- Écritures SQLite transactionnelles avec contrôles de hiérarchie et
  d'appartenance.
- États terminaux immuables dans les runtimes canonique et legacy.
- Validation des provenances de toutes les règles exécutables importées.
- Refus des règles `NEEDS_REVIEW`, JSON invalides ou références non reconnues.
- Quarantaine explicite des anciens plans v4 dépourvus de provenance, sans
  suppression silencieuse de leur historique.
- Aller-retour réel vérifié d'un plan Forever contenant un événement de
  progression TM sourcé par `TM-PROG-001`.

### Livraison Web

- Build de production compatible avec `/` et un sous-chemin tel que
  `/hybrid/`.
- Serveur local avec fallback SPA pour les liens directs.
- Smoke test du bundle compilé : chargement de l'entrée, rechargement du lien
  direct `poc/531/generator` et marqueur posé après le premier rendu réel de la
  page Générateur.
- Persistance Web dans `localStorage`. L'origine complète doit rester stable ;
  l'export JSON est le moyen de transfert portable.

## Preuves de validation au commit `a8585df`

- `flutter pub get` : réussi.
- `dart format --set-exit-if-changed .` : 139 fichiers, aucun changement.
- `flutter analyze` : aucune anomalie.
- `flutter test --reporter compact` : 413/413 tests réussis.
- Build Web release avec base `/` : réussi.
- Build Web release avec base `/hybrid/` : réussi.
- Smoke du bundle compilé sur `/` : réussi.
- Smoke du bundle compilé sur `/hybrid/` : réussi.
- Chrome `150.0.7871.129` avec ChromeDriver `150.0.7871.124` : les cinq
  scénarios d'intégration versionnés réussissent en 34,7 secondes.
- Dernière revue indépendante : aucun P0/P1 restant ; le P2 sur la faiblesse du
  smoke test a été corrigé par le marqueur de rendu de route.

Les messages d'erreur « simulated interruption » visibles dans certains tests
SQLite sont intentionnels : ils vérifient le rollback atomique.

## Commandes de reproduction

Depuis la racine locale du dépôt :

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test --reporter compact
```

Build et validation de la racine :

```powershell
.\tool\build_web_release.ps1 -BaseHref /
.\tool\smoke_web_release.ps1 `
  -ChromeExecutable "<chemin-vers-chrome.exe>" `
  -BasePath / `
  -Port 8081
```

Build et validation du sous-chemin :

```powershell
.\tool\build_web_release.ps1 -BaseHref /hybrid/
.\tool\smoke_web_release.ps1 `
  -ChromeExecutable "<chemin-vers-chrome.exe>" `
  -BasePath /hybrid/ `
  -Port 8082
```

Parcours Chrome versionnés :

```powershell
.\tool\run_chrome_e2e.ps1 `
  -DriverPath "<chemin-vers-chromedriver.exe>" `
  -DriverPort 4444 `
  -ChromeExecutable "<chemin-vers-chrome.exe>"
```

## Test manuel depuis Android Studio

L'environnement est conforme : Flutter 3.44.6, Dart 3.12.2, Chrome et Edge sont
détectés, et `flutter doctor -v` ne signale aucun défaut. Android Studio garde
toutefois dans `.idea/workspace.xml` une ancienne cible physique
`fb5709d`. Le panneau **Running Devices** n'est pas le sélecteur des navigateurs.

La voie immédiate et fiable est le terminal intégré (`Alt+F12`) :

```powershell
flutter run -d chrome -t lib/main.dart
```

Dans cette session, `r` recharge, `R` redémarre et `q` arrête. Pour restaurer
le sélecteur graphique, utiliser `Ctrl+Maj+A`, rechercher `Select Device`, puis
choisir `Chrome (web)`. Si l'action reste absente, fermer Android Studio avant
de retirer la cible périmée de `.idea/workspace.xml` ; ne pas modifier ce fichier
pendant que l'IDE est ouvert.

## Limites et travaux différés

- Chrome est le navigateur de référence de cette livraison.
- Android est volontairement différé conformément à la priorité donnée au Web.
- Edge est détecté mais son ancien parcours WebDriver reste affecté par une
  incompatibilité de capabilities avec Flutter 3.44.6 ; ce n'est pas une porte
  de sortie de la livraison Chrome.
- Firefox a une validation historique, mais n'est pas couvert par le contrat de
  release automatisé actuel.
- Le Web utilise `localStorage`, tandis que SQLite concerne l'application non
  Web.
- Le Core Validation Shell n'est pas une décision définitive d'UI produit.
- Ne pas reprendre de code, texte protégé, secret ou actif sans licence depuis
  `.SOURCE/`.

## Consignes pour la prochaine IA

1. Vérifier immédiatement la branche et `git status --short`.
2. Préserver tout changement utilisateur ; aucun reset ou stash non autorisé.
3. Ne rendre exécutable aucune règle sans provenance revue.
4. Ajouter un test de non-régression à chaque changement métier.
5. Exécuter les quatre commandes obligatoires avant toute déclaration de fin.
6. Pour une évolution Web, reconstruire et tester `/` et `/hybrid/`, puis lancer
   les scénarios Chrome.
7. Ne pousser que `rebuild/forever-engine-core-20260719` vers `GitHub`, après
   liste finale et autorisation explicite du propriétaire.
