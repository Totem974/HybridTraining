import 'dart:collection';

import 'catalog_contract.dart';
import 'template_graph.dart';

enum MaxInputKind { oneRepMax, repMax, directTrainingMax }

enum WeightUnit { kilograms, pounds }

enum RepMaxFormula { epley, brzycki }

final class MaxCalculationRule {
  MaxCalculationRule({
    required this.id,
    required this.governance,
    required Set<RepMaxFormula> formulas,
    this.evidence,
  }) : formulas = UnmodifiableSetView(Set.of(formulas)) {
    if (this.formulas.isEmpty ||
        governance.authority != CatalogAuthority.userCustom &&
            evidence == null) {
      throw ArgumentError('Calculation rules require formulas and evidence.');
    }
  }
  final CatalogId id;
  final CatalogGovernance governance;
  final Set<RepMaxFormula> formulas;
  final CatalogEvidence? evidence;
}

final class MaxInput {
  MaxInput({
    required this.kind,
    required this.weight,
    this.repetitions,
    this.formula,
  }) {
    if (!weight.isFinite || weight <= 0) {
      throw ArgumentError.value(weight, 'weight');
    }
    if (kind == MaxInputKind.repMax &&
        (repetitions == null || repetitions! <= 1)) {
      throw ArgumentError('Rep max requires at least two repetitions.');
    }
    if (kind != MaxInputKind.repMax && repetitions != null) {
      throw ArgumentError('Repetitions are only valid for a rep max.');
    }
    if ((kind == MaxInputKind.repMax) != (formula != null)) {
      throw ArgumentError('Rep max inputs require exactly one formula policy.');
    }
    if (kind == MaxInputKind.repMax &&
        formula == RepMaxFormula.brzycki &&
        repetitions! >= 37) {
      throw ArgumentError('Brzycki requires repetitions below 37.');
    }
  }
  final MaxInputKind kind;
  final double weight;
  final int? repetitions;
  final RepMaxFormula? formula;

  double estimatedOneRepMax() => switch (kind) {
    MaxInputKind.oneRepMax || MaxInputKind.directTrainingMax => weight,
    MaxInputKind.repMax when formula == RepMaxFormula.epley =>
      weight * (1 + repetitions! / 30),
    MaxInputKind.repMax => weight * (36 / (37 - repetitions!)),
  };
}

final class TrainingMaxConfiguration {
  TrainingMaxConfiguration({
    required this.calculationRule,
    required this.globalRatio,
    required this.unit,
    required this.roundingIncrement,
    required Map<CatalogId, MaxInput> inputs,
    Map<CatalogId, double> ratiosByMovement = const {},
  }) : inputs = UnmodifiableMapView(Map.of(inputs)),
       ratiosByMovement = UnmodifiableMapView(Map.of(ratiosByMovement)) {
    _ratio(globalRatio);
    this.ratiosByMovement.values.forEach(_ratio);
    if (!this.inputs.keys.toSet().containsAll(this.ratiosByMovement.keys)) {
      throw ArgumentError('Per-movement ratios require matching max inputs.');
    }
    if (!roundingIncrement.isFinite || roundingIncrement <= 0) {
      throw ArgumentError.value(roundingIncrement, 'roundingIncrement');
    }
  }
  final double globalRatio;
  final MaxCalculationRule calculationRule;
  final WeightUnit unit;
  final double roundingIncrement;
  final Map<CatalogId, MaxInput> inputs;
  final Map<CatalogId, double> ratiosByMovement;
  double ratioFor(CatalogId movementId) =>
      ratiosByMovement[movementId] ?? globalRatio;
  double trainingMaxFor(CatalogId movementId) {
    calculationRule.governance.requireExecutable();
    final input = inputs[movementId];
    if (input == null) {
      throw ArgumentError.value(movementId, 'movementId');
    }
    if (input.formula != null &&
        !calculationRule.formulas.contains(input.formula)) {
      throw StateError(
        'Rep-max formula is not allowed by the calculation rule.',
      );
    }
    final raw = input.kind == MaxInputKind.directTrainingMax
        ? input.weight
        : input.estimatedOneRepMax() * ratioFor(movementId);
    return (raw / roundingIncrement).round() * roundingIncrement;
  }
}

sealed class RepetitionTarget {
  const RepetitionTarget();
}

final class FixedRepetitions extends RepetitionTarget {
  const FixedRepetitions(this.count);
  final int count;
}

final class RepetitionRange extends RepetitionTarget {
  const RepetitionRange(this.minimum, this.maximum);
  final int minimum;
  final int maximum;
}

final class Amrap extends RepetitionTarget {
  const Amrap({this.minimum});
  final int? minimum;
}

sealed class LoadTarget {
  const LoadTarget();
  LoadKind get kind;
}

final class PercentTrainingMax extends LoadTarget {
  const PercentTrainingMax(this.percent);
  final double percent;
  @override
  LoadKind get kind => LoadKind.percentTrainingMax;
}

final class PercentOneRepMax extends LoadTarget {
  const PercentOneRepMax(this.percent);
  final double percent;
  @override
  LoadKind get kind => LoadKind.percentOneRepMax;
}

final class Unloaded extends LoadTarget {
  const Unloaded();
  @override
  LoadKind get kind => LoadKind.none;
}

final class DirectLoad extends LoadTarget {
  DirectLoad(this.amount, this.kind) {
    if (!amount.isFinite ||
        amount < 0 ||
        !const {
          LoadKind.externalWeight,
          LoadKind.machineSetting,
          LoadKind.equipmentSetting,
          LoadKind.assistedBodyweight,
          LoadKind.addedBodyweightLoad,
        }.contains(kind)) {
      throw ArgumentError('Invalid direct load.');
    }
  }
  final double amount;
  @override
  final LoadKind kind;
}

final class BodyweightLoad extends LoadTarget {
  const BodyweightLoad();
  @override
  LoadKind get kind => LoadKind.bodyweight;
}

final class SetPrescription {
  SetPrescription({
    required this.sets,
    required this.repetitions,
    required this.load,
  }) {
    if (sets <= 0) {
      throw ArgumentError.value(sets, 'sets');
    }
    switch (repetitions) {
      case FixedRepetitions(:final count) when count <= 0:
        throw ArgumentError.value(count, 'count');
      case RepetitionRange(:final minimum, :final maximum)
          when minimum <= 0 || maximum < minimum:
        throw ArgumentError('Invalid repetition range.');
      case Amrap(:final minimum) when minimum != null && minimum < 0:
        throw ArgumentError.value(minimum, 'minimum');
      default:
        break;
    }
  }
  final int sets;
  final RepetitionTarget repetitions;
  final LoadTarget load;
}

enum BlockKind {
  main,
  supplemental,
  assistance,
  conditioning,
  recovery,
  custom,
}

enum ConditioningModality { time, distance, repetitions, intervals, open }

final class ConditioningPrescription {
  ConditioningPrescription({
    required this.modality,
    this.target,
    this.workSeconds,
    this.restSeconds,
  }) {
    if (target != null && (!target!.isFinite || target! <= 0) ||
        workSeconds != null && workSeconds! <= 0 ||
        restSeconds != null && restSeconds! < 0) {
      throw ArgumentError('Invalid conditioning target.');
    }
    if (modality == ConditioningModality.intervals && workSeconds == null) {
      throw ArgumentError('Intervals require work duration.');
    }
  }
  final ConditioningModality modality;
  final double? target;
  final int? workSeconds;
  final int? restSeconds;
}

final class OrderedBlock {
  OrderedBlock({
    required this.id,
    required this.order,
    required this.kind,
    this.movementId,
    this.strength,
    this.conditioning,
  }) {
    if (order < 0 || (strength == null) == (conditioning == null)) {
      throw ArgumentError(
        'A block needs one prescription and a non-negative order.',
      );
    }
    if (conditioning != null &&
        (kind != BlockKind.conditioning || movementId != null)) {
      throw ArgumentError(
        'Conditioning blocks cannot carry a movement or strength kind.',
      );
    }
    if (strength != null &&
        (kind == BlockKind.conditioning || movementId == null)) {
      throw ArgumentError(
        'Strength blocks require a movement and non-conditioning kind.',
      );
    }
  }
  final CatalogId id;
  final int order;
  final BlockKind kind;
  final CatalogId? movementId;
  final SetPrescription? strength;
  final ConditioningPrescription? conditioning;
}

final class SessionPlan {
  SessionPlan({
    required this.id,
    required this.offsetDays,
    required Iterable<OrderedBlock> blocks,
    this.roleId,
  }) : blocks = UnmodifiableListView(
         (List.of(blocks)..sort((a, b) => a.order.compareTo(b.order))),
       ) {
    if (offsetDays < 0 ||
        this.blocks.isEmpty ||
        this.blocks.map((b) => b.order).toSet().length != this.blocks.length) {
      throw ArgumentError('Invalid session ordering.');
    }
  }
  final CatalogId id;
  final int offsetDays;
  final CatalogId? roleId;
  final List<OrderedBlock> blocks;
}

enum ScheduleSegmentKind { training, deload, test, recovery, custom }

final class ScheduleSegment {
  ScheduleSegment({
    required this.id,
    required this.kind,
    required this.startOffsetDays,
    required this.durationDays,
    required this.frequency,
    required Set<CatalogId> roleIds,
  }) : roleIds = UnmodifiableSetView(Set.of(roleIds)) {
    if (startOffsetDays < 0 ||
        durationDays <= 0 ||
        frequency <= 0 ||
        this.roleIds.isEmpty) {
      throw ArgumentError('Invalid schedule segment.');
    }
  }
  final CatalogId id;
  final ScheduleSegmentKind kind;
  final int startOffsetDays;
  final int durationDays;
  final int frequency;
  final Set<CatalogId> roleIds;
}

final class TrainingMaxEvolution {
  TrainingMaxEvolution({
    required this.effectiveOffsetDays,
    required this.movementId,
    required this.trainingMax,
  }) {
    if (effectiveOffsetDays < 0 || !trainingMax.isFinite || trainingMax <= 0) {
      throw ArgumentError('Invalid TM evolution.');
    }
  }
  final int effectiveOffsetDays;
  final CatalogId movementId;
  final double trainingMax;
}

final class FlexibleSchedule {
  FlexibleSchedule({
    required this.startDate,
    required Iterable<SessionPlan> sessions,
    Iterable<ScheduleSegment> segments = const [],
    Iterable<TrainingMaxEvolution> trainingMaxEvolution = const [],
  }) : sessions = UnmodifiableListView(
         (List.of(sessions)
           ..sort((a, b) => a.offsetDays.compareTo(b.offsetDays))),
       ),
       segments = UnmodifiableListView(List.of(segments)),
       trainingMaxEvolution = UnmodifiableListView(
         List.of(trainingMaxEvolution),
       ) {
    if (this.sessions.isEmpty) {
      throw ArgumentError('A schedule requires sessions.');
    }
    if (this.sessions.map((value) => value.id).toSet().length !=
        this.sessions.length) {
      throw ArgumentError('Duplicate session ID.');
    }
    if (this.segments.map((value) => value.id).toSet().length !=
        this.segments.length) {
      throw ArgumentError('Duplicate segment ID.');
    }
    final orderedSegments = [...this.segments]
      ..sort((a, b) => a.startOffsetDays.compareTo(b.startOffsetDays));
    for (var index = 1; index < orderedSegments.length; index++) {
      final previous = orderedSegments[index - 1];
      if (orderedSegments[index].startOffsetDays <
          previous.startOffsetDays + previous.durationDays) {
        throw ArgumentError('Schedule segments overlap.');
      }
    }
    for (final segment in this.segments) {
      final actual = this.sessions
          .where(
            (session) =>
                session.offsetDays >= segment.startOffsetDays &&
                session.offsetDays <
                    segment.startOffsetDays + segment.durationDays,
          )
          .length;
      if (actual != segment.frequency) {
        throw ArgumentError('Segment frequency does not match its sessions.');
      }
      final invalidRole = this.sessions
          .where(
            (session) =>
                session.offsetDays >= segment.startOffsetDays &&
                session.offsetDays <
                    segment.startOffsetDays + segment.durationDays,
          )
          .any(
            (session) =>
                session.roleId == null ||
                !segment.roleIds.contains(session.roleId),
          );
      if (invalidRole) {
        throw ArgumentError('Session role is incompatible with its segment.');
      }
    }
    final evolutionKeys = this.trainingMaxEvolution.map(
      (value) => '${value.effectiveOffsetDays}:${value.movementId}',
    );
    if (evolutionKeys.toSet().length != evolutionKeys.length) {
      throw ArgumentError('Duplicate TM evolution point.');
    }
  }
  final DateTime startDate;
  final List<SessionPlan> sessions;
  final List<ScheduleSegment> segments;
  final List<TrainingMaxEvolution> trainingMaxEvolution;

  List<ContractIssue> validateAgainst(CatalogSnapshot snapshot) {
    final known = snapshot.movements.map((movement) => movement.id).toSet();
    final issues = <ContractIssue>[];
    for (final session in sessions) {
      for (final block in session.blocks) {
        if (block.movementId != null && !known.contains(block.movementId)) {
          issues.add(
            ContractIssue(
              'unknown_schedule_movement',
              r'$.sessions.${session.id}.${block.id}',
              'Unknown schedule movement.',
            ),
          );
        }
      }
    }
    for (final evolution in trainingMaxEvolution) {
      if (!known.contains(evolution.movementId)) {
        issues.add(
          ContractIssue(
            'unknown_tm_evolution_movement',
            r'$.trainingMaxEvolution',
            'Unknown TM evolution movement.',
          ),
        );
      }
    }
    return List.unmodifiable(issues);
  }
}

final class EquipmentProfile {
  EquipmentProfile({
    required Set<CatalogId> equipmentIds,
    required Set<LoadKind> supportedLoads,
    this.barWeight,
    Iterable<double> availablePlates = const [],
  }) : equipmentIds = UnmodifiableSetView(Set.of(equipmentIds)),
       supportedLoads = UnmodifiableSetView(Set.of(supportedLoads)),
       availablePlates = UnmodifiableListView(List.of(availablePlates)) {
    if (barWeight != null && (!barWeight!.isFinite || barWeight! <= 0) ||
        this.availablePlates.any((plate) => !plate.isFinite || plate <= 0)) {
      throw ArgumentError('Invalid plating equipment.');
    }
  }
  final Set<CatalogId> equipmentIds;
  final Set<LoadKind> supportedLoads;
  final double? barWeight;
  final List<double> availablePlates;
}

final class PlatePlan {
  PlatePlan(Map<double, int> perSide)
    : perSide = UnmodifiableMapView(Map.of(perSide));
  final Map<double, int> perSide;
}

abstract interface class PlatingPort {
  PlatePlan calculate(PlatingRequest request);
}

final class PlatingRequest {
  PlatingRequest({
    required this.target,
    required this.unit,
    required this.equipment,
    required this.movement,
  }) {
    if (!target.isFinite ||
        target <= 0 ||
        movement.kind != MovementKind.barbell ||
        !equipment.supportedLoads.contains(LoadKind.externalWeight) ||
        !equipment.equipmentIds.contains(CatalogId('barbell')) ||
        equipment.barWeight == null ||
        equipment.availablePlates.isEmpty) {
      throw ArgumentError(
        'Plating requires compatible barbell, bar, plates and external load.',
      );
    }
  }
  final double target;
  final WeightUnit unit;
  final EquipmentProfile equipment;
  final MovementDefinition movement;
}

enum AssistanceDeloadMode { templateDefault, inheritRegular, custom, omit }

final class AssistanceSlot {
  AssistanceSlot({
    required this.id,
    required this.roleId,
    required this.minimumSelections,
    required this.maximumSelections,
    required Set<CatalogId> movementIds,
  }) : movementIds = UnmodifiableSetView(Set.of(movementIds)) {
    if (minimumSelections < 0 ||
        maximumSelections < minimumSelections ||
        movementIds.length < minimumSelections) {
      throw ArgumentError('Invalid assistance slot bounds.');
    }
  }
  final CatalogId id;
  final CatalogId roleId;
  final int minimumSelections;
  final int maximumSelections;
  final Set<CatalogId> movementIds;
}

final class AssistanceSelection {
  AssistanceSelection({
    required this.slotId,
    required this.movementId,
    required this.regular,
    required this.deloadMode,
    this.deload,
  });
  final CatalogId slotId;
  final CatalogId movementId;
  final SetPrescription regular;
  final AssistanceDeloadMode deloadMode;
  final SetPrescription? deload;
}

final class AssistancePlan {
  AssistancePlan({
    required Iterable<AssistanceSlot> slots,
    required Iterable<AssistanceSelection> selections,
  }) : slots = UnmodifiableListView(List.of(slots)),
       selections = UnmodifiableListView(List.of(selections)) {
    final byId = {for (final slot in this.slots) slot.id: slot};
    if (byId.length != this.slots.length) {
      throw ArgumentError('Duplicate assistance slot ID.');
    }
    for (final selection in this.selections) {
      final slot = byId[selection.slotId];
      if (slot == null || !slot.movementIds.contains(selection.movementId)) {
        throw ArgumentError('Invalid assistance selection.');
      }
      if (selection.deloadMode == AssistanceDeloadMode.custom &&
          selection.deload == null) {
        throw ArgumentError('Custom deload requires a prescription.');
      }
      if (selection.deloadMode != AssistanceDeloadMode.custom &&
          selection.deload != null) {
        throw ArgumentError('Only custom deload accepts a prescription.');
      }
    }
    for (final slot in this.slots) {
      final count = this.selections
          .where((selection) => selection.slotId == slot.id)
          .length;
      if (count < slot.minimumSelections || count > slot.maximumSelections) {
        throw ArgumentError(
          'Assistance selection count is outside slot bounds.',
        );
      }
    }
  }
  final List<AssistanceSlot> slots;
  final List<AssistanceSelection> selections;
}

final class ConditioningDefinition {
  ConditioningDefinition({
    required this.id,
    required Set<ConditioningModality> modalities,
    required this.governance,
    this.evidence,
  }) : modalities = UnmodifiableSetView(Set.of(modalities)) {
    if (this.modalities.isEmpty ||
        (governance.authority != CatalogAuthority.userCustom &&
            evidence == null)) {
      throw ArgumentError('Invalid conditioning definition.');
    }
  }
  final CatalogId id;
  final Set<ConditioningModality> modalities;
  final CatalogGovernance governance;
  final CatalogEvidence? evidence;
}

final class ConditioningConfiguration {
  ConditioningConfiguration({
    required this.definition,
    required this.prescription,
  }) {
    if (!definition.modalities.contains(prescription.modality)) {
      throw ArgumentError('Unsupported conditioning modality.');
    }
    definition.governance.requireExecutable();
  }
  final ConditioningDefinition definition;
  final ConditioningPrescription prescription;
}

final class EngineRequest {
  EngineRequest({
    required this.snapshot,
    required this.templateId,
    required this.templateRevision,
    required this.variantId,
    required Map<CatalogId, ResolvedParameter> parameters,
    required this.trainingMaxes,
    required this.equipment,
    this.assistance,
    Iterable<ConditioningConfiguration> conditioning = const [],
  }) : parameters = UnmodifiableMapView(Map.of(parameters)),
       conditioning = UnmodifiableListView(List.of(conditioning));
  final CatalogSnapshot snapshot;
  final CatalogId templateId;
  final int templateRevision;
  final CatalogId variantId;
  final Map<CatalogId, ResolvedParameter> parameters;
  final TrainingMaxConfiguration trainingMaxes;
  final EquipmentProfile equipment;
  final AssistancePlan? assistance;
  final List<ConditioningConfiguration> conditioning;
}

final class ContractIssue {
  const ContractIssue(this.code, this.path, this.message);
  final String code;
  final String path;
  final String message;
}

final class ResolvedTemplate {
  ResolvedTemplate({
    required this.graph,
    required this.variant,
    required this.modules,
  });
  final TrainingTemplateGraph graph;
  final TemplateVariant variant;
  final List<ModuleBinding> modules;
}

final class TemplateContractResolver {
  const TemplateContractResolver();

  ({ResolvedTemplate? value, List<ContractIssue> issues}) resolve(
    EngineRequest request,
  ) {
    final issues = <ContractIssue>[];
    final raw = request.snapshot.templates
        .where(
          (value) =>
              value.id == request.templateId &&
              value.revision == request.templateRevision,
        )
        .firstOrNull;
    if (raw == null) {
      return (
        value: null,
        issues: [
          const ContractIssue(
            'unknown_template',
            r'$.templateId',
            'Unknown template.',
          ),
        ],
      );
    }
    if (raw is! TrainingTemplateGraph) {
      return (
        value: null,
        issues: [
          const ContractIssue(
            'unsupported_graph',
            r'$.templateId',
            'Unsupported template graph.',
          ),
        ],
      );
    }
    final graph = raw;
    if (!graph.governance.isExecutable) {
      return (
        value: null,
        issues: [
          const ContractIssue(
            'template_not_executable',
            r'$.templateId',
            'Template is not executable.',
          ),
        ],
      );
    }
    final variant = graph.variants
        .where((value) => value.id == request.variantId)
        .firstOrNull;
    if (variant == null) {
      issues.add(
        const ContractIssue(
          'unknown_variant',
          r'$.variantId',
          'Unknown variant.',
        ),
      );
      return (value: null, issues: List.unmodifiable(issues));
    }
    final definitions = {
      for (final definition in variant.parameters) definition.id: definition,
    };
    final rules = variant.rules;
    bool isVisible(ParameterDefinition definition) =>
        definition.visibleWhen.evaluate(request.parameters) &&
        rules
            .where(
              (rule) =>
                  rule.kind == DeclarativeRuleKind.visibility &&
                  rule.targetParameterId == definition.id,
            )
            .every((rule) => rule.expression.evaluate(request.parameters));
    bool isRequired(ParameterDefinition definition) =>
        definition.requiredWhen.evaluate(request.parameters) ||
        rules
            .where(
              (rule) =>
                  rule.kind == DeclarativeRuleKind.required &&
                  rule.targetParameterId == definition.id,
            )
            .any((rule) => rule.expression.evaluate(request.parameters));
    for (final entry in request.parameters.entries) {
      final definition = definitions[entry.key];
      if (definition == null) {
        issues.add(
          ContractIssue(
            'unknown_parameter',
            r'$.parameters.${entry.key}',
            'Unknown parameter.',
          ),
        );
      } else if (!isVisible(definition) ||
          !definition.enabledWhen.evaluate(request.parameters)) {
        issues.add(
          ContractIssue(
            'inactive_parameter',
            r'$.parameters.${entry.key}',
            'Hidden or disabled parameter has a value.',
          ),
        );
      } else if (!definition.accepts(entry.value, request.parameters)) {
        issues.add(
          ContractIssue(
            'invalid_parameter',
            r'$.parameters.${entry.key}',
            'Incompatible parameter value.',
          ),
        );
      } else if (entry.value case IdParameter(
        kind: ParameterKind.movement,
        value: final movementId,
      )) {
        final movement = request.snapshot.movements
            .where((movement) => movement.id == movementId)
            .firstOrNull;
        if (movement == null) {
          issues.add(
            ContractIssue(
              'unknown_movement_parameter',
              r'$.parameters.${entry.key}',
              'Movement parameter references an unknown movement.',
            ),
          );
        } else if (!movement.governance.isExecutable) {
          issues.add(
            ContractIssue(
              'movement_parameter_not_executable',
              r'$.parameters.${entry.key}',
              'Movement parameter is not executable.',
            ),
          );
        }
      }
    }
    if (definitions.values.any(
      (definition) =>
          isRequired(definition) &&
          isVisible(definition) &&
          definition.enabledWhen.evaluate(request.parameters) &&
          !request.parameters.containsKey(definition.id),
    )) {
      issues.add(
        const ContractIssue(
          'missing_canonical_parameter',
          r'$.parameters',
          'Canonical parameters must be resolved explicitly.',
        ),
      );
    }
    for (final movementId in request.trainingMaxes.inputs.keys) {
      final movement = request.snapshot.movements
          .where((movement) => movement.id == movementId)
          .firstOrNull;
      if (movement == null) {
        issues.add(
          ContractIssue(
            'unknown_training_max_movement',
            r'$.trainingMaxes.$movementId',
            'Unknown movement.',
          ),
        );
      } else if (!movement.governance.isExecutable) {
        issues.add(
          ContractIssue(
            'training_max_movement_not_executable',
            r'$.trainingMaxes.$movementId',
            'Training Max movement is not executable.',
          ),
        );
      }
    }
    for (final selection
        in request.assistance?.selections ?? const <AssistanceSelection>[]) {
      final movement = request.snapshot.movements
          .where((movement) => movement.id == selection.movementId)
          .firstOrNull;
      if (movement == null) {
        issues.add(
          ContractIssue(
            'unknown_assistance_movement',
            r'$.assistance.${selection.slotId}',
            'Unknown assistance movement.',
          ),
        );
      } else if (!movement.governance.isExecutable) {
        issues.add(
          ContractIssue(
            'assistance_movement_not_executable',
            r'$.assistance.${selection.slotId}',
            'Assistance movement is not executable.',
          ),
        );
      }
      final loads = [
        selection.regular.load,
        if (selection.deload != null) selection.deload!.load,
      ];
      if (loads.any(
        (load) => !request.equipment.supportedLoads.contains(load.kind),
      )) {
        issues.add(
          ContractIssue(
            'unsupported_assistance_load',
            r'$.assistance.${selection.slotId}',
            'Assistance load is unsupported.',
          ),
        );
      }
    }
    final modules = variant.moduleBindings;
    final activeBindings = {for (final binding in modules) binding.id: binding};
    for (final binding in modules) {
      final definition = request.snapshot.modules
          .whereType<ModuleDefinition>()
          .where(
            (value) =>
                value.id == binding.moduleId &&
                value.revision == binding.moduleRevision,
          )
          .firstOrNull;
      if (definition == null) {
        issues.add(
          ContractIssue(
            'unknown_module_revision',
            r'$.modules.${binding.id}',
            'Unknown module revision.',
          ),
        );
        continue;
      }
      if (!definition.governance.isExecutable) {
        issues.add(
          ContractIssue(
            'module_not_executable',
            r'$.modules.${binding.id}',
            'Module is not executable.',
          ),
        );
      }
      if (!request.equipment.equipmentIds.containsAll(
        definition.requiredEquipment,
      )) {
        issues.add(
          ContractIssue(
            'missing_equipment',
            r'$.modules.${binding.id}',
            'Required equipment is unavailable.',
          ),
        );
      }
      if (!request.equipment.supportedLoads.containsAll(
        definition.supportedLoadKinds,
      )) {
        issues.add(
          ContractIssue(
            'unsupported_load',
            r'$.modules.${binding.id}',
            'Required load kind is unavailable.',
          ),
        );
      }
      final ports = {for (final port in definition.inputPorts) port.id: port};
      for (final input in binding.inputs) {
        final port = ports[input.portId];
        if (port == null || port.kind != input.kind) {
          issues.add(
            ContractIssue(
              'invalid_module_port',
              r'$.modules.${binding.id}',
              'Unknown port or incompatible port kind.',
            ),
          );
          continue;
        }
        if (input.kind == ModulePortKind.parameter &&
            !definitions.containsKey(input.targetId)) {
          issues.add(
            ContractIssue(
              'unknown_parameter_binding',
              r'$.modules.${binding.id}',
              'Unknown parameter binding.',
            ),
          );
        }
        if (input.kind == ModulePortKind.module) {
          final target = activeBindings[input.targetId];
          if (target == null) {
            issues.add(
              ContractIssue(
                'module_binding_not_included',
                r'$.modules.${binding.id}',
                'Target module binding is not included in the variant.',
              ),
            );
          } else if (input.targetRevision == null ||
              input.targetRevision != target.moduleRevision) {
            issues.add(
              ContractIssue(
                'module_binding_revision_mismatch',
                r'$.modules.${binding.id}',
                'Target module binding revision does not match.',
              ),
            );
          }
        }
        if (input.kind != ModulePortKind.movement) {
          continue;
        }
        final movement = request.snapshot.movements
            .where((value) => value.id == input.targetId)
            .firstOrNull;
        if (movement == null) {
          issues.add(
            ContractIssue(
              'unknown_movement_binding',
              r'$.modules.${binding.id}',
              'Unknown movement binding.',
            ),
          );
          continue;
        }
        if (!movement.governance.isExecutable) {
          issues.add(
            ContractIssue(
              'module_movement_not_executable',
              r'$.modules.${binding.id}',
              'Module movement is not executable.',
            ),
          );
        }
        final required = {
          ...definition.requiredMovementCapabilities,
          ...binding.requiredMovementCapabilities,
        };
        if (!movement.capabilities.containsAll(required)) {
          issues.add(
            ContractIssue(
              'movement_capability_mismatch',
              r'$.modules.${binding.id}',
              'Movement capabilities are incompatible.',
            ),
          );
        }
      }
      final bound = binding.inputs.map((input) => input.portId).toSet();
      if (definition.inputPorts.any(
        (port) => port.required && !bound.contains(port.id),
      )) {
        issues.add(
          ContractIssue(
            'missing_module_port',
            r'$.modules.${binding.id}',
            'Required module port is unbound.',
          ),
        );
      }
    }
    issues.addAll(_moduleCycleIssues(modules));
    for (final rule in rules.where(
      (rule) =>
          rule.kind == DeclarativeRuleKind.compatibility ||
          rule.kind == DeclarativeRuleKind.constraint,
    )) {
      if (!rule.expression.evaluate(request.parameters)) {
        issues.add(
          ContractIssue(
            rule.id.value,
            rule.kind == DeclarativeRuleKind.compatibility
                ? r'$.variantId'
                : r'$.parameters',
            rule.message,
          ),
        );
      }
    }
    if (issues.isNotEmpty) {
      return (value: null, issues: List.unmodifiable(issues));
    }
    return (
      value: ResolvedTemplate(graph: graph, variant: variant, modules: modules),
      issues: const [],
    );
  }

  List<ContractIssue> _moduleCycleIssues(List<ModuleBinding> bindings) {
    final byId = {for (final binding in bindings) binding.id: binding};
    final visiting = <CatalogId>{};
    final visited = <CatalogId>{};
    final issues = <ContractIssue>[];

    void visit(ModuleBinding binding) {
      if (visited.contains(binding.id)) {
        return;
      }
      if (!visiting.add(binding.id)) {
        issues.add(
          ContractIssue(
            'module_binding_cycle',
            r'$.modules.${binding.id}',
            'Module bindings contain a cycle.',
          ),
        );
        return;
      }
      for (final input in binding.inputs.where(
        (input) => input.kind == ModulePortKind.module,
      )) {
        final target = byId[input.targetId];
        if (target != null) {
          visit(target);
        }
      }
      visiting.remove(binding.id);
      visited.add(binding.id);
    }

    for (final binding in bindings) {
      visit(binding);
    }
    return issues;
  }
}

abstract interface class GenericTrainingEngine {
  List<ContractIssue> validate(EngineRequest request);
  FlexibleSchedule generate(EngineRequest request);
}

void _ratio(double value) {
  if (!value.isFinite || value <= 0 || value > 1) {
    throw ArgumentError.value(value, 'ratio');
  }
}
