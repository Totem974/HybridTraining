import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';

void main() {
  test('default program is the versioned Forever Original FSL template', () {
    const program = ProgramDefinitionRef.originalFsl;

    expect(program.rulesetGeneration, MethodGeneration.forever);
    expect(program.templateId, 'forever-original-fsl-v1');
    expect(program.version, 1);
    expect(program.labelKey, 'program.forever_original_fsl');
    expect(program.validationStatus, ProgramValidationStatus.rulesReviewed);
    expect(program.documentedTrainingMaxMinimum, 0.85);
    expect(program.documentedTrainingMaxMaximum, 0.90);
  });

  test('old definition JSON gets deterministic metadata fallbacks', () {
    final program = ProgramDefinitionRef.fromJson(
      const {
        'format': 'hybrid-training-program',
        'schemaVersion': 1,
        'id': 'forever-original-fsl-v1',
        'weeks': [1, 2, 3],
      },
      persistentId: 'forever-original-fsl-v1',
      persistentVersion: 1,
    );

    expect(program.rulesetGeneration, MethodGeneration.forever);
    expect(program.labelKey, ProgramDefinitionRef.originalFsl.labelKey);
    expect(program.references.single.bookPages, '168-170');
  });
}
