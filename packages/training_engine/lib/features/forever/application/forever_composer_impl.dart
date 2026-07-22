import '../../cycle_generation/domain/cycle_contract.dart';
import '../domain/forever_contract.dart';

enum ForeverCompositionErrorCode {
  definitionMismatch,
  invalidDefinition,
  missingSlotRequest,
  unexpectedSlotRequest,
  requiredSlotDisabled,
  incompatibleCycle,
  resolvedCycleMismatch,
  invalidTrainingMax,
  emptyGeneratedCycle,
}

final class ForeverCompositionException implements Exception {
  const ForeverCompositionException(this.code, this.message);

  final ForeverCompositionErrorCode code;
  final String message;

  @override
  String toString() => 'ForeverCompositionException(${code.name}): $message';
}

final class ForeverComposerImpl
    implements ForeverComposer, SyncForeverComposer {
  const ForeverComposerImpl({
    required this.cycleDefinitionResolver,
    required this.cycleCompiler,
    this.syncCycleDefinitionResolver,
  });

  const ForeverComposerImpl.sync({
    required SyncForeverCycleDefinitionResolver cycleDefinitionResolver,
    required this.cycleCompiler,
  }) : cycleDefinitionResolver = null,
       syncCycleDefinitionResolver = cycleDefinitionResolver;

  final ForeverCycleDefinitionResolver? cycleDefinitionResolver;
  final SyncForeverCycleDefinitionResolver? syncCycleDefinitionResolver;
  final CycleCompiler cycleCompiler;

  @override
  Future<GeneratedMacrocycle> compose(
    ResolvedForeverDefinition definition,
    ForeverRequest request,
  ) async {
    final resolver = cycleDefinitionResolver;
    if (resolver == null) {
      throw StateError('compose requires a ForeverCycleDefinitionResolver.');
    }
    final steps = _plan(definition, request);
    final resolvedSteps = <_ResolvedCompositionStep>[];
    for (final step in steps) {
      resolvedSteps.add(
        _ResolvedCompositionStep(
          step,
          await resolver.resolve(step.request.cycle),
        ),
      );
    }
    return _composeResolved(definition, request, resolvedSteps);
  }

  @override
  GeneratedMacrocycle composeSync(
    ResolvedForeverDefinition definition,
    ForeverRequest request,
  ) {
    final resolver = syncCycleDefinitionResolver;
    if (resolver == null) {
      throw StateError(
        'composeSync requires a SyncForeverCycleDefinitionResolver.',
      );
    }
    final steps = _plan(definition, request);
    return _composeResolved(definition, request, [
      for (final step in steps)
        _ResolvedCompositionStep(
          step,
          resolver.resolveSync(step.request.cycle),
        ),
    ]);
  }

  List<_CompositionStep> _plan(
    ResolvedForeverDefinition definition,
    ForeverRequest request,
  ) {
    _validateDefinitionAndRequest(definition, request);
    final steps = <_CompositionStep>[];
    for (final phase in definition.phases) {
      for (final slot in phase.slots) {
        final slotRequest = request.slotRequests[slot.id]!;
        if (!slotRequest.enabled) continue;
        _validateCycleChoice(slot, slotRequest.cycle);
        for (var repetition = 0; repetition < slot.repeatCount; repetition++) {
          steps.add(_CompositionStep(slot, slotRequest, repetition));
        }
      }
    }
    return steps;
  }

  GeneratedMacrocycle _composeResolved(
    ResolvedForeverDefinition definition,
    ForeverRequest request,
    List<_ResolvedCompositionStep> steps,
  ) {
    for (final step in steps) {
      _validateResolvedCycle(step.request.cycle, step.resolved);
    }

    var nextStart = _dateOnly(request.startDate);
    var currentMaxes = Map<MovementId, Weight>.unmodifiable(
      request.initialTrainingMaxes,
    );
    var currentKind = TrainingMaxValueKind.confirmed;
    final nodes = <GeneratedMacrocycleNode>[];

    for (final resolvedStep in steps) {
      final step = resolvedStep.step;
      final slot = step.slot;
      final slotRequest = step.request;
      final repetition = step.repetition;
      final resolved = resolvedStep.resolved;
      final nodeIndex = nodes.length;
      final cycle = cycleCompiler.compile(
        resolved,
        CycleRequest(
          cycleId: '${request.macrocycleId}-${slot.id}-${repetition + 1}',
          startDate: nextStart,
          trainingDays: slotRequest.trainingDays,
          sessionOrder: slotRequest.sessionOrder,
          maxInputs: {
            for (final entry in currentMaxes.entries)
              entry.key: DirectTrainingMaxInput(entry.value),
          },
          globalTrainingMaxRatio: slotRequest.globalTrainingMaxRatio,
          trainingMaxRatioByMovement: slotRequest.trainingMaxRatioByMovement,
          percentageParameters: slotRequest.percentageParameters,
          percentageParametersByMovement:
              slotRequest.percentageParametersByMovement,
          unit: request.unit,
          roundingIncrement: request.roundingIncrement,
          barProfile: request.barProfile,
          includeDeload: slotRequest.includeDeload,
        ),
      );
      final lastDate = _lastSessionDate(cycle);
      final before = TrainingMaxSnapshot(
        values: currentMaxes,
        kind: currentKind,
      );
      final transition = _applyRule(
        currentMaxes,
        currentKind,
        slot.transition,
        request.unit,
      );
      currentMaxes = transition.values;
      currentKind = transition.kind;
      nodes.add(
        GeneratedMacrocycleNode(
          index: nodeIndex,
          slotId: slot.id,
          role: slot.role,
          cycleReference: slotRequest.cycle,
          cycle: cycle,
          trainingMaxesBefore: before,
          trainingMaxesAfter: transition,
        ),
      );
      nextStart = _dateOnly(lastDate.add(const Duration(days: 1)));
    }

    return GeneratedMacrocycle(
      id: request.macrocycleId,
      definitionId: definition.id,
      definitionRevision: definition.revision,
      state: MacrocycleState.scheduled,
      nodes: List.unmodifiable(nodes),
      initialTrainingMaxes: Map.unmodifiable(request.initialTrainingMaxes),
      projectedTrainingMaxes: currentMaxes,
    );
  }

  void _validateDefinitionAndRequest(
    ResolvedForeverDefinition definition,
    ForeverRequest request,
  ) {
    if (definition.id != request.definitionId ||
        definition.revision != request.definitionRevision) {
      throw const ForeverCompositionException(
        ForeverCompositionErrorCode.definitionMismatch,
        'The request does not target the resolved Forever definition.',
      );
    }
    final slots = <String, ForeverCycleSlot>{};
    for (final phase in definition.phases) {
      for (final slot in phase.slots) {
        if (slot.id.isEmpty ||
            slot.repeatCount < 1 ||
            slots.containsKey(slot.id)) {
          throw ForeverCompositionException(
            ForeverCompositionErrorCode.invalidDefinition,
            'Invalid or duplicate slot ${slot.id}.',
          );
        }
        slots[slot.id] = slot;
      }
    }
    for (final id in request.slotRequests.keys) {
      if (!slots.containsKey(id)) {
        throw ForeverCompositionException(
          ForeverCompositionErrorCode.unexpectedSlotRequest,
          'No slot named $id exists in the definition.',
        );
      }
    }
    for (final entry in slots.entries) {
      final slotRequest = request.slotRequests[entry.key];
      if (slotRequest == null) {
        throw ForeverCompositionException(
          ForeverCompositionErrorCode.missingSlotRequest,
          'No request was supplied for slot ${entry.key}.',
        );
      }
      if (!slotRequest.enabled && !entry.value.optional) {
        throw ForeverCompositionException(
          ForeverCompositionErrorCode.requiredSlotDisabled,
          'Required slot ${entry.key} cannot be disabled.',
        );
      }
    }
    for (final entry in request.initialTrainingMaxes.entries) {
      if (entry.value.unit != request.unit) {
        throw ForeverCompositionException(
          ForeverCompositionErrorCode.invalidTrainingMax,
          'Training Max ${entry.key.value} uses a different unit.',
        );
      }
    }
  }

  void _validateCycleChoice(
    ForeverCycleSlot slot,
    ForeverCycleReference selected,
  ) {
    if (!slot.allowedCycles.any((candidate) => candidate.key == selected.key)) {
      throw ForeverCompositionException(
        ForeverCompositionErrorCode.incompatibleCycle,
        '${selected.key} is not allowed in slot ${slot.id}.',
      );
    }
  }

  void _validateResolvedCycle(
    ForeverCycleReference reference,
    ResolvedCycleDefinition resolved,
  ) {
    if (resolved.templateId != reference.templateId ||
        resolved.variantId != reference.variantId) {
      throw ForeverCompositionException(
        ForeverCompositionErrorCode.resolvedCycleMismatch,
        'The resolver returned a different Cycle definition.',
      );
    }
  }

  TrainingMaxSnapshot _applyRule(
    Map<MovementId, Weight> current,
    TrainingMaxValueKind currentKind,
    ForeverTransition transition,
    WeightUnit unit,
  ) {
    final result = _applyRuleValues(current, transition.trainingMaxRule, unit);
    final needsConfirmation =
        transition.requiresConfirmation ||
        transition.trainingMaxRule is TestThenConfirmTrainingMax;
    final ruleKind = switch (transition.trainingMaxRule) {
      AddTrainingMax rule => rule.resultKind,
      MultiplyTrainingMax rule => rule.resultKind,
      _ => currentKind,
    };
    return TrainingMaxSnapshot(
      values: Map.unmodifiable(result),
      kind: needsConfirmation ? TrainingMaxValueKind.projected : ruleKind,
    );
  }

  Map<MovementId, Weight> _applyRuleValues(
    Map<MovementId, Weight> current,
    TrainingMaxRule rule,
    WeightUnit unit,
  ) {
    if (rule is KeepTrainingMax) return Map.of(current);
    if (rule is TestThenConfirmTrainingMax) {
      return _applyRuleValues(current, rule.projectedRule, unit);
    }
    if (rule is AddTrainingMax) {
      final result = Map<MovementId, Weight>.of(current);
      for (final entry in rule.amounts.entries) {
        if (entry.value.unit != unit) {
          throw const ForeverCompositionException(
            ForeverCompositionErrorCode.invalidTrainingMax,
            'A Training Max increment uses a different unit.',
          );
        }
        final value = result[entry.key];
        if (value != null) {
          result[entry.key] = Weight(
            value.centiUnits + entry.value.centiUnits,
            unit,
          );
        }
      }
      return result;
    }
    if (rule is MultiplyTrainingMax) {
      final result = Map<MovementId, Weight>.of(current);
      for (final entry in rule.ratios.entries) {
        final value = result[entry.key];
        if (value != null) {
          result[entry.key] = Weight(
            (value.centiUnits * entry.value.basisPoints / 10000).round(),
            unit,
          );
        }
      }
      return result;
    }
    throw const ForeverCompositionException(
      ForeverCompositionErrorCode.invalidDefinition,
      'Unsupported Training Max rule.',
    );
  }

  DateTime _lastSessionDate(GeneratedCycle cycle) {
    DateTime? last;
    for (final week in cycle.weeks) {
      for (final session in week.sessions) {
        if (last == null || session.date.isAfter(last)) last = session.date;
      }
    }
    if (last == null) {
      throw ForeverCompositionException(
        ForeverCompositionErrorCode.emptyGeneratedCycle,
        'Generated Cycle ${cycle.id} contains no session.',
      );
    }
    return last;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

final class _CompositionStep {
  const _CompositionStep(this.slot, this.request, this.repetition);

  final ForeverCycleSlot slot;
  final ForeverSlotRequest request;
  final int repetition;
}

final class _ResolvedCompositionStep {
  const _ResolvedCompositionStep(this.step, this.resolved);

  final _CompositionStep step;
  final ResolvedCycleDefinition resolved;

  ForeverSlotRequest get request => step.request;
}
