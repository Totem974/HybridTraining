import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/canonical_plan_generator.dart';
import 'package:hybrid_training/features/programs/domain/v2/generation/generated_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';

void main() {
  const movements = [
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

  CanonicalAthleteConfiguration athlete({
    Map<MovementId, double>? beyond,
    Map<String, Map<MovementId, double>> forever = const {},
  }) => CanonicalAthleteConfiguration(
    movementOrder: movements,
    trainingMaxes: initial,
    progressionIncrements: increments,
    trainingWeekdays: const [1, 2, 4, 5],
    startDate: const LocalDate(2026, 7, 20),
    unit: WeightUnit.kilograms,
    rounder: const LoadRounder(increment: 2.5),
    confirmedBeyondTrainingMaxes: beyond,
    confirmedTrainingMaxesByNode: forever,
  );

  test('Standard Powerlifting 4-week golden is stable', () {
    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.standardPowerlifting,
      athlete: athlete(),
    );
    _expectGolden('powerlifting-standard-4-week.golden.json', plan.toJson());
  });

  test('Beyond two cycles plus deload golden is stable', () {
    final confirmed = {
      for (final movement in movements)
        movement: initial[movement]! + increments[movement]!,
    };
    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.beyondSixWeek,
      athlete: athlete(beyond: confirmed),
    );
    _expectGolden('beyond-two-cycles-deload.golden.json', plan.toJson());
  });

  test('Forever 2L/1A plus typed protocols golden is stable', () {
    Map<MovementId, double> progress(Map<MovementId, double> values) => {
      for (final movement in movements)
        movement: values[movement]! + increments[movement]!,
    };
    final afterThree = progress(initial);
    final afterSix = progress(afterThree);
    final afterTen = progress(afterSix);
    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.foreverOriginalFsl,
      athlete: athlete(
        forever: {'C1': afterThree, 'C2': afterSix, 'C3': afterTen},
      ),
    );
    _expectGolden('forever-original-fsl-2l1a.golden.json', plan.toJson());
  });

  test('Beginner Prep School executable activity golden is stable', () {
    final plan = const CanonicalPlanGenerator().generate(
      blueprint: CanonicalGenerationBlueprint.beginnerPrepSchool,
      athlete: CanonicalAthleteConfiguration(
        movementOrder: movements,
        trainingMaxes: initial,
        progressionIncrements: increments,
        trainingMaxRatios: {
          MovementId.squat: .85,
          MovementId.benchPress: .90,
          MovementId.deadlift: .85,
          MovementId.overheadPress: .90,
        },
        trainingWeekdays: const [1, 3, 5],
        startDate: const LocalDate(2026, 7, 20),
        unit: WeightUnit.kilograms,
        rounder: const LoadRounder(increment: 2.5),
      ),
    );
    _expectGolden('beginner-prep-school.golden.json', plan.toJson());
  });
}

void _expectGolden(String name, Map<String, Object?> value) {
  final file = File('test/fixtures/core-v5/$name');
  final actual = '${const JsonEncoder.withIndent('  ').convert(value)}\n';
  if (Platform.environment['UPDATE_CORE_V5_GOLDENS'] == 'true') {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(actual);
  }
  expect(file.existsSync(), isTrue, reason: 'Missing golden: ${file.path}');
  expect(actual, file.readAsStringSync().replaceAll('\r\n', '\n'));
}
