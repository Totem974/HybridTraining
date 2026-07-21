import 'package:sqflite/sqflite.dart';

abstract final class WorkspaceDatabaseSchema {
  static const version = 2;

  static Future<void> create(DatabaseExecutor db) async {
    await db.execute(
      '''CREATE TABLE athlete_profiles (id TEXT PRIMARY KEY, display_name TEXT NOT NULL, preferred_unit TEXT NOT NULL CHECK(preferred_unit IN ('kg','lb')), rounding_increment REAL CHECK(rounding_increment>0), created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    );
    await db.execute(
      '''CREATE TABLE weight_profiles (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, movement_key TEXT NOT NULL, one_rep_max REAL CHECK(one_rep_max>0), training_max REAL NOT NULL CHECK(training_max>0), training_max_ratio REAL NOT NULL CHECK(training_max_ratio>0 AND training_max_ratio<=1), unit TEXT NOT NULL CHECK(unit IN ('kg','lb')), effective_at TEXT NOT NULL, FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE, UNIQUE(athlete_id,movement_key,effective_at))''',
    );
    await db.execute(
      '''CREATE TABLE gyms (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, name TEXT NOT NULL, is_default INTEGER NOT NULL CHECK(is_default IN (0,1)), FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE, UNIQUE(id,athlete_id))''',
    );
    await db.execute(
      '''CREATE TABLE bars (id TEXT PRIMARY KEY, gym_id TEXT NOT NULL, name TEXT NOT NULL, weight REAL NOT NULL CHECK(weight>0), unit TEXT NOT NULL CHECK(unit IN ('kg','lb')), quantity INTEGER NOT NULL CHECK(quantity>0), FOREIGN KEY(gym_id) REFERENCES gyms(id) ON DELETE CASCADE, UNIQUE(id,gym_id))''',
    );
    await db.execute(
      '''CREATE TABLE plates (id TEXT PRIMARY KEY, gym_id TEXT NOT NULL, weight REAL NOT NULL CHECK(weight>0), unit TEXT NOT NULL CHECK(unit IN ('kg','lb')), quantity INTEGER NOT NULL CHECK(quantity>=0), FOREIGN KEY(gym_id) REFERENCES gyms(id) ON DELETE CASCADE)''',
    );
    await _createDraftsV2(db);
    await db.execute(
      '''CREATE TABLE custom_definitions (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, authority TEXT NOT NULL DEFAULT 'userCustom' CHECK(authority='userCustom'), parent_definition_id TEXT, parent_catalog_version_id TEXT, parent_catalog_content_hash TEXT, schema_version INTEGER NOT NULL CHECK(schema_version > 0), revision INTEGER NOT NULL CHECK(revision > 0), canonicalization_version INTEGER NOT NULL CHECK(canonicalization_version > 0), definition_hash TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('template','module')), name TEXT NOT NULL, definition_json TEXT NOT NULL CHECK(json_valid(definition_json)), created_at TEXT NOT NULL, updated_at TEXT NOT NULL, CHECK((parent_definition_id IS NULL AND parent_catalog_version_id IS NULL AND parent_catalog_content_hash IS NULL) OR (parent_definition_id IS NOT NULL AND parent_catalog_version_id IS NOT NULL AND parent_catalog_content_hash IS NOT NULL)), FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE workspace_preferences (athlete_id TEXT NOT NULL, key TEXT NOT NULL, value_json TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(athlete_id,key), FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
    );
    await _createMigrationQuarantine(db);
    await _createV2TablesAndIndexes(db);
  }

  static Future<void> _createDraftsV2(DatabaseExecutor db) => db.execute(
    '''CREATE TABLE workspace_drafts (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, catalog_version_id TEXT NOT NULL CHECK(length(trim(catalog_version_id))>0), catalog_content_hash TEXT NOT NULL CHECK(length(trim(catalog_content_hash))>0), catalog_canonicalization_version INTEGER NOT NULL CHECK(catalog_canonicalization_version>0), payload_schema_version INTEGER NOT NULL CHECK(payload_schema_version>0), kind TEXT NOT NULL CHECK(kind IN ('configuration','schedule','templateOverlay','moduleOverlay')), payload_json TEXT NOT NULL CHECK(json_valid(payload_json)), created_at TEXT NOT NULL, updated_at TEXT NOT NULL, FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE, UNIQUE(id,athlete_id))''',
  );

  static Future<void> _createMigrationQuarantine(
    DatabaseExecutor db,
  ) => db.execute(
    '''CREATE TABLE IF NOT EXISTS workspace_migration_quarantine (id TEXT PRIMARY KEY, source_schema_version INTEGER NOT NULL CHECK(source_schema_version>0), target_schema_version INTEGER NOT NULL CHECK(target_schema_version>source_schema_version), athlete_id TEXT NOT NULL, entity_type TEXT NOT NULL CHECK(entity_type IN ('workspaceDraft','gym')), entity_id TEXT NOT NULL, issue_code TEXT NOT NULL CHECK(length(trim(issue_code))>0), original_payload TEXT, original_row_json TEXT NOT NULL CHECK(json_valid(original_row_json)), status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','acknowledged')), FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
  );

  static Future<void> _createV2TablesAndIndexes(DatabaseExecutor db) async {
    await db.execute(
      '''CREATE TABLE workspace_draft_equipment (draft_id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, gym_id TEXT NOT NULL, bar_id TEXT NOT NULL, FOREIGN KEY(draft_id,athlete_id) REFERENCES workspace_drafts(id,athlete_id) ON DELETE CASCADE, FOREIGN KEY(gym_id,athlete_id) REFERENCES gyms(id,athlete_id), FOREIGN KEY(bar_id,gym_id) REFERENCES bars(id,gym_id))''',
    );
    await db.execute(
      '''CREATE TABLE workspace_draft_equipment_ids (draft_id TEXT NOT NULL, equipment_id TEXT NOT NULL CHECK(length(trim(equipment_id))>0), PRIMARY KEY(draft_id,equipment_id), FOREIGN KEY(draft_id) REFERENCES workspace_draft_equipment(draft_id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE workspace_draft_supported_loads (draft_id TEXT NOT NULL, load_kind TEXT NOT NULL CHECK(load_kind IN ('none','externalWeight','machineSetting','equipmentSetting','bodyweight','assistedBodyweight','addedBodyweightLoad','percentTrainingMax','percentOneRepMax')), PRIMARY KEY(draft_id,load_kind), FOREIGN KEY(draft_id) REFERENCES workspace_draft_equipment(draft_id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE workspace_draft_assistance (draft_id TEXT PRIMARY KEY, assistance_plan_id TEXT NOT NULL CHECK(length(trim(assistance_plan_id))>0), FOREIGN KEY(draft_id) REFERENCES workspace_drafts(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE workspace_draft_assistance_selections (id TEXT PRIMARY KEY, draft_id TEXT NOT NULL, slot_id TEXT NOT NULL CHECK(length(trim(slot_id))>0), movement_id TEXT NOT NULL CHECK(length(trim(movement_id))>0), deload_mode TEXT NOT NULL CHECK(deload_mode IN ('templateDefault','inheritRegular','custom','omit')), FOREIGN KEY(draft_id) REFERENCES workspace_draft_assistance(draft_id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE workspace_draft_assistance_prescriptions (selection_id TEXT NOT NULL, phase TEXT NOT NULL CHECK(phase IN ('regular','deload')), sets INTEGER NOT NULL CHECK(sets>0), repetition_kind TEXT NOT NULL CHECK(repetition_kind IN ('fixed','range','amrap')), repetition_minimum INTEGER, repetition_maximum INTEGER, load_kind TEXT NOT NULL CHECK(load_kind IN ('none','externalWeight','machineSetting','equipmentSetting','bodyweight','assistedBodyweight','addedBodyweightLoad','percentTrainingMax','percentOneRepMax')), load_value REAL, PRIMARY KEY(selection_id,phase), FOREIGN KEY(selection_id) REFERENCES workspace_draft_assistance_selections(id) ON DELETE CASCADE, CHECK((repetition_kind='fixed' AND repetition_minimum>0 AND repetition_maximum IS NULL) OR (repetition_kind='range' AND repetition_minimum>0 AND repetition_maximum>=repetition_minimum) OR (repetition_kind='amrap' AND repetition_maximum IS NULL AND (repetition_minimum IS NULL OR repetition_minimum>=0))), CHECK((load_kind IN ('none','bodyweight') AND load_value IS NULL) OR (load_kind NOT IN ('none','bodyweight') AND load_value IS NOT NULL AND load_value>=0)))''',
    );
    await db.execute(
      '''CREATE TABLE workspace_draft_conditioning (draft_id TEXT NOT NULL, sequence INTEGER NOT NULL CHECK(sequence>=0), definition_id TEXT NOT NULL CHECK(length(trim(definition_id))>0), modality TEXT NOT NULL CHECK(modality IN ('time','distance','repetitions','intervals','open')), target REAL CHECK(target>0), work_seconds INTEGER CHECK(work_seconds>0), rest_seconds INTEGER CHECK(rest_seconds>=0), PRIMARY KEY(draft_id,sequence), FOREIGN KEY(draft_id) REFERENCES workspace_drafts(id) ON DELETE CASCADE, CHECK(modality!='intervals' OR work_seconds IS NOT NULL))''',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS gyms_one_default_per_athlete_idx ON gyms(athlete_id) WHERE is_default=1',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS weight_profiles_athlete_idx ON weight_profiles(athlete_id,movement_key,effective_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS workspace_drafts_athlete_idx ON workspace_drafts(athlete_id,updated_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS custom_definitions_athlete_idx ON custom_definitions(athlete_id,updated_at)',
    );
  }

  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion == newVersion) return;
    if (oldVersion == 1 && newVersion >= 2) {
      await _migrateV1ToV2(db);
    }
    if (oldVersion >= 1 && newVersion <= version) return;
    throw StateError(
      'No workspace.db migration from $oldVersion to $newVersion.',
    );
  }

  static Future<void> _migrateV1ToV2(Database db) async {
    await db.execute(
      '''ALTER TABLE athlete_profiles ADD COLUMN rounding_increment REAL CHECK(rounding_increment>0)''',
    );
    await db.execute(
      'CREATE UNIQUE INDEX gyms_id_athlete_idx ON gyms(id,athlete_id)',
    );
    await db.execute('CREATE UNIQUE INDEX bars_id_gym_idx ON bars(id,gym_id)');
    await _createMigrationQuarantine(db);

    await db.execute(
      '''INSERT INTO workspace_migration_quarantine (id,source_schema_version,target_schema_version,athlete_id,entity_type,entity_id,issue_code,original_row_json) SELECT 'v1:duplicate-default-gym:' || id,1,2,athlete_id,'gym',id,'gym.multiple_defaults',json_object('id',id,'athleteId',athlete_id,'name',name,'isDefault',is_default) FROM gyms WHERE is_default=1 AND athlete_id IN (SELECT athlete_id FROM gyms WHERE is_default=1 GROUP BY athlete_id HAVING count(*)>1)''',
    );
    await db.execute(
      '''UPDATE gyms SET is_default=0 WHERE is_default=1 AND athlete_id IN (SELECT athlete_id FROM workspace_migration_quarantine WHERE issue_code='gym.multiple_defaults')''',
    );

    await db.execute(
      'ALTER TABLE workspace_drafts RENAME TO workspace_drafts_v1',
    );
    await _createDraftsV2(db);
    await db.execute(
      '''INSERT INTO workspace_migration_quarantine (id,source_schema_version,target_schema_version,athlete_id,entity_type,entity_id,issue_code,original_payload,original_row_json) SELECT 'v1:invalid-draft:' || id,1,2,athlete_id,'workspaceDraft',id,CASE WHEN NOT json_valid(payload_json) THEN 'workspace_draft.invalid_json' ELSE 'workspace_draft.invalid_catalog_coordinate' END,payload_json,json_object('id',id,'athleteId',athlete_id,'catalogVersionId',catalog_version_id,'catalogContentHash',catalog_content_hash,'kind',kind,'payloadJson',payload_json,'createdAt',created_at,'updatedAt',updated_at) FROM workspace_drafts_v1 WHERE NOT json_valid(payload_json) OR length(trim(catalog_version_id))=0 OR length(trim(catalog_content_hash))=0''',
    );
    await db.execute(
      '''INSERT INTO workspace_drafts (id,athlete_id,catalog_version_id,catalog_content_hash,catalog_canonicalization_version,payload_schema_version,kind,payload_json,created_at,updated_at) SELECT id,athlete_id,catalog_version_id,catalog_content_hash,1,1,kind,payload_json,created_at,updated_at FROM workspace_drafts_v1 WHERE json_valid(payload_json) AND length(trim(catalog_version_id))>0 AND length(trim(catalog_content_hash))>0''',
    );
    await db.execute('DROP TABLE workspace_drafts_v1');

    await _createV2TablesAndIndexes(db);
  }
}
