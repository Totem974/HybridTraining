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

  static const schemaVersion = 3;

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

  String encode(Poc531Configuration configuration) =>
      jsonEncode(_canonicalize(configuration.toJson()));

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
      2 => _decodeV3(migrateV2(payload)),
      3 => _decodeV3(payload),
      _ => throw FormatException(
        'Unsupported configuration schema version: $version.',
      ),
    };
  }

  /// Converts the former flat calculator payload into the explicit v3 shape.
  Map<String, Object?> migrateV2(Map<String, Object?> source) {
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
      return Poc531Configuration.forever(
        common: common,
        forever: {
          'programId': id,
          'planKind': isBeginner ? 'standaloneProgram' : 'macrocycle',
          if (!isBeginner) 'recipeId': 'forever-2l1a',
          if (!isBeginner) 'nodes': _foreverOriginalNodes,
          if (requestedId != null && requestedId != id)
            'sourceAlias': requestedId,
        },
      ).toJson();
    }

    final cycle = <String, Object?>{};
    for (final entry in values.entries) {
      if (!_ignoredV2Keys.contains(entry.key) &&
          !_commonKeys.contains(entry.key) &&
          entry.value != null) {
        cycle[entry.key] = _copyValue(entry.value);
      }
    }
    return Poc531Configuration.cycle(common: common, cycle: cycle).toJson();
  }

  Poc531Configuration _decodeV3(Map<String, Object?> payload) {
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
      return Poc531Configuration.forever(
        common: common,
        forever: _requiredMap(payload, 'forever'),
      );
    }
    throw FormatException('Unsupported configuration mode: $mode.');
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
