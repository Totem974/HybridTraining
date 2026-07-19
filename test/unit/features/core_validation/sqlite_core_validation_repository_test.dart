import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/core_validation/data/sqlite_core_validation_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late SqliteCoreValidationRepository repository;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('core-validation-');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temporary.path}/core.db',
    );
    repository = SqliteCoreValidationRepository(
      localDatabase: local,
      clock: () => DateTime.utc(2026, 7, 20),
    );
  });

  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });

  test('DEV fixture persists one Beginner plan and is idempotent', () async {
    await repository.createDevelopmentFixture();
    await repository.createDevelopmentFixture();

    final snapshot = await repository.load();
    expect(snapshot.profileName, 'Athlete DEV');
    expect(snapshot.activePlans, 1);
    expect(snapshot.plannedSessions, 9);
    expect(snapshot.actualTonnage, isNull);
    final database = await local.open();
    expect(
      (await database.query('training_plans')).single['blueprint_id'],
      'forever-beginner-prep-school-v1',
    );
  });

  test(
    'tonnage uses actual successful load and never prescribed load',
    () async {
      await repository.createDevelopmentFixture();
      final database = await local.open();
      final prescription = (await database.query(
        'set_prescriptions',
        limit: 1,
      )).single;
      expect((await repository.load()).actualTonnage, isNull);

      await database.insert('set_performances', {
        'id': 'performance-1',
        'prescription_id': prescription['id'],
        'result': 'success',
        'completed_reps': 6,
        'actual_load': 42.5,
        'notes': '',
        'recorded_at': DateTime.utc(2026, 7, 20).toIso8601String(),
      });

      expect((await repository.load()).actualTonnage, 255);
    },
  );
}
