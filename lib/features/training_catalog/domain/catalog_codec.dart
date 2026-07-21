import 'dart:convert';

import '../../cycle_generation/domain/cycle_contract.dart';
import 'catalog_models.dart';

final class CatalogCodec {
  const CatalogCodec();

  CatalogSeed decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?>) {
      throw const CatalogFormatException('Root must be an object');
    }
    _keys(
      value,
      const {
        'schemaVersion',
        'catalogVersion',
        'status',
        'sourceReference',
        'movements',
        'templates',
        'components',
        'schedules',
        'rules',
      },
      optional: const {'components', 'schedules', 'rules'},
    );
    final schema = _int(value, 'schemaVersion');
    if (schema != 1) {
      throw CatalogFormatException('Unsupported schemaVersion $schema');
    }
    final movements = _list(value, 'movements')
        .map((item) {
          final map = _map(item, 'movement');
          _keys(map, const {'id', 'name'});
          return CatalogMovement(
            id: _string(map, 'id'),
            name: _string(map, 'name'),
          );
        })
        .toList(growable: false);
    final components = value.containsKey('components')
        ? _list(value, 'components')
              .map((item) {
                final map = _map(item, 'component');
                _keys(
                  map,
                  const {'id', 'block', 'ruleIds'},
                  optional: const {'ruleIds'},
                );
                return CatalogComponent(
                  id: _string(map, 'id'),
                  block: _block(map['block']),
                  ruleIds: map['ruleIds'] == null
                      ? const []
                      : _stringList(map, 'ruleIds'),
                );
              })
              .toList(growable: false)
        : const <CatalogComponent>[];
    final schedules = value.containsKey('schedules')
        ? _list(value, 'schedules')
              .map((item) {
                final map = _map(item, 'schedule');
                _keys(map, const {'id', 'type', 'movementIds'});
                if (_string(map, 'type') != 'ordered_sessions') {
                  throw CatalogFormatException(
                    'Unknown schedule type ${map['type']}',
                  );
                }
                return CatalogSchedule(
                  id: _string(map, 'id'),
                  movementIds: _stringList(map, 'movementIds'),
                );
              })
              .toList(growable: false)
        : const <CatalogSchedule>[];
    final componentById = {for (final item in components) item.id: item};
    final scheduleById = {for (final item in schedules) item.id: item};
    final rules = value.containsKey('rules')
        ? _list(value, 'rules')
              .map((item) {
                final map = _map(item, 'rule');
                _keys(map, const {
                  'ruleId',
                  'work',
                  'edition',
                  'section',
                  'reviewStatus',
                });
                final status = _string(map, 'reviewStatus');
                if (!const {'reviewed', 'pending'}.contains(status)) {
                  throw CatalogFormatException('Unknown review status $status');
                }
                return CanonicalRuleReference(
                  ruleId: _string(map, 'ruleId'),
                  work: _string(map, 'work'),
                  edition: _string(map, 'edition'),
                  section: _string(map, 'section'),
                  reviewStatus: status,
                );
              })
              .toList(growable: false)
        : const <CanonicalRuleReference>[];
    final ruleIds = rules.map((rule) => rule.ruleId).toSet();
    for (final component in components) {
      final missing = component.ruleIds.where((id) => !ruleIds.contains(id));
      if (missing.isNotEmpty) {
        throw CatalogFormatException('Unknown rule reference ${missing.first}');
      }
    }
    final templates = _list(value, 'templates')
        .map((item) {
          final map = _map(item, 'template');
          _keys(map, const {'id', 'name', 'variants'});
          return CatalogTemplate(
            id: _string(map, 'id'),
            name: _string(map, 'name'),
            variants: _list(map, 'variants')
                .map((item) => _variant(item, componentById, scheduleById))
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    return CatalogSeed(
      schemaVersion: schema,
      catalogVersion: _int(value, 'catalogVersion'),
      status: _string(value, 'status'),
      sourceReference: _string(value, 'sourceReference'),
      movements: movements,
      templates: templates,
      components: components,
      schedules: schedules,
      rules: rules,
    );
  }

  CatalogVariant _variant(
    Object? item,
    Map<String, CatalogComponent> components,
    Map<String, CatalogSchedule> schedules,
  ) {
    final map = _map(item, 'variant');
    _keys(
      map,
      const {'id', 'name', 'schedule', 'scheduleId', 'weeks'},
      optional: const {'schedule', 'scheduleId'},
    );
    if (map.containsKey('schedule') == map.containsKey('scheduleId')) {
      throw const CatalogFormatException(
        'Variant requires exactly one schedule or scheduleId',
      );
    }
    final movementIds = map.containsKey('scheduleId')
        ? (schedules[_string(map, 'scheduleId')] ??
                  (throw CatalogFormatException(
                    'Unknown schedule reference ${map['scheduleId']}',
                  )))
              .movementIds
        : _inlineSchedule(map['schedule']);
    return CatalogVariant(
      id: _string(map, 'id'),
      name: _string(map, 'name'),
      sessionMovementIds: movementIds,
      weeks: _list(
        map,
        'weeks',
      ).map((item) => _week(item, components)).toList(growable: false),
      componentIdsByWeek: {
        for (final item in _list(map, 'weeks'))
          if ((_map(item, 'week')).containsKey('componentIds'))
            _int(_map(item, 'week'), 'number'): _stringList(
              _map(item, 'week'),
              'componentIds',
            ),
      },
    );
  }

  List<String> _inlineSchedule(Object? value) {
    final schedule = _map(value, 'schedule');
    _keys(schedule, const {'type', 'movementIds'});
    if (_string(schedule, 'type') != 'ordered_sessions') {
      throw CatalogFormatException('Unknown schedule type ${schedule['type']}');
    }
    return _stringList(schedule, 'movementIds');
  }

  WeekDefinition _week(Object? item, Map<String, CatalogComponent> components) {
    final map = _map(item, 'week');
    _keys(
      map,
      const {'number', 'blocks', 'componentIds'},
      optional: const {'blocks', 'componentIds'},
    );
    if (map.containsKey('blocks') == map.containsKey('componentIds')) {
      throw const CatalogFormatException(
        'Week requires exactly one blocks or componentIds',
      );
    }
    final blocks = map.containsKey('blocks')
        ? _list(map, 'blocks').map(_block).toList(growable: false)
        : _stringList(map, 'componentIds')
              .map(
                (id) =>
                    components[id]?.block ??
                    (throw CatalogFormatException(
                      'Unknown component reference $id',
                    )),
              )
              .toList(growable: false);
    return WeekDefinition(number: _int(map, 'number'), blocks: blocks);
  }

  BlockDefinition _block(Object? item) {
    final map = _map(item, 'block');
    _keys(
      map,
      const {'id', 'role', 'sets', 'movementId'},
      optional: const {'movementId'},
    );
    const roles = {
      'warm_up',
      'main_work',
      'supplemental',
      'assistance',
      'deload',
    };
    final role = _string(map, 'role');
    if (!roles.contains(role)) {
      throw CatalogFormatException('Unknown block role $role');
    }
    return BlockDefinition(
      id: _string(map, 'id'),
      role: role,
      sets: _list(map, 'sets').map(_set).toList(growable: false),
      movementId: map['movementId'] == null
          ? null
          : MovementId(_string(map, 'movementId')),
    );
  }

  PrescribedSetDefinition _set(Object? item) {
    final map = _map(item, 'set');
    _keys(map, const {'repetitions', 'load'});
    return PrescribedSetDefinition(
      repetitions: _repetitions(_map(map['repetitions'], 'repetitions')),
      load: _load(_map(map['load'], 'load')),
    );
  }

  RepetitionPrescription _repetitions(Map<String, Object?> map) {
    final type = _string(map, 'type');
    switch (type) {
      case 'fixed':
        _keys(map, const {'type', 'count'});
        return FixedRepetitions(_int(map, 'count'));
      case 'range':
        _keys(map, const {'type', 'minimum', 'maximum'});
        return RepetitionRange(_int(map, 'minimum'), _int(map, 'maximum'));
      case 'total':
        _keys(map, const {'type', 'total'});
        return TotalRepetitions(_int(map, 'total'));
      case 'amrap':
        _keys(map, const {'type', 'minimum'});
        return AmrapRepetitions(
          minimum: map['minimum'] == null ? null : _int(map, 'minimum'),
        );
      default:
        throw CatalogFormatException('Unknown repetition type $type');
    }
  }

  LoadPrescription _load(Map<String, Object?> map) {
    final type = _string(map, 'type');
    switch (type) {
      case 'training_max_percentage':
        _keys(map, const {'type', 'basisPoints'});
        return TrainingMaxPercentageLoad(Percentage(_int(map, 'basisPoints')));
      case 'parameterized_training_max_percentage':
        _keys(map, const {
          'type',
          'parameterId',
          'defaultBasisPoints',
          'minimumBasisPoints',
          'maximumBasisPoints',
        });
        final minimum = _int(map, 'minimumBasisPoints');
        final maximum = _int(map, 'maximumBasisPoints');
        final defaultValue = _int(map, 'defaultBasisPoints');
        if (minimum > maximum ||
            defaultValue < minimum ||
            defaultValue > maximum) {
          throw const CatalogFormatException(
            'Invalid parameterized percentage bounds',
          );
        }
        return ParameterizedTrainingMaxPercentageLoad(
          parameterId: _string(map, 'parameterId'),
          defaultValue: Percentage(defaultValue),
          minimum: Percentage(minimum),
          maximum: Percentage(maximum),
        );
      case 'one_rep_max_percentage':
        _keys(map, const {'type', 'basisPoints'});
        return OneRepMaxPercentageLoad(Percentage(_int(map, 'basisPoints')));
      case 'fixed':
        _keys(map, const {'type', 'centiUnits', 'unit'});
        final unit = _string(map, 'unit');
        return FixedLoad(
          Weight(_int(map, 'centiUnits'), WeightUnit.values.byName(unit)),
        );
      case 'bodyweight':
        _keys(map, const {'type'});
        return const BodyweightLoad();
      case 'unloaded':
        _keys(map, const {'type'});
        return const Unloaded();
      default:
        throw CatalogFormatException('Unknown load type $type');
    }
  }

  static Map<String, Object?> _map(Object? value, String label) =>
      value is Map<String, Object?>
      ? value
      : throw CatalogFormatException('$label must be an object');
  static List<Object?> _list(Map<String, Object?> map, String key) =>
      map[key] is List<Object?>
      ? map[key]! as List<Object?>
      : throw CatalogFormatException('$key must be a list');
  static String _string(Map<String, Object?> map, String key) =>
      map[key] is String
      ? map[key]! as String
      : throw CatalogFormatException('$key must be a string');
  static int _int(Map<String, Object?> map, String key) => map[key] is int
      ? map[key]! as int
      : throw CatalogFormatException('$key must be an integer');
  static List<String> _stringList(Map<String, Object?> map, String key) =>
      _list(map, key)
          .map(
            (value) => value is String
                ? value
                : throw CatalogFormatException('$key values must be strings'),
          )
          .toList(growable: false);
  static void _keys(
    Map<String, Object?> map,
    Set<String> allowed, {
    Set<String> optional = const {},
  }) {
    final unknown = map.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw CatalogFormatException('Unknown key ${unknown.first}');
    }
    final missing = allowed.where((key) => !map.containsKey(key));
    // minimum is the sole optional field in the closed vocabulary.
    final requiredMissing = missing.where(
      (key) => key != 'minimum' && !optional.contains(key),
    );
    if (requiredMissing.isNotEmpty) {
      throw CatalogFormatException('Missing key ${requiredMissing.first}');
    }
  }
}
