import 'dart:collection';

import 'catalog_contract.dart' as catalog;

enum ParameterKind {
  boolean,
  integer,
  decimal,
  enumeration,
  movement,
  duration,
}

sealed class ResolvedParameter {
  const ResolvedParameter();
  ParameterKind get kind;
}

final class BooleanParameter extends ResolvedParameter {
  const BooleanParameter(this.value);
  final bool value;
  @override
  ParameterKind get kind => ParameterKind.boolean;
}

final class NumberParameter extends ResolvedParameter {
  NumberParameter(this.value, this.kind) {
    if (!value.isFinite ||
        !const {
          ParameterKind.integer,
          ParameterKind.decimal,
          ParameterKind.duration,
        }.contains(kind) ||
        kind == ParameterKind.integer && value != value.roundToDouble()) {
      throw ArgumentError('Invalid numeric parameter kind or value.');
    }
  }
  final double value;
  @override
  final ParameterKind kind;
}

final class IdParameter extends ResolvedParameter {
  IdParameter(this.value, this.kind) {
    if (!const {
      ParameterKind.enumeration,
      ParameterKind.movement,
    }.contains(kind)) {
      throw ArgumentError('Invalid ID parameter kind.');
    }
  }
  final catalog.CatalogId value;
  @override
  final ParameterKind kind;
}

final class ParameterDefinition {
  ParameterDefinition({
    required this.id,
    required this.kind,
    this.minimum,
    this.maximum,
    Set<catalog.CatalogId> allowedIds = const {},
    Iterable<ConditionalAllowedIds> allowedIdsWhen = const [],
    this.visibleWhen = const AlwaysCondition(true),
    this.enabledWhen = const AlwaysCondition(true),
    this.requiredWhen = const AlwaysCondition(false),
  }) : allowedIds = UnmodifiableSetView(Set.of(allowedIds)),
       allowedIdsWhen = UnmodifiableListView(List.of(allowedIdsWhen)) {
    if (minimum != null && maximum != null && minimum! > maximum!) {
      throw ArgumentError('Invalid parameter bounds.');
    }
    if (this.allowedIds.isNotEmpty &&
        !const {
          ParameterKind.enumeration,
          ParameterKind.movement,
        }.contains(kind)) {
      throw ArgumentError('Allowed IDs require an ID parameter kind.');
    }
  }

  final catalog.CatalogId id;
  final ParameterKind kind;
  final double? minimum;
  final double? maximum;
  final Set<catalog.CatalogId> allowedIds;
  final List<ConditionalAllowedIds> allowedIdsWhen;
  final ParameterCondition visibleWhen;
  final ParameterCondition enabledWhen;
  final ParameterCondition requiredWhen;

  bool accepts(
    ResolvedParameter value,
    Map<catalog.CatalogId, ResolvedParameter> values,
  ) {
    if (value.kind != kind) {
      return false;
    }
    return switch (value) {
      NumberParameter(:final value) =>
        (minimum == null || value >= minimum!) &&
            (maximum == null || value <= maximum!),
      IdParameter(:final value) =>
        _effectiveAllowedIds(values).isEmpty ||
            _effectiveAllowedIds(values).contains(value),
      _ => true,
    };
  }

  Set<catalog.CatalogId> _effectiveAllowedIds(
    Map<catalog.CatalogId, ResolvedParameter> values,
  ) {
    for (final rule in allowedIdsWhen) {
      if (rule.when.evaluate(values)) {
        return rule.allowedIds;
      }
    }
    return allowedIds;
  }
}

final class ConditionalAllowedIds {
  ConditionalAllowedIds({
    required this.when,
    required Set<catalog.CatalogId> allowedIds,
  }) : allowedIds = UnmodifiableSetView(Set.of(allowedIds));
  final ParameterCondition when;
  final Set<catalog.CatalogId> allowedIds;
}

final class TemplateVariant {
  TemplateVariant({required this.id, required Set<catalog.CatalogId> moduleIds})
    : moduleIds = UnmodifiableSetView(Set.of(moduleIds));
  final catalog.CatalogId id;
  final Set<catalog.CatalogId> moduleIds;
}

sealed class ParameterCondition {
  const ParameterCondition();
  bool evaluate(Map<catalog.CatalogId, ResolvedParameter> values);
}

final class AlwaysCondition extends ParameterCondition {
  const AlwaysCondition(this.value);
  final bool value;
  @override
  bool evaluate(Map<catalog.CatalogId, ResolvedParameter> values) => value;
}

final class PresentCondition extends ParameterCondition {
  const PresentCondition(this.id);
  final catalog.CatalogId id;
  @override
  bool evaluate(Map<catalog.CatalogId, ResolvedParameter> values) =>
      values.containsKey(id);
}

final class EqualsCondition extends ParameterCondition {
  const EqualsCondition(this.id, this.expected);
  final catalog.CatalogId id;
  final ResolvedParameter expected;
  @override
  bool evaluate(Map<catalog.CatalogId, ResolvedParameter> values) =>
      _sameParameter(values[id], expected);
}

final class NotCondition extends ParameterCondition {
  const NotCondition(this.condition);
  final ParameterCondition condition;
  @override
  bool evaluate(Map<catalog.CatalogId, ResolvedParameter> values) =>
      !condition.evaluate(values);
}

final class AllCondition extends ParameterCondition {
  AllCondition(Iterable<ParameterCondition> conditions)
    : conditions = UnmodifiableListView(List.of(conditions));
  final List<ParameterCondition> conditions;
  @override
  bool evaluate(Map<catalog.CatalogId, ResolvedParameter> values) =>
      conditions.every((value) => value.evaluate(values));
}

final class AnyCondition extends ParameterCondition {
  AnyCondition(Iterable<ParameterCondition> conditions)
    : conditions = UnmodifiableListView(List.of(conditions));
  final List<ParameterCondition> conditions;
  @override
  bool evaluate(Map<catalog.CatalogId, ResolvedParameter> values) =>
      conditions.any((value) => value.evaluate(values));
}

final class ParameterConstraint {
  const ParameterConstraint({
    required this.id,
    required this.validWhen,
    required this.message,
  });
  final catalog.CatalogId id;
  final ParameterCondition validWhen;
  final String message;
}

enum ModulePortKind {
  movement,
  parameter,
  prescription,
  schedule,
  module,
  assistance,
  conditioning,
}

final class ModulePort {
  const ModulePort({
    required this.id,
    required this.kind,
    this.required = true,
  });
  final catalog.CatalogId id;
  final ModulePortKind kind;
  final bool required;
}

final class PortBinding {
  const PortBinding({
    required this.portId,
    required this.kind,
    required this.targetId,
    this.targetRevision,
  });
  final catalog.CatalogId portId;
  final ModulePortKind kind;
  final catalog.CatalogId targetId;
  final int? targetRevision;
}

final class ModuleBinding {
  ModuleBinding({
    required this.id,
    required this.moduleId,
    required this.moduleRevision,
    required Iterable<PortBinding> inputs,
    required Set<catalog.CatalogId> requiredMovementCapabilities,
  }) : inputs = UnmodifiableListView(List.of(inputs)),
       requiredMovementCapabilities = UnmodifiableSetView(
         Set.of(requiredMovementCapabilities),
       ) {
    if (moduleRevision <= 0 ||
        this.inputs.map((value) => value.portId).toSet().length !=
            this.inputs.length) {
      throw ArgumentError('Invalid module binding.');
    }
  }

  final catalog.CatalogId id;
  final catalog.CatalogId moduleId;
  final int moduleRevision;
  final List<PortBinding> inputs;
  final Set<catalog.CatalogId> requiredMovementCapabilities;
}

final class ModuleDefinition implements catalog.CatalogModule {
  ModuleDefinition({
    required this.id,
    required this.revision,
    required this.governance,
    required Set<catalog.CatalogId> requiredMovementCapabilities,
    required Set<catalog.CatalogId> requiredEquipment,
    required Set<catalog.LoadKind> supportedLoadKinds,
    required Iterable<ModulePort> inputPorts,
    required Iterable<ModulePort> outputPorts,
    this.evidence,
  }) : requiredMovementCapabilities = UnmodifiableSetView(
         Set.of(requiredMovementCapabilities),
       ),
       requiredEquipment = UnmodifiableSetView(Set.of(requiredEquipment)),
       supportedLoadKinds = UnmodifiableSetView(Set.of(supportedLoadKinds)),
       inputPorts = UnmodifiableListView(List.of(inputPorts)),
       outputPorts = UnmodifiableListView(List.of(outputPorts)) {
    if (revision <= 0 ||
        (governance.authority != catalog.CatalogAuthority.userCustom &&
            evidence == null)) {
      throw ArgumentError('Invalid module definition.');
    }
    final ports = [...this.inputPorts, ...this.outputPorts];
    if (ports.map((value) => value.id).toSet().length != ports.length) {
      throw ArgumentError('Duplicate module port ID.');
    }
  }
  @override
  final catalog.CatalogId id;
  @override
  final int revision;
  @override
  final catalog.CatalogGovernance governance;
  @override
  final catalog.CatalogEvidence? evidence;
  final Set<catalog.CatalogId> requiredMovementCapabilities;
  final Set<catalog.CatalogId> requiredEquipment;
  final Set<catalog.LoadKind> supportedLoadKinds;
  final List<ModulePort> inputPorts;
  final List<ModulePort> outputPorts;
}

final class TrainingTemplateGraph implements catalog.TemplateGraph {
  TrainingTemplateGraph({
    required this.id,
    required this.revision,
    required this.governance,
    required Iterable<TemplateVariant> variants,
    required Iterable<ParameterDefinition> parameters,
    required Iterable<ModuleBinding> modules,
    Iterable<ParameterConstraint> constraints = const [],
    this.evidence,
  }) : variants = UnmodifiableListView(List.of(variants)),
       parameters = UnmodifiableListView(List.of(parameters)),
       modules = UnmodifiableListView(List.of(modules)),
       constraints = UnmodifiableListView(List.of(constraints)) {
    if (revision <= 0 ||
        governance.authority != catalog.CatalogAuthority.userCustom &&
            evidence == null) {
      throw ArgumentError('Canonical templates require evidence.');
    }
    _unique(this.variants.map((value) => value.id), 'variant');
    _unique(this.parameters.map((value) => value.id), 'parameter');
    _unique(this.modules.map((value) => value.id), 'module');
    final knownModules = this.modules.map((value) => value.id).toSet();
    if (this.variants.any(
      (variant) => !knownModules.containsAll(variant.moduleIds),
    )) {
      throw ArgumentError('Variant references an unknown module.');
    }
  }

  @override
  final catalog.CatalogId id;
  @override
  final int revision;
  @override
  final catalog.CatalogGovernance governance;
  final catalog.CatalogEvidence? evidence;
  final List<TemplateVariant> variants;
  final List<ParameterDefinition> parameters;
  final List<ModuleBinding> modules;
  final List<ParameterConstraint> constraints;
}

void _unique(Iterable<catalog.CatalogId> ids, String label) {
  final values = ids.toList(growable: false);
  if (values.toSet().length != values.length) {
    throw ArgumentError('Duplicate $label ID.');
  }
}

bool _sameParameter(ResolvedParameter? left, ResolvedParameter right) =>
    switch ((left, right)) {
      (BooleanParameter(value: final a), BooleanParameter(value: final b)) =>
        a == b,
      (
        NumberParameter(value: final a, kind: final ak),
        NumberParameter(value: final b, kind: final bk),
      ) =>
        a == b && ak == bk,
      (
        IdParameter(value: final a, kind: final ak),
        IdParameter(value: final b, kind: final bk),
      ) =>
        a == b && ak == bk,
      _ => false,
    };
