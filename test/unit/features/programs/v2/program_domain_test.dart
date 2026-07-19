import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/program_catalog.dart'
    as v1;
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain_serializer.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain_validator.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_v1_adapter.dart';

void main() {
  const concept = ProgramConcept(
    id: ProgramConceptId('shared'),
    titleKey: 'shared',
    origin: MethodGeneration.original,
    historicalOrigin: HistoricalConceptOrigin.fiveThreeOne,
  );
  const revision1 = ProgramRevision(
    id: ProgramRevisionId('shared-v1'),
    conceptId: ProgramConceptId('shared'),
    generation: MethodGeneration.original,
    version: ProgramVersion(1),
    ruleStatus: RuleStatus.verified,
    sourceEdition: SourceEdition.original,
    references: [RuleReference(document: 'Source', location: 'page 1')],
  );
  const revision2 = ProgramRevision(
    id: ProgramRevisionId('shared-v2'),
    conceptId: ProgramConceptId('shared'),
    generation: MethodGeneration.forever,
    version: ProgramVersion(2),
    ruleStatus: RuleStatus.verified,
    sourceEdition: SourceEdition.forever,
    references: [RuleReference(document: 'Source', location: 'page 2')],
    supersedes: ProgramRevisionId('shared-v1'),
  );

  ProgramBlueprint blueprint(
    String id,
    List<BlockTemplate> templates,
    List<BlockSequenceEntry> entries,
    Set<BlockTransition> transitions,
  ) => ProgramBlueprint(
    id: ProgramBlueprintId(id),
    version: const ProgramVersion(1),
    revisionIds: const [ProgramRevisionId('shared-v2')],
    capabilities: const {ProgramCapability.mainWork},
    trainingMaxPolicy: const TrainingMaxPolicy(
      PolicyId('tm'),
      ProgramVersion(1),
      ruleStatus: RuleStatus.verified,
    ),
    mainWorkPolicy: const MainWorkPolicy(
      PolicyId('main'),
      ProgramVersion(1),
      ruleStatus: RuleStatus.verified,
    ),
    schedulePolicy: const SchedulePolicy(
      PolicyId('schedule'),
      ProgramVersion(1),
      supportedFrequencies: {3, 4},
      recommendedFrequency: 4,
      mainMovementsPerSession: 2,
      ruleStatus: RuleStatus.verified,
    ),
    blockTemplates: templates,
    blockSequence: BlockSequence(blocks: entries),
    transitionPolicy: TransitionPolicy(
      const PolicyId('transition'),
      const ProgramVersion(1),
      allowedTransitions: transitions,
      ruleStatus: RuleStatus.verified,
    ),
    compatibility: const CompatibilityConstraint(supportedFrequencies: {3, 4}),
    implementationStatus: ImplementationStatus.available,
    generatorId: 'test-generator',
    sourceEdition: SourceEdition.forever,
    generation: MethodGeneration.forever,
    references: const [RuleReference(document: 'Source', location: 'page 2')],
  );

  test('movement ids are stable and extensible beyond the four lifts', () {
    expect(MovementId.squat.value, 'barbell.back-squat');
    expect(MovementId.powerClean, const MovementId('barbell.power-clean'));
    expect(
      const MovementId('bodyweight.pull-up'),
      isNot(MovementId.overheadPress),
    );
  });

  test('generic prescriptions separate targets from actual results', () {
    const prescription = ActivityPrescription(
      id: PrescriptionId('session-1:jump:0'),
      position: 0,
      activityId: ActivityId('athletic.box-jump'),
      target: PrescriptionTarget(
        type: PrescriptionTargetType.totalRepetitions,
        totalRepetitions: 10,
      ),
      kind: PrescriptionKind.jumpsOrThrows,
      ruleId: 'BPS-JUMP-001',
      sourceEdition: SourceEdition.forever,
      generation: MethodGeneration.forever,
      source: RuleReference(document: '5/3/1 Forever', location: 'PDF 51'),
    );
    const result = ActivityResult(
      prescriptionId: PrescriptionId('session-1:jump:0'),
      status: ActivityResultStatus.success,
      actualRepetitions: 8,
      rpe: 6,
    );
    expect(
      const ProgramDomainValidator().validatePrescription(prescription).isValid,
      isTrue,
    );
    expect(prescription.target.totalRepetitions, 10);
    expect(result.actualRepetitions, 8);
  });

  test('generic prescription validator rejects implicit rules', () {
    const invalid = ActivityPrescription(
      id: PrescriptionId('invalid'),
      position: -1,
      activityId: ActivityId('conditioning.run'),
      target: PrescriptionTarget(type: PrescriptionTargetType.distance),
      kind: PrescriptionKind.easyConditioning,
      ruleId: '',
      sourceEdition: SourceEdition.forever,
      generation: MethodGeneration.forever,
      source: RuleReference(document: '', location: null),
    );
    final codes = const ProgramDomainValidator()
        .validatePrescription(invalid)
        .issues
        .map((issue) => issue.code);
    expect(
      codes,
      containsAll([
        ProgramDomainIssueCode.missingSource,
        ProgramDomainIssueCode.invalidPrescription,
      ]),
    );
  });

  test('minimal composition and two revisions of one concept are valid', () {
    final item = blueprint(
      'minimal',
      const [
        BlockTemplate(id: BlockTemplateId('leader'), role: BlockRole.leader),
      ],
      const [
        BlockSequenceEntry(templateId: BlockTemplateId('leader'), order: 0),
      ],
      const {},
    );
    final result = const ProgramDomainValidator().validate(
      ComposableProgramDomain(
        concepts: const [concept],
        revisions: const [revision1, revision2],
        blueprints: [item],
      ),
    );
    expect(result.isValid, isTrue);
  });
  test('two blueprints can use the same concept revision', () {
    final one = blueprint(
      'one',
      const [BlockTemplate(id: BlockTemplateId('l'), role: BlockRole.leader)],
      const [BlockSequenceEntry(templateId: BlockTemplateId('l'), order: 0)],
      const {},
    );
    final two = blueprint(
      'two',
      const [BlockTemplate(id: BlockTemplateId('l'), role: BlockRole.leader)],
      const [BlockSequenceEntry(templateId: BlockTemplateId('l'), order: 0)],
      const {},
    );
    expect(
      const ProgramDomainValidator()
          .validate(
            ComposableProgramDomain(
              concepts: const [concept],
              revisions: const [revision1, revision2],
              blueprints: [one, two],
            ),
          )
          .isValid,
      isTrue,
    );
  });
  test('supports 2 leaders, deload, anchor and TM test', () {
    const templates = [
      BlockTemplate(id: BlockTemplateId('l1'), role: BlockRole.leader),
      BlockTemplate(id: BlockTemplateId('l2'), role: BlockRole.leader),
      BlockTemplate(
        id: BlockTemplateId('d'),
        role: BlockRole.seventhWeek,
        seventhWeekPurpose: SeventhWeekPurpose.deload,
      ),
      BlockTemplate(id: BlockTemplateId('a'), role: BlockRole.anchor),
      BlockTemplate(
        id: BlockTemplateId('tm'),
        role: BlockRole.seventhWeek,
        seventhWeekPurpose: SeventhWeekPurpose.trainingMaxTest,
      ),
    ];
    const entries = [
      BlockSequenceEntry(templateId: BlockTemplateId('l1'), order: 0),
      BlockSequenceEntry(templateId: BlockTemplateId('l2'), order: 1),
      BlockSequenceEntry(templateId: BlockTemplateId('d'), order: 2),
      BlockSequenceEntry(templateId: BlockTemplateId('a'), order: 3),
      BlockSequenceEntry(templateId: BlockTemplateId('tm'), order: 4),
    ];
    final transitions = {
      BlockTransition(BlockRole.leader, BlockRole.leader),
      BlockTransition(BlockRole.leader, BlockRole.seventhWeek),
      BlockTransition(BlockRole.seventhWeek, BlockRole.anchor),
      BlockTransition(BlockRole.anchor, BlockRole.seventhWeek),
    };
    expect(
      const ProgramDomainValidator()
          .validate(
            ComposableProgramDomain(
              concepts: const [concept],
              revisions: const [revision1, revision2],
              blueprints: [blueprint('long', templates, entries, transitions)],
            ),
          )
          .isValid,
      isTrue,
    );
  });
  test('supports 1 leader plus anchor', () {
    final item = blueprint(
      'short',
      const [
        BlockTemplate(id: BlockTemplateId('l'), role: BlockRole.leader),
        BlockTemplate(id: BlockTemplateId('a'), role: BlockRole.anchor),
      ],
      const [
        BlockSequenceEntry(templateId: BlockTemplateId('l'), order: 0),
        BlockSequenceEntry(templateId: BlockTemplateId('a'), order: 1),
      ],
      {const BlockTransition(BlockRole.leader, BlockRole.anchor)},
    );
    expect(
      const ProgramDomainValidator()
          .validate(
            ComposableProgramDomain(
              concepts: const [concept],
              revisions: const [revision1, revision2],
              blueprints: [item],
            ),
          )
          .isValid,
      isTrue,
    );
  });
  test('invalid constraints and seventh week are reported', () {
    final item = blueprint(
      'bad',
      const [
        BlockTemplate(id: BlockTemplateId('7'), role: BlockRole.seventhWeek),
      ],
      const [BlockSequenceEntry(templateId: BlockTemplateId('7'), order: 1)],
      const {},
    );
    final codes = const ProgramDomainValidator()
        .validate(
          ComposableProgramDomain(
            concepts: const [concept],
            revisions: const [revision1, revision2],
            blueprints: [item],
          ),
        )
        .issues
        .map((e) => e.code);
    expect(
      codes,
      containsAll([
        ProgramDomainIssueCode.seventhWeekWithoutPurpose,
        ProgramDomainIssueCode.unorderedCycle,
      ]),
    );
  });
  test('v1 adapter preserves persistent blueprint and validates', () {
    final converted = const ProgramV1Adapter().convert(
      const v1.ProgramCatalog(),
    );
    expect(
      converted.blueprints
          .singleWhere((item) => item.id.value == 'forever-original-fsl-v1')
          .id
          .value,
      'forever-original-fsl-v1',
    );
    expect(const ProgramDomainValidator().validate(converted).isValid, isTrue);
  });
  test('id serialization is stable', () {
    const serializer = ProgramIdSerializer();
    expect(
      serializer.blueprintId(
        serializer.parseBlueprintId('forever-original-fsl-v1'),
      ),
      'forever-original-fsl-v1',
    );
    expect(
      serializer.conceptId(serializer.parseConceptId('concept')),
      'concept',
    );
    expect(
      serializer.revisionId(serializer.parseRevisionId('revision')),
      'revision',
    );
  });
  test('validator reports every unsafe blueprint contract', () {
    const malformedRevision = ProgramRevision(
      id: ProgramRevisionId('missing-parent'),
      conceptId: ProgramConceptId('absent-concept'),
      generation: MethodGeneration.forever,
      version: ProgramVersion(1),
      ruleStatus: RuleStatus.needsReview,
      supersedes: ProgramRevisionId('absent-revision'),
    );
    const malformed = ProgramBlueprint(
      id: ProgramBlueprintId('malformed'),
      version: ProgramVersion(0),
      revisionIds: [
        ProgramRevisionId('missing-parent'),
        ProgramRevisionId('absent'),
      ],
      capabilities: {},
      trainingMaxPolicy: null,
      mainWorkPolicy: null,
      schedulePolicy: SchedulePolicy(
        PolicyId('bad-schedule'),
        ProgramVersion(1),
        supportedFrequencies: {4},
        recommendedFrequency: 3,
        ruleStatus: RuleStatus.needsReview,
      ),
      blockTemplates: [
        BlockTemplate(id: BlockTemplateId('leader'), role: BlockRole.leader),
        BlockTemplate(id: BlockTemplateId('anchor'), role: BlockRole.anchor),
      ],
      blockSequence: BlockSequence(
        blocks: [
          BlockSequenceEntry(templateId: BlockTemplateId('leader'), order: 0),
          BlockSequenceEntry(templateId: BlockTemplateId('missing'), order: 0),
          BlockSequenceEntry(templateId: BlockTemplateId('anchor'), order: 2),
        ],
      ),
      transitionPolicy: null,
      compatibility: CompatibilityConstraint(
        supportedFrequencies: {3},
        requiredCapabilities: {ProgramCapability.conditioning},
      ),
      implementationStatus: ImplementationStatus.available,
      generatorId: '',
    );
    final result = const ProgramDomainValidator().validate(
      const ComposableProgramDomain(
        concepts: [concept, concept],
        revisions: [revision1, revision1, malformedRevision],
        blueprints: [malformed, malformed],
      ),
    );
    final codes = result.issues.map((issue) => issue.code).toSet();
    expect(
      codes,
      containsAll({
        ProgramDomainIssueCode.duplicateId,
        ProgramDomainIssueCode.missingReference,
        ProgramDomainIssueCode.blueprintWithoutVersion,
        ProgramDomainIssueCode.missingRequiredPolicy,
        ProgramDomainIssueCode.incompatibleFrequency,
        ProgramDomainIssueCode.unorderedCycle,
        ProgramDomainIssueCode.invalidTransition,
        ProgramDomainIssueCode.unverifiedAvailableRule,
        ProgramDomainIssueCode.missingGenerator,
      }),
    );
  });
  test('v2 domain has no Flutter dependency', () {
    final files = Directory(
      'lib/features/programs/domain/v2',
    ).listSync().whereType<File>();
    for (final file in files) {
      expect(
        file.readAsStringSync(),
        isNot(contains("package:flutter")),
        reason: file.path,
      );
    }
  });
}
