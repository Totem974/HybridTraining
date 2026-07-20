import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/canonical_plan_generator.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain_validator.dart';
import 'package:hybrid_training/features/poc_531/domain/planning/planning.dart'
    as planning;

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
    Map<int, Map<MovementId, double>> foreverConfirmations = const {},
    Map<String, Map<MovementId, double>> nodeConfirmations = const {},
  }) => CanonicalAthleteConfiguration(
    movementOrder: movements,
    trainingMaxes: trainingMaxes,
    progressionIncrements: increments,
    trainingWeekdays: weekdays,
    startDate: const LocalDate(2026, 7, 20),
    unit: WeightUnit.kilograms,
    rounder: const LoadRounder(increment: 2.5),
    confirmedBeyondTrainingMaxes: confirmed,
    confirmedTrainingMaxesByWeek: foreverConfirmations,
    confirmedTrainingMaxesByNode: nodeConfirmations,
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

  test('legacy adapter preserves the single compiled Anchor checkpoint', () {
    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.foreverOriginalFsl,
      athlete: athlete(),
    );

    expect(plan.weeks, hasLength(11));
    expect(plan.blocks, hasLength(5));
    expect(plan.trainingMaxTimeline, hasLength(8));
    expect(
      plan.trainingMaxTimeline
          .map((decision) => decision.afterProgrammingWeek)
          .toSet(),
      {10, 11},
      reason: 'No Leader checkpoint may be invented by the identity adapter.',
    );
    expect(plan.awaitingTrainingMaxConfirmation, isTrue);
  });

  test('Forever generates the sourced 11-week 2L/1A sequence', () {
    final afterThree = {
      MovementId.squat: 105.0,
      MovementId.benchPress: 82.5,
      MovementId.deadlift: 125.0,
      MovementId.overheadPress: 62.5,
    };
    final afterSix = {
      MovementId.squat: 110.0,
      MovementId.benchPress: 85.0,
      MovementId.deadlift: 130.0,
      MovementId.overheadPress: 65.0,
    };
    final afterTen = {
      MovementId.squat: 115.0,
      MovementId.benchPress: 87.5,
      MovementId.deadlift: 135.0,
      MovementId.overheadPress: 67.5,
    };
    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.foreverOriginalFsl,
      athlete: athlete(
        foreverConfirmations: {3: afterThree, 6: afterSix, 10: afterTen},
      ),
    );

    expect(
      plan.weeks.map((week) => week.number),
      List.generate(11, (i) => i + 1),
    );
    expect(plan.blocks.map((block) => block.role), [
      BlockRole.leader,
      BlockRole.leader,
      BlockRole.seventhWeek,
      BlockRole.anchor,
      BlockRole.trainingMaxTest,
    ]);
    expect(plan.blocks.map((block) => block.id), [
      'forever-leader-1',
      'forever-leader-2',
      'forever-seventh-week-deload',
      'forever-anchor-1',
      'forever-seventh-week-tm-test',
    ]);
    expect(plan.blocks[2].seventhWeekPurpose, SeventhWeekPurpose.deload);
    expect(
      plan.blocks.last.seventhWeekPurpose,
      SeventhWeekPurpose.trainingMaxTest,
    );
    expect(plan.trainingMaxTimeline, hasLength(16));
    expect(
      plan.weeks.first.sessions.first.prescriptions.where(
        (set) => set.kind == PrescriptionKind.supplemental,
      ),
      hasLength(5),
    );
    expect(
      plan.weeks[1].sessions
          .expand((session) => session.prescriptions)
          .any((set) => set.kind == PrescriptionKind.performanceSet),
      isFalse,
    );
    expect(
      plan.weeks[7].sessions.first.prescriptions.any(
        (set) => set.kind == PrescriptionKind.supplemental,
      ),
      isFalse,
    );
    expect(
      plan.weeks.last.sessions.first.prescriptions.last.kind,
      PrescriptionKind.trainingMaxTest,
    );
    expect(
      plan.weeks.last.sessions.first.prescriptions.last.calculatedLoad,
      115,
    );
  });

  test('Forever follows the nodes and identifiers of a compiled sequence', () {
    const source = planning.RuleSource(
      document: '5/3/1 Forever',
      location: 'PDF pages 29-33 and 180-182',
    );
    final sequence = planning.CompiledForeverSequence(
      nodes: const [
        planning.ForeverCycleNode(
          nodeId: 'macro-7-C1',
          source: source,
          templateRevisionId: 'forever-original-pr-set-anchor-v1',
          cycleInstanceId: 'custom-anchor',
          role: planning.CycleRole.anchor,
          revision: planning.foreverOriginalPrSetAnchorRevision,
        ),
        planning.ForeverProtocolNode(
          nodeId: 'macro-7-P1',
          source: source,
          templateRevisionId: 'forever-seventh-week-tm-test-v1',
          purpose: planning.ProtocolPurpose.seventhWeekTrainingMaxTest,
          afterCycleInstanceId: 'custom-anchor',
        ),
      ],
      trainingMaxDecisions: const [],
    );
    final confirmed = {
      for (final movement in movements)
        movement: trainingMaxes[movement]! + increments[movement]!,
    };

    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.foreverOriginalFsl,
      athlete: athlete(nodeConfirmations: {'macro-7-C1': confirmed}),
      foreverSequence: sequence,
    );

    expect(plan.blocks.map((block) => block.id), ['macro-7-C1', 'macro-7-P1']);
    expect(plan.blocks.map((block) => block.role), [
      BlockRole.anchor,
      BlockRole.trainingMaxTest,
    ]);
    expect(plan.weeks, hasLength(4));
    expect(plan.weeks.map((week) => week.cycleNumber).toSet(), {1});
    expect(plan.trainingMaxTimeline, hasLength(8));
  });

  test('confirmed final cycle checkpoint without TM test is not awaiting', () {
    const source = planning.RuleSource(
      document: '5/3/1 Forever',
      location: 'PDF pages 180-182',
    );
    final proposed = {
      for (final movement in movements)
        movement.value: trainingMaxes[movement]! + increments[movement]!,
    };
    final sequence = planning.CompiledForeverSequence(
      nodes: const [
        planning.ForeverCycleNode(
          nodeId: 'final-anchor',
          source: source,
          templateRevisionId: 'forever-original-pr-set-anchor-v1',
          cycleInstanceId: 'final-anchor-instance',
          role: planning.CycleRole.anchor,
          revision: planning.foreverOriginalPrSetAnchorRevision,
        ),
      ],
      trainingMaxDecisions: [
        planning.TrainingMaxDecision(
          nodeId: 'final-anchor',
          cycleInstanceId: 'final-anchor-instance',
          states: {
            for (final movement in movements)
              movement.value: planning.TrainingMaxDecisionState.projected,
          },
          previousTrainingMaxes: {
            for (final movement in movements)
              movement.value: trainingMaxes[movement]!,
          },
          proposedTrainingMaxes: proposed,
        ),
      ],
    );
    final confirmed = {
      for (final movement in movements) movement: proposed[movement.value]!,
    };

    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.foreverOriginalFsl,
      athlete: athlete(nodeConfirmations: {'final-anchor': confirmed}),
      foreverSequence: sequence,
    );

    expect(plan.blocks, hasLength(1));
    expect(plan.awaitingTrainingMaxConfirmation, isFalse);
  });

  test('unconfirmed final cycle checkpoint without TM test is awaiting', () {
    const source = planning.RuleSource(
      document: '5/3/1 Forever',
      location: 'PDF pages 180-182',
    );
    final sequence = planning.CompiledForeverSequence(
      nodes: const [
        planning.ForeverCycleNode(
          nodeId: 'final-anchor',
          source: source,
          templateRevisionId: 'forever-original-pr-set-anchor-v1',
          cycleInstanceId: 'final-anchor-instance',
          role: planning.CycleRole.anchor,
          revision: planning.foreverOriginalPrSetAnchorRevision,
        ),
      ],
      trainingMaxDecisions: [
        planning.TrainingMaxDecision(
          nodeId: 'final-anchor',
          cycleInstanceId: 'final-anchor-instance',
          states: {
            for (final movement in movements)
              movement.value: planning.TrainingMaxDecisionState.projected,
          },
          previousTrainingMaxes: {
            for (final movement in movements)
              movement.value: trainingMaxes[movement]!,
          },
          proposedTrainingMaxes: {
            for (final movement in movements)
              movement.value: trainingMaxes[movement]! + increments[movement]!,
          },
        ),
      ],
    );

    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.foreverOriginalFsl,
      athlete: athlete(),
      foreverSequence: sequence,
    );

    expect(plan.blocks, hasLength(1));
    expect(plan.awaitingTrainingMaxConfirmation, isTrue);
  });

  test('compiled Forever sequence is rejected for another generation', () {
    final sequence = planning.CompiledForeverSequence(
      nodes: const [],
      trainingMaxDecisions: const [],
    );

    expect(
      () => const CanonicalPlanGenerator().generate(
        blueprint: CanonicalGenerationBlueprint.standardPowerlifting,
        athlete: athlete(),
        foreverSequence: sequence,
      ),
      throwsArgumentError,
    );
  });

  test('unknown Forever revision fails structurally before generation', () {
    const source = planning.RuleSource(
      document: 'NEEDS_REVIEW',
      location: 'NEEDS_REVIEW',
    );
    final sequence = planning.CompiledForeverSequence(
      nodes: const [
        planning.ForeverCycleNode(
          nodeId: 'unknown-cycle',
          source: source,
          templateRevisionId: 'NEEDS_REVIEW',
          cycleInstanceId: 'unknown',
          role: planning.CycleRole.leader,
          revision: planning.foreverOriginalFslLeaderRevision,
        ),
      ],
      trainingMaxDecisions: const [],
    );

    expect(
      () => const CanonicalPlanGenerator().generate(
        blueprint: CanonicalGenerationBlueprint.foreverOriginalFsl,
        athlete: athlete(),
        foreverSequence: sequence,
      ),
      throwsA(
        isA<planning.ForeverCompilationException>().having(
          (error) => error.validation.issues.map((issue) => issue.code),
          'issue codes',
          contains('strategy.cycle_not_registered'),
        ),
      ),
    );
  });

  test('protocol purpose cannot override the registered revision', () {
    const source = planning.RuleSource(
      document: '5/3/1 Forever',
      location: 'PDF pages 31 and 33',
    );
    final sequence = planning.CompiledForeverSequence(
      nodes: const [
        planning.ForeverProtocolNode(
          nodeId: 'mismatched-protocol',
          source: source,
          templateRevisionId: 'forever-seventh-week-deload-v1',
          purpose: planning.ProtocolPurpose.seventhWeekTrainingMaxTest,
          afterCycleInstanceId: 'leader-2',
        ),
      ],
      trainingMaxDecisions: const [],
    );

    expect(
      () => const CanonicalPlanGenerator().generate(
        blueprint: CanonicalGenerationBlueprint.foreverOriginalFsl,
        athlete: athlete(),
        foreverSequence: sequence,
      ),
      throwsA(
        isA<planning.ForeverCompilationException>().having(
          (error) => error.validation.issues.map((issue) => issue.code),
          'issue codes',
          contains('strategy.protocol_not_registered'),
        ),
      ),
    );
  });
}
