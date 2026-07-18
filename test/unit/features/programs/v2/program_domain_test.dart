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
  );
  const revision1 = ProgramRevision(
    id: ProgramRevisionId('shared-v1'),
    conceptId: ProgramConceptId('shared'),
    generation: MethodGeneration.original,
    version: ProgramVersion(1),
    ruleStatus: RuleStatus.verified,
  );
  const revision2 = ProgramRevision(
    id: ProgramRevisionId('shared-v2'),
    conceptId: ProgramConceptId('shared'),
    generation: MethodGeneration.forever,
    version: ProgramVersion(2),
    ruleStatus: RuleStatus.verified,
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
  );

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
    expect(converted.blueprints.single.id.value, 'forever-original-fsl-v1');
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
