import 'package:sqflite/sqflite.dart';

abstract final class TrainingDatabaseSchema {
  static const version = 1;

  static Future<void> create(DatabaseExecutor db) async {
    await db.execute(
      '''CREATE TABLE plans (id TEXT PRIMARY KEY, athlete_id TEXT NOT NULL, catalog_version_id TEXT NOT NULL, catalog_content_hash TEXT NOT NULL, snapshot_schema_version INTEGER NOT NULL CHECK(snapshot_schema_version > 0), snapshot_canonicalization_version INTEGER NOT NULL CHECK(snapshot_canonicalization_version > 0), snapshot_hash_algorithm TEXT NOT NULL CHECK(snapshot_hash_algorithm IN ('sha256')), resolved_snapshot_hash TEXT NOT NULL, resolved_snapshot_json TEXT NOT NULL CHECK(json_valid(resolved_snapshot_json)), starts_on TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('draft','scheduled','active','completed','cancelled')), created_at TEXT NOT NULL, completed_at TEXT)''',
    );
    await db.execute(
      '''CREATE TABLE sessions (id TEXT PRIMARY KEY, plan_id TEXT NOT NULL, sequence INTEGER NOT NULL CHECK(sequence>=0), scheduled_for TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('scheduled','postponed','active','completed','cancelled')), postponed_from TEXT, started_at TEXT, completed_at TEXT, notes TEXT NOT NULL DEFAULT '', FOREIGN KEY(plan_id) REFERENCES plans(id) ON DELETE CASCADE, UNIQUE(plan_id,sequence))''',
    );
    await db.execute(
      '''CREATE TABLE session_blocks (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, sequence INTEGER NOT NULL CHECK(sequence>=0), kind TEXT NOT NULL, snapshot_json TEXT NOT NULL CHECK(json_valid(snapshot_json)), FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE, UNIQUE(session_id,sequence))''',
    );
    await db.execute(
      '''CREATE TABLE set_prescriptions (id TEXT PRIMARY KEY, block_id TEXT NOT NULL, sequence INTEGER NOT NULL CHECK(sequence>=0), prescription_json TEXT NOT NULL CHECK(json_valid(prescription_json)), FOREIGN KEY(block_id) REFERENCES session_blocks(id) ON DELETE CASCADE, UNIQUE(block_id,sequence))''',
    );
    await db.execute(
      '''CREATE TABLE set_results (prescription_id TEXT PRIMARY KEY, status TEXT NOT NULL CHECK(status IN ('pending','success','failure','skipped')), result_json TEXT NOT NULL CHECK(json_valid(result_json)), recorded_at TEXT, FOREIGN KEY(prescription_id) REFERENCES set_prescriptions(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      '''CREATE TABLE training_events (id TEXT PRIMARY KEY, plan_id TEXT NOT NULL, session_id TEXT, sequence INTEGER NOT NULL CHECK(sequence>=0), event_type TEXT NOT NULL, payload_json TEXT NOT NULL, occurred_at TEXT NOT NULL, FOREIGN KEY(plan_id) REFERENCES plans(id) ON DELETE CASCADE, FOREIGN KEY(session_id) REFERENCES sessions(id), UNIQUE(plan_id,sequence))''',
    );
    await db.execute(
      '''CREATE TABLE plan_statistics (plan_id TEXT NOT NULL, metric_key TEXT NOT NULL, metric_json TEXT NOT NULL, calculated_at TEXT NOT NULL, PRIMARY KEY(plan_id,metric_key), FOREIGN KEY(plan_id) REFERENCES plans(id) ON DELETE CASCADE)''',
    );
    await db.execute(
      'CREATE INDEX sessions_plan_idx ON sessions(plan_id,sequence)',
    );
    await db.execute(
      'CREATE INDEX events_plan_idx ON training_events(plan_id,sequence)',
    );
  }

  static Future<void> migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion == newVersion) return;
    throw StateError(
      'No training.db migration from $oldVersion to $newVersion.',
    );
  }
}
