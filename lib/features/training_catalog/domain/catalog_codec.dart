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
    _keys(value, const {
      'schemaVersion',
      'catalogVersion',
      'status',
      'sourceReference',
      'movements',
      'templates',
    });
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
    final templates = _list(value, 'templates')
        .map((item) {
          final map = _map(item, 'template');
          _keys(map, const {'id', 'name', 'variants'});
          return CatalogTemplate(
            id: _string(map, 'id'),
            name: _string(map, 'name'),
            variants: _list(
              map,
              'variants',
            ).map(_variant).toList(growable: false),
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
    );
  }

  CatalogVariant _variant(Object? item) {
    final map = _map(item, 'variant');
    _keys(map, const {'id', 'name', 'schedule', 'weeks'});
    final schedule = _map(map['schedule'], 'schedule');
    _keys(schedule, const {'type', 'movementIds'});
    if (_string(schedule, 'type') != 'ordered_sessions') {
      throw CatalogFormatException('Unknown schedule type ${schedule['type']}');
    }
    return CatalogVariant(
      id: _string(map, 'id'),
      name: _string(map, 'name'),
      sessionMovementIds: _list(schedule, 'movementIds')
          .map(
            (id) => id is String
                ? id
                : throw const CatalogFormatException(
                    'Movement id must be a string',
                  ),
          )
          .toList(growable: false),
      weeks: _list(map, 'weeks').map(_week).toList(growable: false),
    );
  }

  WeekDefinition _week(Object? item) {
    final map = _map(item, 'week');
    _keys(map, const {'number', 'blocks'});
    return WeekDefinition(
      number: _int(map, 'number'),
      blocks: _list(map, 'blocks').map(_block).toList(growable: false),
    );
  }

  BlockDefinition _block(Object? item) {
    final map = _map(item, 'block');
    _keys(map, const {'id', 'role', 'sets'});
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
  static void _keys(Map<String, Object?> map, Set<String> allowed) {
    final unknown = map.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw CatalogFormatException('Unknown key ${unknown.first}');
    }
    final missing = allowed.where((key) => !map.containsKey(key));
    // minimum is the sole optional field in the closed vocabulary.
    final requiredMissing = missing.where((key) => key != 'minimum');
    if (requiredMissing.isNotEmpty) {
      throw CatalogFormatException('Missing key ${requiredMissing.first}');
    }
  }
}
