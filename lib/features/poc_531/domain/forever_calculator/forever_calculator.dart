import 'dart:convert';

import '../core.dart' as core;
import '../planning/planning.dart' as planning;

export '../core.dart'
    show
        GeneratedProgram,
        Generation,
        GenerationSpecificOptions,
        LiftInput,
        LiftInputKind,
        MainLift,
        ProgramConfiguration,
        ProgramGenerationException,
        SourceProvenance,
        ValidationIssue,
        WeightUnit;

/// Position of a reviewed block in a fixed Forever sequence.
enum ForeverBlockKind { leader, seventhWeekDeload, anchor, seventhWeekTmTest }

/// Training Max behaviour explicitly supported by the reviewed Core v5 preset.
enum ForeverTrainingMaxPolicy {
  /// The user supplies an 85% or 90% ratio for the current BPS cycle.
  explicitEightyFiveOrNinety,

  /// Future Training Maxes must be confirmed at the declared checkpoints.
  confirmAtCheckpoints,
}

class ForeverSequenceBlock {
  const ForeverSequenceBlock({
    required this.kind,
    required this.startWeek,
    required this.durationWeeks,
    required this.source,
  });

  final ForeverBlockKind kind;
  final int startWeek;
  final int durationWeeks;
  final core.SourceProvenance source;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'startWeek': startWeek,
    'durationWeeks': durationWeeks,
    'source': source.toJson(),
  };
}

class ForeverCalculatorTemplate {
  const ForeverCalculatorTemplate({
    required this.id,
    required this.name,
    required this.variant,
    required this.selectable,
    required this.daysPerWeek,
    required this.trainingMaxPolicy,
    required this.sequence,
    required this.sources,
    this.unavailableReason,
  });

  final String id;
  final String name;
  final String variant;
  final bool selectable;
  final int? daysPerWeek;
  final ForeverTrainingMaxPolicy? trainingMaxPolicy;
  final List<ForeverSequenceBlock> sequence;
  final List<core.SourceProvenance> sources;
  final String? unavailableReason;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'variant': variant,
    'selectable': selectable,
    'daysPerWeek': daysPerWeek,
    'trainingMaxPolicy': trainingMaxPolicy?.name,
    'sequence': sequence.map((block) => block.toJson()).toList(),
    'sources': sources.map((source) => source.toJson()).toList(),
    'unavailableReason': unavailableReason,
  };
}

const _fslSource = core.SourceProvenance(
  title: '5/3/1 Forever',
  pages: '29–33, 180–182',
);
const _bpsSource = core.SourceProvenance(
  title: '5/3/1 Forever',
  pages: '50–57',
);

final _templates = <ForeverCalculatorTemplate>[
  ForeverCalculatorTemplate(
    id: 'FV-141',
    name: 'Beginner Prep School',
    variant: 'A/B full-body',
    selectable: true,
    daysPerWeek: 3,
    trainingMaxPolicy: ForeverTrainingMaxPolicy.explicitEightyFiveOrNinety,
    sequence: [
      ForeverSequenceBlock(
        kind: ForeverBlockKind.leader,
        startWeek: 1,
        durationWeeks: 3,
        source: _bpsSource,
      ),
    ],
    sources: [_bpsSource],
  ),
  ForeverCalculatorTemplate(
    id: 'FV-236',
    name: 'Original 5/3/1 + FSL',
    variant: '2 Leaders / 1 Anchor',
    selectable: true,
    daysPerWeek: 4,
    trainingMaxPolicy: ForeverTrainingMaxPolicy.confirmAtCheckpoints,
    sequence: _compiledForeverOriginalFslSequence(),
    sources: [_fslSource],
  ),
  ForeverCalculatorTemplate(
    id: 'forever-documentary-bbb',
    name: 'Boring But Big',
    variant: 'Documentation only',
    selectable: false,
    daysPerWeek: null,
    trainingMaxPolicy: null,
    sequence: [],
    sources: [_fslSource],
    unavailableReason:
        'NEEDS_REVIEW: no complete reviewed calculator strategy is available.',
  ),
  ForeverCalculatorTemplate(
    id: 'forever-documentary-fsl',
    name: 'First Set Last',
    variant: 'Component',
    selectable: false,
    daysPerWeek: null,
    trainingMaxPolicy: null,
    sequence: [],
    sources: [_fslSource],
    unavailableReason:
        'FSL is documented as a component; only FV-236 is executable here.',
  ),
  ForeverCalculatorTemplate(
    id: 'forever-documentary-simplest-strength',
    name: 'Simplest Strength',
    variant: 'Documentation only',
    selectable: false,
    daysPerWeek: null,
    trainingMaxPolicy: null,
    sequence: [],
    sources: [_fslSource],
    unavailableReason:
        'NEEDS_REVIEW: no complete reviewed calculator strategy is available.',
  ),
  ForeverCalculatorTemplate(
    id: 'forever-documentary-bbs',
    name: 'Boring But Strong',
    variant: 'Documentation only',
    selectable: false,
    daysPerWeek: null,
    trainingMaxPolicy: null,
    sequence: [],
    sources: [_fslSource],
    unavailableReason:
        'NEEDS_REVIEW: no complete reviewed calculator strategy is available.',
  ),
];

List<ForeverSequenceBlock> _compiledForeverOriginalFslSequence() {
  final profile = planning.CommonTrainingProfile(
    trainingDaysPerWeek: 4,
    trainingWeekdays: [1, 2, 4, 5],
    trainingMaxes: {'press': 1},
    progressionIncrements: {'press': 1},
  );
  final configuration = planning.ForeverPlanningConfiguration(
    profile: profile,
    kind: planning.ForeverPlanKind.macrocycle,
    series: planning.createForeverOriginalFslSeries(profile: profile),
  );
  var startWeek = 1;
  return [
    for (final node
        in const planning.ForeverSequenceCompiler().compileStructure(
          configuration,
        ))
      () {
        final duration = node is planning.ForeverCycleNode ? 3 : 1;
        final block = ForeverSequenceBlock(
          kind: switch (node) {
            planning.ForeverCycleNode cycle =>
              cycle.role == planning.CycleRole.leader
                  ? ForeverBlockKind.leader
                  : ForeverBlockKind.anchor,
            planning.ForeverProtocolNode protocol =>
              protocol.purpose == planning.ProtocolPurpose.seventhWeekDeload
                  ? ForeverBlockKind.seventhWeekDeload
                  : ForeverBlockKind.seventhWeekTmTest,
          },
          startWeek: startWeek,
          durationWeeks: duration,
          source: _fslSource,
        );
        startWeek += duration;
        return block;
      }(),
  ];
}

/// Lists both executable presets and clearly labelled documentary entries.
List<ForeverCalculatorTemplate> listForeverCalculatorTemplates({
  bool selectableOnly = false,
}) => List.unmodifiable(
  _templates.where((template) => !selectableOnly || template.selectable),
);

ForeverCalculatorTemplate selectForeverCalculatorTemplate(String id) {
  final template = _templates
      .where((candidate) => candidate.id == id)
      .firstOrNull;
  if (template == null) {
    throw ArgumentError.value(id, 'id', 'Unknown Forever calculator template.');
  }
  if (!template.selectable) {
    throw StateError(
      template.unavailableReason ?? 'Template is not selectable.',
    );
  }
  return template;
}

List<core.ValidationIssue> validateForeverCalculatorConfiguration(
  core.ProgramConfiguration configuration,
) {
  final issues = <core.ValidationIssue>[];
  if (configuration.generation != core.Generation.forever) {
    issues.add(
      const core.ValidationIssue(
        code: 'forever_generation_required',
        message: 'This calculator selection requires the Forever generation.',
        field: 'generation',
      ),
    );
    return List.unmodifiable(issues);
  }
  ForeverCalculatorTemplate template;
  try {
    template = selectForeverCalculatorTemplate(configuration.programId);
  } on Object catch (error) {
    issues.add(
      core.ValidationIssue(
        code: 'forever_template_not_selectable',
        message: error.toString(),
        field: 'programId',
      ),
    );
    return List.unmodifiable(issues);
  }
  issues.addAll(core.validateProgramConfiguration(configuration));
  if (template.trainingMaxPolicy ==
          ForeverTrainingMaxPolicy.explicitEightyFiveOrNinety &&
      configuration.trainingMaxRatio != .85 &&
      configuration.trainingMaxRatio != .90) {
    issues.add(
      const core.ValidationIssue(
        code: 'bps_tm_ratio',
        message: 'Beginner Prep School requires an explicit 85% or 90% TM.',
        field: 'trainingMaxRatio',
      ),
    );
  }
  return List.unmodifiable(issues);
}

core.GeneratedProgram generateForeverCalculatorProgram(
  core.ProgramConfiguration configuration,
) {
  final issues = validateForeverCalculatorConfiguration(
    configuration,
  ).where((issue) => issue.blocking).toList();
  if (issues.isNotEmpty) throw core.ProgramGenerationException(issues);
  return core.generateProgram(configuration);
}

String serializeForeverCalculatorProgram(core.GeneratedProgram program) {
  if (program.generation != core.Generation.forever) {
    throw ArgumentError('Only Forever programs can be serialized here.');
  }
  return core.serializeProgram(program);
}

core.GeneratedProgram deserializeForeverCalculatorProgram(String payload) {
  final program = core.deserializeProgram(payload);
  if (program.generation != core.Generation.forever ||
      !_templates.any(
        (template) => template.selectable && template.id == program.programId,
      )) {
    throw const FormatException('Not a selectable Forever calculator program.');
  }
  return program;
}

String serializeForeverCalculatorTemplate(ForeverCalculatorTemplate template) =>
    jsonEncode(template.toJson());
