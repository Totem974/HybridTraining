import 'dart:convert';

import 'package:training_engine/training_engine.dart';

import 'bridge_service.dart';
import 'cycle_configuration_codec.dart';
import 'cycle_request_normalizer.dart';

final class LocalTrainingEngineBindings implements TrainingEngineJsonBindings {
  final CatalogSourceDocumentCodec _codec = const CatalogSourceDocumentCodec();
  final CatalogPlanDataResolver _dataResolver = const CatalogPlanDataResolver();
  final CatalogPlanResolver _planResolver = const CatalogPlanResolver();
  final CycleCompiler _compiler = const CycleCompilerImpl();
  final CycleConfigurationCodec _configurationCodec =
      const CycleConfigurationCodec();

  int? _catalogVersion;
  String? _catalogHash;
  List<SourceTemplate> _templates = const [];
  List<SourceSchedule> _schedules = const [];
  List<SourceComponent> _components = const [];
  List<Map<String, Object?>> _rawTemplateRecords = const [];
  List<Map<String, Object?>> _rawOptionSchemas = const [];
  List<Map<String, Object?>> _rawScheduleRecords = const [];
  List<Map<String, Object?>> _rawForeverDefinitions = const [];
  List<Map<String, Object?>> _rawTemplateAliases = const [];
  List<SourceCycleOptionRecipe> _optionRecipes = const [];
  Map<String, Map<String, String>> _movementLabels = const {};
  Map<String, String> _movementPatterns = const {};

  @override
  String initialize(String catalogJson) {
    final root = _map(jsonDecode(catalogJson), 'catalog');
    _keys(root, const {
      'schemaVersion',
      'catalogVersion',
      'status',
      'coverage',
      'documents',
      'contentHash',
    });
    final documents = _list(root, 'documents')
        .map((item) {
          final document = _map(item, 'document');
          _keys(document, const {'path', 'content'});
          return _map(document['content'], 'document content');
        })
        .toList(growable: false);
    _catalogVersion = _integer(root, 'catalogVersion');
    _catalogHash = root['contentHash'] is String
        ? root['contentHash']! as String
        : _fnv1a64(_canonicalJson(root));
    _templates = [
      for (final document in documents.where(
        (item) => item['kind'] == 'templates',
      ))
        ..._codec.decodeTemplates(
          jsonEncode(_engineTemplateDocument(document)),
        ),
    ];
    _schedules = [
      for (final document in documents.where(
        (item) => item['kind'] == 'schedules',
      ))
        ..._codec.decodeSchedules(jsonEncode(document)),
    ];
    _components = [
      for (final document in documents.where(
        (item) => item['kind'] == 'components',
      ))
        ..._codec.decodeComponents(jsonEncode(document)),
    ];
    _rawTemplateRecords = [
      for (final document in documents.where(
        (item) => item['kind'] == 'templates',
      ))
        for (final item in _list(document, 'templates'))
          {
            ..._map(item, 'template'),
            'generation': _map(document['generation'], 'template generation'),
          },
    ];
    _rawOptionSchemas = [
      for (final document in documents.where(
        (item) => item['kind'] == 'optionSchemas',
      ))
        for (final item in _list(document, 'optionSchemas'))
          _map(item, 'option schema'),
    ];
    _rawScheduleRecords = [
      for (final document in documents.where(
        (item) => item['kind'] == 'schedules',
      ))
        for (final item in _list(document, 'schedules')) _map(item, 'schedule'),
    ];
    _rawForeverDefinitions = [
      for (final document in documents.where(
        (item) => item['kind'] == 'foreverDefinitions',
      ))
        for (final item in _list(document, 'foreverDefinitions'))
          _map(item, 'forever definition'),
    ];
    _rawTemplateAliases = [
      for (final document in documents.where(
        (item) => item['kind'] == 'templateAliases',
      ))
        for (final item in _list(document, 'templateAliases'))
          _map(item, 'template alias'),
    ];
    _optionRecipes = [
      for (final document in documents.where(
        (item) => item['kind'] == 'cycleOptionRecipes',
      ))
        ..._codec.decodeCycleOptionRecipes(jsonEncode(document)),
    ];
    _movementLabels = {
      for (final document in documents.where(
        (item) => item['kind'] == 'movements',
      ))
        for (final item in _list(document, 'movements'))
          _string(_map(item, 'movement'), 'id'): {
            for (final entry in _map(
              _map(item, 'movement')['labels'],
              'labels',
            ).entries)
              entry.key: entry.value as String,
          },
    };
    _movementPatterns = {
      for (final document in documents.where(
        (item) => item['kind'] == 'movements',
      ))
        for (final item in _list(document, 'movements'))
          _string(_map(item, 'movement'), 'id'): _string(
            _map(item, 'movement'),
            'pattern',
          ),
    };
    if (_templates.isEmpty || _schedules.isEmpty || _components.isEmpty) {
      throw const FormatException('CATALOG_RUNTIME_DOCUMENTS_REQUIRED');
    }
    return jsonEncode(_metadata()..['initialized'] = true);
  }

  @override
  String engineInfo() => jsonEncode({
    ..._metadata(),
    'capabilities': const [
      'catalogIndex',
      'cycleEditorSchema',
      'configurationToCycleRequest',
      'validateCycle',
      'generateCycle',
      'generateMacrocycle',
    ],
  });

  @override
  String configurationToCycleRequest(String configurationJson) => jsonEncode(
    _configurationCodec.toCycleRequest(
      _map(jsonDecode(configurationJson), 'cycle configuration'),
      catalogVersion: _catalogVersion!,
      catalogHash: _catalogHash!,
    ),
  );

  @override
  String catalogIndex(String requestJson) {
    final request = _map(jsonDecode(requestJson), 'request');
    _keys(request, const {'apiVersion', 'schemaVersion'});
    _requireV1(request);
    final publicTemplates = _rawTemplateRecords
        .where((template) => template['surface'] == 'cyclePublic')
        .toList(growable: false);
    final defaults = publicTemplates
        .where((template) => template['isDefault'] == true)
        .toList(growable: false);
    if (defaults.length > 1) {
      throw const FormatException('MULTIPLE_DEFAULT_TEMPLATES');
    }
    final orderedTemplates = [
      ...defaults,
      ...publicTemplates.where((template) => template['isDefault'] != true),
    ];
    return jsonEncode({
      ..._metadata(),
      'templates': [
        for (final template in orderedTemplates)
          {
            'id': template['id'],
            'revision': template['revision'],
            'labels': template['labels'],
            'generation': template['generation'],
            'variantIds': [
              for (final variant in _list(template, 'variants'))
                _map(variant, 'variant')['id'],
            ],
          },
      ],
    });
  }

  @override
  String cycleEditorSchema(String requestJson) {
    final request = _map(jsonDecode(requestJson), 'request');
    _rejectUnknown(request, const {
      'apiVersion',
      'schemaVersion',
      'templateId',
      'variantId',
      'scheduleId',
    });
    var templateId = _string(request, 'templateId');
    var variantId = _string(request, 'variantId');
    final alias = _templateAlias(templateId, variantId);
    final aliasOptionOverrides = alias == null
        ? const <String, Object?>{}
        : _map(alias['optionOverrides'], 'option overrides');
    if (alias != null) {
      templateId = _string(alias, 'templateId');
      variantId = _string(alias, 'variantId');
    }
    final rawTemplate = _rawTemplateRecords.singleWhere(
      (item) => item['id'] == templateId,
    );
    final selectedGeneration = _map(
      rawTemplate['generation'],
      'template generation',
    );
    final publicTemplates = _rawTemplateRecords
        .where((template) => template['surface'] == 'cyclePublic')
        .toList(growable: false);
    final orderedTemplates = [
      ...publicTemplates.where((template) => template['isDefault'] == true),
      ...publicTemplates.where((template) => template['isDefault'] != true),
    ];
    _requireV1(request);
    final rawVariant = _list(rawTemplate, 'variants')
        .map((item) => _map(item, 'variant'))
        .singleWhere((item) => item['id'] == variantId);
    final validExample = _optionalMap(rawVariant['validExample']);
    final optionOverrides = <String, Object?>{
      ...aliasOptionOverrides,
      if (validExample['includeWarmUp'] is bool)
        'warmUp.enabled': validExample['includeWarmUp'],
      if (validExample['includeDeload'] is bool)
        'deload.enabled': validExample['includeDeload'],
    };
    final optionReference = _map(
      rawVariant['optionSchemaId'],
      'option schema reference',
    );
    final optionSchema = _rawOptionSchemas.singleWhere(
      (item) =>
          item['id'] == optionReference['id'] &&
          item['revision'] == optionReference['revision'],
    );
    final optionParameters = [
      for (final item in _list(optionSchema, 'parameters'))
        _map(item, 'parameter'),
    ];
    final optionRequestPaths = {
      for (final parameter in optionParameters)
        _string(parameter, 'id'):
            parameter['requestPath'] as String? ?? _string(parameter, 'id'),
    };
    final optionScopes = {
      for (final parameter in optionParameters)
        _string(parameter, 'id'): parameter['scope'] as String? ?? 'global',
    };
    final defaultScheduleReference =
        rawVariant['validExample'] is Map<String, Object?>
        ? _map(rawVariant['validExample'], 'example')['scheduleId'] as String?
        : null;
    final sourceVariant = _templates
        .singleWhere((template) => template.id == templateId)
        .variants
        .singleWhere((variant) => variant.id == variantId);
    final requestedScheduleId = request['scheduleId'] as String?;
    final selectedScheduleId =
        requestedScheduleId ??
        defaultScheduleReference ??
        sourceVariant.scheduleIds.first.id;
    if (!sourceVariant.scheduleIds.any(
      (item) => item.id == selectedScheduleId,
    )) {
      throw FormatException('SCHEDULE_NOT_ALLOWED:$selectedScheduleId');
    }
    final schemaSchedule = _schedules.firstWhere(
      (item) => item.reference.id == selectedScheduleId,
    );
    _resolve(templateId, variantId, const [], scheduleId: selectedScheduleId);
    final movements = schemaSchedule.sessions
        .expand((session) => session.movementIds)
        .toSet()
        .toList(growable: false);
    const defaultBarWeight = 20.0;
    const plateDenominations = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
    final maximumPlateLoad =
        defaultBarWeight +
        2 * plateDenominations.fold<double>(0, (sum, plate) => sum + plate);
    final fields = <Map<String, Object?>>[
      _field(
        id: 'generation',
        path: 'generationId',
        region: 'template',
        kind: 'choice',
        label: const {'en': 'Generation', 'fr': 'Génération'},
        value: selectedGeneration['id'],
        choices: [
          for (final generation in {
            for (final template in orderedTemplates)
              _string(
                _map(template['generation'], 'template generation'),
                'id',
              ): _map(
                template['generation'],
                'template generation',
              ),
          }.values)
            {'value': generation['id'], 'label': generation['labels']},
        ],
      ),
      _field(
        id: 'template',
        path: 'templateId',
        region: 'template',
        kind: 'choice',
        label: const {'en': 'Template', 'fr': 'Modèle'},
        value: templateId,
        choices: [
          for (final template in orderedTemplates.where(
            (item) =>
                _map(item['generation'], 'template generation')['id'] ==
                selectedGeneration['id'],
          ))
            {'value': template['id'], 'label': template['labels']},
        ],
      ),
      _field(
        id: 'schedule',
        path: 'scheduleId',
        region: 'scheduling',
        kind: sourceVariant.scheduleIds.length == 1 ? 'choice' : 'segmented',
        label: const {'en': 'Frequency', 'fr': 'Fréquence'},
        value: selectedScheduleId,
        readOnly: sourceVariant.scheduleIds.length == 1,
        choices: [
          for (final reference in sourceVariant.scheduleIds)
            {
              'value': reference.id,
              'label': _map(
                _rawScheduleRecords.singleWhere(
                  (item) => item['id'] == reference.id,
                )['labels'],
                'schedule labels',
              ),
            },
        ],
      ),
      _field(
        id: 'variant',
        path: 'variantId',
        region: 'template',
        kind: 'choice',
        label: const {'en': 'Variant', 'fr': 'Variante'},
        value: variantId,
        choices: [
          for (final item in _list(rawTemplate, 'variants'))
            {
              'value': _map(item, 'variant')['id'],
              'label': _map(item, 'variant')['labels'],
            },
        ],
      ),
      _field(
        id: 'max-mode',
        path: 'maxMode',
        region: 'weight',
        kind: 'segmented',
        label: const {'en': 'Maximum type', 'fr': 'Type de maximum'},
        value: 'oneRepMax',
        choices: const [
          {
            'value': 'oneRepMax',
            'label': {'en': '1 RM', 'fr': '1 RM'},
          },
          {
            'value': 'onePlusSet',
            'label': {'en': '1+ set', 'fr': 'Série 1+'},
          },
          {
            'value': 'directTrainingMax',
            'label': {'en': 'Training Max', 'fr': 'Training Max'},
          },
          {
            'value': 'repMax',
            'label': {'en': 'Rep Max', 'fr': 'Rep Max'},
          },
        ],
      ),
      _field(
        id: 'unit',
        path: 'unit',
        region: 'weight',
        kind: 'segmented',
        label: const {'en': 'Unit', 'fr': 'Unité'},
        value: 'kg',
        choices: const [
          {'value': 'kg', 'label': 'kg'},
          {'value': 'lb', 'label': 'lb'},
        ],
      ),
      _field(
        id: 'training-max-ratio',
        path: 'globalTrainingMaxRatioBasisPoints',
        region: 'weight',
        kind: 'percentage',
        label: const {'en': 'Training Max ratio', 'fr': 'Ratio Training Max'},
        value: rawVariant['validExample'] is Map
            ? (_map(
                    rawVariant['validExample'],
                    'example',
                  )['trainingMaxRatioBasisPoints'] ??
                  9000)
            : 9000,
        minimum: 1000,
        maximum: 10000,
        step: 50,
      ),
      for (final movement in movements) ...[
        _field(
          id: 'max-load-$movement',
          path: 'maxInputs.$movement.weight',
          region: 'weight',
          kind: 'weight',
          label: _movementLabels[movement] ?? {'en': movement, 'fr': movement},
          value: 100,
          minimum: 0,
          step: 0.5,
        ),
        _field(
          id: 'max-repetitions-$movement',
          path: 'maxInputs.$movement.repetitions',
          region: 'weight',
          kind: 'integer',
          label: const {'en': 'Repetitions', 'fr': 'Répétitions'},
          value: 5,
          minimum: 1,
          maximum: 20,
          visibleWhen: const [
            {'path': 'maxMode', 'operator': 'equals', 'value': 'repMax'},
          ],
        ),
      ],
      for (final parameter in optionParameters)
        if (parameter['presentationGroup'] != 'hidden')
          ..._optionFields(
            parameter,
            optionRequestPaths,
            optionScopes,
            optionOverrides,
            movements,
          ),
      if (_optionalMap(
            rawVariant['compatibilities'],
          )['includeDeloadRequired'] ==
          true)
        _field(
          id: 'include-deload-required',
          path: 'includeDeload',
          region: 'output',
          kind: 'boolean',
          label: const {'en': 'Include deload', 'fr': 'Inclure le deload'},
          value: true,
          readOnly: true,
          visibleWhen: const [
            {
              'path': '__catalogHiddenOption',
              'operator': 'equals',
              'value': true,
            },
          ],
        ),
      _field(
        id: 'bar-weight',
        path: 'barWeight',
        region: 'plating',
        kind: 'weight',
        label: const {'en': 'Bar weight', 'fr': 'Poids de la barre'},
        value: defaultBarWeight,
        minimum: 0,
        step: 0.5,
      ),
      for (final plate in plateDenominations)
        _field(
          id: 'plate-$plate',
          path: 'plates.$plate',
          region: 'plating',
          kind: 'plate-counter',
          label: '$plate kg',
          value: 1,
          minimum: 0,
          maximum: 10,
        ),
      _field(
        id: 'maximum-plate-load',
        path: 'maximumPlateLoad',
        region: 'plating',
        kind: 'weight',
        label: const {'en': 'Maximum total', 'fr': 'Total maximal'},
        value: maximumPlateLoad,
        readOnly: true,
      ),
      _field(
        id: 'start-date',
        path: 'startDate',
        region: 'scheduling',
        kind: 'date',
        label: const {'en': 'Start date', 'fr': 'Date de départ'},
        value: '2026-01-05',
      ),
      _field(
        id: 'session-order',
        path: 'sessionOrder',
        region: 'scheduling',
        kind: 'token-order',
        label: const {'en': 'Session order', 'fr': 'Ordre des séances'},
        value: [for (final session in schemaSchedule.sessions) session.id],
        choices: [
          for (final session in schemaSchedule.sessions)
            {
              'value': session.id,
              'label': session.movementIds.map(_movementTokenLabel).join('+'),
            },
        ],
      ),
      _field(
        id: 'program-title',
        path: 'programTitle',
        region: 'output',
        kind: 'text',
        label: const {'en': 'Program title', 'fr': 'Titre du programme'},
        value: '5/3/1',
      ),
      _field(
        id: 'show-plating',
        path: 'showPlating',
        region: 'output',
        kind: 'boolean',
        label: const {'en': 'Show plating', 'fr': 'Afficher les plaques'},
        value: true,
      ),
      _field(
        id: 'generate',
        path: 'generate',
        region: 'output',
        kind: 'action',
        label: const {'en': 'Generate', 'fr': 'Générer'},
        value: false,
        action: 'generate',
      ),
    ];
    return jsonEncode({
      ..._metadata(),
      'id': '$templateId/$variantId',
      'templateId': templateId,
      'variantId': variantId,
      'movementIds': movements,
      'sessionIds': [for (final session in schemaSchedule.sessions) session.id],
      'fields': fields,
    });
  }

  @override
  String validateCycle(String requestJson) {
    try {
      _generate(requestJson);
      return jsonEncode({
        ..._metadata(),
        'valid': true,
        'errors': const [],
        'warnings': const [],
      });
    } catch (error) {
      return jsonEncode({
        ..._metadata(),
        'valid': false,
        'errors': [_issue(error)],
        'warnings': const [],
      });
    }
  }

  @override
  String generateCycle(String requestJson) {
    final cycle = _generate(requestJson).toJson();
    final logicalHash = _fnv1a64(_canonicalJson(cycle));
    return jsonEncode({
      ..._metadata(),
      'cycle': cycle,
      'warnings': const [],
      'snapshot': {
        ..._metadata(),
        'kind': 'cycle',
        'logicalHash': logicalHash,
        'payload': cycle,
      },
    });
  }

  @override
  String generateMacrocycle(String requestJson) {
    final json = _map(jsonDecode(requestJson), 'forever request');
    _rejectUnknown(json, const {
      'apiVersion',
      'schemaVersion',
      'macrocycleId',
      'definitionId',
      'definitionRevision',
      'startDate',
      'initialTrainingMaxes',
      'slotRequests',
      'unit',
      'roundingIncrement',
      'barProfile',
    });
    _requireV1(json);
    final definition = _foreverDefinition(
      _rawForeverDefinitions.singleWhere(
        (candidate) =>
            candidate['id'] == _string(json, 'definitionId') &&
            candidate['revision'] == _integer(json, 'definitionRevision'),
      ),
    );
    final unit = WeightUnit.values.byName(_string(json, 'unit'));
    final bar = _map(json['barProfile'], 'barProfile');
    final barWeight = _weight(_map(bar['weight'], 'bar weight'));
    final plates = [
      for (final value in _list(bar, 'platesPerSide'))
        _weight(_map(value, 'plate')),
    ];
    final request = ForeverRequest(
      macrocycleId: _string(json, 'macrocycleId'),
      definitionId: definition.id,
      definitionRevision: definition.revision,
      startDate: DateTime.parse(_string(json, 'startDate')),
      initialTrainingMaxes: {
        for (final entry in _map(
          json['initialTrainingMaxes'],
          'initialTrainingMaxes',
        ).entries)
          MovementId(entry.key): _weight(_map(entry.value, 'training max')),
      },
      slotRequests: {
        for (final entry in _map(json['slotRequests'], 'slotRequests').entries)
          entry.key: _foreverSlotRequest(
            entry.key,
            _map(entry.value, 'slot request'),
          ),
      },
      unit: unit,
      roundingIncrement: _weight(
        _map(json['roundingIncrement'], 'roundingIncrement'),
      ),
      barProfile: BarProfile(weight: barWeight, platesPerSide: plates),
    );
    final composer = ForeverComposerImpl.sync(
      cycleDefinitionResolver: _BridgeForeverCycleResolver(
        _resolveForeverCycle,
      ),
      cycleCompiler: _compiler,
    );
    final generated = composer.composeSync(definition, request);
    final macrocycle = _macrocycleJson(generated);
    final logicalHash = _fnv1a64(_canonicalJson(macrocycle));
    return jsonEncode({
      ..._metadata(),
      'macrocycle': macrocycle,
      'warnings': const [],
      'snapshot': {
        ..._metadata(),
        'kind': 'macrocycle',
        'logicalHash': logicalHash,
        'payload': macrocycle,
      },
    });
  }

  ResolvedCycleDefinition _resolveForeverCycle(
    ForeverCycleReference reference,
  ) => _resolve(reference.templateId, reference.variantId, const []);

  ResolvedForeverDefinition _foreverDefinition(Map<String, Object?> json) {
    _keys(json, const {
      'id',
      'revision',
      'labels',
      'sourceRuleIds',
      'phases',
      'compatibilities',
      'editorSchema',
    });
    final id = ForeverDefinitionId(_string(json, 'id'));
    final revision = ForeverDefinitionRevision(_integer(json, 'revision'));
    final compatibleMovements = _strings(
      _map(json['compatibilities'], 'compatibilities'),
      'movements',
    );
    final phases = <ForeverPhase>[
      for (final phaseValue in _list(json, 'phases'))
        _foreverPhase(_map(phaseValue, 'phase'), compatibleMovements),
    ];
    final labels = _map(json['labels'], 'labels');
    return ResolvedForeverDefinition(
      id: id,
      revision: revision,
      labelEn: _string(labels, 'en'),
      labelFr: _string(labels, 'fr'),
      sourceRuleIds: _strings(json, 'sourceRuleIds'),
      phases: phases,
      editorSchema: ForeverEditorSchema(
        definitionId: id,
        revision: revision,
        configurableSlotIds: [
          for (final phase in phases)
            for (final slot in phase.slots) slot.id,
        ],
      ),
    );
  }

  ForeverPhase _foreverPhase(
    Map<String, Object?> json,
    List<String> movements,
  ) {
    _keys(json, const {
      'id',
      'role',
      'repeatCount',
      'cycle',
      'trainingMaxRule',
    });
    final slot = ForeverCycleSlot(
      id: _string(json, 'id'),
      role: ForeverPhaseRole.values.byName(_string(json, 'role')),
      repeatCount: _integer(json, 'repeatCount'),
      defaultCycle: _cycleReference(_map(json['cycle'], 'cycle')),
      allowedCycles: [_cycleReference(_map(json['cycle'], 'cycle'))],
      transition: ForeverTransition(
        trainingMaxRule: _catalogTrainingMaxRule(
          _map(json['trainingMaxRule'], 'trainingMaxRule'),
          movements,
        ),
        requiresConfirmation:
            _map(json['trainingMaxRule'], 'trainingMaxRule')['type'] ==
            'testThenConfirm',
      ),
    );
    return ForeverPhase(id: _string(json, 'id'), slots: [slot]);
  }

  TrainingMaxRule _catalogTrainingMaxRule(
    Map<String, Object?> json,
    List<String> movements,
  ) {
    final type = _string(json, 'type');
    if (type == 'keep') return const KeepTrainingMax();
    if (type == 'testThenConfirm') {
      return const TestThenConfirmTrainingMax();
    }
    if (type != 'add') {
      throw FormatException('UNKNOWN_CATALOG_TRAINING_MAX_RULE:$type');
    }
    final unit = WeightUnit.values.byName(_string(json, 'unit'));
    return AddTrainingMax(
      {
        for (final movement in movements)
          MovementId(movement): Weight(
            (((_isUpperBodyMovement(movement)
                            ? json['upperBody']
                            : json['lowerBody'])
                        as num) *
                    100)
                .round(),
            unit,
          ),
      },
      resultKind: TrainingMaxValueKind.values.byName(
        _string(json, 'valueState'),
      ),
    );
  }

  bool _isUpperBodyMovement(String movement) {
    final pattern = _movementPatterns[movement];
    return pattern == 'horizontalPush' ||
        pattern == 'verticalPush' ||
        movement == 'bench_press' ||
        movement == 'overhead_press';
  }

  ForeverCycleReference _cycleReference(Map<String, Object?> json) {
    _keys(json, const {
      'templateId',
      'variantId',
      'templateRevision',
      'variantRevision',
    });
    return ForeverCycleReference(
      templateId: _string(json, 'templateId'),
      variantId: _string(json, 'variantId'),
      templateRevision: _integer(json, 'templateRevision'),
      variantRevision: _integer(json, 'variantRevision'),
    );
  }

  ForeverSlotRequest _foreverSlotRequest(
    String key,
    Map<String, Object?> json,
  ) {
    _keys(json, const {
      'slotId',
      'cycle',
      'trainingDays',
      'sessionOrder',
      'enabled',
      'percentageParameters',
      'percentageParametersByMovement',
      'globalTrainingMaxRatioBasisPoints',
      'trainingMaxRatioByMovementBasisPoints',
      'includeDeload',
    });
    final slotId = _string(json, 'slotId');
    if (slotId != key) throw FormatException('SLOT_ID_KEY_MISMATCH:$key');
    return ForeverSlotRequest(
      slotId: slotId,
      cycle: _cycleReference(_map(json['cycle'], 'cycle')),
      trainingDays: _integers(json, 'trainingDays'),
      sessionOrder: [
        for (final value in _strings(json, 'sessionOrder')) MovementId(value),
      ],
      enabled: json['enabled'] as bool,
      percentageParameters: {
        for (final entry in _map(
          json['percentageParameters'],
          'percentageParameters',
        ).entries)
          entry.key: Percentage(entry.value as int),
      },
      percentageParametersByMovement: {
        for (final movement in _map(
          json['percentageParametersByMovement'],
          'percentageParametersByMovement',
        ).entries)
          MovementId(movement.key): {
            for (final entry in _map(
              movement.value,
              'movement parameters',
            ).entries)
              entry.key: Percentage(entry.value as int),
          },
      },
      globalTrainingMaxRatio: Percentage(
        _integer(json, 'globalTrainingMaxRatioBasisPoints'),
      ),
      trainingMaxRatioByMovement: {
        for (final entry in _map(
          json['trainingMaxRatioByMovementBasisPoints'],
          'trainingMaxRatioByMovementBasisPoints',
        ).entries)
          MovementId(entry.key): Percentage(entry.value as int),
      },
      includeDeload: json['includeDeload'] as bool,
    );
  }

  GeneratedCycle _generate(String requestJson) {
    final source = _map(jsonDecode(requestJson), 'cycle request');
    final json = normalizeCycleRequest(
      source,
      catalogOptionKeys: _catalogOptionKeys(
        _string(source, 'templateId'),
        _string(source, 'variantId'),
      ),
    );
    _resolveTemplateAliasAndFullBody(json);
    _rejectUnknown(json, const {
      'apiVersion',
      'schemaVersion',
      'cycleId',
      'templateId',
      'variantId',
      'scheduleId',
      'startDate',
      'trainingDays',
      'sessionOrder',
      'maxInputs',
      'globalTrainingMaxRatioBasisPoints',
      'trainingMaxRatioByMovement',
      'trainingMaxRatioByMovementBasisPoints',
      'percentageParameters',
      'percentageParametersByMovement',
      'options',
      'unit',
      'roundingIncrement',
      'barProfile',
      'includeDeload',
      'programTitle',
      'showPlating',
    });
    _requireV1(json);
    final templateId = _string(json, 'templateId');
    final variantId = _string(json, 'variantId');
    final sessionOrder = _strings(json, 'sessionOrder');
    final unit = WeightUnit.values.byName(_string(json, 'unit'));
    final scheduleId = json['scheduleId'] as String?;
    final selectedSchedule = _selectSchedule(
      templateId,
      variantId,
      sessionOrder,
      scheduleId: scheduleId,
    );
    final definition = _resolve(
      templateId,
      variantId,
      sessionOrder,
      scheduleId: selectedSchedule.reference.id,
      optionValues: _catalogOptionValues(
        templateId,
        variantId,
        _map(json['options'], 'options'),
      ),
    );
    final ratioByMovement = _optionalMap(
      json['trainingMaxRatioByMovement'] ??
          json['trainingMaxRatioByMovementBasisPoints'],
    );
    final bar = _map(json['barProfile'], 'barProfile');
    final barWeight = bar['weight'] == null
        ? Weight(_integer(bar, 'barWeightCentiUnits'), unit)
        : _weight(_map(bar['weight'], 'bar weight'));
    final plates = bar['platesPerSide'] == null
        ? [
            for (final value in _integers(bar, 'platesPerSideCentiUnits'))
              Weight(value, unit),
          ]
        : [
            for (final value in _list(bar, 'platesPerSide'))
              _weight(_map(value, 'plate')),
          ];
    if (plates.isEmpty) throw const FormatException('PLATES_REQUIRED');
    final rounding = json['roundingIncrement'] == null
        ? Weight(
            plates
                    .map((plate) => plate.centiUnits)
                    .reduce((a, b) => a < b ? a : b) *
                2,
            unit,
          )
        : _weight(_map(json['roundingIncrement'], 'roundingIncrement'));
    final maxInputs = <MovementId, TrainingMaxInput>{};
    for (final entry in _map(json['maxInputs'], 'maxInputs').entries) {
      final value = _map(entry.value, 'max input');
      final kind = (value['type'] ?? value['kind']) as String?;
      _rejectUnknown(
        value,
        kind == 'repMax'
            ? const {
                'type',
                'kind',
                'weight',
                'weightCentiUnits',
                'repetitions',
                'formula',
              }
            : const {'type', 'kind', 'weight', 'weightCentiUnits'},
      );
      final weight = value['weight'] == null
          ? Weight(_integer(value, 'weightCentiUnits'), unit)
          : _weight(_map(value['weight'], 'maximum weight'));
      maxInputs[MovementId(entry.key)] = switch (kind) {
        'oneRepMax' => OneRepMaxInput(weight),
        'onePlusSet' => OnePlusSetInput(weight),
        'repMax' => RepMaxInput(
          weight,
          _integer(value, 'repetitions'),
          formula: value['formula'] as String? ?? 'epley',
        ),
        'directTrainingMax' => DirectTrainingMaxInput(weight),
        _ => throw FormatException('UNKNOWN_MAX_INPUT_KIND:$kind'),
      };
    }
    return _compiler.compile(
      definition,
      CycleRequest(
        cycleId: _string(json, 'cycleId'),
        startDate: DateTime.parse(_string(json, 'startDate')),
        trainingDays: json['trainingDays'] == null
            ? _defaultTrainingDays(selectedSchedule)
            : _integers(json, 'trainingDays'),
        sessionOrder: [for (final id in sessionOrder) MovementId(id)],
        maxInputs: maxInputs,
        globalTrainingMaxRatio: Percentage(
          _integer(json, 'globalTrainingMaxRatioBasisPoints'),
        ),
        trainingMaxRatioByMovement: {
          for (final entry in ratioByMovement.entries)
            MovementId(entry.key): Percentage(entry.value as int),
        },
        percentageParameters: {
          for (final entry in _optionalMap(
            json['percentageParameters'],
          ).entries)
            entry.key: Percentage(entry.value as int),
        },
        percentageParametersByMovement: {
          for (final movement in _optionalMap(
            json['percentageParametersByMovement'],
          ).entries)
            MovementId(movement.key): {
              for (final entry in _optionalMap(movement.value).entries)
                entry.key: Percentage(entry.value as int),
            },
        },
        unit: unit,
        roundingIncrement: rounding,
        barProfile: BarProfile(weight: barWeight, platesPerSide: plates),
        includeDeload: json['includeDeload'] as bool? ?? true,
        cycleOptions: _cycleOptions(_map(json['options'], 'options'), unit),
      ),
    );
  }

  CycleExecutionOptions _cycleOptions(
    Map<String, Object?> options,
    WeightUnit unit,
  ) {
    final warmUp = _optionalMap(options['warmUp']);
    final joker = _optionalMap(options['joker']);
    final deload = _optionalMap(options['deload']);
    final warmUpEnabled = warmUp['enabled'] as bool? ?? false;
    final warmUpType = warmUpEnabled
        ? WarmUpType.values.byName(_string(warmUp, 'type'))
        : null;
    final bases = warmUpType == WarmUpType.beyond
        ? _map(warmUp['bases'], 'warm-up bases')
        : const <String, Object?>{};
    final deloadEnabled = deload['enabled'] as bool? ?? false;
    final deloadType = deloadEnabled
        ? switch (_string(deload, 'type')) {
            'deload1' => DeloadType.type1,
            'deload2' => DeloadType.type2,
            'deload3' => DeloadType.type3,
            'deload4' => DeloadType.type4,
            'deload5' => DeloadType.type5,
            'highIntensity' => DeloadType.highIntensity,
            final value => throw FormatException('UNKNOWN_DELOAD_TYPE:$value'),
          }
        : null;
    Weight? baseWeight(String key) {
      if (warmUpType != WarmUpType.beyond) return null;
      final value = _weight(_map(bases[key], 'warm-up $key base'));
      if (value.unit != unit) {
        throw FormatException('WARM_UP_BASE_UNIT_MISMATCH:$key');
      }
      return value;
    }

    return CycleExecutionOptions(
      warmUp: WarmUpExecutionOptions(
        enabled: warmUpEnabled,
        type: warmUpType,
        lowerBodyBaseWeight: baseWeight('lowerBody'),
        upperBodyBaseWeight: baseWeight('upperBody'),
      ),
      joker: JokerExecutionOptions(
        enabled: joker['enabled'] as bool? ?? false,
        ceilingBasisPoints: joker['enabled'] == true
            ? _integer(joker, 'ceilingBasisPoints')
            : null,
      ),
      deload: DeloadExecutionOptions(
        enabled: deloadEnabled,
        type: deloadType,
        skipWarmUp: deload['skipWarmUp'] as bool? ?? false,
      ),
    );
  }

  ResolvedCycleDefinition _resolve(
    String templateId,
    String variantId,
    List<String> requestedOrder, {
    String? scheduleId,
    Map<String, Object?> optionValues = const {},
  }) {
    final template = _templates.singleWhere((item) => item.id == templateId);
    final variant = template.variants.singleWhere(
      (item) => item.id == variantId,
    );
    final schedule = _selectSchedule(
      templateId,
      variantId,
      requestedOrder,
      scheduleId: scheduleId,
    );
    return _planResolver.resolve(
      _dataResolver.resolve(
        catalogVersion: _catalogVersion!,
        template: template,
        variant: variant,
        scheduleReference: schedule.reference,
        schedules: _schedules,
        components: _components,
        optionRecipes: _optionRecipes,
        optionValues: optionValues,
        optionDefaults: _optionDefaults(templateId, variantId),
        sourceReference: 'catalog.bundle.json:$templateId/$variantId',
      ),
    );
  }

  void _resolveTemplateAliasAndFullBody(Map<String, Object?> request) {
    final alias = _templateAlias(
      request['templateId'] as String,
      request['variantId'] as String,
    );
    final options = _map(request['options'], 'options');
    if (alias != null) {
      request['templateId'] = _string(alias, 'templateId');
      request['variantId'] = _string(alias, 'variantId');
      final overrides = _map(alias['optionOverrides'], 'option overrides');
      options['fullBody'] = {'profile': request['variantId'], ...overrides};
    }
    final fullBody = options['fullBody'];
    if (fullBody == null) return;
    final selection = _map(fullBody, 'options.fullBody');
    final profile = _string(selection, 'profile');
    final template = _rawTemplateRecords
        .where(
          (item) =>
              item['id'] == request['templateId'] &&
              _list(
                item,
                'variants',
              ).any((candidate) => _map(candidate, 'variant')['id'] == profile),
        )
        .firstOrNull;
    if (template == null) {
      throw FormatException('FULL_BODY_PROFILE_NOT_AVAILABLE:$profile');
    }
    request['variantId'] = profile;
  }

  Map<String, Object?>? _templateAlias(String templateId, String variantId) =>
      _rawTemplateAliases
          .where(
            (item) =>
                item['legacyTemplateId'] == templateId &&
                item['legacyVariantId'] == variantId,
          )
          .firstOrNull;

  Set<String> _catalogOptionKeys(String templateId, String variantId) {
    final alias = _templateAlias(templateId, variantId);
    final resolvedTemplateId = alias == null
        ? templateId
        : _string(alias, 'templateId');
    final resolvedVariantId = alias == null
        ? variantId
        : _string(alias, 'variantId');
    return {
      for (final parameter in _optionParameters(
        resolvedTemplateId,
        resolvedVariantId,
      ))
        ((parameter['requestPath'] as String?) ?? _string(parameter, 'id'))
            .split('.')
            .first,
    };
  }

  List<Map<String, Object?>> _optionParameters(
    String templateId,
    String variantId,
  ) {
    final template = _rawTemplateRecords.singleWhere(
      (item) => item['id'] == templateId,
    );
    final rawVariant = _list(template, 'variants')
        .map((item) => _map(item, 'variant'))
        .singleWhere((item) => item['id'] == variantId);
    final reference = _map(
      rawVariant['optionSchemaId'],
      'option schema reference',
    );
    final schema = _rawOptionSchemas.singleWhere(
      (item) =>
          item['id'] == reference['id'] &&
          item['revision'] == reference['revision'],
    );
    return [
      for (final raw in _list(schema, 'parameters')) _map(raw, 'parameter'),
    ];
  }

  Map<String, Object?> _catalogOptionValues(
    String templateId,
    String variantId,
    Map<String, Object?> options,
  ) {
    final values = <String, Object?>{};
    for (final parameter in _optionParameters(templateId, variantId)) {
      final id = _string(parameter, 'id');
      final path = (parameter['requestPath'] as String?) ?? id;
      Object? value = options;
      for (final segment in path.split('.')) {
        if (value is! Map || !value.containsKey(segment)) {
          value = null;
          break;
        }
        value = value[segment];
      }
      if (value != null) values[id] = value;
    }
    final fullBody = options['fullBody'];
    if (fullBody == null) return values;
    final selection = _map(fullBody, 'options.fullBody');
    if (selection['phase'] != null) values['phase'] = selection['phase'];
    if (selection['liftProfiles'] case final Object rawProfiles) {
      final profiles = _map(rawProfiles, 'options.fullBody.liftProfiles');
      for (final entry in profiles.entries) {
        values['${entry.key}_set_profile'] = entry.value;
      }
    }
    return values;
  }

  Map<String, Object?> _optionDefaults(String templateId, String variantId) {
    return {
      for (final parameter in _optionParameters(templateId, variantId))
        if (parameter['default'] != null)
          _string(parameter, 'id'): parameter['default'],
    };
  }

  SourceSchedule _selectSchedule(
    String templateId,
    String variantId,
    List<String> requestedOrder, {
    String? scheduleId,
  }) {
    final variant = _templates
        .singleWhere((item) => item.id == templateId)
        .variants
        .singleWhere((item) => item.id == variantId);
    final allowed = _schedules
        .where(
          (schedule) => variant.scheduleIds.any(
            (reference) =>
                reference.id == schedule.reference.id &&
                reference.revision == schedule.reference.revision,
          ),
        )
        .toList(growable: false);
    return allowed.where((candidate) {
          final order = candidate.sessions
              .map((session) => session.id)
              .toList(growable: false);
          return scheduleId == null &&
              requestedOrder.isNotEmpty &&
              _sameStrings(order, requestedOrder);
        }).firstOrNull ??
        allowed
            .where((candidate) => candidate.reference.id == scheduleId)
            .firstOrNull ??
        allowed.first;
  }

  List<int> _defaultTrainingDays(SourceSchedule schedule) {
    return List<int>.generate(schedule.sessions.length, (index) => index + 1);
  }

  Map<String, Object?> _metadata() {
    if (_catalogVersion == null || _catalogHash == null) {
      throw StateError('ENGINE_NOT_INITIALIZED');
    }
    return {
      'apiVersion': 'v1',
      'schemaVersion': 1,
      'engineVersion': '0.1.0',
      'catalogVersion': _catalogVersion,
      'catalogHash': _catalogHash,
    };
  }

  Map<String, Object?> _issue(Object error) => {
    'code': 'INVALID_CYCLE_REQUEST',
    'path': '',
    'messageKey': 'engine.invalidCycleRequest',
    'details': {'message': error.toString()},
    'severity': 'error',
  };

  Iterable<Map<String, Object?>> _optionFields(
    Map<String, Object?> parameter,
    Map<String, String> requestPaths,
    Map<String, String> scopes,
    Map<String, Object?> optionOverrides,
    List<String> movementIds,
  ) {
    if (scopes[_string(parameter, 'id')] != 'perMovement') {
      return [_optionField(parameter, requestPaths, scopes, optionOverrides)];
    }
    if (parameter['type'] != 'percentage') {
      throw FormatException(
        'UNSUPPORTED_PER_MOVEMENT_EDITOR_TYPE:${parameter['type']}',
      );
    }
    return [
      for (final movementId in movementIds)
        _optionField(
          parameter,
          requestPaths,
          scopes,
          optionOverrides,
          movementId: movementId,
        ),
    ];
  }

  Map<String, Object?> _optionField(
    Map<String, Object?> parameter,
    Map<String, String> requestPaths,
    Map<String, String> scopes,
    Map<String, Object?> optionOverrides, {
    String? movementId,
  }) {
    final parameterId = _string(parameter, 'id');
    final type = parameter['type'] as String;
    final presentationGroup = parameter['presentationGroup'] as String?;
    final baseRequestPath = requestPaths[parameterId]!;
    final requestPath = movementId == null
        ? baseRequestPath
        : '$baseRequestPath.$movementId';
    final scopedRequestPaths = {
      for (final entry in requestPaths.entries)
        entry.key: movementId != null && scopes[entry.key] == 'perMovement'
            ? '${entry.value}.$movementId'
            : entry.value,
    };
    final baseLabel = {
      'en': parameter['labelEn'] ?? parameterId,
      'fr': parameter['labelFr'] ?? parameter['labelEn'] ?? parameterId,
    };
    final movementLabel = movementId == null
        ? null
        : _movementLabels[movementId];
    final kind = switch (type) {
      'boolean' => 'boolean',
      'integer' => 'integer',
      'percentage' => 'percentage',
      'choice' || 'enumeration' => 'choice',
      'weight' => 'weight',
      _ => 'text',
    };
    return _field(
      id: movementId == null ? parameterId : '$parameterId.$movementId',
      path: 'options.$requestPath',
      region: const {'warmup', 'joker', 'deload'}.contains(presentationGroup)
          ? 'additional-options'
          : 'template',
      group: presentationGroup,
      groupLabel: _optionGroupLabel(presentationGroup),
      kind: kind,
      label: movementLabel == null
          ? baseLabel
          : {
              'en': '${baseLabel['en']} — ${movementLabel['en'] ?? movementId}',
              'fr':
                  '${baseLabel['fr']} — '
                  '${movementLabel['fr'] ?? movementLabel['en'] ?? movementId}',
            },
      value: _scopedOptionValue(
        optionOverrides[parameterId],
        parameter['default'],
        movementId,
      ),
      minimum: parameter['minimum'] as num?,
      maximum: parameter['maximum'] as num?,
      step: parameter['step'] as num?,
      choices: [
        for (final value
            in (parameter['allowedValues'] as List<Object?>? ?? const []))
          {'value': value, 'label': value.toString()},
      ],
      visibleWhen: _editorConditions(
        parameter['visibleWhen'],
        scopedRequestPaths,
      ),
      enabledWhen: _editorConditions(
        parameter['enabledWhen'],
        scopedRequestPaths,
      ),
    );
  }
}

Object? _scopedOptionValue(
  Object? override,
  Object? defaultValue,
  String? movementId,
) {
  if (movementId == null) return override ?? defaultValue;
  if (override is Map && override.containsKey(movementId)) {
    return override[movementId];
  }
  if (defaultValue is Map && defaultValue.containsKey(movementId)) {
    return defaultValue[movementId];
  }
  return override ?? defaultValue;
}

Map<String, Object?> _engineTemplateDocument(Map<String, Object?> document) {
  final copy = _map(jsonDecode(jsonEncode(document)), 'template document');
  for (final raw in _list(copy, 'templates')) {
    _map(raw, 'template').remove('isDefault');
  }
  return copy;
}

List<Map<String, Object?>> _editorConditions(
  Object? raw,
  Map<String, String> requestPaths,
) {
  if (raw == null) return const [];
  final condition = _map(raw, 'option condition');
  final type = _string(condition, 'type');
  String path() {
    final optionId =
        condition['parameterId'] as String? ?? condition['optionId'] as String?;
    if (optionId == null) {
      throw const FormatException('CONDITION_PARAMETER_ID_REQUIRED');
    }
    final requestPath = requestPaths[optionId];
    if (requestPath == null) {
      throw FormatException('UNKNOWN_CONDITION_OPTION:$optionId');
    }
    return 'options.$requestPath';
  }

  return switch (type) {
    'always' =>
      condition['value'] as bool? ?? true
          ? const []
          : throw const FormatException('ALWAYS_FALSE_EDITOR_CONDITION'),
    'present' => [
      {'path': path(), 'operator': 'present'},
    ],
    'equals' => [
      {'path': path(), 'operator': 'equals', 'value': condition['value']},
    ],
    'in' => [
      {'path': path(), 'operator': 'in', 'value': condition['values']},
    ],
    'range' => [
      {
        'path': path(),
        'operator': 'greaterThanOrEqual',
        'value': condition['minimum'],
      },
      {
        'path': path(),
        'operator': 'lessThanOrEqual',
        'value': condition['maximum'],
      },
    ],
    'all' => [
      for (final child in _list(condition, 'conditions'))
        ..._editorConditions(child, requestPaths),
    ],
    final value => throw FormatException('UNSUPPORTED_EDITOR_CONDITION:$value'),
  };
}

Map<String, String>? _optionGroupLabel(String? group) => switch (group) {
  'warmup' => const {'en': 'Warm-up', 'fr': 'Échauffement'},
  'joker' => const {'en': 'Joker Sets', 'fr': 'Séries Joker'},
  'deload' => const {'en': 'Deload', 'fr': 'Deload'},
  'assistance' => const {'en': 'Assistance', 'fr': 'Assistance'},
  'conditioning' => const {'en': 'Conditioning', 'fr': 'Conditionnement'},
  _ => null,
};

final class _BridgeForeverCycleResolver
    implements SyncForeverCycleDefinitionResolver {
  const _BridgeForeverCycleResolver(this._resolve);

  final ResolvedCycleDefinition Function(ForeverCycleReference) _resolve;

  @override
  ResolvedCycleDefinition resolveSync(ForeverCycleReference reference) =>
      _resolve(reference);
}

Map<String, Object?> _macrocycleJson(GeneratedMacrocycle value) => {
  'id': value.id,
  'definitionId': value.definitionId.value,
  'definitionRevision': value.definitionRevision.value,
  'state': value.state.name,
  'nodes': [
    for (final node in value.nodes)
      {
        'index': node.index,
        'slotId': node.slotId,
        'role': node.role.name,
        'cycleReference': {
          'templateId': node.cycleReference.templateId,
          'variantId': node.cycleReference.variantId,
          'templateRevision': node.cycleReference.templateRevision,
          'variantRevision': node.cycleReference.variantRevision,
        },
        'cycle': node.cycle.toJson(),
        'trainingMaxesBefore': _trainingMaxSnapshotJson(
          node.trainingMaxesBefore,
        ),
        'trainingMaxesAfter': _trainingMaxSnapshotJson(node.trainingMaxesAfter),
      },
  ],
  'initialTrainingMaxes': {
    for (final entry in value.initialTrainingMaxes.entries)
      entry.key.value: entry.value.toJson(),
  },
  'projectedTrainingMaxes': {
    for (final entry in value.projectedTrainingMaxes.entries)
      entry.key.value: entry.value.toJson(),
  },
};

Map<String, Object?> _trainingMaxSnapshotJson(TrainingMaxSnapshot value) => {
  'kind': value.kind.name,
  'values': {
    for (final entry in value.values.entries)
      entry.key.value: entry.value.toJson(),
  },
};

String _movementTokenLabel(String id) => switch (id) {
  'overhead_press' => 'OP',
  'bench_press' => 'BP',
  'squat' => 'SQ',
  'deadlift' => 'DL',
  'squat_bench_press' => 'SQ+BP',
  'deadlift_overhead_press' => 'DL+OP',
  _ => id,
};

Map<String, Object?> _field({
  required String id,
  required String path,
  required String region,
  required String kind,
  required Object label,
  required Object? value,
  Object? choices,
  String? group,
  Object? groupLabel,
  num? minimum,
  num? maximum,
  num? step,
  String? action,
  bool? readOnly,
  Object? visibleWhen,
  Object? enabledWhen,
}) => {
  'id': id,
  'path': path,
  'region': region,
  'kind': kind,
  'label': label,
  'value': value,
  'choices': ?choices,
  'group': ?group,
  'groupLabel': ?groupLabel,
  'minimum': ?minimum,
  'maximum': ?maximum,
  'step': ?step,
  'action': ?action,
  'readOnly': ?readOnly,
  'visibleWhen': ?visibleWhen,
  'enabledWhen': ?enabledWhen,
};

Map<String, Object?> _map(Object? value, String label) =>
    value is Map<String, Object?>
    ? value
    : throw FormatException('$label must be an object');
List<Object?> _list(Map<String, Object?> map, String key) =>
    map[key] is List<Object?>
    ? map[key]! as List<Object?>
    : throw FormatException('$key must be a list');
String _string(Map<String, Object?> map, String key) => map[key] is String
    ? map[key]! as String
    : throw FormatException('$key must be a string');
int _integer(Map<String, Object?> map, String key) => map[key] is int
    ? map[key]! as int
    : throw FormatException('$key must be an integer');
List<String> _strings(Map<String, Object?> map, String key) =>
    _list(map, key).map((value) => value as String).toList(growable: false);
List<int> _integers(Map<String, Object?> map, String key) =>
    _list(map, key).map((value) => value as int).toList(growable: false);
Map<String, Object?> _optionalMap(Object? value) =>
    value == null ? <String, Object?>{} : _map(value, 'map');
Weight _weight(Map<String, Object?> value) => Weight(
  _integer(value, 'centiUnits'),
  WeightUnit.values.byName(_string(value, 'unit')),
);
bool _sameStrings(List<String> left, List<String> right) =>
    left.length == right.length &&
    List.generate(
      left.length,
      (index) => left[index] == right[index],
    ).every((value) => value);
void _keys(Map<String, Object?> map, Set<String> allowed) {
  final unknown = map.keys.toSet().difference(allowed);
  if (unknown.isNotEmpty) throw FormatException('Unknown key ${unknown.first}');
  final missing = allowed.difference(map.keys.toSet());
  if (missing.isNotEmpty) throw FormatException('Missing key ${missing.first}');
}

void _rejectUnknown(Map<String, Object?> map, Set<String> allowed) {
  final unknown = map.keys.toSet().difference(allowed);
  if (unknown.isNotEmpty) throw FormatException('UNKNOWN_KEY:${unknown.first}');
}

void _requireV1(Map<String, Object?> map) {
  if (map['apiVersion'] != 'v1' || map['schemaVersion'] != 1) {
    throw const FormatException('UNSUPPORTED_CONTRACT_VERSION');
  }
}

String _canonicalJson(Object? value) {
  if (value is List) return '[${value.map(_canonicalJson).join(',')}]';
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  return jsonEncode(value);
}

String _fnv1a64(String value) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final byte in utf8.encode(value)) {
    hash ^= BigInt.from(byte);
    hash = (hash * prime) & mask;
  }
  return 'fnv1a64-${hash.toRadixString(16).padLeft(16, '0')}';
}
