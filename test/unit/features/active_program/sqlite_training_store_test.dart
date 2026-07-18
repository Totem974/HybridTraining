import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_training_store.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'profile, generated workout and history survive a database reopen',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'hybrid-training-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final path = '${temporary.path}/persistence.db';
      final now = DateTime.utc(2026, 7, 17, 8);
      final first = SqliteTrainingStore(
        localDatabase: LocalDatabase(
          factory: databaseFactoryFfi,
          databasePath: path,
        ),
        clock: () => now,
      );
      await first.initialize();
      await first.createFoundation(
        FoundationProfileInput(
          displayName: 'Athlete Example',
          unit: WeightUnit.kilograms,
          roundingIncrement: 2.5,
          startDate: DateTime(2026, 7, 20),
          trainingDaysPerWeek: 3,
          oneRepMaxes: {
            MainLift.squat: 200,
            MainLift.benchPress: 120,
            MainLift.deadlift: 220,
            MainLift.overheadPress: 80,
          },
        ),
      );
      final generated = await first.loadSnapshot();

      expect(generated.nextSession, isNotNull);
      expect(generated.nextSession!.scheduledFor, DateTime(2026, 7, 20));
      expect(generated.nextSession!.sets, hasLength(8));
      expect(generated.nextSession!.sets.first.load, 125);
      expect(generated.nextSession!.notes, isEmpty);
      expect(generated.trainingMaxes[MainLift.squat], 180);
      await first.startSession(generated.nextSession!.id);
      final restUntil = now.add(const Duration(minutes: 3));
      await first.setRestUntil(generated.nextSession!.id, restUntil);
      await first.updateSessionNotes(
        generated.nextSession!.id,
        'Séance fluide',
      );
      for (var index = 0; index < generated.nextSession!.sets.length; index++) {
        final set = generated.nextSession!.sets[index];
        await first.recordSet(
          set.id,
          repetitions: index == 0 ? 7 : set.repetitions,
          result: index == 1 ? SetResult.failure : SetResult.success,
        );
      }
      final inProgress = await first.loadSnapshot();
      expect(inProgress.nextSession!.isStarted, isTrue);
      expect(inProgress.nextSession!.restUntil, restUntil);
      expect(inProgress.nextSession!.sets.first.completedRepetitions, 7);
      expect(inProgress.nextSession!.sets[1].result, SetResult.failure);
      final database = await first.localDatabase.open();
      final records = await database.query('personal_records');
      expect(records, hasLength(1));
      expect(records.single['repetitions'], 3);
      await first.finishSession(generated.nextSession!.id);
      await database.update(
        'program_definitions',
        {
          'definition_json':
              '{"format":"hybrid-training-program","schemaVersion":1,"id":"forever-original-fsl-v1","weeks":[1,2,3]}',
        },
        where: 'id = ?',
        whereArgs: ['forever-original-fsl-v1'],
      );
      await first.updateTrainingMaxes(const {
        MainLift.squat: 180,
        MainLift.benchPress: 100,
        MainLift.deadlift: 200,
        MainLift.overheadPress: 70,
      });
      await first.close();

      final reopened = SqliteTrainingStore(
        localDatabase: LocalDatabase(
          factory: databaseFactoryFfi,
          databasePath: path,
        ),
        clock: () => now.add(const Duration(hours: 1)),
      );
      addTearDown(reopened.close);
      await reopened.initialize();
      final restored = await reopened.loadSnapshot();

      expect(restored.displayName, 'Athlete Example');
      expect(restored.activeProgram, isNotNull);
      expect(
        restored.activeProgram.templateId,
        ProgramDefinitionRef.originalFsl.templateId,
      );
      expect(restored.activeProgram.rulesetGeneration, MethodGeneration.forever);
      expect(
        restored.activeProgram.validationStatus,
        ProgramValidationStatus.rulesReviewed,
      );
      expect(restored.history, hasLength(1));
      expect(restored.history.single.notes, 'Séance fluide');
      expect(
        restored.history.single.sets.every((set) => set.isComplete),
        isTrue,
      );
      expect(restored.nextSession?.lift, MainLift.benchPress);
      expect(restored.nextSession?.scheduledFor, DateTime(2026, 7, 22));
      expect(restored.trainingMaxes[MainLift.benchPress], 100);
      expect(restored.nextSession!.sets.first.load, 70);
    },
  );

  test(
    'store rejects incomplete, missing and already completed sessions',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'hybrid-integrity-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final store = SqliteTrainingStore(
        localDatabase: LocalDatabase(
          factory: databaseFactoryFfi,
          databasePath: '${temporary.path}/integrity.db',
        ),
        clock: () => DateTime.utc(2026, 7, 18, 8),
      );
      addTearDown(store.close);
      await store.initialize();
      await store.createFoundation(
        FoundationProfileInput(
          displayName: 'Integrity Example',
          unit: WeightUnit.kilograms,
          roundingIncrement: 2.5,
          startDate: DateTime(2026, 7, 20),
          trainingDaysPerWeek: 4,
          oneRepMaxes: const {
            MainLift.squat: 200,
            MainLift.benchPress: 120,
            MainLift.deadlift: 220,
            MainLift.overheadPress: 80,
          },
        ),
      );
      final session = (await store.loadSnapshot()).nextSession!;

      await expectLater(store.finishSession(session.id), throwsStateError);
      await expectLater(
        store.finishSession('missing-session'),
        throwsStateError,
      );
      for (final set in session.sets) {
        await store.recordSet(
          set.id,
          repetitions: set.repetitions,
          result: SetResult.success,
        );
      }
      await store.finishSession(session.id);
      await expectLater(
        store.recordSet(
          session.sets.first.id,
          repetitions: 3,
          result: SetResult.success,
        ),
        throwsStateError,
      );
      await expectLater(store.finishSession(session.id), throwsStateError);
    },
  );
}
