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
}
