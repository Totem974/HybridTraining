import 'dart:convert';

import '../../cycle_generation/domain/catalog_cycle_primitives.dart';
import '../../cycle_generation/domain/cycle_contract.dart';

final class SourceComponent {
  const SourceComponent({
    required this.reference,
    required this.block,
    required this.constraints,
    required this.compatibilities,
  });
  final ComponentReference reference;
  final BlockDefinition block;
  final Map<String, Object?> constraints;
  final Map<String, Object?> compatibilities;
}

final class SourceSchedule {
  const SourceSchedule({required this.reference, required this.sessions});
  final ComponentReference reference;
  final List<SourceSession> sessions;
}

final class SourceSession {
  const SourceSession({required this.id, required this.movementIds});
  final String id;
  final List<String> movementIds;
}

final class SourceVariant {
  const SourceVariant({
    required this.id,
    required this.revision,
    required this.scheduleIds,
    required this.weekPlans,
    required this.phases,
    required this.compatibilities,
  });
  final String id;
  final int revision;
  final List<ComponentReference> scheduleIds;
  final List<CatalogWeekPlan> weekPlans;
  final List<CatalogPhase> phases;
  final Map<String, Object?> compatibilities;
}

final class SourceTemplate {
  const SourceTemplate({
    required this.id,
    required this.revision,
    required this.variants,
  });
  final String id;
  final int revision;
  final List<SourceVariant> variants;
}

final class CatalogSourceDocumentCodec {
  const CatalogSourceDocumentCodec();

  List<SourceComponent> decodeComponents(String source) {
    final root = _root(source, 'components');
    return _list(root, 'components')
        .map((value) {
          final map = _map(value, 'component');
          _keys(map, const {
            'id',
            'revision',
            'role',
            'labels',
            'sourceRuleIds',
            'parameterSchemaIds',
            'constraints',
            'compatibilities',
            'block',
          });
          return SourceComponent(
            reference: _recordReference(map),
            block: _block(_map(map['block'], 'block')),
            constraints: _map(map['constraints'], 'constraints'),
            compatibilities: _map(map['compatibilities'], 'compatibilities'),
          );
        })
        .toList(growable: false);
  }

  List<SourceSchedule> decodeSchedules(String source) {
    final root = _root(source, 'schedules');
    return _list(root, 'schedules')
        .map((value) {
          final map = _map(value, 'schedule');
          _keys(map, const {
            'id',
            'revision',
            'labels',
            'sourceRuleIds',
            'type',
            'sessions',
          });
          return SourceSchedule(
            reference: _recordReference(map),
            sessions: _list(map, 'sessions')
                .map((value) {
                  final session = _map(value, 'session');
                  _keys(session, const {'id', 'role', 'movementIds'});
                  return SourceSession(
                    id: _string(session, 'id'),
                    movementIds: _strings(session, 'movementIds'),
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  List<SourceTemplate> decodeTemplates(String source) {
    final root = _root(source, 'templates');
    return _list(root, 'templates')
        .map((value) {
          final map = _map(value, 'template');
          _keys(map, const {
            'id',
            'revision',
            'labels',
            'sourceRuleIds',
            'variants',
          });
          return SourceTemplate(
            id: _string(map, 'id'),
            revision: _int(map, 'revision'),
            variants: _list(
              map,
              'variants',
            ).map(_variant).toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  List<Map<String, Object?>> decodeOptionSchemas(String source) {
    final root = _root(source, 'optionSchemas');
    return _list(root, 'optionSchemas')
        .map((value) {
          final map = _map(value, 'optionSchema');
          _keys(map, const {'id', 'revision', 'sourceRuleIds', 'parameters'});
          for (final value in _list(map, 'parameters')) {
            _keys(_map(value, 'parameter'), const {
              'id',
              'type',
              'scope',
              'default',
              'minimum',
              'maximum',
              'step',
              'allowedValues',
              'visibleWhen',
              'enabledWhen',
              'requiredWhen',
            });
          }
          return map;
        })
        .toList(growable: false);
  }

  SourceVariant _variant(Object? value) {
    final map = _map(value, 'variant');
    _keys(
      map,
      const {
        'id',
        'revision',
        'labels',
        'sourceRuleIds',
        'optionSchemaId',
        'scheduleIds',
        'compatibilities',
        'validExample',
        'weekPlans',
        'phases',
        'assistancePlanIds',
        'conditioningDefinitionIds',
      },
      optional: const {
        'weekPlans',
        'phases',
        'assistancePlanIds',
        'conditioningDefinitionIds',
      },
    );
    if (map.containsKey('weekPlans') == map.containsKey('phases'))
      throw const FormatException(
        'Variant requires exactly one of weekPlans or phases.',
      );
    return SourceVariant(
      id: _string(map, 'id'),
      revision: _int(map, 'revision'),
      scheduleIds: _list(map, 'scheduleIds')
          .map((value) => _reference(_map(value, 'reference')))
          .toList(growable: false),
      weekPlans: map['weekPlans'] == null
          ? const []
          : _weekPlans(_list(map, 'weekPlans')),
      phases: map['phases'] == null
          ? const []
          : _list(map, 'phases')
                .map((value) {
                  final phase = _map(value, 'phase');
                  _keys(phase, const {'id', 'repeatCount', 'weekPlans'});
                  return CatalogPhase(
                    id: _string(phase, 'id'),
                    repeatCount: _int(phase, 'repeatCount'),
                    weekPlans: _weekPlans(_list(phase, 'weekPlans')),
                  );
                })
                .toList(growable: false),
      compatibilities: _map(map['compatibilities'], 'compatibilities'),
    );
  }

  List<CatalogWeekPlan> _weekPlans(List<Object?> values) => values
      .map((value) {
        final map = _map(value, 'weekPlan');
        _keys(map, const {'weekNumber', 'componentIds'});
        return CatalogWeekPlan(
          weekNumber: _int(map, 'weekNumber'),
          components: _list(map, 'componentIds')
              .map((value) => _reference(_map(value, 'reference')))
              .toList(growable: false),
        );
      })
      .toList(growable: false);

  BlockDefinition _block(Map<String, Object?> map) {
    _keys(
      map,
      const {'id', 'role', 'sets', 'movementId'},
      optional: const {'movementId'},
    );
    return BlockDefinition(
      id: _string(map, 'id'),
      role: _string(map, 'role'),
      movementId: map['movementId'] == null
          ? null
          : MovementId(_string(map, 'movementId')),
      sets: _list(map, 'sets')
          .map((value) {
            final set = _map(value, 'set');
            _keys(set, const {'repetitions', 'load'});
            final reps = _map(set['repetitions'], 'repetitions');
            final load = _map(set['load'], 'load');
            return PrescribedSetDefinition(
              repetitions: _repetitions(reps),
              load: _load(load),
            );
          })
          .toList(growable: false),
    );
  }

  RepetitionPrescription _repetitions(Map<String, Object?> map) {
    switch (_string(map, 'type')) {
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
        _keys(map, const {'type', 'minimum'}, optional: const {'minimum'});
        return AmrapRepetitions(
          minimum: map['minimum'] == null ? null : _int(map, 'minimum'),
        );
      default:
        throw FormatException("Unknown repetition type ${map['type']}.");
    }
  }

  LoadPrescription _load(Map<String, Object?> map) {
    switch (_string(map, 'type')) {
      case 'training_max_percentage':
        _keys(map, const {'type', 'basisPoints'});
        return TrainingMaxPercentageLoad(Percentage(_int(map, 'basisPoints')));
      case 'one_rep_max_percentage':
        _keys(map, const {'type', 'basisPoints'});
        return OneRepMaxPercentageLoad(Percentage(_int(map, 'basisPoints')));
      case 'bodyweight':
        _keys(map, const {'type'});
        return const BodyweightLoad();
      case 'unloaded':
        _keys(map, const {'type'});
        return const Unloaded();
      case 'relative_set':
        _keys(map, const {'type', 'position', 'multiplierBasisPoints'});
        return RelativeSetLoad(
          position: RelativeSetPosition.values.byName(_string(map, 'position')),
          multiplierBasisPoints: _int(map, 'multiplierBasisPoints'),
        );
      default:
        throw FormatException("Unknown load type ${map['type']}.");
    }
  }

  Map<String, Object?> _root(String source, String kind) {
    final root = _map(jsonDecode(source), 'root');
    _keys(root, {'schemaVersion', 'kind', kind});
    if (_int(root, 'schemaVersion') != 1 || _string(root, 'kind') != kind)
      throw FormatException('Expected schemaVersion 1 $kind document.');
    return root;
  }

  ComponentReference _reference(Map<String, Object?> map) {
    _keys(map, const {'id', 'revision'});
    return ComponentReference(_string(map, 'id'), _int(map, 'revision'));
  }

  ComponentReference _recordReference(Map<String, Object?> map) =>
      ComponentReference(_string(map, 'id'), _int(map, 'revision'));

  static Map<String, Object?> _map(Object? value, String label) =>
      value is Map<String, Object?>
      ? value
      : throw FormatException('$label must be an object.');
  static List<Object?> _list(Map<String, Object?> map, String key) =>
      map[key] is List<Object?>
      ? map[key]! as List<Object?>
      : throw FormatException('$key must be a list.');
  static String _string(Map<String, Object?> map, String key) =>
      map[key] is String
      ? map[key]! as String
      : throw FormatException('$key must be a string.');
  static int _int(Map<String, Object?> map, String key) => map[key] is int
      ? map[key]! as int
      : throw FormatException('$key must be an integer.');
  static List<String> _strings(Map<String, Object?> map, String key) =>
      _list(map, key)
          .map(
            (value) => value is String
                ? value
                : throw FormatException('$key values must be strings.'),
          )
          .toList();
  static void _keys(
    Map<String, Object?> map,
    Set<String> allowed, {
    Set<String> optional = const {},
  }) {
    final unknown = map.keys.toSet().difference(allowed);
    if (unknown.isNotEmpty)
      throw FormatException('Unknown key ${unknown.first}.');
    final missing = allowed.difference(map.keys.toSet()).difference(optional);
    if (missing.isNotEmpty)
      throw FormatException('Missing key ${missing.first}.');
  }
}
