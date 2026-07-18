import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';
import 'package:hybrid_training/features/programs/domain/program_library.dart';

void main() {
  const repository = InMemoryProgramLibraryRepository();

  test('catalogue exposes every canonical entry type', () {
    final result = repository.query(const ProgramQuery());
    expect(result.entries, hasLength(canonicalProgramEntries.length));
    expect(
      result.entries.map((e) => e.kind).toSet(),
      ProgramEntryKind.values.toSet(),
    );
    expect(result.entries.length, greaterThanOrEqualTo(45));
    expect(
      result.entries.map((entry) => entry.conceptId),
      containsAll([
        'program.beginner-prep-school',
        'program.1000-percent-awesome',
        'program.krypteia',
        'component.5s-pro',
      ]),
    );
  });

  test('search ignores accents and case in French and English', () {
    expect(
      repository.query(const ProgramQuery(search: 'executable')).entries,
      isNotEmpty,
    );
    expect(
      repository.query(const ProgramQuery(search: 'polyvalent')).entries,
      hasLength(1),
    );
  });

  test('every filter dimension is supported', () {
    final filters = <String, ProgramFilter>{
      'origin': const ProgramFilter(origins: {MethodGeneration.beyond}),
      'generation': const ProgramFilter(
        generations: {MethodGeneration.original},
      ),
      'Forever status': const ProgramFilter(
        foreverStatuses: {ForeverStatus.superseded},
      ),
      'kind': const ProgramFilter(kinds: {ProgramEntryKind.protocol}),
      'phase': const ProgramFilter(phases: {ProgramPhase.transition}),
      'level': const ProgramFilter(levels: {ProgramLevel.beginner}),
      'goal': const ProgramFilter(goals: {ProgramGoal.general}),
      'frequency': const ProgramFilter(frequencies: {3}),
      'main movements': const ProgramFilter(mainMovementsPerSession: {2}),
      'equipment': const ProgramFilter(
        equipment: {ProgramEquipment.bodyweight},
      ),
      'TM range': const ProgramFilter(tmRange: ProgramTmRange(.85, .86)),
      'documentation': const ProgramFilter(
        documentationStatuses: {ProgramValidationStatus.rulesReviewed},
      ),
      'implementation': const ProgramFilter(
        implementationStatuses: {ProgramImplementationStatus.productionReady},
      ),
    };
    for (final MapEntry(key: dimension, value: filter) in filters.entries) {
      expect(
        repository.query(ProgramQuery(filter: filter)).entries,
        isNotEmpty,
        reason: 'filter dimension: $dimension',
      );
    }
  });

  test('filters compose with AND semantics', () {
    final result = repository.query(
      const ProgramQuery(
        filter: ProgramFilter(
          kinds: {ProgramEntryKind.preset},
          frequencies: {3},
          levels: {ProgramLevel.beginner},
          goals: {ProgramGoal.general},
          mainMovementsPerSession: {2},
        ),
      ),
    );
    expect(result.entries.single.conceptId, 'program.beginner-prep-school');
  });

  test('all sorts are stable and deterministic', () {
    for (final sort in ProgramLibrarySort.values) {
      final first = repository
          .query(ProgramQuery(sort: sort))
          .entries
          .map((e) => e.id)
          .toList();
      final second = repository
          .query(ProgramQuery(sort: sort))
          .entries
          .map((e) => e.id)
          .toList();
      expect(second, first);
    }
  });

  test('concept spans generations and concept has one-to-many preset API', () {
    final original = repository
        .query(const ProgramQuery())
        .entries
        .where((e) => e.conceptId == 'program.original-531')
        .toList();
    expect(original.map((e) => e.generation).toSet(), {
      MethodGeneration.original,
      MethodGeneration.forever,
    });
    expect(
      repository.presetsForConcept('program.original-531-fsl'),
      hasLength(1),
    );
  });

  test('repository preserves a one-to-many concept-to-preset relation', () {
    const entries = [
      ProgramLibraryEntry(
        id: 'preset-a',
        conceptId: 'concept-a',
        titleFr: 'Preset A',
        titleEn: 'Preset A',
        kind: ProgramEntryKind.preset,
        origin: MethodGeneration.forever,
        generation: MethodGeneration.forever,
        foreverStatus: ForeverStatus.current,
        documentationStatus: ProgramValidationStatus.rulesReviewed,
        implementationStatus: ProgramImplementationStatus.experimental,
        presetId: 'preset-a-v1',
      ),
      ProgramLibraryEntry(
        id: 'preset-b',
        conceptId: 'concept-a',
        titleFr: 'Preset B',
        titleEn: 'Preset B',
        kind: ProgramEntryKind.preset,
        origin: MethodGeneration.forever,
        generation: MethodGeneration.forever,
        foreverStatus: ForeverStatus.current,
        documentationStatus: ProgramValidationStatus.rulesReviewed,
        implementationStatus: ProgramImplementationStatus.experimental,
        presetId: 'preset-b-v1',
      ),
    ];
    const fixture = InMemoryProgramLibraryRepository(entries);
    expect(fixture.presetsForConcept('concept-a'), hasLength(2));
  });

  test('only an implemented preset can be selected', () {
    final executable = repository.findById('preset-forever-original-fsl')!;
    final component = repository.findById('component-fsl')!;
    final documentary = repository.findById('program-coffinworm')!;
    expect(executable.isExecutable, isTrue);
    expect(
      repository.findById('preset-forever-beginner-prep-school')!.isExecutable,
      isTrue,
    );
    expect(component.isExecutable, isFalse);
    expect(documentary.isExecutable, isFalse);
  });
}
