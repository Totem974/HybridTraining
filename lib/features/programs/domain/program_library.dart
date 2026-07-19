import 'program_identity.dart';
import 'v2/program_domain.dart' as canonical;

typedef ProgramEntryKind = canonical.ProgramEntryKind;

enum ProgramPhase { prep, leader, anchor, transition }

enum ProgramLevel { beginner, intermediate, advanced }

enum ProgramGoal { strength, hypertrophy, conditioning, general }

enum ProgramEquipment { barbell, rack, bench, dumbbells, bodyweight }

enum ProgramLibrarySort {
  name,
  recommendation,
  level,
  frequency,
  origin,
  documentationMaturity,
  implementationMaturity,
  complexity,
}

class ProgramTmRange {
  const ProgramTmRange(this.minimum, this.maximum)
    : assert(minimum >= 0 && maximum <= 1 && minimum <= maximum);
  final double minimum;
  final double maximum;
  bool overlaps(ProgramTmRange other) =>
      minimum <= other.maximum && maximum >= other.minimum;
}

class ProgramLibraryEntry {
  const ProgramLibraryEntry({
    required this.id,
    required this.conceptId,
    required this.titleFr,
    required this.titleEn,
    required this.kind,
    required this.origin,
    required this.generation,
    required this.foreverStatus,
    required this.documentationStatus,
    this.phases = const {},
    this.level,
    this.goals = const {},
    this.frequencies = const {},
    this.mainMovementsPerSession,
    this.equipment = const {},
    this.tmRange,
    this.implementationStatus,
    this.complexity,
    this.presetId,
    this.revisionId,
    this.recommended = false,
    this.sourceEdition,
    this.references = const [],
    this.generatorId,
    this.blueprintVersion,
    this.aliases = const {},
    this.capabilities = const {},
    this.restrictions = const {},
    this.summaryFr = '',
    this.summaryEn = '',
  });

  const ProgramLibraryEntry.foreverDocumentary({
    required this.id,
    required this.conceptId,
    required this.titleFr,
    required this.titleEn,
    this.kind = ProgramEntryKind.program,
    this.origin = MethodGeneration.forever,
    this.foreverStatus = ForeverStatus.unknown,
    this.documentationStatus = ProgramValidationStatus.indexed,
    this.phases = const {},
    this.level,
    this.goals = const {},
    this.frequencies = const {},
    this.mainMovementsPerSession,
    this.equipment = const {},
    this.tmRange,
    this.complexity,
    this.summaryFr = 'Entrée documentaire. Règles à vérifier avant activation.',
    this.summaryEn =
        'Documentary entry. Rules must be reviewed before activation.',
  }) : generation = MethodGeneration.forever,
       implementationStatus = null,
       presetId = null,
       revisionId = null,
       recommended = false,
       sourceEdition = canonical.SourceEdition.forever,
       references = const [],
       generatorId = null,
       blueprintVersion = null,
       aliases = const {},
       capabilities = const {},
       restrictions = const {};

  final String id;
  final String conceptId;
  final String titleFr;
  final String titleEn;
  final ProgramEntryKind kind;
  final MethodGeneration origin;
  final MethodGeneration generation;
  final ForeverStatus foreverStatus;
  final Set<ProgramPhase> phases;
  final ProgramLevel? level;
  final Set<ProgramGoal> goals;
  final Set<int> frequencies;
  final int? mainMovementsPerSession;
  final Set<ProgramEquipment> equipment;
  final ProgramTmRange? tmRange;
  final ProgramValidationStatus documentationStatus;
  final ProgramImplementationStatus? implementationStatus;
  final int? complexity;
  final String? presetId;
  final String? revisionId;
  final bool recommended;
  final canonical.SourceEdition? sourceEdition;
  final List<canonical.RuleReference> references;
  final String? generatorId;
  final int? blueprintVersion;
  final Set<String> aliases;
  final Set<canonical.ProgramCapability> capabilities;
  final Set<String> restrictions;
  final String summaryFr;
  final String summaryEn;

  bool get isExecutable =>
      kind == ProgramEntryKind.preset &&
      presetId != null &&
      documentationStatus == ProgramValidationStatus.rulesReviewed &&
      implementationStatus == ProgramImplementationStatus.productionReady &&
      sourceEdition != null &&
      references.isNotEmpty &&
      references.every(
        (reference) =>
            reference.document.trim().isNotEmpty &&
            (reference.location?.trim().isNotEmpty ?? false),
      ) &&
      generatorId != null &&
      generatorId!.isNotEmpty &&
      (blueprintVersion ?? 0) > 0;
}

class ProgramFilter {
  const ProgramFilter({
    this.origins = const {},
    this.generations = const {},
    this.foreverStatuses = const {},
    this.kinds = const {},
    this.phases = const {},
    this.levels = const {},
    this.goals = const {},
    this.frequencies = const {},
    this.mainMovementsPerSession = const {},
    this.equipment = const {},
    this.tmRange,
    this.documentationStatuses = const {},
    this.implementationStatuses = const {},
  });
  final Set<MethodGeneration> origins;
  final Set<MethodGeneration> generations;
  final Set<ForeverStatus> foreverStatuses;
  final Set<ProgramEntryKind> kinds;
  final Set<ProgramPhase> phases;
  final Set<ProgramLevel> levels;
  final Set<ProgramGoal> goals;
  final Set<int> frequencies;
  final Set<int> mainMovementsPerSession;
  final Set<ProgramEquipment> equipment;
  final ProgramTmRange? tmRange;
  final Set<ProgramValidationStatus> documentationStatuses;
  final Set<ProgramImplementationStatus> implementationStatuses;

  bool matches(ProgramLibraryEntry entry) =>
      _allows(origins, entry.origin) &&
      _allows(generations, entry.generation) &&
      _allows(foreverStatuses, entry.foreverStatus) &&
      _allows(kinds, entry.kind) &&
      _intersects(phases, entry.phases) &&
      _allowsNullable(levels, entry.level) &&
      _intersects(goals, entry.goals) &&
      _intersects(frequencies, entry.frequencies) &&
      _allowsNullable(mainMovementsPerSession, entry.mainMovementsPerSession) &&
      _intersects(equipment, entry.equipment) &&
      (tmRange == null ||
          (entry.tmRange != null && entry.tmRange!.overlaps(tmRange!))) &&
      _allows(documentationStatuses, entry.documentationStatus) &&
      _allowsNullable(implementationStatuses, entry.implementationStatus);

  static bool _allows<T>(Set<T> selected, T value) =>
      selected.isEmpty || selected.contains(value);
  static bool _allowsNullable<T>(Set<T> selected, T? value) =>
      selected.isEmpty || (value != null && selected.contains(value));
  static bool _intersects<T>(Set<T> selected, Set<T> values) =>
      selected.isEmpty || selected.any(values.contains);
}

class ProgramQuery {
  const ProgramQuery({
    this.search = '',
    this.filter = const ProgramFilter(),
    this.sort = ProgramLibrarySort.recommendation,
    this.descending = false,
  });
  final String search;
  final ProgramFilter filter;
  final ProgramLibrarySort sort;
  final bool descending;
}

class ProgramFacet<T> {
  const ProgramFacet(this.value, this.count);
  final T value;
  final int count;
}

class ProgramLibraryResult {
  const ProgramLibraryResult({required this.entries, required this.kindFacets});
  final List<ProgramLibraryEntry> entries;
  final List<ProgramFacet<ProgramEntryKind>> kindFacets;
}

abstract interface class ProgramLibraryRepository {
  ProgramLibraryResult query(ProgramQuery query);
  ProgramLibraryEntry? findById(String id);
  List<ProgramLibraryEntry> presetsForConcept(String conceptId);
  ProgramLibraryEntry? findByPresetId(String presetId);
  ProgramLibraryValidation validate({Set<String> registeredGenerators});
}

class ProgramLibraryValidation {
  const ProgramLibraryValidation(this.errors);
  final List<String> errors;
  bool get isValid => errors.isEmpty;
}

class InMemoryProgramLibraryRepository implements ProgramLibraryRepository {
  const InMemoryProgramLibraryRepository([
    this.entries = canonicalProgramEntries,
  ]);
  final List<ProgramLibraryEntry> entries;

  @override
  ProgramLibraryResult query(ProgramQuery query) {
    final needle = _normalize(query.search.trim());
    final filtered = entries.where((entry) {
      final searchable = _normalize(
        '${entry.titleFr} ${entry.titleEn} ${entry.summaryFr} ${entry.summaryEn}',
      );
      return (needle.isEmpty || searchable.contains(needle)) &&
          query.filter.matches(entry);
    }).toList();
    final canonicalOrder = <String, int>{
      for (var index = 0; index < entries.length; index++)
        entries[index].id: index,
    };
    filtered.sort((a, b) {
      var comparison = _compare(a, b, query.sort);
      if (query.descending) comparison = -comparison;
      return comparison != 0
          ? comparison
          : canonicalOrder[a.id]!.compareTo(canonicalOrder[b.id]!);
    });
    return ProgramLibraryResult(
      entries: List.unmodifiable(filtered),
      kindFacets: ProgramEntryKind.values
          .map(
            (kind) => ProgramFacet(
              kind,
              filtered.where((entry) => entry.kind == kind).length,
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  ProgramLibraryEntry? findById(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  @override
  List<ProgramLibraryEntry> presetsForConcept(String conceptId) =>
      List.unmodifiable(
        entries.where(
          (entry) =>
              entry.conceptId == conceptId &&
              entry.kind == ProgramEntryKind.preset,
        ),
      );

  @override
  ProgramLibraryEntry? findByPresetId(String presetId) {
    for (final entry in entries) {
      if (entry.presetId == presetId || entry.aliases.contains(presetId)) {
        return entry;
      }
    }
    return null;
  }

  @override
  ProgramLibraryValidation validate({
    Set<String> registeredGenerators = const {
      'canonical-powerlifting',
      'canonical-beyond',
      'canonical-forever-original-fsl',
      'canonical-bps',
    },
  }) {
    final errors = <String>[];
    _duplicates(entries.map((entry) => entry.id), 'entry', errors);
    _duplicates(
      entries.map((entry) => entry.presetId).whereType<String>(),
      'preset',
      errors,
    );
    final aliases = <String>{};
    for (final entry in entries) {
      for (final alias in entry.aliases) {
        if (!aliases.add(alias)) errors.add('Duplicate alias: $alias');
      }
      if (entry.frequencies.any(
        (frequency) => frequency < 1 || frequency > 7,
      )) {
        errors.add('Invalid frequency: ${entry.id}');
      }
      if (entry.documentationStatus == ProgramValidationStatus.rulesReviewed &&
          (entry.sourceEdition == null || entry.references.isEmpty)) {
        errors.add('Reviewed entry without source: ${entry.id}');
      }
      if (entry.implementationStatus ==
              ProgramImplementationStatus.productionReady &&
          !entry.isExecutable) {
        errors.add('Production entry is not executable: ${entry.id}');
      }
      if (entry.isExecutable &&
          !registeredGenerators.contains(entry.generatorId)) {
        errors.add('Missing generator: ${entry.id}');
      }
    }
    return ProgramLibraryValidation(List.unmodifiable(errors));
  }

  static void _duplicates(
    Iterable<String> values,
    String kind,
    List<String> errors,
  ) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value)) errors.add('Duplicate $kind: $value');
    }
  }

  static int _compare(
    ProgramLibraryEntry a,
    ProgramLibraryEntry b,
    ProgramLibrarySort sort,
  ) => switch (sort) {
    ProgramLibrarySort.name => _normalize(
      a.titleFr,
    ).compareTo(_normalize(b.titleFr)),
    ProgramLibrarySort.recommendation => _rank(
      b.recommended,
    ).compareTo(_rank(a.recommended)),
    ProgramLibrarySort.level => _compareNullableIndex(a.level, b.level),
    ProgramLibrarySort.frequency => _compareNullableInt(
      _minimum(a.frequencies),
      _minimum(b.frequencies),
    ),
    ProgramLibrarySort.origin => a.origin.index.compareTo(b.origin.index),
    ProgramLibrarySort.documentationMaturity =>
      b.documentationStatus.index.compareTo(a.documentationStatus.index),
    ProgramLibrarySort.implementationMaturity => _compareNullableIndex(
      b.implementationStatus,
      a.implementationStatus,
    ),
    ProgramLibrarySort.complexity => _compareNullableInt(
      a.complexity,
      b.complexity,
    ),
  };

  static int _rank(bool value) => value ? 1 : 0;
  static int? _minimum(Set<int> values) => values.isEmpty
      ? null
      : values.reduce((current, next) => current < next ? current : next);
  static int _compareNullableInt(int? a, int? b) => switch ((a, b)) {
    (null, null) => 0,
    (null, _) => 1,
    (_, null) => -1,
    _ => a!.compareTo(b!),
  };
  static int _compareNullableIndex(Enum? a, Enum? b) =>
      _compareNullableInt(a?.index, b?.index);

  static String _normalize(String value) {
    const accents = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿœæ';
    const plain = 'aaaaaaceeeeiiiinooooouuuuyyoea';
    final output = StringBuffer();
    for (final rune in value.toLowerCase().runes) {
      final character = String.fromCharCode(rune);
      final index = accents.indexOf(character);
      output.write(index < 0 ? character : plain[index]);
    }
    return output.toString();
  }
}

const _allPhases = {
  ProgramPhase.prep,
  ProgramPhase.leader,
  ProgramPhase.anchor,
  ProgramPhase.transition,
};
const _basicEquipment = {
  ProgramEquipment.barbell,
  ProgramEquipment.rack,
  ProgramEquipment.bench,
};

const canonicalProgramEntries = <ProgramLibraryEntry>[
  ProgramLibraryEntry(
    id: 'preset-powerlifting-standard-531',
    conceptId: 'standard-531',
    titleFr: '5/3/1 Standard - Powerlifting',
    titleEn: 'Standard 5/3/1 - Powerlifting',
    kind: ProgramEntryKind.preset,
    origin: MethodGeneration.original,
    generation: MethodGeneration.powerlifting,
    foreverStatus: ForeverStatus.unknown,
    phases: {ProgramPhase.transition},
    level: ProgramLevel.intermediate,
    goals: {ProgramGoal.strength},
    frequencies: {3, 4},
    mainMovementsPerSession: 1,
    equipment: _basicEquipment,
    tmRange: ProgramTmRange(.90, .90),
    documentationStatus: ProgramValidationStatus.rulesReviewed,
    implementationStatus: ProgramImplementationStatus.productionReady,
    complexity: 1,
    presetId: 'powerlifting-standard-531-v1',
    revisionId: 'powerlifting-standard-531-v1',
    recommended: false,
    sourceEdition: canonical.SourceEdition.powerlifting,
    references: [
      canonical.RuleReference(
        document: '5/3/1 for Powerlifting',
        location: 'PDF pages 10-16',
      ),
    ],
    generatorId: 'canonical-powerlifting',
    blueprintVersion: 1,
    aliases: {'standard-531-v1'},
    capabilities: {canonical.ProgramCapability.mainWork},
  ),
  ProgramLibraryEntry(
    id: 'preset-beyond-six-week-cycle',
    conceptId: 'beyond-six-week-cycle',
    titleFr: 'Beyond - deux cycles et deload',
    titleEn: 'Beyond - two cycles and deload',
    kind: ProgramEntryKind.preset,
    origin: MethodGeneration.beyond,
    generation: MethodGeneration.beyond,
    foreverStatus: ForeverStatus.unknown,
    phases: {ProgramPhase.transition},
    level: ProgramLevel.intermediate,
    goals: {ProgramGoal.strength},
    frequencies: {3, 4},
    mainMovementsPerSession: 1,
    equipment: _basicEquipment,
    tmRange: ProgramTmRange(.85, .90),
    documentationStatus: ProgramValidationStatus.rulesReviewed,
    implementationStatus: ProgramImplementationStatus.productionReady,
    complexity: 2,
    presetId: 'beyond-six-week-cycle-v1',
    revisionId: 'beyond-six-week-cycle-v1',
    recommended: false,
    sourceEdition: canonical.SourceEdition.beyond,
    references: [
      canonical.RuleReference(
        document: 'Beyond 5/3/1',
        location: 'PDF pages 9, 11-12',
      ),
    ],
    generatorId: 'canonical-beyond',
    blueprintVersion: 1,
    capabilities: {canonical.ProgramCapability.mainWork},
  ),
  ProgramLibraryEntry(
    id: 'preset-forever-original-fsl',
    conceptId: 'program.original-531-fsl',
    titleFr: 'Original + First Set Last',
    titleEn: 'Original + First Set Last',
    kind: ProgramEntryKind.preset,
    origin: MethodGeneration.original,
    generation: MethodGeneration.forever,
    foreverStatus: ForeverStatus.current,
    phases: _allPhases,
    level: ProgramLevel.beginner,
    goals: {ProgramGoal.strength, ProgramGoal.general},
    frequencies: {4},
    mainMovementsPerSession: 1,
    equipment: _basicEquipment,
    tmRange: ProgramTmRange(.85, .90),
    documentationStatus: ProgramValidationStatus.rulesReviewed,
    implementationStatus: ProgramImplementationStatus.productionReady,
    complexity: 1,
    presetId: 'forever-original-531-fsl-2l1a-v1',
    revisionId: 'forever-original-531-fsl-v1',
    recommended: false,
    sourceEdition: canonical.SourceEdition.forever,
    references: [
      canonical.RuleReference(
        document: '5/3/1 Forever',
        location: 'PDF pages 29-33 and 180-182',
      ),
    ],
    generatorId: 'canonical-forever-original-fsl',
    blueprintVersion: 1,
    aliases: {'forever-original-fsl-v1'},
    capabilities: {
      canonical.ProgramCapability.mainWork,
      canonical.ProgramCapability.supplementalWork,
    },
    summaryFr:
        'Deux Leaders 3/5/1 + FSL, deload typé, Anchor Original, puis TM Test typé.',
    summaryEn:
        'Two 3/5/1 + FSL Leaders, typed deload, Original Anchor, then typed TM Test.',
  ),
  ProgramLibraryEntry(
    id: 'revision-original-531',
    conceptId: 'program.original-531',
    titleFr: 'Original 5/3/1 — révision historique',
    titleEn: 'Original 5/3/1 — historical revision',
    kind: ProgramEntryKind.revision,
    origin: MethodGeneration.original,
    generation: MethodGeneration.original,
    foreverStatus: ForeverStatus.superseded,
    phases: _allPhases,
    frequencies: {3, 4},
    mainMovementsPerSession: 1,
    equipment: _basicEquipment,
    tmRange: ProgramTmRange(.90, .90),
    documentationStatus: ProgramValidationStatus.indexed,
    implementationStatus: null,
    complexity: 1,
    revisionId: 'original-original-531-v1',
  ),
  ProgramLibraryEntry(
    id: 'preset-forever-beginner-prep-school',
    conceptId: 'program.beginner-prep-school',
    titleFr: 'Beginner Prep School',
    titleEn: 'Beginner Prep School',
    kind: ProgramEntryKind.preset,
    origin: MethodGeneration.forever,
    generation: MethodGeneration.forever,
    foreverStatus: ForeverStatus.current,
    documentationStatus: ProgramValidationStatus.rulesReviewed,
    phases: {ProgramPhase.prep, ProgramPhase.leader},
    level: ProgramLevel.beginner,
    goals: {ProgramGoal.general},
    frequencies: {3},
    mainMovementsPerSession: 2,
    equipment: {..._basicEquipment, ProgramEquipment.bodyweight},
    tmRange: ProgramTmRange(.85, .90),
    implementationStatus: ProgramImplementationStatus.productionReady,
    complexity: 2,
    presetId: 'forever-beginner-prep-school-v1',
    revisionId: 'forever-beginner-prep-school-v1',
    recommended: true,
    sourceEdition: canonical.SourceEdition.forever,
    references: [
      canonical.RuleReference(
        document: '5/3/1 Forever',
        location: 'PDF pages 50-57',
      ),
    ],
    generatorId: 'canonical-bps',
    blueprintVersion: 1,
    aliases: {'beginner-prep-school-v1'},
    capabilities: {
      canonical.ProgramCapability.mainWork,
      canonical.ProgramCapability.supplementalWork,
      canonical.ProgramCapability.assistance,
      canonical.ProgramCapability.conditioning,
      canonical.ProgramCapability.athleticWork,
      canonical.ProgramCapability.multipleMainMovements,
    },
    summaryFr:
        'Programme débutant Forever sur 3 jours, alternance A/B, deux mouvements principaux par séance. Exige une course régulière, des sauts maîtrisés et un circuit d’assistance chronométré.',
    summaryEn:
        'Three-day Forever beginner program with A/B alternation and two main lifts per session. Requires regular running, sound jumping mechanics, and a timed assistance circuit.',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'component-bbb',
    conceptId: 'supplemental.bbb',
    titleFr: 'Boring But Big',
    titleEn: 'Boring But Big',
    kind: ProgramEntryKind.component,
    origin: MethodGeneration.original,
    phases: {ProgramPhase.leader},
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'component-fsl',
    conceptId: 'supplemental.fsl',
    titleFr: 'First Set Last',
    titleEn: 'First Set Last',
    kind: ProgramEntryKind.component,
    origin: MethodGeneration.beyond,
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'component-ssl',
    conceptId: 'supplemental.ssl',
    titleFr: 'Second Set Last',
    titleEn: 'Second Set Last',
    kind: ProgramEntryKind.component,
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'component-bbs',
    conceptId: 'supplemental.bbs',
    titleFr: 'Boring But Strong',
    titleEn: 'Boring But Strong',
    kind: ProgramEntryKind.component,
    phases: {ProgramPhase.leader},
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'component-5s-pro',
    conceptId: 'component.5s-pro',
    titleFr: "5's Pro",
    titleEn: "5's Pro",
    kind: ProgramEntryKind.component,
    origin: MethodGeneration.beyond,
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'component-joker-sets',
    conceptId: 'component.joker-sets',
    titleFr: 'Joker Sets',
    titleEn: 'Joker Sets',
    kind: ProgramEntryKind.component,
    origin: MethodGeneration.beyond,
    phases: {ProgramPhase.anchor},
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'component-widowmaker',
    conceptId: 'component.widowmaker',
    titleFr: 'Widowmaker',
    titleEn: 'Widowmaker',
    kind: ProgramEntryKind.component,
    origin: MethodGeneration.forever,
    documentationStatus: ProgramValidationStatus.needsReview,
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'protocol-7th-week',
    conceptId: 'protocol.7th-week',
    titleFr: 'Protocole de la 7e semaine',
    titleEn: '7th Week Protocol',
    kind: ProgramEntryKind.protocol,
    phases: {ProgramPhase.transition},
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-1000-percent-awesome',
    conceptId: 'program.1000-percent-awesome',
    titleFr: 'Full Body (1000% Awesome)',
    titleEn: 'Full Body (1000% Awesome)',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-svr-ii',
    conceptId: 'program.svr-ii',
    titleFr: 'S.V.R II',
    titleEn: 'S.V.R II',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-morning-star',
    conceptId: 'program.morning-star',
    titleFr: 'The Morning Star',
    titleEn: 'The Morning Star',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-volume-and-strength',
    conceptId: 'program.volume-and-strength',
    titleFr: 'Volume and Strength',
    titleEn: 'Volume and Strength',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-5x5-531',
    conceptId: 'program.5x5-531',
    titleFr: '5x5/3/1',
    titleEn: '5x5/3/1',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'revision-rhodes-5x5-531',
    conceptId: 'program.5x5-531',
    titleFr: 'Rhodes 5x5/3/1',
    titleEn: 'Rhodes 5x5/3/1',
    kind: ProgramEntryKind.revision,
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'revision-portals-5x5-531',
    conceptId: 'program.5x5-531',
    titleFr: "Portal's 5x5/3/1",
    titleEn: "Portal's 5x5/3/1",
    kind: ProgramEntryKind.revision,
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-five-and-dime',
    conceptId: 'program.five-and-dime',
    titleFr: 'Five and Dime',
    titleEn: 'Five and Dime',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-simplest-strength',
    conceptId: 'program.simplest-strength',
    titleFr: 'Simplest Strength Template',
    titleEn: 'Simplest Strength Template',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-god-is-a-beast',
    conceptId: 'program.god-is-a-beast',
    titleFr: 'God Is a Beast',
    titleEn: 'God Is a Beast',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-black-army-jacket',
    conceptId: 'program.black-army-jacket',
    titleFr: 'Black Army Jacket',
    titleEn: 'Black Army Jacket',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-spinal-tap-5s-pro',
    conceptId: 'program.spinal-tap-5s-pro',
    titleFr: "Spinal Tap 5's Pro",
    titleEn: "Spinal Tap 5's Pro",
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-spinal-tap-high-school',
    conceptId: 'program.spinal-tap-high-school',
    titleFr: 'Spinal Tap, The High School Years',
    titleEn: 'Spinal Tap, The High School Years',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-coffinworm',
    conceptId: 'program.coffinworm',
    titleFr: 'Coffinworm',
    titleEn: 'Coffinworm',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-full-body-85',
    conceptId: 'program.full-body-85',
    titleFr: 'Full Body 85%',
    titleEn: 'Full Body 85%',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-supplemental-heaven',
    conceptId: 'program.supplemental-heaven',
    titleFr: 'Supplemental Heaven',
    titleEn: 'Supplemental Heaven',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-full-body-squat-push-pull',
    conceptId: 'program.full-body-squat-push-pull',
    titleFr: 'Full Body — Squat, Push, Pull',
    titleEn: 'Full Body — Squat, Push, Pull',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-pervertor',
    conceptId: 'program.pervertor',
    titleFr: 'Pervertor',
    titleEn: 'Pervertor',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-original-531',
    conceptId: 'program.original-531',
    titleFr: 'Original 5/3/1',
    titleEn: 'Original 5/3/1',
    origin: MethodGeneration.original,
    documentationStatus: ProgramValidationStatus.needsReview,
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-original-531-fsl',
    conceptId: 'program.original-531-fsl',
    titleFr: 'Original 5/3/1 and FSL',
    titleEn: 'Original 5/3/1 and FSL',
    origin: MethodGeneration.original,
    documentationStatus: ProgramValidationStatus.needsReview,
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-prowler-challenge',
    conceptId: 'program.prowler-challenge',
    titleFr: '5/3/1 Prowler Challenge',
    titleEn: '5/3/1 Prowler Challenge',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-original-challenge',
    conceptId: 'program.original-challenge',
    titleFr: 'Original 5/3/1 Challenge',
    titleEn: 'Original 5/3/1 Challenge',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-combination-template',
    conceptId: 'program.combination-template',
    titleFr: 'Combination Template',
    titleEn: 'Combination Template',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-limited-time',
    conceptId: 'program.limited-time',
    titleFr: 'Limited Time',
    titleEn: 'Limited Time',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-bodybuilder-upper-athlete-lower',
    conceptId: 'program.bodybuilder-upper-athlete-lower',
    titleFr: 'Bodybuilder the Upper / Athlete the Lower',
    titleEn: 'Bodybuilder the Upper / Athlete the Lower',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-strength-conditioning',
    conceptId: 'program.strength-conditioning',
    titleFr: 'Strength and Conditioning',
    titleEn: 'Strength and Conditioning',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-wendler-classic',
    conceptId: 'program.wendler-classic',
    titleFr: 'The Wendler Classic',
    titleEn: 'The Wendler Classic',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-leviathan',
    conceptId: 'program.leviathan',
    titleFr: 'Leviathan',
    titleEn: 'Leviathan',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-con-clavi-con-dio',
    conceptId: 'program.con-clavi-con-dio',
    titleFr: 'Con Clavi Con Dio',
    titleEn: 'Con Clavi Con Dio',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-prep-fat-loss',
    conceptId: 'program.prep-fat-loss',
    titleFr: 'Prep and Fat Loss',
    titleEn: 'Prep and Fat Loss',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-strength-circuits',
    conceptId: 'program.strength-circuits',
    titleFr: '5/3/1 Strength Circuits',
    titleEn: '5/3/1 Strength Circuits',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-widowmaker-circuit',
    conceptId: 'program.widowmaker-circuit',
    titleFr: 'Widowmaker Circuit',
    titleEn: 'Widowmaker Circuit',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-ceremony-of-opposites',
    conceptId: 'program.ceremony-of-opposites',
    titleFr: 'Ceremony of Opposites',
    titleEn: 'Ceremony of Opposites',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-2x2x2',
    conceptId: 'program.2x2x2',
    titleFr: '2x2x2',
    titleEn: '2x2x2',
  ),
  ProgramLibraryEntry.foreverDocumentary(
    id: 'program-krypteia',
    conceptId: 'program.krypteia',
    titleFr: 'Krypteia',
    titleEn: 'The Krypteia',
  ),
];
