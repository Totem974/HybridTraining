import 'package:training_engine/features/cycle_generation/domain/cycle_contract.dart';
import 'package:training_engine/features/cycle_generation/domain/cycle_option_schema.dart';
import 'package:training_engine/features/forever/domain/forever_architecture.dart'
    as architecture;
import 'package:training_engine/features/forever/domain/forever_contract.dart';
import '../../cycle_web/application/cycle_web_contract.dart';
import '../../training_catalog/application/catalog_repository.dart';
import '../data/forever_draft_payload.dart';
import '../data/forever_json_export.dart';
import '../data/sqlite_forever_draft_repository.dart';
import '../data/sqlite_forever_macrocycle_repository.dart';
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

final class ForeverWebApplicationImpl
    implements ForeverWebApplication, ForeverWebExportApplication {
  ForeverWebApplicationImpl({
    required this.catalogVersion,
    required this.definitionRepository,
    required this.catalogQuery,
    required this.cycleResolver,
    required this.composer,
    required this.draftRepository,
    required this.macrocycleRepository,
    required this.now,
  });

  final int catalogVersion;
  final ForeverDefinitionRepository definitionRepository;
  final CycleCatalogQuery catalogQuery;
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
    final payload = ForeverDraftPayload.decode(
      payloadVersion: stored.payloadVersion,
      definitionId: stored.definitionId,
      payload: stored.payload,
    );
    return ForeverEditorDraft(
      definitionId: stored.definitionId,
      definitionRevision: stored.definitionRevision,
      startDate: payload.startDate,
      trainingMaxCentiUnits: payload.trainingMaxCentiUnits,
      selectedCyclesBySlot: {
        for (final node in payload.architecture)
          node.id: '${node.templateId}/${node.variantId}',
      },
      architectureMode: payload.mode == ForeverDraftMode.preset
          ? ForeverWebArchitectureMode.preset
          : ForeverWebArchitectureMode.userDefined,
      nodes: stored.payloadVersion == 1
          ? const []
          : payload.architecture
                .map(
                  (node) => ForeverDraftNode(
                    id: node.id,
                    role: node.role,
                    cycleKey: '${node.templateId}/${node.variantId}',
                    configuration: node.configuration.isEmpty
                        ? null
                        : _cycleStateFromJson(node.configuration),
                  ),
                )
                .toList(growable: false),
      equipment: payload.equipment,
      globalOptions: payload.globalOptions,
    );
  }

  @override
  Future<void> saveDraft(ForeverEditorDraft draft) => draftRepository.save(
    StoredForeverDraft(
      id: 'forever-web-draft',
      payloadVersion: ForeverDraftPayload.currentVersion,
      definitionId: draft.definitionId,
      definitionRevision: draft.definitionRevision,
      payload: _draftPayload(draft).toJson(),
      updatedAt: now(),
    ),
  );

  @override
  Future<GeneratedMacrocycleView> generateSaveAndReload(
    ForeverEditorDraft draft,
  ) async {
    final published = await definitionRepository.resolve(
      catalogVersion: catalogVersion,
      id: ForeverDefinitionId(draft.definitionId),
      revision: ForeverDefinitionRevision(draft.definitionRevision),
    );
    final architectureValue = await _architecture(draft, published);
    final definition = architectureValue.toResolvedDefinition(
      labelEn: published.labelEn,
      labelFr: published.labelFr,
    );
    final macrocycleId =
        'forever-${draft.definitionId}-${now().toUtc().microsecondsSinceEpoch}';
    final macrocycle = await composer.compose(
      definition,
      architectureValue.toRequest(
        macrocycleId: macrocycleId,
        startDate: draft.startDate,
        initialTrainingMaxes: draft.trainingMaxCentiUnits.map(
          (id, value) => MapEntry(MovementId(id), Weight(value, WeightUnit.lb)),
        ),
        unit: WeightUnit.lb,
        roundingIncrement: Weight(
          draft.equipment['roundingIncrementCentiUnits'] as int? ?? 500,
          WeightUnit.lb,
        ),
        barProfile: _barProfile(draft),
      ),
    );
    await macrocycleRepository.save(macrocycle: macrocycle, savedAt: now());
    await saveDraft(
      draft.copyWith(
        globalOptions: {
          ...draft.globalOptions,
          'lastMacrocycleId': macrocycle.id,
        },
      ),
    );
    final stored = await macrocycleRepository.load(macrocycle.id);
    return _storedView(stored);
  }

  @override
  Future<GeneratedMacrocycleView?> loadSavedMacrocycle() async {
    final draft = await loadDraft();
    if (draft == null) return null;
    final id = draft.globalOptions['lastMacrocycleId'] as String?;
    if (id == null || id.isEmpty) return null;
    try {
      return _storedView(await macrocycleRepository.load(id));
    } on StateError {
      return null;
    }
  }

  @override
  Future<String> exportDraft(ForeverEditorDraft draft) async {
    await saveDraft(draft);
    final stored = await draftRepository.load('forever-web-draft');
    if (stored == null) throw StateError('Forever draft was not saved.');
    return ForeverJsonExport.configuration(stored);
  }

  @override
  Future<String> exportMacrocycle(String macrocycleId) async =>
      ForeverJsonExport.result(await macrocycleRepository.load(macrocycleId));

  Future<architecture.ForeverArchitecture> _architecture(
    ForeverEditorDraft draft,
    ResolvedForeverDefinition published,
  ) async {
    final publishedSlots = {
      for (final phase in published.phases)
        for (final slot in phase.slots) slot.id: slot,
    };
    final nodes = <architecture.ForeverArchitectureNode>[];
    for (final draftNode in draft.nodes) {
      final slotId = draftNode.id.replaceFirst(RegExp(r'-\d+$'), '');
      final publishedSlot = publishedSlots[slotId];
      final reference = _reference(draftNode.cycleKey);
      final resolved = await cycleResolver.resolve(reference);
      final state = draftNode.configuration;
      final sessionOrder = state == null || state.sessionOrder.isEmpty
          ? resolved.sessionMovementIds
          : state.sessionOrder.map(MovementId.new).toList(growable: false);
      final trainingDays = state == null || state.trainingDays.isEmpty
          ? _days(sessionOrder.length)
          : state.trainingDays;
      final percentageParameters = <String, Percentage>{};
      final percentageParametersByMovement =
          <MovementId, Map<String, Percentage>>{};
      var includeDeload = true;
      if (state != null) {
        final schema = await catalogQuery.loadEditorSchema(
          catalogVersion: catalogVersion,
          templateId: state.templateId,
          variantId: state.variantId,
        );
        for (final option in schema.options) {
          final value = state.values[option.id] ?? option.defaultValue;
          if (option.id == 'include_deload') {
            includeDeload = value as bool;
          } else if (option.type == CycleOptionType.percentage) {
            if (option.scope == CycleOptionScope.perMovement) {
              for (final entry in (value as Map).entries) {
                percentageParametersByMovement.putIfAbsent(
                  MovementId(entry.key as String),
                  () => {},
                )[option.id] = Percentage(
                  (entry.value as num).round(),
                );
              }
            } else {
              percentageParameters[option.id] = Percentage(
                (value as num).round(),
              );
            }
          }
        }
      }
      final configuration = architecture.ForeverNodeConfiguration(
        cycle: reference,
        trainingDays: trainingDays,
        sessionOrder: sessionOrder,
        parameters: state?.values.cast<String, Object?>() ?? const {},
        percentageParameters: percentageParameters,
        percentageParametersByMovement: percentageParametersByMovement,
        globalTrainingMaxRatio: Percentage(
          state?.globalTrainingMaxRatioBasisPoints ?? 10000,
        ),
        trainingMaxRatioByMovement:
            (state?.trainingMaxRatioByMovementBasisPoints ?? const {}).map(
              (id, ratio) => MapEntry(MovementId(id), Percentage(ratio)),
            ),
        scheduleId: state?.values['scheduleId'] as String?,
        includeDeload: includeDeload,
      );
      nodes.add(
        architecture.ForeverArchitectureNode(
          id: draftNode.id,
          role: ForeverPhaseRole.values.byName(draftNode.role),
          transition:
              draft.architectureMode == ForeverWebArchitectureMode.preset
              ? publishedSlot!.transition
              : const ForeverTransition(trainingMaxRule: KeepTrainingMax()),
          configuration: configuration,
          allowedRoles:
              draft.architectureMode == ForeverWebArchitectureMode.preset
              ? [publishedSlot!.role]
              : ForeverPhaseRole.values,
          allowedCycles:
              draft.architectureMode == ForeverWebArchitectureMode.preset
              ? publishedSlot!.allowedCycles
              : [reference],
          required: draft.architectureMode == ForeverWebArchitectureMode.preset
              ? publishedSlot!.optional == false
              : false,
          locked: draft.architectureMode == ForeverWebArchitectureMode.preset,
        ),
      );
    }
    return architecture.ForeverArchitecture(
      id: draft.architectureMode == ForeverWebArchitectureMode.preset
          ? published.id.value
          : 'web-${draft.startDate.toUtc().millisecondsSinceEpoch}',
      mode: draft.architectureMode == ForeverWebArchitectureMode.preset
          ? architecture.ForeverArchitectureMode.preset
          : architecture.ForeverArchitectureMode.userDefined,
      nodes: nodes,
      presetDefinitionId:
          draft.architectureMode == ForeverWebArchitectureMode.preset
          ? published.id
          : null,
      presetRevision:
          draft.architectureMode == ForeverWebArchitectureMode.preset
          ? published.revision
          : null,
      sourceRuleIds: draft.architectureMode == ForeverWebArchitectureMode.preset
          ? published.sourceRuleIds
          : const ['userDefined'],
    );
  }

  BarProfile _barProfile(ForeverEditorDraft draft) {
    final bar = draft.equipment['barWeightCentiUnits'] as int? ?? 4500;
    final plates =
        (draft.equipment['platesPerSideCentiUnits'] as List?)?.cast<int>() ??
        const [4500, 3500, 2500, 1000, 500, 250];
    return BarProfile(
      weight: Weight(bar, WeightUnit.lb),
      platesPerSide: plates
          .map((value) => Weight(value, WeightUnit.lb))
          .toList(growable: false),
    );
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

  ForeverDraftPayload _draftPayload(ForeverEditorDraft draft) =>
      ForeverDraftPayload(
        mode: draft.architectureMode == ForeverWebArchitectureMode.preset
            ? ForeverDraftMode.preset
            : ForeverDraftMode.custom,
        presetId: draft.architectureMode == ForeverWebArchitectureMode.preset
            ? draft.definitionId
            : null,
        startDate: draft.startDate,
        architecture: draft.nodes
            .map((node) {
              final reference = _reference(node.cycleKey);
              return ForeverDraftNodePayload(
                id: node.id,
                role: node.role,
                templateId: reference.templateId,
                variantId: reference.variantId,
                configuration: node.configuration == null
                    ? const {}
                    : _cycleStateJson(node.configuration!),
              );
            })
            .toList(growable: false),
        trainingMaxCentiUnits: draft.trainingMaxCentiUnits,
        equipment: draft.equipment,
        globalOptions: draft.globalOptions,
      );

  Map<String, Object?> _cycleStateJson(CycleEditorState state) => {
    'templateId': state.templateId,
    'variantId': state.variantId,
    'values': state.values,
    'startDate': state.startDate?.toUtc().toIso8601String(),
    'trainingDays': state.trainingDays,
    'sessionOrder': state.sessionOrder,
    'maxInputs': state.maxInputs.map(
      (id, input) => MapEntry(id, {
        'kind': input.kind.name,
        'weightCentiUnits': input.weightCentiUnits,
        'repetitions': input.repetitions,
      }),
    ),
    'globalTrainingMaxRatioBasisPoints':
        state.globalTrainingMaxRatioBasisPoints,
    'trainingMaxRatioByMovementBasisPoints':
        state.trainingMaxRatioByMovementBasisPoints,
    'unit': state.unit.name,
    'roundingIncrementCentiUnits': state.roundingIncrementCentiUnits,
    'barWeightCentiUnits': state.barWeightCentiUnits,
    'platesPerSideCentiUnits': state.platesPerSideCentiUnits,
    'cycleId': state.cycleId,
  };

  CycleEditorState _cycleStateFromJson(Map<String, Object?> json) =>
      CycleEditorState(
        templateId: json['templateId']! as String,
        variantId: json['variantId']! as String,
        values: (json['values']! as Map).cast<String, Object>(),
        startDate: json['startDate'] == null
            ? null
            : DateTime.parse(json['startDate']! as String),
        trainingDays: (json['trainingDays']! as List<Object?>).cast<int>(),
        sessionOrder: (json['sessionOrder']! as List<Object?>).cast<String>(),
        maxInputs: ((json['maxInputs']! as Map).cast<String, Object?>()).map((
          id,
          raw,
        ) {
          final input = (raw! as Map).cast<String, Object?>();
          return MapEntry(
            id,
            CycleMovementMaxInput(
              kind: CycleMaxInputKind.values.byName(input['kind']! as String),
              weightCentiUnits: input['weightCentiUnits']! as int,
              repetitions: input['repetitions'] as int?,
            ),
          );
        }),
        globalTrainingMaxRatioBasisPoints:
            json['globalTrainingMaxRatioBasisPoints']! as int,
        trainingMaxRatioByMovementBasisPoints:
            (json['trainingMaxRatioByMovementBasisPoints']! as Map)
                .cast<String, int>(),
        unit: WeightUnit.values.byName(json['unit']! as String),
        roundingIncrementCentiUnits:
            json['roundingIncrementCentiUnits']! as int,
        barWeightCentiUnits: json['barWeightCentiUnits']! as int,
        platesPerSideCentiUnits:
            (json['platesPerSideCentiUnits']! as List<Object?>).cast<int>(),
        cycleId: json['cycleId']! as String,
      );

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
