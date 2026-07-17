import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/program_definition_validator.dart';

void main() {
  const validator = ProgramDefinitionValidator();

  test('accepts a minimal versioned program definition', () {
    expect(
      validator.validate(const {
        'format': 'hybrid-training-program',
        'schemaVersion': 1,
        'id': 'forever-original-fsl-v1',
        'weeks': [1, 2, 3],
      }),
      isEmpty,
    );
  });

  test('reports each missing structural field', () {
    expect(
      validator.validate(const {}),
      containsAll(['format', 'schemaVersion', 'id', 'weeks']),
    );
  });
}
