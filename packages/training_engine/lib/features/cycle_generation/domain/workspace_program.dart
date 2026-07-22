import 'dart:convert';

import 'cycle_contract.dart';

final class WorkspaceProgramFormatException implements Exception {
  const WorkspaceProgramFormatException(this.message);
  final String message;
  @override
  String toString() => 'WorkspaceProgramFormatException: $message';
}

final class WorkspaceProgram {
  const WorkspaceProgram({
    required this.id,
    required this.profileId,
    required this.name,
    required this.revision,
    required this.catalogVersion,
    required this.weeks,
  });

  final String id;
  final String profileId;
  final String name;
  final int revision;
  final int catalogVersion;
  final List<WeekDefinition> weeks;

  Set<MovementId> get catalogMovementReferences => {
    for (final week in weeks)
      for (final session in week.sessions)
        for (final block in session.blocks) ?block.movementId,
  };
}

final class WorkspaceProgramCodec {
  const WorkspaceProgramCodec();

  String encode(WorkspaceProgram program) => jsonEncode({
    'schemaVersion': 1,
    'authority': 'userDefined',
    'origin': 'userDefined',
    'weeks': program.weeks.map(_weekJson).toList(),
  });

  List<WeekDefinition> decodeDefinition(String source) {
    final root = _map(jsonDecode(source), 'root');
    _keys(root, const {'schemaVersion', 'authority', 'origin', 'weeks'});
    if (_integer(root, 'schemaVersion') != 1) {
      throw const WorkspaceProgramFormatException(
        'Unsupported workspace program schema',
      );
    }
    if (_string(root, 'authority') != 'userDefined' ||
        _string(root, 'origin') != 'userDefined') {
      throw const WorkspaceProgramFormatException(
        'Workspace programs must be userDefined',
      );
    }
    final weeks = _list(root, 'weeks').map(_week).toList(growable: false);
    if (weeks.isEmpty) {
      throw const WorkspaceProgramFormatException('weeks cannot be empty');
    }
    return weeks;
  }

  static Map<String, Object> _weekJson(WeekDefinition week) => {
    'number': week.number,
    'sessions': week.sessions.map(_sessionJson).toList(),
  };

  static Map<String, Object> _sessionJson(SessionDefinition session) => {
    'id': session.id.value,
    'role': session.role,
    'blocks': session.blocks.map(_blockJson).toList(),
  };

  static Map<String, Object?> _blockJson(BlockDefinition block) => {
    'id': block.id,
    'role': block.role,
    'movementReference': block.movementId == null
        ? null
        : {'movementId': block.movementId!.value},
    'sets': block.sets.map(_setJson).toList(),
  };

  static Map<String, Object> _setJson(PrescribedSetDefinition set) => {
    'repetitions': set.repetitions.toJson(),
    'load': _loadJson(set.load),
  };

  static Map<String, Object> _loadJson(LoadPrescription load) => switch (load) {
    TrainingMaxPercentageLoad(:final percentage) => {
      'type': 'training_max_percentage',
      'basisPoints': percentage.basisPoints,
    },
    ParameterizedTrainingMaxPercentageLoad(
      :final parameterId,
      :final defaultValue,
      :final minimum,
      :final maximum,
    ) =>
      {
        'type': 'parameterized_training_max_percentage',
        'parameterId': parameterId,
        'defaultBasisPoints': defaultValue.basisPoints,
        'minimumBasisPoints': minimum.basisPoints,
        'maximumBasisPoints': maximum.basisPoints,
      },
    OneRepMaxPercentageLoad(:final percentage) => {
      'type': 'one_rep_max_percentage',
      'basisPoints': percentage.basisPoints,
    },
    FixedLoad(:final weight) => {
      'type': 'fixed',
      'centiUnits': weight.centiUnits,
      'unit': weight.unit.name,
    },
    BodyweightLoad() => {'type': 'bodyweight'},
    Unloaded() => {'type': 'unloaded'},
    RelativeSetLoad(:final position, :final multiplierBasisPoints) => {
      'type': 'relative_set',
      'position': position.name,
      'multiplierBasisPoints': multiplierBasisPoints,
    },
    MainWorkSetPlusLoad() ||
    WarmUpBaseLoad() ||
    TrainingMaxRampLoad() => throw const WorkspaceProgramFormatException(
      'Resolved option loads cannot be stored in user-defined programs',
    ),
  };

  WeekDefinition _week(Object? value) {
    final map = _map(value, 'week');
    _keys(map, const {'number', 'sessions'});
    final sessions = _list(
      map,
      'sessions',
    ).map(_session).toList(growable: false);
    if (sessions.isEmpty) {
      throw const WorkspaceProgramFormatException(
        'A week must contain sessions',
      );
    }
    return WeekDefinition(number: _integer(map, 'number'), sessions: sessions);
  }

  SessionDefinition _session(Object? value) {
    final map = _map(value, 'session');
    _keys(map, const {'id', 'role', 'blocks'});
    final blocks = _list(map, 'blocks').map(_block).toList(growable: false);
    if (blocks.isEmpty) {
      throw const WorkspaceProgramFormatException(
        'A session must contain blocks',
      );
    }
    return SessionDefinition(
      id: MovementId(_nonEmpty(map, 'id')),
      role: _nonEmpty(map, 'role'),
      blocks: blocks,
    );
  }

  BlockDefinition _block(Object? value) {
    final map = _map(value, 'block');
    _keys(map, const {'id', 'role', 'movementReference', 'sets'});
    final reference = map['movementReference'];
    MovementId? movement;
    if (reference != null) {
      final referenceMap = _map(reference, 'movementReference');
      _keys(referenceMap, const {'movementId'});
      movement = MovementId(_nonEmpty(referenceMap, 'movementId'));
    }
    final sets = _list(map, 'sets').map(_set).toList(growable: false);
    if (sets.isEmpty) {
      throw const WorkspaceProgramFormatException('A block must contain sets');
    }
    return BlockDefinition(
      id: _nonEmpty(map, 'id'),
      role: _nonEmpty(map, 'role'),
      movementId: movement,
      sets: sets,
    );
  }

  PrescribedSetDefinition _set(Object? value) {
    final map = _map(value, 'set');
    _keys(map, const {'repetitions', 'load'});
    return PrescribedSetDefinition(
      repetitions: _repetitions(_map(map['repetitions'], 'repetitions')),
      load: _load(_map(map['load'], 'load')),
    );
  }

  RepetitionPrescription _repetitions(Map<String, Object?> map) {
    switch (_string(map, 'type')) {
      case 'fixed':
        _keys(map, const {'type', 'count'});
        return FixedRepetitions(_integer(map, 'count'));
      case 'range':
        _keys(map, const {'type', 'minimum', 'maximum'});
        return RepetitionRange(
          _integer(map, 'minimum'),
          _integer(map, 'maximum'),
        );
      case 'total':
        _keys(map, const {'type', 'total'});
        return TotalRepetitions(_integer(map, 'total'));
      case 'amrap':
        _keys(map, const {'type', 'minimum'}, optional: const {'minimum'});
        return AmrapRepetitions(
          minimum: map['minimum'] == null ? null : _integer(map, 'minimum'),
        );
      default:
        throw WorkspaceProgramFormatException(
          'Unknown repetition type ${map['type']}',
        );
    }
  }

  LoadPrescription _load(Map<String, Object?> map) {
    switch (_string(map, 'type')) {
      case 'training_max_percentage':
        _keys(map, const {'type', 'basisPoints'});
        return TrainingMaxPercentageLoad(
          Percentage(_integer(map, 'basisPoints')),
        );
      case 'parameterized_training_max_percentage':
        _keys(map, const {
          'type',
          'parameterId',
          'defaultBasisPoints',
          'minimumBasisPoints',
          'maximumBasisPoints',
        });
        final minimum = _integer(map, 'minimumBasisPoints');
        final maximum = _integer(map, 'maximumBasisPoints');
        final defaultValue = _integer(map, 'defaultBasisPoints');
        if (minimum > maximum ||
            defaultValue < minimum ||
            defaultValue > maximum) {
          throw const WorkspaceProgramFormatException(
            'Invalid parameterized percentage bounds',
          );
        }
        return ParameterizedTrainingMaxPercentageLoad(
          parameterId: _nonEmpty(map, 'parameterId'),
          defaultValue: Percentage(defaultValue),
          minimum: Percentage(minimum),
          maximum: Percentage(maximum),
        );
      case 'one_rep_max_percentage':
        _keys(map, const {'type', 'basisPoints'});
        return OneRepMaxPercentageLoad(
          Percentage(_integer(map, 'basisPoints')),
        );
      case 'relative_set':
        _keys(map, const {'type', 'position', 'multiplierBasisPoints'});
        final position = _string(map, 'position');
        if (!RelativeSetPosition.values.any(
          (value) => value.name == position,
        )) {
          throw WorkspaceProgramFormatException(
            'Unknown relative set position $position',
          );
        }
        return RelativeSetLoad(
          position: RelativeSetPosition.values.byName(position),
          multiplierBasisPoints: _integer(map, 'multiplierBasisPoints'),
        );
      case 'fixed':
        _keys(map, const {'type', 'centiUnits', 'unit'});
        final unitName = _string(map, 'unit');
        WeightUnit unit;
        try {
          unit = WeightUnit.values.byName(unitName);
        } on ArgumentError {
          throw WorkspaceProgramFormatException('Unknown unit $unitName');
        }
        return FixedLoad(Weight(_integer(map, 'centiUnits'), unit));
      case 'bodyweight':
        _keys(map, const {'type'});
        return const BodyweightLoad();
      case 'unloaded':
        _keys(map, const {'type'});
        return const Unloaded();
      default:
        throw WorkspaceProgramFormatException(
          'Unknown load type ${map['type']}',
        );
    }
  }

  static Map<String, Object?> _map(Object? value, String label) =>
      value is Map<String, Object?>
      ? value
      : throw WorkspaceProgramFormatException('$label must be an object');

  static List<Object?> _list(Map<String, Object?> map, String key) =>
      map[key] is List<Object?>
      ? map[key]! as List<Object?>
      : throw WorkspaceProgramFormatException('$key must be a list');

  static String _string(Map<String, Object?> map, String key) =>
      map[key] is String
      ? map[key]! as String
      : throw WorkspaceProgramFormatException('$key must be a string');

  static String _nonEmpty(Map<String, Object?> map, String key) {
    final value = _string(map, key);
    if (value.trim().isEmpty) {
      throw WorkspaceProgramFormatException('$key cannot be empty');
    }
    return value;
  }

  static int _integer(Map<String, Object?> map, String key) => map[key] is int
      ? map[key]! as int
      : throw WorkspaceProgramFormatException('$key must be an integer');

  static void _keys(
    Map<String, Object?> map,
    Set<String> allowed, {
    Set<String> optional = const {},
  }) {
    final unknown = map.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw WorkspaceProgramFormatException('Unknown key ${unknown.first}');
    }
    final missing = allowed.where(
      (key) => !optional.contains(key) && !map.containsKey(key),
    );
    if (missing.isNotEmpty) {
      throw WorkspaceProgramFormatException('Missing key ${missing.first}');
    }
  }
}
