import '../../cycle_generation/domain/cycle_contract.dart';

extension type const ForeverDefinitionId(String value) {}

final class ForeverDefinitionRevision {
  const ForeverDefinitionRevision(this.value) : assert(value >= 1);
  final int value;

  @override
  bool operator ==(Object other) =>
      other is ForeverDefinitionRevision && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

enum ForeverPhaseRole { leader, anchor, transition, deload, test, custom }

enum MacrocycleState { draft, scheduled, active, completed, cancelled }

enum TrainingMaxValueKind { projected, confirmed }

final class ForeverCycleReference {
  const ForeverCycleReference({
    required this.templateId,
    required this.variantId,
    this.templateRevision = 1,
    this.variantRevision = 1,
  }) : assert(templateId != ''),
       assert(variantId != ''),
       assert(templateRevision >= 1),
       assert(variantRevision >= 1);

  final String templateId;
  final String variantId;
  final int templateRevision;
  final int variantRevision;

  String get key => '$templateId/$variantId';
}

sealed class TrainingMaxRule {
  const TrainingMaxRule();
}

final class KeepTrainingMax extends TrainingMaxRule {
  const KeepTrainingMax();
}

final class AddTrainingMax extends TrainingMaxRule {
  const AddTrainingMax(
    this.amounts, {
    this.resultKind = TrainingMaxValueKind.projected,
  });
  final Map<MovementId, Weight> amounts;
  final TrainingMaxValueKind resultKind;
}

final class MultiplyTrainingMax extends TrainingMaxRule {
  const MultiplyTrainingMax(
    this.ratios, {
    this.resultKind = TrainingMaxValueKind.projected,
  });
  final Map<MovementId, Percentage> ratios;
  final TrainingMaxValueKind resultKind;
}

final class TestThenConfirmTrainingMax extends TrainingMaxRule {
  const TestThenConfirmTrainingMax({
    this.projectedRule = const KeepTrainingMax(),
  });
  final TrainingMaxRule projectedRule;
}

final class ForeverTransition {
  const ForeverTransition({
    required this.trainingMaxRule,
    this.requiresConfirmation = false,
  });

  final TrainingMaxRule trainingMaxRule;
  final bool requiresConfirmation;
}

final class ForeverCycleSlot {
  const ForeverCycleSlot({
    required this.id,
    required this.role,
    required this.repeatCount,
    required this.defaultCycle,
    required this.allowedCycles,
    required this.transition,
    this.optional = false,
  }) : assert(id != ''),
       assert(repeatCount >= 1),
       assert(allowedCycles.length > 0);

  final String id;
  final ForeverPhaseRole role;
  final int repeatCount;
  final ForeverCycleReference defaultCycle;
  final List<ForeverCycleReference> allowedCycles;
  final ForeverTransition transition;
  final bool optional;
}

final class ForeverPhase {
  const ForeverPhase({required this.id, required this.slots})
    : assert(id != ''),
      assert(slots.length > 0);
  final String id;
  final List<ForeverCycleSlot> slots;
}

final class ForeverEditorSchema {
  const ForeverEditorSchema({
    required this.definitionId,
    required this.revision,
    required this.configurableSlotIds,
  });

  final ForeverDefinitionId definitionId;
  final ForeverDefinitionRevision revision;
  final List<String> configurableSlotIds;
}

final class ResolvedForeverDefinition {
  const ResolvedForeverDefinition({
    required this.id,
    required this.revision,
    required this.labelEn,
    required this.labelFr,
    required this.sourceRuleIds,
    required this.phases,
    required this.editorSchema,
  }) : assert(labelEn != ''),
       assert(labelFr != ''),
       assert(sourceRuleIds.length > 0),
       assert(phases.length > 0);

  final ForeverDefinitionId id;
  final ForeverDefinitionRevision revision;
  final String labelEn;
  final String labelFr;
  final List<String> sourceRuleIds;
  final List<ForeverPhase> phases;
  final ForeverEditorSchema editorSchema;
}

final class ForeverSlotRequest {
  const ForeverSlotRequest({
    required this.slotId,
    required this.cycle,
    required this.trainingDays,
    required this.sessionOrder,
    this.enabled = true,
    this.percentageParameters = const {},
    this.percentageParametersByMovement = const {},
    this.globalTrainingMaxRatio = const Percentage(10000),
    this.trainingMaxRatioByMovement = const {},
    this.includeDeload = true,
  }) : assert(slotId != ''),
       assert(trainingDays.length > 0),
       assert(sessionOrder.length > 0);

  final String slotId;
  final ForeverCycleReference cycle;
  final List<int> trainingDays;
  final List<MovementId> sessionOrder;
  final bool enabled;
  final Map<String, Percentage> percentageParameters;
  final Map<MovementId, Map<String, Percentage>> percentageParametersByMovement;
  final Percentage globalTrainingMaxRatio;
  final Map<MovementId, Percentage> trainingMaxRatioByMovement;
  final bool includeDeload;
}

final class ForeverRequest {
  const ForeverRequest({
    required this.macrocycleId,
    required this.definitionId,
    required this.definitionRevision,
    required this.startDate,
    required this.initialTrainingMaxes,
    required this.slotRequests,
    required this.unit,
    required this.roundingIncrement,
    required this.barProfile,
  }) : assert(macrocycleId != ''),
       assert(initialTrainingMaxes.length > 0);

  final String macrocycleId;
  final ForeverDefinitionId definitionId;
  final ForeverDefinitionRevision definitionRevision;
  final DateTime startDate;
  final Map<MovementId, Weight> initialTrainingMaxes;
  final Map<String, ForeverSlotRequest> slotRequests;
  final WeightUnit unit;
  final Weight roundingIncrement;
  final BarProfile barProfile;
}

final class TrainingMaxSnapshot {
  const TrainingMaxSnapshot({required this.values, required this.kind});
  final Map<MovementId, Weight> values;
  final TrainingMaxValueKind kind;
}

final class GeneratedMacrocycleNode {
  const GeneratedMacrocycleNode({
    required this.index,
    required this.slotId,
    required this.role,
    required this.cycleReference,
    required this.cycle,
    required this.trainingMaxesBefore,
    required this.trainingMaxesAfter,
  });

  final int index;
  final String slotId;
  final ForeverPhaseRole role;
  final ForeverCycleReference cycleReference;
  final GeneratedCycle cycle;
  final TrainingMaxSnapshot trainingMaxesBefore;
  final TrainingMaxSnapshot trainingMaxesAfter;
}

final class GeneratedMacrocycle {
  const GeneratedMacrocycle({
    required this.id,
    required this.definitionId,
    required this.definitionRevision,
    required this.state,
    required this.nodes,
    required this.initialTrainingMaxes,
    required this.projectedTrainingMaxes,
  });

  final String id;
  final ForeverDefinitionId definitionId;
  final ForeverDefinitionRevision definitionRevision;
  final MacrocycleState state;
  final List<GeneratedMacrocycleNode> nodes;
  final Map<MovementId, Weight> initialTrainingMaxes;
  final Map<MovementId, Weight> projectedTrainingMaxes;
}

final class MacrocycleSnapshot {
  const MacrocycleSnapshot({
    required this.schemaVersion,
    required this.macrocycle,
    required this.logicalHash,
  });

  final int schemaVersion;
  final GeneratedMacrocycle macrocycle;
  final String logicalHash;
}

final class ForeverEditorState {
  const ForeverEditorState({
    required this.definitionId,
    required this.definitionRevision,
    required this.startDate,
    required this.initialTrainingMaxes,
    required this.slotRequests,
  });

  final ForeverDefinitionId definitionId;
  final ForeverDefinitionRevision definitionRevision;
  final DateTime startDate;
  final Map<MovementId, Weight> initialTrainingMaxes;
  final Map<String, ForeverSlotRequest> slotRequests;
}

abstract interface class ForeverDefinitionRepository {
  Future<List<ResolvedForeverDefinition>> loadPublishedDefinitions(
    int catalogVersion,
  );

  Future<ResolvedForeverDefinition> resolve({
    required int catalogVersion,
    required ForeverDefinitionId id,
    required ForeverDefinitionRevision revision,
  });
}

abstract interface class ForeverCycleDefinitionResolver {
  Future<ResolvedCycleDefinition> resolve(ForeverCycleReference reference);
}

abstract interface class SyncForeverCycleDefinitionResolver {
  ResolvedCycleDefinition resolveSync(ForeverCycleReference reference);
}

abstract interface class ForeverComposer {
  Future<GeneratedMacrocycle> compose(
    ResolvedForeverDefinition definition,
    ForeverRequest request,
  );
}

abstract interface class SyncForeverComposer {
  GeneratedMacrocycle composeSync(
    ResolvedForeverDefinition definition,
    ForeverRequest request,
  );
}
