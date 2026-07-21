import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/domain/generic_engine/generic_engine.dart';

void main() {
  final governance = CatalogGovernance(
    authority: CatalogAuthority.canonical,
    review: CatalogReviewStatus.confirmed,
    lifecycle: CatalogLifecycle.published,
    visibility: CatalogVisibility.public,
    executable: true,
  );
  final templateEvidence = _evidence('template-rule', 'p. 1');
  final movement = MovementDefinition(
    id: CatalogId('squat'),
    governance: governance,
    kind: MovementKind.barbell,
    bodyRegion: BodyRegion.lower,
    capabilities: const {},
    evidence: templateEvidence,
  );
  final calculationRule = MaxCalculationRule(
    id: CatalogId('calculation'),
    governance: governance,
    formulas: {RepMaxFormula.epley},
    evidence: templateEvidence,
  );

  EngineRequest request(
    TrainingTemplateGraph graph,
    CatalogId variantId,
    Map<CatalogId, ResolvedParameter> parameters,
  ) => EngineRequest(
    snapshot: CatalogSnapshot(
      id: CatalogId('snapshot'),
      revision: 1,
      contentHash:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      canonicalizationVersion: 1,
      movements: [movement],
      templates: [graph],
      modules: const [],
      finitePrograms: const [],
    ),
    templateId: graph.id,
    templateRevision: graph.revision,
    variantId: variantId,
    parameters: parameters,
    trainingMaxes: TrainingMaxConfiguration(
      calculationRule: calculationRule,
      globalRatio: .9,
      unit: WeightUnit.kilograms,
      roundingIncrement: 1,
      inputs: {
        movement.id: MaxInput(kind: MaxInputKind.oneRepMax, weight: 100),
      },
    ),
    equipment: EquipmentProfile(
      equipmentIds: const {},
      supportedLoads: const {},
    ),
  );

  test('A and B variants keep disjoint parameters and bindings', () {
    final parameterA = ParameterDefinition(
      id: CatalogId('parameter-a'),
      kind: ParameterKind.boolean,
      requiredWhen: const AlwaysCondition(true),
    );
    final parameterB = ParameterDefinition(
      id: CatalogId('parameter-b'),
      kind: ParameterKind.boolean,
      requiredWhen: const AlwaysCondition(true),
    );
    final graph = TrainingTemplateGraph(
      id: CatalogId('disjoint-template'),
      revision: 1,
      governance: governance,
      evidence: templateEvidence,
      variants: [
        TemplateVariant(
          id: CatalogId('variant-a'),
          parameters: [parameterA],
          moduleBindings: const [],
          rules: const [],
        ),
        TemplateVariant(
          id: CatalogId('variant-b'),
          parameters: [parameterB],
          moduleBindings: const [],
          rules: const [],
        ),
      ],
      parameters: const [],
      modules: const [],
    );

    final resolved = const TemplateContractResolver().resolve(
      request(graph, CatalogId('variant-b'), {
        parameterB.id: const BooleanParameter(true),
      }),
    );

    expect(resolved.issues, isEmpty);
    expect(resolved.value!.variant.parameters.map((value) => value.id), [
      parameterB.id,
    ]);
    expect(resolved.value!.variant.moduleBindings, isEmpty);
  });

  test('rules and constraints from an unselected variant never run', () {
    final graph = TrainingTemplateGraph(
      id: CatalogId('scoped-rule-template'),
      revision: 1,
      governance: governance,
      evidence: templateEvidence,
      variants: [
        TemplateVariant(
          id: CatalogId('variant-a'),
          parameters: const [],
          moduleBindings: const [],
          rules: [
            DeclarativeRule(
              id: CatalogId('a-only-constraint'),
              kind: DeclarativeRuleKind.constraint,
              expression: const AlwaysCondition(false),
              message: 'Only variant A is blocked.',
            ),
          ],
          evidence: [_evidence('a-only-constraint', 'p. 20')],
        ),
        TemplateVariant(
          id: CatalogId('variant-b'),
          parameters: const [],
          moduleBindings: const [],
          rules: const [],
        ),
      ],
      parameters: const [],
      modules: const [],
    );

    final resolved = const TemplateContractResolver().resolve(
      request(graph, CatalogId('variant-b'), const {}),
    );

    expect(resolved.issues, isEmpty);
  });

  test('selected variant required and compatibility rules fail closed', () {
    final parameter = ParameterDefinition(
      id: CatalogId('variant-option'),
      kind: ParameterKind.boolean,
    );
    final graph = TrainingTemplateGraph(
      id: CatalogId('selected-rules-template'),
      revision: 1,
      governance: governance,
      evidence: templateEvidence,
      variants: [
        TemplateVariant(
          id: CatalogId('variant-a'),
          parameters: [parameter],
          moduleBindings: const [],
          rules: [
            DeclarativeRule(
              id: CatalogId('required-option'),
              kind: DeclarativeRuleKind.required,
              targetParameterId: parameter.id,
              expression: const AlwaysCondition(true),
              message: 'The option is required.',
            ),
            DeclarativeRule(
              id: CatalogId('compatible-option'),
              kind: DeclarativeRuleKind.compatibility,
              expression: const AlwaysCondition(false),
              message: 'The selected variant is incompatible.',
            ),
          ],
          evidence: [
            _evidence('required-option', 'p. 30'),
            _evidence('compatible-option', 'p. 31'),
          ],
        ),
      ],
      parameters: const [],
      modules: const [],
    );

    final resolved = const TemplateContractResolver().resolve(
      request(graph, CatalogId('variant-a'), const {}),
    );

    expect(
      resolved.issues.map((issue) => issue.code),
      containsAll({'missing_canonical_parameter', 'compatible-option'}),
    );
  });

  test('unknown AST version and node are rejected at the codec boundary', () {
    expect(
      () => DeclarativeRuleAstBoundary.requireSupported(
        version: declarativeRuleAstVersion + 1,
        nodeType: 'always',
      ),
      throwsUnsupportedError,
    );
    expect(
      () => DeclarativeRuleAstBoundary.requireSupported(
        version: declarativeRuleAstVersion,
        nodeType: 'execute-code',
      ),
      throwsUnsupportedError,
    );
  });

  test('multiple evidence rows are grouped by rule id', () {
    final ruleId = CatalogId('scoped-rule');
    final variant = TemplateVariant(
      id: CatalogId('variant-a'),
      parameters: const [],
      moduleBindings: const [],
      rules: const [],
      evidence: [
        _evidence(ruleId.value, 'p. 10'),
        _evidence(ruleId.value, 'p. 11'),
        _evidence('another-rule', 'p. 12'),
      ],
    );

    expect(variant.evidenceByRuleId[ruleId], hasLength(2));
    expect(variant.evidenceByRuleId, hasLength(2));
    expect(
      () => variant.evidenceByRuleId[ruleId]!.add(
        EvidenceReference(
          sourceId: CatalogId('book'),
          locator: 'p. 99',
          sourceRevision: 1,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('canonical scoped rules without matching evidence are rejected', () {
    expect(
      () => TrainingTemplateGraph(
        id: CatalogId('unsourced-rule-template'),
        revision: 1,
        governance: governance,
        evidence: templateEvidence,
        variants: [
          TemplateVariant(
            id: CatalogId('variant-a'),
            parameters: const [],
            moduleBindings: const [],
            rules: [
              DeclarativeRule(
                id: CatalogId('unsourced-rule'),
                kind: DeclarativeRuleKind.constraint,
                expression: const AlwaysCondition(true),
                message: 'This rule has no matching evidence.',
              ),
            ],
          ),
        ],
        parameters: const [],
        modules: const [],
      ),
      throwsArgumentError,
    );
  });
}

CatalogEvidence _evidence(String ruleId, String locator) => CatalogEvidence(
  ruleId: CatalogId(ruleId),
  references: [
    EvidenceReference(
      sourceId: CatalogId('book'),
      locator: locator,
      sourceRevision: 1,
    ),
  ],
);
