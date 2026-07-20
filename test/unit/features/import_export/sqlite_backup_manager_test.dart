import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_versioned_plan_store.dart';
import 'package:hybrid_training/features/active_program/domain/versioned_training_plan.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_training_store.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/import_export/domain/backup_envelope.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/beginner_prep_school_blueprint.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/forever_macrocycle_generator.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
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

  test('v1 backup imports into v5 without losing legacy history', () async {
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

  test(
    'v5 import rejects unsourced executable rules before changing the database',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'hybrid-unsourced-v5-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final store = SqliteTrainingStore(
        localDatabase: LocalDatabase(
          factory: databaseFactoryFfi,
          databasePath: '${temporary.path}/unsourced.db',
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
      final clean =
          jsonDecode(await store.exportBackup()) as Map<String, Object?>;
      final payload = clean['payload']! as Map<String, Object?>;
      _injectExecutablePlan(payload);
      final originalDefinitions = await (await store.localDatabase.open())
          .query('program_definitions');

      for (final invalidProvenance in [
        jsonEncode({'document': 'NEEDS_REVIEW', 'location': 'NEEDS_REVIEW'}),
        jsonEncode(<String, Object?>{}),
        '{corrupt-json',
      ]) {
        final document = jsonDecode(jsonEncode(clean)) as Map<String, Object?>;
        final candidatePayload = document['payload']! as Map<String, Object?>;
        final blocks = candidatePayload['session_blocks']! as List<Object?>;
        (blocks.single! as Map<String, Object?>)['rule_provenance_json'] =
            invalidProvenance;
        final source = jsonEncode(document);

        final simulation = await store.importBackup(source, dryRun: true);
        expect(simulation.applied, isFalse);
        expect(
          simulation.issues.map((issue) => issue.message).join('\n'),
          contains('source provenance'),
        );

        final apply = await store.importBackup(source, dryRun: false);
        expect(apply.applied, isFalse);
        expect(
          (await store.loadSnapshot()).displayName,
          'Fictitious Preserved Athlete',
        );
        expect(
          await (await store.localDatabase.open()).query('program_definitions'),
          originalDefinitions,
        );
      }

      Map<String, Object?> copy() =>
          jsonDecode(jsonEncode(clean)) as Map<String, Object?>;
      Future<String> inspectMessages(Map<String, Object?> document) async =>
          (await store.importBackup(
            jsonEncode(document),
            dryRun: true,
          )).issues.map((issue) => issue.message).join('\n');

      for (final canonicalDocument in const [
        '5/3/1 Original — Second Edition',
        '5/3/1 — Second Edition',
        '5/3/1 for Powerlifting',
        '5/3/1 Forever',
        'Beyond 5/3/1',
        'Core v5 reviewed historical compatibility contract',
        'forever-original-fsl-v1',
        'forever-program-catalog.md',
      ]) {
        final generatedRoundTrip = copy();
        final generatedPayload =
            generatedRoundTrip['payload']! as Map<String, Object?>;
        ((generatedPayload['session_blocks']! as List<Object?>).single!
            as Map<String, Object?>)['rule_provenance_json'] = jsonEncode({
          'document': canonicalDocument,
          'location': 'reviewed generator reference',
        });
        expect(
          await inspectMessages(generatedRoundTrip),
          isNot(contains('source provenance')),
          reason: canonicalDocument,
        );
      }

      final downgraded = copy()..['schemaVersion'] = 4;
      final downgradedPayload = downgraded['payload']! as Map<String, Object?>;
      ((downgradedPayload['session_blocks']! as List<Object?>).single!
          as Map<String, Object?>)['rule_provenance_json'] = jsonEncode({
        'document': 'NEEDS_REVIEW',
        'location': 'NEEDS_REVIEW',
      });
      expect(await inspectMessages(downgraded), contains('source provenance'));

      final planned = copy();
      final plannedPayload = planned['payload']! as Map<String, Object?>;
      ((plannedPayload['training_plans']! as List<Object?>).single!
              as Map<String, Object?>)['status'] =
          'planned';
      ((plannedPayload['plan_training_sessions']! as List<Object?>).single!
              as Map<String, Object?>)['status'] =
          'planned';
      ((plannedPayload['session_blocks']! as List<Object?>).single!
          as Map<String, Object?>)['rule_provenance_json'] = jsonEncode({
        'document': 'NEEDS_REVIEW',
        'location': 'NEEDS_REVIEW',
      });
      expect(await inspectMessages(planned), contains('source provenance'));

      final historical = copy();
      final historicalPayload = historical['payload']! as Map<String, Object?>;
      ((historicalPayload['plan_training_sessions']! as List<Object?>).single!
              as Map<String, Object?>)['status'] =
          'complete';
      ((historicalPayload['session_blocks']! as List<Object?>).single!
          as Map<String, Object?>)['rule_provenance_json'] = jsonEncode({
        'document': 'NEEDS_REVIEW',
        'location': 'NEEDS_REVIEW',
      });
      expect(
        await inspectMessages(historical),
        isNot(contains('source provenance')),
      );

      final activity = copy();
      final activityPayload = activity['payload']! as Map<String, Object?>;
      (activityPayload['activity_prescriptions']! as List<Object?>).add({
        'id': 'import-activity',
        'session_block_id': 'import-session-block',
        'sequence': 0,
        'movement_or_activity_id': 'jump',
        'target_type': 'qualitative',
        'target_json': '{"goal":"NEEDS_REVIEW"}',
        'prescription_kind': 'athletic',
        'rule_id': 'BPS-JUMP-001',
        'source_edition': 'forever',
        'ruleset_generation': 'forever',
        'source_reference_json':
            '{"document":"5/3/1 Forever","location":"PDF page 50"}',
      });
      expect(await inspectMessages(activity), contains('source provenance'));

      final event = copy();
      final eventPayload = event['payload']! as Map<String, Object?>;
      (eventPayload['planned_events_v5']! as List<Object?>).add({
        'id': 'import-event',
        'plan_id': 'import-plan',
        'sequence': 0,
        'event_type': 'trainingMaxTest',
        'payload_json': '{"rule":"NEEDS_REVIEW"}',
        'rule_id': 'TM-PROG-001',
        'source_reference_json':
            '{"document":"5/3/1 Forever","location":"PDF pages 50-51"}',
      });
      expect(await inspectMessages(event), contains('source provenance'));
    },
  );

  test('v4 migrated plan round-trips in an explicit safe quarantine', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'hybrid-migrated-v4-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final store = SqliteTrainingStore(
      localDatabase: LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${temporary.path}/migrated-v4.db',
      ),
    );
    addTearDown(store.close);
    await store.initialize();
    await store.createFoundation(
      FoundationProfileInput(
        displayName: 'Fictitious Migrated Athlete',
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
    _injectExecutablePlan(payload);
    document['schemaVersion'] = 4;
    final plan =
        (payload['training_plans']! as List<Object?>).single!
            as Map<String, Object?>;
    plan.remove('source_edition');
    plan.remove('ruleset_generation');

    final simulation = await store.importBackup(
      jsonEncode(document),
      dryRun: true,
    );
    expect(simulation.applied, isFalse);
    expect(
      simulation.issues.map((issue) => issue.message).join('\n'),
      contains('preserved in quarantine'),
    );
    expect(
      simulation.issues.where((issue) => issue.severity.name == 'error'),
      isEmpty,
    );

    final imported = await store.importBackup(
      jsonEncode(document),
      dryRun: false,
    );
    expect(imported.applied, isTrue);
    final database = await store.localDatabase.open();
    expect(
      (await database.query(
        'training_plans',
        where: 'id = ?',
        whereArgs: ['import-plan'],
      )).single['status'],
      'cancelled',
    );
    expect(
      (await database.query(
        'plan_training_sessions',
        where: 'id = ?',
        whereArgs: ['import-session'],
      )).single['status'],
      'cancelled',
    );
  });

  test('Forever TM planned event survives a real backup round-trip', () async {
    final temporary = await Directory.systemTemp.createTemp(
      'hybrid-forever-tm-roundtrip-',
    );
    addTearDown(() => temporary.delete(recursive: true));
    final local = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temporary.path}/forever-tm.db',
    );
    final trainingStore = SqliteTrainingStore(localDatabase: local);
    addTearDown(trainingStore.close);
    await trainingStore.initialize();
    await trainingStore.createFoundation(
      FoundationProfileInput(
        displayName: 'Fictitious Forever Athlete',
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
    final database = await local.open();
    final athleteId =
        (await database.query('athlete_profiles')).single['id']! as String;
    final generated = const ForeverMacrocycleGenerator().generate(
      snapshot: BeginnerPrepSchoolBlueprint.create(
        trainingMaxRatios: const {
          MainLift.squat: .85,
          MainLift.benchPress: .90,
          MainLift.deadlift: .85,
          MainLift.overheadPress: .90,
        },
      ),
      athlete: AthletePlanConfiguration(
        trainingMaxes: const {
          MainLift.squat: 100,
          MainLift.benchPress: 75,
          MainLift.deadlift: 120,
          MainLift.overheadPress: 50,
        },
        unit: WeightUnit.kilograms,
        trainingWeekdays: const [1, 3, 5],
        startDate: const LocalDate(2026, 7, 20),
        rounder: const LoadRounder(increment: 2.5),
      ),
    );
    await SqliteVersionedPlanStore(localDatabase: local).createPlan(
      VersionedTrainingPlan.fromGenerated(
        id: 'forever-tm-plan',
        athleteId: athleteId,
        macrocycle: 1,
        createdAt: DateTime.utc(2026, 7, 18),
        generated: generated,
      ),
    );
    final exported = await trainingStore.exportBackup();
    final exportedDocument = jsonDecode(exported) as Map<String, Object?>;
    final exportedPayload =
        exportedDocument['payload']! as Map<String, Object?>;
    final exportedEvents =
        exportedPayload['planned_events_v5']! as List<Object?>;
    expect(exportedEvents, isNotEmpty);
    expect(
      jsonDecode(
        (exportedEvents.first!
                as Map<String, Object?>)['source_reference_json']!
            as String,
      ),
      containsPair('document', 'TM-PROG-001'),
    );

    await trainingStore.deleteAllData();
    final imported = await trainingStore.importBackup(exported, dryRun: false);
    expect(imported.applied, isTrue);
    expect(
      imported.issues.where((issue) => issue.severity.name == 'error'),
      isEmpty,
    );
    final restoredEvents = await database.query(
      'planned_events_v5',
      where: 'plan_id = ?',
      whereArgs: ['forever-tm-plan'],
    );
    expect(restoredEvents, hasLength(exportedEvents.length));
    expect(
      jsonDecode(restoredEvents.first['source_reference_json']! as String),
      containsPair('document', 'TM-PROG-001'),
    );
  });
}

void _injectExecutablePlan(Map<String, Object?> payload) {
  final athleteId =
      ((payload['athlete_profiles']! as List<Object?>).single!
          as Map<String, Object?>)['id'];
  const source = '{"document":"5/3/1 Forever","location":"PDF pages 29-33"}';
  (payload['program_definition_snapshots']! as List<Object?>).add({
    'id': 'import-snapshot',
    'blueprint_id': 'import-blueprint',
    'blueprint_version': 1,
    'snapshot_json': '{"schemaVersion":5}',
    'rule_provenance_json': '[$source]',
    'created_at': '2026-07-20T00:00:00.000Z',
  });
  (payload['training_plans']! as List<Object?>).add({
    'id': 'import-plan',
    'athlete_id': athleteId,
    'blueprint_id': 'import-blueprint',
    'blueprint_version': 1,
    'definition_snapshot_id': 'import-snapshot',
    'macrocycle': 1,
    'status': 'active',
    'created_at': '2026-07-20T00:00:00.000Z',
    'source_edition': 'forever',
    'ruleset_generation': 'forever',
  });
  (payload['training_blocks']! as List<Object?>).add({
    'id': 'import-block',
    'plan_id': 'import-plan',
    'sequence': 0,
    'role': 'leader',
    'template_id': 'import-template',
    'status': 'active',
  });
  (payload['plan_training_cycles']! as List<Object?>).add({
    'id': 'import-cycle',
    'block_id': 'import-block',
    'sequence': 0,
    'starts_on': '2026-07-20',
    'status': 'active',
  });
  (payload['plan_training_sessions']! as List<Object?>).add({
    'id': 'import-session',
    'cycle_id': 'import-cycle',
    'sequence': 0,
    'scheduled_for': '2026-07-20',
    'status': 'started',
  });
  (payload['session_blocks']! as List<Object?>).add({
    'id': 'import-session-block',
    'session_id': 'import-session',
    'sequence': 0,
    'kind': 'mainWork',
    'movement_id': 'barbell.back-squat',
    'rule_provenance_json': source,
  });
  (payload['set_prescriptions']! as List<Object?>).add({
    'id': 'import-prescription',
    'session_block_id': 'import-session-block',
    'sequence': 0,
    'training_max': 100.0,
    'percentage': 0.65,
    'unrounded_load': 65.0,
    'rounding_increment': 2.5,
    'prescribed_load': 65.0,
    'prescribed_reps': 5,
    'prescription_json': '{"repetitions":5}',
    'rule_provenance_json': source,
  });
}
