import 'original_fsl_program.dart';
import 'program_catalog.dart';
import 'program_identity.dart';

class ProgramGeneratorFactory {
  const ProgramGeneratorFactory({this.catalog = const ProgramCatalog()});
  final ProgramCatalog catalog;

  OriginalFslProgram resolve(String persistentPresetId) {
    final preset = catalog.preset(persistentPresetId);
    if (preset.availability != ProductAvailability.available ||
        preset.generatorId == null) {
      throw StateError('Preset is not available: $persistentPresetId');
    }
    return _generator(preset);
  }

  /// Compatibility-only entry point for reopening and testing legacy v1 data.
  /// New product flows must use an available versioned preset instead.
  @Deprecated('Use GenerateBeginnerPlan and the versioned plan repository.')
  OriginalFslProgram resolveLegacy(String persistentPresetId) {
    final preset = catalog.preset(persistentPresetId);
    if (!preset.legacyCompatible || preset.generatorId == null) {
      throw StateError('Preset is not a legacy compatibility entry.');
    }
    return _generator(preset);
  }

  OriginalFslProgram _generator(ProgramPresetDefinition preset) =>
      switch (preset.generatorId) {
        'original-fsl' => const OriginalFslProgram(),
        _ => throw StateError(
          'No generator for preset: ${preset.persistentPresetId}',
        ),
      };
}
