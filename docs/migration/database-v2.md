# Migration de base de données v2

## Ouverture

`DatabaseSchema.version` vaut 2. Une base neuve crée d’abord le schéma v1 puis
les tables additives v2. Une base v1 exécute la même partie additive dans la
transaction d’upgrade SQLite. Les tables v1 et leurs lignes ne sont jamais
supprimées.

Tables ajoutées :

- `program_definition_snapshots`
- `training_plans`
- `training_blocks`
- `plan_training_cycles`
- `plan_training_sessions`
- `session_blocks`
- `set_prescriptions`
- `set_performances`
- `plan_events`

Les noms `plan_training_cycles` et `plan_training_sessions` évitent de modifier
la sémantique des tables historiques homonymes du schéma v1.

## Atomicité et reprise

SQLite exécute `onUpgrade` dans une transaction. Une exception laisse la version
à 1 et annule les objets déjà créés. L’application peut alors être relancée ou
le fichier v1 restauré. Le test d’interruption vérifie la version, la disparition
d’une table sonde et la conservation d’une ligne v1.

## Sauvegardes

Le format d’export passe à la version 2 et inclut toutes les tables. L’inspection
d’import accepte les versions 1 et 2. Pour une sauvegarde v1, les tables v2
absentes sont normalisées en listes vides avant l’application atomique. Le
dry-run effectue la même validation sans écriture. Toute erreur de contrainte ou
d’insertion annule le remplacement complet.

Une sauvegarde v1 restaurée conserve le cycle `forever-original-fsl-v1`, les
séances et séries historiques, les résultats, records, notes et métadonnées de
repos. Elle ne fabrique aucun plan v2.

## Retour arrière applicatif

Le schéma v2 est additif, mais une ancienne version de l’application ne doit pas
ouvrir en écriture un fichier dont `user_version` vaut 2. Pour revenir à
l’application v1, restaurer une sauvegarde v1. Pour revenir aux données v1 avec
l’application actuelle, importer la sauvegarde v1 via le pipeline transactionnel.
