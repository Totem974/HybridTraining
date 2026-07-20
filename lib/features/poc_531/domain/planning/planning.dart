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

class PairingRule {
  const PairingRule({
    required this.id,
    required this.mainWorkRevision,
    required this.supplementalWorkRevision,
    required this.source,
  });

  final String id;
  final ProgramRevision mainWorkRevision;
  final ProgramRevision supplementalWorkRevision;
  final RuleSource source;

  CompatibilityResult evaluate(CycleRevision revision) {
    final issues = <PlanningIssue>[];
    if (revision.mainWork != mainWorkRevision) {
      issues.add(
        const PlanningIssue(
          code: 'pairing.main_work_not_supported',
          path: 'mainWork',
          message: 'Only the sourced Original main-work revision is supported.',
        ),
      );
    }
    if (revision.supplementalWork != supplementalWorkRevision) {
      issues.add(
        const PlanningIssue(
          code: 'pairing.supplemental_not_supported',
          path: 'supplementalWork',
          message: 'Only the sourced First Set Last revision is supported.',
        ),
      );
    }
    return CompatibilityResult(issues);
  }
}

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
    required this.state,
    required Map<String, double> previousTrainingMaxes,
    required Map<String, double> proposedTrainingMaxes,
  }) : previousTrainingMaxes = Map.unmodifiable(previousTrainingMaxes),
       proposedTrainingMaxes = Map.unmodifiable(proposedTrainingMaxes);

  final String nodeId;
  final String cycleInstanceId;
  final TrainingMaxDecisionState state;
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

const foreverOriginalFslPairing = PairingRule(
  id: 'forever-original-plus-fsl-v1',
  mainWorkRevision: foreverOriginalMainWorkRevision,
  supplementalWorkRevision: foreverFirstSetLastRevision,
  source: RuleSource(document: '5/3/1 Forever', location: 'PDF pages 180-182'),
);

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

class ForeverMacrocycle {
  ForeverMacrocycle({
    required this.instanceId,
    required this.intent,
    required this.status,
    required this.recipe,
    required Iterable<CycleSlotSelection> cycleSelections,
  }) : cycleSelections = List.unmodifiable(cycleSelections);

  final String instanceId;
  final MacrocycleIntent intent;
  final MacrocycleStatus status;
  final MacrocycleRecipeRevision recipe;
  final List<CycleSlotSelection> cycleSelections;
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
    var sawProjected = false;
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
      if (sawProjected && macrocycle.intent == MacrocycleIntent.active) {
        issues.add(
          PlanningIssue(
            code: 'series.active_after_projected',
            path: '$path.intent',
            message:
                'An active macrocycle cannot follow a projected macrocycle.',
          ),
        );
      }
      sawProjected =
          sawProjected || macrocycle.intent == MacrocycleIntent.projected;
      if (macrocycle.status == MacrocycleStatus.completed &&
          macrocycle.intent != MacrocycleIntent.active) {
        issues.add(
          PlanningIssue(
            code: 'series.completed_must_be_active',
            path: '$path.intent',
            message:
                'A completed macrocycle belongs to immutable active history.',
          ),
        );
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

class ForeverSequenceCompiler implements ForeverProgramCompiler {
  const ForeverSequenceCompiler();

  PlanningValidationResult validate(
    ForeverPlanningConfiguration configuration,
  ) {
    if (configuration.series != null) {
      final issues = [
        ...const MacrocycleSeriesValidator()
            .validate(configuration.series!)
            .issues,
      ];
      final profile = configuration.profile;
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
              message:
                  'Every Training Max needs a positive progression increment.',
            ),
          );
        }
      }
      return PlanningValidationResult(issues);
    }
    return PlanningValidationResult(const []);
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
              message:
                  'Every Training Max needs a positive progression increment.',
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
    var nodeIndex = 0;
    for (final macrocycle in series.macrocycles) {
      for (final slot in macrocycle.recipe.slots) {
        final selection = macrocycle.cycleSelections.singleWhere(
          (item) => item.slotId == slot.slotId,
        );
        final nodeId = '${macrocycle.instanceId}-C${++nodeIndex}';
        nodes.add(
          ForeverCycleNode(
            nodeId: nodeId,
            source: macrocycle.recipe.source,
            templateRevisionId: selection.revision.id,
            cycleInstanceId: selection.cycleInstanceId,
            role: slot.role,
            revision: selection.revision,
          ),
        );
        final proposed = {
          for (final entry in current.entries)
            entry.key: entry.value + profile.progressionIncrements[entry.key]!,
        };
        decisions.add(
          TrainingMaxDecision(
            nodeId: nodeId,
            cycleInstanceId: selection.cycleInstanceId,
            state: macrocycle.intent == MacrocycleIntent.projected
                ? TrainingMaxDecisionState.projected
                : TrainingMaxDecisionState.confirmed,
            previousTrainingMaxes: current,
            proposedTrainingMaxes: proposed,
          ),
        );
        current = proposed;
        for (final boundary in macrocycle.recipe.boundaryProtocols.where(
          (rule) => rule.afterSlotId == slot.slotId && rule.required,
        )) {
          nodes.add(
            ForeverProtocolNode(
              nodeId:
                  '${macrocycle.instanceId}-P${nodes.whereType<ForeverProtocolNode>().length + 1}',
              source: boundary.source,
              templateRevisionId: boundary.protocol.id,
              autoInserted: true,
              purpose: boundary.protocol.purpose,
              afterCycleInstanceId: selection.cycleInstanceId,
            ),
          );
        }
      }
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
