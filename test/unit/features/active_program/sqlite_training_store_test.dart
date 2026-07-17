import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_training_store.dart';
import 'package:hybrid_training/features/active_program/domain/training_store.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
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
        const FoundationProfileInput(
          displayName: 'Athlete Example',
          unit: WeightUnit.kilograms,
          roundingIncrement: 2.5,
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
      expect(generated.nextSession!.sets, hasLength(8));
      expect(generated.nextSession!.sets.first.load, 125);
      for (final set in generated.nextSession!.sets) {
        await first.completeSet(set.id, repetitions: set.repetitions);
      }
      await first.finishSession(generated.nextSession!.id);
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
      expect(restored.history, hasLength(1));
      expect(
        restored.history.single.sets.every((set) => set.isComplete),
        isTrue,
      );
      expect(restored.nextSession?.lift, MainLift.benchPress);
    },
  );
}
