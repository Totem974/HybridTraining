import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/training_max/domain/tm_adjustment_decision.dart';

void main() {
  test('proposes hold, bounded progression and individual reset', () {
    final progression = TmAdjustmentDecision.progress(
      movement: MainLift.squat,
      previousTrainingMax: 100,
      requestedIncrease: 5,
      unit: WeightUnit.kilograms,
      reason: 'Completed reviewed cycle',
    );
    expect(progression.nextTrainingMax, 105);
    expect(progression.kind, TmAdjustmentKind.progress);
    expect(progression.ruleId, 'TM-PROG-001');

    final hold = TmAdjustmentDecision.progress(
      movement: MainLift.benchPress,
      previousTrainingMax: 70,
      requestedIncrease: 0,
      unit: WeightUnit.kilograms,
      reason: 'Repeat while technique improves',
    );
    expect(hold.kind, TmAdjustmentKind.hold);

    final reset = TmAdjustmentDecision.reset(
      movement: MainLift.overheadPress,
      previousTrainingMax: 50,
      nextTrainingMax: 45,
      reason: 'Individual reset after insufficient test',
    );
    expect(reset.kind, TmAdjustmentKind.reset);
    expect(reset.ruleId, 'TM-RESET-001');
  });

  test('rejects accelerated progression and invalid reset', () {
    expect(
      () => TmAdjustmentDecision.progress(
        movement: MainLift.benchPress,
        previousTrainingMax: 70,
        requestedIncrease: 5,
        unit: WeightUnit.kilograms,
        reason: 'Too fast',
      ),
      throwsArgumentError,
    );
    expect(
      () => TmAdjustmentDecision.reset(
        movement: MainLift.squat,
        previousTrainingMax: 100,
        nextTrainingMax: 105,
        reason: 'Not a reset',
      ),
      throwsArgumentError,
    );
  });
}
