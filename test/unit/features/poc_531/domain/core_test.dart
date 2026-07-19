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
      final summary = getCatalogSummary();
      expect(summary.total, 354);
      expect(summary.byGeneration[Generation.original], 40);
      expect(summary.byGeneration[Generation.beyond], 107);
      expect(summary.byGeneration[Generation.forever], 182);
      final report = getCatalogCoverageReport();
      expect(report.total, report.classified);
      expect(report.executable, 4);
      expect(report.ambiguous, 350);
      expect(report.isComplete, isFalse);
      expect(
        listPrograms(
          const ProgramFilters(
            generation: Generation.original,
            includeLegacy: true,
            executableOnly: false,
          ),
        ),
        everyElement(
          predicate<ProgramDefinition>(
            (program) =>
                program.generation == Generation.original &&
                program.sourceKind == SourceKind.canonical,
          ),
        ),
      );
      expect(
        listPrograms(
          const ProgramFilters(
            executableOnly: false,
            includeSupplements: true,
            includeLegacy: true,
          ),
        ).where((program) => program.id.startsWith('PL-')),
        hasLength(25),
      );
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
      expect(
        () => deriveTrainingMax(
          input: const LiftInput(
            lift: MainLift.squat,
            kind: LiftInputKind.trainingMax,
            weight: 0,
          ),
          ratio: .9,
        ),
        throwsArgumentError,
      );
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

    test('reports invalid ratios, rounding, rep maxes and supplements', () {
      final invalid = ProgramConfiguration(
        programId: 'original-fsl-v1',
        generation: Generation.original,
        unit: WeightUnit.kilograms,
        lifts: {
          for (final lift in MainLift.values)
            lift: LiftInput(
              lift: lift,
              kind: LiftInputKind.repetitionMax,
              weight: 100,
              repetitions: 0,
            ),
        },
        trainingMaxRatio: 1.1,
        daysPerWeek: 4,
        trainingWeekdays: const [1, 1, 2, 3],
        roundingIncrement: 0,
        startDate: DateTime.utc(2026, 7, 20),
      );
      expect(
        validateProgramConfiguration(invalid).map((issue) => issue.code),
        containsAll([
          'invalid_frequency',
          'invalid_tm_ratio',
          'invalid_rounding',
          'invalid_lift',
        ]),
      );
      final supplement = _configuration('PL-001', Generation.original, days: 4);
      expect(
        validateProgramConfiguration(supplement).map((issue) => issue.code),
        contains('supplement_not_generation'),
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
      final preferred = recommendPrograms(
        const UserProfile(
          goal: TrainingGoal.hypertrophy,
          level: ExperienceLevel.beginner,
          preferredGeneration: Generation.forever,
          constraints: UserConstraints(daysPerWeek: 4, allowLegacy: true),
        ),
      );
      expect(preferred, isNotEmpty);
      expect(preferred.first.reasons, contains('Génération préférée'));
      expect(preferred.first.tradeoffs, isNotEmpty);
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
      expect(explainGeneratedProgram(plan), contains('schéma 1'));
    });

    test('all executable imported templates resolve to a Core strategy', () {
      final configurations = [
        _configuration('BY-026', Generation.beyond, days: 3),
        _configuration('FV-141', Generation.forever, days: 3, ratio: .85),
        _configuration('FV-236', Generation.forever, days: 4),
        _configuration(
          'PL-001',
          Generation.original,
          days: 4,
          powerliftingExtension: true,
        ),
      ];
      for (final configuration in configurations) {
        expect(validateProgramConfiguration(configuration), isEmpty);
        expect(generateProgram(configuration).payload['blocks'], isNotEmpty);
      }
    });
  });
}

ProgramConfiguration _configuration(
  String id,
  Generation generation, {
  required int days,
  double ratio = .9,
  bool powerliftingExtension = false,
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
    options: GenerationSpecificOptions(
      enablePowerliftingExtension: powerliftingExtension,
    ),
    startDate: DateTime.utc(2026, 7, 20),
  );
}
