import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/forever/application/forever_composer_impl.dart';
import 'package:hybrid_training/features/forever/domain/forever_contract.dart';

void main() {
  const squat = MovementId('squat');
  const press = MovementId('press');

  test(
    'expands slots, delegates every node and advances by actual dates',
    () async {
      final compiler = _RecordingCompiler(const Duration(days: 18));
      final composer = ForeverComposerImpl(
        cycleDefinitionResolver: _Resolver(),
        cycleCompiler: compiler,
      );
      final definition = _definition([
        _slot(
          id: 'leader',
          repeats: 2,
          transition: const ForeverTransition(
            trainingMaxRule: AddTrainingMax({
              squat: Weight(500, WeightUnit.kg),
            }),
          ),
        ),
        _slot(
          id: 'anchor',
          transition: const ForeverTransition(
            trainingMaxRule: MultiplyTrainingMax({press: Percentage(11000)}),
          ),
        ),
      ]);

      final result = await composer.compose(definition, _request(definition));

      expect(result.nodes, hasLength(3));
      expect(compiler.requests, hasLength(3));
      expect(compiler.requests.map((r) => r.startDate), [
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 24),
        DateTime(2026, 2, 12),
      ]);
      expect(
        compiler.requests.every(
          (request) =>
              request.maxInputs.values.every(
                (v) => v is DirectTrainingMaxInput,
              ) &&
              request.globalTrainingMaxRatio.basisPoints == 10000,
        ),
        isTrue,
      );
      expect(
        result.nodes[0].trainingMaxesBefore.kind,
        TrainingMaxValueKind.confirmed,
      );
      expect(
        result.nodes[0].trainingMaxesAfter.values[squat]!.centiUnits,
        10500,
      );
      expect(
        result.nodes[1].trainingMaxesAfter.values[squat]!.centiUnits,
        11000,
      );
      expect(result.projectedTrainingMaxes[press]!.centiUnits, 6600);
    },
  );

  test(
    'marks test-then-confirm values projected without confirming them',
    () async {
      final definition = _definition([
        _slot(
          id: 'test',
          role: ForeverPhaseRole.test,
          transition: const ForeverTransition(
            trainingMaxRule: TestThenConfirmTrainingMax(
              projectedRule: AddTrainingMax({
                squat: Weight(250, WeightUnit.kg),
              }),
            ),
          ),
        ),
        _slot(
          id: 'after',
          transition: const ForeverTransition(
            trainingMaxRule: KeepTrainingMax(),
          ),
        ),
      ]);
      final result = await ForeverComposerImpl(
        cycleDefinitionResolver: _Resolver(),
        cycleCompiler: _RecordingCompiler(Duration.zero),
      ).compose(definition, _request(definition));

      expect(
        result.nodes.first.trainingMaxesAfter.kind,
        TrainingMaxValueKind.projected,
      );
      expect(
        result.nodes.last.trainingMaxesBefore.kind,
        TrainingMaxValueKind.projected,
      );
      expect(
        result.nodes.last.trainingMaxesAfter.kind,
        TrainingMaxValueKind.projected,
      );
      expect(result.projectedTrainingMaxes[squat]!.centiUnits, 10250);
    },
  );

  test(
    'skips a disabled optional slot and rejects disabled required slot',
    () async {
      final optionalDefinition = _definition([
        _slot(id: 'optional', optional: true),
      ]);
      final disabled = _request(optionalDefinition, enabled: false);
      final composer = ForeverComposerImpl(
        cycleDefinitionResolver: _Resolver(),
        cycleCompiler: _RecordingCompiler(Duration.zero),
      );
      expect(
        (await composer.compose(optionalDefinition, disabled)).nodes,
        isEmpty,
      );

      final requiredDefinition = _definition([_slot(id: 'required')]);
      await expectLater(
        composer.compose(
          requiredDefinition,
          _request(requiredDefinition, enabled: false),
        ),
        throwsA(
          isA<ForeverCompositionException>().having(
            (e) => e.code,
            'code',
            ForeverCompositionErrorCode.requiredSlotDisabled,
          ),
        ),
      );
    },
  );

  test('rejects a cycle outside the typed compatibility list', () async {
    final definition = _definition([_slot(id: 'leader')]);
    final request = _request(
      definition,
      reference: const ForeverCycleReference(
        templateId: 'other',
        variantId: 'other',
      ),
    );
    await expectLater(
      ForeverComposerImpl(
        cycleDefinitionResolver: _Resolver(),
        cycleCompiler: _RecordingCompiler(Duration.zero),
      ).compose(definition, request),
      throwsA(
        isA<ForeverCompositionException>().having(
          (e) => e.code,
          'code',
          ForeverCompositionErrorCode.incompatibleCycle,
        ),
      ),
    );
  });

  test(
    'rejects definition identity, missing slots and unit mismatches',
    () async {
      final definition = _definition([_slot(id: 'leader')]);
      final composer = ForeverComposerImpl(
        cycleDefinitionResolver: _Resolver(),
        cycleCompiler: _RecordingCompiler(Duration.zero),
      );
      final wrongIdentity = _request(
        definition,
        definitionId: const ForeverDefinitionId('wrong'),
      );
      await expectLater(
        composer.compose(definition, wrongIdentity),
        _throwsCode(ForeverCompositionErrorCode.definitionMismatch),
      );
      await expectLater(
        composer.compose(definition, _request(definition, omitSlots: true)),
        _throwsCode(ForeverCompositionErrorCode.missingSlotRequest),
      );
      await expectLater(
        composer.compose(
          definition,
          _request(definition, maxUnit: WeightUnit.lb),
        ),
        _throwsCode(ForeverCompositionErrorCode.invalidTrainingMax),
      );
    },
  );
}

Matcher _throwsCode(ForeverCompositionErrorCode code) => throwsA(
  isA<ForeverCompositionException>().having((e) => e.code, 'code', code),
);

const _cycle = ForeverCycleReference(
  templateId: 'cycle-template',
  variantId: 'cycle-variant',
);

ForeverCycleSlot _slot({
  required String id,
  int repeats = 1,
  ForeverPhaseRole role = ForeverPhaseRole.leader,
  bool optional = false,
  ForeverTransition transition = const ForeverTransition(
    trainingMaxRule: KeepTrainingMax(),
  ),
}) => ForeverCycleSlot(
  id: id,
  role: role,
  repeatCount: repeats,
  defaultCycle: _cycle,
  allowedCycles: const [_cycle],
  transition: transition,
  optional: optional,
);

ResolvedForeverDefinition _definition(List<ForeverCycleSlot> slots) {
  const id = ForeverDefinitionId('forever-test');
  const revision = ForeverDefinitionRevision(1);
  return ResolvedForeverDefinition(
    id: id,
    revision: revision,
    labelEn: 'Test',
    labelFr: 'Test',
    sourceRuleIds: const ['source'],
    phases: [ForeverPhase(id: 'phase', slots: slots)],
    editorSchema: ForeverEditorSchema(
      definitionId: id,
      revision: revision,
      configurableSlotIds: [for (final slot in slots) slot.id],
    ),
  );
}

ForeverRequest _request(
  ResolvedForeverDefinition definition, {
  bool enabled = true,
  bool omitSlots = false,
  ForeverCycleReference reference = _cycle,
  ForeverDefinitionId? definitionId,
  WeightUnit maxUnit = WeightUnit.kg,
}) => ForeverRequest(
  macrocycleId: 'macro',
  definitionId: definitionId ?? definition.id,
  definitionRevision: definition.revision,
  startDate: DateTime(2026, 1, 5, 16),
  initialTrainingMaxes: {
    const MovementId('squat'): Weight(10000, maxUnit),
    const MovementId('press'): Weight(6000, maxUnit),
  },
  slotRequests: omitSlots
      ? const {}
      : {
          for (final slot in definition.phases.expand((p) => p.slots))
            slot.id: ForeverSlotRequest(
              slotId: slot.id,
              cycle: reference,
              trainingDays: const [1],
              sessionOrder: const [MovementId('squat')],
              enabled: enabled,
            ),
        },
  unit: WeightUnit.kg,
  roundingIncrement: const Weight(250, WeightUnit.kg),
  barProfile: const BarProfile(
    weight: Weight(2000, WeightUnit.kg),
    platesPerSide: [Weight(2000, WeightUnit.kg)],
  ),
);

final class _Resolver implements ForeverCycleDefinitionResolver {
  @override
  Future<ResolvedCycleDefinition> resolve(
    ForeverCycleReference reference,
  ) async => ResolvedCycleDefinition(
    catalogVersion: 1,
    templateId: reference.templateId,
    variantId: reference.variantId,
    sessionMovementIds: const [MovementId('squat')],
    weeks: const [],
    sourceReference: 'test',
  );
}

final class _RecordingCompiler implements CycleCompiler {
  _RecordingCompiler(this.duration);
  final Duration duration;
  final requests = <CycleRequest>[];

  @override
  GeneratedCycle compile(
    ResolvedCycleDefinition definition,
    CycleRequest request,
  ) {
    requests.add(request);
    return GeneratedCycle(
      id: request.cycleId,
      catalogVersion: definition.catalogVersion,
      templateId: definition.templateId,
      variantId: definition.variantId,
      effectiveTrainingMaxes: {
        for (final entry in request.maxInputs.entries)
          entry.key.value: (entry.value as DirectTrainingMaxInput).weight,
      },
      weeks: [
        GeneratedWeek(
          number: 1,
          sessions: [
            GeneratedSession(
              id: '${request.cycleId}-session',
              date: request.startDate.add(duration),
              movementId: const MovementId('squat'),
              blocks: const [],
            ),
          ],
        ),
      ],
    );
  }
}
