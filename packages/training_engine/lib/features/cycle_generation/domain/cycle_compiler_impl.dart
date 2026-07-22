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
    final requiredMaxes = _requiredMaximums(definition, request);
    final maxes = <MovementId, Weight>{};
    for (final movement in requiredMaxes) {
      final input = request.maxInputs[movement];
      if (input == null) {
        throw CycleGenerationException(
          CycleGenerationErrorCode.missingMaximum,
          'No maximum was supplied for ${movement.value}.',
        );
      }
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
              _blocksFor(week, movement),
              movement,
              maxes,
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
    MovementId sessionMovement,
    Map<MovementId, Weight> maxes,
    CycleRequest request,
  ) => [
    for (final block in definitions)
      if (request.includeDeload || block.role != 'deload')
        GeneratedBlock(
          id: block.id,
          role: block.role,
          movementId: block.movementId ?? sessionMovement,
          sets: [
            for (var index = 0; index < block.sets.length; index++)
              _compileSet(
                index,
                block.sets[index],
                definitions,
                block.movementId ?? sessionMovement,
                maxes[block.movementId ?? sessionMovement],
                request.maxInputs[block.movementId ?? sessionMovement],
                request,
              ),
          ],
        ),
  ];

  GeneratedSet _compileSet(
    int index,
    PrescribedSetDefinition definition,
    List<BlockDefinition> sessionBlocks,
    MovementId movement,
    Weight? trainingMax,
    TrainingMaxInput? maxInput,
    CycleRequest request,
  ) {
    final load = definition.load;
    Weight? desired;
    int? percentage;
    switch (load) {
      case TrainingMaxPercentageLoad(percentage: final value):
        if (trainingMax == null) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.missingMaximum,
            'A training max is required for a percentage load.',
          );
        }
        percentage = value.basisPoints;
        desired = loadCalculator.percentage(trainingMax, value);
      case ParameterizedTrainingMaxPercentageLoad(
        :final parameterId,
        :final defaultValue,
        :final minimum,
        :final maximum,
      ):
        if (trainingMax == null) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.missingMaximum,
            'A training max is required for a percentage load.',
          );
        }
        final value =
            request.percentageParametersByMovement[movement]?[parameterId] ??
            request.percentageParameters[parameterId] ??
            defaultValue;
        if (value.basisPoints < minimum.basisPoints ||
            value.basisPoints > maximum.basisPoints) {
          throw CycleGenerationException(
            CycleGenerationErrorCode.invalidTrainingMaxRatio,
            'Parameter $parameterId must be between ${minimum.basisPoints} '
            'and ${maximum.basisPoints} basis points.',
          );
        }
        percentage = value.basisPoints;
        desired = loadCalculator.percentage(trainingMax, value);
      case OneRepMaxPercentageLoad(percentage: final value):
        if (maxInput == null) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.missingMaximum,
            'A maximum is required for a 1RM percentage load.',
          );
        }
        percentage = value.basisPoints;
        desired = loadCalculator.percentage(_oneRepMax(maxInput), value);
      case FixedLoad(:final weight):
        desired = weight;
      case BodyweightLoad() || Unloaded():
        desired = null;
      case RelativeSetLoad(:final position, :final multiplierBasisPoints):
        if (trainingMax == null) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.missingMaximum,
            'A training max is required for a relative set load.',
          );
        }
        final target = _relativeTarget(
          sessionBlocks,
          movement,
          position,
          request,
        );
        percentage =
            (target.basisPoints * multiplierBasisPoints + 5000) ~/ 10000;
        desired = loadCalculator.percentage(
          trainingMax,
          Percentage(percentage),
        );
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
      execution: definition.execution,
      runtimeDecisions: [
        for (final gate in definition.runtimeGates)
          RuntimeDecision(
            kind: gate.kind,
            status: gate.required
                ? RuntimeDecisionStatus.pending
                : RuntimeDecisionStatus.notRequired,
          ),
      ],
      warning: selection?.warning,
    );
  }

  Percentage _relativeTarget(
    List<BlockDefinition> sessionBlocks,
    MovementId movement,
    RelativeSetPosition position,
    CycleRequest request,
  ) {
    final candidates = sessionBlocks
        .where(
          (block) =>
              const {'main_work', 'main work'}.contains(block.role) &&
              (block.movementId == null || block.movementId == movement),
        )
        .toList(growable: false);
    if (candidates.isEmpty) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.missingRelativeLoadTarget,
        'A relative load requires a main-work block in the same session.',
      );
    }
    if (candidates.length > 1) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.ambiguousRelativeLoadTarget,
        'A relative load found multiple main-work blocks for its movement.',
      );
    }
    final workSets = candidates.single.sets;
    final index = switch (position) {
      RelativeSetPosition.first => 0,
      RelativeSetPosition.second => workSets.length < 2 ? null : 1,
      RelativeSetPosition.top => workSets.length - 1,
    };
    if (index == null || workSets.isEmpty) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.missingRelativeLoadTarget,
        'The referenced main-work set does not exist.',
      );
    }
    final load = workSets[index].load;
    return switch (load) {
      TrainingMaxPercentageLoad(:final percentage) => percentage,
      ParameterizedTrainingMaxPercentageLoad(
        :final parameterId,
        :final defaultValue,
        :final minimum,
        :final maximum,
      ) =>
        _percentageParameter(
          request,
          movement,
          parameterId,
          defaultValue,
          minimum,
          maximum,
        ),
      _ => throw const CycleGenerationException(
        CycleGenerationErrorCode.missingRelativeLoadTarget,
        'Relative set loads require a TM-percentage main-work set.',
      ),
    };
  }

  Percentage _percentageParameter(
    CycleRequest request,
    MovementId movement,
    String parameterId,
    Percentage defaultValue,
    Percentage minimum,
    Percentage maximum,
  ) {
    final value =
        request.percentageParametersByMovement[movement]?[parameterId] ??
        request.percentageParameters[parameterId] ??
        defaultValue;
    if (value.basisPoints < minimum.basisPoints ||
        value.basisPoints > maximum.basisPoints) {
      throw CycleGenerationException(
        CycleGenerationErrorCode.invalidTrainingMaxRatio,
        'Parameter $parameterId must be between ${minimum.basisPoints} '
        'and ${maximum.basisPoints} basis points.',
      );
    }
    return value;
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
    for (final movement in _requiredMaximums(definition, request)) {
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

  List<BlockDefinition> _blocksFor(WeekDefinition week, MovementId sessionId) {
    if (week.sessions.isEmpty) return week.blocks;
    return week.sessions
        .singleWhere((session) => session.id == sessionId)
        .blocks;
  }

  Set<MovementId> _requiredMaximums(
    ResolvedCycleDefinition definition,
    CycleRequest request,
  ) {
    final result = <MovementId>{};
    for (final week in definition.weeks) {
      for (final sessionId in request.sessionOrder) {
        for (final block in _blocksFor(week, sessionId)) {
          if (block.sets.any(
            (set) =>
                set.load is TrainingMaxPercentageLoad ||
                set.load is ParameterizedTrainingMaxPercentageLoad ||
                set.load is OneRepMaxPercentageLoad ||
                set.load is RelativeSetLoad,
          )) {
            result.add(block.movementId ?? sessionId);
          }
        }
      }
    }
    return result;
  }

  DateTime _onOrAfter(DateTime date, int weekday) {
    final days = (weekday - date.weekday + 7) % 7;
    return date.add(Duration(days: days));
  }
}
