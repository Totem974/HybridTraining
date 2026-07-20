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
    required this.kind,
    required this.firstLeader,
    required this.secondLeader,
    required this.anchor,
  }) : super(mode: PlanningMode.forever);

  final ForeverPlanKind kind;
  final CycleRevision firstLeader;
  final CycleRevision secondLeader;
  final CycleRevision anchor;
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

const foreverOriginalFslCycleRevision = CycleRevision(
  id: 'forever-original-531-fsl-v1',
  version: 1,
  mainWork: foreverOriginalMainWorkRevision,
  supplementalWork: foreverFirstSetLastRevision,
);

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
    this.terminated = false,
  }) : macrocycles = List.unmodifiable(macrocycles);

  final String id;
  final List<ForeverMacrocycle> macrocycles;
  final bool terminated;
}

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

abstract interface class ForeverProgramCompiler {
  CompiledForeverSequence compileSeries(ForeverProgramSeries series);
}

class ForeverSequenceCompiler {
  const ForeverSequenceCompiler();

  static const _sequenceSource = RuleSource(
    document: '5/3/1 Forever',
    location: 'PDF pages 29-33 and 180-182',
  );
  static const _deloadSource = RuleSource(
    document: '5/3/1 Forever',
    location: 'PDF pages 31 and 33',
  );
  static const _testSource = RuleSource(
    document: '5/3/1 Forever',
    location: 'PDF pages 31-33',
  );

  PlanningValidationResult validate(
    ForeverPlanningConfiguration configuration,
  ) {
    final issues = <PlanningIssue>[];
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
    final revisions = <(String, CycleRevision)>[
      ('firstLeader', configuration.firstLeader),
      ('secondLeader', configuration.secondLeader),
      ('anchor', configuration.anchor),
    ];
    for (final entry in revisions) {
      for (final issue in foreverOriginalFslPairing.evaluate(entry.$2).issues) {
        issues.add(
          PlanningIssue(
            code: issue.code,
            path: '${entry.$1}.${issue.path}',
            message: issue.message,
            severity: issue.severity,
          ),
        );
      }
    }
    if (configuration.secondLeader != configuration.firstLeader) {
      issues.add(
        const PlanningIssue(
          code: 'forever.second_leader_revision_mismatch',
          path: 'secondLeader',
          message:
              'The sourced 2L/1A recipe requires identical Leader revisions.',
        ),
      );
    }
    return PlanningValidationResult(issues);
  }

  CompiledForeverSequence compile(ForeverPlanningConfiguration configuration) {
    final validation = validate(configuration);
    if (!validation.isValid) throw ForeverCompilationException(validation);

    final nodes = compileStructure(configuration);

    var current = configuration.profile.trainingMaxes;
    final decisions = <TrainingMaxDecision>[];
    for (final node in nodes.whereType<ForeverCycleNode>()) {
      final proposed = {
        for (final entry in current.entries)
          entry.key:
              entry.value +
              configuration.profile.progressionIncrements[entry.key]!,
      };
      decisions.add(
        TrainingMaxDecision(
          nodeId: node.nodeId,
          cycleInstanceId: node.cycleInstanceId,
          state: TrainingMaxDecisionState.projected,
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

  List<ForeverPlanNode> compileStructure(
    ForeverPlanningConfiguration configuration,
  ) => List.unmodifiable(<ForeverPlanNode>[
    ForeverCycleNode(
      nodeId: 'C1',
      templateRevisionId: 'forever-original-531-fsl-v1',
      cycleInstanceId: 'leader-1',
      role: CycleRole.leader,
      revision: configuration.firstLeader,
      source: _sequenceSource,
    ),
    ForeverCycleNode(
      nodeId: 'C2',
      templateRevisionId: 'forever-original-531-fsl-v1',
      cycleInstanceId: 'leader-2',
      role: CycleRole.leader,
      revision: configuration.secondLeader,
      source: _sequenceSource,
    ),
    const ForeverProtocolNode(
      nodeId: 'P1',
      templateRevisionId: 'forever-seventh-week-deload-v1',
      autoInserted: true,
      purpose: ProtocolPurpose.seventhWeekDeload,
      afterCycleInstanceId: 'leader-2',
      source: _deloadSource,
    ),
    ForeverCycleNode(
      nodeId: 'C3',
      templateRevisionId: 'forever-original-531-fsl-v1',
      cycleInstanceId: 'anchor-1',
      role: CycleRole.anchor,
      revision: configuration.anchor,
      source: _sequenceSource,
    ),
    const ForeverProtocolNode(
      nodeId: 'P2',
      templateRevisionId: 'forever-seventh-week-tm-test-v1',
      autoInserted: true,
      purpose: ProtocolPurpose.seventhWeekTrainingMaxTest,
      afterCycleInstanceId: 'anchor-1',
      source: _testSource,
    ),
  ]);
}
