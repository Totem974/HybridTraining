enum MethodGeneration { original, beyond, forever }

enum BlockRole { prep, leader, seventhWeek, anchor }

enum SeventhWeekPurpose {
  deload,
  trainingMaxTest,
  personalRecordTest,
  conditioningTest,
}

enum ProgramCapability {
  mainWork,
  supplementalWork,
  assistance,
  conditioning,
  athleticWork,
  multipleMainMovements,
}

enum RuleStatus { verified, needsReview, undocumented }

enum ImplementationStatus { available, planned, documentationOnly }

abstract class StableId {
  const StableId(this.value) : assert(value != '');
  final String value;
  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is StableId &&
      other.value == value;
  @override
  int get hashCode => Object.hash(runtimeType, value);
  @override
  String toString() => value;
}

class ProgramConceptId extends StableId {
  const ProgramConceptId(super.value);
}

class ProgramRevisionId extends StableId {
  const ProgramRevisionId(super.value);
}

class ProgramBlueprintId extends StableId {
  const ProgramBlueprintId(super.value);
}

class PolicyId extends StableId {
  const PolicyId(super.value);
}

class BlockTemplateId extends StableId {
  const BlockTemplateId(super.value);
}

class ProgramVersion implements Comparable<ProgramVersion> {
  const ProgramVersion(this.value) : assert(value >= 0);
  final int value;
  bool get isSpecified => value > 0;
  @override
  int compareTo(ProgramVersion other) => value.compareTo(other.value);
  @override
  bool operator ==(Object other) =>
      other is ProgramVersion && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

class RuleReference {
  const RuleReference({required this.document, this.location});
  final String document;
  final String? location;
}

class ProgramConcept {
  const ProgramConcept({
    required this.id,
    required this.titleKey,
    required this.origin,
  });
  final ProgramConceptId id;
  final String titleKey;
  final MethodGeneration? origin;
}

class ProgramRevision {
  const ProgramRevision({
    required this.id,
    required this.conceptId,
    required this.generation,
    required this.version,
    required this.ruleStatus,
    this.references = const [],
    this.supersedes,
  });
  final ProgramRevisionId id;
  final ProgramConceptId conceptId;
  final MethodGeneration generation;
  final ProgramVersion version;
  final RuleStatus ruleStatus;
  final List<RuleReference> references;
  final ProgramRevisionId? supersedes;
}

abstract class VersionedPolicy {
  const VersionedPolicy(
    this.id,
    this.version, {
    this.ruleStatus = RuleStatus.needsReview,
  });
  final PolicyId id;
  final ProgramVersion version;
  final RuleStatus ruleStatus;
}

class TrainingMaxPolicy extends VersionedPolicy {
  const TrainingMaxPolicy(super.id, super.version, {super.ruleStatus});
}

class MainWorkPolicy extends VersionedPolicy {
  const MainWorkPolicy(super.id, super.version, {super.ruleStatus});
}

class SupplementalPolicy extends VersionedPolicy {
  const SupplementalPolicy(super.id, super.version, {super.ruleStatus});
}

class AssistancePolicy extends VersionedPolicy {
  const AssistancePolicy(super.id, super.version, {super.ruleStatus});
}

class ConditioningPolicy extends VersionedPolicy {
  const ConditioningPolicy(super.id, super.version, {super.ruleStatus});
}

class AthleticWorkPolicy extends VersionedPolicy {
  const AthleticWorkPolicy(super.id, super.version, {super.ruleStatus});
}

class SchedulePolicy extends VersionedPolicy {
  const SchedulePolicy(
    super.id,
    super.version, {
    required this.supportedFrequencies,
    required this.recommendedFrequency,
    this.mainMovementsPerSession = 1,
    super.ruleStatus,
  });
  final Set<int> supportedFrequencies;
  final int recommendedFrequency;
  final int mainMovementsPerSession;
}

class BlockTemplate {
  const BlockTemplate({
    required this.id,
    required this.role,
    this.seventhWeekPurpose,
  });
  final BlockTemplateId id;
  final BlockRole role;
  final SeventhWeekPurpose? seventhWeekPurpose;
}

class BlockSequenceEntry {
  const BlockSequenceEntry({required this.templateId, required this.order});
  final BlockTemplateId templateId;
  final int order;
}

class BlockSequence {
  const BlockSequence({required this.blocks});
  final List<BlockSequenceEntry> blocks;
}

class BlockTransition {
  const BlockTransition(this.from, this.to);
  final BlockRole from;
  final BlockRole to;
  @override
  bool operator ==(Object other) =>
      other is BlockTransition && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(from, to);
}

class TransitionPolicy extends VersionedPolicy {
  const TransitionPolicy(
    super.id,
    super.version, {
    required this.allowedTransitions,
    super.ruleStatus,
  });
  final Set<BlockTransition> allowedTransitions;
}

class CompatibilityConstraint {
  const CompatibilityConstraint({
    required this.supportedFrequencies,
    this.requiredCapabilities = const {},
  });
  final Set<int> supportedFrequencies;
  final Set<ProgramCapability> requiredCapabilities;
}

class ProgramBlueprint {
  const ProgramBlueprint({
    required this.id,
    required this.version,
    required this.revisionIds,
    required this.capabilities,
    required this.trainingMaxPolicy,
    required this.mainWorkPolicy,
    required this.schedulePolicy,
    required this.blockTemplates,
    required this.blockSequence,
    required this.transitionPolicy,
    required this.compatibility,
    required this.implementationStatus,
    required this.generatorId,
    this.supplementalPolicy,
    this.assistancePolicy,
    this.conditioningPolicy,
    this.athleticWorkPolicy,
    this.references = const [],
  });
  final ProgramBlueprintId id;
  final ProgramVersion version;
  final List<ProgramRevisionId> revisionIds;
  final Set<ProgramCapability> capabilities;
  final TrainingMaxPolicy? trainingMaxPolicy;
  final MainWorkPolicy? mainWorkPolicy;
  final SupplementalPolicy? supplementalPolicy;
  final AssistancePolicy? assistancePolicy;
  final ConditioningPolicy? conditioningPolicy;
  final AthleticWorkPolicy? athleticWorkPolicy;
  final SchedulePolicy? schedulePolicy;
  final List<BlockTemplate> blockTemplates;
  final BlockSequence blockSequence;
  final TransitionPolicy? transitionPolicy;
  final CompatibilityConstraint compatibility;
  final List<RuleReference> references;
  final ImplementationStatus implementationStatus;
  final String? generatorId;
}

class ComposableProgramDomain {
  const ComposableProgramDomain({
    required this.concepts,
    required this.revisions,
    required this.blueprints,
  });
  final List<ProgramConcept> concepts;
  final List<ProgramRevision> revisions;
  final List<ProgramBlueprint> blueprints;
}
