# Migration de base de données v3

`CURRENT` — `DatabaseSchema.version = 3`.

La migration additive crée `workout_runtime_sessions`, `workout_runtime_blocks` et `workout_activities`, ainsi que l'index `workout_activities_block_idx`. Les clés étrangères utilisent `ON DELETE CASCADE` vers les séances/blocs versionnés.

Le format de sauvegarde vaut 3 et couvre les 24 tables v1 à v3. Les sauvegardes v1 et v2 restent acceptées ; les tables absentes sont normalisées en listes vides. L'import reste une transaction unique et un test restaure statut, bloc actif, notes, repos, activités et résultat JSON.
