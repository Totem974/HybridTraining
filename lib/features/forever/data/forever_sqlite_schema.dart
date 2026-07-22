import 'package:sqflite_common/sqlite_api.dart';

Future<void> createForeverWorkspaceTables(Database db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS forever_drafts(
    draft_id TEXT PRIMARY KEY,
    payload_version INTEGER NOT NULL,
    definition_id TEXT NOT NULL,
    definition_revision INTEGER NOT NULL,
    payload_json TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''');
}

Future<void> createForeverTrainingTables(Database db) async {
  await db.execute('''CREATE TABLE IF NOT EXISTS macrocycles(
    id TEXT PRIMARY KEY,
    definition_id TEXT NOT NULL,
    definition_revision INTEGER NOT NULL,
    state TEXT NOT NULL,
    schema_version INTEGER NOT NULL,
    logical_hash TEXT NOT NULL,
    snapshot_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS macrocycle_nodes(
    macrocycle_id TEXT NOT NULL,
    node_index INTEGER NOT NULL,
    slot_id TEXT NOT NULL,
    role TEXT NOT NULL,
    cycle_id TEXT NOT NULL,
    state TEXT NOT NULL,
    snapshot_json TEXT NOT NULL,
    PRIMARY KEY(macrocycle_id, node_index)
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS macrocycle_training_maxes(
    macrocycle_id TEXT NOT NULL,
    node_index INTEGER NOT NULL,
    movement_id TEXT NOT NULL,
    value_kind TEXT NOT NULL,
    centi_units INTEGER NOT NULL,
    unit TEXT NOT NULL,
    PRIMARY KEY(macrocycle_id, node_index, movement_id, value_kind)
  )''');
  await db.execute('''CREATE TABLE IF NOT EXISTS macrocycle_events(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    macrocycle_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    occurred_at TEXT NOT NULL
  )''');
}

Future<void> migrateForeverWorkspaceTables(
  Database db,
  int oldVersion,
  int newVersion,
) => createForeverWorkspaceTables(db);

Future<void> migrateForeverTrainingTables(
  Database db,
  int oldVersion,
  int newVersion,
) => createForeverTrainingTables(db);
