import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/load_rounding.dart';
import 'package:hybrid_training/features/programs/domain/original_fsl_program.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';

void main() {
  const program = OriginalFslProgram();
  const liftMax = LiftMax(
    lift: MainLift.squat,
    oneRepMax: 200,
    trainingMaxRatio: 0.9,
    unit: WeightUnit.kilograms,
  );
  const rounder = LoadRounder(increment: 2.5);

  test('week 1 uses 3/5/1 percentages and five FSL sets', () {
    final session = program.buildSession(
      week: 1,
      liftMax: liftMax,
      rounder: rounder,
    );

    expect(session.sets, hasLength(8));
    expect(
      session.sets.take(3).map((set) => set.load),
      orderedEquals([125, 145, 162.5]),
    );
    expect(session.sets[2].isPerformanceSet, isTrue);
    expect(session.sets.skip(3).map((set) => set.load), everyElement(125));
  });

  test('week 2 has no performance set', () {
    final session = program.buildSession(
      week: 2,
      liftMax: liftMax,
      rounder: rounder,
    );

    expect(session.sets.any((set) => set.isPerformanceSet), isFalse);
    expect(
      session.sets.take(3).map((set) => set.repetitions),
      orderedEquals([5, 5, 5]),
    );
  });

  test('week 3 marks only the final main set as a performance set', () {
    final session = program.buildSession(
      week: 3,
      liftMax: liftMax,
      rounder: rounder,
    );

    expect(session.sets.where((set) => set.isPerformanceSet), hasLength(1));
    expect(session.sets[2].load, 170);
    expect(session.sets[2].repetitions, 1);
  });

  test('supports the confirmed three-set FSL option', () {
    const reducedProgram = OriginalFslProgram(supplementalSets: 3);

    final session = reducedProgram.buildSession(
      week: 1,
      liftMax: liftMax,
      rounder: rounder,
    );

    expect(session.sets, hasLength(6));
  });

  test('rounds independently for kg and lb increments', () {
    final kilograms = program.buildSession(
      week: 1,
      liftMax: liftMax,
      rounder: const LoadRounder(increment: 2.5),
    );
    final pounds = program.buildSession(
      week: 1,
      liftMax: const LiftMax(
        lift: MainLift.squat,
        oneRepMax: 445,
        trainingMaxRatio: 0.9,
        unit: WeightUnit.pounds,
      ),
      rounder: const LoadRounder(increment: 5),
    );

    expect(kilograms.sets.first.load, 125);
    expect(pounds.sets.first.load, 280);
    expect(pounds.sets.first.roundingIncrement, 5);
  });

  test('rejects a week outside the confirmed cycle', () {
    expect(
      () => program.buildSession(week: 4, liftMax: liftMax, rounder: rounder),
      throwsArgumentError,
    );
  });
}
