import 'package:hybrid_training/features/programs/domain/training_models.dart';

class MaxCalculator {
  const MaxCalculator();

  double estimateOneRepMax({required double load, required int repetitions}) {
    if (load <= 0 || repetitions <= 0) {
      throw ArgumentError('Load and repetitions must be positive.');
    }
    if (repetitions == 1) return load;
    return load * (1 + repetitions / 30);
  }

  double trainingMax({required double oneRepMax, required double ratio}) {
    if (oneRepMax <= 0 || ratio <= 0 || ratio > 1) {
      throw ArgumentError('Invalid one-rep max or training max ratio.');
    }
    return oneRepMax * ratio;
  }

  double progressedTrainingMax({
    required double current,
    required MainLift lift,
    required WeightUnit unit,
  }) {
    if (current <= 0) throw ArgumentError.value(current, 'current');
    final lowerBody = lift == MainLift.squat || lift == MainLift.deadlift;
    final increase = switch (unit) {
      WeightUnit.kilograms => lowerBody ? 5.0 : 2.5,
      WeightUnit.pounds => lowerBody ? 10.0 : 5.0,
    };
    return current + increase;
  }
}
