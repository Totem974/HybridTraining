import '../../cycle_generation/domain/cycle_contract.dart';
import '../../training_catalog/application/catalog_repository.dart';
import '../data/sqlite_forever_draft_repository.dart';
import '../data/sqlite_forever_macrocycle_repository.dart';
import '../domain/forever_contract.dart';
import '../presentation/forever_web_contract.dart';

final class CatalogForeverCycleResolver
    implements ForeverCycleDefinitionResolver {
  const CatalogForeverCycleResolver(this.catalog, this.catalogVersion);

  final TrainingCatalogRepository catalog;
  final int catalogVersion;

  @override
  Future<ResolvedCycleDefinition> resolve(ForeverCycleReference reference) =>
      catalog.resolve(
        catalogVersion: catalogVersion,
        templateId: reference.templateId,
        variantId: reference.variantId,
      );
}

final class ForeverWebApplicationImpl implements ForeverWebApplication {
  ForeverWebApplicationImpl({
    required this.catalogVersion,
    required this.definitionRepository,
    required this.cycleResolver,
    required this.composer,
    required this.draftRepository,
    required this.macrocycleRepository,
    required this.now,
  });

  final int catalogVersion;
  final ForeverDefinitionRepository definitionRepository;
  final ForeverCycleDefinitionResolver cycleResolver;
  final ForeverComposer composer;
  final SqliteForeverDraftRepository draftRepository;
  final SqliteForeverMacrocycleRepository macrocycleRepository;
  final DateTime Function() now;

  @override
  Future<List<ForeverDefinitionItem>> loadDefinitions() async {
    final definitions = await definitionRepository.loadPublishedDefinitions(
      catalogVersion,
    );
    return Future.wait(definitions.map(_definitionItem));
  }

  @override
  Future<ForeverEditorDraft?> loadDraft() async {
    final stored = await draftRepository.load('forever-web-draft');
    if (stored == null) return null;
    final payload = stored.payload;
    return ForeverEditorDraft(
      definitionId: stored.definitionId,
      definitionRevision: stored.definitionRevision,
      startDate: DateTime.parse(payload['startDate']! as String),
      trainingMaxCentiUnits: (payload['trainingMaxes']! as Map).map(
        (key, value) => MapEntry(key as String, value as int),
      ),
      selectedCyclesBySlot: (payload['selectedCycles']! as Map).map(
        (key, value) => MapEntry(key as String, value as String),
      ),
    );
  }

  @override
  Future<void> saveDraft(ForeverEditorDraft draft) => draftRepository.save(
    StoredForeverDraft(
      id: 'forever-web-draft',
      payloadVersion: 1,
      definitionId: draft.definitionId,
      definitionRevision: draft.definitionRevision,
      payload: {
        'startDate': draft.startDate.toUtc().toIso8601String(),
        'trainingMaxes': draft.trainingMaxCentiUnits,
        'selectedCycles': draft.selectedCyclesBySlot,
      },
      updatedAt: now(),
    ),
  );

  @override
  Future<GeneratedMacrocycleView> generateSaveAndReload(
    ForeverEditorDraft draft,
  ) async {
    final definition = await definitionRepository.resolve(
      catalogVersion: catalogVersion,
      id: ForeverDefinitionId(draft.definitionId),
      revision: ForeverDefinitionRevision(draft.definitionRevision),
    );
    final slotRequests = <String, ForeverSlotRequest>{};
    for (final phase in definition.phases) {
      for (final slot in phase.slots) {
        final selected = _reference(
          draft.selectedCyclesBySlot[slot.id] ?? slot.defaultCycle.key,
        );
        final cycle = await cycleResolver.resolve(selected);
        slotRequests[slot.id] = ForeverSlotRequest(
          slotId: slot.id,
          cycle: selected,
          trainingDays: _days(cycle.sessionMovementIds.length),
          sessionOrder: cycle.sessionMovementIds,
          includeDeload: false,
        );
      }
    }
    final macrocycleId =
        'forever-${draft.definitionId}-${draft.startDate.toUtc().millisecondsSinceEpoch}';
    final macrocycle = await composer.compose(
      definition,
      ForeverRequest(
        macrocycleId: macrocycleId,
        definitionId: definition.id,
        definitionRevision: definition.revision,
        startDate: draft.startDate,
        initialTrainingMaxes: draft.trainingMaxCentiUnits.map(
          (id, value) => MapEntry(MovementId(id), Weight(value, WeightUnit.lb)),
        ),
        slotRequests: slotRequests,
        unit: WeightUnit.lb,
        roundingIncrement: const Weight(500, WeightUnit.lb),
        barProfile: const BarProfile(
          weight: Weight(4500, WeightUnit.lb),
          platesPerSide: [
            Weight(4500, WeightUnit.lb),
            Weight(3500, WeightUnit.lb),
            Weight(2500, WeightUnit.lb),
            Weight(1000, WeightUnit.lb),
            Weight(500, WeightUnit.lb),
            Weight(250, WeightUnit.lb),
          ],
        ),
      ),
    );
    await macrocycleRepository.save(macrocycle: macrocycle, savedAt: now());
    final stored = await macrocycleRepository.load(macrocycle.id);
    return _storedView(stored);
  }

  @override
  Future<GeneratedMacrocycleView?> loadSavedMacrocycle() async {
    final draft = await loadDraft();
    if (draft == null) return null;
    try {
      return _storedView(await macrocycleRepository.load(_macrocycleId(draft)));
    } on StateError {
      return null;
    }
  }

  Future<ForeverDefinitionItem> _definitionItem(
    ResolvedForeverDefinition definition,
  ) async {
    final movements = <String>{};
    final phases = <ForeverPhaseItem>[];
    for (final phase in definition.phases) {
      final slots = <ForeverSlotItem>[];
      for (final slot in phase.slots) {
        final choices = <ForeverCycleChoice>[];
        for (final reference in slot.allowedCycles) {
          final cycle = await cycleResolver.resolve(reference);
          choices.add(
            ForeverCycleChoice(
              key: reference.key,
              label: '${cycle.templateId} · ${cycle.variantId}',
            ),
          );
          for (final week in cycle.weeks) {
            for (final session in week.sessions) {
              for (final block in session.blocks) {
                movements.add((block.movementId ?? session.id).value);
              }
            }
          }
        }
        slots.add(
          ForeverSlotItem(
            id: slot.id,
            role: slot.role.name,
            repeatCount: slot.repeatCount,
            defaultCycleKey: slot.defaultCycle.key,
            allowedCycles: choices,
            optional: slot.optional,
          ),
        );
      }
      phases.add(ForeverPhaseItem(id: phase.id, slots: slots));
    }
    return ForeverDefinitionItem(
      id: definition.id.value,
      revision: definition.revision.value,
      labelEn: definition.labelEn,
      labelFr: definition.labelFr,
      phases: phases,
      movementIds: movements.toList()..sort(),
    );
  }

  GeneratedMacrocycleView _storedView(StoredMacrocycle stored) {
    final nodes = stored.nodes
        .map((node) {
          final cycle = (node['cycle']! as Map).cast<String, Object?>();
          final weeks = (cycle['weeks']! as List<Object?>).cast<Map>();
          final dates = weeks
              .expand(
                (week) => (week['sessions']! as List<Object?>).cast<Map>(),
              )
              .map((session) => DateTime.parse(session['date']! as String))
              .toList(growable: false);
          final reference = (node['cycleReference']! as Map)
              .cast<String, Object?>();
          return GeneratedMacrocycleNodeView(
            index: node['index']! as int,
            role: node['role']! as String,
            cycleLabel: '${reference['templateId']}/${reference['variantId']}',
            startDate: dates.first,
            endDate: dates.last,
            trainingMaxesBefore: _storedMaxes(node['trainingMaxesBefore']!),
            trainingMaxesAfter: _storedMaxes(node['trainingMaxesAfter']!),
            weeks: [
              for (final week in weeks)
                ForeverCycleWeekView(
                  number: week['number']! as int,
                  sessions: (week['sessions']! as List<Object?>)
                      .cast<Map>()
                      .map((session) => session['movementId']! as String)
                      .toList(growable: false),
                ),
            ],
          );
        })
        .toList(growable: false);
    return GeneratedMacrocycleView(
      id: stored.id,
      state: stored.state.name,
      nodes: nodes,
      wasReloaded: true,
    );
  }

  Map<String, int> _storedMaxes(Object value) {
    final snapshot = (value as Map).cast<String, Object?>();
    final values = (snapshot['values']! as Map).cast<String, Object?>();
    return values.map((id, raw) {
      final weight = (raw! as Map).cast<String, Object?>();
      return MapEntry(id, weight['centiUnits']! as int);
    });
  }

  ForeverCycleReference _reference(String key) {
    final separator = key.indexOf('/');
    if (separator <= 0 || separator == key.length - 1) {
      throw FormatException('Invalid Cycle reference $key.');
    }
    return ForeverCycleReference(
      templateId: key.substring(0, separator),
      variantId: key.substring(separator + 1),
    );
  }

  String _macrocycleId(ForeverEditorDraft draft) =>
      'forever-${draft.definitionId}-${draft.startDate.toUtc().millisecondsSinceEpoch}';

  List<int> _days(int count) => switch (count) {
    1 => const [1],
    2 => const [1, 4],
    3 => const [1, 3, 5],
    4 => const [1, 2, 4, 5],
    5 => const [1, 2, 3, 5, 6],
    6 => const [1, 2, 3, 4, 5, 6],
    7 => const [1, 2, 3, 4, 5, 6, 7],
    _ => throw StateError('Unsupported session count $count.'),
  };
}
