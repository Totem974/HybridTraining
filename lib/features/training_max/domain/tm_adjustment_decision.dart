import '../../programs/domain/training_models.dart';

enum TmAdjustmentKind { hold, progress, reset }

class TmAdjustmentDecision {
  const TmAdjustmentDecision._({
    required this.movement,
    required this.previousTrainingMax,
    required this.nextTrainingMax,
    required this.kind,
    required this.reason,
    required this.ruleId,
    required this.generation,
    required this.source,
  });

  factory TmAdjustmentDecision.progress({
    required MainLift movement,
    required double previousTrainingMax,
    required double requestedIncrease,
    required WeightUnit unit,
    required String reason,
  }) {
    if (previousTrainingMax <= 0 || requestedIncrease < 0) {
      throw ArgumentError('Training Max and increase must be valid.');
    }
    final lower = movement == MainLift.squat || movement == MainLift.deadlift;
    final maximumIncrease = switch (unit) {
      WeightUnit.pounds => lower ? 10.0 : 5.0,
      WeightUnit.kilograms => lower ? 5.0 : 2.5,
    };
    if (requestedIncrease > maximumIncrease + 1e-9) {
      throw ArgumentError(
        'Requested increase exceeds the reviewed Forever maximum.',
      );
    }
    return TmAdjustmentDecision._(
      movement: movement,
      previousTrainingMax: previousTrainingMax,
      nextTrainingMax: previousTrainingMax + requestedIncrease,
      kind: requestedIncrease == 0
          ? TmAdjustmentKind.hold
          : TmAdjustmentKind.progress,
      reason: _reason(reason),
      ruleId: 'TM-PROG-001',
      generation: 'forever',
      source: '5/3/1 Forever, book p. 3; PDF p. 15',
    );
  }

  factory TmAdjustmentDecision.reset({
    required MainLift movement,
    required double previousTrainingMax,
    required double nextTrainingMax,
    required String reason,
  }) {
    if (previousTrainingMax <= 0 ||
        nextTrainingMax <= 0 ||
        nextTrainingMax >= previousTrainingMax) {
      throw ArgumentError('A reset must lower a positive Training Max.');
    }
    return TmAdjustmentDecision._(
      movement: movement,
      previousTrainingMax: previousTrainingMax,
      nextTrainingMax: nextTrainingMax,
      kind: TmAdjustmentKind.reset,
      reason: _reason(reason),
      ruleId: 'TM-RESET-001',
      generation: 'forever',
      source: '5/3/1 Forever, book p. 23; PDF p. 35',
    );
  }

  final MainLift movement;
  final double previousTrainingMax;
  final double nextTrainingMax;
  final TmAdjustmentKind kind;
  final String reason;
  final String ruleId;
  final String generation;
  final String source;

  static String _reason(String value) {
    if (value.trim().isEmpty) throw ArgumentError('A reason is required.');
    return value.trim();
  }
}
