import 'package:sqflite_common/sqlite_api.dart';

import '../../forever/data/forever_sqlite_schema.dart';

abstract final class TrainingDatabaseSchema {
  static const version = 3;
  static Future<void> create(Database db, int _) async {
    await db.execute('''CREATE TABLE snapshots(
      cycle_id TEXT PRIMARY KEY, schema_version INTEGER NOT NULL CHECK(schema_version = 1),
      resolved_json TEXT NOT NULL)''');
    await db.execute(
      '''CREATE TABLE sessions(
      id TEXT PRIMARY KEY, cycle_id TEXT NOT NULL REFERENCES snapshots(cycle_id),
      week_number INTEGER NOT NULL, sequence INTEGER NOT NULL, scheduled_for TEXT NOT NULL,
      movement_id TEXT NOT NULL, state TEXT NOT NULL CHECK(state IN
      ('planned','inProgress','completed','postponed','cancelled','skipped')))''',
    );
    await db.execute(
      '''CREATE TABLE blocks(
      id TEXT PRIMARY KEY, session_id TEXT NOT NULL REFERENCES sessions(id),
      sequence INTEGER NOT NULL, role TEXT NOT NULL, movement_id TEXT NOT NULL)''',
    );
    await db.execute('''CREATE TABLE planned_sets(
      id TEXT PRIMARY KEY, block_id TEXT NOT NULL REFERENCES blocks(id), sequence INTEGER NOT NULL,
      repetitions_json TEXT NOT NULL, percentage_basis_points INTEGER,
      planned_load_centi_units INTEGER, unit TEXT, plates_json TEXT NOT NULL,
      warning_json TEXT, result_state TEXT NOT NULL DEFAULT 'pending' CHECK(result_state IN
      ('pending','completed','failed','skipped')), actual_repetitions INTEGER,
      actual_load_centi_units INTEGER, note TEXT,
      CHECK(actual_repetitions IS NULL OR actual_repetitions >= 0),
      CHECK(actual_load_centi_units IS NULL OR actual_load_centi_units >= 0),
      CHECK(result_state != 'completed' OR actual_repetitions IS NOT NULL))''');
    await createForeverTrainingTables(db);
  }

  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await db.execute(
        "ALTER TABLE blocks ADD COLUMN movement_id TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await migrateForeverTrainingTables(db, oldVersion, newVersion);
    }
  }
}
