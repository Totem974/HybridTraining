import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/canonical_plan_generator.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain_validator.dart';

void main() {
  const movements = [
    MovementId.squat,
    MovementId.benchPress,
    MovementId.deadlift,
    MovementId.overheadPress,
  ];
  final trainingMaxes = {
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

  CanonicalAthleteConfiguration athlete({
    List<int> weekdays = const [1, 2, 4, 5],
    Map<MovementId, double>? confirmed,
  }) => CanonicalAthleteConfiguration(
    movementOrder: movements,
    trainingMaxes: trainingMaxes,
    progressionIncrements: increments,
    trainingWeekdays: weekdays,
    startDate: const LocalDate(2026, 7, 20),
    unit: WeightUnit.kilograms,
    rounder: const LoadRounder(increment: 2.5),
    confirmedBeyondTrainingMaxes: confirmed,
  );

  test('Powerlifting standard creates three work weeks and typed deload', () {
    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.standardPowerlifting,
      athlete: athlete(),
    );

    expect(plan.schemaVersion, 5);
    expect(plan.sourceEdition, SourceEdition.powerlifting);
    expect(plan.generation, MethodGeneration.powerlifting);
    expect(plan.weeks, hasLength(4));
    expect(plan.weeks.expand((week) => week.sessions), hasLength(16));
    expect(plan.blocks.map((block) => block.role), [
      BlockRole.classicCycle,
      BlockRole.deload,
    ]);
    final firstSets = plan.weeks.first.sessions.first.prescriptions;
    expect(firstSets.map((set) => set.target.repetitionsPerSet), [5, 5, 5]);
    expect(firstSets.map((set) => set.calculatedLoad), [65, 75, 85]);
    expect(firstSets.last.kind, PrescriptionKind.performanceSet);
    expect(
      plan.weeks.last.sessions.first.prescriptions.map(
        (set) => set.calculatedLoad,
      ),
      [40, 50, 60],
    );
    expect(
      plan.weeks.last.sessions
          .expand((session) => session.prescriptions)
          .any((set) => set.kind == PrescriptionKind.performanceSet),
      isFalse,
    );
    expect(plan.trainingMaxTimeline, hasLength(4));
    expect(plan.awaitingTrainingMaxConfirmation, isTrue);
  });

  test(
    'explicit 3/5/1 selection switches weeks and suppresses week-two PR',
    () {
      const blueprint = CanonicalGenerationBlueprint(
        id: ProgramBlueprintId('powerlifting-351-v1'),
        version: ProgramVersion(1),
        sourceEdition: SourceEdition.powerlifting,
        generation: MethodGeneration.powerlifting,
        cycleModel: CanonicalCycleModel.alternative351,
        source: RuleReference(
          document: '5/3/1 for Powerlifting',
          location: 'PDF pages 11-12',
        ),
      );
      final plan = const CanonicalPlanGenerator().generate(
        blueprint: blueprint,
        athlete: athlete(),
      );
      expect(
        plan.weeks
            .take(3)
            .map(
              (week) => week
                  .sessions
                  .first
                  .prescriptions
                  .first
                  .target
                  .repetitionsPerSet,
            ),
        [3, 5, 5],
      );
      expect(
        plan.weeks[1].sessions
            .expand((session) => session.prescriptions)
            .any((set) => set.kind == PrescriptionKind.performanceSet),
        isFalse,
      );
    },
  );

  test('Beyond stops after cycle one until the TM decision is confirmed', () {
    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.beyondSixWeek,
      athlete: athlete(),
    );

    expect(plan.blocks, hasLength(1));
    expect(plan.blocks.single.role, BlockRole.beyondCycle);
    expect(plan.weeks, hasLength(3));
    expect(plan.trainingMaxTimeline, hasLength(4));
    expect(plan.trainingMaxTimeline.map((decision) => decision.state).toSet(), {
      TrainingMaxDecisionState.previewed,
    });
    expect(plan.awaitingTrainingMaxConfirmation, isTrue);
  });

  test('confirmed Beyond TM applies only to cycle two and then deloads', () {
    final confirmed = {
      MovementId.squat: 105.0,
      MovementId.benchPress: 82.5,
      MovementId.deadlift: 125.0,
      MovementId.overheadPress: 62.5,
    };
    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.beyondSixWeek,
      athlete: athlete(weekdays: const [1, 3, 5], confirmed: confirmed),
    );

    expect(plan.blocks.map((block) => block.role), [
      BlockRole.beyondCycle,
      BlockRole.beyondCycle,
      BlockRole.deload,
    ]);
    expect(plan.weeks, hasLength(7));
    expect(plan.weeks[0].sessions.first.prescriptions.first.unroundedLoad, 65);
    expect(
      plan.weeks[3].sessions.first.prescriptions.first.unroundedLoad,
      68.25,
    );
    expect(
      plan.trainingMaxTimeline
          .take(4)
          .every(
            (decision) => decision.state == TrainingMaxDecisionState.confirmed,
          ),
      isTrue,
    );
    expect(plan.weeks.first.sessions.map((session) => session.date.iso8601), [
      '2026-07-20',
      '2026-07-22',
      '2026-07-24',
      '2026-07-27',
    ]);
    expect(
      plan.weeks.last.sessions.last.date.compareTo(const LocalDate(2026, 9, 6)),
      greaterThan(0),
      reason: 'three-day rotation must extend beyond seven calendar weeks',
    );
  });

  test('every generated prescription has exact source and valid load data', () {
    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.standardPowerlifting,
      athlete: athlete(),
    );
    final validator = const ProgramDomainValidator();
    for (final prescription
        in plan.weeks
            .expand((week) => week.sessions)
            .expand((session) => session.prescriptions)) {
      expect(
        validator.validatePrescription(prescription).isValid,
        isTrue,
        reason: prescription.id.value,
      );
    }
  });

  test('Beyond rejects an unconfirmed or invented cycle-two TM', () {
    expect(
      () => const CanonicalPlanGenerator().generate(
        blueprint: CanonicalGenerationBlueprint.beyondSixWeek,
        athlete: athlete(
          confirmed: {
            MovementId.squat: 999,
            MovementId.benchPress: 82.5,
            MovementId.deadlift: 125,
            MovementId.overheadPress: 62.5,
          },
        ),
      ),
      throwsStateError,
    );
  });
}
