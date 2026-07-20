import 'dart:convert';

/// Versioned transport envelope for calculator and planning configuration.
///
/// The nested maps deliberately remain transport values: this codec can be
/// shared by presentation and planning without either layer depending on the
/// other's models.
class Poc531Configuration {
  Poc531Configuration._({
    required this.mode,
    required Map<String, Object?> common,
    Map<String, Object?>? cycle,
    Map<String, Object?>? forever,
  }) : common = Map.unmodifiable(common),
       cycle = cycle == null ? null : Map.unmodifiable(cycle),
       forever = forever == null ? null : Map.unmodifiable(forever);

  factory Poc531Configuration.cycle({
    required Map<String, Object?> common,
    required Map<String, Object?> cycle,
  }) => Poc531Configuration._(mode: 'cycle', common: common, cycle: cycle);

  factory Poc531Configuration.forever({
    required Map<String, Object?> common,
    required Map<String, Object?> forever,
  }) =>
      Poc531Configuration._(mode: 'forever', common: common, forever: forever);

  static const schemaVersion = 4;

  final String mode;
  final Map<String, Object?> common;
  final Map<String, Object?>? cycle;
  final Map<String, Object?>? forever;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'mode': mode,
    'common': common,
    if (cycle != null) 'cycle': cycle,
    if (forever != null) 'forever': forever,
  };
}

class Poc531ConfigurationCodec {
  const Poc531ConfigurationCodec();

  static const beginnerPrepSchoolId = 'forever-beginner-prep-school-v1';
  static const foreverOriginalFslId = 'forever-original-531-fsl-2l1a-v1';

  static const _beginnerAliases = {
    beginnerPrepSchoolId,
    'beginner-prep-school-v1',
    'beginner-prep-school',
    'FV-141',
  };
  static const _foreverOriginalAliases = {foreverOriginalFslId, 'FV-236'};

  String encode(Poc531Configuration configuration) {
    if (configuration.forever case final forever?) {
      _validateForeverV4(forever);
    }
    return jsonEncode(_canonicalize(configuration.toJson()));
  }

  Poc531Configuration decode(String payload) {
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      throw const FormatException('Configuration must be a JSON object.');
    }
    return decodeMap(_stringMap(decoded));
  }

  Poc531Configuration decodeMap(Map<String, Object?> payload) {
    final version = payload['schemaVersion'];
    return switch (version) {
      2 => _decodeV4(migrateV3ToV4(migrateV2ToV3(payload))),
      3 => _decodeV4(migrateV3ToV4(payload)),
      4 => _decodeV4(payload),
      _ => throw FormatException(
        'Unsupported configuration schema version: $version.',
      ),
    };
  }

  /// Converts the former flat calculator payload into the explicit v3 shape.
  Map<String, Object?> migrateV2(Map<String, Object?> source) =>
      migrateV3ToV4(migrateV2ToV3(source));

  /// Converts the former flat calculator payload into the explicit v3 shape.
  Map<String, Object?> migrateV2ToV3(Map<String, Object?> source) {
    if (source['schemaVersion'] != 2) {
      throw const FormatException('Only schema version 2 can be migrated.');
    }
    final values = Map<String, Object?>.from(source);
    final requestedId = _stringValue(
      values['foreverTemplateId'] ?? values['programId'],
    );
    final isBeginner =
        requestedId != null && _beginnerAliases.contains(requestedId);
    final isForever = values['mode'] == 'forever';

    final common = <String, Object?>{};
    for (final key in _commonKeys) {
      if (values.containsKey(key)) common[key] = _copyValue(values[key]);
    }

    if (isForever) {
      final id = isBeginner
          ? beginnerPrepSchoolId
          : _canonicalForeverId(requestedId);
      return <String, Object?>{
        'schemaVersion': 3,
        'mode': 'forever',
        'common': common,
        'forever': {
          'programId': id,
          'planKind': isBeginner ? 'standaloneProgram' : 'macrocycle',
          if (!isBeginner) 'recipeId': 'forever-2l1a',
          if (!isBeginner) 'nodes': _foreverOriginalNodes,
          if (requestedId != null && requestedId != id)
            'sourceAlias': requestedId,
        },
      };
    }

    final cycle = <String, Object?>{};
    for (final entry in values.entries) {
      if (!_ignoredV2Keys.contains(entry.key) &&
          !_commonKeys.contains(entry.key) &&
          entry.value != null) {
        cycle[entry.key] = _copyValue(entry.value);
      }
    }
    return <String, Object?>{
      'schemaVersion': 3,
      'mode': 'cycle',
      'common': common,
      'cycle': cycle,
    };
  }

  /// Migrates v3's fixed Forever plan into v4's finite macrocycle series.
  Map<String, Object?> migrateV3ToV4(Map<String, Object?> source) {
    if (source['schemaVersion'] != 3) {
      throw const FormatException('Only schema version 3 can be migrated.');
    }
    final result = _stringMap(source)..['schemaVersion'] = 4;
    if (result['mode'] != 'forever') return result;

    final oldForever = _requiredMap(result, 'forever');
    final planKind = oldForever['planKind'];
    final requestedId = _stringValue(oldForever['programId']);
    if (planKind == 'standaloneProgram' ||
        (requestedId != null && _beginnerAliases.contains(requestedId))) {
      result['forever'] = <String, Object?>{
        'standaloneProgramId': beginnerPrepSchoolId,
        if (oldForever['sourceAlias'] != null)
          'sourceAlias': _copyValue(oldForever['sourceAlias']),
      };
      return result;
    }

    final sourceAlias =
        oldForever['sourceAlias'] ??
        (requestedId != null && requestedId != foreverOriginalFslId
            ? requestedId
            : null);
    result['forever'] = <String, Object?>{
      'series': <String, Object?>{
        'id': 'forever-series-v1',
        'terminated': false,
        'macrocycles': <Object?>[
          <String, Object?>{
            'instanceId': 'M1',
            'intent': 'active',
            'status': 'active',
            'recipeId': 'forever-2l1a-v2',
            'slots': _v4SlotsFromNodes(oldForever['nodes']),
            'protocols': _v4ProtocolsFromNodes(oldForever['nodes']),
            'trainingMaxStates': <String, Object?>{},
          },
        ],
      },
      'sourceAlias': ?sourceAlias,
    };
    return result;
  }

  Poc531Configuration _decodeV4(Map<String, Object?> payload) {
    final mode = payload['mode'];
    final common = _requiredMap(payload, 'common');
    if (mode == 'cycle') {
      if (payload.containsKey('forever')) {
        throw const FormatException(
          'Cycle configuration cannot contain forever.',
        );
      }
      return Poc531Configuration.cycle(
        common: common,
        cycle: _requiredMap(payload, 'cycle'),
      );
    }
    if (mode == 'forever') {
      if (payload.containsKey('cycle')) {
        throw const FormatException(
          'Forever configuration cannot contain cycle.',
        );
      }
      final forever = _requiredMap(payload, 'forever');
      final standaloneId = _stringValue(forever['standaloneProgramId']);
      if (standaloneId != null && _beginnerAliases.contains(standaloneId)) {
        forever['standaloneProgramId'] = beginnerPrepSchoolId;
        if (standaloneId != beginnerPrepSchoolId) {
          forever.putIfAbsent('sourceAlias', () => standaloneId);
        }
      }
      _validateForeverV4(forever);
      return Poc531Configuration.forever(common: common, forever: forever);
    }
    throw FormatException('Unsupported configuration mode: $mode.');
  }

  static void _validateForeverV4(Map<String, Object?> forever) {
    final standaloneValue = forever['standaloneProgramId'];
    final seriesValue = forever['series'];
    if (standaloneValue != null && standaloneValue is! String) {
      throw const FormatException('standaloneProgramId must be a string.');
    }
    if (seriesValue != null && seriesValue is! Map) {
      throw const FormatException('series must be an object.');
    }
    final hasStandalone = standaloneValue is String;
    final hasSeries = seriesValue is Map;
    if (hasStandalone == hasSeries) {
      throw const FormatException(
        'Forever must contain exactly one of standaloneProgramId or series.',
      );
    }
    if (hasStandalone) {
      if (standaloneValue.isEmpty) {
        throw const FormatException(
          'standaloneProgramId must be a non-empty string.',
        );
      }
      return;
    }
    final series = _stringMap(forever['series']! as Map);
    if (series['id'] is! String || (series['id'] as String).isEmpty) {
      throw const FormatException('series.id must be a non-empty string.');
    }
    if (series['terminated'] is! bool) {
      throw const FormatException('series.terminated must be a boolean.');
    }
    final macrocycles = series['macrocycles'];
    if (macrocycles is! List) {
      throw const FormatException('series.macrocycles must be a list.');
    }
    final instanceIds = <String>{};
    var projectedWasSeen = false;
    for (final value in macrocycles) {
      if (value is! Map) {
        throw const FormatException('Every macrocycle must be an object.');
      }
      final macrocycle = _stringMap(value);
      if (macrocycle['recipeId'] is! String ||
          (macrocycle['recipeId'] as String).isEmpty) {
        throw const FormatException(
          'macrocycle.recipeId must be a non-empty string.',
        );
      }
      final instanceId = macrocycle['instanceId'];
      if (instanceId is! String || instanceId.isEmpty) {
        throw const FormatException(
          'macrocycle.instanceId must be a non-empty string.',
        );
      }
      if (!instanceIds.add(instanceId)) {
        throw FormatException('Duplicate macrocycle instanceId: $instanceId.');
      }
      final intent = macrocycle['intent'];
      if (intent != 'active' && intent != 'projected') {
        throw FormatException('Unsupported macrocycle intent: $intent.');
      }
      if (intent == 'projected') projectedWasSeen = true;
      if (intent == 'active' && projectedWasSeen) {
        throw const FormatException(
          'An active macrocycle cannot follow a projected macrocycle.',
        );
      }
      final status = macrocycle['status'];
      if (!_macrocycleStatuses.contains(status)) {
        throw FormatException('Unsupported macrocycle status: $status.');
      }
      if (series['terminated'] == true &&
          (intent == 'projected' ||
              status == 'active' ||
              status == 'planned')) {
        throw const FormatException(
          'A terminated series cannot contain active or future macrocycles.',
        );
      }
      if (macrocycle['recipeId'] == 'forever-2l2a-v1' ||
          macrocycle['recipeId'] == 'forever-3l2a-v1' ||
          macrocycle['status'] == 'needsReview' ||
          _containsNeedsReview(macrocycle)) {
        throw const FormatException(
          'A needsReview definition cannot be executable.',
        );
      }
      for (final key in const ['slots', 'protocols']) {
        if (macrocycle[key] is! List) {
          throw FormatException('macrocycle.$key must be a list.');
        }
        if ((macrocycle[key]! as List).any((value) => value is! Map)) {
          throw FormatException(
            'Every macrocycle.$key item must be an object.',
          );
        }
      }
      if (macrocycle['trainingMaxStates'] is! Map) {
        throw const FormatException(
          'macrocycle.trainingMaxStates must be an object.',
        );
      }
      final trainingMaxStates = macrocycle['trainingMaxStates'] as Map;
      for (final entry in trainingMaxStates.entries) {
        if (entry.key is! String || entry.key.toString().isEmpty) {
          throw const FormatException('Training Max lift IDs must be strings.');
        }
        final rawState = entry.value;
        final state = rawState is String
            ? rawState
            : rawState is Map
            ? rawState['state']
            : null;
        if (state is! String || !_trainingMaxStates.contains(state)) {
          throw FormatException('Unsupported Training Max state: $rawState.');
        }
        if (rawState is Map) {
          for (final valueKey in const [
            'trainingMax',
            'confirmedTrainingMax',
            'proposedTrainingMax',
            'value',
          ]) {
            final candidate = rawState[valueKey];
            if (candidate != null && (candidate is! num || candidate <= 0)) {
              throw FormatException(
                'Invalid Training Max value for ${entry.key}.',
              );
            }
          }
        }
      }
      if (macrocycle['recipeId'] == 'forever-2l1a-v2') {
        _validateTwoLeadersOneAnchor(macrocycle);
      }
    }
  }

  static void _validateTwoLeadersOneAnchor(Map<String, Object?> macrocycle) {
    final slots = macrocycle['slots']! as List;
    const expectedSlots = [
      ('leader-1', 'leader', 'forever-original-fsl-leader-v1'),
      ('leader-2', 'leader', 'forever-original-fsl-leader-v1'),
      ('anchor-1', 'anchor', 'forever-original-pr-set-anchor-v1'),
    ];
    if (slots.length != expectedSlots.length) {
      throw const FormatException('The 2L/1A recipe requires three slots.');
    }
    for (var index = 0; index < expectedSlots.length; index++) {
      final value = slots[index];
      if (value is! Map) {
        throw const FormatException('Every slot must be an object.');
      }
      final expected = expectedSlots[index];
      if (value['slotId'] != expected.$1 ||
          value['role'] != expected.$2 ||
          value['cycleTemplateRevisionId'] != expected.$3) {
        throw FormatException('Invalid 2L/1A slot at index $index.');
      }
    }

    final protocols = macrocycle['protocols']! as List;
    const expectedProtocols = {
      'leaders-to-anchor': 'forever-seventh-week-deload-v1',
      'macrocycle-end': 'forever-seventh-week-tm-test-v1',
    };
    if (protocols.length != expectedProtocols.length) {
      throw const FormatException(
        'The 2L/1A recipe requires both boundary protocols.',
      );
    }
    final seenBoundaries = <String>{};
    for (final value in protocols) {
      if (value is! Map || value['required'] != true) {
        throw const FormatException('Boundary protocols must be required.');
      }
      final boundaryId = value['boundaryId'];
      if (boundaryId is! String ||
          !seenBoundaries.add(boundaryId) ||
          value['protocolTemplateRevisionId'] !=
              expectedProtocols[boundaryId]) {
        throw const FormatException('Invalid mandatory boundary protocol.');
      }
    }
  }

  static const _macrocycleStatuses = {
    'planned',
    'active',
    'completed',
    'cancelled',
  };
  static const _trainingMaxStates = {
    'confirmed',
    'projected',
    'proposed',
    'held',
    'reset',
  };

  static bool _containsNeedsReview(Object? value) => switch (value) {
    String text => text == 'needsReview' || text == 'NEEDS_REVIEW',
    Map map => map.values.any(_containsNeedsReview),
    List list => list.any(_containsNeedsReview),
    _ => false,
  };

  static List<Map<String, Object?>> _v4SlotsFromNodes(Object? nodes) {
    final cycleNodes = nodes is List
        ? nodes
              .whereType<Map>()
              .where((node) => node['kind'] == 'cycle')
              .toList()
        : const <Map>[];
    const defaults = [
      ('leader-1', 'leader', 'forever-original-fsl-leader-v1'),
      ('leader-2', 'leader', 'forever-original-fsl-leader-v1'),
      ('anchor-1', 'anchor', 'forever-original-pr-set-anchor-v1'),
    ];
    return [
      for (var index = 0; index < defaults.length; index++)
        <String, Object?>{
          'slotId': defaults[index].$1,
          'role': defaults[index].$2,
          'cycleTemplateRevisionId': defaults[index].$3,
          if (index < cycleNodes.length)
            'sourceNodeId': cycleNodes[index]['nodeId'],
        },
    ];
  }

  static List<Map<String, Object?>> _v4ProtocolsFromNodes(Object? nodes) {
    final protocolNodes = nodes is List
        ? nodes
              .whereType<Map>()
              .where((node) => node['kind'] == 'protocol')
              .toList()
        : const <Map>[];
    return [
      <String, Object?>{
        'boundaryId': 'leaders-to-anchor',
        'protocolTemplateRevisionId': 'forever-seventh-week-deload-v1',
        'required': true,
        if (protocolNodes.isNotEmpty)
          'sourceNodeId': protocolNodes.first['nodeId'],
      },
      <String, Object?>{
        'boundaryId': 'macrocycle-end',
        'protocolTemplateRevisionId': 'forever-seventh-week-tm-test-v1',
        'required': true,
        if (protocolNodes.length > 1)
          'sourceNodeId': protocolNodes[1]['nodeId'],
      },
    ];
  }

  static String _canonicalForeverId(String? id) =>
      id != null && _foreverOriginalAliases.contains(id)
      ? foreverOriginalFslId
      : id ?? foreverOriginalFslId;

  static Map<String, Object?> _requiredMap(
    Map<String, Object?> payload,
    String key,
  ) {
    final value = payload[key];
    if (value is! Map) throw FormatException('$key must be an object.');
    return _stringMap(value);
  }

  static String? _stringValue(Object? value) => value is String ? value : null;

  static Map<String, Object?> _stringMap(Map value) => {
    for (final entry in value.entries)
      entry.key.toString(): _copyValue(entry.value),
  };

  static Object? _copyValue(Object? value) => switch (value) {
    Map map => _stringMap(map),
    List list => [for (final item in list) _copyValue(item)],
    _ => value,
  };

  static Object? _canonicalize(Object? value) => switch (value) {
    Map map => {
      for (final key in map.keys.map((key) => key.toString()).toList()..sort())
        key: _canonicalize(map[key]),
    },
    List list => [for (final item in list) _canonicalize(item)],
    _ => value,
  };

  static const _commonKeys = {
    'unit',
    'inputMode',
    'trainingMaxRatio',
    'days',
    'trainingWeekdays',
    'roundingIncrement',
    'startDate',
    'barWeight',
    'plates',
    'lifts',
    'repetitions',
    'liftOrder',
  };

  static const _ignoredV2Keys = {'schemaVersion', 'mode', 'foreverTemplateId'};

  static const _foreverOriginalNodes = <Map<String, String>>[
    {'nodeId': 'C1', 'kind': 'cycle', 'role': 'leader'},
    {'nodeId': 'C2', 'kind': 'cycle', 'role': 'leader'},
    {'nodeId': 'P1', 'kind': 'protocol', 'purpose': 'seventhWeekDeload'},
    {'nodeId': 'C3', 'kind': 'cycle', 'role': 'anchor'},
    {
      'nodeId': 'P2',
      'kind': 'protocol',
      'purpose': 'seventhWeekTrainingMaxTest',
    },
  ];
}
