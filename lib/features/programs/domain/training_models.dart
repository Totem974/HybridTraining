enum MainLift { squat, benchPress, deadlift, overheadPress }

enum WeightUnit { kilograms, pounds }

enum SetKind { main, supplemental }

class LiftMax {
  const LiftMax({
    required this.lift,
    required this.oneRepMax,
    required this.trainingMaxRatio,
    required this.unit,
  }) : assert(oneRepMax > 0),
       assert(trainingMaxRatio > 0 && trainingMaxRatio <= 1);

  final MainLift lift;
  final double oneRepMax;
  final double trainingMaxRatio;
  final WeightUnit unit;

  double get trainingMax => oneRepMax * trainingMaxRatio;
}

class SetPrescription {
  const SetPrescription({
    required this.kind,
    required this.percentage,
    required this.repetitions,
    required this.load,
    required this.trainingMax,
    required this.unroundedLoad,
    required this.roundingIncrement,
    this.isPerformanceSet = false,
  });

  final SetKind kind;
  final double percentage;
  final int repetitions;
  final double load;
  final double trainingMax;
  final double unroundedLoad;
  final double roundingIncrement;
  final bool isPerformanceSet;
}

class TrainingSession {
  const TrainingSession({
    required this.week,
    required this.lift,
    required this.sets,
  });

  final int week;
  final MainLift lift;
  final List<SetPrescription> sets;
}
