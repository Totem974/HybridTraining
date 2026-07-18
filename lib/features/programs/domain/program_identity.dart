enum MethodGeneration { original, beyond, forever }

enum ForeverStatus {
  current,
  currentWithRestrictions,
  legacy,
  superseded,
  unknown,
}

enum ProgramValidationStatus { rulesReviewed, indexed, needsReview }

enum ProductAvailability { available, comingSoon, documentationOnly }

enum ProgramImplementationStatus { experimental, productionReady }

enum ProgramConceptType {
  mainMethod,
  supplementalWork,
  assistance,
  cycleProtocol,
  completePreset,
  standaloneProgram,
}

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
    required this.rulesetGeneration,
    required this.persistentPresetId,
    required this.version,
    required this.labelKey,
    required this.validationStatus,
    required this.references,
  });

  static const originalFsl = ProgramDefinitionRef(
    rulesetGeneration: MethodGeneration.forever,
    persistentPresetId: 'forever-original-fsl-v1',
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

  final MethodGeneration rulesetGeneration;
  final String persistentPresetId;
  final int version;
  final String labelKey;
  final ProgramValidationStatus validationStatus;
  final List<ProgramDocumentReference> references;

  @Deprecated('Use persistentPresetId')
  String get templateId => persistentPresetId;
  @Deprecated('Use rulesetGeneration')
  MethodGeneration get family => rulesetGeneration;
  double get documentedTrainingMaxMinimum => 0.85;
  double get documentedTrainingMaxMaximum => 0.90;

  static ProgramDefinitionRef fromJson(
    Map<String, Object?> json, {
    required String persistentId,
    required int persistentVersion,
  }) {
    if (persistentId != originalFsl.persistentPresetId) {
      throw StateError('Unsupported program definition: $persistentId');
    }
    return ProgramDefinitionRef(
      rulesetGeneration:
          parseGeneration(json['rulesetGeneration'] ?? json['family']) ??
          originalFsl.rulesetGeneration,
      persistentPresetId: persistentId,
      version: persistentVersion,
      labelKey: json['labelKey'] as String? ?? originalFsl.labelKey,
      validationStatus:
          _status(json['validationStatus']) ?? originalFsl.validationStatus,
      references: _references(json['references']),
    );
  }

  static MethodGeneration? parseGeneration(Object? value) => switch (value) {
    'original' || 'classic' => MethodGeneration.original,
    'beyond' => MethodGeneration.beyond,
    'forever' => MethodGeneration.forever,
    _ => null,
  };

  static ProgramValidationStatus? _status(Object? value) => switch (value) {
    'rulesReviewed' => ProgramValidationStatus.rulesReviewed,
    'indexed' => ProgramValidationStatus.indexed,
    'needsReview' => ProgramValidationStatus.needsReview,
    _ => null,
  };

  static List<ProgramDocumentReference> _references(Object? value) {
    if (value is! List<Object?>) {
      return originalFsl.references;
    }
    final result = <ProgramDocumentReference>[];
    for (final item in value) {
      if (item is! Map<String, Object?> ||
          item['title'] is! String ||
          item['bookPages'] is! String ||
          item['pdfPages'] is! String) {
        return originalFsl.references;
      }
      result.add(
        ProgramDocumentReference(
          title: item['title']! as String,
          bookPages: item['bookPages']! as String,
          pdfPages: item['pdfPages']! as String,
        ),
      );
    }
    return result.isEmpty ? originalFsl.references : List.unmodifiable(result);
  }
}
