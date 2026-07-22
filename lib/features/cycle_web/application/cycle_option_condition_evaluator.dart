import 'package:training_engine/features/cycle_generation/domain/cycle_option_schema.dart';

abstract final class CycleOptionConditionEvaluator {
  static bool evaluate(
    CycleOptionCondition condition,
    Map<String, Object> values,
  ) => switch (condition) {
    AlwaysCondition(:final value) => value,
    PresentCondition(:final optionId) => values.containsKey(optionId),
    EqualsCondition(:final optionId, :final value) => values[optionId] == value,
    NotCondition(:final condition) => !evaluate(condition, values),
    AllCondition(:final conditions) => conditions.every(
      (item) => evaluate(item, values),
    ),
    AnyCondition(:final conditions) => conditions.any(
      (item) => evaluate(item, values),
    ),
    InCondition(optionId: final optionId, values: final allowedValues) =>
      allowedValues.contains(values[optionId]),
    RangeCondition(:final optionId, :final minimum, :final maximum) => _inRange(
      values[optionId],
      minimum,
      maximum,
    ),
  };

  static bool _inRange(Object? value, num minimum, num maximum) =>
      value is num && value >= minimum && value <= maximum;
}
