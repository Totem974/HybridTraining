import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/core_validation/data/sqlite_core_validation_repository.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/training_max/data/sqlite_tm_adjustment_store.dart';
import 'package:hybrid_training/features/training_max/domain/tm_adjustment_decision.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late SqliteTmAdjustmentStore store;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('tm-adjustment-');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temporary.path}/tm.db',
    );
    await SqliteCoreValidationRepository(
      localDatabase: local,
      clock: () => DateTime.utc(2026, 7, 20),
    ).createDevelopmentFixture();
    store = SqliteTmAdjustmentStore(localDatabase: local);
  });

  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });

  test(
    'applies decision and provenance atomically without rewriting history',
    () async {
      final decision = TmAdjustmentDecision.progress(
        movement: MainLift.squat,
        previousTrainingMax: 100,
        requestedIncrease: 5,
        unit: WeightUnit.kilograms,
        reason: 'Completed reviewed cycle',
      );
      await store.apply(
        id: 'tm-adjustment-1',
        planId: 'dev-bps-plan-1',
        athleteId: 'dev-core-athlete',
        unit: 'kg',
        decision: decision,
        effectiveAt: DateTime.utc(2026, 8, 10),
      );
      final database = await local.open();
      final history = await database.query(
        'training_max_history',
        where: "exercise_id = 'squat'",
        orderBy: 'effective_at',
      );
      expect(history.map((row) => row['training_max']), [100.0, 105.0]);
      final event = (await database.query('plan_events')).single;
      expect(event['event_type'], 'tmAdjustment');
      expect(event['rule_provenance_json'], contains('TM-PROG-001'));
    },
  );

  test('stale preview rolls back both history and event', () async {
    final stale = TmAdjustmentDecision.progress(
      movement: MainLift.squat,
      previousTrainingMax: 95,
      requestedIncrease: 5,
      unit: WeightUnit.kilograms,
      reason: 'Stale preview',
    );
    await expectLater(
      store.apply(
        id: 'stale',
        planId: 'dev-bps-plan-1',
        athleteId: 'dev-core-athlete',
        unit: 'kg',
        decision: stale,
        effectiveAt: DateTime.utc(2026, 8, 10),
      ),
      throwsStateError,
    );
    final database = await local.open();
    expect(await database.query('plan_events'), isEmpty);
    expect(
      await database.query(
        'training_max_history',
        where: "exercise_id = 'squat'",
      ),
      hasLength(1),
    );
  });

  test(
    'selects latest instant when imported ISO dates use mixed offsets',
    () async {
      final database = await local.open();
      await database.insert('training_max_history', {
        'id': 'mixed-offset-actual-latest',
        'athlete_id': 'dev-core-athlete',
        'exercise_id': 'squat',
        'one_rep_max': 130.0,
        'training_max': 110.0,
        'unit': 'kg',
        'effective_at': '2026-07-20T23:30:00-10:00',
      });
      await database.insert('training_max_history', {
        'id': 'mixed-offset-text-latest',
        'athlete_id': 'dev-core-athlete',
        'exercise_id': 'squat',
        'one_rep_max': 125.0,
        'training_max': 105.0,
        'unit': 'kg',
        'effective_at': '2026-07-21T08:00:00Z',
      });
      final decision = TmAdjustmentDecision.progress(
        movement: MainLift.squat,
        previousTrainingMax: 110,
        requestedIncrease: 5,
        unit: WeightUnit.kilograms,
        reason: 'Completed reviewed cycle',
      );

      await store.apply(
        id: 'tm-adjustment-mixed-offset',
        planId: 'dev-bps-plan-1',
        athleteId: 'dev-core-athlete',
        unit: 'kg',
        decision: decision,
        effectiveAt: DateTime.utc(2026, 7, 21, 10),
      );

      expect(
        (await database.query(
          'training_max_history',
          where: "exercise_id = 'squat'",
        )).map((row) => row['training_max']),
        containsAll(<double>[100, 105, 110, 115]),
      );
      expect(await database.query('plan_events'), hasLength(1));
    },
  );

  test('invalid imported effective date aborts without writing', () async {
    final database = await local.open();
    await database.insert('training_max_history', {
      'id': 'invalid-effective-date',
      'athlete_id': 'dev-core-athlete',
      'exercise_id': 'squat',
      'one_rep_max': 125.0,
      'training_max': 105.0,
      'unit': 'kg',
      'effective_at': 'not-an-instant',
    });
    final decision = TmAdjustmentDecision.progress(
      movement: MainLift.squat,
      previousTrainingMax: 105,
      requestedIncrease: 5,
      unit: WeightUnit.kilograms,
      reason: 'Completed reviewed cycle',
    );

    await expectLater(
      store.apply(
        id: 'tm-adjustment-invalid-date',
        planId: 'dev-bps-plan-1',
        athleteId: 'dev-core-athlete',
        unit: 'kg',
        decision: decision,
        effectiveAt: DateTime.utc(2026, 7, 22),
      ),
      throwsStateError,
    );

    expect(await database.query('plan_events'), isEmpty);
    expect(
      await database.query(
        'training_max_history',
        where: "exercise_id = 'squat'",
      ),
      hasLength(2),
    );
  });

  test('equivalent imported instants abort ambiguous history', () async {
    final database = await local.open();
    for (final row in [
      ('ambiguous-z', 105.0, '2026-07-21T08:00:00Z'),
      ('ambiguous-offset', 110.0, '2026-07-21T10:00:00+02:00'),
    ]) {
      await database.insert('training_max_history', {
        'id': row.$1,
        'athlete_id': 'dev-core-athlete',
        'exercise_id': 'squat',
        'one_rep_max': 130.0,
        'training_max': row.$2,
        'unit': 'kg',
        'effective_at': row.$3,
      });
    }
    final decision = TmAdjustmentDecision.progress(
      movement: MainLift.squat,
      previousTrainingMax: 110,
      requestedIncrease: 5,
      unit: WeightUnit.kilograms,
      reason: 'Completed reviewed cycle',
    );

    await expectLater(
      store.apply(
        id: 'tm-adjustment-ambiguous-date',
        planId: 'dev-bps-plan-1',
        athleteId: 'dev-core-athlete',
        unit: 'kg',
        decision: decision,
        effectiveAt: DateTime.utc(2026, 7, 22),
      ),
      throwsStateError,
    );

    expect(await database.query('plan_events'), isEmpty);
    expect(
      await database.query(
        'training_max_history',
        where: "exercise_id = 'squat'",
      ),
      hasLength(3),
    );
  });

  for (final chronology in <String, DateTime>{
    'earlier': DateTime.utc(2026, 7, 19),
    'equal': DateTime.utc(2026, 7, 20),
  }.entries) {
    test(
      '${chronology.key} effective date rolls back both history and event',
      () async {
        final decision = TmAdjustmentDecision.progress(
          movement: MainLift.squat,
          previousTrainingMax: 100,
          requestedIncrease: 5,
          unit: WeightUnit.kilograms,
          reason: 'Completed reviewed cycle',
        );

        await expectLater(
          store.apply(
            id: 'tm-adjustment-${chronology.key}',
            planId: 'dev-bps-plan-1',
            athleteId: 'dev-core-athlete',
            unit: 'kg',
            decision: decision,
            effectiveAt: chronology.value,
          ),
          throwsStateError,
        );

        final database = await local.open();
        expect(await database.query('plan_events'), isEmpty);
        expect(
          await database.query(
            'training_max_history',
            where: "exercise_id = 'squat'",
          ),
          hasLength(1),
        );
      },
    );
  }
}
