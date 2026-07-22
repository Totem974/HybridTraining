enum CycleGenerationErrorCode {
  emptyCycleId,
  invalidTrainingDays,
  duplicateTrainingDays,
  unsupportedMovement,
  missingMaximum,
  invalidTrainingMaxRatio,
  invalidRoundingIncrement,
  unitMismatch,
  invalidRepMaxFormula,
  invalidEquipment,
  missingRelativeLoadTarget,
  ambiguousRelativeLoadTarget,
}

final class CycleGenerationException implements Exception {
  const CycleGenerationException(this.code, this.message);

  final CycleGenerationErrorCode code;
  final String message;

  @override
  String toString() => 'CycleGenerationException(${code.name}): $message';
}

