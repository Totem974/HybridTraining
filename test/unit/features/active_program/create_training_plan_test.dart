import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/application/create_training_plan.dart';
import 'package:hybrid_training/features/active_program/data/sqlite_versioned_plan_store.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/canonical_plan_generator.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test(
    'CreateTrainingPlan persists and reopens complete Beyond v5 data',
    () async {
      final temporary = await Directory.systemTemp.createTemp(
        'create-v5-plan-',
      );
      addTearDown(() => temporary.delete(recursive: true));
      final local = LocalDatabase(
        factory: databaseFactoryFfi,
        databasePath: '${temporary.path}/plan.db',
      );
      addTearDown(local.close);
      var database = await local.open();
      const now = '2026-07-19T08:00:00.000Z';
      await database.insert('athlete_profiles', {
        'id': 'athlete-1',
        'display_name': 'Fictitious Canonical Athlete',
        'preferred_unit': 'kg',
        'rounding_increment': 2.5,
        'created_at': now,
        'updated_at': now,
      });
      final movements = [
        MovementId.squat,
        MovementId.benchPress,
        MovementId.deadlift,
        MovementId.overheadPress,
      ];
      final initial = {
        MovementId.squat: 100.0,
        MovementId.benchPress: 80.0,
        MovementId.deadlift: 120.0,
        MovementId.overheadPress: 60.0,
      };
      final increments = {
        MovementId.squat: 5.0,
        MovementId.benchPress: 2.5,
        MovementId.deadlift: 5.0,
        MovementId.overheadPress: 2.5,
      };
      final confirmed = {
        for (final movement in movements)
          movement: initial[movement]! + increments[movement]!,
      };
      final store = SqliteVersionedPlanStore(localDatabase: local);
      final plan =
          await CreateTrainingPlan(
            repository: store,
            clock: () => DateTime.utc(2026, 7, 19, 8),
          )(
            CreateTrainingPlanRequest(
              planId: 'beyond-plan-1',
              athleteId: 'athlete-1',
              presetId: 'beyond-six-week-cycle-v1',
              athlete: CanonicalAthleteConfiguration(
                movementOrder: movements,
                trainingMaxes: initial,
                progressionIncrements: increments,
                trainingWeekdays: const [1, 3, 5],
                startDate: const LocalDate(2026, 7, 20),
                unit: WeightUnit.kilograms,
                rounder: const LoadRounder(increment: 2.5),
                confirmedBeyondTrainingMaxes: confirmed,
              ),
            ),
          );

      expect(plan.blocks.map((block) => block.role), [
        BlockRole.beyondCycle.name,
        BlockRole.beyondCycle.name,
        BlockRole.deload.name,
      ]);
      await local.close();
      database = await local.open();
      expect(await database.query('training_plans'), [
        allOf(
          containsPair('source_edition', 'beyond'),
          containsPair('ruleset_generation', 'beyond'),
        ),
      ]);
      final blocks = await database.query(
        'training_blocks',
        orderBy: 'sequence',
      );
      expect(blocks.map((row) => row['ruleset_role']), [
        'beyondCycle',
        'beyondCycle',
        'deload',
      ]);
      expect(blocks.map((row) => row['block_type']), [
        'cycle',
        'cycle',
        'deload',
      ]);
      final weeks = await database.rawQuery(
        'SELECT DISTINCT programming_week_number FROM plan_training_sessions '
        'ORDER BY programming_week_number',
      );
      expect(weeks.map((row) => row['programming_week_number']), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]);
      expect(await database.query('activity_prescriptions'), hasLength(84));
      expect(await database.query('training_max_timeline'), hasLength(8));
      expect(await database.query('planned_events_v5'), hasLength(8));
      final reopened = await store.loadPlan('beyond-plan-1');
      expect(reopened, isNotNull);
      expect(reopened!['source_edition'], 'beyond');
      expect(reopened['ruleset_generation'], 'beyond');
      expect(reopened['trainingMaxTimeline'], hasLength(8));
      expect(reopened['plannedEvents'], hasLength(8));
      final reopenedBlocks = reopened['blocks']! as List<Map<String, Object?>>;
      final reopenedActivities = reopenedBlocks
          .expand(
            (block) => (block['cycles']! as List<Map<String, Object?>>).expand(
              (cycle) =>
                  (cycle['sessions']! as List<Map<String, Object?>>).expand(
                    (session) =>
                        (session['blocks']! as List<Map<String, Object?>>)
                            .expand(
                              (sessionBlock) =>
                                  sessionBlock['activities']!
                                      as List<Map<String, Object?>>,
                            ),
                  ),
            ),
          )
          .toList();
      expect(reopenedActivities, hasLength(84));
      expect(reopenedActivities.first['target'], isA<Map<String, Object?>>());
      final cycleTwo = await database.rawQuery(
        '''SELECT target_json, calculated_load FROM activity_prescriptions
         WHERE id = ?''',
        ['beyond-plan-1-session-13:set-1'],
      );
      expect(cycleTwo.single['calculated_load'], 67.5);
    },
  );
}
