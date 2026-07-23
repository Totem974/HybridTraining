import 'dart:convert';

/// Strict decoder and generic projection for `CycleConfiguration` v1.
///
/// Template-specific options remain opaque here. They are merged with the
/// three cross-cutting option groups and are interpreted later by the catalog
/// resolver, never by this codec.
final class CycleConfigurationCodec {
  const CycleConfigurationCodec();

  Map<String, Object?> toCycleRequest(
    Map<String, Object?> source, {
    required int catalogVersion,
    required String catalogHash,
  }) {
    _keys(source, const {
      'format',
      'configurationVersion',
      'catalogVersion',
      'catalogHash',
      'template',
      'commonOptions',
      'maxes',
      'schedule',
      'equipment',
      'output',
    }, r'$');
    if (source['format'] != 'hybrid-training-cycle' ||
        source['configurationVersion'] != 1) {
      _fail(
        'UNSUPPORTED_CONFIGURATION_VERSION',
        r'$',
        'configuration.unsupportedVersion',
      );
    }
    if (_integer(source, 'catalogVersion', r'$') != catalogVersion ||
        _string(source, 'catalogHash', r'$') != catalogHash) {
      _fail(
        'CATALOG_IDENTITY_MISMATCH',
        r'$',
        'configuration.catalogIdentityMismatch',
        details: {
          'expectedCatalogVersion': catalogVersion,
          'expectedCatalogHash': catalogHash,
          'actualCatalogVersion': source['catalogVersion'],
          'actualCatalogHash': source['catalogHash'],
        },
      );
    }

    final template = _object(source['template'], r'$.template');
    _keys(template, const {'id', 'variantId', 'options'}, r'$.template');
    final templateId = _stableId(template, 'id', r'$.template');
    final variantId = _stableId(template, 'variantId', r'$.template');
    final templateOptions = _jsonObject(
      template['options'],
      r'$.template.options',
    );

    final common = _object(source['commonOptions'], r'$.commonOptions');
    _keys(common, const {'warmUp', 'joker', 'deload'}, r'$.commonOptions');
    final commonOptions = {
      'warmUp': _warmUp(common['warmUp']),
      'joker': _joker(common['joker']),
      'deload': _deload(common['deload']),
    };

    final maxes = _object(source['maxes'], r'$.maxes');
    _keys(
      maxes,
      const {
        'mode',
        'globalTrainingMaxRatioBasisPoints',
        'values',
        'ratiosByMovement',
      },
      r'$.maxes',
      optional: const {'ratiosByMovement'},
    );
    final mode = _enum(maxes, 'mode', const {
      'oneRepMax',
      'onePlusSet',
      'repMax',
      'directTrainingMax',
    }, r'$.maxes');
    final ratio = _basisPoints(
      maxes['globalTrainingMaxRatioBasisPoints'],
      r'$.maxes.globalTrainingMaxRatioBasisPoints',
    );
    final values = _object(maxes['values'], r'$.maxes.values');
    if (values.isEmpty) {
      _fail(
        'MIN_PROPERTIES',
        r'$.maxes.values',
        'configuration.valuesRequired',
      );
    }
    final maxInputs = <String, Object?>{};
    for (final entry in values.entries) {
      _checkStableId(entry.key, '\$.maxes.values.${entry.key}');
      final value = _object(entry.value, '\$.maxes.values.${entry.key}');
      final allowed = mode == 'repMax'
          ? const {'weight', 'repetitions', 'formula'}
          : const {'weight'};
      _keys(
        value,
        allowed,
        '\$.maxes.values.${entry.key}',
        optional: mode == 'repMax' ? const {'formula'} : const {},
      );
      final input = <String, Object?>{
        'type': mode,
        'weight': _weight(
          value['weight'],
          '\$.maxes.values.${entry.key}.weight',
        ),
      };
      if (mode == 'repMax') {
        final repetitions = _integer(
          value,
          'repetitions',
          '\$.maxes.values.${entry.key}',
        );
        if (repetitions < 1) {
          _fail(
            'VALUE_OUT_OF_RANGE',
            '\$.maxes.values.${entry.key}.repetitions',
            'configuration.invalidRepetitions',
          );
        }
        input['repetitions'] = repetitions;
        if (value['formula'] != null) {
          input['formula'] = _nonEmptyString(
            value,
            'formula',
            '\$.maxes.values.${entry.key}',
          );
        }
      }
      maxInputs[entry.key] = input;
    }
    final ratiosByMovement = maxes['ratiosByMovement'] == null
        ? null
        : _basisPointMap(
            maxes['ratiosByMovement'],
            r'$.maxes.ratiosByMovement',
          );

    final schedule = _object(source['schedule'], r'$.schedule');
    _keys(
      schedule,
      const {'id', 'startDate', 'sessionOrder', 'trainingDays'},
      r'$.schedule',
      optional: const {'trainingDays'},
    );
    final scheduleId = _stableId(schedule, 'id', r'$.schedule');
    final startDate = _nonEmptyString(schedule, 'startDate', r'$.schedule');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(startDate) ||
        DateTime.tryParse(startDate) == null) {
      _fail(
        'INVALID_DATE_TIME',
        r'$.schedule.startDate',
        'configuration.invalidStartDate',
      );
    }
    final sessionOrder = _stableIdList(
      schedule['sessionOrder'],
      r'$.schedule.sessionOrder',
    );
    final trainingDays = schedule['trainingDays'] == null
        ? null
        : _trainingDays(schedule['trainingDays']);

    final equipment = _object(source['equipment'], r'$.equipment');
    _keys(
      equipment,
      const {'unit', 'barProfileId', 'bar'},
      r'$.equipment',
      optional: const {'barProfileId', 'bar'},
    );
    final unit = _enum(equipment, 'unit', const {'kg', 'lb'}, r'$.equipment');
    final hasProfile = equipment['barProfileId'] != null;
    final hasBar = equipment['bar'] != null;
    if (hasProfile == hasBar) {
      _fail(
        'EQUIPMENT_PROFILE_XOR_REQUIRED',
        r'$.equipment',
        'configuration.equipmentProfileXorRequired',
      );
    }
    if (hasProfile) {
      _stableId(equipment, 'barProfileId', r'$.equipment');
      _fail(
        'BAR_PROFILE_RESOLUTION_REQUIRED',
        r'$.equipment.barProfileId',
        'configuration.barProfileResolutionRequired',
      );
    }
    final bar = _bar(equipment['bar'], unit);

    final output = _object(source['output'], r'$.output');
    _keys(output, const {'title', 'showPlating'}, r'$.output');
    final title = _string(output, 'title', r'$.output');
    final showPlating = _boolean(output, 'showPlating', r'$.output');
    final date = startDate.substring(0, 10);

    return {
      'apiVersion': 'v1',
      'schemaVersion': 1,
      'cycleId': 'cycle-$templateId-$variantId-$date',
      'templateId': templateId,
      'variantId': variantId,
      'scheduleId': scheduleId,
      'startDate': startDate,
      'trainingDays': ?trainingDays,
      'sessionOrder': sessionOrder,
      'maxInputs': maxInputs,
      'globalTrainingMaxRatioBasisPoints': ratio,
      'trainingMaxRatioByMovement': ?ratiosByMovement,
      'options': {...templateOptions, ...commonOptions},
      'unit': unit,
      'barProfile': bar,
      'includeDeload': commonOptions['deload']!['enabled'],
      'programTitle': title,
      'showPlating': showPlating,
    };
  }
}

final class CycleConfigurationFormatException extends FormatException {
  CycleConfigurationFormatException({
    required this.code,
    required this.path,
    required this.messageKey,
    this.details = const {},
  }) : super('$code:$path');

  final String code;
  final String path;
  final String messageKey;
  final Map<String, Object?> details;

  Map<String, Object?> toIssue() => {
    'code': code,
    'path': path,
    'messageKey': messageKey,
    'details': details,
    'severity': 'error',
  };
}

Never _fail(
  String code,
  String path,
  String messageKey, {
  Map<String, Object?> details = const {},
}) => throw CycleConfigurationFormatException(
  code: code,
  path: path,
  messageKey: messageKey,
  details: details,
);

Map<String, Object?> _warmUp(Object? raw) {
  final value = _object(raw, r'$.commonOptions.warmUp');
  final enabled = _boolean(value, 'enabled', r'$.commonOptions.warmUp');
  if (!enabled) {
    _keys(value, const {'enabled'}, r'$.commonOptions.warmUp');
    return {'enabled': false};
  }
  final type = _enum(value, 'type', const {
    'original',
    'beyond',
  }, r'$.commonOptions.warmUp');
  if (type == 'original') {
    _keys(value, const {'enabled', 'type'}, r'$.commonOptions.warmUp');
    return {'enabled': true, 'type': type};
  }
  _keys(value, const {'enabled', 'type', 'bases'}, r'$.commonOptions.warmUp');
  final bases = _object(value['bases'], r'$.commonOptions.warmUp.bases');
  _keys(bases, const {
    'lowerBody',
    'upperBody',
  }, r'$.commonOptions.warmUp.bases');
  return {
    'enabled': true,
    'type': type,
    'bases': {
      'lowerBody': _weight(
        bases['lowerBody'],
        r'$.commonOptions.warmUp.bases.lowerBody',
      ),
      'upperBody': _weight(
        bases['upperBody'],
        r'$.commonOptions.warmUp.bases.upperBody',
      ),
    },
  };
}

Map<String, Object?> _joker(Object? raw) {
  final value = _object(raw, r'$.commonOptions.joker');
  final enabled = _boolean(value, 'enabled', r'$.commonOptions.joker');
  if (!enabled) {
    _keys(value, const {'enabled'}, r'$.commonOptions.joker');
    return {'enabled': false};
  }
  _keys(value, const {
    'enabled',
    'ceilingBasisPoints',
  }, r'$.commonOptions.joker');
  final ceiling = _integer(
    value,
    'ceilingBasisPoints',
    r'$.commonOptions.joker',
  );
  if (!const {500, 1000, 1500, 2000, 2500, 3000}.contains(ceiling)) {
    _fail(
      'INVALID_JOKER_CEILING',
      r'$.commonOptions.joker.ceilingBasisPoints',
      'configuration.invalidJokerCeiling',
    );
  }
  return {'enabled': true, 'ceilingBasisPoints': ceiling};
}

Map<String, Object?> _deload(Object? raw) {
  final value = _object(raw, r'$.commonOptions.deload');
  final enabled = _boolean(value, 'enabled', r'$.commonOptions.deload');
  if (!enabled) {
    _keys(value, const {'enabled'}, r'$.commonOptions.deload');
    return {'enabled': false};
  }
  final type = _enum(value, 'type', const {
    'deload1',
    'deload2',
    'deload3',
    'deload4',
    'deload5',
    'highIntensity',
  }, r'$.commonOptions.deload');
  if (type == 'highIntensity') {
    _keys(value, const {'enabled', 'type'}, r'$.commonOptions.deload');
    return {'enabled': true, 'type': type};
  }
  _keys(value, const {
    'enabled',
    'type',
    'skipWarmUp',
  }, r'$.commonOptions.deload');
  return {
    'enabled': true,
    'type': type,
    'skipWarmUp': _boolean(value, 'skipWarmUp', r'$.commonOptions.deload'),
  };
}

Map<String, Object?> _bar(Object? raw, String unit) {
  final value = _object(raw, r'$.equipment.bar');
  _keys(value, const {'weight', 'platesPerSide'}, r'$.equipment.bar');
  final weight = _weight(value['weight'], r'$.equipment.bar.weight');
  final platesRaw = value['platesPerSide'];
  if (platesRaw is! List<Object?>) {
    _type(r'$.equipment.bar.platesPerSide', 'array');
  }
  final plates = [
    for (var index = 0; index < platesRaw.length; index++)
      _weight(platesRaw[index], r'$.equipment.bar.platesPerSide[$index]'),
  ];
  if (weight['unit'] != unit || plates.any((plate) => plate['unit'] != unit)) {
    _fail(
      'EQUIPMENT_UNIT_MISMATCH',
      r'$.equipment.bar',
      'configuration.equipmentUnitMismatch',
    );
  }
  if (plates.isEmpty) {
    _fail(
      'PLATES_REQUIRED',
      r'$.equipment.bar.platesPerSide',
      'configuration.platesRequired',
    );
  }
  return {'weight': weight, 'platesPerSide': plates};
}

Map<String, Object?> _weight(Object? raw, String path) {
  final value = _object(raw, path);
  _keys(value, const {'centiUnits', 'unit'}, path);
  final amount = _integer(value, 'centiUnits', path);
  if (amount < 0) {
    _fail(
      'VALUE_OUT_OF_RANGE',
      '$path.centiUnits',
      'configuration.invalidWeight',
    );
  }
  return {
    'centiUnits': amount,
    'unit': _enum(value, 'unit', const {'kg', 'lb'}, path),
  };
}

Map<String, Object?> _basisPointMap(Object? raw, String path) {
  final value = _object(raw, path);
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    _checkStableId(entry.key, '$path.${entry.key}');
    result[entry.key] = _basisPoints(entry.value, '$path.${entry.key}');
  }
  return result;
}

int _basisPoints(Object? value, String path) {
  if (value is! int) _type(path, 'integer');
  if (value < 0 || value > 20000) {
    _fail('VALUE_OUT_OF_RANGE', path, 'configuration.invalidBasisPoints');
  }
  return value;
}

List<int> _trainingDays(Object? raw) {
  if (raw is! List<Object?>) _type(r'$.schedule.trainingDays', 'array');
  if (raw.isEmpty ||
      raw.any((value) => value is! int || value < 1 || value > 7) ||
      raw.toSet().length != raw.length) {
    _fail(
      'INVALID_TRAINING_DAYS',
      r'$.schedule.trainingDays',
      'configuration.invalidTrainingDays',
    );
  }
  return raw.cast<int>();
}

List<String> _stableIdList(Object? raw, String path) {
  if (raw is! List<Object?>) _type(path, 'array');
  if (raw.isEmpty) _fail('MIN_ITEMS', path, 'configuration.itemsRequired');
  return [
    for (var index = 0; index < raw.length; index++)
      raw[index] is String
          ? _checkedStableId(raw[index]! as String, '$path[$index]')
          : _type('$path[$index]', 'string'),
  ];
}

Map<String, Object?> _jsonObject(Object? raw, String path) {
  final value = _object(raw, path);
  try {
    return (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();
  } on JsonUnsupportedObjectError {
    return _type(path, 'JSON object');
  }
}

Map<String, Object?> _object(Object? value, String path) =>
    value is Map<String, Object?> ? value : _type(path, 'object');

String _stableId(Map<String, Object?> value, String key, String path) =>
    _checkedStableId(_nonEmptyString(value, key, path), '$path.$key');

String _checkedStableId(String value, String path) {
  _checkStableId(value, path);
  return value;
}

void _checkStableId(String value, String path) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]*$').hasMatch(value)) {
    _fail('INVALID_STABLE_ID', path, 'configuration.invalidStableId');
  }
}

String _nonEmptyString(Map<String, Object?> value, String key, String path) {
  final result = _string(value, key, path);
  if (result.isEmpty) {
    _fail('MIN_LENGTH', '$path.$key', 'configuration.emptyString');
  }
  return result;
}

String _string(Map<String, Object?> value, String key, String path) =>
    value[key] is String
    ? value[key]! as String
    : _type('$path.$key', 'string');

int _integer(Map<String, Object?> value, String key, String path) =>
    value[key] is int ? value[key]! as int : _type('$path.$key', 'integer');

bool _boolean(Map<String, Object?> value, String key, String path) =>
    value[key] is bool ? value[key]! as bool : _type('$path.$key', 'boolean');

String _enum(
  Map<String, Object?> value,
  String key,
  Set<String> allowed,
  String path,
) {
  final result = _string(value, key, path);
  if (!allowed.contains(result)) {
    _fail(
      'INVALID_ENUM_VALUE',
      '$path.$key',
      'configuration.invalidEnumValue',
      details: {'allowed': allowed.toList(), 'actual': result},
    );
  }
  return result;
}

void _keys(
  Map<String, Object?> value,
  Set<String> allowed,
  String path, {
  Set<String> optional = const {},
}) {
  final unknown = value.keys.toSet().difference(allowed);
  if (unknown.isNotEmpty) {
    final key = unknown.first;
    _fail('UNKNOWN_KEY', '$path.$key', 'configuration.unknownKey');
  }
  final required = allowed.difference(optional);
  final missing = required.difference(value.keys.toSet());
  if (missing.isNotEmpty) {
    final key = missing.first;
    _fail(
      'REQUIRED_KEY_MISSING',
      '$path.$key',
      'configuration.requiredKeyMissing',
    );
  }
}

Never _type(String path, String expected) => _fail(
  'INVALID_TYPE',
  path,
  'configuration.invalidType',
  details: {'expected': expected},
);
