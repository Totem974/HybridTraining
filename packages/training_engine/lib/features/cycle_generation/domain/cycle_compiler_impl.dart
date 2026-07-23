import 'cycle_calculations.dart';
import 'cycle_contract.dart';
import 'cycle_execution_options.dart';
import 'cycle_generation_error.dart';
import 'cycle_schedule_contract.dart';
import 'cycle_schedule_mode.dart';
import 'cycle_v2_primitives.dart';

final class CycleCompilerImpl implements CycleCompiler, ScheduledCycleCompiler {
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
    final effectiveDefinition = _applyWeekOrder(
      definition,
      options.mainWork.weekOrder,
    );
    _validateOptions(effectiveDefinition, request, options);
    final requiredMaxes = _requiredMaximums(effectiveDefinition, request);
    final maxes = _resolveMaximums(requiredMaxes, request);

    var cursor = DateTime(
      request.startDate.year,
      request.startDate.month,
      request.startDate.day,
    );
    final weeks = <GeneratedWeek>[];
    for (final week in effectiveDefinition.weeks) {
      final sessions = <GeneratedSession>[];
      for (var index = 0; index < request.sessionOrder.length; index++) {
        final movement = request.sessionOrder[index];
        final blocks = _effectiveBlocks(
          effectiveDefinition,
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

  @override
  GeneratedCycle compileScheduled({
    required ResolvedCycleDefinition definition,
    required ResolvedCycleSchedule schedule,
    required CycleScheduleSelection selection,
    required CycleRequest request,
  }) {
    _validateScheduled(definition, schedule, selection, request);
    final options = request.cycleOptions.normalized();
    final effectiveDefinition = _applyWeekOrder(
      definition,
      options.mainWork.weekOrder,
    );
    _validateOptions(effectiveDefinition, request, options);
    final layout = _buildScheduleLayout(
      effectiveDefinition,
      schedule,
      selection,
      request.includeDeload,
    );
    final maxes = _resolveMaximums(
      _requiredScheduledMaximums(effectiveDefinition, layout, request, options),
      request,
    );

    var cursor = DateTime(
      request.startDate.year,
      request.startDate.month,
      request.startDate.day,
    );
    final weeks = <GeneratedWeek>[];
    for (final displayedWeek in layout) {
      final sessions = <GeneratedSession>[];
      for (var dayIndex = 0; dayIndex < displayedWeek.days.length; dayIndex++) {
        final day = displayedWeek.days[dayIndex];
        cursor = _onOrAfter(cursor, selection.trainingDays[dayIndex]);
        final blocks = <GeneratedBlock>[];
        for (final source in day.sources) {
          final effective = _effectiveBlocks(
            effectiveDefinition,
            source.week,
            MovementId(source.template.id.value),
            request,
            options,
          );
          blocks.addAll(
            _compileBlocks(
              effective,
              source.template.movementIds.first,
              maxes,
              request,
            ),
          );
        }
        if (blocks.isNotEmpty) {
          sessions.add(
            GeneratedSession(
              id: '${request.cycleId}-w${displayedWeek.number}-s${dayIndex + 1}',
              date: cursor,
              movementId: MovementId(day.sources.first.template.id.value),
              blocks: List.unmodifiable(blocks),
            ),
          );
        }
        cursor = cursor.add(const Duration(days: 1));
      }
      if (sessions.isNotEmpty) {
        weeks.add(
          GeneratedWeek(
            number: displayedWeek.number,
            sessions: List.unmodifiable(sessions),
          ),
        );
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
      weeks: List.unmodifiable(weeks),
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
    final options = request.cycleOptions.normalized().mainWork;
    final indices = List<int>.generate(block.sets.length, (index) => index);
    final orderedIndices =
        _isMainWork(block) && options.setOrder == WorkSetOrder.bastard
        ? indices.reversed
        : indices;
    final plusTarget = _isMainWork(block)
        ? _heaviestMainWorkSetIndex(block)
        : null;
    for (final index in orderedIndices) {
      final definition = _effectiveMainWorkSet(
        block.sets[index],
        index: index,
        plusTarget: plusTarget,
        mode: options.plusSet,
      );
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
    final base = _warmUpBaseWeight(baseLoads.single, request);
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

  Weight? _warmUpBaseWeight(WarmUpBaseLoad load, CycleRequest request) {
    final fixed = load.fixedWeight;
    if (fixed != null) {
      if (fixed.unit != request.unit) {
        throw const CycleGenerationException(
          CycleGenerationErrorCode.unitMismatch,
          'A fixed warm-up base must use the request unit.',
        );
      }
      return fixed;
    }
    final warmUp = request.cycleOptions.normalized().warmUp;
    return switch (load.region!) {
      WarmUpBodyRegion.upperBody => warmUp.upperBodyBaseWeight,
      WarmUpBodyRegion.lowerBody => warmUp.lowerBodyBaseWeight,
    };
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
      case UnconfiguredLoad():
        throw const CycleGenerationException(
          CycleGenerationErrorCode.invalidCycleOptions,
          'An unconfigured load cannot be compiled.',
        );
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
      case final WarmUpBaseLoad warmUpBase:
        desired = _warmUpBaseWeight(warmUpBase, request);
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
      case OnePlusSetInput():
        throw const CycleGenerationException(
          CycleGenerationErrorCode.missingMaximum,
          'A 1+ set input cannot resolve a 1RM percentage.',
        );
    }
  }

  Map<MovementId, Weight> _resolveMaximums(
    Set<MovementId> required,
    CycleRequest request,
  ) {
    final maxes = <MovementId, Weight>{};
    for (final movement in required) {
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
    return maxes;
  }

  ResolvedCycleDefinition _applyWeekOrder(
    ResolvedCycleDefinition definition,
    WorkWeekOrder order,
  ) {
    if (order == WorkWeekOrder.catalog) return definition;
    final transformed = <WeekDefinition>[];
    for (final target in definition.weeks) {
      final sourceNumber = target.origin?.sourceWeekNumber ?? target.number;
      final desiredNumber = switch (order) {
        WorkWeekOrder.catalog => sourceNumber,
        WorkWeekOrder.fiveThreeOne => sourceNumber,
        WorkWeekOrder.threeFiveOne => switch (sourceNumber) {
          1 => 2,
          2 => 1,
          _ => sourceNumber,
        },
      };
      final donors = definition.weeks.where(
        (candidate) =>
            _samePhase(target, candidate) &&
            (candidate.origin?.sourceWeekNumber ?? candidate.number) ==
                desiredNumber,
      );
      final donor = donors.length == 1 ? donors.single : target;
      transformed.add(
        WeekDefinition(
          number: target.number,
          blocks: List.unmodifiable(donor.blocks),
          sessions: List.unmodifiable(donor.sessions),
          origin: target.origin,
        ),
      );
    }
    return ResolvedCycleDefinition(
      catalogVersion: definition.catalogVersion,
      templateId: definition.templateId,
      variantId: definition.variantId,
      sessionMovementIds: definition.sessionMovementIds,
      weeks: List.unmodifiable(transformed),
      sourceReference: definition.sourceReference,
      optionRecipes: definition.optionRecipes,
      scheduleReference: definition.scheduleReference,
      scheduleMode: definition.scheduleMode,
      assistancePlanIds: definition.assistancePlanIds,
      conditioningDefinitionIds: definition.conditioningDefinitionIds,
    );
  }

  bool _samePhase(WeekDefinition left, WeekDefinition right) {
    final leftOrigin = left.origin;
    final rightOrigin = right.origin;
    if (leftOrigin == null || rightOrigin == null) {
      return leftOrigin == null && rightOrigin == null;
    }
    return leftOrigin.phaseId == rightOrigin.phaseId &&
        leftOrigin.phaseIteration == rightOrigin.phaseIteration;
  }

  PrescribedSetDefinition _effectiveMainWorkSet(
    PrescribedSetDefinition definition, {
    required int index,
    required int? plusTarget,
    required PlusSetMode mode,
  }) {
    if (plusTarget == null || mode == PlusSetMode.catalog) return definition;
    final repetitions = definition.repetitions;
    RepetitionPrescription? replacement;
    switch (mode) {
      case PlusSetMode.catalog:
        break;
      case PlusSetMode.disabled:
        replacement = switch (repetitions) {
          AmrapRepetitions(:final minimum) => FixedRepetitions(minimum ?? 1),
          PlusSetRepetitions(:final minimum) => FixedRepetitions(minimum),
          _ => null,
        };
      case PlusSetMode.enabled:
        if (index == plusTarget) {
          switch (repetitions) {
            case AmrapRepetitions(:final minimum):
              replacement = PlusSetRepetitions(minimum ?? 1);
            default:
              break;
          }
        }
    }
    if (replacement == null) return definition;
    return PrescribedSetDefinition(
      repetitions: replacement,
      load: definition.load,
      execution: definition.execution,
      runtimeGates: definition.runtimeGates,
    );
  }

  int? _heaviestMainWorkSetIndex(BlockDefinition block) {
    int? bestIndex;
    var bestBasisPoints = -1;
    for (final entry in block.sets.indexed) {
      final basisPoints = switch (entry.$2.load) {
        TrainingMaxPercentageLoad(:final percentage) => percentage.basisPoints,
        ParameterizedTrainingMaxPercentageLoad(:final defaultValue) =>
          defaultValue.basisPoints,
        OneRepMaxPercentageLoad(:final percentage) => percentage.basisPoints,
        _ => null,
      };
      if (basisPoints != null && basisPoints >= bestBasisPoints) {
        bestBasisPoints = basisPoints;
        bestIndex = entry.$1;
      }
    }
    return bestIndex ?? (block.sets.isEmpty ? null : block.sets.length - 1);
  }

  bool _isMainWork(BlockDefinition block) =>
      const {'main_work', 'main work'}.contains(block.role);

  void _validate(ResolvedCycleDefinition definition, CycleRequest request) {
    _validateCommon(request);
    if (request.trainingDays.length != request.sessionOrder.length) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidTrainingDays,
        'One weekday from 1 to 7 is required for every session.',
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
  }

  void _validateCommon(CycleRequest request) {
    if (request.cycleId.trim().isEmpty) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.emptyCycleId,
        'Cycle id cannot be empty.',
      );
    }
    if (request.trainingDays.isEmpty ||
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

  void _validateScheduled(
    ResolvedCycleDefinition definition,
    ResolvedCycleSchedule schedule,
    CycleScheduleSelection selection,
    CycleRequest request,
  ) {
    _validateCommon(request);
    if (!_sameInts(request.trainingDays, selection.trainingDays) ||
        !_sameSessionOrder(request.sessionOrder, selection.sessionOrder)) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidSessionOrder,
        'CycleRequest and CycleScheduleSelection must describe the same schedule.',
      );
    }
    if (schedule.sessions.isEmpty ||
        schedule.sessions.any((session) => session.movementIds.isEmpty) ||
        schedule.allowedFrequencies.isEmpty) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidScheduleDefinition,
        'A resolved schedule requires sessions, movements, and frequencies.',
      );
    }
    if (schedule.allowedFrequencies.any(
          (frequency) => frequency < 1 || frequency > 7,
        ) ||
        !schedule.allowedFrequencies.contains(selection.trainingDays.length)) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidScheduleFrequency,
        'The selected weekly frequency is not allowed by this schedule.',
      );
    }
    final templates = {
      for (final session in schedule.sessions) session.id.value: session,
    };
    if (templates.length != schedule.sessions.length) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidScheduleDefinition,
        'Schedule session identifiers must be unique.',
      );
    }
    final selected = selection.sessionOrder.map((id) => id.value).toList();
    if (selected.toSet().length != selected.length ||
        selected.length != templates.length ||
        !selected.toSet().containsAll(templates.keys)) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidSessionOrder,
        'Session order must contain every schedule session exactly once.',
      );
    }
    if (definition.scheduleReference case final reference?) {
      if (reference.id != schedule.id) {
        throw const CycleGenerationException(
          CycleGenerationErrorCode.invalidScheduleDefinition,
          'The resolved schedule does not match the cycle definition.',
        );
      }
    }
    if (definition.scheduleMode case final mode?) {
      if (mode != schedule.mode) {
        throw const CycleGenerationException(
          CycleGenerationErrorCode.invalidScheduleDefinition,
          'The resolved schedule mode does not match the cycle definition.',
        );
      }
    }
    final frequency = selection.trainingDays.length;
    switch (schedule.mode) {
      case CycleScheduleMode.fixed || CycleScheduleMode.multiMovement:
        if (frequency != schedule.sessions.length ||
            schedule.finiteSlots.isNotEmpty) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.invalidScheduleFrequency,
            'Fixed and multi-movement schedules require one day per session.',
          );
        }
      case CycleScheduleMode.rotating:
        if (frequency > schedule.sessions.length ||
            schedule.finiteSlots.isNotEmpty) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.invalidScheduleFrequency,
            'A rotating schedule cannot have more days than sessions.',
          );
        }
      case CycleScheduleMode.finite:
        if (schedule.finiteSlots.isEmpty) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.invalidScheduleDefinition,
            'A finite schedule requires an explicit finite sequence.',
          );
        }
    }

    final weeks = <int, WeekDefinition>{};
    for (final week in definition.weeks) {
      if (weeks.containsKey(week.number)) {
        throw const CycleGenerationException(
          CycleGenerationErrorCode.invalidScheduleDefinition,
          'Definition week numbers must be unique.',
        );
      }
      weeks[week.number] = week;
    }
    if (weeks.isEmpty) {
      throw const CycleGenerationException(
        CycleGenerationErrorCode.invalidScheduleDefinition,
        'A scheduled cycle requires at least one definition week.',
      );
    }
    void validateSource(int weekNumber, SessionId sessionId) {
      final week = weeks[weekNumber];
      if (week == null ||
          week.sessions
                  .where((session) => session.id.value == sessionId.value)
                  .length !=
              1) {
        throw const CycleGenerationException(
          CycleGenerationErrorCode.invalidScheduleDefinition,
          'Every scheduled source must resolve to exactly one session.',
        );
      }
    }

    if (schedule.mode == CycleScheduleMode.finite) {
      for (final slot in schedule.finiteSlots) {
        if (slot.sources.isEmpty) {
          throw const CycleGenerationException(
            CycleGenerationErrorCode.invalidScheduleDefinition,
            'Finite schedule slots cannot be empty.',
          );
        }
        for (final source in slot.sources) {
          if (!templates.containsKey(source.sessionId.value)) {
            throw const CycleGenerationException(
              CycleGenerationErrorCode.invalidScheduleDefinition,
              'A finite schedule references an unknown session.',
            );
          }
          validateSource(source.definitionWeekNumber, source.sessionId);
        }
      }
    } else {
      for (final week in definition.weeks) {
        for (final sessionId in selection.sessionOrder) {
          validateSource(week.number, sessionId);
        }
      }
    }
  }

  List<_ScheduledWeek> _buildScheduleLayout(
    ResolvedCycleDefinition definition,
    ResolvedCycleSchedule schedule,
    CycleScheduleSelection selection,
    bool includeDeload,
  ) {
    final templates = {
      for (final template in schedule.sessions) template.id.value: template,
    };
    final weeks = {for (final week in definition.weeks) week.number: week};
    _ScheduledSource source(WeekDefinition week, SessionId sessionId) =>
        _ScheduledSource(week: week, template: templates[sessionId.value]!);

    switch (schedule.mode) {
      case CycleScheduleMode.fixed || CycleScheduleMode.multiMovement:
        return [
              for (final week in definition.weeks)
                if (includeDeload || !_isDeloadWeek(week))
                  _ScheduledWeek(
                    number: 0,
                    days: [
                      for (final sessionId in selection.sessionOrder)
                        _ScheduledDay(sources: [source(week, sessionId)]),
                    ],
                  ),
            ].indexed
            .map(
              (entry) =>
                  _ScheduledWeek(number: entry.$1 + 1, days: entry.$2.days),
            )
            .toList(growable: false);
      case CycleScheduleMode.rotating:
        return _rotatingLayout(
          definition.weeks,
          selection,
          source,
          includeDeload,
        );
      case CycleScheduleMode.finite:
        final slots = <_ScheduledDay>[];
        for (final slot in schedule.finiteSlots) {
          final sources = [
            for (final item in slot.sources)
              if (includeDeload ||
                  !_isDeloadWeek(weeks[item.definitionWeekNumber]!))
                source(weeks[item.definitionWeekNumber]!, item.sessionId),
          ];
          if (sources.isNotEmpty) {
            slots.add(_ScheduledDay(sources: List.unmodifiable(sources)));
          }
        }
        final result = <_ScheduledWeek>[];
        final frequency = selection.trainingDays.length;
        for (var offset = 0; offset < slots.length; offset += frequency) {
          result.add(
            _ScheduledWeek(
              number: result.length + 1,
              days: List.unmodifiable(
                slots.sublist(
                  offset,
                  (offset + frequency).clamp(0, slots.length),
                ),
              ),
            ),
          );
        }
        return List.unmodifiable(result);
    }
  }

  List<_ScheduledWeek> _rotatingLayout(
    List<WeekDefinition> sourceWeeks,
    CycleScheduleSelection selection,
    _ScheduledSource Function(WeekDefinition, SessionId) source,
    bool includeDeload,
  ) {
    final result = <_ScheduledWeek>[];
    final work = <WeekDefinition>[];
    final frequency = selection.trainingDays.length;

    void flushWork() {
      if (work.isEmpty) return;
      final sources = [
        for (final week in work)
          for (final sessionId in selection.sessionOrder)
            source(week, sessionId),
      ];
      for (var offset = 0; offset < sources.length; offset += frequency) {
        result.add(
          _ScheduledWeek(
            number: result.length + 1,
            days: [
              for (
                var index = offset;
                index < sources.length && index < offset + frequency;
                index++
              )
                _ScheduledDay(sources: [sources[index]]),
            ],
          ),
        );
      }
      work.clear();
    }

    for (final week in sourceWeeks) {
      if (!_isDeloadWeek(week)) {
        work.add(week);
        continue;
      }
      flushWork();
      if (!includeDeload) continue;
      final count = selection.sessionOrder.length;
      final quotient = count ~/ frequency;
      final remainder = count % frequency;
      var cursor = 0;
      final days = <_ScheduledDay>[];
      for (var day = 0; day < frequency; day++) {
        final size = quotient + (day < remainder ? 1 : 0);
        final group = selection.sessionOrder.sublist(cursor, cursor + size);
        cursor += size;
        days.add(
          _ScheduledDay(
            sources: [for (final sessionId in group) source(week, sessionId)],
          ),
        );
      }
      result.add(
        _ScheduledWeek(
          number: result.length + 1,
          days: List.unmodifiable(days),
        ),
      );
    }
    flushWork();
    return List.unmodifiable(result);
  }

  bool _isDeloadWeek(WeekDefinition week) => [
    ...week.blocks,
    for (final session in week.sessions) ...session.blocks,
  ].any((block) => block.role == 'deload');

  bool _sameInts(List<int> left, List<int> right) =>
      left.length == right.length &&
      left.indexed.every((entry) => entry.$2 == right[entry.$1]);

  bool _sameSessionOrder(List<MovementId> legacy, List<SessionId> selected) =>
      legacy.length == selected.length &&
      legacy.indexed.every(
        (entry) => entry.$2.value == selected[entry.$1].value,
      );

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
    final isSourceDeloadWeek = blocks.any((block) => block.role == 'deload');
    // `includeDeload` remains the v1 compatibility authority. The bridge
    // normalizer keeps it synchronized with the typed deload option when that
    // option is present, while old snapshots can still rely on this field.
    if (isSourceDeloadWeek && !request.includeDeload) {
      return const <BlockDefinition>[];
    }
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
    final sessionMovements = _blocksFor(
      week,
      sessionId,
    ).map((block) => block.movementId).whereType<MovementId>().toSet();
    if (sessionMovements.length <= 1) return blocks;
    return [
      for (final block in blocks)
        if (block.movementId != null)
          block
        else
          for (final movement in sessionMovements)
            BlockDefinition(
              id: block.id,
              role: block.role,
              sets: block.sets,
              movementId: movement,
            ),
    ];
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
          if (_requiresMaximum(block)) {
            result.add(block.movementId ?? sessionId);
          }
        }
      }
    }
    return result;
  }

  Set<MovementId> _requiredScheduledMaximums(
    ResolvedCycleDefinition definition,
    List<_ScheduledWeek> layout,
    CycleRequest request,
    CycleExecutionOptions options,
  ) {
    final result = <MovementId>{};
    for (final week in layout) {
      for (final day in week.days) {
        for (final source in day.sources) {
          final sessionId = MovementId(source.template.id.value);
          for (final block in _effectiveBlocks(
            definition,
            source.week,
            sessionId,
            request,
            options,
          )) {
            if (_requiresMaximum(block)) {
              result.add(block.movementId ?? source.template.movementIds.first);
            }
          }
        }
      }
    }
    return result;
  }

  bool _requiresMaximum(BlockDefinition block) => block.sets.any(
    (set) =>
        set.load is TrainingMaxPercentageLoad ||
        set.load is ParameterizedTrainingMaxPercentageLoad ||
        set.load is OneRepMaxPercentageLoad ||
        set.load is RelativeSetLoad ||
        set.load is MainWorkSetPlusLoad ||
        set.load is TrainingMaxRampLoad,
  );

  DateTime _onOrAfter(DateTime date, int weekday) {
    final days = (weekday - date.weekday + 7) % 7;
    return date.add(Duration(days: days));
  }
}

final class _ScheduledSource {
  const _ScheduledSource({required this.week, required this.template});

  final WeekDefinition week;
  final ScheduleSessionTemplate template;
}

final class _ScheduledDay {
  const _ScheduledDay({required this.sources});

  final List<_ScheduledSource> sources;
}

final class _ScheduledWeek {
  const _ScheduledWeek({required this.number, required this.days});

  final int number;
  final List<_ScheduledDay> days;
}
