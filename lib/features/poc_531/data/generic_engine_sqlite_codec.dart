import 'dart:convert';

import '../domain/generic_engine/generic_engine.dart';
import 'sqlite_catalog_snapshot_repository.dart';

/// A fail-closed error raised when persisted generic-engine JSON is not v1.
final class GenericEngineCodecException extends FormatException {
  const GenericEngineCodecException({
    required this.code,
    required this.path,
    required String message,
  }) : super(message);

  final String code;
  final String path;

  @override
  String toString() => '$code at $path: $message';
}

/// The configuration part of a workspace draft.
///
/// Catalog objects are deliberately referenced by stable ID. A repository can
/// resolve those IDs from the catalog snapshot before constructing an
/// [EngineRequest].
final class GenericEngineWorkspaceDraft {
  const GenericEngineWorkspaceDraft({
    required this.templateId,
    required this.templateRevision,
    required this.variantId,
    required this.parameters,
    required this.trainingMaxes,
    required this.equipment,
    required this.assistance,
    required this.conditioning,
  });

  final CatalogId templateId;
  final int templateRevision;
  final CatalogId variantId;
  final Map<CatalogId, ResolvedParameter> parameters;
  final WorkspaceTrainingMaxDraft trainingMaxes;
  final EquipmentProfile equipment;
  final AssistancePlan? assistance;
  final List<WorkspaceConditioningDraft> conditioning;
}

/// Training-max values persisted in a workspace, before catalog rule lookup.
final class WorkspaceTrainingMaxDraft {
  const WorkspaceTrainingMaxDraft({
    required this.calculationRuleId,
    required this.globalRatio,
    required this.unit,
    required this.roundingIncrement,
    required this.inputs,
    required this.ratiosByMovement,
  });

  final CatalogId calculationRuleId;
  final double globalRatio;
  final WeightUnit unit;
  final double roundingIncrement;
  final Map<CatalogId, MaxInput> inputs;
  final Map<CatalogId, double> ratiosByMovement;

  TrainingMaxConfiguration resolve(MaxCalculationRule calculationRule) {
    if (calculationRule.id != calculationRuleId) {
      throw ArgumentError.value(
        calculationRule.id,
        'calculationRule',
        'Resolved calculation rule has the wrong stable ID.',
      );
    }
    return TrainingMaxConfiguration(
      calculationRule: calculationRule,
      globalRatio: globalRatio,
      unit: unit,
      roundingIncrement: roundingIncrement,
      inputs: inputs,
      ratiosByMovement: ratiosByMovement,
    );
  }
}

/// A conditioning choice persisted before its catalog definition is resolved.
final class WorkspaceConditioningDraft {
  const WorkspaceConditioningDraft({
    required this.definitionId,
    required this.prescription,
  });

  final CatalogId definitionId;
  final ConditioningPrescription prescription;

  ConditioningConfiguration resolve(ConditioningDefinition definition) {
    if (definition.id != definitionId) {
      throw ArgumentError.value(
        definition.id,
        'definition',
        'Resolved conditioning definition has the wrong stable ID.',
      );
    }
    return ConditioningConfiguration(
      definition: definition,
      prescription: prescription,
    );
  }
}

/// Strict v1 decoder for generic-engine JSON stored in SQLite text columns.
///
/// Every object is closed: unknown fields, enum values and schema versions are
/// rejected instead of being ignored.
final class GenericEngineSqliteCodec implements CatalogSnapshotCodec {
  const GenericEngineSqliteCodec();

  static const schemaVersion = 1;

  @override
  List<ParameterDefinition> decodeParameterSchema(String json) {
    final root = _root(json);
    _closed(root, r'$', required: const {'schemaVersion', 'parameters'});
    _version(root);
    final values = _list(root['parameters'], r'$.parameters');
    final result = <ParameterDefinition>[
      for (var index = 0; index < values.length; index++)
        _parameter(
          values[index],
          r'$.parameters'
          '[$index]',
        ),
    ];
    _uniqueIds(result.map((value) => value.id), r'$.parameters');
    return List.unmodifiable(result);
  }

  @override
  ModuleDefinition decodeModuleDefinition(
    String json, {
    required CatalogId id,
    required int revision,
    required CatalogGovernance governance,
    CatalogEvidence? evidence,
  }) {
    final root = _root(json);
    _closed(
      root,
      r'$',
      required: const {
        'schemaVersion',
        'requiredMovementCapabilities',
        'requiredEquipment',
        'supportedLoadKinds',
        'inputPorts',
        'outputPorts',
      },
    );
    _version(root);
    try {
      return ModuleDefinition(
        id: id,
        revision: revision,
        governance: governance,
        requiredMovementCapabilities: _idSet(
          root['requiredMovementCapabilities'],
          r'$.requiredMovementCapabilities',
        ),
        requiredEquipment: _idSet(
          root['requiredEquipment'],
          r'$.requiredEquipment',
        ),
        supportedLoadKinds: _enumSet(
          root['supportedLoadKinds'],
          r'$.supportedLoadKinds',
          LoadKind.values,
        ),
        inputPorts: _ports(root['inputPorts'], r'$.inputPorts'),
        outputPorts: _ports(root['outputPorts'], r'$.outputPorts'),
        evidence: evidence,
      );
    } on ArgumentError catch (error) {
      throw _invalid(r'$', error.message.toString());
    }
  }

  @override
  ModuleBinding decodeModuleBindingConfiguration(
    String json, {
    required CatalogId id,
    required CatalogId moduleId,
    required int moduleRevision,
  }) {
    final root = _root(json);
    _closed(
      root,
      r'$',
      required: const {
        'schemaVersion',
        'inputs',
        'requiredMovementCapabilities',
      },
    );
    _version(root);
    final rawInputs = _list(root['inputs'], r'$.inputs');
    try {
      return ModuleBinding(
        id: id,
        moduleId: moduleId,
        moduleRevision: moduleRevision,
        inputs: [
          for (var index = 0; index < rawInputs.length; index++)
            _binding(
              rawInputs[index],
              r'$.inputs'
              '[$index]',
            ),
        ],
        requiredMovementCapabilities: _idSet(
          root['requiredMovementCapabilities'],
          r'$.requiredMovementCapabilities',
        ),
      );
    } on ArgumentError catch (error) {
      throw _invalid(r'$', error.message.toString());
    }
  }

  @override
  DeclarativeRule decodeDeclarativeRule(
    String json, {
    required CatalogId id,
    required DeclarativeRuleKind kind,
  }) {
    final root = _root(json);
    _version(root);
    final decodedKind = _enum(
      root['kind'],
      r'$.kind',
      DeclarativeRuleKind.values,
    );
    final targetsParameter =
        decodedKind == DeclarativeRuleKind.visibility ||
        decodedKind == DeclarativeRuleKind.required;
    _closed(
      root,
      r'$',
      required: {
        'schemaVersion',
        'ruleId',
        'kind',
        'condition',
        'messageKey',
        if (targetsParameter) 'targetParameterId',
      },
    );
    final decodedId = _id(root['ruleId'], r'$.ruleId');
    if (decodedId != id) {
      throw _invalid(r'$.ruleId', 'Rule ID does not match its SQL row.');
    }
    if (decodedKind != kind) {
      throw _invalid(r'$.kind', 'Rule kind does not match its SQL row.');
    }
    try {
      return DeclarativeRule(
        id: decodedId,
        kind: decodedKind,
        expression: _condition(root['condition'], r'$.condition'),
        message: _messageKey(root['messageKey'], r'$.messageKey'),
        targetParameterId: targetsParameter
            ? _id(root['targetParameterId'], r'$.targetParameterId')
            : null,
      );
    } on ArgumentError catch (error) {
      throw _invalid(r'$', error.message.toString());
    }
  }

  String encodeDeclarativeRule(DeclarativeRule rule) {
    final targetsParameter =
        rule.kind == DeclarativeRuleKind.visibility ||
        rule.kind == DeclarativeRuleKind.required;
    if (targetsParameter != (rule.targetParameterId != null)) {
      throw _invalid(
        r'$.targetParameterId',
        'Rule target does not match its kind.',
      );
    }
    final messageKey = _messageKey(rule.message, r'$.messageKey');
    return jsonEncode(
      _canonicalize({
        'schemaVersion': schemaVersion,
        'ruleId': rule.id.value,
        'kind': rule.kind.name,
        'condition': _encodeCondition(rule.expression),
        'messageKey': messageKey,
        if (rule.targetParameterId case final target?)
          'targetParameterId': target.value,
      }),
    );
  }

  TemplateVariant assembleVariant({
    required CatalogId id,
    required Iterable<ParameterDefinition> parameters,
    required Iterable<ModuleBinding> moduleBindings,
    required Iterable<DeclarativeRule> rules,
    required Iterable<RuleEvidenceRow> evidenceRows,
  }) => TemplateVariant(
    id: id,
    parameters: parameters,
    moduleBindings: moduleBindings,
    rules: rules,
    evidence: groupEvidenceByRuleId(evidenceRows),
  );

  GenericEngineWorkspaceDraft decodeWorkspaceDraft(String json) {
    final root = _root(json);
    _closed(
      root,
      r'$',
      required: const {
        'schemaVersion',
        'templateId',
        'templateRevision',
        'variantId',
        'parameters',
        'trainingMaxes',
        'equipment',
        'conditioning',
      },
      optional: const {'assistance'},
    );
    _version(root);
    final parameters = _parametersMap(root['parameters'], r'$.parameters');
    final trainingMaxes = _trainingMaxes(
      root['trainingMaxes'],
      r'$.trainingMaxes',
    );
    final conditioningValues = _list(root['conditioning'], r'$.conditioning');
    return GenericEngineWorkspaceDraft(
      templateId: _id(root['templateId'], r'$.templateId'),
      templateRevision: _positiveInt(
        root['templateRevision'],
        r'$.templateRevision',
      ),
      variantId: _id(root['variantId'], r'$.variantId'),
      parameters: Map.unmodifiable(parameters),
      trainingMaxes: trainingMaxes,
      equipment: _equipment(root['equipment'], r'$.equipment'),
      assistance: root.containsKey('assistance')
          ? _assistance(root['assistance'], r'$.assistance')
          : null,
      conditioning: List.unmodifiable([
        for (var index = 0; index < conditioningValues.length; index++)
          _conditioning(
            conditioningValues[index],
            r'$.conditioning'
            '[$index]',
          ),
      ]),
    );
  }
}

/// One confirmed SQL evidence row before references are grouped by rule ID.
final class RuleEvidenceRow {
  const RuleEvidenceRow({required this.ruleId, required this.reference});

  final CatalogId ruleId;
  final EvidenceReference reference;
}

List<CatalogEvidence> groupEvidenceByRuleId(Iterable<RuleEvidenceRow> rows) {
  final grouped = <CatalogId, List<EvidenceReference>>{};
  for (final row in rows) {
    grouped.putIfAbsent(row.ruleId, () => []).add(row.reference);
  }
  return List.unmodifiable([
    for (final entry in grouped.entries)
      CatalogEvidence(ruleId: entry.key, references: entry.value),
  ]);
}

Map<String, Object?> _root(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw GenericEngineCodecException(
      code: 'invalid_json',
      path: r'$',
      message: error.message,
    );
  }
  return _object(decoded, r'$');
}

void _version(Map<String, Object?> root) {
  if (root['schemaVersion'] != GenericEngineSqliteCodec.schemaVersion) {
    throw const GenericEngineCodecException(
      code: 'unsupported_schema_version',
      path: r'$.schemaVersion',
      message: 'Only generic-engine schema version 1 is supported.',
    );
  }
}

ParameterDefinition _parameter(Object? value, String path) {
  final object = _object(value, path);
  _closed(
    object,
    path,
    required: const {'id', 'kind'},
    optional: const {
      'minimum',
      'maximum',
      'allowedIds',
      'allowedIdsWhen',
      'visibleWhen',
      'enabledWhen',
      'requiredWhen',
    },
  );
  final conditionalValues = object.containsKey('allowedIdsWhen')
      ? _list(object['allowedIdsWhen'], '$path.allowedIdsWhen')
      : const <Object?>[];
  try {
    return ParameterDefinition(
      id: _id(object['id'], '$path.id'),
      kind: _enum(object['kind'], '$path.kind', ParameterKind.values),
      minimum: object.containsKey('minimum')
          ? _number(object['minimum'], '$path.minimum')
          : null,
      maximum: object.containsKey('maximum')
          ? _number(object['maximum'], '$path.maximum')
          : null,
      allowedIds: object.containsKey('allowedIds')
          ? _idSet(object['allowedIds'], '$path.allowedIds')
          : const {},
      allowedIdsWhen: [
        for (var index = 0; index < conditionalValues.length; index++)
          _conditionalAllowedIds(
            conditionalValues[index],
            '$path.allowedIdsWhen[$index]',
          ),
      ],
      visibleWhen: object.containsKey('visibleWhen')
          ? _condition(object['visibleWhen'], '$path.visibleWhen')
          : const AlwaysCondition(true),
      enabledWhen: object.containsKey('enabledWhen')
          ? _condition(object['enabledWhen'], '$path.enabledWhen')
          : const AlwaysCondition(true),
      requiredWhen: object.containsKey('requiredWhen')
          ? _condition(object['requiredWhen'], '$path.requiredWhen')
          : const AlwaysCondition(false),
    );
  } on ArgumentError catch (error) {
    throw _invalid(path, error.message.toString());
  }
}

ConditionalAllowedIds _conditionalAllowedIds(Object? value, String path) {
  final object = _object(value, path);
  _closed(object, path, required: const {'when', 'allowedIds'});
  return ConditionalAllowedIds(
    when: _condition(object['when'], '$path.when'),
    allowedIds: _idSet(object['allowedIds'], '$path.allowedIds'),
  );
}

ParameterCondition _condition(Object? value, String path) {
  final object = _object(value, path);
  final version = _integer(object['astVersion'], '$path.astVersion');
  if (version != declarativeRuleAstVersion) {
    throw GenericEngineCodecException(
      code: 'unsupported_ast_version',
      path: '$path.astVersion',
      message: 'Only declarative rule AST version 1 is supported.',
    );
  }
  final nodeType = _string(object['nodeType'], '$path.nodeType');
  if (!DeclarativeRuleAstBoundary.supportedNodeTypes.contains(nodeType)) {
    throw GenericEngineCodecException(
      code: 'unknown_ast_node',
      path: '$path.nodeType',
      message: 'Unknown declarative rule AST node: $nodeType.',
    );
  }
  switch (nodeType) {
    case 'always':
      _closed(
        object,
        path,
        required: const {'astVersion', 'nodeType', 'value'},
      );
      return AlwaysCondition(_boolean(object['value'], '$path.value'));
    case 'present':
      _closed(
        object,
        path,
        required: const {'astVersion', 'nodeType', 'parameterId'},
      );
      return PresentCondition(_id(object['parameterId'], '$path.parameterId'));
    case 'equals':
      _closed(
        object,
        path,
        required: const {'astVersion', 'nodeType', 'parameterId', 'value'},
      );
      return EqualsCondition(
        _id(object['parameterId'], '$path.parameterId'),
        _resolvedParameter(object['value'], '$path.value'),
      );
    case 'not':
      _closed(
        object,
        path,
        required: const {'astVersion', 'nodeType', 'condition'},
      );
      return NotCondition(_condition(object['condition'], '$path.condition'));
    case 'all':
    case 'any':
      _closed(
        object,
        path,
        required: const {'astVersion', 'nodeType', 'conditions'},
      );
      final values = _list(object['conditions'], '$path.conditions');
      final conditions = [
        for (var index = 0; index < values.length; index++)
          _condition(values[index], '$path.conditions[$index]'),
      ];
      return nodeType == 'all'
          ? AllCondition(conditions)
          : AnyCondition(conditions);
    default:
      throw StateError('AST node was validated before dispatch.');
  }
}

Map<String, Object?> _encodeCondition(ParameterCondition condition) {
  DeclarativeRuleAstBoundary.requireSupported(
    version: condition.astVersion,
    nodeType: condition.nodeType,
  );
  return switch (condition) {
    AlwaysCondition(:final value) => {
      'astVersion': condition.astVersion,
      'nodeType': condition.nodeType,
      'value': value,
    },
    PresentCondition(:final id) => {
      'astVersion': condition.astVersion,
      'nodeType': condition.nodeType,
      'parameterId': id.value,
    },
    EqualsCondition(:final id, :final expected) => {
      'astVersion': condition.astVersion,
      'nodeType': condition.nodeType,
      'parameterId': id.value,
      'value': _encodeResolvedParameter(expected),
    },
    NotCondition(condition: final nested) => {
      'astVersion': condition.astVersion,
      'nodeType': condition.nodeType,
      'condition': _encodeCondition(nested),
    },
    AllCondition(:final conditions) || AnyCondition(:final conditions) => {
      'astVersion': condition.astVersion,
      'nodeType': condition.nodeType,
      'conditions': conditions.map(_encodeCondition).toList(growable: false),
    },
  };
}

Map<String, Object?> _encodeResolvedParameter(ResolvedParameter parameter) => {
  'kind': parameter.kind.name,
  'value': switch (parameter) {
    BooleanParameter(:final value) => value,
    NumberParameter(:final value) => value,
    IdParameter(:final value) => value.value,
  },
};

ResolvedParameter _resolvedParameter(Object? value, String path) {
  final object = _object(value, path);
  _closed(object, path, required: const {'kind', 'value'});
  final kind = _enum(object['kind'], '$path.kind', ParameterKind.values);
  try {
    return switch (kind) {
      ParameterKind.boolean => BooleanParameter(
        _boolean(object['value'], '$path.value'),
      ),
      ParameterKind.integer ||
      ParameterKind.decimal ||
      ParameterKind.duration => NumberParameter(
        _number(object['value'], '$path.value'),
        kind,
      ),
      ParameterKind.enumeration || ParameterKind.movement => IdParameter(
        _id(object['value'], '$path.value'),
        kind,
      ),
    };
  } on ArgumentError catch (error) {
    throw _invalid(path, error.message.toString());
  }
}

List<ModulePort> _ports(Object? value, String path) {
  final values = _list(value, path);
  return [
    for (var index = 0; index < values.length; index++)
      _port(values[index], '$path[$index]'),
  ];
}

ModulePort _port(Object? value, String path) {
  final object = _object(value, path);
  _closed(object, path, required: const {'id', 'kind', 'required'});
  return ModulePort(
    id: _id(object['id'], '$path.id'),
    kind: _enum(object['kind'], '$path.kind', ModulePortKind.values),
    required: _boolean(object['required'], '$path.required'),
  );
}

PortBinding _binding(Object? value, String path) {
  final object = _object(value, path);
  _closed(
    object,
    path,
    required: const {'portId', 'kind', 'targetId'},
    optional: const {'targetRevision'},
  );
  return PortBinding(
    portId: _id(object['portId'], '$path.portId'),
    kind: _enum(object['kind'], '$path.kind', ModulePortKind.values),
    targetId: _id(object['targetId'], '$path.targetId'),
    targetRevision: object.containsKey('targetRevision')
        ? _positiveInt(object['targetRevision'], '$path.targetRevision')
        : null,
  );
}

Map<CatalogId, ResolvedParameter> _parametersMap(Object? value, String path) {
  final values = _list(value, path);
  final result = <CatalogId, ResolvedParameter>{};
  for (var index = 0; index < values.length; index++) {
    final entryPath = '$path[$index]';
    final object = _object(values[index], entryPath);
    _closed(object, entryPath, required: const {'id', 'value'});
    final id = _id(object['id'], '$entryPath.id');
    if (result.containsKey(id)) {
      throw _invalid('$entryPath.id', 'Duplicate parameter ID.');
    }
    result[id] = _resolvedParameter(object['value'], '$entryPath.value');
  }
  return result;
}

WorkspaceTrainingMaxDraft _trainingMaxes(Object? value, String path) {
  final object = _object(value, path);
  _closed(
    object,
    path,
    required: const {
      'calculationRuleId',
      'globalRatio',
      'unit',
      'roundingIncrement',
      'inputs',
      'ratiosByMovement',
    },
  );
  final inputs = <CatalogId, MaxInput>{};
  final rawInputs = _list(object['inputs'], '$path.inputs');
  for (var index = 0; index < rawInputs.length; index++) {
    final entryPath = '$path.inputs[$index]';
    final entry = _object(rawInputs[index], entryPath);
    _closed(
      entry,
      entryPath,
      required: const {'movementId', 'kind', 'weight'},
      optional: const {'repetitions', 'formula'},
    );
    final movementId = _id(entry['movementId'], '$entryPath.movementId');
    if (inputs.containsKey(movementId)) {
      throw _invalid('$entryPath.movementId', 'Duplicate movement ID.');
    }
    final kind = _enum(entry['kind'], '$entryPath.kind', MaxInputKind.values);
    try {
      inputs[movementId] = MaxInput(
        kind: kind,
        weight: _number(entry['weight'], '$entryPath.weight'),
        repetitions: entry.containsKey('repetitions')
            ? _positiveInt(entry['repetitions'], '$entryPath.repetitions')
            : null,
        formula: entry.containsKey('formula')
            ? _enum(
                entry['formula'],
                '$entryPath.formula',
                RepMaxFormula.values,
              )
            : null,
      );
    } on ArgumentError catch (error) {
      throw _invalid(entryPath, error.message.toString());
    }
  }
  final ratios = <CatalogId, double>{};
  final rawRatios = _list(object['ratiosByMovement'], '$path.ratiosByMovement');
  for (var index = 0; index < rawRatios.length; index++) {
    final entryPath = '$path.ratiosByMovement[$index]';
    final entry = _object(rawRatios[index], entryPath);
    _closed(entry, entryPath, required: const {'movementId', 'ratio'});
    final movementId = _id(entry['movementId'], '$entryPath.movementId');
    if (ratios.containsKey(movementId)) {
      throw _invalid('$entryPath.movementId', 'Duplicate movement ID.');
    }
    ratios[movementId] = _number(entry['ratio'], '$entryPath.ratio');
  }
  return WorkspaceTrainingMaxDraft(
    calculationRuleId: _id(
      object['calculationRuleId'],
      '$path.calculationRuleId',
    ),
    globalRatio: _ratio(object['globalRatio'], '$path.globalRatio'),
    unit: _enum(object['unit'], '$path.unit', WeightUnit.values),
    roundingIncrement: _positiveNumber(
      object['roundingIncrement'],
      '$path.roundingIncrement',
    ),
    inputs: Map.unmodifiable(inputs),
    ratiosByMovement: Map.unmodifiable(ratios),
  );
}

EquipmentProfile _equipment(Object? value, String path) {
  final object = _object(value, path);
  _closed(
    object,
    path,
    required: const {'equipmentIds', 'supportedLoads', 'availablePlates'},
    optional: const {'barWeight'},
  );
  try {
    return EquipmentProfile(
      equipmentIds: _idSet(object['equipmentIds'], '$path.equipmentIds'),
      supportedLoads: _enumSet(
        object['supportedLoads'],
        '$path.supportedLoads',
        LoadKind.values,
      ),
      barWeight: object.containsKey('barWeight')
          ? _positiveNumber(object['barWeight'], '$path.barWeight')
          : null,
      availablePlates: _numberList(
        object['availablePlates'],
        '$path.availablePlates',
        positive: true,
      ),
    );
  } on ArgumentError catch (error) {
    throw _invalid(path, error.message.toString());
  }
}

AssistancePlan _assistance(Object? value, String path) {
  final object = _object(value, path);
  _closed(object, path, required: const {'slots', 'selections'});
  final rawSlots = _list(object['slots'], '$path.slots');
  final rawSelections = _list(object['selections'], '$path.selections');
  try {
    return AssistancePlan(
      slots: [
        for (var index = 0; index < rawSlots.length; index++)
          _assistanceSlot(rawSlots[index], '$path.slots[$index]'),
      ],
      selections: [
        for (var index = 0; index < rawSelections.length; index++)
          _assistanceSelection(
            rawSelections[index],
            '$path.selections[$index]',
          ),
      ],
    );
  } on ArgumentError catch (error) {
    throw _invalid(path, error.message.toString());
  }
}

AssistanceSlot _assistanceSlot(Object? value, String path) {
  final object = _object(value, path);
  _closed(
    object,
    path,
    required: const {
      'id',
      'roleId',
      'minimumSelections',
      'maximumSelections',
      'movementIds',
    },
  );
  return AssistanceSlot(
    id: _id(object['id'], '$path.id'),
    roleId: _id(object['roleId'], '$path.roleId'),
    minimumSelections: _nonNegativeInt(
      object['minimumSelections'],
      '$path.minimumSelections',
    ),
    maximumSelections: _nonNegativeInt(
      object['maximumSelections'],
      '$path.maximumSelections',
    ),
    movementIds: _idSet(object['movementIds'], '$path.movementIds'),
  );
}

AssistanceSelection _assistanceSelection(Object? value, String path) {
  final object = _object(value, path);
  _closed(
    object,
    path,
    required: const {'slotId', 'movementId', 'regular', 'deloadMode'},
    optional: const {'deload'},
  );
  return AssistanceSelection(
    slotId: _id(object['slotId'], '$path.slotId'),
    movementId: _id(object['movementId'], '$path.movementId'),
    regular: _prescription(object['regular'], '$path.regular'),
    deloadMode: _enum(
      object['deloadMode'],
      '$path.deloadMode',
      AssistanceDeloadMode.values,
    ),
    deload: object.containsKey('deload')
        ? _prescription(object['deload'], '$path.deload')
        : null,
  );
}

WorkspaceConditioningDraft _conditioning(Object? value, String path) {
  final object = _object(value, path);
  _closed(object, path, required: const {'definitionId', 'prescription'});
  return WorkspaceConditioningDraft(
    definitionId: _id(object['definitionId'], '$path.definitionId'),
    prescription: _conditioningPrescription(
      object['prescription'],
      '$path.prescription',
    ),
  );
}

SetPrescription _prescription(Object? value, String path) {
  final object = _object(value, path);
  _closed(object, path, required: const {'sets', 'repetitions', 'load'});
  try {
    return SetPrescription(
      sets: _positiveInt(object['sets'], '$path.sets'),
      repetitions: _repetitions(object['repetitions'], '$path.repetitions'),
      load: _load(object['load'], '$path.load'),
    );
  } on ArgumentError catch (error) {
    throw _invalid(path, error.message.toString());
  }
}

RepetitionTarget _repetitions(Object? value, String path) {
  final object = _object(value, path);
  final kind = _string(object['kind'], '$path.kind');
  switch (kind) {
    case 'fixed':
      _closed(object, path, required: const {'kind', 'count'});
      return FixedRepetitions(_positiveInt(object['count'], '$path.count'));
    case 'range':
      _closed(object, path, required: const {'kind', 'minimum', 'maximum'});
      return RepetitionRange(
        _positiveInt(object['minimum'], '$path.minimum'),
        _positiveInt(object['maximum'], '$path.maximum'),
      );
    case 'amrap':
      _closed(
        object,
        path,
        required: const {'kind'},
        optional: const {'minimum'},
      );
      return Amrap(
        minimum: object.containsKey('minimum')
            ? _nonNegativeInt(object['minimum'], '$path.minimum')
            : null,
      );
    default:
      throw _unknownEnum('$path.kind', kind);
  }
}

LoadTarget _load(Object? value, String path) {
  final object = _object(value, path);
  final kind = _enum(object['kind'], '$path.kind', LoadKind.values);
  switch (kind) {
    case LoadKind.none:
      _closed(object, path, required: const {'kind'});
      return const Unloaded();
    case LoadKind.bodyweight:
      _closed(object, path, required: const {'kind'});
      return const BodyweightLoad();
    case LoadKind.percentTrainingMax:
      _closed(object, path, required: const {'kind', 'percent'});
      return PercentTrainingMax(_ratio(object['percent'], '$path.percent'));
    case LoadKind.percentOneRepMax:
      _closed(object, path, required: const {'kind', 'percent'});
      return PercentOneRepMax(_ratio(object['percent'], '$path.percent'));
    case LoadKind.externalWeight:
    case LoadKind.machineSetting:
    case LoadKind.equipmentSetting:
    case LoadKind.assistedBodyweight:
    case LoadKind.addedBodyweightLoad:
      _closed(object, path, required: const {'kind', 'amount'});
      try {
        return DirectLoad(_number(object['amount'], '$path.amount'), kind);
      } on ArgumentError catch (error) {
        throw _invalid(path, error.message.toString());
      }
  }
}

ConditioningPrescription _conditioningPrescription(Object? value, String path) {
  final object = _object(value, path);
  _closed(
    object,
    path,
    required: const {'modality'},
    optional: const {'target', 'workSeconds', 'restSeconds'},
  );
  try {
    return ConditioningPrescription(
      modality: _enum(
        object['modality'],
        '$path.modality',
        ConditioningModality.values,
      ),
      target: object.containsKey('target')
          ? _positiveNumber(object['target'], '$path.target')
          : null,
      workSeconds: object.containsKey('workSeconds')
          ? _positiveInt(object['workSeconds'], '$path.workSeconds')
          : null,
      restSeconds: object.containsKey('restSeconds')
          ? _nonNegativeInt(object['restSeconds'], '$path.restSeconds')
          : null,
    );
  } on ArgumentError catch (error) {
    throw _invalid(path, error.message.toString());
  }
}

Map<String, Object?> _object(Object? value, String path) {
  if (value is! Map<String, dynamic>) {
    throw _type(path, 'object');
  }
  return value.cast<String, Object?>();
}

List<Object?> _list(Object? value, String path) {
  if (value is! List) throw _type(path, 'array');
  return value.cast<Object?>();
}

void _closed(
  Map<String, Object?> object,
  String path, {
  required Set<String> required,
  Set<String> optional = const {},
}) {
  for (final key in required) {
    if (!object.containsKey(key)) {
      throw GenericEngineCodecException(
        code: 'missing_field',
        path: '$path.$key',
        message: 'Required field is missing.',
      );
    }
  }
  final allowed = {...required, ...optional};
  for (final key in object.keys) {
    if (!allowed.contains(key)) {
      throw GenericEngineCodecException(
        code: 'unknown_field',
        path: '$path.$key',
        message: 'Unknown field.',
      );
    }
  }
}

String _string(Object? value, String path) {
  if (value is! String || value.isEmpty) throw _type(path, 'non-empty string');
  return value;
}

String _messageKey(Object? value, String path) {
  final key = _string(value, path);
  if (!RegExp(r'^[a-z][a-zA-Z0-9]*(?:\.[a-z][a-zA-Z0-9]*)+$').hasMatch(key)) {
    throw _invalid(path, 'Expected a stable namespaced localization key.');
  }
  return key;
}

bool _boolean(Object? value, String path) {
  if (value is! bool) throw _type(path, 'boolean');
  return value;
}

double _number(Object? value, String path) {
  if (value is! num || !value.isFinite) throw _type(path, 'finite number');
  return value.toDouble();
}

double _positiveNumber(Object? value, String path) {
  final result = _number(value, path);
  if (result <= 0) throw _invalid(path, 'Expected a positive number.');
  return result;
}

double _ratio(Object? value, String path) {
  final result = _number(value, path);
  if (result <= 0 || result > 1) {
    throw _invalid(path, 'Expected a ratio in the interval (0, 1].');
  }
  return result;
}

int _positiveInt(Object? value, String path) {
  final result = _integer(value, path);
  if (result <= 0) throw _invalid(path, 'Expected a positive integer.');
  return result;
}

int _nonNegativeInt(Object? value, String path) {
  final result = _integer(value, path);
  if (result < 0) throw _invalid(path, 'Expected a non-negative integer.');
  return result;
}

int _integer(Object? value, String path) {
  if (value is! int) throw _type(path, 'integer');
  return value;
}

CatalogId _id(Object? value, String path) {
  try {
    return CatalogId(_string(value, path));
  } on ArgumentError catch (error) {
    throw _invalid(path, error.message.toString());
  }
}

Set<CatalogId> _idSet(Object? value, String path) {
  final values = _list(value, path);
  final result = <CatalogId>{};
  for (var index = 0; index < values.length; index++) {
    final id = _id(values[index], '$path[$index]');
    if (!result.add(id)) throw _invalid('$path[$index]', 'Duplicate ID.');
  }
  return result;
}

T _enum<T extends Enum>(Object? value, String path, List<T> values) {
  final name = _string(value, path);
  for (final candidate in values) {
    if (candidate.name == name) return candidate;
  }
  throw _unknownEnum(path, name);
}

Set<T> _enumSet<T extends Enum>(Object? value, String path, List<T> values) {
  final raw = _list(value, path);
  final result = <T>{};
  for (var index = 0; index < raw.length; index++) {
    final item = _enum(raw[index], '$path[$index]', values);
    if (!result.add(item)) {
      throw _invalid('$path[$index]', 'Duplicate enum value.');
    }
  }
  return result;
}

List<double> _numberList(Object? value, String path, {required bool positive}) {
  final raw = _list(value, path);
  return [
    for (var index = 0; index < raw.length; index++)
      positive
          ? _positiveNumber(raw[index], '$path[$index]')
          : _number(raw[index], '$path[$index]'),
  ];
}

void _uniqueIds(Iterable<CatalogId> ids, String path) {
  final values = ids.toList(growable: false);
  if (values.toSet().length != values.length) {
    throw _invalid(path, 'Duplicate ID.');
  }
}

Object? _canonicalize(Object? value) => switch (value) {
  Map map => {
    for (final key in map.keys.map((key) => key.toString()).toList()..sort())
      key: _canonicalize(map[key]),
  },
  List list => [for (final item in list) _canonicalize(item)],
  _ => value,
};

GenericEngineCodecException _type(String path, String expected) =>
    GenericEngineCodecException(
      code: 'invalid_type',
      path: path,
      message: 'Expected $expected.',
    );

GenericEngineCodecException _invalid(String path, String message) =>
    GenericEngineCodecException(
      code: 'invalid_value',
      path: path,
      message: message,
    );

GenericEngineCodecException _unknownEnum(String path, String value) =>
    GenericEngineCodecException(
      code: 'unknown_enum',
      path: path,
      message: 'Unknown enum value: $value.',
    );
