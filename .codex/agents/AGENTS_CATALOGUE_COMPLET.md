# AGENTS.md — HybridTraining

## Objectif produit

```text
catalogue publié
+ choix utilisateur
+ 1RM / rep-max / Training Max
+ ratio TM
+ schedule
+ matériel
+ assistance / conditioning
= cycle généré
```

Forever viendra ensuite et composera des cycles en appelant le même `CycleCompiler`.

L'interface ne contient aucune règle d'entraînement.

## Priorité active

```text
CATALOGUE CYCLE EXHAUSTIF
+ POC WEB CYCLE PILOTÉ PAR CE CATALOGUE
```

Le vertical slice Standard existe déjà. Ne pas le reconstruire.

Ordre :

1. geler les contrats catalogue, moteur et Web ;
2. classifier tout l'inventaire ;
3. terminer les composants réutilisables ;
4. normaliser toutes les familles Cycle ;
5. combler les primitives génériques manquantes ;
6. compiler toutes les variantes ;
7. raccorder l'interface Web existante ;
8. valider le POC ;
9. traiter Forever plus tard.

## Définition de « complet »

Le catalogue est complet seulement si :

- toutes les entrées historiques sont présentes et classifiées ;
- tous les templates Cycle sont présents ;
- toutes leurs variantes, options et schedules sont présents ;
- les composants communs sont référencés, jamais recopiés ;
- chaque paramètre possède type, portée, défaut, bornes, pas et conditions ;
- chaque règle canonique possède livre, édition si connue, page ou section ;
- chaque variante Cycle possède une configuration valide compilable ;
- aucune variante Cycle attendue n'est `TODO`, placeholder, stub, `NEEDS_REVIEW`, `blocked`, `comingSoon` ou « non implémentée » ;
- aucune option affichée n'est sans effet ;
- aucune primitive Cycle n'est non supportée ;
- le rapport automatique indique zéro entrée Cycle non résolue.

Les entrées réellement documentaires ou non-Cycle sont classifiées et exclues du générateur. Elles ne sont pas affichées comme programmes désactivés.

## Architecture

```text
catalog_src/
  sources/
  shared/
  classic/
  beyond/
  powerlifting/
  forever_cycle/
  exercises/
  assistance/
  conditioning/
  schedules/

lib/features/
  training_catalog/
  cycle_generation/
  cycle_web/
  forever/
  training_log/
```

Dépendances :

```text
presentation → application → domain
data/infrastructure → ports domain/application
```

Le domaine est en Dart pur, sans Flutter, SQLite ni legacy.

## Trois bases

### `catalog.db`

Sources, mouvements, exercices, prescriptions, composants, templates, variantes, options, schedules, assistance, conditioning et définitions de cycles.

Une version publiée est immuable. Une correction crée une nouvelle version.

Une règle canonique exige une référence précise. Aucune licence, signature, PKI, trust channel ou reçu cryptographique.

### `workspace.db`

Profil, max, ratios, matériel, préférences, brouillons Web, configurations et programmes personnalisés.

### `training.db`

Snapshots autonomes, cycles, séances, blocs, séries, charges, plaques, résultats et événements.

Aucune clé étrangère inter-base.

## Source du catalogue

`catalog.db` est la base runtime.

Les sources modifiables sont déclaratives et réparties dans `catalog_src/`.

```text
catalog_src
→ lint
→ build déterministe
→ catalog.db
→ verify
→ coverage
```

Ne pas créer un fichier monolithique, un modèle EAV, un langage libre ou deux sources mutables concurrentes.

Les payloads polymorphes sont stricts et versionnés.

## Composants réutilisables

Référencer séparément :

- main work ;
- warm-up ;
- Joker ;
- deloads ;
- supplemental ;
- assistance ;
- conditioning ;
- prescriptions ;
- schedules ;
- mouvements et exercices ;
- équipements et capacités.

Chaque composant possède ID stable, révision, provenance, paramètres, contraintes et compatibilités.

## CycleCompiler

```text
ResolvedCycleDefinition
+ CycleRequest
= GeneratedCycle
```

Le compilateur :

- est pur et déterministe ;
- ne lit pas SQLite ;
- reçoit la date explicitement ;
- n'utilise aucun ID de template ;
- interprète uniquement des primitives génériques ;
- produit semaines, séances, blocs, séries, charges, plaques et snapshot.

Interdits :

```text
BbbCompiler
FslCompiler
PplCompiler
switch(templateId)
if (templateId == ...)
appel au moteur legacy
```

Une primitive nouvelle est générique et ajoutée une seule fois.

## POC Web Cycle

Réutiliser l'interface existante : mise en page, responsive, accessibilité, traductions et widgets.

Supprimer :

- listes statiques ;
- règles dans les widgets ;
- `Map` legacy ;
- conditions par template ;
- fallback legacy.

L'interface consomme un contrat applicatif gelé :

```text
CycleCatalogIndex
CycleEditorSchema
CycleEditorState
CycleRequest
GeneratedCycleView
```

Elle charge le catalogue depuis `catalog.db`, sauvegarde les brouillons dans `workspace.db` et les programmes dans `training.db`.

Sections :

- template et variante ;
- 1RM / rep-max / TM ;
- ratios ;
- warm-up ;
- Joker ;
- deload ;
- supplemental ;
- assistance ;
- conditioning ;
- barres et plaques ;
- scheduling ;
- résumé ;
- génération et sauvegarde.

Préserver la navigation Forever, sans développer Forever.

## Provenance

Ordre de recherche :

1. livres et références locales ;
2. audits validés ;
3. branches donneuses et goldens ;
4. moteur legacy comme oracle ;
5. application de référence pour les comportements observables.

Une observation d'application est marquée `referenceAppObserved`.

Ne jamais inventer une prescription.

En cas de conflit réel, poursuivre les lots indépendants et demander uniquement la décision précise.

## Réutilisation

Réutiliser sélectivement :

- calculs purs ;
- plating ;
- schedules ;
- value objects ;
- goldens ;
- fixtures ;
- widgets Web ;
- données et audits des branches donneuses.

Ne jamais fusionner ou cherry-pick une branche entière.

## Agents parallèles

Utiliser tous les slots disponibles, jusqu'à huit agents, après gel des contrats.

Chaque agent possède des chemins exclusifs et travaille dans un worktree ou une branche isolée.

Répartition :

1. Classic + Powerlifting ;
2. Beyond ;
3. cycles Forever + programmes finis Cycle ;
4. composants + schedules ;
5. exercices + assistance + conditioning ;
6. primitives + compilation ;
7. POC Web ;
8. couverture + intégration.

Le lead possède les contrats, schémas partagés, exports, composition root, intégration et commits.

Un agent ne contourne jamais une dépendance manquante.

## Efficacité

- Ne pas refaire les audits existants.
- Ne pas écrire de longs ADR.
- Ne pas reconstruire Standard.
- Ne pas créer de sécurité spéculative.
- Ne pas travailler sur Forever.
- Ne pas ajouter de placeholder.
- Tests ciblés pendant les lots, suite complète aux gates.
- Aucun build Android sans changement Android.

## Validation

```text
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
git diff --check
flutter build web --release
```

Rapport final minimum :

```text
classifiedEntries == inventoryEntries
unresolvedCycleEntries == 0
missingVariants == 0
missingOptionSchemas == 0
missingSchedules == 0
missingReferences == 0
unsupportedPrimitives == 0
placeholderEntries == 0
compileFailures == 0
```

## Git

- Préserver les changements utilisateur.
- Jamais de `git reset --hard`.
- Jamais de push forcé.
- Petits commits cohérents.
- Diff et tests avant commit.
- Aucun push sans autorisation explicite.
