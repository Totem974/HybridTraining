import 'program_identity.dart';

class ProgramConcept {
  const ProgramConcept({required this.id, required this.titleKey, required this.type, required this.originGeneration, required this.documentationStatus});
  final String id;
  final String titleKey;
  final ProgramConceptType type;
  final MethodGeneration? originGeneration;
  final ProgramValidationStatus documentationStatus;
}

class ProgramRevision {
  const ProgramRevision({required this.id, required this.conceptId, required this.generation, required this.version, required this.foreverStatus, required this.documentationStatus, required this.references, this.supersedesRevisionId});
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
  const ProgramPresetDefinition({required this.persistentPresetId, required this.version, required this.rulesetGeneration, required this.mainRevisionId, required this.supplementalRevisionId, required this.supportedFrequencies, required this.recommendedFrequency, required this.availability, required this.recommended, required this.generatorId});
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

class ProgramCatalog {
  const ProgramCatalog();

  static const concepts = <ProgramConcept>[
    ProgramConcept(id: 'original-531', titleKey: 'program.original_531', type: ProgramConceptType.mainMethod, originGeneration: MethodGeneration.original, documentationStatus: ProgramValidationStatus.rulesReviewed),
    ProgramConcept(id: 'first-set-last', titleKey: 'program.first_set_last', type: ProgramConceptType.supplementalWork, originGeneration: null, documentationStatus: ProgramValidationStatus.needsReview),
    ProgramConcept(id: 'boring-but-big', titleKey: 'program.boring_but_big', type: ProgramConceptType.supplementalWork, originGeneration: null, documentationStatus: ProgramValidationStatus.needsReview),
    ProgramConcept(id: 'joker-sets', titleKey: 'program.joker_sets', type: ProgramConceptType.supplementalWork, originGeneration: null, documentationStatus: ProgramValidationStatus.needsReview),
    ProgramConcept(id: 'boring-but-strong', titleKey: 'program.boring_but_strong', type: ProgramConceptType.standaloneProgram, originGeneration: MethodGeneration.forever, documentationStatus: ProgramValidationStatus.indexed),
    ProgramConcept(id: 'full-body-1000-awesome', titleKey: 'program.full_body_1000', type: ProgramConceptType.standaloneProgram, originGeneration: MethodGeneration.forever, documentationStatus: ProgramValidationStatus.indexed),
    ProgramConcept(id: 'coffinworm', titleKey: 'program.coffinworm', type: ProgramConceptType.standaloneProgram, originGeneration: MethodGeneration.forever, documentationStatus: ProgramValidationStatus.indexed),
    ProgramConcept(id: 'pervertor', titleKey: 'program.pervertor', type: ProgramConceptType.standaloneProgram, originGeneration: MethodGeneration.forever, documentationStatus: ProgramValidationStatus.indexed),
    ProgramConcept(id: 'god-is-a-beast', titleKey: 'program.god_is_a_beast', type: ProgramConceptType.standaloneProgram, originGeneration: MethodGeneration.forever, documentationStatus: ProgramValidationStatus.indexed),
    ProgramConcept(id: 'krypteia', titleKey: 'program.krypteia', type: ProgramConceptType.standaloneProgram, originGeneration: MethodGeneration.forever, documentationStatus: ProgramValidationStatus.indexed),
  ];

  static const revisions = <ProgramRevision>[
    ProgramRevision(id: 'original-531-v1', conceptId: 'original-531', generation: MethodGeneration.original, version: 1, foreverStatus: ForeverStatus.current, documentationStatus: ProgramValidationStatus.rulesReviewed, references: []),
    ProgramRevision(id: 'forever-first-set-last-5x5-v1', conceptId: 'first-set-last', generation: MethodGeneration.forever, version: 1, foreverStatus: ForeverStatus.current, documentationStatus: ProgramValidationStatus.rulesReviewed, references: ProgramDefinitionRef.originalFsl.references),
  ];

  static const presets = <ProgramPresetDefinition>[
    ProgramPresetDefinition(persistentPresetId: 'forever-original-fsl-v1', version: 1, rulesetGeneration: MethodGeneration.forever, mainRevisionId: 'original-531-v1', supplementalRevisionId: 'forever-first-set-last-5x5-v1', supportedFrequencies: {3, 4}, recommendedFrequency: 4, availability: ProductAvailability.available, recommended: true, generatorId: 'original-fsl'),
  ];

  ProgramConcept concept(String id) => concepts.singleWhere((item) => item.id == id);
  ProgramRevision revision(String id) => revisions.singleWhere((item) => item.id == id);
  ProgramPresetDefinition preset(String id) => presets.singleWhere((item) => item.persistentPresetId == id);
  List<ProgramConcept> conceptsByOrigin(MethodGeneration origin) => concepts.where((item) => item.originGeneration == origin).toList(growable: false);
  List<ProgramRevision> revisionsByGeneration(MethodGeneration generation) => revisions.where((item) => item.generation == generation).toList(growable: false);
  List<ProgramRevision> revisionsByForeverStatus(ForeverStatus status) => revisions.where((item) => item.foreverStatus == status).toList(growable: false);
  List<ProgramPresetDefinition> presetsByAvailability(ProductAvailability availability) => presets.where((item) => item.availability == availability).toList(growable: false);
  List<ProgramPresetDefinition> get selectablePresets => presetsByAvailability(ProductAvailability.available);
  ProgramPresetDefinition get recommendedPreset => presets.singleWhere((item) => item.recommended && item.availability == ProductAvailability.available);
}
