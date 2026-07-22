import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  test('compose and composeSync produce the same macrocycle', () async {
    final resolver = _DualResolver();
    final composer = ForeverComposerImpl(
      cycleDefinitionResolver: resolver,
      syncCycleDefinitionResolver: resolver,
      cycleCompiler: _Compiler(),
    );
    final definition = _definition();
    final request = _request(definition);

    final asynchronous = await composer.compose(definition, request);
    final synchronous = composer.composeSync(definition, request);

    expect(_snapshot(synchronous), _snapshot(asynchronous));
    expect(resolver.asyncCalls, 2);
    expect(resolver.syncCalls, 2);
  });

  test('composeSync requires an explicitly synchronous resolver', () {
    final definition = _definition();
    final composer = ForeverComposerImpl(
      cycleDefinitionResolver: _DualResolver(),
      cycleCompiler: _Compiler(),
    );

    expect(
      () => composer.composeSync(definition, _request(definition)),
      throwsStateError,
    );
  });

  test('sync constructor needs no asynchronous resolver', () {
    final definition = _definition();
    final composer = ForeverComposerImpl.sync(
      cycleDefinitionResolver: _DualResolver(),
      cycleCompiler: _Compiler(),
    );

    expect(
      composer.composeSync(definition, _request(definition)).nodes,
      hasLength(2),
    );
  });
}

const _reference = ForeverCycleReference(
  templateId: 'template',
  variantId: 'variant',
);
const _movement = MovementId('squat');

ResolvedForeverDefinition _definition() {
  const id = ForeverDefinitionId('forever');
  const revision = ForeverDefinitionRevision(1);
  return ResolvedForeverDefinition(
    id: id,
    revision: revision,
    labelEn: 'Forever',
    labelFr: 'Forever',
    sourceRuleIds: const ['test'],
    phases: [
      ForeverPhase(
        id: 'phase',
        slots: [
          ForeverCycleSlot(
            id: 'leader',
            role: ForeverPhaseRole.leader,
            repeatCount: 2,
            defaultCycle: _reference,
            allowedCycles: [_reference],
            transition: ForeverTransition(
              trainingMaxRule: AddTrainingMax({
                _movement: Weight(250, WeightUnit.kg),
              }),
            ),
          ),
        ],
      ),
    ],
    editorSchema: const ForeverEditorSchema(
      definitionId: id,
      revision: revision,
      configurableSlotIds: ['leader'],
    ),
  );
}

ForeverRequest _request(ResolvedForeverDefinition definition) => ForeverRequest(
  macrocycleId: 'macro',
  definitionId: definition.id,
  definitionRevision: definition.revision,
  startDate: DateTime(2026, 1, 5),
  initialTrainingMaxes: const {_movement: Weight(10000, WeightUnit.kg)},
  slotRequests: {
    'leader': ForeverSlotRequest(
      slotId: 'leader',
      cycle: _reference,
      trainingDays: [1],
      sessionOrder: [_movement],
    ),
  },
  unit: WeightUnit.kg,
  roundingIncrement: const Weight(250, WeightUnit.kg),
  barProfile: const BarProfile(
    weight: Weight(2000, WeightUnit.kg),
    platesPerSide: [Weight(2000, WeightUnit.kg)],
  ),
);

Map<String, Object> _snapshot(GeneratedMacrocycle value) => {
  'id': value.id,
  'definition': value.definitionId.value,
  'revision': value.definitionRevision.value,
  'state': value.state.name,
  'projected': value.projectedTrainingMaxes.map(
    (key, weight) => MapEntry(key.value, weight.toJson()),
  ),
  'nodes': [
    for (final node in value.nodes)
      {
        'index': node.index,
        'slotId': node.slotId,
        'role': node.role.name,
        'cycle': node.cycle.toJson(),
        'before': node.trainingMaxesBefore.values.map(
          (key, weight) => MapEntry(key.value, weight.toJson()),
        ),
        'after': node.trainingMaxesAfter.values.map(
          (key, weight) => MapEntry(key.value, weight.toJson()),
        ),
      },
  ],
};

final class _DualResolver
    implements
        ForeverCycleDefinitionResolver,
        SyncForeverCycleDefinitionResolver {
  int asyncCalls = 0;
  int syncCalls = 0;

  @override
  Future<ResolvedCycleDefinition> resolve(
    ForeverCycleReference reference,
  ) async {
    asyncCalls++;
    return _resolve(reference);
  }

  @override
  ResolvedCycleDefinition resolveSync(ForeverCycleReference reference) {
    syncCalls++;
    return _resolve(reference);
  }

  ResolvedCycleDefinition _resolve(ForeverCycleReference reference) =>
      ResolvedCycleDefinition(
        catalogVersion: 1,
        templateId: reference.templateId,
        variantId: reference.variantId,
        sessionMovementIds: const [_movement],
        weeks: const [],
        sourceReference: 'test',
      );
}

final class _Compiler implements CycleCompiler {
  @override
  GeneratedCycle compile(
    ResolvedCycleDefinition definition,
    CycleRequest request,
  ) => GeneratedCycle(
    id: request.cycleId,
    catalogVersion: definition.catalogVersion,
    templateId: definition.templateId,
    variantId: definition.variantId,
    effectiveTrainingMaxes: {
      _movement.value:
          (request.maxInputs[_movement]! as DirectTrainingMaxInput).weight,
    },
    weeks: [
      GeneratedWeek(
        number: 1,
        sessions: [
          GeneratedSession(
            id: '${request.cycleId}-session',
            date: request.startDate.add(const Duration(days: 6)),
            movementId: _movement,
            blocks: const [],
          ),
        ],
      ),
    ],
  );
}
