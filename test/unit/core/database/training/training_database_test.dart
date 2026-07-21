import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/training/training_database.dart';
import 'package:hybrid_training/core/database/training/training_database_schema.dart';
import 'package:hybrid_training/core/database/training/training_plan_snapshot_repository.dart';
import 'package:hybrid_training/core/database/training/training_plan_status_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late TrainingDatabase database;
  setUp(() async {
    database = await TrainingDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
      options: OpenDatabaseOptions(
        version: TrainingDatabaseSchema.version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: (db, version) => TrainingDatabaseSchema.create(db),
        singleInstance: false,
      ),
    );
  });
  tearDown(() => database.close());

  test(
    'structured writes accept only canonical allowlisted table names',
    () async {
      final attempts = <Future<int> Function()>[
        () => database.insert('main.plans', const {'id': 'bypass'}),
        () => database.update('"plans"', const {'status': 'active'}),
        () => database.delete(' plans '),
        () => database.insert('plans AS p', const {'id': 'bypass'}),
      ];

      for (final attempt in attempts) {
        await expectLater(
          attempt(),
          throwsA(
            isA<TrainingSnapshotWriteException>().having(
              (error) => error.code,
              'code',
              'database.table_write_forbidden',
            ),
          ),
        );
      }
      expect(await database.query('plans'), isEmpty);
    },
  );

  test('exact plans identifier remains reserved for createPlan', () async {
    await expectLater(
      database.insert('plans', const {'id': 'bypass'}),
      throwsA(
        isA<TrainingSnapshotWriteException>().having(
          (error) => error.code,
          'code',
          'snapshot.direct_write_forbidden',
        ),
      ),
    );
  });

  test('canonical runtime table names remain writable', () async {
    await _createPlan(database, status: TrainingPlanStatus.scheduled);

    await database.insert('sessions', const {
      'id': 'session-1',
      'plan_id': 'plan-1',
      'sequence': 0,
      'scheduled_for': '2026-07-21',
      'status': 'scheduled',
    });

    expect(await database.query('sessions'), hasLength(1));
  });

  const allowed = <TrainingPlanStatus, Set<TrainingPlanStatus>>{
    TrainingPlanStatus.draft: {
      TrainingPlanStatus.scheduled,
      TrainingPlanStatus.cancelled,
    },
    TrainingPlanStatus.scheduled: {
      TrainingPlanStatus.active,
      TrainingPlanStatus.cancelled,
    },
    TrainingPlanStatus.active: {
      TrainingPlanStatus.completed,
      TrainingPlanStatus.cancelled,
    },
  };
  for (final from in TrainingPlanStatus.values) {
    for (final to in TrainingPlanStatus.values) {
      test('plan status ${from.name} -> ${to.name}', () async {
        await _createPlan(database, status: from);
        final before = (await database.query('plans')).single;
        if (allowed[from]?.contains(to) ?? false) {
          await database.transitionPlanStatus(planId: 'plan-1', to: to);
          final after = (await database.query('plans')).single;
          expect(after['status'], to.name);
          expect(
            Map<String, Object?>.of(after)..remove('status'),
            Map<String, Object?>.of(before)..remove('status'),
          );
        } else {
          await expectLater(
            database.transitionPlanStatus(planId: 'plan-1', to: to),
            throwsA(
              isA<TrainingPlanTransitionException>().having(
                (error) => error.code,
                'code',
                'plan.invalid_status_transition',
              ),
            ),
          );
          expect((await database.query('plans')).single['status'], from.name);
        }
      });
    }
  }

  test('status transition rejects an unknown plan', () async {
    await expectLater(
      database.transitionPlanStatus(
        planId: 'missing',
        to: TrainingPlanStatus.cancelled,
      ),
      throwsA(
        isA<TrainingPlanTransitionException>().having(
          (error) => error.code,
          'code',
          'plan.not_found',
        ),
      ),
    );
  });
}

Future<void> _createPlan(
  TrainingDatabase database, {
  required TrainingPlanStatus status,
}) async {
  const snapshotJson =
      '{"schemaVersion":1,"catalogVersionId":"catalog-v1",'
      '"catalogContentHash":"catalog-hash",'
      '"template":{"id":"standard","revision":1},'
      '"schedule":{"sessions":[{"id":"session-1","sequence":0,'
      '"offsetDays":0,"blocks":[{"id":"block-1","sequence":0,'
      '"kind":"main"}]}]}}';
  await database.createPlan(
    TrainingPlanSnapshotWrite(
      id: 'plan-1',
      athleteId: 'athlete-1',
      catalogVersionId: 'catalog-v1',
      catalogContentHash: 'catalog-hash',
      snapshotSchemaVersion: 1,
      snapshotCanonicalizationVersion: 1,
      snapshotHashAlgorithm: 'sha256',
      resolvedSnapshotHash: TrainingSnapshotIntegrity.hash(snapshotJson),
      resolvedSnapshotJson: snapshotJson,
      startsOn: '2026-07-21',
      status: TrainingPlanStatus.draft.name,
      createdAt: '2026-07-21T00:00:00Z',
    ),
  );
  switch (status) {
    case TrainingPlanStatus.draft:
      return;
    case TrainingPlanStatus.scheduled:
      await database.transitionPlanStatus(
        planId: 'plan-1',
        to: TrainingPlanStatus.scheduled,
      );
    case TrainingPlanStatus.active:
      await database.transitionPlanStatus(
        planId: 'plan-1',
        to: TrainingPlanStatus.scheduled,
      );
      await database.transitionPlanStatus(
        planId: 'plan-1',
        to: TrainingPlanStatus.active,
      );
    case TrainingPlanStatus.completed:
      await database.transitionPlanStatus(
        planId: 'plan-1',
        to: TrainingPlanStatus.scheduled,
      );
      await database.transitionPlanStatus(
        planId: 'plan-1',
        to: TrainingPlanStatus.active,
      );
      await database.transitionPlanStatus(
        planId: 'plan-1',
        to: TrainingPlanStatus.completed,
      );
    case TrainingPlanStatus.cancelled:
      await database.transitionPlanStatus(
        planId: 'plan-1',
        to: TrainingPlanStatus.cancelled,
      );
  }
}
