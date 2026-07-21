import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/poc_531/data/generic_engine_sqlite_codec.dart';
import 'package:hybrid_training/features/poc_531/domain/generic_engine/generic_engine.dart';

void main() {
  const codec = GenericEngineSqliteCodec();

  group('parameter_schemas.schema_json', () {
    test('decodes v1 definitions and conditions into domain contracts', () {
      final definitions = codec.decodeParameterSchema(
        jsonEncode({
          'schemaVersion': 1,
          'parameters': [
            {
              'id': 'days-per-week',
              'kind': 'integer',
              'minimum': 2,
              'maximum': 4,
              'visibleWhen': {
                'astVersion': 1,
                'nodeType': 'always',
                'value': true,
              },
              'enabledWhen': {
                'astVersion': 1,
                'nodeType': 'not',
                'condition': {
                  'astVersion': 1,
                  'nodeType': 'present',
                  'parameterId': 'disabled-flag',
                },
              },
              'requiredWhen': {
                'astVersion': 1,
                'nodeType': 'equals',
                'parameterId': 'mode',
                'value': {'kind': 'enumeration', 'value': 'standard'},
              },
            },
            {
              'id': 'main-lift',
              'kind': 'movement',
              'allowedIds': ['squat', 'deadlift'],
              'allowedIdsWhen': [
                {
                  'when': {
                    'astVersion': 1,
                    'nodeType': 'all',
                    'conditions': [
                      {
                        'astVersion': 1,
                        'nodeType': 'present',
                        'parameterId': 'days-per-week',
                      },
                    ],
                  },
                  'allowedIds': ['squat'],
                },
              ],
            },
          ],
        }),
      );

      expect(definitions, hasLength(2));
      expect(definitions.first.id, CatalogId('days-per-week'));
      expect(definitions.first.kind, ParameterKind.integer);
      expect(definitions.first.minimum, 2);
      expect(definitions.first.maximum, 4);
      expect(definitions.first.requiredWhen, isA<EqualsCondition>());
      expect(definitions.last.allowedIds, {
        CatalogId('squat'),
        CatalogId('deadlift'),
      });
      expect(definitions.last.allowedIdsWhen, hasLength(1));
    });

    test('rejects unknown nested fields at their exact path', () {
      expect(
        () => codec.decodeParameterSchema(
          jsonEncode({
            'schemaVersion': 1,
            'parameters': [
              {
                'id': 'days',
                'kind': 'integer',
                'visibleWhen': {
                  'astVersion': 1,
                  'nodeType': 'always',
                  'value': true,
                  'fallback': false,
                },
              },
            ],
          }),
        ),
        throwsA(
          isA<GenericEngineCodecException>()
              .having((error) => error.code, 'code', 'unknown_field')
              .having(
                (error) => error.path,
                'path',
                r'$.parameters[0].visibleWhen.fallback',
              ),
        ),
      );
    });
  });

  group('module_versions.definition_json', () {
    test('decodes a v1 definition with row context', () {
      final definition = codec.decodeModuleDefinition(
        jsonEncode({
          'schemaVersion': 1,
          'requiredMovementCapabilities': ['barbell'],
          'requiredEquipment': ['rack'],
          'supportedLoadKinds': ['percentTrainingMax'],
          'inputPorts': [
            {'id': 'main-lift', 'kind': 'movement', 'required': true},
          ],
          'outputPorts': [
            {'id': 'work-sets', 'kind': 'prescription', 'required': true},
          ],
        }),
        id: CatalogId('main-work'),
        revision: 3,
        governance: _governance,
        evidence: _evidence,
      );

      expect(definition.id, CatalogId('main-work'));
      expect(definition.revision, 3);
      expect(definition.supportedLoadKinds, {LoadKind.percentTrainingMax});
      expect(definition.inputPorts.single.kind, ModulePortKind.movement);
    });

    test('rejects unknown enum values', () {
      expect(
        () => codec.decodeModuleDefinition(
          jsonEncode({
            'schemaVersion': 1,
            'requiredMovementCapabilities': <String>[],
            'requiredEquipment': <String>[],
            'supportedLoadKinds': ['inventedLoad'],
            'inputPorts': <Object?>[],
            'outputPorts': <Object?>[],
          }),
          id: CatalogId('module'),
          revision: 1,
          governance: _governance,
          evidence: _evidence,
        ),
        throwsA(
          isA<GenericEngineCodecException>()
              .having((error) => error.code, 'code', 'unknown_enum')
              .having(
                (error) => error.path,
                'path',
                r'$.supportedLoadKinds[0]',
              ),
        ),
      );
    });
  });

  group('variant_module_bindings.configuration_json', () {
    test('decodes a v1 binding with row context', () {
      final binding = codec.decodeModuleBindingConfiguration(
        jsonEncode({
          'schemaVersion': 1,
          'inputs': [
            {
              'portId': 'upstream',
              'kind': 'module',
              'targetId': 'main-binding',
              'targetRevision': 2,
            },
          ],
          'requiredMovementCapabilities': ['barbell'],
        }),
        id: CatalogId('supplemental-binding'),
        moduleId: CatalogId('supplemental-work'),
        moduleRevision: 4,
      );

      expect(binding.id, CatalogId('supplemental-binding'));
      expect(binding.moduleId, CatalogId('supplemental-work'));
      expect(binding.moduleRevision, 4);
      expect(binding.inputs.single.targetRevision, 2);
    });

    test('rejects unknown nested binding fields', () {
      expect(
        () => codec.decodeModuleBindingConfiguration(
          jsonEncode({
            'schemaVersion': 1,
            'inputs': [
              {
                'portId': 'lift',
                'kind': 'movement',
                'targetId': 'squat',
                'rule': 'unsourced',
              },
            ],
            'requiredMovementCapabilities': <String>[],
          }),
          id: CatalogId('binding'),
          moduleId: CatalogId('module'),
          moduleRevision: 1,
        ),
        throwsA(
          isA<GenericEngineCodecException>()
              .having((error) => error.code, 'code', 'unknown_field')
              .having((error) => error.path, 'path', r'$.inputs[0].rule'),
        ),
      );
    });
  });

  group('declarative_rules.expression_json', () {
    test('encodes and decodes the complete closed v1 AST symmetrically', () {
      final source = DeclarativeRule(
        id: CatalogId('option-visible'),
        kind: DeclarativeRuleKind.visibility,
        targetParameterId: CatalogId('variant-option'),
        expression: AllCondition([
          PresentCondition(CatalogId('mode')),
          const NotCondition(AlwaysCondition(false)),
          EqualsCondition(
            CatalogId('mode'),
            IdParameter(CatalogId('standard'), ParameterKind.enumeration),
          ),
          AnyCondition(const [AlwaysCondition(true), AlwaysCondition(false)]),
        ]),
        message: 'genericEngine.rules.optionVisible',
      );

      final encoded = codec.encodeDeclarativeRule(source);
      final decoded = codec.decodeDeclarativeRule(
        encoded,
        id: source.id,
        kind: source.kind,
      );
      final json = jsonDecode(encoded) as Map<String, dynamic>;
      final condition = json['condition'] as Map<String, dynamic>;

      expect(json['schemaVersion'], 1);
      expect(json['ruleId'], 'option-visible');
      expect(json['messageKey'], 'genericEngine.rules.optionVisible');
      expect(condition['astVersion'], 1);
      expect(condition['nodeType'], 'all');
      expect(decoded.id, source.id);
      expect(decoded.kind, DeclarativeRuleKind.visibility);
      expect(decoded.targetParameterId, CatalogId('variant-option'));
      expect(decoded.expression, isA<AllCondition>());
    });

    test('rejects unknown AST versions and node types', () {
      Map<String, Object?> envelope(Map<String, Object?> condition) => {
        'schemaVersion': 1,
        'ruleId': 'compatibility-rule',
        'kind': 'compatibility',
        'condition': condition,
        'messageKey': 'genericEngine.rules.compatibility',
      };

      expect(
        () => codec.decodeDeclarativeRule(
          jsonEncode(
            envelope({'astVersion': 2, 'nodeType': 'always', 'value': true}),
          ),
          id: CatalogId('compatibility-rule'),
          kind: DeclarativeRuleKind.compatibility,
        ),
        throwsA(
          isA<GenericEngineCodecException>()
              .having((error) => error.code, 'code', 'unsupported_ast_version')
              .having((error) => error.path, 'path', r'$.condition.astVersion'),
        ),
      );
      expect(
        () => codec.decodeDeclarativeRule(
          jsonEncode(envelope({'astVersion': 1, 'nodeType': 'executeCode'})),
          id: CatalogId('compatibility-rule'),
          kind: DeclarativeRuleKind.compatibility,
        ),
        throwsA(
          isA<GenericEngineCodecException>()
              .having((error) => error.code, 'code', 'unknown_ast_node')
              .having((error) => error.path, 'path', r'$.condition.nodeType'),
        ),
      );
    });

    test('rejects row mismatch and kind-specific target shapes', () {
      final visibility = {
        'schemaVersion': 1,
        'ruleId': 'visible-option',
        'kind': 'visibility',
        'condition': {'astVersion': 1, 'nodeType': 'always', 'value': true},
        'messageKey': 'genericEngine.rules.visibleOption',
      };
      expect(
        () => codec.decodeDeclarativeRule(
          jsonEncode(visibility),
          id: CatalogId('visible-option'),
          kind: DeclarativeRuleKind.visibility,
        ),
        throwsA(
          isA<GenericEngineCodecException>()
              .having((error) => error.code, 'code', 'missing_field')
              .having((error) => error.path, 'path', r'$.targetParameterId'),
        ),
      );

      final compatibility = {
        ...visibility,
        'ruleId': 'compatible-option',
        'kind': 'compatibility',
        'targetParameterId': 'variant-option',
      };
      expect(
        () => codec.decodeDeclarativeRule(
          jsonEncode(compatibility),
          id: CatalogId('compatible-option'),
          kind: DeclarativeRuleKind.compatibility,
        ),
        throwsA(
          isA<GenericEngineCodecException>()
              .having((error) => error.code, 'code', 'unknown_field')
              .having((error) => error.path, 'path', r'$.targetParameterId'),
        ),
      );
      expect(
        () => codec.decodeDeclarativeRule(
          jsonEncode({...compatibility}..remove('targetParameterId')),
          id: CatalogId('different-row-id'),
          kind: DeclarativeRuleKind.compatibility,
        ),
        throwsA(
          isA<GenericEngineCodecException>()
              .having((error) => error.code, 'code', 'invalid_value')
              .having((error) => error.path, 'path', r'$.ruleId'),
        ),
      );
    });

    test('requires a stable namespaced localization key', () {
      expect(
        () => codec.decodeDeclarativeRule(
          jsonEncode({
            'schemaVersion': 1,
            'ruleId': 'rule',
            'kind': 'constraint',
            'condition': {'astVersion': 1, 'nodeType': 'always', 'value': true},
            'messageKey': 'Free text is forbidden',
          }),
          id: CatalogId('rule'),
          kind: DeclarativeRuleKind.constraint,
        ),
        throwsA(
          isA<GenericEngineCodecException>()
              .having((error) => error.code, 'code', 'invalid_value')
              .having((error) => error.path, 'path', r'$.messageKey'),
        ),
      );
    });
  });

  test('assembles variant-scoped contracts and groups evidence by rule ID', () {
    final rule = DeclarativeRule(
      id: CatalogId('scoped-rule'),
      kind: DeclarativeRuleKind.constraint,
      expression: const AlwaysCondition(true),
      message: 'genericEngine.rules.scoped',
    );
    final variant = codec.assembleVariant(
      id: CatalogId('variant-a'),
      parameters: [
        ParameterDefinition(
          id: CatalogId('variant-option'),
          kind: ParameterKind.boolean,
        ),
      ],
      moduleBindings: const [],
      rules: [rule],
      evidenceRows: [
        RuleEvidenceRow(ruleId: rule.id, reference: _reference('p. 10')),
        RuleEvidenceRow(ruleId: rule.id, reference: _reference('p. 11')),
        RuleEvidenceRow(
          ruleId: CatalogId('another-rule'),
          reference: _reference('p. 12'),
        ),
      ],
    );

    expect(variant.parameters.single.id, CatalogId('variant-option'));
    expect(variant.rules.single.id, rule.id);
    expect(variant.evidenceByRuleId[rule.id], hasLength(2));
    expect(variant.evidenceByRuleId, hasLength(2));
  });

  group('workspace_drafts.payload_json', () {
    test('decodes v1 configuration values without inventing catalog rules', () {
      final draft = codec.decodeWorkspaceDraft(jsonEncode(_workspaceDraft));

      expect(draft.templateId, CatalogId('template'));
      expect(draft.templateRevision, 2);
      expect(draft.variantId, CatalogId('four-day'));
      expect(
        draft.parameters[CatalogId('days-per-week')],
        isA<NumberParameter>()
            .having((value) => value.kind, 'kind', ParameterKind.integer)
            .having((value) => value.value, 'value', 4),
      );
      expect(draft.trainingMaxes.calculationRuleId, CatalogId('tm-rule'));
      expect(
        draft.trainingMaxes.inputs[CatalogId('squat')]?.kind,
        MaxInputKind.repMax,
      );
      expect(draft.equipment.supportedLoads, {LoadKind.externalWeight});
      expect(draft.assistance, isNull);
      expect(draft.conditioning, isEmpty);
    });

    test('rejects unknown workspace fields', () {
      final invalid = Map<String, Object?>.from(_workspaceDraft)
        ..['automaticProgression'] = true;
      expect(
        () => codec.decodeWorkspaceDraft(jsonEncode(invalid)),
        throwsA(
          isA<GenericEngineCodecException>()
              .having((error) => error.code, 'code', 'unknown_field')
              .having((error) => error.path, 'path', r'$.automaticProgression'),
        ),
      );
    });
  });

  test('all SQLite payload decoders reject unknown schema versions', () {
    final calls = <void Function()>[
      () => codec.decodeParameterSchema(
        jsonEncode({'schemaVersion': 2, 'parameters': <Object?>[]}),
      ),
      () => codec.decodeModuleDefinition(
        jsonEncode({
          'schemaVersion': 2,
          'requiredMovementCapabilities': <String>[],
          'requiredEquipment': <String>[],
          'supportedLoadKinds': <String>[],
          'inputPorts': <Object?>[],
          'outputPorts': <Object?>[],
        }),
        id: CatalogId('module'),
        revision: 1,
        governance: _governance,
        evidence: _evidence,
      ),
      () => codec.decodeModuleBindingConfiguration(
        jsonEncode({
          'schemaVersion': 2,
          'inputs': <Object?>[],
          'requiredMovementCapabilities': <String>[],
        }),
        id: CatalogId('binding'),
        moduleId: CatalogId('module'),
        moduleRevision: 1,
      ),
      () => codec.decodeDeclarativeRule(
        jsonEncode({
          'schemaVersion': 2,
          'ruleId': 'rule',
          'kind': 'constraint',
          'condition': {'astVersion': 1, 'nodeType': 'always', 'value': true},
          'messageKey': 'genericEngine.rules.rule',
        }),
        id: CatalogId('rule'),
        kind: DeclarativeRuleKind.constraint,
      ),
      () => codec.decodeWorkspaceDraft(
        jsonEncode({..._workspaceDraft, 'schemaVersion': 2}),
      ),
    ];

    for (final call in calls) {
      expect(
        call,
        throwsA(
          isA<GenericEngineCodecException>()
              .having(
                (error) => error.code,
                'code',
                'unsupported_schema_version',
              )
              .having((error) => error.path, 'path', r'$.schemaVersion'),
        ),
      );
    }
  });
}

final _governance = CatalogGovernance(
  authority: CatalogAuthority.canonical,
  review: CatalogReviewStatus.confirmed,
  lifecycle: CatalogLifecycle.published,
  visibility: CatalogVisibility.public,
  executable: true,
);

final _evidence = CatalogEvidence(
  ruleId: CatalogId('module-rule'),
  references: [
    EvidenceReference(
      sourceId: CatalogId('source'),
      locator: 'fixture locator',
      sourceRevision: 1,
    ),
  ],
);

EvidenceReference _reference(String locator) => EvidenceReference(
  sourceId: CatalogId('source'),
  locator: locator,
  sourceRevision: 1,
);

final Map<String, Object?> _workspaceDraft = {
  'schemaVersion': 1,
  'templateId': 'template',
  'templateRevision': 2,
  'variantId': 'four-day',
  'parameters': [
    {
      'id': 'days-per-week',
      'value': {'kind': 'integer', 'value': 4},
    },
    {
      'id': 'main-lift',
      'value': {'kind': 'movement', 'value': 'squat'},
    },
  ],
  'trainingMaxes': {
    'calculationRuleId': 'tm-rule',
    'globalRatio': 0.9,
    'unit': 'kilograms',
    'roundingIncrement': 2.5,
    'inputs': [
      {
        'movementId': 'squat',
        'kind': 'repMax',
        'weight': 100,
        'repetitions': 5,
        'formula': 'epley',
      },
    ],
    'ratiosByMovement': [
      {'movementId': 'squat', 'ratio': 0.85},
    ],
  },
  'equipment': {
    'equipmentIds': ['barbell'],
    'supportedLoads': ['externalWeight'],
    'barWeight': 20,
    'availablePlates': [20, 10, 5, 2.5],
  },
  'conditioning': <Object?>[],
};
