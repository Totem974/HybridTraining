import 'dart:convert';

/// Migrates saved pre-v1 option identifiers and returns the strict v1 shape.
///
/// This adapter is deliberately owned by the JSON boundary. The engine only
/// receives typed, canonical options.
Map<String, Object?> normalizeCycleRequest(
  Map<String, Object?> source, {
  Set<String> catalogOptionKeys = const {},
}) {
  final request = _clone(source);
  final rawOptions = request['options'];
  final options = rawOptions == null
      ? <String, Object?>{}
      : _object(rawOptions, 'options');

  _migrateWarmUp(options, request['unit'] as String?);
  _migrateJoker(options);
  _migrateDeload(options);
  _migrateFullBody(options);
  _cleanAndValidate(options, catalogOptionKeys);

  request['options'] = options;
  if (options['deload'] case final Map<String, Object?> deload) {
    request['includeDeload'] = deload['enabled'] as bool;
  } else {
    request['includeDeload'] = request['includeDeload'] as bool? ?? true;
  }
  return request;
}

void _migrateWarmUp(Map<String, Object?> options, String? unit) {
  if (options.containsKey('warmUp')) return;
  final legacy = options.remove('warmup');
  if (legacy == null) return;
  final type = _legacyIndex(legacy, 'warmup') == 1 ? 'beyond' : 'original';
  final warmUp = <String, Object?>{'enabled': true, 'type': type};
  if (type == 'beyond') {
    warmUp['bases'] = {
      'lowerBody': _legacyWeight(options.remove('lowerBase'), unit),
      'upperBody': _legacyWeight(options.remove('upperBase'), unit),
    };
  } else {
    options.remove('lowerBase');
    options.remove('upperBase');
  }
  options['warmUp'] = warmUp;
}

void _migrateJoker(Map<String, Object?> options) {
  if (options.containsKey('joker')) return;
  final legacy = options.remove('jokerMax');
  if (legacy == null) return;
  final index = _legacyIndex(legacy, 'jokerMax');
  options['joker'] = index == 0
      ? <String, Object?>{'enabled': false}
      : <String, Object?>{'enabled': true, 'ceilingBasisPoints': index * 500};
}

void _migrateDeload(Map<String, Object?> options) {
  if (options['deload'] is Map) return;
  final legacy = options.remove('deload');
  if (legacy != null) {
    final index = _legacyIndex(legacy, 'deload');
    if (index < 0) {
      options['deload'] = <String, Object?>{'enabled': false};
    } else {
      options['deload'] = <String, Object?>{
        'enabled': true,
        'type': index == 5 ? 'highIntensity' : 'deload${index + 1}',
        if (index < 5)
          'skipWarmUp': options.remove('deloadSkipWarmup') as bool? ?? false,
      };
    }
    options.remove('deloadSkipWarmup');
    return;
  }
}

void _migrateFullBody(Map<String, Object?> options) {
  if (!options.containsKey('fullBody') && options.containsKey('option')) {
    const profiles = ['original', 'updated', 'full_boring'];
    const liftProfiles = [
      '65x5_75x5_85x5',
      '70x3_80x3_90x3',
      '75x5_85x3_95x1',
      '80x1_90x1_100x1',
    ];
    const deadliftProfiles = [
      '65x3_75x3_85x3',
      '70x3_80x3_90x3',
      '75x5_85x3_95x1',
      '80x1_90x1_100x1',
    ];
    final profileIndex = _legacyIndex(options.remove('option'), 'option');
    if (profileIndex < 0 || profileIndex >= profiles.length) {
      throw const FormatException('UNKNOWN_FULL_BODY_PROFILE');
    }
    final profile = profiles[profileIndex];
    if (profile == 'original') {
      final phase = _legacyIndex(options.remove('phase') ?? 0, 'phase') + 1;
      options.remove('ratios');
      options['fullBody'] = {
        'profile': profile,
        'phase': const ['phase_one', 'phase_two', 'phase_three'][phase - 1],
      };
    } else {
      final ratios = options.remove('ratios');
      if (ratios is! List || ratios.length < 3) {
        throw const FormatException('FULL_BODY_RATIOS_REQUIRED');
      }
      String lift(int index, {bool deadlift = false}) {
        final value = _legacyIndex(ratios[index], 'ratios[$index]');
        if (value < 0 || value >= liftProfiles.length) {
          throw FormatException('UNKNOWN_FULL_BODY_LIFT_PROFILE:$value');
        }
        return (deadlift ? deadliftProfiles : liftProfiles)[value];
      }

      options.remove('phase');
      options['fullBody'] = {
        'profile': profile,
        'liftProfiles': profile == 'updated'
            ? {'squat': lift(1)}
            : {
                'bench': lift(0),
                'squat': lift(1),
                'deadlift': lift(2, deadlift: true),
              },
      };
    }
  }
}

void _cleanAndValidate(
  Map<String, Object?> options,
  Set<String> catalogOptionKeys,
) {
  final allowed = {
    'warmUp',
    'joker',
    'deload',
    'fullBody',
    ...catalogOptionKeys,
  };
  _rejectUnknown(options, allowed, 'options');

  if (options['warmUp'] case final Object value) {
    final warmUp = _object(value, 'options.warmUp');
    final enabled = _boolean(warmUp, 'enabled', 'options.warmUp');
    if (!enabled) {
      warmUp.removeWhere((key, _) => key != 'enabled');
    } else {
      final type = warmUp['type'];
      if (type != 'original' && type != 'beyond') {
        throw FormatException('UNKNOWN_WARM_UP_TYPE:$type');
      }
      if (type == 'original') {
        warmUp.remove('bases');
      } else {
        final bases = _object(warmUp['bases'], 'options.warmUp.bases');
        _rejectUnknown(bases, const {
          'lowerBody',
          'upperBody',
        }, 'options.warmUp.bases');
        _requireWeight(bases['lowerBody'], 'options.warmUp.bases.lowerBody');
        _requireWeight(bases['upperBody'], 'options.warmUp.bases.upperBody');
      }
      _rejectUnknown(warmUp, const {
        'enabled',
        'type',
        'bases',
      }, 'options.warmUp');
    }
  }

  if (options['joker'] case final Object value) {
    final joker = _object(value, 'options.joker');
    final enabled = _boolean(joker, 'enabled', 'options.joker');
    if (!enabled) joker.removeWhere((key, _) => key != 'enabled');
    if (enabled &&
        !const {
          500,
          1000,
          1500,
          2000,
          2500,
          3000,
        }.contains(joker['ceilingBasisPoints'])) {
      throw FormatException(
        'INVALID_JOKER_CEILING:${joker['ceilingBasisPoints']}',
      );
    }
    _rejectUnknown(joker, const {
      'enabled',
      'ceilingBasisPoints',
    }, 'options.joker');
  }

  if (options['deload'] case final Object value) {
    final deload = _object(value, 'options.deload');
    final enabled = _boolean(deload, 'enabled', 'options.deload');
    if (!enabled) {
      deload.removeWhere((key, _) => key != 'enabled');
    } else {
      const types = {
        'deload1',
        'deload2',
        'deload3',
        'deload4',
        'deload5',
        'highIntensity',
      };
      if (!types.contains(deload['type'])) {
        throw FormatException('UNKNOWN_DELOAD_TYPE:${deload['type']}');
      }
      if (deload['type'] == 'highIntensity') deload.remove('skipWarmUp');
      if (deload['type'] != 'highIntensity' && deload['skipWarmUp'] is! bool) {
        throw const FormatException('DELOAD_SKIP_WARM_UP_REQUIRED');
      }
      _rejectUnknown(deload, const {
        'enabled',
        'type',
        'skipWarmUp',
      }, 'options.deload');
    }
  }

  if (options['fullBody'] case final Object value) {
    final fullBody = _object(value, 'options.fullBody');
    final profile = fullBody['profile'];
    if (profile == 'original') {
      if (!const {
        'phase_one',
        'phase_two',
        'phase_three',
      }.contains(fullBody['phase'])) {
        throw FormatException('UNKNOWN_FULL_BODY_PHASE:${fullBody['phase']}');
      }
      fullBody.remove('liftProfiles');
      _rejectUnknown(fullBody, const {'profile', 'phase'}, 'options.fullBody');
    } else if (profile == 'updated' || profile == 'full_boring') {
      fullBody.remove('phase');
      final lifts = _object(
        fullBody['liftProfiles'],
        'options.fullBody.liftProfiles',
      );
      final required = profile == 'updated'
          ? const {'squat'}
          : const {'bench', 'squat', 'deadlift'};
      _rejectUnknown(lifts, required, 'options.fullBody.liftProfiles');
      if (!lifts.keys.toSet().containsAll(required)) {
        throw const FormatException('FULL_BODY_LIFT_PROFILES_REQUIRED');
      }
      const profiles = {
        '65x5_75x5_85x5',
        '70x3_80x3_90x3',
        '75x5_85x3_95x1',
        '80x1_90x1_100x1',
      };
      const deadliftProfiles = {
        '65x3_75x3_85x3',
        '70x3_80x3_90x3',
        '75x5_85x3_95x1',
        '80x1_90x1_100x1',
      };
      for (final entry in lifts.entries) {
        final allowed = entry.key == 'deadlift' ? deadliftProfiles : profiles;
        if (!allowed.contains(entry.value)) {
          throw FormatException(
            'UNKNOWN_FULL_BODY_LIFT_PROFILE:${entry.value}',
          );
        }
      }
      _rejectUnknown(fullBody, const {
        'profile',
        'liftProfiles',
      }, 'options.fullBody');
    } else {
      throw FormatException('UNKNOWN_FULL_BODY_PROFILE:$profile');
    }
  }
}

Map<String, Object?> _clone(Map<String, Object?> source) =>
    (jsonDecode(jsonEncode(source)) as Map).cast<String, Object?>();

Map<String, Object?> _object(Object? value, String path) => value is Map
    ? value.cast<String, Object?>()
    : throw FormatException('$path must be an object');

bool _boolean(Map<String, Object?> value, String key, String path) =>
    value[key] is bool
    ? value[key]! as bool
    : throw FormatException('$path.$key must be a boolean');

int _legacyIndex(Object? value, String path) => value is int
    ? value
    : value is num
    ? value.toInt()
    : throw FormatException('$path must be numeric');

Map<String, Object?> _legacyWeight(Object? value, String? unit) {
  final amount = value is num ? value : 0;
  return {'centiUnits': (amount * 100).round(), 'unit': unit ?? 'kg'};
}

void _requireWeight(Object? value, String path) {
  final weight = _object(value, path);
  _rejectUnknown(weight, const {'centiUnits', 'unit'}, path);
  if (weight['centiUnits'] is! int ||
      !const {'kg', 'lb'}.contains(weight['unit'])) {
    throw FormatException('$path must be a weight');
  }
}

void _rejectUnknown(
  Map<String, Object?> value,
  Set<String> allowed,
  String path,
) {
  final unknown = value.keys.toSet().difference(allowed);
  if (unknown.isNotEmpty) {
    throw FormatException('UNKNOWN_KEY:$path.${unknown.first}');
  }
}
