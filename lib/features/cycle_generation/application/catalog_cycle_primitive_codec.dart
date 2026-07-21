import '../domain/catalog_cycle_primitives.dart';
import '../domain/cycle_contract.dart';

final class CatalogCyclePrimitiveCodec {
  const CatalogCyclePrimitiveCodec();

  RelativeSetLoad decodeRelativeSetLoad(Map<String, Object?> json) {
    _expectKeys(json, const {'type', 'position', 'multiplierBasisPoints'});
    if (json['type'] != 'relativeSet') {
      throw const FormatException('Expected relativeSet load.');
    }
    final multiplier = (json['multiplierBasisPoints'] as int?) ?? 10000;
    if (multiplier <= 0 || multiplier > 20000) {
      throw const FormatException(
        'Relative-set multiplier must be greater than zero and at most 20000.',
      );
    }
    return RelativeSetLoad(
      position: _enumByName(RelativeSetPosition.values, json['position']),
      multiplierBasisPoints: multiplier,
    );
  }

  SetExecution decodeSetExecution(Map<String, Object?> json) {
    _expectKeys(json, const {
      'type',
      'restSeconds',
      'pauseSeconds',
      'clusterRepetitions',
      'targetVelocity',
    });
    final result = SetExecution(
      kind: _enumByName(SetExecutionKind.values, json['type']),
      restSeconds: json['restSeconds'] as int?,
      pauseSeconds: json['pauseSeconds'] as int?,
      clusterRepetitions: json['clusterRepetitions'] as int?,
      targetVelocity: json['targetVelocity'] as String?,
    );
    _validateExecution(result);
    return result;
  }

  RuntimeGate decodeRuntimeGate(Map<String, Object?> json) {
    _expectKeys(json, const {'type', 'required'});
    return RuntimeGate(
      kind: _enumByName(RuntimeGateKind.values, json['type']),
      required: json['required']! as bool,
    );
  }

  List<CatalogPhase> decodePhases(List<Object?> json) => List.unmodifiable(
    json.map((value) {
      final phase = value! as Map<String, Object?>;
      _expectKeys(phase, const {'id', 'repeatCount', 'weekPlans'});
      return CatalogPhase(
        id: phase['id']! as String,
        repeatCount: phase['repeatCount']! as int,
        weekPlans: _decodeWeekPlans(phase['weekPlans']! as List<Object?>),
      );
    }),
  );

  List<CatalogWeekPlan> _decodeWeekPlans(List<Object?> json) =>
      List.unmodifiable(
        json.map((value) {
          final week = value! as Map<String, Object?>;
          _expectKeys(week, const {'weekNumber', 'componentIds'});
          return CatalogWeekPlan(
            weekNumber: week['weekNumber']! as int,
            components: List.unmodifiable(
              (week['componentIds']! as List<Object?>).map((value) {
                final reference = value! as Map<String, Object?>;
                _expectKeys(reference, const {'id', 'revision'});
                return ComponentReference(
                  reference['id']! as String,
                  reference['revision']! as int,
                );
              }),
            ),
          );
        }),
      );

  T _enumByName<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) throw const FormatException('Enum name is required.');
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown enum value: $name.');
  }

  void _expectKeys(Map<String, Object?> json, Set<String> allowed) {
    final unknown = json.keys.toSet().difference(allowed);
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown keys: ${unknown.join(', ')}.');
    }
  }

  void _validateExecution(SetExecution execution) {
    switch (execution.kind) {
      case SetExecutionKind.straight:
        if (execution.restSeconds != null ||
            execution.pauseSeconds != null ||
            execution.clusterRepetitions != null ||
            execution.targetVelocity != null) {
          throw const FormatException(
            'Straight sets accept no technique fields.',
          );
        }
        return;
      case SetExecutionKind.restPause:
        if ((execution.restSeconds ?? 0) <= 0 ||
            (execution.clusterRepetitions ?? 0) <= 0 ||
            execution.pauseSeconds != null ||
            execution.targetVelocity != null) {
          throw const FormatException(
            'Rest-pause requires positive rest and cluster repetitions.',
          );
        }
        return;
      case SetExecutionKind.paused:
        if ((execution.pauseSeconds ?? 0) <= 0 ||
            execution.restSeconds != null ||
            execution.clusterRepetitions != null ||
            execution.targetVelocity != null) {
          throw const FormatException(
            'Paused sets require positive pauseSeconds.',
          );
        }
        return;
      case SetExecutionKind.dynamic:
        if (execution.targetVelocity == null ||
            execution.restSeconds != null ||
            execution.pauseSeconds != null ||
            execution.clusterRepetitions != null) {
          throw const FormatException('Dynamic work requires targetVelocity.');
        }
        return;
    }
  }
}
