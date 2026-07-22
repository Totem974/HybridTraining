# AGENTS.md — HybridTraining

## 1. Fondation validée

Le checkpoint de référence est la branche :

```text
codex/cycle-ui-source-parity-v2
```

avec notamment :

```text
94b0a25 docs: set cycle UI parity authority
19bb4fc feat: align cycle generator with source UI
```

État annoncé et à vérifier localement :

- catalogue exhaustif construit depuis `catalog_src` ;
- `CatalogResolver` ;
- `CycleCompiler` pur ;
- `ForeverComposer` pur ;
- 23 variantes Cycle compilées ;
- interface Flutter Web Cycle validée ;
- 399 tests ;
- build Web release ;
- branche poussée et worktree propre.

Cette branche est l’oracle fonctionnel et visuel de migration. Elle ne doit pas être réécrite ni supprimée.

## 2. Priorité active

```text
EXTRAIRE LE MOTEUR DART EN SDK LOCAL
+
CRÉER UNE INTERFACE WEB STATIQUE LÉGÈRE POUR /cycle
```

La nouvelle interface Web utilise :

```text
HTML
CSS
TypeScript
Vite
```

Elle fonctionne entièrement dans le navigateur.

Il n’existe :

- aucun backend ;
- aucun serveur applicatif ;
- aucune API HTTP métier ;
- aucun compte ;
- aucun cloud ;
- aucune synchronisation ;
- aucun transfert de données personnelles.

## 3. Architecture cible

```text
catalog_src
   ↓ build déterministe
catalog.db                 catalog.bundle.json
(native / référence)       (Web statique)
          \                 /
           \               /
        training_engine Dart pur
                  ↓
      training_engine_web_bridge
          Dart compilé en JavaScript
                  ↓
      Web HTML/CSS/TypeScript
                  ↓
       IndexedDB / export local
```

Le catalogue natif et le bundle Web sont produits depuis la même source et doivent partager la même empreinte logique.

## 4. Arborescence cible

```text
packages/
  training_engine/
    pubspec.yaml
    lib/
    test/

  training_engine_web_bridge/
    pubspec.yaml
    web/
    test/

contracts/
  v1/
    *.schema.json
    fixtures/

apps/
  web_generator/
    package.json
    vite.config.ts
    cycle/
      index.html
    src/
      engine/
      catalog/
      storage/
      shared/
      cycle/
    public/
    tests/

legacy/
  flutter_web_reference/   # uniquement si un déplacement est nécessaire
```

Le projet Flutter existant peut rester à la racine pendant la migration. Ne pas déplacer tout le dépôt sans nécessité.

## 5. Règle de non-duplication

Il ne doit exister qu’un seul moteur métier.

Interdictions :

- copier le moteur dans un nouveau dossier en conservant l’ancien actif ;
- réécrire les calculs en TypeScript ;
- coder les règles BBB/FSL/Forever dans le front ;
- conserver deux `CycleCompiler` ;
- maintenir deux codecs concurrents ;
- faire du front Web une nouvelle autorité métier.

Après extraction, Flutter doit lui aussi consommer `packages/training_engine`.

## 6. Contenu de `training_engine`

Le package est Dart pur.

Il contient ou expose :

- modèles du catalogue résolu ;
- codecs et validations métier ;
- calcul 1RM / rep-max / TM ;
- `CycleCompiler` ;
- `ForeverComposer` ;
- plating ;
- schedules ;
- erreurs et avertissements ;
- snapshots ;
- contrats de génération.

Il ne doit importer :

- ni Flutter ;
- ni `sqflite` ;
- ni `dart:io` ;
- ni DOM ;
- ni IndexedDB ;
- ni code de présentation ;
- ni moteur legacy.

Le moteur reçoit des objets ou snapshots résolus. Il ne lit pas directement une base.

## 7. Port local du moteur Web

Le bridge Web est une couche très mince.

Il utilise les API modernes :

```text
dart:js_interop
@JSExport
Function.toJS
createJSInteropWrapper
```

Il n’utilise pas :

```text
dart:html
dart:js
dart:js_util
package:js
```

La première cible est JavaScript optimisé :

```text
dart compile js -O2
```

Wasm est hors périmètre de cette première migration.

## 8. Frontière JSON locale

Le bridge n’expose pas d’objets Dart internes.

Toutes les opérations publiques utilisent des chaînes JSON versionnées :

```text
initialize(catalogJson) -> EngineInfoJson
getCatalogIndex(requestJson) -> CatalogIndexJson
getCycleEditorSchema(requestJson) -> CycleEditorSchemaJson
validateCycle(requestJson) -> ValidationReportJson
generateCycle(requestJson) -> CycleResponseJson
generateMacrocycle(requestJson) -> ForeverResponseJson
```

`generateMacrocycle` peut être exposé pour stabiliser le SDK, mais aucune nouvelle interface Forever n’est construite pendant cette phase.

Chaque réponse contient :

```text
apiVersion
engineVersion
catalogVersion
catalogHash
schemaVersion
```

Les erreurs sont structurées :

```text
code
path
messageKey
details
severity
```

Aucun texte localisé n’est utilisé comme identité.

## 9. Contrats

Les contrats publics sont versionnés dans :

```text
contracts/v1/
```

Le format source doit permettre de générer les types TypeScript.

Ne pas maintenir manuellement deux modèles divergents.

Les contrats minimum sont :

- `EngineInfo` ;
- `CatalogIndex` ;
- `CycleEditorSchema` ;
- `CycleRequest` ;
- `CycleResponse` ;
- `ForeverRequest` ;
- `ForeverResponse` ;
- `ValidationReport` ;
- `EngineError` ;
- `EngineWarning` ;
- `SnapshotEnvelope`.

Les clés inconnues sont refusées à la frontière moteur.

## 10. Catalogue Web

Le Web ne charge pas SQLite/Wasm pendant cette phase.

Il charge un bundle statique :

```text
catalog.bundle.json
```

Ce bundle est produit par le même pipeline que `catalog.db`.

Le build doit prouver :

```text
logicalHash(catalog.db) == logicalHash(catalog.bundle.json)
```

Le bundle contient uniquement les données nécessaires au runtime Web, sans données utilisateur.

## 11. Stockage Web

### IndexedDB

Utiliser IndexedDB pour :

- brouillon Cycle ;
- configurations sauvegardées ;
- snapshots générés ;
- futur brouillon Forever ;
- préférences nécessaires.

### localStorage

Réserver localStorage aux préférences minuscules, par exemple :

- langue ;
- sections repliées ;
- option d’affichage des plaques.

Le moteur ne connaît ni IndexedDB ni localStorage.

Le front stocke des enveloppes JSON versionnées produites ou validées par le moteur.

## 12. Interface Web

Technologie :

```text
HTML sémantique
CSS natif
TypeScript strict
Vite
```

Pas de React, Flutter, Vue ou Svelte dans cette première migration.

Le front utilise des modules et composants DOM légers, avec un store explicite.

La page Cycle reproduit au plus près le rendu validé :

- Weight ;
- Template ;
- Additional Options ;
- Plating & Barbell ;
- Scheduling ;
- Output ;
- Program ;
- responsive 1440 / 390 / 320 ;
- FR / EN ;
- clavier ;
- accessibilité.

Les règles de visibilité et de compatibilité viennent du moteur.

## 13. Deux pages à terme

L’architecture Web doit permettre une application multi-page statique :

```text
/cycle/
/forever/
```

Cette phase livre uniquement `/cycle/`.

Ne pas créer une fausse page Forever ni un placeholder produit.

L’ancienne page Flutter Forever reste disponible comme référence jusqu’au chantier suivant.

## 14. Migration progressive

Ordre obligatoire :

1. geler les résultats de référence ;
2. extraire le package Dart pur ;
3. faire consommer ce package par Flutter ;
4. créer les contrats JSON ;
5. créer le bridge JS ;
6. générer le bundle catalogue Web ;
7. construire la page `/cycle/` statique ;
8. comparer moteur natif et bridge JS ;
9. valider la parité visuelle et fonctionnelle ;
10. préparer le cutover ;
11. supprimer Flutter Web uniquement après autorisation.

Ne jamais retirer l’oracle avant la parité.

## 15. Parité obligatoire

Pour chaque variante Cycle exécutable :

```text
même catalogue
+ même CycleRequest
→ sortie Dart native
→ sortie bridge JavaScript
→ JSON canonique identique
```

La comparaison couvre :

- semaines ;
- séances ;
- blocs ;
- séries ;
- charges ;
- plaques ;
- dates ;
- avertissements ;
- snapshot ;
- hash logique.

Le front TypeScript ne transforme pas le résultat métier, sauf pour la présentation.

## 16. Tests Web

Utiliser :

- tests unitaires TypeScript ;
- tests DOM ;
- Playwright ;
- captures visuelles ;
- Chrome/Chromium ;
- mobile émulé ;
- tests d’absence de réseau externe.

Les tests doivent échouer si l’application appelle une URL externe au chargement ou pendant une génération.

## 17. Build

Scripts reproductibles attendus :

```text
engine:test
engine:build
contracts:generate
catalog:build:web
web:typecheck
web:test
web:e2e
web:build
verify:parity
```

Le build Web final produit uniquement des fichiers statiques.

Mesurer et rapporter :

- poids brut et gzip du bridge moteur ;
- poids brut et gzip du JavaScript UI ;
- poids CSS ;
- poids du catalogue ;
- temps de chargement local ;
- temps de génération de scénarios représentatifs.

Ne pas fixer de budget arbitraire avant la première mesure.

## 18. Travail parallèle

Après gel des contrats et ownership :

1. audit d’extraction moteur ;
2. package Dart pur ;
3. contrats + bridge JS ;
4. export catalogue Web ;
5. design system + HTML/CSS ;
6. formulaire Cycle TypeScript ;
7. stockage local + export ;
8. parité + Playwright + revue.

Le lead possède :

- contrats publics ;
- interfaces du package ;
- scripts de build racine ;
- intégration ;
- commits.

Aucun fichier modifié simultanément par deux agents.

## 19. Hors périmètre

- nouvelle interface Forever ;
- Android natif ;
- iOS natif ;
- backend ;
- API HTTP ;
- authentification ;
- synchronisation ;
- cloud ;
- suppression immédiate de Flutter ;
- Wasm ;
- refonte du catalogue ;
- nouvelles recettes.

## 20. Validation

Dart :

```text
dart format --set-exit-if-changed .
dart analyze
dart test
```

Flutter oracle :

```text
flutter analyze
flutter test
flutter build web --release
```

Web statique :

```text
npm ci
npm run typecheck
npm test
npm run build
npm run e2e
```

Parité :

```text
verify:parity
```

## 21. Git

- créer une branche depuis le checkpoint UI validé ;
- préserver tous les changements utilisateur ;
- jamais de `git reset --hard` ;
- jamais de push forcé ;
- petits commits cohérents ;
- aucun push sans autorisation explicite ;
- ne pas supprimer Flutter Web avant validation et autorisation.
