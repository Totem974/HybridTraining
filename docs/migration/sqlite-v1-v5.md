# Traçabilité SQLite v1 vers v5

## Périmètre et espaces de version

Quatre numéros coexistent et ne sont pas interchangeables :

| Espace | Version courante | Autorité | Signification |
|---|---:|---|---|
| Base locale SQLite | **v5** | `DatabaseSchema.version` | Structure physique ouverte par `LocalDatabase` et migrations `onUpgrade`. |
| Configuration du POC 5/3/1 | **v4** | `Poc531Configuration.schemaVersion` | Forme JSON des choix saisis ou restaurés par le composeur. Ce n'est pas une version SQLite. |
| Plan logique Core | **v5** | `canonicalTrainingPlanSchemaVersion` | Modèle canonique de plan, prescriptions, provenance, transitions et amendements. « v5 » est ici une génération métier, même si son stockage a été ajouté avec SQLite v5. |
| Sauvegarde native | **v5** | `BackupEnvelope.schemaVersion` | Format d'enveloppe export/import. Une sauvegarde n'est pas un fichier de base SQLite. |

Le présent document décrit la migration de **base locale**. La configuration POC
est détaillée dans [Migration Forever](../531-poc/forever-migration.md). Le format
de sauvegarde est résumé séparément plus bas.

## Chaîne d'upgrade de la base

`DatabaseSchema.migrate` applique les créations dans l'ordre croissant. Toutes
les versions sources publiées, v1 à v4, ont une route vers v5 ; toute route hors
de l'intervalle v1…v5 lève explicitement une `StateError`.

| Source | Étapes exécutées vers v5 | Transformation de lignes | Conservation prouvée | Preuve automatisée |
|---:|---|---|---|---|
| v1 | création v2, v3, v4, puis v5 | aucune ligne v1 réécrite | ligne `app_metadata` conservée ; tables historiques présentes ; nouvelles tables vides | `database_schema_test.dart` — **v1 to v5 migration preserves legacy rows** |
| v2 | création v3, v4, puis v5 | aucune ligne v2 réécrite | ligne sentinelle `app_metadata` conservée ; tables v3–v5 créées | boucle **v2 to v5 migration preserves existing rows** |
| v3 | création v4, conversion du runtime v3, puis création v5 | voir matrice runtime ci-dessous | sentinelle conservée ; exécution interrompue, résultat et événement migrés | boucle **v3 to v5 migration preserves existing rows** |
| v4 | création v5 uniquement | ajout de colonnes nullables et de tables ; aucun backfill | ligne sentinelle conservée ; tables v5 créées | boucle **v4 to v5 migration preserves existing rows** |
| v5 | aucune | aucune | ouverture à version identique sans migration | branche `oldVersion == newVersion` ; création complète couverte par **empty database creates v1 to v5 tables with constraints** |

La preuve « sentinelle conservée » ne signifie pas que chaque colonne de chaque
table historique possède un test de migration dédié. Le schéma est additif : les
anciennes tables ne sont ni supprimées ni renommées, et le test détaillé porte sur
le seul chemin qui transforme des lignes, le runtime v3.

## Tables et transformations

| Version introduite | Tables ou colonnes ajoutées | Traitement des données existantes | Provenance et événements | Preuve |
|---:|---|---|---|---|
| v1 | profil, exercices, historique TM, salles/barres/plaques, définitions, cycles/séances/séries historiques, records, métadonnées et imports | socle initial | `program_definitions.definition_json` et `import_runs.report_json` conservent leurs documents, sans journal de migration dédié | `createV1` ; test de création complète |
| v2 | snapshots de définition, plans/blocs/cycles/séances versionnés, blocs de séance, prescriptions/résultats de séries, `plan_events` | ajout pur ; les tables d'exécution v1 restent intactes | `rule_provenance_json` sur snapshot, bloc de séance, prescription et événement ; événement ordonné par plan | `createV2` ; tests v1→v5 et v2→v5 |
| v3 | `workout_runtime_sessions`, `workout_runtime_blocks`, `workout_activities` | ajout pur lors de v2→v5 ; ces tables deviennent source de conversion lors de v3→v5 | activité avec cible/résultat JSON, sans événement propre v3 | `createV3` ; tests v2→v5 et v3→v5 |
| v4 | `workout_executions`, `workout_set_outcomes`, `workout_execution_events` | pour une source v3, conversion session par session ; les tables v3 restent lisibles | création d'un événement `migratedFromV3` avec `{"sourceSchemaVersion":3}` | `createV4`, `migrateV3RuntimeToV4` ; test v3→v5 |
| v5 | colonnes Core sur plans/blocs/cycles/séances ; `activity_prescriptions`, `activity_results`, `training_max_timeline`, `plan_amendments`, `plan_transitions_v5`, `planned_events_v5` | colonnes ajoutées nullables, nouvelles tables vides ; aucun backfill implicite | `rule_id`, édition/génération de règles et `source_reference_json` sur prescriptions, timeline, transitions et événements ; snapshots avant/après et diff sur amendements | `createV5` ; test de création complète et boucle v1…v4→v5 |

### Conversion canonique du runtime v3

| Source v3 | Destination v4 conservée en v5 | Règle de conversion prouvée |
|---|---|---|
| `workout_runtime_sessions.status` | `workout_executions.state` | `started→activeSet`, `completed→completed`, `abandoned→abandoned`, `skipped→skipped`, sinon `planned` |
| première prescription sans résultat | `active_set_index` | premier index en attente ; si aucune attente, dernier index |
| prescriptions déjà renseignées | `reversible_stack_json` | liste ordonnée de leurs index |
| `set_performances` ou résultat de `workout_activities` | `workout_set_outcomes` | résultat, répétitions, charge, notes et horodatages sont repris avec priorité au résultat de série |
| session convertie | `workout_execution_events` | événement ordonné `migratedFromV3`, daté avec `updated_at` de la session |

Le test **v3 to v5 migration preserves existing rows** prouve le cas d'une
séance `started`, une série réussie de 5 répétitions à 80 kg et l'événement de
migration. Les autres branches du mapping sont définies dans
`migrateV3RuntimeToV4`, mais ne disposent pas chacune d'un cas de test isolé.

## Atomicité, échec et retour arrière

- SQLite exécute `onUpgrade` dans une transaction. Le test **interrupted
  migration rolls back and leaves v1 restorable** injecte une table puis une
  exception : la version reste v1, la ligne historique subsiste et la table
  partielle disparaît.
- **unknown migration paths fail explicitly** prouve qu'une source non prise en
  charge échoue au lieu d'être interprétée silencieusement.
- Il n'existe pas de downgrade v5→v4 ni de suppression des tables historiques.
  Le retour applicatif repose sur une sauvegarde compatible, pas sur une
  migration SQLite descendante.
- Le test d'interruption démontre la transaction d'upgrade sur un scénario v1 ;
  il ne simule pas une interruption distincte à chacune des étapes v2–v5.

## Sauvegarde v5 et restauration historique

`SqliteBackupManager` exporte dans une transaction un snapshot de toutes les
tables listées par `HybridBackupHandler.tables`. L'enveloppe native porte
`schemaVersion: 5`. Les sauvegardes v1, v2, v3, v4 et v5 sont inspectées ; pour
v1–v4, les tables apparues plus tard sont normalisées en listes vides avant
l'application. L'écriture supprime puis insère les données dans une transaction
unique respectant les dépendances de clés étrangères.

| Comportement sauvegarde | Conservation / échec | Preuve automatisée |
|---|---|---|
| export v5 puis dry-run et import | profil et programme restaurés ; dry-run sans écriture | **export, dry-run, atomic import and delete preserve a profile** |
| inspection/import v1 à v5 | chaque version attend son préfixe de tables et complète les tables ultérieures à vide | **backup schemas v1 through v5 pass inspection and import** |
| sauvegarde v1 utilisable | historique v1 et prochaine séance conservés, tables de plans v2 vides | **v1 backup imports into v5 without losing legacy history** |
| sauvegarde v2 | tables runtime v3 absentes restaurées vides | **v2 backup remains importable with empty runtime v3 tables** |
| version inconnue | rapport d'erreur, données existantes non remplacées | **invalid backup never replaces existing data** |
| document structurellement valide mais inutilisable | rapport d'erreur, profil existant conservé | **structurally valid but unusable backup never replaces a profile** |

Autorités : `lib/core/database/database_schema.dart`,
`test/unit/core/database/database_schema_test.dart`, puis, uniquement pour la
sauvegarde, `backup_envelope.dart`, `hybrid_backup_handler.dart`,
`sqlite_backup_manager.dart` et `sqlite_backup_manager_test.dart`.
