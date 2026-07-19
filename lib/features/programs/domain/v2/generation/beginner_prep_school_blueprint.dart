import '../../training_models.dart';
import '../program_domain.dart';
import 'forever_macrocycle_generator.dart';
import 'generated_training_plan.dart';

const beginnerPrepSchoolPresetId = 'forever-beginner-prep-school-v1';

class BeginnerPrepSchoolBlueprint {
  const BeginnerPrepSchoolBlueprint._();

  static ProgramBlueprintSnapshot create({
    required Map<MainLift, double> trainingMaxRatios,
    int cycleCount = 1,
  }) {
    if (cycleCount < 1) throw ArgumentError.value(cycleCount, 'cycleCount');
    for (final lift in MainLift.values) {
      final ratio = trainingMaxRatios[lift];
      if (ratio != .85 && ratio != .90) {
        throw ArgumentError('Each lift must explicitly use an 85% or 90% TM.');
      }
    }
    return ProgramBlueprintSnapshot(
      blueprint: _blueprint,
      blocks: [
        MacrocycleBlockDefinition(
          templateId: const BlockTemplateId('bps-leader'),
          role: BlockRole.leader,
          cycleCount: cycleCount,
          weeks: [
            _week(0, const [_a, _b, _a], trainingMaxRatios),
            _week(1, const [_b, _a, _b], trainingMaxRatios),
            _week(2, const [_a, _b, _a], trainingMaxRatios),
          ],
          rule: _rule('BPS-ROLE-001', 'Forever PDF 57'),
        ),
      ],
      canonicalJson: _canonical(trainingMaxRatios, cycleCount),
      allowedAssistanceSelections: const {
        'lower': {'kbSwingOrSnatch', 'dumbbellOrBodyweightSquat'},
        'push': {'pushUp', 'dip'},
        'pull': {'chinUpOrPullUp', 'invertedRow'},
        'core': {'abWheel', 'hangingLegRaise'},
      },
      allowedConditioningSelections: const {
        'run': {
          'oneToThreeMiles',
          'track100',
          'track200',
          'track400',
          'track800',
        },
      },
    );
  }

  static WeekTemplate _week(
    int week,
    List<List<MainLift>> pattern,
    Map<MainLift, double> ratios,
  ) => WeekTemplate(
    sessions: [
      for (final movements in pattern) _session(week, movements, ratios),
    ],
  );

  static SessionTemplate _session(
    int week,
    List<MainLift> movements,
    Map<MainLift, double> ratios,
  ) => SessionTemplate(
    blocks: [
      SessionBlockTemplate(
        kind: GeneratedSessionBlockKind.warmup,
        movements: const [],
        instructions: const [
          '3 rounds: 25 jumping jacks; 10 bodyweight squats; 10 mountain climbers per leg.',
        ],
      ),
      SessionBlockTemplate(
        kind: GeneratedSessionBlockKind.athletic,
        movements: const [],
        instructions: const [
          '10-20 contacts: box jump or standing broad jump; no depth jumps.',
        ],
      ),
      for (var index = 0; index < movements.length; index++) ...[
        SessionBlockTemplate(
          kind: GeneratedSessionBlockKind.mainWork,
          movements: [_main(movements[index], week)],
          instructions: const ['5\'s Pro; crisp speed and sound technique.'],
        ),
        SessionBlockTemplate(
          kind: GeneratedSessionBlockKind.supplemental,
          movements: [
            _supplemental(movements[index], week, ratios[movements[index]]!),
          ],
          instructions: const ['5x5; FSL at 90% TM, SSL at 85% TM.'],
        ),
        if (index == 0)
          SessionBlockTemplate(
            kind: GeneratedSessionBlockKind.transition,
            movements: const [],
            instructions: const [
              'Transition to the second barbell lift; excluded from the time target per lift.',
            ],
          ),
      ],
      SessionBlockTemplate(
        kind: GeneratedSessionBlockKind.assistance,
        movements: const [],
        instructions: const [
          'Circuit of 4 exercises for 3-5 rounds; target 20 minutes.',
          'Lower and push: 25-100 total reps; pull and core: 25-50 total reps.',
        ],
      ),
      SessionBlockTemplate(
        kind: GeneratedSessionBlockKind.conditioning,
        movements: const [],
        instructions: const [
          'Run 3 times per week for 1-3 miles, unless exempted by in-season sport.',
        ],
      ),
    ],
  );

  static MovementTemplate _main(MainLift lift, int week) => MovementTemplate(
    movement: lift,
    sets: [
      for (final percentage in _percentages[week])
        SetTemplate(
          percentage: percentage,
          repetitions: 5,
          kind: SetKind.main,
          rule: _rule('BPS-MAIN-00${week + 1}', 'Forever PDF 52'),
        ),
    ],
  );

  static MovementTemplate _supplemental(MainLift lift, int week, double ratio) {
    final percentage = _percentages[week][ratio == .85 ? 1 : 0];
    return MovementTemplate(
      movement: lift,
      sets: [
        for (var set = 0; set < 5; set++)
          SetTemplate(
            percentage: percentage,
            repetitions: 5,
            kind: SetKind.supplemental,
            rule: _rule(
              ratio == .85 ? 'BPS-SSL-001' : 'BPS-FSL-001',
              'Forever PDF 52',
            ),
          ),
      ],
    );
  }

  static ReviewedRule _rule(String id, String location) => ReviewedRule(
    id: id,
    status: RuleStatus.verified,
    source: RuleReference(
      document: '5/3/1 Forever',
      location: '$id; $location',
    ),
  );

  static Map<String, Object?> _canonical(
    Map<MainLift, double> ratios,
    int cycles,
  ) => {
    'id': beginnerPrepSchoolPresetId,
    'version': 1,
    'audience':
        'beginners, including high-school athletes and adults lacking a base',
    'trainingMaxRatios': {
      for (final lift in MainLift.values) lift.name: ratios[lift],
    },
    'schedule': {'daysPerWeek': 3, 'alternation': 'A-B-A / B-A-B'},
    'sessions': {
      'A': ['squat', 'benchPress'],
      'B': ['deadlift', 'overheadPress'],
    },
    'cycleCount': cycles,
    'duration': 'no fixed duration; continue while productive',
    'progression':
        'after each cycle; upper body max +5 lb, lower body max +10 lb; weaker squat/deadlift may use +5 lb, repeats or microloads',
    'exitCriteria': [
      'barbell work within prescribed time',
      'assistance circuit within 20 minutes',
      'run one mile',
      'jump and land correctly',
      'balanced training base',
    ],
    'references': ['5/3/1 Forever PDF 50-57', 'forever-program-catalog.md'],
  };

  static const _a = [MainLift.squat, MainLift.benchPress];
  static const _b = [MainLift.deadlift, MainLift.overheadPress];
  static const _percentages = [
    [.70, .80, .90],
    [.65, .75, .85],
    [.75, .85, .95],
  ];

  static final _blueprint = ProgramBlueprint(
    id: ProgramBlueprintId(beginnerPrepSchoolPresetId),
    version: ProgramVersion(1),
    revisionIds: [ProgramRevisionId('forever-beginner-prep-school-v1')],
    capabilities: {
      ProgramCapability.mainWork,
      ProgramCapability.supplementalWork,
      ProgramCapability.assistance,
      ProgramCapability.conditioning,
      ProgramCapability.athleticWork,
      ProgramCapability.multipleMainMovements,
    },
    trainingMaxPolicy: TrainingMaxPolicy(
      PolicyId('bps-tm'),
      ProgramVersion(1),
      ruleStatus: RuleStatus.verified,
    ),
    mainWorkPolicy: MainWorkPolicy(
      PolicyId('bps-main'),
      ProgramVersion(1),
      ruleStatus: RuleStatus.verified,
    ),
    supplementalPolicy: SupplementalPolicy(
      PolicyId('bps-supplemental'),
      ProgramVersion(1),
      ruleStatus: RuleStatus.verified,
    ),
    assistancePolicy: AssistancePolicy(
      PolicyId('bps-assistance'),
      ProgramVersion(1),
      ruleStatus: RuleStatus.verified,
    ),
    conditioningPolicy: ConditioningPolicy(
      PolicyId('bps-conditioning'),
      ProgramVersion(1),
      ruleStatus: RuleStatus.verified,
    ),
    athleticWorkPolicy: AthleticWorkPolicy(
      PolicyId('bps-athletic'),
      ProgramVersion(1),
      ruleStatus: RuleStatus.verified,
    ),
    schedulePolicy: SchedulePolicy(
      PolicyId('bps-schedule'),
      ProgramVersion(1),
      supportedFrequencies: {3},
      recommendedFrequency: 3,
      mainMovementsPerSession: 2,
      ruleStatus: RuleStatus.verified,
    ),
    blockTemplates: [
      BlockTemplate(
        id: BlockTemplateId('bps-leader'),
        role: BlockRole.leader,
        type: BlockType.cycle,
        sourceEdition: SourceEdition.forever,
        generation: MethodGeneration.forever,
      ),
    ],
    blockSequence: BlockSequence(
      blocks: [
        BlockSequenceEntry(templateId: BlockTemplateId('bps-leader'), order: 0),
      ],
    ),
    transitionPolicy: TransitionPolicy(
      PolicyId('bps-transition'),
      ProgramVersion(1),
      allowedTransitions: const {},
      ruleStatus: RuleStatus.verified,
    ),
    compatibility: CompatibilityConstraint(
      supportedFrequencies: {3},
      requiredCapabilities: {ProgramCapability.multipleMainMovements},
    ),
    implementationStatus: ImplementationStatus.available,
    generatorId: 'beginner-prep-school',
    sourceEdition: SourceEdition.forever,
    generation: MethodGeneration.forever,
    references: [
      RuleReference(document: '5/3/1 Forever', location: 'PDF 50-57'),
      RuleReference(
        document: 'forever-program-catalog.md',
        location: 'Beginner Prep School',
      ),
    ],
  );
}
