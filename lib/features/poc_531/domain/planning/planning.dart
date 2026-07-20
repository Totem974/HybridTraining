enum PlanningMode { cycle, forever }

enum ForeverPlanKind { standaloneProgram, macrocycle }

enum CycleRole { leader, anchor }

enum MacrocycleIntent { active, projected }

enum MacrocycleStatus { planned, active, completed, cancelled }

enum ContinuationMode { manual, repeatSame, cloneAndEdit, recommendNext }

enum CompatibilityStatus {
  recommended,
  allowed,
  restricted,
  forbidden,
  needsReview,
}

enum ProtocolPurpose {
  seventhWeekDeload,
  seventhWeekTrainingMaxTest,
  seventhWeekPersonalRecordTest,
}

enum PlanningIssueSeverity { info, warning, blocking }

enum TrainingUnit { kilograms, pounds }

class RuleSource {
  const RuleSource({required this.document, required this.location});

  final String document;
  final String location;
}

class ProgramRevision {
  const ProgramRevision({
    required this.id,
    required this.version,
    required this.source,
  });

  final String id;
  final int version;
  final RuleSource source;

  @override
  bool operator ==(Object other) =>
      other is ProgramRevision && other.id == id && other.version == version;

  @override
  int get hashCode => Object.hash(id, version);
}

class CycleRevision {
  const CycleRevision({
    required this.id,
    required this.version,
    required this.mainWork,
    required this.supplementalWork,
  });

  final String id;
  final int version;
  final ProgramRevision mainWork;
  final ProgramRevision supplementalWork;

  @override
  bool operator ==(Object other) =>
      other is CycleRevision && other.id == id && other.version == version;

  @override
  int get hashCode => Object.hash(id, version);
}

class CommonTrainingProfile {
  CommonTrainingProfile({
    this.unit = TrainingUnit.kilograms,
    required this.trainingDaysPerWeek,
    List<String> liftOrder = const [],
    this.trainingMaxRatio = .9,
    List<int> trainingWeekdays = const [],
    this.roundingIncrement = 2.5,
    List<double> availablePlates = const [],
    required Map<String, double> trainingMaxes,
    required Map<String, double> progressionIncrements,
  }) : liftOrder = List.unmodifiable(liftOrder),
       trainingWeekdays = List.unmodifiable(trainingWeekdays),
       availablePlates = List.unmodifiable(availablePlates),
       trainingMaxes = Map.unmodifiable(trainingMaxes),
       progressionIncrements = Map.unmodifiable(progressionIncrements);

  final TrainingUnit unit;
  final int trainingDaysPerWeek;
  final List<String> liftOrder;
  final double trainingMaxRatio;
  final List<int> trainingWeekdays;
  final double roundingIncrement;
  final List<double> availablePlates;
  final Map<String, double> trainingMaxes;
  final Map<String, double> progressionIncrements;
}

sealed class PlanningConfiguration {
  const PlanningConfiguration({required this.mode, required this.profile});

  final PlanningMode mode;
  final CommonTrainingProfile profile;
}

class CyclePlanningConfiguration extends PlanningConfiguration {
  const CyclePlanningConfiguration({
    required super.profile,
    required this.revision,
  }) : super(mode: PlanningMode.cycle);

  final CycleRevision revision;
}

class ForeverPlanningConfiguration extends PlanningConfiguration {
  const ForeverPlanningConfiguration({
    required super.profile,
    this.kind = ForeverPlanKind.macrocycle,
    this.standaloneProgramId,
    this.series,
  }) : assert(
         (standaloneProgramId == null) != (series == null),
         'Exactly one standalone program or series is required.',
       ),
       super(mode: PlanningMode.forever);

  final ForeverPlanKind kind;
  final String? standaloneProgramId;
  final ForeverProgramSeries? series;
}

class CycleTransitionRule {
  const CycleTransitionRule({
    required this.fromTemplateRevisionId,
    required this.fromRole,
    required this.toTemplateRevisionId,
    required this.toRole,
    required this.status,
    required this.allowedFrequencies,
    required this.trainingMaxCompatibility,
    required this.requiredEquipment,
    required this.source,
  });

  final String fromTemplateRevisionId;
  final CycleRole fromRole;
  final String toTemplateRevisionId;
  final CycleRole toRole;
  final CompatibilityStatus status;
  final List<int> allowedFrequencies;
  final String trainingMaxCompatibility;
  final List<String> requiredEquipment;
  final RuleSource source;

  CompatibilityResult evaluate({required int frequency}) {
    final issues = <PlanningIssue>[];
    if (!allowedFrequencies.contains(frequency)) {
      issues.add(
        const PlanningIssue(
          code: 'transition.frequency_not_allowed',
          path: 'trainingDaysPerWeek',
          message: 'The selected transition does not allow this frequency.',
        ),
      );
    }
    if (status == CompatibilityStatus.forbidden ||
        status == CompatibilityStatus.needsReview) {
      issues.add(
        PlanningIssue(
          code: status == CompatibilityStatus.needsReview
              ? 'transition.needs_review'
              : 'transition.forbidden',
          path: 'transition',
          message: status == CompatibilityStatus.needsReview
              ? 'A transition awaiting source review cannot be generated.'
              : 'The selected transition is forbidden.',
        ),
      );
    }
    return CompatibilityResult(issues, status: status);
  }
}

/// Historical type alias. New code must model an explicit cycle-to-cycle
/// transition instead of a main-work/supplemental pairing.
typedef PairingRule = CycleTransitionRule;

class CompatibilityResult {
  CompatibilityResult(
    Iterable<PlanningIssue> issues, {
    this.status = CompatibilityStatus.allowed,
  }) : issues = List.unmodifiable(issues);

  final List<PlanningIssue> issues;
  final CompatibilityStatus status;
  bool get isCompatible =>
      status != CompatibilityStatus.forbidden &&
      status != CompatibilityStatus.needsReview &&
      issues.every((issue) => issue.severity != PlanningIssueSeverity.blocking);
}

class PlanningIssue {
  const PlanningIssue({
    required this.code,
    required this.path,
    required this.message,
    this.severity = PlanningIssueSeverity.blocking,
  });

  final String code;
  final String path;
  final String message;
  final PlanningIssueSeverity severity;
}

class PlanningValidationResult {
  PlanningValidationResult(Iterable<PlanningIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<PlanningIssue> issues;
  bool get isValid =>
      issues.every((issue) => issue.severity != PlanningIssueSeverity.blocking);
}

sealed class ForeverPlanNode {
  const ForeverPlanNode({
    required this.nodeId,
    required this.source,
    required this.templateRevisionId,
    this.autoInserted = false,
  });

  final String nodeId;
  final RuleSource source;
  final String templateRevisionId;
  final bool autoInserted;
}

class ForeverCycleNode extends ForeverPlanNode {
  const ForeverCycleNode({
    required super.nodeId,
    required super.source,
    required super.templateRevisionId,
    required this.cycleInstanceId,
    required this.role,
    required this.revision,
  });

  final String cycleInstanceId;
  final CycleRole role;
  final CycleRevision revision;
}

class ForeverProtocolNode extends ForeverPlanNode {
  const ForeverProtocolNode({
    required super.nodeId,
    required super.source,
    required super.templateRevisionId,
    super.autoInserted,
    required this.purpose,
    required this.afterCycleInstanceId,
  });

  final ProtocolPurpose purpose;
  final String afterCycleInstanceId;
}

enum TrainingMaxDecisionState { confirmed, projected, proposed, held, reset }

class TrainingMaxDecision {
  TrainingMaxDecision({
    required this.nodeId,
    required this.cycleInstanceId,
    required Map<String, TrainingMaxDecisionState> states,
    required Map<String, double> previousTrainingMaxes,
    required Map<String, double> proposedTrainingMaxes,
  }) : states = Map.unmodifiable(states),
       previousTrainingMaxes = Map.unmodifiable(previousTrainingMaxes),
       proposedTrainingMaxes = Map.unmodifiable(proposedTrainingMaxes);

  final String nodeId;
  final String cycleInstanceId;
  final Map<String, TrainingMaxDecisionState> states;

  /// Compatibility accessor for historical consumers that only handled a
  /// uniform decision. Mixed per-lift decisions must use [states].
  TrainingMaxDecisionState get state {
    final distinctStates = states.values.toSet();
    if (distinctStates.length != 1) {
      throw StateError('Training Max states differ by lift; inspect states.');
    }
    return distinctStates.single;
  }

  final Map<String, double> previousTrainingMaxes;
  final Map<String, double> proposedTrainingMaxes;
}

class TrainingMaxChoice {
  const TrainingMaxChoice({required this.state, required this.value});

  final TrainingMaxDecisionState state;
  final double value;
}

class CompiledForeverSequence {
  CompiledForeverSequence({
    required Iterable<ForeverPlanNode> nodes,
    required Iterable<TrainingMaxDecision> trainingMaxDecisions,
  }) : nodes = List.unmodifiable(nodes),
       trainingMaxDecisions = List.unmodifiable(trainingMaxDecisions);

  final List<ForeverPlanNode> nodes;
  final List<TrainingMaxDecision> trainingMaxDecisions;
}

class ForeverCompilationException implements Exception {
  ForeverCompilationException(this.validation);

  final PlanningValidationResult validation;
}

const foreverOriginalMainWorkRevision = ProgramRevision(
  id: 'forever-original-531-v1',
  version: 1,
  source: RuleSource(document: '5/3/1 Forever', location: 'PDF pages 180-182'),
);

const foreverFirstSetLastRevision = ProgramRevision(
  id: 'forever-first-set-last-5x5-v1',
  version: 1,
  source: RuleSource(document: '5/3/1 Forever', location: 'PDF pages 180-182'),
);

const foreverOriginalFslLeaderRevision = CycleRevision(
  id: 'forever-original-fsl-leader-v1',
  version: 1,
  mainWork: foreverOriginalMainWorkRevision,
  supplementalWork: foreverFirstSetLastRevision,
);

const foreverOriginalPrSetRevision = ProgramRevision(
  id: 'forever-original-pr-set-v1',
  version: 1,
  source: RuleSource(document: '5/3/1 Forever', location: 'PDF pages 180-182'),
);

const foreverOriginalPrSetAnchorRevision = CycleRevision(
  id: 'forever-original-pr-set-anchor-v1',
  version: 1,
  mainWork: foreverOriginalMainWorkRevision,
  supplementalWork: foreverOriginalPrSetRevision,
);

/// Historical alias retained for persisted configurations only.
const foreverOriginalFslCycleRevision = foreverOriginalFslLeaderRevision;

const foreverOriginalFslLeaderTransition = CycleTransitionRule(
  fromTemplateRevisionId: 'forever-original-fsl-leader-v1',
  fromRole: CycleRole.leader,
  toTemplateRevisionId: 'forever-original-fsl-leader-v1',
  toRole: CycleRole.leader,
  status: CompatibilityStatus.recommended,
  allowedFrequencies: [4],
  trainingMaxCompatibility: 'preserve-per-lift',
  requiredEquipment: [],
  source: RuleSource(document: '5/3/1 Forever', location: 'PDF pages 180-182'),
);

const foreverOriginalFslAnchorTransition = CycleTransitionRule(
  fromTemplateRevisionId: 'forever-original-fsl-leader-v1',
  fromRole: CycleRole.leader,
  toTemplateRevisionId: 'forever-original-pr-set-anchor-v1',
  toRole: CycleRole.anchor,
  status: CompatibilityStatus.recommended,
  allowedFrequencies: [4],
  trainingMaxCompatibility: 'preserve-per-lift',
  requiredEquipment: [],
  source: RuleSource(document: '5/3/1 Forever', location: 'PDF pages 180-182'),
);

/// Historical constant alias retained for clients that referenced the old
/// pairing name. Its value now has explicit transition semantics.
const foreverOriginalFslPairing = foreverOriginalFslLeaderTransition;

typedef CycleTemplateRevision = CycleRevision;

class ProtocolTemplateRevision {
  const ProtocolTemplateRevision({
    required this.id,
    required this.version,
    required this.purpose,
    required this.source,
  });

  final String id;
  final int version;
  final ProtocolPurpose purpose;
  final RuleSource source;
}

class CycleSelection {
  const CycleSelection({required this.instanceId, required this.revision});
  final String instanceId;
  final CycleTemplateRevision revision;
}

class ProtocolSelection {
  const ProtocolSelection({required this.revision, this.autoInserted = false});
  final ProtocolTemplateRevision revision;
  final bool autoInserted;
}

class MacrocycleSlotDefinition {
  const MacrocycleSlotDefinition({
    required this.slotId,
    required this.role,
    this.defaultsToSlotId,
  });

  final String slotId;
  final CycleRole role;
  final String? defaultsToSlotId;
}

class CycleSlotSelection {
  const CycleSlotSelection({
    required this.slotId,
    required this.cycleInstanceId,
    required this.revision,
  });

  final String slotId;
  final String cycleInstanceId;
  final CycleTemplateRevision revision;
}

class BoundaryProtocolRule {
  const BoundaryProtocolRule({
    required this.boundaryId,
    required this.afterSlotId,
    required this.protocol,
    required this.required,
    required this.source,
  });

  final String boundaryId;
  final String afterSlotId;
  final ProtocolTemplateRevision protocol;
  final bool required;
  final RuleSource source;
}

class MacrocycleRecipeRevision {
  const MacrocycleRecipeRevision({
    required this.id,
    required this.version,
    required this.kind,
    required this.source,
    required this.status,
    required this.slots,
    required this.boundaryProtocols,
  });
  final String id;
  final int version;
  final ForeverPlanKind kind;
  final RuleSource source;
  final CompatibilityStatus status;
  final List<MacrocycleSlotDefinition> slots;
  final List<BoundaryProtocolRule> boundaryProtocols;

  bool get isExecutable =>
      status != CompatibilityStatus.needsReview &&
      status != CompatibilityStatus.forbidden;
}

typedef MacrocycleRecipeDefinition = MacrocycleRecipeRevision;

typedef ForeverMacrocycleConfiguration = ForeverPlanningConfiguration;
typedef TrainingMaxProjection = TrainingMaxDecision;
typedef CompiledTrainingPlan = CompiledForeverSequence;

const foreverSeventhWeekDeloadRevision = ProtocolTemplateRevision(
  id: 'forever-seventh-week-deload-v1',
  version: 1,
  purpose: ProtocolPurpose.seventhWeekDeload,
  source: RuleSource(
    document: '5/3/1 Forever',
    location: 'PDF pages 31 and 33',
  ),
);

const foreverSeventhWeekTrainingMaxTestRevision = ProtocolTemplateRevision(
  id: 'forever-seventh-week-tm-test-v1',
  version: 1,
  purpose: ProtocolPurpose.seventhWeekTrainingMaxTest,
  source: RuleSource(document: '5/3/1 Forever', location: 'PDF pages 31-33'),
);

const foreverTwoLeadersOneAnchorRecipe = MacrocycleRecipeRevision(
  id: 'forever-2l1a-v2',
  version: 2,
  kind: ForeverPlanKind.macrocycle,
  source: RuleSource(
    document: '5/3/1 Forever',
    location: 'PDF pages 29-33 and 180-182',
  ),
  status: CompatibilityStatus.recommended,
  slots: [
    MacrocycleSlotDefinition(slotId: 'leader-1', role: CycleRole.leader),
    MacrocycleSlotDefinition(
      slotId: 'leader-2',
      role: CycleRole.leader,
      defaultsToSlotId: 'leader-1',
    ),
    MacrocycleSlotDefinition(slotId: 'anchor-1', role: CycleRole.anchor),
  ],
  boundaryProtocols: [
    BoundaryProtocolRule(
      boundaryId: 'leaders-to-anchor',
      afterSlotId: 'leader-2',
      protocol: foreverSeventhWeekDeloadRevision,
      required: true,
      source: RuleSource(
        document: '5/3/1 Forever',
        location: 'PDF pages 31 and 33',
      ),
    ),
    BoundaryProtocolRule(
      boundaryId: 'macrocycle-end',
      afterSlotId: 'anchor-1',
      protocol: foreverSeventhWeekTrainingMaxTestRevision,
      required: true,
      source: RuleSource(
        document: '5/3/1 Forever',
        location: 'PDF pages 31-33',
      ),
    ),
  ],
);

const foreverTwoLeadersTwoAnchorsRecipe = MacrocycleRecipeRevision(
  id: 'forever-2l2a-v1',
  version: 1,
  kind: ForeverPlanKind.macrocycle,
  source: RuleSource(document: 'NEEDS_REVIEW', location: 'NEEDS_REVIEW'),
  status: CompatibilityStatus.needsReview,
  slots: [],
  boundaryProtocols: [],
);

const foreverThreeLeadersTwoAnchorsRecipe = MacrocycleRecipeRevision(
  id: 'forever-3l2a-v1',
  version: 1,
  kind: ForeverPlanKind.macrocycle,
  source: RuleSource(document: 'NEEDS_REVIEW', location: 'NEEDS_REVIEW'),
  status: CompatibilityStatus.needsReview,
  slots: [],
  boundaryProtocols: [],
);

class ForeverMacrocycle {
  ForeverMacrocycle({
    required this.instanceId,
    required this.intent,
    required this.status,
    required this.recipe,
    required Iterable<CycleSlotSelection> cycleSelections,
    this.outcome,
    Map<String, double> trainingMaxChoices = const {},
  }) : cycleSelections = List.unmodifiable(cycleSelections),
       trainingMaxChoices = Map.unmodifiable(trainingMaxChoices);

  final String instanceId;
  final MacrocycleIntent intent;
  final MacrocycleStatus status;
  final MacrocycleRecipeRevision recipe;
  final List<CycleSlotSelection> cycleSelections;
  final MacrocycleOutcome? outcome;
  final Map<String, double> trainingMaxChoices;
}

class ForeverProgramSeries {
  ForeverProgramSeries({
    required this.id,
    required Iterable<ForeverMacrocycle> macrocycles,
    this.profile,
    this.terminated = false,
  }) : macrocycles = List.unmodifiable(macrocycles);

  final String id;
  final List<ForeverMacrocycle> macrocycles;
  final CommonTrainingProfile? profile;
  final bool terminated;

  ForeverProgramSeries append(ForeverMacrocycle macrocycle) =>
      ForeverProgramSeries(
        id: id,
        profile: profile,
        macrocycles: [...macrocycles, macrocycle],
        terminated: terminated,
      );
}

ForeverProgramSeries createForeverOriginalFslSeries({
  required CommonTrainingProfile profile,
  String seriesId = 'forever-original-fsl-series',
  String macrocycleInstanceId = 'M1',
  CycleRevision firstLeader = foreverOriginalFslLeaderRevision,
  CycleRevision? secondLeader,
  CycleRevision anchor = foreverOriginalPrSetAnchorRevision,
}) => ForeverProgramSeries(
  id: seriesId,
  profile: profile,
  macrocycles: [
    ForeverMacrocycle(
      instanceId: macrocycleInstanceId,
      intent: MacrocycleIntent.active,
      status: MacrocycleStatus.active,
      recipe: foreverTwoLeadersOneAnchorRecipe,
      cycleSelections: [
        CycleSlotSelection(
          slotId: 'leader-1',
          cycleInstanceId: '$macrocycleInstanceId-leader-1',
          revision: firstLeader,
        ),
        CycleSlotSelection(
          slotId: 'leader-2',
          cycleInstanceId: '$macrocycleInstanceId-leader-2',
          revision: secondLeader ?? firstLeader,
        ),
        CycleSlotSelection(
          slotId: 'anchor-1',
          cycleInstanceId: '$macrocycleInstanceId-anchor-1',
          revision: anchor,
        ),
      ],
    ),
  ],
);

class MacrocycleOutcome {
  MacrocycleOutcome({
    required this.macrocycleInstanceId,
    required Map<String, TrainingMaxDecisionState> trainingMaxStates,
  }) : trainingMaxStates = Map.unmodifiable(trainingMaxStates);

  final String macrocycleInstanceId;
  final Map<String, TrainingMaxDecisionState> trainingMaxStates;
}

class MacrocycleContinuationProposal {
  const MacrocycleContinuationProposal({
    required this.mode,
    required this.macrocycle,
  });

  final ContinuationMode mode;
  final ForeverMacrocycle? macrocycle;
}

class MacrocycleSeriesValidator {
  const MacrocycleSeriesValidator();

  PlanningValidationResult validate(ForeverProgramSeries series) {
    final issues = <PlanningIssue>[];
    if (series.macrocycles.isEmpty) {
      issues.add(
        const PlanningIssue(
          code: 'series.empty',
          path: 'macrocycles',
          message: 'A series must contain at least one macrocycle.',
        ),
      );
    }
    final ids = <String>{};
    var activeCount = 0;
    var plannedCount = 0;
    var sawActive = false;
    var sawPlanned = false;
    for (var index = 0; index < series.macrocycles.length; index++) {
      final macrocycle = series.macrocycles[index];
      final path = 'macrocycles[$index]';
      if (!ids.add(macrocycle.instanceId)) {
        issues.add(
          PlanningIssue(
            code: 'series.duplicate_macrocycle_id',
            path: '$path.instanceId',
            message: 'Macrocycle instance identifiers must be unique.',
          ),
        );
      }
      if (!macrocycle.recipe.isExecutable) {
        issues.add(
          PlanningIssue(
            code: macrocycle.recipe.status == CompatibilityStatus.needsReview
                ? 'recipe.needs_review'
                : 'recipe.forbidden',
            path: '$path.recipe',
            message: 'An unreviewed or forbidden recipe cannot be executed.',
          ),
        );
      }
      final isHistory =
          macrocycle.status == MacrocycleStatus.completed ||
          macrocycle.status == MacrocycleStatus.cancelled;
      final isActive = macrocycle.status == MacrocycleStatus.active;
      final isPlanned = macrocycle.status == MacrocycleStatus.planned;
      final hasHistoricalIntent = macrocycle.intent == MacrocycleIntent.active;
      final hasProjectedIntent =
          macrocycle.intent == MacrocycleIntent.projected;

      if (isHistory && !hasHistoricalIntent) {
        issues.add(
          PlanningIssue(
            code: 'series.history_must_be_active_intent',
            path: '$path.intent',
            message:
                'Completed and cancelled macrocycles belong to immutable active history.',
          ),
        );
      }
      if (isActive && !hasHistoricalIntent) {
        issues.add(
          PlanningIssue(
            code: 'series.active_status_must_be_active_intent',
            path: '$path.intent',
            message: 'An active macrocycle must have active intent.',
          ),
        );
      }
      if (isPlanned && !hasProjectedIntent) {
        issues.add(
          PlanningIssue(
            code: 'series.planned_status_must_be_projected_intent',
            path: '$path.intent',
            message: 'A planned macrocycle must have projected intent.',
          ),
        );
      }
      if (hasProjectedIntent && !isPlanned) {
        issues.add(
          PlanningIssue(
            code: 'series.projected_intent_must_be_planned',
            path: '$path.status',
            message: 'Projected intent is only valid for a planned macrocycle.',
          ),
        );
      }

      if (isHistory && (sawActive || sawPlanned)) {
        issues.add(
          PlanningIssue(
            code: 'series.history_after_current_or_future',
            path: '$path.status',
            message:
                'Historical macrocycles must precede the active and planned macrocycles.',
          ),
        );
      }
      if (isActive) {
        activeCount++;
        if (activeCount > 1) {
          issues.add(
            PlanningIssue(
              code: 'series.multiple_active',
              path: '$path.status',
              message: 'A series may contain at most one active macrocycle.',
            ),
          );
        }
        if (sawPlanned) {
          issues.add(
            PlanningIssue(
              code: 'series.active_after_planned',
              path: '$path.status',
              message:
                  'An active macrocycle cannot follow a planned macrocycle.',
            ),
          );
        }
        sawActive = true;
      }
      if (isPlanned) {
        plannedCount++;
        if (plannedCount > 1) {
          issues.add(
            PlanningIssue(
              code: 'series.multiple_planned',
              path: '$path.status',
              message: 'A series may contain at most one planned macrocycle.',
            ),
          );
        }
        sawPlanned = true;
      }
      final selections = {
        for (final selection in macrocycle.cycleSelections)
          selection.slotId: selection,
      };
      if (selections.length != macrocycle.cycleSelections.length) {
        issues.add(
          PlanningIssue(
            code: 'macrocycle.duplicate_slot',
            path: '$path.cycleSelections',
            message: 'Each recipe slot may be selected only once.',
          ),
        );
      }
      for (final slot in macrocycle.recipe.slots) {
        if (!selections.containsKey(slot.slotId)) {
          issues.add(
            PlanningIssue(
              code: 'macrocycle.slot_missing',
              path: '$path.cycleSelections.${slot.slotId}',
              message: 'Every recipe slot requires a cycle selection.',
            ),
          );
        }
      }
      for (final selection in macrocycle.cycleSelections) {
        if (!macrocycle.recipe.slots.any(
          (slot) => slot.slotId == selection.slotId,
        )) {
          issues.add(
            PlanningIssue(
              code: 'macrocycle.unknown_slot',
              path: '$path.cycleSelections.${selection.slotId}',
              message: 'The selection does not belong to the recipe.',
            ),
          );
        }
        final slot = macrocycle.recipe.slots
            .where((item) => item.slotId == selection.slotId)
            .firstOrNull;
        if (slot == null) continue;
        final expectedRevision = slot.role == CycleRole.leader
            ? foreverOriginalFslLeaderRevision
            : foreverOriginalPrSetAnchorRevision;
        if (selection.revision != expectedRevision) {
          issues.add(
            PlanningIssue(
              code: 'transition.template_revision_not_allowed',
              path: '$path.cycleSelections.${selection.slotId}.revision',
              message:
                  'The selected cycle revision is not allowed for this role.',
            ),
          );
        }
      }
      final firstLeader = selections['leader-1'];
      final secondLeader = selections['leader-2'];
      if (firstLeader != null &&
          secondLeader != null &&
          firstLeader.revision != secondLeader.revision) {
        issues.add(
          PlanningIssue(
            code: 'forever.second_leader_revision_mismatch',
            path: '$path.cycleSelections.leader-2',
            message:
                'The sourced 2L/1A recipe requires identical Leader revisions.',
          ),
        );
      }
    }
    if (series.terminated &&
        series.macrocycles.any(
          (item) => item.intent == MacrocycleIntent.projected,
        )) {
      issues.add(
        const PlanningIssue(
          code: 'series.terminated_has_future',
          path: 'terminated',
          message: 'A terminated series cannot retain projected macrocycles.',
        ),
      );
    }
    return PlanningValidationResult(issues);
  }
}

abstract interface class ForeverProgramCompiler {
  CompiledForeverSequence compileSeries(ForeverProgramSeries series);
}

enum ForeverPrescriptionKind {
  mainWork,
  performanceSet,
  supplemental,
  trainingMaxTest,
}

class ForeverSetPrescription {
  const ForeverSetPrescription({
    required this.percentage,
    required this.repetitions,
    required this.kind,
    required this.ruleId,
    required this.source,
  });

  final double percentage;
  final int repetitions;
  final ForeverPrescriptionKind kind;
  final String ruleId;
  final RuleSource source;
}

class ForeverCycleStrategy {
  ForeverCycleStrategy({
    required this.revision,
    required this.role,
    required Iterable<Iterable<ForeverSetPrescription>> weeks,
  }) : weeks = List.unmodifiable(
         weeks.map((week) => List<ForeverSetPrescription>.unmodifiable(week)),
       );

  final CycleTemplateRevision revision;
  final CycleRole role;
  final List<List<ForeverSetPrescription>> weeks;
}

class ForeverProtocolStrategy {
  ForeverProtocolStrategy({
    required this.revision,
    required Iterable<ForeverSetPrescription> prescriptions,
    required this.isTrainingMaxTest,
  }) : prescriptions = List.unmodifiable(prescriptions);

  final ProtocolTemplateRevision revision;
  final List<ForeverSetPrescription> prescriptions;
  final bool isTrainingMaxTest;
}

class CycleStrategyRegistry {
  const CycleStrategyRegistry();

  CycleTemplateRevision? resolve(String revisionId) => switch (revisionId) {
    'forever-original-fsl-leader-v1' => foreverOriginalFslLeaderRevision,
    'forever-original-pr-set-anchor-v1' => foreverOriginalPrSetAnchorRevision,
    _ => null,
  };

  ForeverCycleStrategy? resolveStrategy(
    String revisionId, {
    required CycleRole role,
  }) {
    final revision = resolve(revisionId);
    if (revision == null) return null;
    if (role == CycleRole.leader &&
        revisionId == foreverOriginalFslLeaderRevision.id) {
      return ForeverCycleStrategy(
        revision: revision,
        role: role,
        weeks: _foreverLeaderPrescriptionWeeks,
      );
    }
    if (role == CycleRole.anchor &&
        revisionId == foreverOriginalPrSetAnchorRevision.id) {
      return ForeverCycleStrategy(
        revision: revision,
        role: role,
        weeks: _foreverAnchorPrescriptionWeeks,
      );
    }
    return null;
  }
}

class ProtocolStrategyRegistry {
  const ProtocolStrategyRegistry();

  ProtocolTemplateRevision? resolve(String revisionId) => switch (revisionId) {
    'forever-seventh-week-deload-v1' => foreverSeventhWeekDeloadRevision,
    'forever-seventh-week-tm-test-v1' =>
      foreverSeventhWeekTrainingMaxTestRevision,
    _ => null,
  };

  ForeverProtocolStrategy? resolveStrategy(String revisionId) {
    final revision = resolve(revisionId);
    if (revision == null) return null;
    if (revisionId == foreverSeventhWeekDeloadRevision.id) {
      return ForeverProtocolStrategy(
        revision: revision,
        prescriptions: _foreverDeloadPrescriptions,
        isTrainingMaxTest: false,
      );
    }
    if (revisionId == foreverSeventhWeekTrainingMaxTestRevision.id) {
      return ForeverProtocolStrategy(
        revision: revision,
        prescriptions: _foreverTrainingMaxTestPrescriptions,
        isTrainingMaxTest: true,
      );
    }
    return null;
  }
}

ForeverSetPrescription _foreverSet({
  required double percentage,
  required int repetitions,
  required ForeverPrescriptionKind kind,
  required String ruleId,
  required RuleSource source,
}) => ForeverSetPrescription(
  percentage: percentage,
  repetitions: repetitions,
  kind: kind,
  ruleId: ruleId,
  source: source,
);

final List<List<ForeverSetPrescription>> _foreverLeaderPrescriptionWeeks = [
  _foreverWorkWeek(1, const [(0.70, 3), (0.80, 3), (0.90, 3)], true, 0.70),
  _foreverWorkWeek(2, const [(0.65, 5), (0.75, 5), (0.85, 5)], false, 0.65),
  _foreverWorkWeek(3, const [(0.75, 5), (0.85, 3), (0.95, 1)], true, 0.75),
];

final List<List<ForeverSetPrescription>> _foreverAnchorPrescriptionWeeks = [
  _foreverAnchorWeek(1, const [(0.65, 5), (0.75, 5), (0.85, 5)]),
  _foreverAnchorWeek(2, const [(0.70, 3), (0.80, 3), (0.90, 3)]),
  _foreverAnchorWeek(3, const [(0.75, 5), (0.85, 3), (0.95, 1)]),
];

List<ForeverSetPrescription> _foreverWorkWeek(
  int week,
  List<(double, int)> main,
  bool performance,
  double fslPercentage,
) => [
  for (final set in main.indexed)
    _foreverSet(
      percentage: set.$2.$1,
      repetitions: set.$2.$2,
      kind: performance && set.$1 == main.length - 1
          ? ForeverPrescriptionKind.performanceSet
          : ForeverPrescriptionKind.mainWork,
      ruleId: 'FOREVER-ORIGINAL-FSL-L-W$week-M${set.$1 + 1}',
      source: foreverOriginalMainWorkRevision.source,
    ),
  for (var set = 1; set <= 5; set++)
    _foreverSet(
      percentage: fslPercentage,
      repetitions: 5,
      kind: ForeverPrescriptionKind.supplemental,
      ruleId: 'FOREVER-ORIGINAL-FSL-L-W$week-FSL-$set',
      source: foreverFirstSetLastRevision.source,
    ),
];

List<ForeverSetPrescription> _foreverAnchorWeek(
  int week,
  List<(double, int)> main,
) => [
  for (final set in main.indexed)
    _foreverSet(
      percentage: set.$2.$1,
      repetitions: set.$2.$2,
      kind: set.$1 == main.length - 1
          ? ForeverPrescriptionKind.performanceSet
          : ForeverPrescriptionKind.mainWork,
      ruleId: 'FOREVER-ORIGINAL-FSL-A-W$week-M${set.$1 + 1}',
      source: foreverOriginalPrSetRevision.source,
    ),
];

final List<ForeverSetPrescription> _foreverDeloadPrescriptions = [
  for (final set in const [(0.70, 5), (0.80, 3), (0.90, 1), (1.0, 1)].indexed)
    _foreverSet(
      percentage: set.$2.$1,
      repetitions: set.$2.$2,
      kind: ForeverPrescriptionKind.mainWork,
      ruleId: const [
        'FOREVER-7W-DELOAD-70',
        'FOREVER-7W-DELOAD-80',
        'FOREVER-7W-DELOAD-90',
        'FOREVER-7W-DELOAD-TM',
      ][set.$1],
      source: foreverSeventhWeekDeloadRevision.source,
    ),
];

final List<ForeverSetPrescription> _foreverTrainingMaxTestPrescriptions = [
  for (final set in const [(0.70, 5), (0.80, 5), (0.90, 5), (1.0, 3)].indexed)
    _foreverSet(
      percentage: set.$2.$1,
      repetitions: set.$2.$2,
      kind: ForeverPrescriptionKind.trainingMaxTest,
      ruleId: const [
        'FOREVER-7W-TMTEST-70',
        'FOREVER-7W-TMTEST-80',
        'FOREVER-7W-TMTEST-90',
        'FOREVER-7W-TMTEST-TM',
      ][set.$1],
      source: foreverSeventhWeekTrainingMaxTestRevision.source,
    ),
];

List<PlanningIssue> _validateTrainingProfile(CommonTrainingProfile profile) {
  final issues = <PlanningIssue>[];
  if (profile.trainingDaysPerWeek != 4) {
    issues.add(
      const PlanningIssue(
        code: 'profile.frequency_not_supported',
        path: 'profile.trainingDaysPerWeek',
        message: 'The sourced Original + FSL recipe requires four days.',
      ),
    );
  }
  if (profile.trainingMaxes.isEmpty) {
    issues.add(
      const PlanningIssue(
        code: 'profile.training_maxes_empty',
        path: 'profile.trainingMaxes',
        message: 'At least one Training Max is required.',
      ),
    );
  }
  for (final entry in profile.trainingMaxes.entries) {
    if (entry.value <= 0) {
      issues.add(
        PlanningIssue(
          code: 'profile.training_max_invalid',
          path: 'profile.trainingMaxes.${entry.key}',
          message: 'Training Maxes must be positive.',
        ),
      );
    }
    final increment = profile.progressionIncrements[entry.key];
    if (increment == null || increment <= 0) {
      issues.add(
        PlanningIssue(
          code: 'profile.progression_increment_invalid',
          path: 'profile.progressionIncrements.${entry.key}',
          message: 'Every Training Max needs a positive progression increment.',
        ),
      );
    }
  }
  return issues;
}

class ForeverSequenceCompiler implements ForeverProgramCompiler {
  const ForeverSequenceCompiler({
    this.cycleStrategies = const CycleStrategyRegistry(),
    this.protocolStrategies = const ProtocolStrategyRegistry(),
  });

  final CycleStrategyRegistry cycleStrategies;
  final ProtocolStrategyRegistry protocolStrategies;

  PlanningValidationResult validate(
    ForeverPlanningConfiguration configuration,
  ) {
    final issues = <PlanningIssue>[
      ..._validateTrainingProfile(configuration.profile),
    ];
    if (configuration.kind == ForeverPlanKind.macrocycle &&
        configuration.series == null) {
      issues.add(
        const PlanningIssue(
          code: 'forever.kind_requires_series',
          path: 'kind',
          message: 'Macrocycle planning requires a series.',
        ),
      );
    }
    if (configuration.kind == ForeverPlanKind.standaloneProgram &&
        configuration.standaloneProgramId == null) {
      issues.add(
        const PlanningIssue(
          code: 'forever.kind_requires_standalone',
          path: 'kind',
          message:
              'Standalone planning requires a standalone program identifier.',
        ),
      );
    }
    if (configuration.series != null) {
      issues.addAll(
        const MacrocycleSeriesValidator()
            .validate(configuration.series!)
            .issues,
      );
    }
    return PlanningValidationResult(issues);
  }

  CompiledForeverSequence compile(ForeverPlanningConfiguration configuration) {
    final validation = validate(configuration);
    if (!validation.isValid) throw ForeverCompilationException(validation);

    if (configuration.series == null) {
      throw ForeverCompilationException(
        PlanningValidationResult(const [
          PlanningIssue(
            code: 'forever.standalone_not_a_series',
            path: 'standaloneProgramId',
            message: 'Standalone programs are generated without a series.',
          ),
        ]),
      );
    }
    final series = configuration.series!;
    return compileSeries(
      ForeverProgramSeries(
        id: series.id,
        profile: series.profile ?? configuration.profile,
        macrocycles: series.macrocycles,
        terminated: series.terminated,
      ),
    );
  }

  List<ForeverPlanNode> compileStructure(
    ForeverPlanningConfiguration configuration,
  ) => compile(configuration).nodes;

  @override
  CompiledForeverSequence compileSeries(ForeverProgramSeries series) {
    final validation = const MacrocycleSeriesValidator().validate(series);
    final profile = series.profile;
    final issues = [...validation.issues];
    if (profile == null) {
      issues.add(
        const PlanningIssue(
          code: 'series.profile_missing',
          path: 'profile',
          message: 'A compilable series requires a training profile.',
        ),
      );
    } else {
      issues.addAll(_validateTrainingProfile(profile));
    }
    if (issues.any(
      (issue) => issue.severity == PlanningIssueSeverity.blocking,
    )) {
      throw ForeverCompilationException(PlanningValidationResult(issues));
    }
    for (
      var macrocycleIndex = 0;
      macrocycleIndex < series.macrocycles.length;
      macrocycleIndex++
    ) {
      final macrocycle = series.macrocycles[macrocycleIndex];
      for (final selection in macrocycle.cycleSelections) {
        final slot = macrocycle.recipe.slots.singleWhere(
          (item) => item.slotId == selection.slotId,
        );
        if (cycleStrategies.resolveStrategy(
              selection.revision.id,
              role: slot.role,
            ) ==
            null) {
          issues.add(
            PlanningIssue(
              code: 'strategy.cycle_not_registered',
              path:
                  'macrocycles[$macrocycleIndex].cycleSelections.${selection.slotId}',
              message: 'The cycle revision has no sourced executable strategy.',
            ),
          );
        }
      }
      for (final boundary in macrocycle.recipe.boundaryProtocols.where(
        (rule) => rule.required,
      )) {
        final strategy = protocolStrategies.resolveStrategy(
          boundary.protocol.id,
        );
        if (strategy == null ||
            strategy.revision.purpose != boundary.protocol.purpose) {
          issues.add(
            PlanningIssue(
              code: 'strategy.protocol_not_registered',
              path:
                  'macrocycles[$macrocycleIndex].recipe.boundaryProtocols.${boundary.boundaryId}',
              message:
                  'The protocol revision has no sourced executable strategy.',
            ),
          );
        }
      }
    }
    if (issues.any(
      (issue) => issue.severity == PlanningIssueSeverity.blocking,
    )) {
      throw ForeverCompilationException(PlanningValidationResult(issues));
    }
    final nodes = <ForeverPlanNode>[];
    final decisions = <TrainingMaxDecision>[];
    var current = profile!.trainingMaxes;
    for (final macrocycle in series.macrocycles) {
      ForeverCycleNode? lastCycleNode;
      var cycleIndex = 0;
      for (final slot in macrocycle.recipe.slots) {
        final selection = macrocycle.cycleSelections.singleWhere(
          (item) => item.slotId == slot.slotId,
        );
        final nodeId = '${macrocycle.instanceId}-C${++cycleIndex}';
        final resolvedRevision = cycleStrategies
            .resolveStrategy(selection.revision.id, role: slot.role)!
            .revision;
        lastCycleNode = ForeverCycleNode(
          nodeId: nodeId,
          source: macrocycle.recipe.source,
          templateRevisionId: resolvedRevision.id,
          cycleInstanceId: selection.cycleInstanceId,
          role: slot.role,
          revision: resolvedRevision,
        );
        nodes.add(lastCycleNode);
        for (final boundary in macrocycle.recipe.boundaryProtocols.where(
          (rule) => rule.afterSlotId == slot.slotId && rule.required,
        )) {
          nodes.add(
            ForeverProtocolNode(
              nodeId:
                  '${macrocycle.instanceId}-P${nodes.whereType<ForeverProtocolNode>().length + 1}',
              source: boundary.source,
              templateRevisionId: protocolStrategies
                  .resolve(boundary.protocol.id)!
                  .id,
              autoInserted: true,
              purpose: boundary.protocol.purpose,
              afterCycleInstanceId: selection.cycleInstanceId,
            ),
          );
        }
      }
      final proposed = macrocycle.trainingMaxChoices.isNotEmpty
          ? {...current, ...macrocycle.trainingMaxChoices}
          : macrocycle.intent == MacrocycleIntent.projected
          ? {
              for (final entry in current.entries)
                entry.key:
                    entry.value + profile.progressionIncrements[entry.key]!,
            }
          : current;
      final fallbackState = macrocycle.intent == MacrocycleIntent.projected
          ? TrainingMaxDecisionState.projected
          : TrainingMaxDecisionState.confirmed;
      final outcomeStates = macrocycle.outcome?.trainingMaxStates ?? const {};
      final states = <String, TrainingMaxDecisionState>{
        for (final lift in current.keys)
          lift: outcomeStates[lift] ?? fallbackState,
      };
      decisions.add(
        TrainingMaxDecision(
          nodeId: lastCycleNode!.nodeId,
          cycleInstanceId: macrocycle.instanceId,
          states: states,
          previousTrainingMaxes: current,
          proposedTrainingMaxes: proposed,
        ),
      );
      current = proposed;
    }
    return CompiledForeverSequence(
      nodes: nodes,
      trainingMaxDecisions: decisions,
    );
  }

  MacrocycleContinuationProposal proposeNextMacrocycle({
    required ForeverProgramSeries series,
    required ContinuationMode mode,
    ForeverMacrocycle? editedMacrocycle,
    bool incrementConfirmed = false,
    int maximumMacrocycles = 24,
  }) {
    final validation = const MacrocycleSeriesValidator().validate(series);
    if (!validation.isValid) throw ForeverCompilationException(validation);
    if (series.terminated || mode == ContinuationMode.manual) {
      return MacrocycleContinuationProposal(mode: mode, macrocycle: null);
    }
    if (!incrementConfirmed) {
      throw ForeverCompilationException(
        PlanningValidationResult(const [
          PlanningIssue(
            code: 'series.increment_confirmation_required',
            path: 'confirmation',
            message:
                'Adding the next macrocycle requires explicit confirmation.',
          ),
        ]),
      );
    }
    if (series.macrocycles.length >= maximumMacrocycles) {
      throw ForeverCompilationException(
        PlanningValidationResult(const [
          PlanningIssue(
            code: 'series.increment_limit_reached',
            path: 'macrocycles',
            message: 'The configured finite series limit has been reached.',
          ),
        ]),
      );
    }
    final last = series.macrocycles.last;
    if (last.status != MacrocycleStatus.completed) {
      throw ForeverCompilationException(
        PlanningValidationResult(const [
          PlanningIssue(
            code: 'series.previous_not_completed',
            path: 'macrocycles',
            message: 'Only a completed macrocycle can be extended.',
          ),
        ]),
      );
    }
    final candidate = mode == ContinuationMode.cloneAndEdit
        ? editedMacrocycle
        : ForeverMacrocycle(
            instanceId: 'M${series.macrocycles.length + 1}',
            intent: MacrocycleIntent.projected,
            status: MacrocycleStatus.planned,
            recipe: last.recipe,
            cycleSelections: [
              for (final selection in last.cycleSelections)
                CycleSlotSelection(
                  slotId: selection.slotId,
                  cycleInstanceId:
                      'M${series.macrocycles.length + 1}-${selection.slotId}',
                  revision: selection.revision,
                ),
            ],
          );
    if (candidate == null ||
        candidate.intent != MacrocycleIntent.projected ||
        candidate.status != MacrocycleStatus.planned) {
      throw ForeverCompilationException(
        PlanningValidationResult(const [
          PlanningIssue(
            code: 'series.invalid_continuation',
            path: 'macrocycle',
            message:
                'The next macrocycle must be a projected planned macrocycle.',
          ),
        ]),
      );
    }
    final candidateValidation = const MacrocycleSeriesValidator().validate(
      series.append(candidate),
    );
    if (!candidateValidation.isValid) {
      throw ForeverCompilationException(candidateValidation);
    }
    return MacrocycleContinuationProposal(mode: mode, macrocycle: candidate);
  }

  ForeverProgramSeries regenerateFuture({
    required ForeverProgramSeries series,
    required Iterable<ForeverMacrocycle> future,
  }) {
    final history = series.macrocycles
        .where(
          (macrocycle) =>
              macrocycle.intent == MacrocycleIntent.active ||
              macrocycle.status == MacrocycleStatus.completed ||
              macrocycle.status == MacrocycleStatus.cancelled,
        )
        .toList(growable: false);
    final replacements = future.toList(growable: false);
    if (replacements.any(
      (macrocycle) =>
          macrocycle.intent != MacrocycleIntent.projected ||
          macrocycle.status != MacrocycleStatus.planned,
    )) {
      throw ForeverCompilationException(
        PlanningValidationResult(const [
          PlanningIssue(
            code: 'series.regeneration_not_future',
            path: 'macrocycles',
            message:
                'Regeneration may only create projected planned macrocycles.',
          ),
        ]),
      );
    }
    final regenerated = ForeverProgramSeries(
      id: series.id,
      profile: series.profile,
      macrocycles: [...history, ...replacements],
      terminated: series.terminated,
    );
    final validation = const MacrocycleSeriesValidator().validate(regenerated);
    if (!validation.isValid) {
      throw ForeverCompilationException(validation);
    }
    return regenerated;
  }

  Map<String, double> confirmTrainingMaxes({
    required CommonTrainingProfile profile,
    required Map<String, double> currentTrainingMaxes,
    required Map<String, TrainingMaxChoice> choices,
  }) {
    final resolved = <String, double>{};
    for (final entry in currentTrainingMaxes.entries) {
      final choice = choices[entry.key];
      final increment = profile.progressionIncrements[entry.key];
      if (choice == null || increment == null || increment <= 0) {
        throw ArgumentError('Every lift requires a sourced TM choice.');
      }
      if (choice.state == TrainingMaxDecisionState.projected ||
          choice.state == TrainingMaxDecisionState.proposed) {
        throw ArgumentError('A projected or proposed TM is not confirmed.');
      }
      if (choice.value <= 0 || choice.value > entry.value + increment) {
        throw ArgumentError(
          'A TM may not exceed the source-defined increment.',
        );
      }
      if (choice.state == TrainingMaxDecisionState.held &&
          choice.value != entry.value) {
        throw ArgumentError('A held TM must equal the current TM.');
      }
      resolved[entry.key] = choice.value;
    }
    if (choices.keys.any((lift) => !currentTrainingMaxes.containsKey(lift))) {
      throw ArgumentError('A TM choice references an unknown lift.');
    }
    return Map.unmodifiable(resolved);
  }
}
