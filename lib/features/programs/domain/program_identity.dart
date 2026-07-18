enum ProgramFamily { forever, beyond, classic }

enum ProgramValidationStatus { rulesReviewed, indexed, needsReview }

class ProgramDocumentReference {
  const ProgramDocumentReference({
    required this.title,
    required this.bookPages,
    required this.pdfPages,
  });

  final String title;
  final String bookPages;
  final String pdfPages;
}

class ProgramDefinitionRef {
  const ProgramDefinitionRef({
    required this.family,
    required this.templateId,
    required this.version,
    required this.labelKey,
    required this.validationStatus,
    required this.references,
  });

  static const originalFsl = ProgramDefinitionRef(
    family: ProgramFamily.forever,
    templateId: 'forever-original-fsl-v1',
    version: 1,
    labelKey: 'program.forever_original_fsl',
    validationStatus: ProgramValidationStatus.rulesReviewed,
    references: [
      ProgramDocumentReference(
        title: '5/3/1 Forever',
        bookPages: '168-170',
        pdfPages: '180-182',
      ),
    ],
  );

  final ProgramFamily family;
  final String templateId;
  final int version;
  final String labelKey;
  final ProgramValidationStatus validationStatus;
  final List<ProgramDocumentReference> references;

  double get documentedTrainingMaxMinimum => 0.85;
  double get documentedTrainingMaxMaximum => 0.90;

  static ProgramDefinitionRef fromJson(
    Map<String, Object?> definition, {
    required String persistentId,
    required int persistentVersion,
  }) {
    if (persistentId == originalFsl.templateId) {
      return ProgramDefinitionRef(
        family: _family(definition['family']) ?? originalFsl.family,
        templateId: persistentId,
        version: persistentVersion,
        labelKey: definition['labelKey'] as String? ?? originalFsl.labelKey,
        validationStatus:
            _status(definition['validationStatus']) ??
            originalFsl.validationStatus,
        references: _references(definition['references']),
      );
    }
    throw StateError('Unsupported program definition: $persistentId');
  }

  static ProgramFamily? _family(Object? value) => switch (value) {
    'forever' => ProgramFamily.forever,
    'beyond' => ProgramFamily.beyond,
    'classic' => ProgramFamily.classic,
    _ => null,
  };

  static ProgramValidationStatus? _status(Object? value) => switch (value) {
    'rulesReviewed' => ProgramValidationStatus.rulesReviewed,
    'indexed' => ProgramValidationStatus.indexed,
    'needsReview' => ProgramValidationStatus.needsReview,
    _ => null,
  };

  static List<ProgramDocumentReference> _references(Object? value) {
    if (value is! List<Object?>) return originalFsl.references;
    final parsed = <ProgramDocumentReference>[];
    for (final item in value) {
      if (item is! Map<String, Object?> ||
          item['title'] is! String ||
          item['bookPages'] is! String ||
          item['pdfPages'] is! String) {
        return originalFsl.references;
      }
      parsed.add(
        ProgramDocumentReference(
          title: item['title']! as String,
          bookPages: item['bookPages']! as String,
          pdfPages: item['pdfPages']! as String,
        ),
      );
    }
    return parsed.isEmpty ? originalFsl.references : List.unmodifiable(parsed);
  }
}
