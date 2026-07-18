import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/program_catalog.dart';
import 'package:hybrid_training/features/programs/domain/program_generator_factory.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';

void main() {
  const catalog = ProgramCatalog();

  test('generations and classic compatibility are distinct and stable', () {
    expect(MethodGeneration.values, [MethodGeneration.original, MethodGeneration.beyond, MethodGeneration.forever]);
    expect(ProgramDefinitionRef.parseGeneration('classic'), MethodGeneration.original);
  });

  test('concept origin differs from revision generation', () {
    final concept = catalog.concept('original-531');
    final revision = catalog.revision('original-531-v1');
    expect(concept.originGeneration, MethodGeneration.original);
    expect(revision.generation, MethodGeneration.original);
    expect(catalog.concept('first-set-last').originGeneration, isNull);
    expect(catalog.revision('forever-first-set-last-5x5-v1').generation, MethodGeneration.forever);
  });

  test('catalog identifiers and executable recommendation are unique', () {
    expect(conceptsIds(), hasLength(ProgramCatalog.concepts.length));
    expect(revisionIds(), hasLength(ProgramCatalog.revisions.length));
    expect(presetIds(), hasLength(ProgramCatalog.presets.length));
    expect(catalog.selectablePresets, hasLength(1));
    expect(catalog.recommendedPreset.persistentPresetId, 'forever-original-fsl-v1');
  });

  test('preset composes Original main work and Forever FSL revision', () {
    final preset = catalog.recommendedPreset;
    expect(preset.rulesetGeneration, MethodGeneration.forever);
    expect(preset.mainRevisionId, 'original-531-v1');
    expect(preset.supplementalRevisionId, 'forever-first-set-last-5x5-v1');
    expect(preset.supportedFrequencies, {3, 4});
    expect(const ProgramGeneratorFactory().resolve(preset.persistentPresetId), isNotNull);
  });
}

Set<String> conceptsIds() => {for (final item in ProgramCatalog.concepts) item.id};
Set<String> revisionIds() => {for (final item in ProgramCatalog.revisions) item.id};
Set<String> presetIds() => {for (final item in ProgramCatalog.presets) item.persistentPresetId};
