import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';

class OriginalFslProgram {
  const OriginalFslProgram({this.supplementalSets = 5})
    : assert(supplementalSets == 3 || supplementalSets == 5);

  final int supplementalSets;

  TrainingSession buildSession({
    required int week,
    required LiftMax liftMax,
    required LoadRounder rounder,
  }) {
    final prescription = _week(week);
    final sets = <SetPrescription>[
      for (var index = 0; index < prescription.main.length; index++)
        SetPrescription(
          kind: SetKind.main,
          percentage: prescription.main[index].percentage,
          repetitions: prescription.main[index].repetitions,
          trainingMax: liftMax.trainingMax,
          unroundedLoad:
              liftMax.trainingMax * prescription.main[index].percentage,
          roundingIncrement: rounder.increment,
          load: rounder.nearest(
            liftMax.trainingMax * prescription.main[index].percentage,
          ),
          isPerformanceSet:
              prescription.hasPerformanceSet &&
              index == prescription.main.length - 1,
        ),
      for (var index = 0; index < supplementalSets; index++)
        SetPrescription(
          kind: SetKind.supplemental,
          percentage: prescription.fslPercentage,
          repetitions: 5,
          trainingMax: liftMax.trainingMax,
          unroundedLoad: liftMax.trainingMax * prescription.fslPercentage,
          roundingIncrement: rounder.increment,
          load: rounder.nearest(
            liftMax.trainingMax * prescription.fslPercentage,
          ),
        ),
    ];

    return TrainingSession(week: week, lift: liftMax.lift, sets: sets);
  }

  _WeekPrescription _week(int week) => switch (week) {
    1 => const _WeekPrescription(
      main: [
        _SetRatio(percentage: 0.70, repetitions: 3),
        _SetRatio(percentage: 0.80, repetitions: 3),
        _SetRatio(percentage: 0.90, repetitions: 3),
      ],
      fslPercentage: 0.70,
      hasPerformanceSet: true,
    ),
    2 => const _WeekPrescription(
      main: [
        _SetRatio(percentage: 0.65, repetitions: 5),
        _SetRatio(percentage: 0.75, repetitions: 5),
        _SetRatio(percentage: 0.85, repetitions: 5),
      ],
      fslPercentage: 0.65,
      hasPerformanceSet: false,
    ),
    3 => const _WeekPrescription(
      main: [
        _SetRatio(percentage: 0.75, repetitions: 5),
        _SetRatio(percentage: 0.85, repetitions: 3),
        _SetRatio(percentage: 0.95, repetitions: 1),
      ],
      fslPercentage: 0.75,
      hasPerformanceSet: true,
    ),
    _ => throw ArgumentError.value(week, 'week', 'must be between 1 and 3'),
  };
}

class _WeekPrescription {
  const _WeekPrescription({
    required this.main,
    required this.fslPercentage,
    required this.hasPerformanceSet,
  });

  final List<_SetRatio> main;
  final double fslPercentage;
  final bool hasPerformanceSet;
}

class _SetRatio {
  const _SetRatio({required this.percentage, required this.repetitions});

  final double percentage;
  final int repetitions;
}
