import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_versioned_plan_store.dart';
import 'package:hybrid_training/features/active_program/domain/versioned_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporary;
  late LocalDatabase local;
  late SqliteVersionedPlanStore store;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('versioned-plan-');
    local = LocalDatabase(
      factory: databaseFactoryFfi,
      databasePath: '${temporary.path}/plan.db',
    );
    store = SqliteVersionedPlanStore(localDatabase: local);
    final db = await local.open();
    await db.insert('athlete_profiles', {
      'id': 'athlete',
      'display_name': 'Fictitious Athlete',
      'preferred_unit': 'kg',
      'rounding_increment': 2.5,
      'created_at': '2026-07-18T00:00:00Z',
      'updated_at': '2026-07-18T00:00:00Z',
    });
  });
  tearDown(() async {
    await local.close();
    await temporary.delete(recursive: true);
  });

  test('atomically persists snapshot, multiple blocks and movements', () async {
    await store.createPlan(_plan());
    final db = await local.open();
    expect(await db.query('training_blocks'), hasLength(2));
    expect(await db.query('session_blocks'), hasLength(2));
    expect(await db.query('set_prescriptions'), hasLength(2));
    expect(
      (await db.query('set_prescriptions')).map((row) => row['training_max']),
      containsAll([150.0, 100.0]),
    );
    await store.recordPerformance(
      id: 'performance-1',
      prescriptionId: 'squat-block-set',
      result: 'success',
      completedReps: 5,
      actualLoad: 97.5,
      notes: 'Fictitious result',
      recordedAt: DateTime.utc(2026, 7, 20),
    );

    await local.close();
    final reloaded = await store.loadPlan('plan-1');
    expect(reloaded?['blueprint_id'], 'forever-original-fsl-v1');
    expect(reloaded?['blocks'], hasLength(2));
    final blocks = reloaded?['blocks']! as List<Map<String, Object?>>;
    final cycles = blocks.first['cycles']! as List<Map<String, Object?>>;
    final sessions = cycles.first['sessions']! as List<Map<String, Object?>>;
    final sessionBlocks =
        sessions.first['blocks']! as List<Map<String, Object?>>;
    final prescriptions =
        sessionBlocks.first['prescriptions']! as List<Map<String, Object?>>;
    expect(prescriptions.single['training_max'], 150.0);
    expect(
      (prescriptions.single['performance']! as Map<String, Object?>)['notes'],
      'Fictitious result',
    );
  });

  test('duplicate aggregate rolls back without partial rows', () async {
    final invalid = _plan(duplicateSessionBlockSequence: true);
    await expectLater(store.createPlan(invalid), throwsArgumentError);
    final db = await local.open();
    expect(await db.query('training_plans'), isEmpty);
    expect(await db.query('set_prescriptions'), isEmpty);
  });

  test('snapshot is immutable for a blueprint version', () async {
    await store.createPlan(_plan());
    await expectLater(
      store.createPlan(_plan(id: 'plan-2', snapshot: {'id': 'changed'})),
      throwsStateError,
    );
    final db = await local.open();
    expect(await db.query('training_plans'), hasLength(1));
  });

  test('block transition and confirmed TM event are atomic', () async {
    await store.createPlan(_plan());
    await expectLater(
      store.transitionBlock(
        eventId: 'bad',
        planId: 'plan-1',
        fromBlockId: 'missing',
        toBlockId: 'anchor',
        eventSequence: 0,
        proposedTrainingMaxes: const {'squat': 155},
        confirmedTrainingMaxes: const {'squat': 155},
        ruleProvenance: const {'policy': 'tm-v1'},
        occurredAt: DateTime.utc(2026, 8, 1),
      ),
      throwsStateError,
    );
    var db = await local.open();
    expect(await db.query('plan_events'), isEmpty);
    expect(
      (await db.query(
        'training_blocks',
        where: "id = 'anchor'",
      )).single['status'],
      'planned',
    );

    await store.transitionBlock(
      eventId: 'transition-1',
      planId: 'plan-1',
      fromBlockId: 'leader',
      toBlockId: 'anchor',
      eventSequence: 0,
      proposedTrainingMaxes: const {'squat': 155},
      confirmedTrainingMaxes: const {'squat': 155},
      ruleProvenance: const {'policy': 'tm-v1'},
      occurredAt: DateTime.utc(2026, 8, 1),
    );
    db = await local.open();
    expect(await db.query('plan_events'), hasLength(1));
  });

  test('adapts and persists the generated G1 aggregate', () async {
    const rule = RuleReference(
      document: 'verified-fixture',
      location: 'line-1',
    );
    final generated = GeneratedTrainingPlan(
      schemaVersion: 1,
      blueprintId: const ProgramBlueprintId('forever-original-fsl-v1'),
      blueprintVersion: const ProgramVersion(1),
      blueprintSnapshot: '{"id":"forever-original-fsl-v1","version":1}',
      unit: WeightUnit.kilograms,
      seed: 42,
      blocks: [
        GeneratedPlanBlock(
          id: 'leader-template',
          role: BlockRole.leader,
          rule: rule,
          cycles: [
            GeneratedCycle(
              number: 1,
              weeks: [
                GeneratedProgrammingWeek(
                  number: 1,
                  sessions: [
                    GeneratedSession(
                      id: 'session-1',
                      date: const LocalDate(2026, 7, 20),
                      blocks: [
                        GeneratedSessionBlock(
                          kind: GeneratedSessionBlockKind.mainWork,
                          prescriptions: const [
                            GeneratedPrescription(
                              movement: MainLift.squat,
                              setKind: SetKind.main,
                              percentage: 0.65,
                              repetitions: 5,
                              trainingMax: 150,
                              unroundedLoad: 97.5,
                              load: 97.5,
                              roundingIncrement: 2.5,
                              rule: rule,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
      transitions: const [],
      events: const [],
    );
    final plan = VersionedTrainingPlan.fromGenerated(
      id: 'generated-plan',
      athleteId: 'athlete',
      macrocycle: 1,
      createdAt: DateTime.utc(2026, 7, 18),
      generated: generated,
    );

    await store.createPlan(plan);

    final reloaded = await store.loadPlan('generated-plan');
    expect(reloaded?['blueprint_id'], 'forever-original-fsl-v1');
    final blocks = reloaded?['blocks']! as List<Map<String, Object?>>;
    final cycles = blocks.single['cycles']! as List<Map<String, Object?>>;
    final sessions = cycles.single['sessions']! as List<Map<String, Object?>>;
    expect(sessions.single['scheduled_for'], '2026-07-20');
  });
}

VersionedTrainingPlan _plan({
  String id = 'plan-1',
  Map<String, Object?> snapshot = const {
    'id': 'forever-original-fsl-v1',
    'version': 1,
  },
  bool duplicateSessionBlockSequence = false,
}) => VersionedTrainingPlan(
  id: id,
  athleteId: 'athlete',
  blueprintId: 'forever-original-fsl-v1',
  blueprintVersion: 1,
  blueprintSnapshot: snapshot,
  ruleProvenance: const [
    {'document': 'verified-fixture', 'status': 'verified'},
  ],
  macrocycle: 1,
  createdAt: DateTime.utc(2026, 7, 18),
  blocks: [
    PlannedTrainingBlock(
      id: 'leader',
      sequence: 0,
      role: 'leader',
      templateId: 'leader-template',
      cycles: [
        PlannedCycle(
          id: 'cycle-1',
          sequence: 0,
          startsOn: DateTime(2026, 7, 20),
          sessions: [
            PlannedSession(
              id: 'session-1',
              sequence: 0,
              scheduledFor: DateTime(2026, 7, 20),
              blocks: [
                _sessionBlock('squat-block', 0, 'squat', 150),
                _sessionBlock(
                  'bench-block',
                  duplicateSessionBlockSequence ? 0 : 1,
                  'benchPress',
                  100,
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    const PlannedTrainingBlock(
      id: 'anchor',
      sequence: 1,
      role: 'anchor',
      templateId: 'anchor-template',
      cycles: [],
    ),
  ],
);

PlannedSessionBlock _sessionBlock(
  String id,
  int sequence,
  String movement,
  double trainingMax,
) => PlannedSessionBlock(
  id: id,
  sequence: sequence,
  kind: 'mainWork',
  movementId: movement,
  ruleProvenance: const {'policy': 'main-v1'},
  prescriptions: [
    PlannedSetPrescription(
      id: '$id-set',
      sequence: 0,
      trainingMax: trainingMax,
      percentage: 0.65,
      unroundedLoad: trainingMax * 0.65,
      roundingIncrement: 2.5,
      prescribedLoad: trainingMax * 0.65,
      prescribedReps: 5,
      details: const {'kind': 'work'},
      ruleProvenance: const {'policy': 'main-v1'},
    ),
  ],
);
