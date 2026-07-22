import 'cycle_calculations.dart';
import 'cycle_contract.dart';
import 'cycle_execution_options.dart';
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
    final options = request.cycleOptions.normalized();
    _validateOptions(definition, request, options);
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
        final blocks = _effectiveBlocks(
          definition,
          week,
          movement,
          request,
          options,
        );
        if (blocks.isEmpty) continue;
        cursor = _onOrAfter(cursor, request.trainingDays[index]);
        sessions.add(
          GeneratedSession(
            id: '${request.cycleId}-w${week.number}-s${index + 1}',
            date: cursor,
            movementId: movement,
            blocks: _compileBlocks(blocks, movement, maxes, request),
          ),
        );
        cursor = cursor.add(const Duration(days: 1));
      }
      if (sessions.isNotEmpty) {
        weeks.add(GeneratedWeek(number: week.number, sessions: sessions));
      }
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
      GeneratedBlock(
        id: block.id,
        role: block.role,
        movementId: block.movementId ?? sessionMovement,
        sets: _compileSets(
          block,
          definitions,
          block.movementId ?? sessionMovement,
          maxes[block.movementId ?? sessionMovement],
          request.maxInputs[block.movementId ?? sessionMovement],
          request,
        ),
      ),
  ];

  List<GeneratedSet> _compileSets(
    BlockDefinition block,
    List<BlockDefinition> sessionBlocks,
    MovementId movement,
    Weight? trainingMax,
    TrainingMaxInput? maxInput,
    CycleRequest request,
  ) {
    final result = <GeneratedSet>[];
    for (final definition in block.sets) {
      if (definition.load case final TrainingMaxRampLoad ramp) {
        result.addAll(
          _compileRampSets(
            ramp,
            definition.repetitions,
            block,
            sessionBlocks,
            movement,
            trainingMax,
            maxInput,
            request,
            result.length,
          ),
        );
      } else {
        result.add(
          _compileSet(
            result.length,
            definition,
            sessionBlocks,
            movement,
            trainingMax,
            maxInput,
            request,
          ),
        );
      }
    }
    return result;
  }

  List<GeneratedSet> _compileRampSets(
    TrainingMaxRampLoad ramp,
    RepetitionPrescription repetitions,
    BlockDefinition block,
    List<BlockDefinition> sessionBlocks,
    MovementId movement,
    Weight? trainingMax,
    TrainingMaxInput? maxInput,
    CycleRequest request,
    int startIndex,
  ) {
    if (trainingMax == null || repetitions is! PercentageThresholdRepetitions) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidCycleOptions,
        'A TM ramp requires a training max and percentage thresholds.',
      );
    }
    final baseLoads = block.sets
        .where((set) => set.load is WarmUpBaseLoad)
        .map((set) => set.load as WarmUpBaseLoad)
        .toList(growable: false);
    if (baseLoads.length != 1) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidCycleOptions,
        'A TM ramp requires exactly one warm-up base in its block.',
      );
    }
    final warmUp = request.cycleOptions.normalized().warmUp;
    final base = switch (baseLoads.single.region) {
      WarmUpBodyRegion.upperBody => warmUp.upperBodyBaseWeight,
      WarmUpBodyRegion.lowerBody => warmUp.lowerBodyBaseWeight,
    };
    if (base == null) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidCycleOptions,
        'A TM ramp requires its declared warm-up base.',
      );
    }
    final step = loadCalculator.percentage(
      trainingMax,
      Percentage(ramp.stepBasisPoints),
    );
    final desiredLoads = <Weight>[];
    switch (ramp.anchor) {
      case TrainingMaxRampAnchor.beforeMainWork:
        final main = loadCalculator.percentage(
          trainingMax,
          _heaviestMainWorkTarget(
            sessionBlocks,
            movement,
            request,
            roles: const {'main_work', 'main work', 'deload'},
          ),
        );
        var current = main.centiUnits - step.centiUnits;
        final lower =
            base.centiUnits +
            (step.centiUnits * ramp.lowerBoundStepFractionBasisPoints! +
                    5000) ~/
                10000;
        while (current > lower) {
          desiredLoads.add(Weight(current, request.unit));
          current -= step.centiUnits;
        }
        desiredLoads.sort(
          (left, right) => left.centiUnits.compareTo(right.centiUnits),
        );
      case TrainingMaxRampAnchor.warmUpBase:
        var current =
            (base.centiUnits * ramp.anchorMultiplierBasisPoints! + 5000) ~/
            10000;
        final maximum =
            (trainingMax.centiUnits * ramp.maximumExclusiveBasisPoints! +
                5000) ~/
            10000;
        while (current < maximum) {
          desiredLoads.add(Weight(current, request.unit));
          current += step.centiUnits;
        }
    }
    return [
      for (var offset = 0; offset < desiredLoads.length; offset++)
        _compileSet(
          startIndex + offset,
          PrescribedSetDefinition(
            repetitions: FixedRepetitions(
              _rampRepetitions(desiredLoads[offset], trainingMax, repetitions),
            ),
            load: FixedLoad(desiredLoads[offset]),
          ),
          sessionBlocks,
          movement,
          trainingMax,
          maxInput,
          request,
        ),
    ];
  }

  int _rampRepetitions(
    Weight desired,
    Weight trainingMax,
    PercentageThresholdRepetitions prescription,
  ) {
    for (final threshold in prescription.thresholds) {
      final maximum =
          (trainingMax.centiUnits * threshold.maximumBasisPoints + 5000) ~/
          10000;
      if (desired.centiUnits <= maximum) return threshold.count;
    }
    throw const CycleGenerationException(
      CycleGenerationErrorCode.invalidCycleOptions,
      'Ramp repetition thresholds do not cover the generated load.',
    );
  }

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
      case MainWorkSetPlusLoad(:final cumulativeIncreaseBasisPoints):
        if (trainingMax == null) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.missingMaximum,
            'A training max is required for a Joker load.',
          );
        }
        final target = _heaviestMainWorkTarget(
          sessionBlocks,
          movement,
          request,
        );
        percentage = target.basisPoints + cumulativeIncreaseBasisPoints;
        desired = loadCalculator.percentage(
          trainingMax,
          Percentage(percentage),
        );
      case WarmUpBaseLoad(:final region):
        final warmUp = request.cycleOptions.normalized().warmUp;
        desired = switch (region) {
          WarmUpBodyRegion.upperBody => warmUp.upperBodyBaseWeight,
          WarmUpBodyRegion.lowerBody => warmUp.lowerBodyBaseWeight,
        };
      case TrainingMaxRampLoad():
        throw const CycleGenerationException(
          CycleGenerationErrorCode.invalidCycleOptions,
          'TM ramps must be expanded at block level.',
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

  Percentage _heaviestMainWorkTarget(
    List<BlockDefinition> sessionBlocks,
    MovementId movement,
    CycleRequest request, {
    Set<String> roles = const {'main_work', 'main work'},
  }) {
    final values = <Percentage>[];
    for (final block in sessionBlocks.where(
      (block) =>
          roles.contains(block.role) &&
          (block.movementId == null || block.movementId == movement),
    )) {
      for (final set in block.sets) {
        switch (set.load) {
          case TrainingMaxPercentageLoad(:final percentage):
            values.add(percentage);
          case ParameterizedTrainingMaxPercentageLoad(
            :final parameterId,
            :final defaultValue,
            :final minimum,
            :final maximum,
          ):
            final value =
                request
                    .percentageParametersByMovement[movement]?[parameterId] ??
                request.percentageParameters[parameterId] ??
                defaultValue;
            if (value.basisPoints < minimum.basisPoints ||
                value.basisPoints > maximum.basisPoints) {
              throw CycleGenerationException(
                CycleGenerationErrorCode.invalidTrainingMaxRatio,
                'Parameter $parameterId is outside its declared range.',
              );
            }
            values.add(value);
          default:
            break;
        }
      }
    }
    if (values.isEmpty) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.missingRelativeLoadTarget,
        'Joker Sets require a TM-percentage main-work set.',
      );
    }
    values.sort((a, b) => b.basisPoints.compareTo(a.basisPoints));
    return values.first;
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

  void _validateOptions(
    ResolvedCycleDefinition definition,
    CycleRequest request,
    CycleExecutionOptions options,
  ) {
    final recipes = definition.optionRecipes;
    if (options.warmUp.enabled) {
      final type = options.warmUp.type;
      if (type == null || !recipes.warmUp.containsKey(type)) {
        throw const CycleGenerationException(
          CycleGenerationErrorCode.invalidCycleOptions,
          'The selected warm-up recipe is not available.',
        );
      }
      if (type == WarmUpType.beyond) {
        final bases = [
          options.warmUp.upperBodyBaseWeight,
          options.warmUp.lowerBodyBaseWeight,
        ];
        if (bases.any(
          (weight) =>
              weight == null ||
              weight.centiUnits <= 0 ||
              weight.unit != request.unit,
        )) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.invalidCycleOptions,
            'Beyond warm-up requires positive upper/lower bases in the request unit.',
          );
        }
      }
      _validateRecipeUnit(recipes.warmUp[type]!, request.unit, 'warm-up');
    }
    if (options.joker.enabled) {
      final ceiling = options.joker.ceilingBasisPoints;
      final recipe = recipes.joker;
      if (ceiling == null ||
          ceiling < 500 ||
          ceiling > 3000 ||
          ceiling % 500 != 0 ||
          recipe == null) {
        throw const CycleGenerationException(
          CycleGenerationErrorCode.invalidCycleOptions,
          'Joker Sets require a recipe and a 5%..30% ceiling.',
        );
      }
      if (recipe.blockId.trim().isEmpty ||
          recipe.steps.length < ceiling ~/ 500) {
        throw const CycleGenerationException(
          CycleGenerationErrorCode.invalidCycleOptions,
          'The Joker recipe does not cover the selected ceiling.',
        );
      }
      for (var index = 0; index < recipe.steps.length; index++) {
        if (recipe.steps[index].cumulativeIncreaseBasisPoints !=
            (index + 1) * 500) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.invalidCycleOptions,
            'Joker recipe steps must be cumulative 5% increments.',
          );
        }
      }
    }
    if (options.deload.enabled) {
      final type = options.deload.type;
      if (type == null || !recipes.deload.containsKey(type)) {
        throw const CycleGenerationException(
          CycleGenerationErrorCode.invalidCycleOptions,
          'The selected deload recipe is not available.',
        );
      }
      _validateRecipeUnit(recipes.deload[type]!, request.unit, 'deload');
    }
  }

  void _validateRecipeUnit(
    ResolvedBlockRecipe recipe,
    WeightUnit unit,
    String label,
  ) {
    if (recipe.overlaysFor(unit).isEmpty) {
      throw CycleGenerationException(
        CycleGenerationErrorCode.invalidCycleOptions,
        'The $label recipe has no ${unit.name} prescription.',
      );
    }
  }

  List<BlockDefinition> _effectiveBlocks(
    ResolvedCycleDefinition definition,
    WeekDefinition week,
    MovementId sessionId,
    CycleRequest request,
    CycleExecutionOptions options,
  ) {
    final recipes = definition.optionRecipes;
    var blocks = List<BlockDefinition>.of(_blocksFor(week, sessionId));
    final deloadType = options.deload.type;
    final selectedDeloadBlocks = options.deload.enabled && deloadType != null
        ? _overlayBlocks(
            recipes.deload[deloadType]!,
            request.unit,
            week.number,
            sessionId,
          )
        : const <BlockDefinition>[];
    final isDeloadWeek =
        blocks.any((block) => block.role == 'deload') ||
        selectedDeloadBlocks.isNotEmpty;

    if (recipes.warmUp.isNotEmpty) {
      blocks.removeWhere((block) => block.role == 'warm_up');
      final type = options.warmUp.type;
      final skip =
          isDeloadWeek &&
          options.deload.enabled &&
          options.deload.type != DeloadType.highIntensity &&
          options.deload.skipWarmUp;
      if (options.warmUp.enabled && !skip && type != null) {
        blocks.insertAll(
          0,
          _overlayBlocks(
            recipes.warmUp[type]!,
            request.unit,
            week.number,
            sessionId,
          ),
        );
      }
    }

    if (recipes.deload.isNotEmpty) {
      blocks.removeWhere((block) => block.role == 'deload');
      if (options.deload.enabled && deloadType != null) {
        blocks.addAll(selectedDeloadBlocks);
      }
    } else if (!request.includeDeload) {
      blocks.removeWhere((block) => block.role == 'deload');
    }

    if (options.joker.enabled) {
      final recipe = recipes.joker!;
      final steps = recipe.steps.take(options.joker.ceilingBasisPoints! ~/ 500);
      final withJokers = <BlockDefinition>[];
      for (final block in blocks) {
        withJokers.add(block);
        if (const {'main_work', 'main work'}.contains(block.role)) {
          withJokers.add(
            BlockDefinition(
              id: '${recipe.blockId}-${block.id}',
              role: 'joker',
              movementId: block.movementId,
              sets: [
                for (final step in steps)
                  PrescribedSetDefinition(
                    repetitions: step.repetitions,
                    load: MainWorkSetPlusLoad(
                      step.cumulativeIncreaseBasisPoints,
                    ),
                  ),
              ],
            ),
          );
        }
      }
      blocks = withJokers;
    }
    return blocks;
  }

  List<BlockDefinition> _overlayBlocks(
    ResolvedBlockRecipe recipe,
    WeightUnit unit,
    int weekNumber,
    MovementId sessionId,
  ) => [
    for (final overlay in recipe.overlaysFor(unit))
      if (overlay.weekNumber == weekNumber && overlay.sessionId == sessionId)
        ...overlay.blocks,
  ];

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
    final options = request.cycleOptions.normalized();
    for (final week in definition.weeks) {
      for (final sessionId in request.sessionOrder) {
        for (final block in _effectiveBlocks(
          definition,
          week,
          sessionId,
          request,
          options,
        )) {
          if (block.sets.any(
            (set) =>
                set.load is TrainingMaxPercentageLoad ||
                set.load is ParameterizedTrainingMaxPercentageLoad ||
                set.load is OneRepMaxPercentageLoad ||
                set.load is RelativeSetLoad ||
                set.load is MainWorkSetPlusLoad ||
                set.load is TrainingMaxRampLoad,
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
