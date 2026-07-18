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
    return switch (preset.generatorId) {
      'original-fsl' => const OriginalFslProgram(),
      _ => throw StateError('No generator for preset: $persistentPresetId'),
    };
  }
}
