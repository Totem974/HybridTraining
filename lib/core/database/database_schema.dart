import 'package:sqflite/sqflite.dart';

abstract final class DatabaseSchema {
  static const version = 1;

  static Future<void> createV1(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE athlete_profiles (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        preferred_unit TEXT NOT NULL CHECK(preferred_unit IN ('kg', 'lb')),
        rounding_increment REAL NOT NULL CHECK(rounding_increment > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name_key TEXT NOT NULL,
        category TEXT NOT NULL,
        is_main_lift INTEGER NOT NULL CHECK(is_main_lift IN (0, 1)),
        created_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE training_max_history (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        one_rep_max REAL NOT NULL CHECK(one_rep_max > 0),
        training_max REAL NOT NULL CHECK(training_max > 0),
        unit TEXT NOT NULL CHECK(unit IN ('kg', 'lb')),
        effective_at TEXT NOT NULL,
        FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id),
        FOREIGN KEY(exercise_id) REFERENCES exercises(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE gyms (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        name TEXT NOT NULL,
        is_default INTEGER NOT NULL CHECK(is_default IN (0, 1)),
        created_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE gym_bars (
        id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        name TEXT NOT NULL,
        weight REAL NOT NULL CHECK(weight > 0),
        unit TEXT NOT NULL CHECK(unit IN ('kg', 'lb')),
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        deleted_at TEXT,
        FOREIGN KEY(gym_id) REFERENCES gyms(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE gym_plates (
        id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        weight REAL NOT NULL CHECK(weight > 0),
        unit TEXT NOT NULL CHECK(unit IN ('kg', 'lb')),
        quantity INTEGER NOT NULL CHECK(quantity >= 0),
        deleted_at TEXT,
        FOREIGN KEY(gym_id) REFERENCES gyms(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE program_definitions (
        id TEXT PRIMARY KEY,
        schema_version INTEGER NOT NULL,
        name_key TEXT NOT NULL,
        definition_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE training_cycles (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        program_definition_id TEXT NOT NULL,
        program_definition_version INTEGER NOT NULL,
        starts_on TEXT NOT NULL,
        status TEXT NOT NULL,
        settings_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id),
        FOREIGN KEY(program_definition_id)
          REFERENCES program_definitions(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE training_sessions (
        id TEXT PRIMARY KEY,
        cycle_id TEXT NOT NULL,
        scheduled_for TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        status TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(cycle_id) REFERENCES training_cycles(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE training_sets (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        lift_id TEXT NOT NULL,
        sequence INTEGER NOT NULL,
        kind TEXT NOT NULL,
        training_max REAL NOT NULL,
        percentage REAL NOT NULL,
        unrounded_load REAL NOT NULL,
        rounding_increment REAL NOT NULL,
        prescribed_load REAL NOT NULL,
        prescribed_reps INTEGER NOT NULL,
        performance_set INTEGER NOT NULL CHECK(performance_set IN (0, 1)),
        result TEXT,
        completed_reps INTEGER,
        notes TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(session_id) REFERENCES training_sessions(id) ON DELETE CASCADE,
        UNIQUE(session_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE TABLE personal_records (
        id TEXT PRIMARY KEY,
        lift_id TEXT NOT NULL,
        load REAL NOT NULL,
        repetitions INTEGER NOT NULL,
        unit TEXT NOT NULL,
        achieved_at TEXT NOT NULL,
        source_set_id TEXT,
        FOREIGN KEY(source_set_id) REFERENCES training_sets(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE import_runs (
        id TEXT PRIMARY KEY,
        source_format TEXT NOT NULL,
        source_schema_version INTEGER,
        source_digest TEXT NOT NULL,
        dry_run INTEGER NOT NULL CHECK(dry_run IN (0, 1)),
        status TEXT NOT NULL,
        report_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX training_sessions_cycle_idx '
      'ON training_sessions(cycle_id, scheduled_for)',
    );
    await database.execute(
      'CREATE INDEX training_sets_session_idx '
      'ON training_sets(session_id, sequence)',
    );
  }

  static Future<void> migrate(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion == newVersion) return;
    throw StateError(
      'No database migration registered from $oldVersion to $newVersion.',
    );
  }
}
