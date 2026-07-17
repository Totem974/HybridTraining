class ProgramDefinitionValidator {
  const ProgramDefinitionValidator();

  List<String> validate(Map<String, Object?> definition) {
    final errors = <String>[];
    if (definition['format'] != 'hybrid-training-program') {
      errors.add('format');
    }
    if (definition['schemaVersion'] != 1) errors.add('schemaVersion');
    if (definition['id'] is! String || (definition['id']! as String).isEmpty) {
      errors.add('id');
    }
    final weeks = definition['weeks'];
    if (weeks is! List<Object?> || weeks.isEmpty) errors.add('weeks');
    return errors;
  }
}
