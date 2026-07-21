import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/domain/generic_engine/generic_engine.dart';

void main() {
  const contentHash =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  final published = CatalogGovernance(
    authority: CatalogAuthority.canonical,
    review: CatalogReviewStatus.confirmed,
    lifecycle: CatalogLifecycle.published,
    visibility: CatalogVisibility.public,
    executable: true,
  );
  final source = CatalogEvidence(
    ruleId: CatalogId('rule-one'),
    references: [
      EvidenceReference(
        sourceId: CatalogId('book-one'),
        locator: 'p. 1',
        sourceRevision: 1,
      ),
    ],
  );
  final calculationRule = MaxCalculationRule(
    id: CatalogId('max-calculation'),
    governance: published,
    formulas: RepMaxFormula.values.toSet(),
    evidence: source,
  );
  final squat = MovementDefinition(
    id: CatalogId('squat'),
    governance: published,
    kind: MovementKind.barbell,
    bodyRegion: BodyRegion.lower,
    capabilities: {CatalogId('percent-training-max')},
    evidence: source,
  );
  final module = ModuleDefinition(
    id: CatalogId('ordered-strength'),
    revision: 1,
    governance: published,
    requiredMovementCapabilities: {CatalogId('percent-training-max')},
    requiredEquipment: {CatalogId('barbell')},
    supportedLoadKinds: {LoadKind.percentTrainingMax},
    inputPorts: [
      ModulePort(id: CatalogId('movement'), kind: ModulePortKind.movement),
    ],
    outputPorts: const [],
    evidence: source,
  );

  TrainingTemplateGraph graph(CatalogAuthority authority) =>
      TrainingTemplateGraph(
        id: CatalogId('generic-strength'),
        revision: 1,
        governance: CatalogGovernance(
          authority: authority,
          review: CatalogReviewStatus.confirmed,
          lifecycle: CatalogLifecycle.published,
          visibility: CatalogVisibility.public,
          executable: true,
          customMetadata: authority == CatalogAuthority.userCustom
              ? CustomCatalogMetadata(
                  ownerId: CatalogId('owner'),
                  derivedFrom: CatalogId('generic-strength'),
                  diff: 'sets may be omitted',
                )
              : null,
        ),
        evidence: authority == CatalogAuthority.canonical ? source : null,
        variants: [
          TemplateVariant(
            id: CatalogId('default-variant'),
            moduleIds: {CatalogId('binding-one')},
          ),
        ],
        parameters: [
          ParameterDefinition(
            id: CatalogId('sets'),
            kind: ParameterKind.integer,
            minimum: 1,
            maximum: 10,
            requiredWhen: const AlwaysCondition(true),
          ),
        ],
        modules: [
          ModuleBinding(
            id: CatalogId('binding-one'),
            moduleId: module.id,
            moduleRevision: 1,
            inputs: [
              PortBinding(
                portId: CatalogId('movement'),
                kind: ModulePortKind.movement,
                targetId: squat.id,
              ),
            ],
            requiredMovementCapabilities: const {},
          ),
        ],
      );

  EngineRequest request(
    TrainingTemplateGraph template,
    Map<CatalogId, ResolvedParameter> parameters, {
    EquipmentProfile? equipment,
    AssistancePlan? assistance,
    List<MovementDefinition>? movements,
    List<CatalogModule>? catalogModules,
  }) => EngineRequest(
    snapshot: CatalogSnapshot(
      id: CatalogId('snapshot-one'),
      revision: 1,
      contentHash: contentHash,
      canonicalizationVersion: 1,
      movements: movements ?? [squat],
      templates: [template],
      modules: catalogModules ?? [module],
      finitePrograms: const [],
    ),
    templateId: template.id,
    templateRevision: template.revision,
    variantId: CatalogId('default-variant'),
    parameters: parameters,
    trainingMaxes: TrainingMaxConfiguration(
      calculationRule: calculationRule,
      globalRatio: .9,
      unit: WeightUnit.kilograms,
      roundingIncrement: 2.5,
      inputs: {squat.id: MaxInput(kind: MaxInputKind.oneRepMax, weight: 200)},
    ),
    equipment:
        equipment ??
        EquipmentProfile(
          equipmentIds: {CatalogId('barbell')},
          supportedLoads: {LoadKind.percentTrainingMax},
        ),
    assistance: assistance,
  );

  test('governance blocks unpublished canonical records', () {
    final draft = CatalogGovernance(
      authority: CatalogAuthority.canonical,
      review: CatalogReviewStatus.confirmed,
      lifecycle: CatalogLifecycle.draft,
      visibility: CatalogVisibility.public,
      executable: true,
    );
    expect(draft.isExecutable, false);
    expect(_throws(draft.requireExecutable), true);
    expect(published.isPublic, true);
  });

  test(
    'snapshot content identity requires SHA-256 and canonicalization version',
    () {
      expect(
        _throws(
          () => CatalogSnapshot(
            id: CatalogId('invalid-hash-snapshot'),
            revision: 1,
            contentHash: 'ABC',
            canonicalizationVersion: 1,
            movements: const [],
            templates: const [],
            modules: const [],
            finitePrograms: const [],
          ),
        ),
        true,
      );
      expect(
        _throws(
          () => CatalogSnapshot(
            id: CatalogId('invalid-version-snapshot'),
            revision: 1,
            contentHash: contentHash,
            canonicalizationVersion: 0,
            movements: const [],
            templates: const [],
            modules: const [],
            finitePrograms: const [],
          ),
        ),
        true,
      );
    },
  );

  test('custom governance never bypasses confirmation and publication', () {
    expect(
      _throws(
        () => CatalogGovernance(
          authority: CatalogAuthority.userCustom,
          review: CatalogReviewStatus.confirmed,
          lifecycle: CatalogLifecycle.published,
          visibility: CatalogVisibility.internal,
          executable: true,
        ),
      ),
      true,
    );
    final customDraft = CatalogGovernance(
      authority: CatalogAuthority.userCustom,
      review: CatalogReviewStatus.confirmed,
      lifecycle: CatalogLifecycle.draft,
      visibility: CatalogVisibility.internal,
      executable: true,
      customMetadata: CustomCatalogMetadata(
        ownerId: CatalogId('owner'),
        derivedFrom: CatalogId('base'),
        diff: 'changed schedule',
      ),
    );
    expect(customDraft.isExecutable, false);
  });

  test('compatible definitions require structured evidence', () {
    expect(
      _throws(
        () => MovementDefinition(
          id: CatalogId('compatible-movement'),
          governance: CatalogGovernance(
            authority: CatalogAuthority.compatible,
            review: CatalogReviewStatus.confirmed,
            lifecycle: CatalogLifecycle.published,
            visibility: CatalogVisibility.public,
            executable: true,
          ),
          kind: MovementKind.other,
          bodyRegion: BodyRegion.fullBody,
          capabilities: const {},
        ),
      ),
      true,
    );
  });

  test('parameter kinds and conditional allowed values are strict', () {
    expect(_throws(() => NumberParameter(1.5, ParameterKind.integer)), true);
    expect(
      _throws(() => IdParameter(CatalogId('x'), ParameterKind.decimal)),
      true,
    );
    final selector = CatalogId('mode');
    final definition = ParameterDefinition(
      id: CatalogId('movement'),
      kind: ParameterKind.movement,
      allowedIdsWhen: [
        ConditionalAllowedIds(
          when: EqualsCondition(
            selector,
            IdParameter(CatalogId('a'), ParameterKind.enumeration),
          ),
          allowedIds: {CatalogId('squat')},
        ),
      ],
    );
    expect(
      definition.accepts(IdParameter(squat.id, ParameterKind.movement), {
        selector: IdParameter(CatalogId('a'), ParameterKind.enumeration),
      }),
      true,
    );
  });

  test(
    'canonical parameters are explicit and custom values remain validated',
    () {
      final canonical = const TemplateContractResolver().resolve(
        request(graph(CatalogAuthority.canonical), const {}),
      );
      expect(canonical.issues.single.code, 'missing_canonical_parameter');
      final invalidCustom = const TemplateContractResolver().resolve(
        request(graph(CatalogAuthority.userCustom), {
          CatalogId('sets'): NumberParameter(11, ParameterKind.integer),
        }),
      );
      expect(invalidCustom.issues.single.code, 'invalid_parameter');
    },
  );

  test(
    'module revision, equipment and movement capabilities are validated',
    () {
      final result = const TemplateContractResolver().resolve(
        request(
          graph(CatalogAuthority.canonical),
          {CatalogId('sets'): NumberParameter(3, ParameterKind.integer)},
          equipment: EquipmentProfile(
            equipmentIds: const {},
            supportedLoads: const {},
          ),
        ),
      );
      expect(
        result.issues.map((issue) => issue.code).contains('missing_equipment'),
        true,
      );
    },
  );

  test('typed module port mismatch is returned as an issue, not thrown', () {
    final invalidGraph = TrainingTemplateGraph(
      id: CatalogId('invalid-binding-template'),
      revision: 1,
      governance: published,
      evidence: source,
      variants: [
        TemplateVariant(
          id: CatalogId('default-variant'),
          moduleIds: {CatalogId('bad-binding')},
        ),
      ],
      parameters: const [],
      modules: [
        ModuleBinding(
          id: CatalogId('bad-binding'),
          moduleId: module.id,
          moduleRevision: 1,
          inputs: [
            PortBinding(
              portId: CatalogId('movement'),
              kind: ModulePortKind.parameter,
              targetId: CatalogId('missing'),
            ),
          ],
          requiredMovementCapabilities: const {},
        ),
      ],
    );
    final result = const TemplateContractResolver().resolve(
      request(invalidGraph, const {}),
    );
    expect(
      result.issues.any((issue) => issue.code == 'invalid_module_port'),
      true,
    );
  });

  test('draft movements are rejected wherever referenced', () {
    final draftMovement = MovementDefinition(
      id: squat.id,
      governance: CatalogGovernance(
        authority: CatalogAuthority.canonical,
        review: CatalogReviewStatus.confirmed,
        lifecycle: CatalogLifecycle.draft,
        visibility: CatalogVisibility.internal,
        executable: true,
      ),
      kind: MovementKind.barbell,
      bodyRegion: BodyRegion.lower,
      capabilities: squat.capabilities,
      evidence: source,
    );
    final result = const TemplateContractResolver().resolve(
      request(
        graph(CatalogAuthority.canonical),
        {CatalogId('sets'): NumberParameter(3, ParameterKind.integer)},
        movements: [draftMovement],
      ),
    );
    expect(
      result.issues.any(
        (issue) => issue.code == 'training_max_movement_not_executable',
      ),
      true,
    );
    expect(
      result.issues.any(
        (issue) => issue.code == 'module_movement_not_executable',
      ),
      true,
    );
  });

  test(
    'module targets require inclusion, revision and executable governance',
    () {
      final modulePort = ModulePort(
        id: CatalogId('child'),
        kind: ModulePortKind.module,
      );
      ModuleDefinition definition(CatalogId id, CatalogGovernance governance) =>
          ModuleDefinition(
            id: id,
            revision: 1,
            governance: governance,
            requiredMovementCapabilities: const {},
            requiredEquipment: const {},
            supportedLoadKinds: const {},
            inputPorts: [modulePort],
            outputPorts: const [],
            evidence: source,
          );
      final childId = CatalogId('child-module');
      final draft = CatalogGovernance(
        authority: CatalogAuthority.canonical,
        review: CatalogReviewStatus.confirmed,
        lifecycle: CatalogLifecycle.draft,
        visibility: CatalogVisibility.internal,
        executable: true,
      );
      final rootDefinition = definition(CatalogId('root-module'), published);
      final childDefinition = definition(childId, draft);
      final root = ModuleBinding(
        id: CatalogId('root-binding'),
        moduleId: rootDefinition.id,
        moduleRevision: 1,
        inputs: [
          PortBinding(
            portId: modulePort.id,
            kind: ModulePortKind.module,
            targetId: CatalogId('child-binding'),
            targetRevision: 2,
          ),
        ],
        requiredMovementCapabilities: const {},
      );
      final child = ModuleBinding(
        id: CatalogId('child-binding'),
        moduleId: childDefinition.id,
        moduleRevision: 1,
        inputs: [
          PortBinding(
            portId: modulePort.id,
            kind: ModulePortKind.module,
            targetId: root.id,
            targetRevision: 1,
          ),
        ],
        requiredMovementCapabilities: const {},
      );
      final template = TrainingTemplateGraph(
        id: CatalogId('module-graph'),
        revision: 1,
        governance: published,
        evidence: source,
        variants: [
          TemplateVariant(
            id: CatalogId('default-variant'),
            moduleIds: {root.id, child.id},
          ),
        ],
        parameters: const [],
        modules: [root, child],
      );
      final result = const TemplateContractResolver().resolve(
        request(
          template,
          const {},
          catalogModules: [rootDefinition, childDefinition],
        ),
      );
      expect(
        result.issues.any((issue) => issue.code == 'module_not_executable'),
        true,
      );
      expect(
        result.issues.any(
          (issue) => issue.code == 'module_binding_revision_mismatch',
        ),
        true,
      );
      expect(
        result.issues.any((issue) => issue.code == 'module_binding_cycle'),
        true,
      );
    },
  );

  test('module target outside the selected variant is rejected', () {
    final recursiveModule = ModuleDefinition(
      id: CatalogId('recursive-module'),
      revision: 1,
      governance: published,
      requiredMovementCapabilities: const {},
      requiredEquipment: const {},
      supportedLoadKinds: const {},
      inputPorts: [
        ModulePort(id: CatalogId('child'), kind: ModulePortKind.module),
      ],
      outputPorts: const [],
      evidence: source,
    );
    final root = ModuleBinding(
      id: CatalogId('included-root'),
      moduleId: recursiveModule.id,
      moduleRevision: 1,
      inputs: [
        PortBinding(
          portId: CatalogId('child'),
          kind: ModulePortKind.module,
          targetId: CatalogId('excluded-child'),
          targetRevision: 1,
        ),
      ],
      requiredMovementCapabilities: const {},
    );
    final excluded = ModuleBinding(
      id: CatalogId('excluded-child'),
      moduleId: recursiveModule.id,
      moduleRevision: 1,
      inputs: const [],
      requiredMovementCapabilities: const {},
    );
    final template = TrainingTemplateGraph(
      id: CatalogId('inclusion-graph'),
      revision: 1,
      governance: published,
      evidence: source,
      variants: [
        TemplateVariant(id: CatalogId('default-variant'), moduleIds: {root.id}),
      ],
      parameters: const [],
      modules: [root, excluded],
    );
    final result = const TemplateContractResolver().resolve(
      request(template, const {}, catalogModules: [recursiveModule]),
    );
    expect(
      result.issues.any((issue) => issue.code == 'module_binding_not_included'),
      true,
    );
  });

  test('movement parameters reject ghost and non-executable movements', () {
    final movementParameter = ParameterDefinition(
      id: CatalogId('selected-movement'),
      kind: ParameterKind.movement,
      requiredWhen: const AlwaysCondition(true),
    );
    final template = TrainingTemplateGraph(
      id: CatalogId('movement-parameter-template'),
      revision: 1,
      governance: published,
      evidence: source,
      variants: [
        TemplateVariant(id: CatalogId('default-variant'), moduleIds: const {}),
      ],
      parameters: [movementParameter],
      modules: const [],
    );
    final result = const TemplateContractResolver().resolve(
      request(template, {
        movementParameter.id: IdParameter(
          CatalogId('ghost-lift'),
          ParameterKind.movement,
        ),
      }),
    );
    expect(result.issues.single.code, 'unknown_movement_parameter');
  });

  test('assistance movement loads are validated by the engine request', () {
    final slot = AssistanceSlot(
      id: CatalogId('load-slot'),
      roleId: CatalogId('role-a'),
      minimumSelections: 1,
      maximumSelections: 1,
      movementIds: {squat.id},
    );
    final assistance = AssistancePlan(
      slots: [slot],
      selections: [
        AssistanceSelection(
          slotId: slot.id,
          movementId: squat.id,
          regular: SetPrescription(
            sets: 1,
            repetitions: const FixedRepetitions(10),
            load: const BodyweightLoad(),
          ),
          deloadMode: AssistanceDeloadMode.omit,
        ),
      ],
    );
    final result = const TemplateContractResolver().resolve(
      request(graph(CatalogAuthority.canonical), {
        CatalogId('sets'): NumberParameter(3, ParameterKind.integer),
      }, assistance: assistance),
    );
    expect(
      result.issues.any((issue) => issue.code == 'unsupported_assistance_load'),
      true,
    );
  });

  test('direct TM is never reratioed and rep max requires a formula', () {
    final direct = TrainingMaxConfiguration(
      calculationRule: calculationRule,
      globalRatio: .5,
      unit: WeightUnit.pounds,
      roundingIncrement: 5,
      inputs: {
        squat.id: MaxInput(kind: MaxInputKind.directTrainingMax, weight: 183),
      },
    );
    expect(direct.trainingMaxFor(squat.id), 185);
    expect(
      _throws(
        () => MaxInput(kind: MaxInputKind.repMax, weight: 180, repetitions: 3),
      ),
      true,
    );
  });

  test('Brzycki and ratio references are bounded', () {
    expect(
      _throws(
        () => MaxInput(
          kind: MaxInputKind.repMax,
          weight: 100,
          repetitions: 37,
          formula: RepMaxFormula.brzycki,
        ),
      ),
      true,
    );
    expect(
      _throws(
        () => TrainingMaxConfiguration(
          calculationRule: calculationRule,
          globalRatio: .9,
          unit: WeightUnit.kilograms,
          roundingIncrement: 1,
          inputs: {
            squat.id: MaxInput(kind: MaxInputKind.oneRepMax, weight: 100),
          },
          ratiosByMovement: {CatalogId('unknown'): .8},
        ),
      ),
      true,
    );
  });

  test('max calculation refuses unsourced and needs-review rules', () {
    expect(
      _throws(
        () => MaxCalculationRule(
          id: CatalogId('unsourced-calculation'),
          governance: published,
          formulas: {RepMaxFormula.epley},
        ),
      ),
      true,
    );
    final needsReview = MaxCalculationRule(
      id: CatalogId('needs-review-calculation'),
      governance: CatalogGovernance(
        authority: CatalogAuthority.canonical,
        review: CatalogReviewStatus.needsReview,
        lifecycle: CatalogLifecycle.published,
        visibility: CatalogVisibility.internal,
        executable: true,
      ),
      formulas: {RepMaxFormula.epley},
      evidence: source,
    );
    final configuration = TrainingMaxConfiguration(
      calculationRule: needsReview,
      globalRatio: .9,
      unit: WeightUnit.kilograms,
      roundingIncrement: 1,
      inputs: {squat.id: MaxInput(kind: MaxInputKind.oneRepMax, weight: 100)},
    );
    expect(_throws(() => configuration.trainingMaxFor(squat.id)), true);
  });

  test('ordered block payload and movement invariants reject mismatches', () {
    expect(
      _throws(
        () => OrderedBlock(
          id: CatalogId('bad-conditioning'),
          order: 0,
          kind: BlockKind.conditioning,
          movementId: squat.id,
          conditioning: ConditioningPrescription(
            modality: ConditioningModality.time,
            target: 10,
          ),
        ),
      ),
      true,
    );
  });

  test('plating requires a compatible bar, plates and external load', () {
    expect(
      _throws(
        () => PlatingRequest(
          target: 100,
          unit: WeightUnit.kilograms,
          movement: squat,
          equipment: EquipmentProfile(
            equipmentIds: {CatalogId('barbell')},
            supportedLoads: {LoadKind.externalWeight},
          ),
        ),
      ),
      true,
    );
  });

  test('schedule rejects overlaps, invalid roles and duplicate TM points', () {
    final session = SessionPlan(
      id: CatalogId('role-session'),
      offsetDays: 0,
      roleId: CatalogId('role-a'),
      blocks: [
        OrderedBlock(
          id: CatalogId('role-work'),
          order: 0,
          kind: BlockKind.main,
          movementId: squat.id,
          strength: SetPrescription(
            sets: 1,
            repetitions: const FixedRepetitions(1),
            load: const PercentTrainingMax(90),
          ),
        ),
      ],
    );
    expect(
      _throws(
        () => FlexibleSchedule(
          startDate: DateTime.utc(2026),
          sessions: [session],
          segments: [
            ScheduleSegment(
              id: CatalogId('one'),
              kind: ScheduleSegmentKind.training,
              startOffsetDays: 0,
              durationDays: 7,
              frequency: 1,
              roleIds: {CatalogId('role-a')},
            ),
            ScheduleSegment(
              id: CatalogId('two'),
              kind: ScheduleSegmentKind.deload,
              startOffsetDays: 6,
              durationDays: 7,
              frequency: 1,
              roleIds: {CatalogId('role-a')},
            ),
          ],
        ),
      ),
      true,
    );
  });

  test('schedule validation rejects unknown block and TM movements', () {
    final unknown = CatalogId('unknown-movement');
    final schedule = FlexibleSchedule(
      startDate: DateTime.utc(2026),
      sessions: [
        SessionPlan(
          id: CatalogId('unknown-session'),
          offsetDays: 0,
          blocks: [
            OrderedBlock(
              id: CatalogId('unknown-work'),
              order: 0,
              kind: BlockKind.main,
              movementId: unknown,
              strength: SetPrescription(
                sets: 1,
                repetitions: const FixedRepetitions(1),
                load: const PercentTrainingMax(90),
              ),
            ),
          ],
        ),
      ],
      trainingMaxEvolution: [
        TrainingMaxEvolution(
          effectiveOffsetDays: 1,
          movementId: unknown,
          trainingMax: 100,
        ),
      ],
    );
    final snapshot = CatalogSnapshot(
      id: CatalogId('empty-snapshot'),
      revision: 1,
      contentHash: contentHash,
      canonicalizationVersion: 1,
      movements: [squat],
      templates: const [],
      modules: const [],
      finitePrograms: const [],
    );
    expect(schedule.validateAgainst(snapshot).length, 2);
  });

  test('assistance supports unbounded slot count and typed deload', () {
    final slots = List.generate(
      12,
      (index) => AssistanceSlot(
        id: CatalogId('slot-$index'),
        roleId: CatalogId('role-a'),
        minimumSelections: 1,
        maximumSelections: 1,
        movementIds: {squat.id},
      ),
    );
    final plan = AssistancePlan(
      slots: slots,
      selections: slots.map(
        (slot) => AssistanceSelection(
          slotId: slot.id,
          movementId: squat.id,
          regular: SetPrescription(
            sets: 5,
            repetitions: const FixedRepetitions(10),
            load: const PercentTrainingMax(50),
          ),
          deloadMode: AssistanceDeloadMode.omit,
        ),
      ),
    );
    expect(plan.slots.length, 12);
  });

  test('schedule preserves roles, segments, deload and TM evolution', () {
    final session = SessionPlan(
      id: CatalogId('session-a'),
      offsetDays: 0,
      roleId: CatalogId('squat-day'),
      blocks: [
        OrderedBlock(
          id: CatalogId('main-work'),
          order: 0,
          kind: BlockKind.main,
          movementId: squat.id,
          strength: SetPrescription(
            sets: 3,
            repetitions: const FixedRepetitions(5),
            load: const PercentTrainingMax(70),
          ),
        ),
      ],
    );
    final schedule = FlexibleSchedule(
      startDate: DateTime.utc(2026, 7, 21),
      sessions: [session],
      segments: [
        ScheduleSegment(
          id: CatalogId('deload-segment'),
          kind: ScheduleSegmentKind.deload,
          startOffsetDays: 0,
          durationDays: 7,
          frequency: 1,
          roleIds: {CatalogId('squat-day')},
        ),
      ],
      trainingMaxEvolution: [
        TrainingMaxEvolution(
          effectiveOffsetDays: 7,
          movementId: squat.id,
          trainingMax: 205,
        ),
      ],
    );
    expect(schedule.segments.single.kind, ScheduleSegmentKind.deload);
  });

  test('finite program distinguishes leader and anchor phases', () {
    FlexibleSchedule schedule() => FlexibleSchedule(
      startDate: DateTime.utc(2026),
      sessions: [
        SessionPlan(
          id: CatalogId('session'),
          offsetDays: 0,
          blocks: [
            OrderedBlock(
              id: CatalogId('work'),
              order: 0,
              kind: BlockKind.main,
              movementId: squat.id,
              strength: SetPrescription(
                sets: 1,
                repetitions: const Amrap(minimum: 1),
                load: const Unloaded(),
              ),
            ),
          ],
        ),
      ],
    );
    final definition = FiniteProgramDefinition(
      id: CatalogId('leader-anchor'),
      revision: 1,
      governance: published,
      evidence: source,
      phases: [
        ProgramPhase(
          id: CatalogId('leader'),
          role: ProgramPhaseRole.leader,
          segments: [
            ProgramSegment(
              id: CatalogId('leader-cycle'),
              templateId: CatalogId('template'),
              templateRevision: 1,
              variantId: CatalogId('variant'),
              schedule: schedule(),
              transitionAfter: TrainingMaxTransition.add(
                upperDelta: 5,
                lowerDelta: 10,
              ),
            ),
          ],
        ),
        ProgramPhase(
          id: CatalogId('anchor'),
          role: ProgramPhaseRole.anchor,
          segments: [
            ProgramSegment(
              id: CatalogId('anchor-cycle'),
              templateId: CatalogId('template'),
              templateRevision: 1,
              variantId: CatalogId('variant'),
              schedule: schedule(),
              transitionAfter: TrainingMaxTransition.testThenSet(),
            ),
          ],
        ),
      ],
    );
    expect(definition.phases.map((phase) => phase.role), [
      ProgramPhaseRole.leader,
      ProgramPhaseRole.anchor,
    ]);
  });
}

bool _throws(void Function() action) {
  try {
    action();
    return false;
  } on Object {
    return true;
  }
}
