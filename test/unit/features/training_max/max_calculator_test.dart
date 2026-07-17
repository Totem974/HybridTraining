import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/training_max/domain/max_calculator.dart';

void main() {
  const calculator = MaxCalculator();

  test('estimates one-rep max with the documented Epley formula', () {
    expect(
      calculator.estimateOneRepMax(load: 100, repetitions: 5),
      closeTo(116.6667, 0.0001),
    );
    expect(calculator.estimateOneRepMax(load: 100, repetitions: 1), 100);
  });

  test('calculates a 90 percent training max', () {
    expect(calculator.trainingMax(oneRepMax: 200, ratio: 0.9), 180);
  });

  test('progresses upper and lower body in kg and lb', () {
    expect(
      calculator.progressedTrainingMax(
        current: 100,
        lift: MainLift.benchPress,
        unit: WeightUnit.kilograms,
      ),
      102.5,
    );
    expect(
      calculator.progressedTrainingMax(
        current: 300,
        lift: MainLift.deadlift,
        unit: WeightUnit.pounds,
      ),
      310,
    );
  });
}
