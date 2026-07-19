import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/domain/core.dart';

void main() {
  group('public catalog', () {
    test('contains exactly the three primary generations', () {
      expect(listGenerations(), [
        Generation.original,
        Generation.beyond,
        Generation.forever,
      ]);
      expect(
        listGenerations().map((value) => value.name),
        isNot(contains('powerlifting')),
      );
      final extension = getProgramDefinition('powerlifting-standard-531-v1')!;
      expect(extension.generation, isNull);
      expect(extension.sourceKind, SourceKind.supplement);
      expect(extension.isExecutable, isFalse);
    });

    test('classifies every entry and links every executable strategy', () {
      final report = getCatalogCoverageReport();
      expect(report.total, report.classified);
      expect(report.executable, 4);
      expect(report.ambiguous, 350);
      expect(report.isComplete, isFalse);
    });
  });

  group('max calculations', () {
    test('estimates one rep max with the existing Epley implementation', () {
      expect(
        calculateEstimatedOneRepMax(
          const RepMaxInput(weight: 100, repetitions: 5),
        ),
        closeTo(116.666666, .00001),
      );
      expect(
        calculateEstimatedOneRepMax(
          const RepMaxInput(weight: 100, repetitions: 1),
        ),
        100,
      );
    });

    test('derives TM from 1RM, rep max, or an explicit TM', () {
      final one = deriveTrainingMax(
        input: const LiftInput(
          lift: MainLift.squat,
          kind: LiftInputKind.oneRepMax,
          weight: 200,
        ),
        ratio: .9,
      );
      expect(one.trainingMax, 180);
      final reps = deriveTrainingMax(
        input: const LiftInput(
          lift: MainLift.squat,
          kind: LiftInputKind.repetitionMax,
          weight: 100,
          repetitions: 5,
        ),
        ratio: .9,
      );
      expect(reps.trainingMax, 105);
      final tm = deriveTrainingMax(
        input: const LiftInput(
          lift: MainLift.squat,
          kind: LiftInputKind.trainingMax,
          weight: 180,
        ),
        ratio: .9,
      );
      expect(tm.oneRepMax, 200);
    });
  });

  test('plate loading is exact or reports a deterministic rounding error', () {
    final inventory = PlateInventory(
      barWeight: 20,
      plates: {20: 4, 10: 2, 5: 2, 2.5: 2, 1.25: 2},
    );
    final exact = calculatePlateLoading(100, inventory);
    expect(exact.perSide, [20, 20]);
    expect(exact.roundingError, 0);
    final rounded = calculatePlateLoading(101, inventory);
    expect(rounded.loadedWeight, 100);
    expect(rounded.roundingError, -1);
  });

  group('validation and recommendations', () {
    test('blocks a generation mismatch and missing lifts', () {
      final configuration = _configuration(
        'original-fsl-v1',
        Generation.forever,
        days: 3,
      );
      final issues = validateProgramConfiguration(configuration);
      expect(
        issues.map((issue) => issue.code),
        containsAll(['generation_mismatch', 'invalid_frequency']),
      );
    });

    test('recommendations are stable and never promote the supplement', () {
      const profile = UserProfile(
        goal: TrainingGoal.strength,
        level: ExperienceLevel.intermediate,
        constraints: UserConstraints(daysPerWeek: 4, allowLegacy: true),
      );
      final first = recommendPrograms(profile);
      final second = recommendPrograms(profile);
      expect(
        first.map((item) => item.program.id),
        second.map((item) => item.program.id),
      );
      expect(
        first.map((item) => item.program.sourceKind),
        everyElement(SourceKind.canonical),
      );
      expect(
        explainRecommendation(first.first),
        contains(first.first.program.name),
      );
    });
  });

  group('generation', () {
    test(
      'generates Original deterministically through the existing adapter',
      () {
        final configuration = _configuration(
          'original-fsl-v1',
          Generation.original,
          days: 4,
        );
        final first = generateProgram(configuration);
        final second = generateProgram(configuration);
        expect(serializeProgram(first), serializeProgram(second));
        expect((first.payload['blocks'] as List), isNotEmpty);
      },
    );

    test('generates complete Beyond cycles and deload', () {
      final plan = generateProgram(
        _configuration('beyond-six-week-cycle-v1', Generation.beyond, days: 3),
      );
      final blocks = plan.payload['blocks'] as List;
      expect(blocks, hasLength(3));
      expect(plan.payload['trainingMaxTimeline'], isNotEmpty);
    });

    test('generates Forever leader, seventh weeks, anchor and transitions', () {
      final plan = generateProgram(
        _configuration(
          'forever-original-531-fsl-2l1a-v1',
          Generation.forever,
          days: 4,
        ),
      );
      final blocks = plan.payload['blocks'] as List;
      expect(blocks, hasLength(5));
      expect(jsonEncode(blocks), contains('seventhWeek'));
      expect(jsonEncode(blocks), contains('anchor'));
      expect(plan.payload['transitions'], isNotEmpty);
    });

    test('generates beginner Forever only with a sourced TM ratio', () {
      final plan = generateProgram(
        _configuration(
          'forever-beginner-prep-school-v1',
          Generation.forever,
          days: 3,
          ratio: .85,
        ),
      );
      expect(plan.payload['blocks'], isNotEmpty);
    });

    test('serializes and restores a versioned plan', () {
      final plan = generateProgram(
        _configuration('beyond-six-week-cycle-v1', Generation.beyond, days: 3),
      );
      final restored = deserializeProgram(serializeProgram(plan));
      expect(serializeProgram(restored), serializeProgram(plan));
      expect(
        () => deserializeProgram('{"schemaVersion":99}'),
        throwsFormatException,
      );
    });
  });
}

ProgramConfiguration _configuration(
  String id,
  Generation generation, {
  required int days,
  double ratio = .9,
}) {
  const weights = {
    MainLift.squat: 160.0,
    MainLift.benchPress: 110.0,
    MainLift.deadlift: 190.0,
    MainLift.overheadPress: 75.0,
  };
  return ProgramConfiguration(
    programId: id,
    generation: generation,
    unit: WeightUnit.kilograms,
    lifts: {
      for (final entry in weights.entries)
        entry.key: LiftInput(
          lift: entry.key,
          kind: LiftInputKind.oneRepMax,
          weight: entry.value,
        ),
    },
    trainingMaxRatio: ratio,
    daysPerWeek: days,
    trainingWeekdays: days == 3 ? const [1, 3, 5] : const [1, 2, 4, 5],
    roundingIncrement: 2.5,
    startDate: DateTime.utc(2026, 7, 20),
  );
}
