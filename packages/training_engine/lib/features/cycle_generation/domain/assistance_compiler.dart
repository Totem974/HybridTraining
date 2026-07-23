import 'assistance_contract.dart';
import 'cycle_contract.dart';
import 'cycle_generation_error.dart';
import 'cycle_v2_primitives.dart';

final class RoundedAverageEdgeRemainderDistributor {
  const RoundedAverageEdgeRemainderDistributor();

  List<int> distribute({required int total, required int setCount}) {
    if (total <= 0 || setCount <= 0) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidCycleOptions,
        'Assistance total and set count must be positive.',
      );
    }
    final rounded = (total * 2 + setCount) ~/ (setCount * 2);
    final equalSets = List<int>.filled(setCount - 1, rounded);
    final leftover =
        total - equalSets.fold<int>(0, (sum, value) => sum + value);
    return List.unmodifiable(
      leftover > rounded
          ? <int>[leftover, ...equalSets]
          : <int>[...equalSets, leftover],
    );
  }
}

final class AssistanceCompiler {
  const AssistanceCompiler({
    this.distributor = const RoundedAverageEdgeRemainderDistributor(),
  });

  final RoundedAverageEdgeRemainderDistributor distributor;

  List<GeneratedBlock> compileSession({
    required Iterable<ResolvedAssistancePlan> plans,
    required String sessionRole,
    CycleOptionValues optionValues = const CycleOptionValues(),
  }) {
    final result = <GeneratedBlock>[];
    for (final plan in plans) {
      for (final slot in plan.slots.where(
        (candidate) => candidate.sessionRole == sessionRole,
      )) {
        for (final prescription in slot.prescriptions) {
          final repetitions = _repetitions(
            prescription.volume,
            sessionRole,
            optionValues,
          );
          result.add(
            GeneratedBlock(
              id:
                  'assistance-${plan.id}-${slot.id}-'
                  '${prescription.exerciseId}',
              role: 'assistance',
              // Cycle response v1 has a generic string movementId and no
              // exerciseId field. Keeping the exercise identifier here makes
              // the addition schema-compatible until the v2 response exposes
              // a dedicated exerciseId.
              movementId: MovementId(prescription.exerciseId),
              sets: [
                for (final (index, count) in repetitions.indexed)
                  GeneratedSet(
                    index: index,
                    repetitions: FixedRepetitions(count).toJson(),
                    percentageBasisPoints: null,
                    plannedLoad: null,
                    platesPerSide: const [],
                  ),
              ],
            ),
          );
        }
      }
    }
    return List.unmodifiable(result);
  }

  List<int> _repetitions(
    AssistanceVolumePrescription volume,
    String sessionRole,
    CycleOptionValues values,
  ) => switch (volume) {
    FixedAssistanceVolume(:final setCount, :final repetitions) =>
      List<int>.unmodifiable(List<int>.filled(setCount, repetitions)),
    DistributedTotalAssistanceVolume(
      :final setCount,
      :final totalRepetitions,
      :final distribution,
    ) =>
      switch (distribution) {
        AssistanceDistributionKind.roundedAverageEdgeRemainder =>
          distributor.distribute(
            total: _parameter(totalRepetitions, sessionRole, values),
            setCount: _parameter(setCount, sessionRole, values),
          ),
      },
  };

  int _parameter(
    AssistanceIntegerParameter parameter,
    String sessionRole,
    CycleOptionValues values,
  ) {
    final candidate =
        values.bySession[SessionId(sessionRole)]?[parameter.id] ??
        values.byMovement[MovementId(sessionRole)]?[parameter.id] ??
        values.global[parameter.id] ??
        parameter.defaultValue;
    if (candidate is! int ||
        candidate < parameter.minimum ||
        candidate > parameter.maximum ||
        (candidate - parameter.minimum) % parameter.step != 0) {
      throw CycleGenerationException(
        CycleGenerationErrorCode.invalidCycleOptions,
        '${parameter.id} must be an integer from ${parameter.minimum} to '
        '${parameter.maximum} by ${parameter.step}.',
      );
    }
    return candidate;
  }
}
