import 'cycle_calculations.dart';
import 'cycle_contract.dart';
import 'cycle_generation_error.dart';

final class CycleCompilerImpl implements CycleCompiler {
  const CycleCompilerImpl({
    this.maxResolver = const TrainingMaxResolver(),
    this.loadCalculator = const LoadCalculator(),
    this.plateCalculator = const PlateCalculator(),
  });

  final TrainingMaxResolver maxResolver;
  final LoadCalculator loadCalculator;
  final PlateCalculator plateCalculator;

  @override
  GeneratedCycle compile(
    ResolvedCycleDefinition definition,
    CycleRequest request,
  ) {
    _validate(definition, request);
    final maxes = <MovementId, Weight>{};
    for (final movement in request.sessionOrder) {
      final input = request.maxInputs[movement]!;
      final ratio =
          request.trainingMaxRatioByMovement[movement] ??
          request.globalTrainingMaxRatio;
      final resolved = maxResolver.resolve(input, ratio);
      if (resolved.unit != request.unit) {
        throw CycleGenerationException(
          CycleGenerationErrorCode.unitMismatch,
          'Maximum for ${movement.value} does not use ${request.unit.name}.',
        );
      }
      maxes[movement] = resolved;
    }

    var cursor = DateTime(
      request.startDate.year,
      request.startDate.month,
      request.startDate.day,
    );
    final weeks = <GeneratedWeek>[];
    for (final week in definition.weeks) {
      final sessions = <GeneratedSession>[];
      for (var index = 0; index < request.sessionOrder.length; index++) {
        final movement = request.sessionOrder[index];
        cursor = _onOrAfter(cursor, request.trainingDays[index]);
        sessions.add(
          GeneratedSession(
            id: '${request.cycleId}-w${week.number}-s${index + 1}',
            date: cursor,
            movementId: movement,
            blocks: _compileBlocks(
              week.blocks,
              maxes[movement]!,
              request.maxInputs[movement]!,
              request,
            ),
          ),
        );
        cursor = cursor.add(const Duration(days: 1));
      }
      weeks.add(GeneratedWeek(number: week.number, sessions: sessions));
    }
    return GeneratedCycle(
      id: request.cycleId,
      catalogVersion: definition.catalogVersion,
      templateId: definition.templateId,
      variantId: definition.variantId,
      effectiveTrainingMaxes: {
        for (final entry in maxes.entries) entry.key.value: entry.value,
      },
      weeks: weeks,
    );
  }

  List<GeneratedBlock> _compileBlocks(
    List<BlockDefinition> definitions,
    Weight trainingMax,
    TrainingMaxInput maxInput,
    CycleRequest request,
  ) => [
    for (final block in definitions)
      if (request.includeDeload || block.role != 'deload')
        GeneratedBlock(
          id: block.id,
          role: block.role,
          sets: [
            for (var index = 0; index < block.sets.length; index++)
              _compileSet(
                index,
                block.sets[index],
                trainingMax,
                maxInput,
                request,
              ),
          ],
        ),
  ];

  GeneratedSet _compileSet(
    int index,
    PrescribedSetDefinition definition,
    Weight trainingMax,
    TrainingMaxInput maxInput,
    CycleRequest request,
  ) {
    final load = definition.load;
    Weight? desired;
    int? percentage;
    switch (load) {
      case TrainingMaxPercentageLoad(percentage: final value):
        percentage = value.basisPoints;
        desired = loadCalculator.percentage(trainingMax, value);
      case OneRepMaxPercentageLoad(percentage: final value):
        percentage = value.basisPoints;
        desired = loadCalculator.percentage(_oneRepMax(maxInput), value);
      case FixedLoad(:final weight):
        desired = weight;
      case BodyweightLoad() || Unloaded():
        desired = null;
    }
    PlateSelection? selection;
    if (desired != null) {
      final rounded = loadCalculator.roundToIncrement(
        desired,
        request.roundingIncrement,
      );
      selection = plateCalculator.select(rounded, request.barProfile);
    }
    return GeneratedSet(
      index: index,
      repetitions: definition.repetitions.toJson(),
      percentageBasisPoints: percentage,
      plannedLoad: selection?.load,
      platesPerSide: selection?.platesPerSide ?? const [],
      warning: selection?.warning,
    );
  }

  Weight _oneRepMax(TrainingMaxInput input) {
    switch (input) {
      case OneRepMaxInput(:final weight):
        return weight;
      case RepMaxInput(:final weight, :final repetitions, :final formula):
        if (formula.toLowerCase() != 'epley') {
          throw CycleGenerationException(
            CycleGenerationErrorCode.invalidRepMaxFormula,
            'Unsupported rep-max formula: $formula.',
          );
        }
        return maxResolver.epley.estimate(weight, repetitions);
      case DirectTrainingMaxInput():
        throw const CycleGenerationException(
          CycleGenerationErrorCode.missingMaximum,
          'A direct training max cannot resolve a 1RM percentage.',
        );
    }
  }

  void _validate(ResolvedCycleDefinition definition, CycleRequest request) {
    if (request.cycleId.trim().isEmpty) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.emptyCycleId,
        'Cycle id cannot be empty.',
      );
    }
    if (request.trainingDays.length != request.sessionOrder.length ||
        request.trainingDays.isEmpty ||
        request.trainingDays.any((day) => day < 1 || day > 7)) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidTrainingDays,
        'One weekday from 1 to 7 is required for every session.',
      );
    }
    if (request.trainingDays.toSet().length != request.trainingDays.length) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.duplicateTrainingDays,
        'Training weekdays must be unique.',
      );
    }
    final supported = definition.sessionMovementIds.toSet();
    if (request.sessionOrder.length != definition.sessionMovementIds.length ||
        request.sessionOrder.toSet().length != supported.length ||
        !request.sessionOrder.toSet().containsAll(supported)) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.unsupportedMovement,
        'Session order must contain every definition movement exactly once.',
      );
    }
    for (final movement in request.sessionOrder) {
      if (!supported.contains(movement)) {
        throw CycleGenerationException(
          CycleGenerationErrorCode.unsupportedMovement,
          'Movement ${movement.value} is not supported by the definition.',
        );
      }
      if (!request.maxInputs.containsKey(movement)) {
        throw CycleGenerationException(
          CycleGenerationErrorCode.missingMaximum,
          'No maximum was supplied for ${movement.value}.',
        );
      }
    }
    if (request.roundingIncrement.centiUnits <= 0) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidRoundingIncrement,
        'Rounding increment must be positive.',
      );
    }
    final ratios = <Percentage>[
      request.globalTrainingMaxRatio,
      ...request.trainingMaxRatioByMovement.values,
    ];
    if (ratios.any(
      (ratio) => ratio.basisPoints <= 0 || ratio.basisPoints > 10000,
    )) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidTrainingMaxRatio,
        'Training-max ratios must be greater than 0% and at most 100%.',
      );
    }
  }

  DateTime _onOrAfter(DateTime date, int weekday) {
    final days = (weekday - date.weekday + 7) % 7;
    return date.add(Duration(days: days));
  }
}
