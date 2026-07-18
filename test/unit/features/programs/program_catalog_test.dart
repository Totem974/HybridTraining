import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/program_catalog.dart';
import 'package:hybrid_training/features/programs/domain/program_generator_factory.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';

void main() {
  const catalog = ProgramCatalog();

  test('generations and classic compatibility are stable', () {
    expect(MethodGeneration.values, [
      MethodGeneration.original,
      MethodGeneration.beyond,
      MethodGeneration.forever,
    ]);
    expect(
      ProgramDefinitionRef.parseGeneration('classic'),
      MethodGeneration.original,
    );
  });

  test('Original concept has distinct Original and Forever revisions', () {
    final revisions = catalog.revisionsFor('original-531');
    expect(
      catalog.concept('original-531').originGeneration,
      MethodGeneration.original,
    );
    expect(
      revisions.map((item) => item.id),
      containsAll(['original-original-531-v1', 'forever-original-531-v1']),
    );
    expect(
      catalog.revision('forever-original-531-v1').generation,
      MethodGeneration.forever,
    );
  });

  test('preset uses both reviewed Forever revisions', () {
    final preset = catalog.preset('forever-original-fsl-v1');
    expect(preset.mainRevisionId, 'forever-original-531-v1');
    expect(preset.supplementalRevisionId, 'forever-first-set-last-5x5-v1');
    expect(preset.supportedFrequencies, {3, 4});
    expect(preset.recommended, isFalse);
    expect(preset.legacyCompatible, isTrue);
    expect(
      preset.implementationStatus,
      ProgramImplementationStatus.experimental,
    );
    expect(catalog.recommendedPreset, isNull);
    expect(
      const ProgramGeneratorFactory().resolve(preset.persistentPresetId),
      isNotNull,
    );
  });

  test('default catalog satisfies every invariant', () {
    expect(catalog.validate().errors, isEmpty);
    expect(catalog.concepts, hasLength(11));
    expect(catalog.selectablePresets, hasLength(1));
    expect(
      catalog.presetsForConcept('original-531').single.persistentPresetId,
      'forever-original-fsl-v1',
    );
  });

  test('Beginner Prep School stays unavailable until UI v2 is wired', () {
    final preset = catalog.preset('forever-beginner-prep-school-v1');
    expect(preset.supportedFrequencies, {3});
    expect(preset.recommended, isFalse);
    expect(preset.availability, ProductAvailability.comingSoon);
    expect(
      preset.implementationStatus,
      ProgramImplementationStatus.productionReady,
    );
  });

  test('validator detects duplicate and broken references', () {
    final invalid = ProgramCatalog(
      concepts: [catalog.concepts.first, catalog.concepts.first],
      revisions: const [
        ProgramRevision(
          id: 'broken',
          conceptId: 'missing',
          generation: MethodGeneration.original,
          version: 1,
          foreverStatus: ForeverStatus.unknown,
          documentationStatus: ProgramValidationStatus.needsReview,
          references: [],
        ),
      ],
      presets: const [
        ProgramPresetDefinition(
          persistentPresetId: 'broken',
          version: 0,
          rulesetGeneration: MethodGeneration.forever,
          mainRevisionId: 'missing',
          supplementalRevisionId: null,
          supportedFrequencies: {3},
          recommendedFrequency: 4,
          availability: ProductAvailability.available,
          recommended: true,
          legacyCompatible: false,
          implementationStatus: ProgramImplementationStatus.experimental,
          generatorId: null,
        ),
      ],
    );
    final errors = invalid.validate(generators: const {}).errors.join('\n');
    expect(errors, contains('Duplicate concept'));
    expect(errors, contains('Missing concept'));
    expect(errors, contains('Missing revision'));
    expect(errors, contains('Unsupported recommended frequency'));
    expect(errors, contains('Invalid preset version'));
    expect(errors, contains('Missing generator'));
  });
}
