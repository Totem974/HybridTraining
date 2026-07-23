import 'cycle_contract.dart';
import 'cycle_generation_error.dart';

final class EpleyRepMaxFormula {
  const EpleyRepMaxFormula();

  Weight estimate(Weight weight, int repetitions) {
    if (repetitions <= 0) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidRepMaxFormula,
        'Epley repetitions must be positive.',
      );
    }
    return Weight(
      _divideAndRound(weight.centiUnits * (30 + repetitions), 30),
      weight.unit,
    );
  }
}

final class TrainingMaxResolver {
  const TrainingMaxResolver({this.epley = const EpleyRepMaxFormula()});

  final EpleyRepMaxFormula epley;

  Weight resolve(TrainingMaxInput input, Percentage ratio) {
    _validateRatio(ratio);
    final Weight base;
    switch (input) {
      case OneRepMaxInput(:final weight):
        base = weight;
      case RepMaxInput(:final weight, :final repetitions, :final formula):
        if (formula.toLowerCase() != 'epley') {
          throw CycleGenerationException(
            CycleGenerationErrorCode.invalidRepMaxFormula,
            'Unsupported rep-max formula: $formula.',
          );
        }
        base = epley.estimate(weight, repetitions);
      case DirectTrainingMaxInput(:final weight):
        return weight;
      case OnePlusSetInput(:final weight, :final topSetPercentage):
        if (topSetPercentage.basisPoints <= 0 ||
            topSetPercentage.basisPoints > 10000) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.invalidTrainingMaxRatio,
            'The 1+ set percentage must be greater than 0% and at most 100%.',
          );
        }
        return Weight(
          _divideAndRound(
            weight.centiUnits * 10000,
            topSetPercentage.basisPoints,
          ),
          weight.unit,
        );
    }
    return Weight(
      _divideAndRound(base.centiUnits * ratio.basisPoints, 10000),
      base.unit,
    );
  }

  void _validateRatio(Percentage ratio) {
    if (ratio.basisPoints <= 0 || ratio.basisPoints > 10000) {
      throw CycleGenerationException(
        CycleGenerationErrorCode.invalidTrainingMaxRatio,
        'Training-max ratio must be greater than 0% and at most 100%.',
      );
    }
  }
}

final class LoadCalculator {
  const LoadCalculator();

  Weight percentage(Weight base, Percentage percentage) => Weight(
    _divideAndRound(base.centiUnits * percentage.basisPoints, 10000),
    base.unit,
  );

  Weight roundToIncrement(Weight weight, Weight increment) {
    if (increment.centiUnits <= 0) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidRoundingIncrement,
        'Rounding increment must be positive.',
      );
    }
    if (increment.unit != weight.unit) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.unitMismatch,
        'Load and rounding increment units must match.',
      );
    }
    return Weight(
      _divideAndRound(weight.centiUnits, increment.centiUnits) *
          increment.centiUnits,
      weight.unit,
    );
  }
}

final class PlateSelection {
  const PlateSelection({
    required this.load,
    required this.platesPerSide,
    this.warning,
  });

  final Weight load;
  final List<Weight> platesPerSide;
  final GenerationWarning? warning;
}

final class PlateCalculator {
  const PlateCalculator();

  PlateSelection select(Weight target, BarProfile profile) {
    _validateProfile(target.unit, profile);
    final targetPerSide = (target.centiUnits - profile.weight.centiUnits) ~/ 2;
    if (targetPerSide < 0) {
      return PlateSelection(
        load: profile.weight,
        platesPerSide: const [],
        warning: const GenerationWarning(
          GenerationWarningCode.insufficientEquipment,
          'The bar is heavier than the requested load.',
        ),
      );
    }

    var bestTotal = 0;
    var bestDistance = targetPerSide.abs();
    var bestMask = 0;
    final plates = profile.platesPerSide;
    for (var mask = 0; mask < (1 << plates.length); mask++) {
      var total = 0;
      for (var index = 0; index < plates.length; index++) {
        if ((mask & (1 << index)) != 0) total += plates[index].centiUnits;
      }
      final distance = (targetPerSide - total).abs();
      if (distance < bestDistance ||
          (distance == bestDistance && total < bestTotal)) {
        bestTotal = total;
        bestDistance = distance;
        bestMask = mask;
      }
    }
    final selected = <Weight>[
      for (var index = 0; index < plates.length; index++)
        if ((bestMask & (1 << index)) != 0) plates[index],
    ]..sort((a, b) => b.centiUnits.compareTo(a.centiUnits));
    final actual = Weight(
      profile.weight.centiUnits + (2 * bestTotal),
      target.unit,
    );
    final maximum =
        profile.weight.centiUnits +
        (2 * plates.fold<int>(0, (sum, plate) => sum + plate.centiUnits));
    final warning = actual.centiUnits == target.centiUnits
        ? null
        : target.centiUnits > maximum
        ? const GenerationWarning(
            GenerationWarningCode.insufficientEquipment,
            'Available equipment cannot reach the requested load.',
          )
        : const GenerationWarning(
            GenerationWarningCode.exactLoadUnavailable,
            'The requested load cannot be plated exactly.',
          );
    return PlateSelection(
      load: actual,
      platesPerSide: List.unmodifiable(selected),
      warning: warning,
    );
  }

  void _validateProfile(WeightUnit unit, BarProfile profile) {
    if (profile.weight.unit != unit ||
        profile.platesPerSide.any(
          (plate) => plate.unit != unit || plate.centiUnits <= 0,
        )) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidEquipment,
        'Bar and plates must use the requested unit and positive plate weights.',
      );
    }
  }
}

int _divideAndRound(int numerator, int denominator) =>
    (numerator + denominator ~/ 2) ~/ denominator;
