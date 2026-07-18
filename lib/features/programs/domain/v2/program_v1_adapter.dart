import '../program_catalog.dart' as v1;
import '../program_identity.dart' as v1_identity;
import 'program_domain.dart';

class ProgramV1Adapter {
  const ProgramV1Adapter();
  ComposableProgramDomain convert(v1.ProgramCatalog source) =>
      ComposableProgramDomain(
        concepts: source.concepts
            .map(
              (item) => ProgramConcept(
                id: ProgramConceptId(item.id),
                titleKey: item.titleKey,
                origin: _generation(item.originGeneration),
              ),
            )
            .toList(growable: false),
        revisions: source.revisions
            .map(
              (item) => ProgramRevision(
                id: ProgramRevisionId(item.id),
                conceptId: ProgramConceptId(item.conceptId),
                generation: _generation(item.generation)!,
                version: ProgramVersion(item.version),
                ruleStatus: _status(item.documentationStatus),
                references: item.references
                    .map(
                      (ref) => RuleReference(
                        document: ref.title,
                        location: '${ref.bookPages}; ${ref.pdfPages}',
                      ),
                    )
                    .toList(growable: false),
                supersedes: item.supersedesRevisionId == null
                    ? null
                    : ProgramRevisionId(item.supersedesRevisionId!),
              ),
            )
            .toList(growable: false),
        blueprints: source.presets.map(_blueprint).toList(growable: false),
      );
  ProgramBlueprint _blueprint(v1.ProgramPresetDefinition preset) {
    const verified = RuleStatus.verified;
    final policyVersion = ProgramVersion(preset.version);
    const leader = BlockTemplate(
      id: BlockTemplateId('legacy-cycle'),
      role: BlockRole.leader,
    );
    return ProgramBlueprint(
      id: ProgramBlueprintId(preset.persistentPresetId),
      version: policyVersion,
      revisionIds: [
        ProgramRevisionId(preset.mainRevisionId),
        if (preset.supplementalRevisionId != null)
          ProgramRevisionId(preset.supplementalRevisionId!),
      ],
      capabilities: {
        ProgramCapability.mainWork,
        if (preset.supplementalRevisionId != null)
          ProgramCapability.supplementalWork,
      },
      trainingMaxPolicy: TrainingMaxPolicy(
        const PolicyId('legacy-training-max'),
        policyVersion,
        ruleStatus: verified,
      ),
      mainWorkPolicy: MainWorkPolicy(
        const PolicyId('legacy-main-work'),
        policyVersion,
        ruleStatus: verified,
      ),
      supplementalPolicy: preset.supplementalRevisionId == null
          ? null
          : SupplementalPolicy(
              const PolicyId('legacy-supplemental'),
              policyVersion,
              ruleStatus: verified,
            ),
      schedulePolicy: SchedulePolicy(
        const PolicyId('legacy-schedule'),
        policyVersion,
        supportedFrequencies: preset.supportedFrequencies,
        recommendedFrequency: preset.recommendedFrequency,
        ruleStatus: verified,
      ),
      blockTemplates: const [leader],
      blockSequence: const BlockSequence(
        blocks: [
          BlockSequenceEntry(
            templateId: BlockTemplateId('legacy-cycle'),
            order: 0,
          ),
        ],
      ),
      transitionPolicy: const TransitionPolicy(
        PolicyId('legacy-transition'),
        ProgramVersion(1),
        allowedTransitions: {},
        ruleStatus: verified,
      ),
      compatibility: CompatibilityConstraint(
        supportedFrequencies: preset.supportedFrequencies,
      ),
      implementationStatus:
          preset.availability == v1_identity.ProductAvailability.available
          ? ImplementationStatus.available
          : ImplementationStatus.documentationOnly,
      generatorId: preset.generatorId,
    );
  }

  static MethodGeneration? _generation(v1_identity.MethodGeneration? value) =>
      switch (value) {
        v1_identity.MethodGeneration.original => MethodGeneration.original,
        v1_identity.MethodGeneration.beyond => MethodGeneration.beyond,
        v1_identity.MethodGeneration.forever => MethodGeneration.forever,
        null => null,
      };
  static RuleStatus _status(v1_identity.ProgramValidationStatus value) =>
      value == v1_identity.ProgramValidationStatus.rulesReviewed
      ? RuleStatus.verified
      : RuleStatus.needsReview;
}
