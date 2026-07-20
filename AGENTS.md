# AGENTS.md

## Phase temporaire : séries de macrocycles Forever v2

- Branche source en lecture seule : `refactor/forever-mode-composer`.
- Branche de travail : `refactor/forever-macrocycle-series-v2`.
- Remote de travail temporaire et unique : `GitHub`. `GiTea` reste hors circuit.
- La mission couvre le domaine Dart pur, le schéma v4 et ses migrations, le
  compilateur, la persistance, le composeur UI, l'accessibilité, les tests et la
  documentation nécessaires au vertical slice Forever.
- `ProgramLibrary -> ForeverProgramSeries -> MacrocycleSeriesValidator ->
  ForeverSequenceCompiler -> CycleStrategyRegistry / ProtocolStrategyRegistry
  -> VersionedTrainingPlan` est la chaîne d'autorité cible.
- Aucune règle non sourcée ou `NEEDS_REVIEW` ne peut devenir exécutable.
- Les plans existants, les anciens snapshots et les goldens historiques doivent
  être préservés ou rester fonctionnellement équivalents.
- Une série extensible ajoute un macrocycle à la fois ; aucune séquence infinie
  ne doit être matérialisée.
- Les séances et macrocycles terminés sont immuables. Seul le futur peut être
  régénéré.
- `.SOURCE/` ne peut être archivé ou nettoyé qu'après manifeste, archive externe
  intégrale et vérification de cette archive dans le cadre de cette tâche.
- Aucune suppression distante ni aucun push sans liste finale et autorisation
  explicite du propriétaire.
- Les commandes de qualité et validations Android de ce fichier restent
  obligatoires.
- Ces consignes sont temporaires et ne constituent pas une décision produit
  permanente.

## Projet

Hybrid 5/3/1 est une application Flutter locale en priorité Android. Elle doit
rester ouvrable dans Android Studio, compréhensible par une personne non
développeuse et utilisable sans compte ni connexion Internet.

## Architecture obligatoire

- Organisation feature-first sous `lib/features/`.
- Séparation présentation, domaine, données et services de plateforme.
- Domaine 5/3/1 en Dart pur, sans dépendance à Flutter, SQLite ou aux widgets.
- Règles de calcul dans le domaine, jamais dans les écrans.
- Persistance derrière des interfaces de domaine ou d'application.
- Navigation déclarative et état prévisible, injecté et testable.
- Modèles immuables lorsqu'ils représentent une valeur métier.
- Identifiants internes stables, indépendants des traductions.
- Définitions de programmes versionnées, structurées et validées.

Éviter les couches sans comportement, les packages internes multiples et les
abstractions ajoutées uniquement en prévision d'un besoin hypothétique.

## Structure cible

```text
lib/
  app/
  core/
  features/
  shared/
test/
  unit/
  widget/
  fixtures/
integration_test/
docs/
  architecture/
  audit/
  migration/
  product/
  program-specifications/
```

## Commandes obligatoires

Avant de terminer une tâche, exécuter depuis la racine :

```powershell
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Pour une modification de persistance, de navigation ou de parcours utilisateur,
exécuter également les tests d'intégration pertinents. Pour une modification
Android, compiler au minimum les deux flavors en mode debug.

Si une commande ne peut pas être exécutée, ne pas déclarer la tâche terminée :
documenter la commande, le blocage et la validation encore nécessaire.

## Git

- Branche de référence : `kevin` en minuscules.
- Branche source de cette mission : `refactor/forever-mode-composer`, en lecture
  seule.
- Branche de travail actuelle : `refactor/forever-macrocycle-series-v2`, créée
  depuis la branche source.
- Remote de travail temporaire et unique : `GitHub` / `origin` ; `GiTea` est hors
  circuit.
- `master`, `kevin` et la branche source sont protégées : ne jamais les modifier,
  les rebaser, les fusionner ou les pousser directement.
- Ne jamais utiliser de push forcé ou supprimer l'historique.
- Pousser uniquement `refactor/forever-macrocycle-series-v2`, sur GitHub, après
  les validations finales et l'autorisation explicite du propriétaire.
- Préférer de petits commits cohérents aux changements monolithiques.
- Vérifier `git status --short` avant et après une tâche.
- Préserver les changements utilisateur sans reset ni stash non autorisé.

## Références protégées

`.SOURCE/` et `reference/` sont locaux, ignorés et en lecture seule.

Interdictions :

- modifier ou commiter les références ;
- copier du code décompilé ;
- reprendre clés, signatures, certificats, identifiants commerciaux ou fichiers
  Firebase ;
- reprendre une icône, un logo, une illustration ou une police sans licence ;
- reproduire substantiellement le texte des livres.

Une règle ambiguë doit être marquée `NEEDS_REVIEW` avec sa source. Ne jamais
compléter une règle depuis la mémoire ou une supposition.

## Données et sécurité

- Ne jamais commiter de données personnelles ou d'export utilisateur réel.
- Les fixtures doivent être fictives et manifestement non personnelles.
- Aucun secret ni chemin local ne doit être versionné.
- Les imports doivent proposer validation, simulation, rapport et transaction
  atomique.
- Une donnée ignorée ou invalide ne doit jamais disparaître silencieusement.
- Les données de démonstration sont autorisées uniquement dans la flavor `dev`.

## Non-régression

Toute correction ou évolution métier doit ajouter ou adapter un test qui échoue
sans la modification. Les résultats attendus des calculs doivent être explicites.
Une migration de base doit préserver les données et disposer d'un test de version.
Les textes visibles doivent passer par la localisation française et anglaise.

## Critères de fin d'une tâche

Une tâche est terminée seulement si :

1. son comportement est implémenté sans données factices présentées comme réelles ;
2. les tests pertinents sont ajoutés et passent ;
3. formatage et analyse statique passent ;
4. les flavors concernées compilent ;
5. la documentation utilisateur et technique est à jour ;
6. aucune référence, donnée personnelle ou configuration locale n'est suivie ;
7. les limites et validations manuelles restantes sont déclarées.
