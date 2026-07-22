enum CycleOptionType {
  boolean,
  enumeration,
  integer,
  percentage,
  weight,
  movement,
  exercise,
  prescription,
}

enum CycleOptionScope { global, perMovement, perSession }

enum CycleOptionPresentationGroup {
  hidden,
  template,
  warmup,
  joker,
  deload,
  supplemental,
  assistance,
  conditioning,
}

sealed class CycleOptionCondition {
  const CycleOptionCondition();
}

final class AlwaysCondition extends CycleOptionCondition {
  const AlwaysCondition(this.value);
  final bool value;
}

final class PresentCondition extends CycleOptionCondition {
  const PresentCondition(this.optionId);
  final String optionId;
}

final class EqualsCondition extends CycleOptionCondition {
  const EqualsCondition(this.optionId, this.value);
  final String optionId;
  final Object value;
}

final class NotCondition extends CycleOptionCondition {
  const NotCondition(this.condition);
  final CycleOptionCondition condition;
}

final class AllCondition extends CycleOptionCondition {
  const AllCondition(this.conditions);
  final List<CycleOptionCondition> conditions;
}

final class AnyCondition extends CycleOptionCondition {
  const AnyCondition(this.conditions);
  final List<CycleOptionCondition> conditions;
}

final class InCondition extends CycleOptionCondition {
  const InCondition(this.optionId, this.values);
  final String optionId;
  final List<Object> values;
}

final class RangeCondition extends CycleOptionCondition {
  const RangeCondition(
    this.optionId, {
    required this.minimum,
    required this.maximum,
  });
  final String optionId;
  final num minimum;
  final num maximum;
}

final class CycleOptionDefinition {
  const CycleOptionDefinition({
    required this.id,
    required this.type,
    required this.scope,
    required this.defaultValue,
    this.minimum,
    this.maximum,
    this.step,
    this.allowedValues = const [],
    this.visibleWhen = const AlwaysCondition(true),
    this.enabledWhen = const AlwaysCondition(true),
    this.requiredWhen = const AlwaysCondition(false),
    this.presentationGroup = CycleOptionPresentationGroup.supplemental,
    this.labelEn = '',
    this.labelFr = '',
  });

  final String id;
  final CycleOptionType type;
  final CycleOptionScope scope;
  final Object defaultValue;
  final num? minimum;
  final num? maximum;
  final num? step;
  final List<Object> allowedValues;
  final CycleOptionCondition visibleWhen;
  final CycleOptionCondition enabledWhen;
  final CycleOptionCondition requiredWhen;
  final CycleOptionPresentationGroup presentationGroup;
  final String labelEn;
  final String labelFr;
}

final class CycleEditorSchema {
  const CycleEditorSchema({
    required this.id,
    required this.templateId,
    required this.variantId,
    required this.options,
  });

  final String id;
  final String templateId;
  final String variantId;
  final List<CycleOptionDefinition> options;
}

