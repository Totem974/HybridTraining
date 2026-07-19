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
}
