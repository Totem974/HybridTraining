import 'program_identity.dart';

class ProgramConcept {
  const ProgramConcept({
    required this.id,
    required this.titleKey,
    required this.type,
    required this.originGeneration,
    required this.documentationStatus,
  });

  final String id;
  final String titleKey;
  final ProgramConceptType type;
  final MethodGeneration? originGeneration;
  final ProgramValidationStatus documentationStatus;
}

class ProgramRevision {
  const ProgramRevision({
    required this.id,
    required this.conceptId,
    required this.generation,
    required this.version,
    required this.foreverStatus,
    required this.documentationStatus,
    required this.references,
    this.supersedesRevisionId,
  });

  final String id;
  final String conceptId;
  final MethodGeneration generation;
  final int version;
  final ForeverStatus foreverStatus;
  final ProgramValidationStatus documentationStatus;
  final List<ProgramDocumentReference> references;
  final String? supersedesRevisionId;
}

class ProgramPresetDefinition {
  const ProgramPresetDefinition({
    required this.persistentPresetId,
    required this.version,
    required this.rulesetGeneration,
    required this.mainRevisionId,
    required this.supplementalRevisionId,
    required this.supportedFrequencies,
    required this.recommendedFrequency,
    required this.availability,
    required this.recommended,
    required this.generatorId,
  });

  final String persistentPresetId;
  final int version;
  final MethodGeneration rulesetGeneration;
  final String mainRevisionId;
  final String? supplementalRevisionId;
  final Set<int> supportedFrequencies;
  final int recommendedFrequency;
  final ProductAvailability availability;
  final bool recommended;
  final String? generatorId;
}

class ProgramCatalogValidation {
  const ProgramCatalogValidation(this.errors);
  final List<String> errors;
  bool get isValid => errors.isEmpty;
}

class ProgramCatalog {
  const ProgramCatalog({
    this.concepts = defaultConcepts,
    this.revisions = defaultRevisions,
    this.presets = defaultPresets,
  });

  final List<ProgramConcept> concepts;
  final List<ProgramRevision> revisions;
  final List<ProgramPresetDefinition> presets;

  static const defaultConcepts = <ProgramConcept>[
    ProgramConcept(
      id: 'original-531',
      titleKey: 'program.original_531',
      type: ProgramConceptType.mainMethod,
      originGeneration: MethodGeneration.original,
      documentationStatus: ProgramValidationStatus.rulesReviewed,
    ),
    ProgramConcept(
      id: 'first-set-last',
      titleKey: 'program.first_set_last',
      type: ProgramConceptType.supplementalWork,
      originGeneration: MethodGeneration.beyond,
      documentationStatus: ProgramValidationStatus.rulesReviewed,
    ),
    ProgramConcept(
      id: 'boring-but-big',
      titleKey: 'program.boring_but_big',
      type: ProgramConceptType.supplementalWork,
      originGeneration: MethodGeneration.original,
      documentationStatus: ProgramValidationStatus.indexed,
    ),
    ProgramConcept(
      id: 'joker-sets',
      titleKey: 'program.joker_sets',
      type: ProgramConceptType.supplementalWork,
      originGeneration: MethodGeneration.beyond,
      documentationStatus: ProgramValidationStatus.indexed,
    ),
    ProgramConcept(
      id: 'boring-but-strong',
      titleKey: 'program.boring_but_strong',
      type: ProgramConceptType.standaloneProgram,
      originGeneration: MethodGeneration.forever,
      documentationStatus: ProgramValidationStatus.indexed,
    ),
    ProgramConcept(
      id: 'full-body-1000-awesome',
      titleKey: 'program.full_body_1000',
      type: ProgramConceptType.standaloneProgram,
      originGeneration: MethodGeneration.forever,
      documentationStatus: ProgramValidationStatus.indexed,
    ),
    ProgramConcept(
      id: 'coffinworm',
      titleKey: 'program.coffinworm',
      type: ProgramConceptType.standaloneProgram,
      originGeneration: MethodGeneration.forever,
      documentationStatus: ProgramValidationStatus.indexed,
    ),
    ProgramConcept(
      id: 'pervertor',
      titleKey: 'program.pervertor',
      type: ProgramConceptType.standaloneProgram,
      originGeneration: MethodGeneration.forever,
      documentationStatus: ProgramValidationStatus.indexed,
    ),
    ProgramConcept(
      id: 'god-is-a-beast',
      titleKey: 'program.god_is_a_beast',
      type: ProgramConceptType.standaloneProgram,
      originGeneration: MethodGeneration.forever,
      documentationStatus: ProgramValidationStatus.indexed,
    ),
    ProgramConcept(
      id: 'krypteia',
      titleKey: 'program.krypteia',
      type: ProgramConceptType.standaloneProgram,
      originGeneration: MethodGeneration.forever,
      documentationStatus: ProgramValidationStatus.indexed,
    ),
  ];

  static const defaultRevisions = <ProgramRevision>[
    ProgramRevision(
      id: 'original-original-531-v1',
      conceptId: 'original-531',
      generation: MethodGeneration.original,
      version: 1,
      foreverStatus: ForeverStatus.superseded,
      documentationStatus: ProgramValidationStatus.indexed,
      references: [],
    ),
    ProgramRevision(
      id: 'forever-original-531-v1',
      conceptId: 'original-531',
      generation: MethodGeneration.forever,
      version: 1,
      foreverStatus: ForeverStatus.current,
      documentationStatus: ProgramValidationStatus.rulesReviewed,
      references: [
        ProgramDocumentReference(
          title: '5/3/1 Forever',
          bookPages: '168-170',
          pdfPages: '180-182',
        ),
      ],
      supersedesRevisionId: 'original-original-531-v1',
    ),
    ProgramRevision(
      id: 'forever-first-set-last-5x5-v1',
      conceptId: 'first-set-last',
      generation: MethodGeneration.forever,
      version: 1,
      foreverStatus: ForeverStatus.current,
      documentationStatus: ProgramValidationStatus.rulesReviewed,
      references: [
        ProgramDocumentReference(
          title: '5/3/1 Forever',
          bookPages: '168-170',
          pdfPages: '180-182',
        ),
      ],
    ),
  ];

  static const defaultPresets = <ProgramPresetDefinition>[
    ProgramPresetDefinition(
      persistentPresetId: 'forever-original-fsl-v1',
      version: 1,
      rulesetGeneration: MethodGeneration.forever,
      mainRevisionId: 'forever-original-531-v1',
      supplementalRevisionId: 'forever-first-set-last-5x5-v1',
      supportedFrequencies: {3, 4},
      recommendedFrequency: 4,
      availability: ProductAvailability.available,
      recommended: true,
      generatorId: 'original-fsl',
    ),
  ];

  ProgramConcept concept(String id) =>
      concepts.singleWhere((item) => item.id == id);
  ProgramRevision revision(String id) =>
      revisions.singleWhere((item) => item.id == id);
  ProgramPresetDefinition preset(String id) =>
      presets.singleWhere((item) => item.persistentPresetId == id);
  List<ProgramRevision> revisionsFor(String conceptId) => revisions
      .where((item) => item.conceptId == conceptId)
      .toList(growable: false);
  List<ProgramConcept> conceptsByOrigin(MethodGeneration origin) => concepts
      .where((item) => item.originGeneration == origin)
      .toList(growable: false);
  List<ProgramPresetDefinition> get selectablePresets => presets
      .where((item) => item.availability == ProductAvailability.available)
      .toList(growable: false);
  ProgramPresetDefinition get recommendedPreset => presets.singleWhere(
    (item) =>
        item.recommended && item.availability == ProductAvailability.available,
  );
  ProgramPresetDefinition? presetForConcept(String conceptId) {
    for (final preset in presets) {
      if (revision(preset.mainRevisionId).conceptId == conceptId ||
          (preset.supplementalRevisionId != null &&
              revision(preset.supplementalRevisionId!).conceptId ==
                  conceptId)) {
        return preset;
      }
    }
    return null;
  }

  ProductAvailability availabilityFor(String conceptId) =>
      presetForConcept(conceptId)?.availability ??
      ProductAvailability.documentationOnly;

  ProgramCatalogValidation validate({
    Map<String, String> generators = const {
      'forever-original-fsl-v1': 'original-fsl',
    },
  }) {
    final errors = <String>[];
    _duplicates(concepts.map((item) => item.id), 'concept', errors);
    _duplicates(revisions.map((item) => item.id), 'revision', errors);
    _duplicates(
      presets.map((item) => item.persistentPresetId),
      'preset',
      errors,
    );
    final conceptIds = concepts.map((item) => item.id).toSet();
    final revisionIds = revisions.map((item) => item.id).toSet();
    for (final revision in revisions) {
      if (!conceptIds.contains(revision.conceptId)) {
        errors.add('Missing concept: ${revision.conceptId}');
      }
    }
    for (final preset in presets) {
      if (!revisionIds.contains(preset.mainRevisionId) ||
          (preset.supplementalRevisionId != null &&
              !revisionIds.contains(preset.supplementalRevisionId))) {
        errors.add('Missing revision for preset: ${preset.persistentPresetId}');
      }
      if (!preset.supportedFrequencies.contains(preset.recommendedFrequency)) {
        errors.add(
          'Unsupported recommended frequency: ${preset.persistentPresetId}',
        );
      }
      if (preset.version <= 0) {
        errors.add('Invalid preset version: ${preset.persistentPresetId}');
      }
      if (preset.availability == ProductAvailability.available &&
          (preset.generatorId == null ||
              generators[preset.persistentPresetId] != preset.generatorId)) {
        errors.add('Missing generator: ${preset.persistentPresetId}');
      }
      if (preset.availability == ProductAvailability.documentationOnly &&
          generators.containsKey(preset.persistentPresetId)) {
        errors.add(
          'Generator registered for documentation-only preset: ${preset.persistentPresetId}',
        );
      }
    }
    if (presets
            .where(
              (item) =>
                  item.recommended &&
                  item.availability == ProductAvailability.available,
            )
            .length !=
        1) {
      errors.add('Exactly one available preset must be recommended');
    }
    return ProgramCatalogValidation(List.unmodifiable(errors));
  }

  static void _duplicates(
    Iterable<String> ids,
    String kind,
    List<String> errors,
  ) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) {
        errors.add('Duplicate $kind id: $id');
      }
    }
  }
}
