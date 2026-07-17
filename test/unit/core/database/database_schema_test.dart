import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/database_schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'schema version 1 creates all Base0 tables and enforces relations',
    () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: DatabaseSchema.version,
          onConfigure: (database) =>
              database.execute('PRAGMA foreign_keys = ON'),
          onCreate: (database, version) => DatabaseSchema.createV1(database),
        ),
      );
      addTearDown(database.close);

      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final names = tables.map((row) => row['name']).toSet();

      expect(
        names,
        containsAll({
          'athlete_profiles',
          'exercises',
          'training_max_history',
          'gyms',
          'gym_bars',
          'gym_plates',
          'program_definitions',
          'training_cycles',
          'training_sessions',
          'training_sets',
          'personal_records',
          'app_metadata',
          'import_runs',
        }),
      );

      await expectLater(
        database.insert('training_sessions', {
          'id': 'session-without-cycle',
          'cycle_id': 'missing',
          'scheduled_for': '2026-07-17',
          'status': 'planned',
        }),
        throwsA(isA<DatabaseException>()),
      );
    },
  );

  test('unknown migration paths fail explicitly', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await expectLater(
      DatabaseSchema.migrate(database, 1, 2),
      throwsA(isA<StateError>()),
    );
  });
}
