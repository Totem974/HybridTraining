import 'package:sqflite/sqflite.dart';

abstract final class WorkspaceDatabaseSchema {
  static const version = 1;

  static Future<void> create(DatabaseExecutor db) async {
    await db.execute(
      '''CREATE TABLE athlete_profiles (id TEXT PRIMARY KEY, display_name TEXT NOT NULL, preferred_unit TEXT NOT NULL CHECK(preferred_unit IN ('kg','lb')), created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    );
    await db.execute(
      '''CREATE TABLE weight_profiles (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, movement_key TEXT NOT NULL, one_rep_max REAL CHECK(one_rep_max>0), training_max REAL NOT NULL CHECK(training_max>0), training_max_ratio REAL NOT NULL CHECK(training_max_ratio>0 AND training_max_ratio<=1), unit TEXT NOT NULL CHECK(unit IN ('kg','lb')), effective_at TEXT NOT NULL, FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE, UNIQUE(athlete_id,movement_key,effective_at))''',
    );
    await db.execute(
      '''CREATE TABLE gyms (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, name TEXT NOT NULL, is_default INTEGER NOT NULL CHECK(is_default IN (0,1)), FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE bars (id TEXT PRIMARY KEY, gym_id TEXT NOT NULL, name TEXT NOT NULL, weight REAL NOT NULL CHECK(weight>0), unit TEXT NOT NULL CHECK(unit IN ('kg','lb')), quantity INTEGER NOT NULL CHECK(quantity>0), FOREIGN KEY(gym_id) REFERENCES gyms(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE plates (id TEXT PRIMARY KEY, gym_id TEXT NOT NULL, weight REAL NOT NULL CHECK(weight>0), unit TEXT NOT NULL CHECK(unit IN ('kg','lb')), quantity INTEGER NOT NULL CHECK(quantity>=0), FOREIGN KEY(gym_id) REFERENCES gyms(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE workspace_drafts (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, catalog_version_id TEXT NOT NULL, catalog_content_hash TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('configuration','schedule','templateOverlay','moduleOverlay')), payload_json TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE custom_definitions (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, authority TEXT NOT NULL DEFAULT 'userCustom' CHECK(authority='userCustom'), parent_definition_id TEXT, parent_catalog_version_id TEXT, parent_catalog_content_hash TEXT, schema_version INTEGER NOT NULL CHECK(schema_version > 0), revision INTEGER NOT NULL CHECK(revision > 0), canonicalization_version INTEGER NOT NULL CHECK(canonicalization_version > 0), definition_hash TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('template','module')), name TEXT NOT NULL, definition_json TEXT NOT NULL CHECK(json_valid(definition_json)), created_at TEXT NOT NULL, updated_at TEXT NOT NULL, CHECK((parent_definition_id IS NULL AND parent_catalog_version_id IS NULL AND parent_catalog_content_hash IS NULL) OR (parent_definition_id IS NOT NULL AND parent_catalog_version_id IS NOT NULL AND parent_catalog_content_hash IS NOT NULL)), FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE workspace_preferences (athlete_id TEXT NOT NULL, key TEXT NOT NULL, value_json TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(athlete_id,key), FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      'CREATE INDEX weight_profiles_athlete_idx ON weight_profiles(athlete_id,movement_key,effective_at)',
    );
    await db.execute(
      'CREATE INDEX workspace_drafts_athlete_idx ON workspace_drafts(athlete_id,updated_at)',
    );
    await db.execute(
      'CREATE INDEX custom_definitions_athlete_idx ON custom_definitions(athlete_id,updated_at)',
    );
  }

  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion == newVersion) return;
    throw StateError(
      'No workspace.db migration from $oldVersion to $newVersion.',
    );
  }
}
