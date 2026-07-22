import 'cycle_contract.dart';

enum WarmUpType { original, beyond }

final class WarmUpExecutionOptions {
  const WarmUpExecutionOptions({
    required this.enabled,
    this.type,
    this.upperBodyBaseWeight,
    this.lowerBodyBaseWeight,
  });
  const WarmUpExecutionOptions.disabled()
    : enabled = false,
      type = null,
      upperBodyBaseWeight = null,
      lowerBodyBaseWeight = null;

  final bool enabled;
  final WarmUpType? type;
  final Weight? upperBodyBaseWeight;
  final Weight? lowerBodyBaseWeight;
}

final class JokerExecutionOptions {
  const JokerExecutionOptions({required this.enabled, this.ceilingBasisPoints});
  const JokerExecutionOptions.disabled()
    : enabled = false,
      ceilingBasisPoints = null;

  final bool enabled;
  final int? ceilingBasisPoints;
}

enum DeloadType { type1, type2, type3, type4, type5, highIntensity }

final class DeloadExecutionOptions {
  const DeloadExecutionOptions({
    required this.enabled,
    this.type,
    this.skipWarmUp = false,
  });
  const DeloadExecutionOptions.disabled()
    : enabled = false,
      type = null,
      skipWarmUp = false;

  final bool enabled;
  final DeloadType? type;
  final bool skipWarmUp;
}

final class CycleExecutionOptions {
  const CycleExecutionOptions({
    this.warmUp = const WarmUpExecutionOptions.disabled(),
    this.joker = const JokerExecutionOptions.disabled(),
    this.deload = const DeloadExecutionOptions.disabled(),
  });

  final WarmUpExecutionOptions warmUp;
  final JokerExecutionOptions joker;
  final DeloadExecutionOptions deload;

  CycleExecutionOptions normalized() => CycleExecutionOptions(
    warmUp: warmUp.enabled
        ? WarmUpExecutionOptions(
            enabled: true,
            type: warmUp.type,
            upperBodyBaseWeight: warmUp.type == WarmUpType.beyond
                ? warmUp.upperBodyBaseWeight
                : null,
            lowerBodyBaseWeight: warmUp.type == WarmUpType.beyond
                ? warmUp.lowerBodyBaseWeight
                : null,
          )
        : const WarmUpExecutionOptions.disabled(),
    joker: joker.enabled ? joker : const JokerExecutionOptions.disabled(),
    deload: deload.enabled
        ? DeloadExecutionOptions(
            enabled: true,
            type: deload.type,
            skipWarmUp:
                deload.type != DeloadType.highIntensity && deload.skipWarmUp,
          )
        : const DeloadExecutionOptions.disabled(),
  );
}

final class ResolvedBlockOverlay {
  const ResolvedBlockOverlay({
    required this.weekNumber,
    required this.sessionId,
    required this.blocks,
  });

  final int weekNumber;
  final MovementId sessionId;
  final List<BlockDefinition> blocks;
}

final class ResolvedBlockRecipe {
  const ResolvedBlockRecipe({
    this.unitIndependent = const [],
    this.byUnit = const {},
  });

  final List<ResolvedBlockOverlay> unitIndependent;
  final Map<WeightUnit, List<ResolvedBlockOverlay>> byUnit;

  List<ResolvedBlockOverlay> overlaysFor(WeightUnit unit) => [
    ...unitIndependent,
    ...?byUnit[unit],
  ];
}

final class JokerRecipeStep {
  const JokerRecipeStep({
    required this.cumulativeIncreaseBasisPoints,
    required this.repetitions,
  });

  final int cumulativeIncreaseBasisPoints;
  final RepetitionPrescription repetitions;
}

final class ResolvedJokerRecipe {
  const ResolvedJokerRecipe({required this.blockId, required this.steps});

  final String blockId;
  final List<JokerRecipeStep> steps;
}

final class ResolvedCycleOptionRecipes {
  const ResolvedCycleOptionRecipes({
    this.warmUp = const {},
    this.joker,
    this.deload = const {},
  });

  final Map<WarmUpType, ResolvedBlockRecipe> warmUp;
  final ResolvedJokerRecipe? joker;
  final Map<DeloadType, ResolvedBlockRecipe> deload;
}
