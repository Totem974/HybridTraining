import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_training_store.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/import_export/domain/backup_envelope.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'export, dry-run, atomic import and delete preserve a profile',
    () async {
      final temporary = await Directory.systemTemp.createTemp('hybrid-backup-');
      addTearDown(() => temporary.delete(recursive: true));
      final store = SqliteTrainingStore(
        localDatabase: LocalDatabase(
          factory: databaseFactoryFfi,
          databasePath: '${temporary.path}/backup.db',
        ),
        clock: () => DateTime.utc(2026, 7, 17, 12),
      );
      addTearDown(store.close);
      await store.initialize();
      await store.createFoundation(
        FoundationProfileInput(
          displayName: 'Athlete Backup Example',
          unit: WeightUnit.kilograms,
          oneRepMaxes: const {
            MainLift.squat: 150,
            MainLift.benchPress: 100,
            MainLift.deadlift: 180,
            MainLift.overheadPress: 70,
          },
          roundingIncrement: 2.5,
          startDate: DateTime(2026, 7, 20),
          trainingDaysPerWeek: 4,
        ),
      );

      final source = await store.exportBackup();
      final document = jsonDecode(source) as Map<String, Object?>;
      expect(document['format'], BackupEnvelope.format);
      expect(
        (document['payload']! as Map<String, Object?>)['training_sessions'],
        hasLength(12),
      );
      final exportedDefinitions =
          (document['payload']! as Map<String, Object?>)['program_definitions']!
              as List<Object?>;
      expect(
        (exportedDefinitions.single! as Map<String, Object?>)['id'],
        'forever-original-fsl-v1',
      );

      await store.deleteAllData();
      expect(await store.hasProfile(), isFalse);

      final inspection = await store.importBackup(source, dryRun: true);
      expect(inspection.applied, isFalse);
      expect(inspection.issues, isEmpty);
      expect(await store.hasProfile(), isFalse);

      final imported = await store.importBackup(source, dryRun: false);
      expect(imported.applied, isTrue);
      expect(
        (await store.loadSnapshot()).displayName,
        'Athlete Backup Example',
      );
      expect(
        (await store.loadSnapshot()).activeProgram.persistentPresetId,
        'forever-original-fsl-v1',
      );
    },
  );

  test('invalid backup never replaces existing data', () async {
    final temporary = await Directory.systemTemp.createTemp('hybrid-invalid-');
    addTearDown(() => temporary.delete(recursive: true));
    final store = SqliteTrainingStore(
      localDatabase: LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${temporary.path}/invalid.db',
      ),
    );
    addTearDown(store.close);
    await store.initialize();

    final report = await store.importBackup(
      '{"format":"hybrid-training-backup","schemaVersion":999,"payload":{}}',
      dryRun: false,
    );

    expect(report.applied, isFalse);
    expect(report.issues, isNotEmpty);
    final database = await store.localDatabase.open();
    expect(await database.query('program_definitions'), isNotEmpty);
  });

  test('backup schemas v1 through v5 pass inspection and import', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'hybrid-supported-backups-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final store = SqliteTrainingStore(
      localDatabase: LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${temporary.path}/supported.db',
      ),
    );
    addTearDown(store.close);
    await store.initialize();

    final exported =
        jsonDecode(await store.exportBackup()) as Map<String, Object?>;
    final currentPayload = exported['payload']! as Map<String, Object?>;
    const tableCountsByVersion = {1: 12, 2: 21, 3: 24, 4: 28, 5: 34};

    for (final entry in tableCountsByVersion.entries) {
      final document = Map<String, Object?>.from(exported);
      document['schemaVersion'] = entry.key;
      document['payload'] = Map<String, Object?>.fromEntries(
        currentPayload.entries.take(entry.value),
      );
      final source = jsonEncode(document);

      final inspection = await store.importBackup(source, dryRun: true);
      expect(inspection.applied, isFalse, reason: 'schema v${entry.key}');
      expect(inspection.issues, isEmpty, reason: 'schema v${entry.key}');

      final imported = await store.importBackup(source, dryRun: false);
      expect(imported.applied, isTrue, reason: 'schema v${entry.key}');
      expect(imported.issues, isEmpty, reason: 'schema v${entry.key}');
    }
  });

  test(
    'structurally valid but unusable backup never replaces a profile',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'hybrid-unusable-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final store = SqliteTrainingStore(
        localDatabase: LocalDatabase(
          factory: databaseFactoryFfi,
          databasePath: '${temporary.path}/unusable.db',
        ),
      );
      addTearDown(store.close);
      await store.initialize();
      await store.createFoundation(
        FoundationProfileInput(
          displayName: 'Fictitious Preserved Athlete',
          unit: WeightUnit.kilograms,
          oneRepMaxes: const {
            MainLift.squat: 150,
            MainLift.benchPress: 100,
            MainLift.deadlift: 180,
            MainLift.overheadPress: 70,
          },
          roundingIncrement: 2.5,
          startDate: DateTime(2026, 7, 20),
          trainingDaysPerWeek: 4,
        ),
      );
      final document =
          jsonDecode(await store.exportBackup()) as Map<String, Object?>;
      final payload = document['payload']! as Map<String, Object?>;
      payload['training_cycles'] = <Object?>[];
      payload['training_sessions'] = <Object?>[];
      payload['training_sets'] = <Object?>[];

      final report = await store.importBackup(
        jsonEncode(document),
        dryRun: false,
      );

      expect(report.applied, isFalse);
      expect(report.issues, isNotEmpty);
      expect(
        (await store.loadSnapshot()).displayName,
        'Fictitious Preserved Athlete',
      );
    },
  );

  test('v1 backup imports into v2 without losing legacy history', () async {
    final temporary = await Directory.systemTemp.createTemp('hybrid-v1-');
    addTearDown(() => temporary.delete(recursive: true));
    final store = SqliteTrainingStore(
      localDatabase: LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${temporary.path}/v1.db',
      ),
      clock: () => DateTime.utc(2026, 7, 18, 12),
    );
    addTearDown(store.close);
    await store.initialize();
    await store.createFoundation(
      FoundationProfileInput(
        displayName: 'Fictitious V1 Athlete',
        unit: WeightUnit.kilograms,
        oneRepMaxes: const {
          MainLift.squat: 150,
          MainLift.benchPress: 100,
          MainLift.deadlift: 180,
          MainLift.overheadPress: 70,
        },
        roundingIncrement: 2.5,
        startDate: DateTime(2026, 7, 20),
        trainingDaysPerWeek: 4,
      ),
    );
    final document =
        jsonDecode(await store.exportBackup()) as Map<String, Object?>;
    document['schemaVersion'] = 1;
    final payload = document['payload']! as Map<String, Object?>;
    for (final table in [
      'program_definition_snapshots',
      'training_plans',
      'training_blocks',
      'plan_training_cycles',
      'plan_training_sessions',
      'session_blocks',
      'set_prescriptions',
      'set_performances',
      'plan_events',
    ]) {
      payload.remove(table);
    }

    final report = await store.importBackup(jsonEncode(document), dryRun: true);
    expect(report.applied, isFalse);
    expect(report.issues, isEmpty);
    final applied = await store.importBackup(
      jsonEncode(document),
      dryRun: false,
    );
    expect(applied.applied, isTrue);
    final snapshot = await store.loadSnapshot();
    expect(
      snapshot.activeProgram.persistentPresetId,
      'forever-original-fsl-v1',
    );
    expect(snapshot.nextSession, isNotNull);
    final db = await store.localDatabase.open();
    expect(await db.query('training_plans'), isEmpty);
    expect(await db.query('training_sessions'), hasLength(12));
  });

  test('v2 backup remains importable with empty runtime v3 tables', () async {
    final temporary = await Directory.systemTemp.createTemp('hybrid-v2-');
    addTearDown(() => temporary.delete(recursive: true));
    final store = SqliteTrainingStore(
      localDatabase: LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${temporary.path}/v2.db',
      ),
    );
    addTearDown(store.close);
    await store.initialize();
    final document =
        jsonDecode(await store.exportBackup()) as Map<String, Object?>;
    document['schemaVersion'] = 2;
    final payload = document['payload']! as Map<String, Object?>;
    for (final table in [
      'workout_runtime_sessions',
      'workout_runtime_blocks',
      'workout_activities',
    ]) {
      payload.remove(table);
    }

    final report = await store.importBackup(jsonEncode(document), dryRun: true);
    expect(report.applied, isFalse);
    expect(report.issues, isEmpty);
    final applied = await store.importBackup(
      jsonEncode(document),
      dryRun: false,
    );
    expect(applied.applied, isTrue);
    final database = await store.localDatabase.open();
    expect(await database.query('workout_runtime_sessions'), isEmpty);
    expect(await database.query('workout_runtime_blocks'), isEmpty);
    expect(await database.query('workout_activities'), isEmpty);
  });
}
