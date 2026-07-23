import 'dart:convert';

import '../domain/assistance_contract.dart';

final class AssistancePlanResolver {
  const AssistancePlanResolver();

  List<ResolvedAssistancePlan> decodeDocument(String source) {
    final root = _map(jsonDecode(source), 'root');
    _keys(root, const {'schemaVersion', 'kind', 'assistancePlans'}, 'root');
    if (root['schemaVersion'] != 1 || root['kind'] != 'assistancePlans') {
      throw const FormatException(
        'Assistance document must be schemaVersion 1 and kind assistancePlans.',
      );
    }
    return List.unmodifiable(
      _list(
        root,
        'assistancePlans',
      ).map((item) => resolve(_map(item, 'assistancePlan'))),
    );
  }

  ResolvedAssistancePlan resolve(Map<String, Object?> value) {
    _keys(value, const {
      'id',
      'revision',
      'labels',
      'sourceRuleIds',
      'slots',
      'constraints',
      'compatibleExerciseCategories',
    }, 'assistancePlan');
    final id = _string(value, 'id');
    final revision = _positiveInt(value, 'revision');
    final slots = <AssistanceSessionSlot>[];
    final slotIds = <String>{};
    final exercisesByRole = <String, Set<String>>{};
    for (final raw in _list(value, 'slots')) {
      final slot = _slot(_map(raw, '$id.slot'));
      if (!slotIds.add(slot.id)) {
        throw FormatException('$id has duplicate slot ${slot.id}.');
      }
      final seen = exercisesByRole.putIfAbsent(slot.sessionRole, () => {});
      for (final prescription in slot.prescriptions) {
        if (!seen.add(prescription.exerciseId)) {
          throw FormatException(
            '$id/${slot.sessionRole} repeats ${prescription.exerciseId}.',
          );
        }
      }
      slots.add(slot);
    }
    return ResolvedAssistancePlan(
      id: id,
      revision: revision,
      slots: List.unmodifiable(slots),
    );
  }

  AssistanceSessionSlot _slot(Map<String, Object?> value) {
    _keys(value, const {
      'id',
      'sessionRole',
      'minimumExercises',
      'maximumExercises',
      'allowedCategories',
      'prescriptions',
    }, 'assistanceSlot');
    final id = _string(value, 'id');
    final prescriptions = _list(value, 'prescriptions')
        .map((item) => _prescription(_map(item, '$id.prescription')))
        .toList(growable: false);
    final minimum = _positiveInt(value, 'minimumExercises');
    final maximum = _positiveInt(value, 'maximumExercises');
    if (maximum < minimum ||
        prescriptions.length < minimum ||
        prescriptions.length > maximum) {
      throw FormatException(
        '$id prescription count must be between $minimum and $maximum.',
      );
    }
    return AssistanceSessionSlot(
      id: id,
      sessionRole: _string(value, 'sessionRole'),
      prescriptions: List.unmodifiable(prescriptions),
    );
  }

  AssistanceExercisePrescription _prescription(Map<String, Object?> value) {
    _keys(value, const {
      'exerciseId',
      'sets',
      'repetitions',
      'load',
    }, 'assistancePrescription');
    final sets = value['sets'];
    final repetitions = _map(value['repetitions'], 'repetitions');
    final volume = sets is int
        ? FixedAssistanceVolume(
            setCount: _positive(sets, 'sets'),
            repetitions: _fixedRepetitions(repetitions),
          )
        : _distributedVolume(_map(sets, 'sets'), repetitions);
    final load = _map(value['load'], 'load');
    _keys(load, const {'type'}, 'load');
    return AssistanceExercisePrescription(
      exerciseId: _string(value, 'exerciseId'),
      volume: volume,
      load: switch (_string(load, 'type')) {
        'bodyweight' => AssistanceLoadKind.bodyweight,
        'unconfigured' => AssistanceLoadKind.unconfigured,
        final type => throw FormatException(
          'Unsupported assistance load $type.',
        ),
      },
    );
  }

  int _fixedRepetitions(Map<String, Object?> value) {
    _keys(value, const {'type', 'count'}, 'repetitions');
    if (_string(value, 'type') != 'fixed') {
      throw const FormatException(
        'Fixed assistance sets require fixed repetitions.',
      );
    }
    return _positiveInt(value, 'count');
  }

  DistributedTotalAssistanceVolume _distributedVolume(
    Map<String, Object?> sets,
    Map<String, Object?> repetitions,
  ) {
    final setParameter = _parameter(sets, 'sets');
    _keys(repetitions, const {
      'type',
      'parameterId',
      'default',
      'minimum',
      'maximum',
      'step',
      'distribution',
    }, 'repetitions');
    if (_string(repetitions, 'type') != 'distributed_total' ||
        _string(repetitions, 'distribution') !=
            'rounded_average_edge_remainder') {
      throw const FormatException(
        'Unsupported assistance repetition distribution.',
      );
    }
    return DistributedTotalAssistanceVolume(
      setCount: setParameter,
      totalRepetitions: AssistanceIntegerParameter(
        id: _string(repetitions, 'parameterId'),
        defaultValue: _positiveInt(repetitions, 'default'),
        minimum: _positiveInt(repetitions, 'minimum'),
        maximum: _positiveInt(repetitions, 'maximum'),
        step: _positiveInt(repetitions, 'step'),
      ),
    );
  }

  AssistanceIntegerParameter _parameter(Map<String, Object?> value, String at) {
    _keys(value, const {
      'type',
      'parameterId',
      'default',
      'minimum',
      'maximum',
      'step',
    }, at);
    if (_string(value, 'type') != 'parameterized') {
      throw FormatException('$at must be parameterized.');
    }
    return AssistanceIntegerParameter(
      id: _string(value, 'parameterId'),
      defaultValue: _positiveInt(value, 'default'),
      minimum: _positiveInt(value, 'minimum'),
      maximum: _positiveInt(value, 'maximum'),
      step: _positiveInt(value, 'step'),
    );
  }

  static Map<String, Object?> _map(Object? value, String at) {
    if (value is! Map<String, Object?>) {
      throw FormatException('$at must be an object.');
    }
    return value;
  }

  static List<Object?> _list(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! List<Object?>) {
      throw FormatException('$key must be an array.');
    }
    return result;
  }

  static String _string(Map<String, Object?> value, String key) {
    final result = value[key];
    if (result is! String || result.isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return result;
  }

  static int _positiveInt(Map<String, Object?> value, String key) =>
      _positive(value[key], key);

  static int _positive(Object? value, String at) {
    if (value is! int || value <= 0) {
      throw FormatException('$at must be a positive integer.');
    }
    return value;
  }

  static void _keys(
    Map<String, Object?> value,
    Set<String> allowed,
    String at,
  ) {
    final unknown = value.keys.where((key) => !allowed.contains(key)).toList();
    final missing = allowed.where((key) => !value.containsKey(key)).toList();
    if (unknown.isNotEmpty || missing.isNotEmpty) {
      throw FormatException(
        '$at has unknown keys $unknown or missing keys $missing.',
      );
    }
  }
}
