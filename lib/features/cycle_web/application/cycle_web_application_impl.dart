import 'dart:convert';

import '../../cycle_generation/domain/cycle_contract.dart';
import '../../cycle_generation/domain/cycle_option_schema.dart';
import '../../training_catalog/application/catalog_repository.dart';
import '../../training_catalog/domain/catalog_index.dart';
import '../../training_log/application/training_snapshot_repository.dart';
import 'cycle_option_condition_evaluator.dart';
import 'cycle_web_contract.dart';
import 'cycle_web_draft_repository.dart';

final class CycleWebGenerationContext {
  const CycleWebGenerationContext({
    required this.startDate,
    required this.trainingDays,
    required this.maxInputs,
    required this.globalTrainingMaxRatio,
    this.trainingMaxRatioByMovement = const {},
    required this.unit,
    required this.roundingIncrement,
    required this.barProfile,
    required this.cycleId,
  });

  final DateTime startDate;
  final List<int> trainingDays;
  final Map<MovementId, TrainingMaxInput> maxInputs;
  final Percentage globalTrainingMaxRatio;
  final Map<MovementId, Percentage> trainingMaxRatioByMovement;
  final WeightUnit unit;
  final Weight roundingIncrement;
  final BarProfile barProfile;
  final String cycleId;
}

final class CycleWebApplicationImpl
    implements CycleWebApplication, CycleWebExportApplication {
  const CycleWebApplicationImpl({
    required this.catalogVersion,
    required this.catalogQuery,
    required this.catalogRepository,
    required this.draftRepository,
    required this.snapshotRepository,
    required this.compiler,
    required this.generationContext,
  });

  final int catalogVersion;
  final CycleCatalogQuery catalogQuery;
  final TrainingCatalogRepository catalogRepository;
  final CycleWebDraftRepository draftRepository;
  final TrainingSnapshotRepository snapshotRepository;
  final CycleCompiler compiler;
  final CycleWebGenerationContext generationContext;

  @override
  Future<CycleCatalogIndex> loadIndex() =>
      catalogQuery.loadIndex(catalogVersion: catalogVersion);

  @override
  Future<CycleEditorSchema> loadEditorSchema({
    required String templateId,
    required String variantId,
  }) => catalogQuery.loadEditorSchema(
    catalogVersion: catalogVersion,
    templateId: templateId,
    variantId: variantId,
  );

  @override
  Future<List<String>> loadMovementIds({
    required String templateId,
    required String variantId,
  }) async {
    final definition = await catalogRepository.resolve(
      catalogVersion: catalogVersion,
      templateId: templateId,
      variantId: variantId,
    );
    final movements = <String>{};
    for (final week in definition.weeks) {
      for (final session in week.sessions) {
        for (final block in session.blocks) {
          movements.add((block.movementId ?? session.id).value);
        }
      }
    }
    return movements.toList(growable: false)..sort();
  }

  @override
  Future<List<String>> loadSessionIds({
    required String templateId,
    required String variantId,
  }) async {
    final definition = await catalogRepository.resolve(
      catalogVersion: catalogVersion,
      templateId: templateId,
      variantId: variantId,
    );
    return definition.sessionMovementIds
        .map((movement) => movement.value)
        .toList(growable: false);
  }

  @override
  Future<CycleEditorState?> loadDraft() => draftRepository.load();

  @override
  Future<void> saveDraft(CycleEditorState state) => draftRepository.save(state);

  @override
  Future<GeneratedCycleView> generate(CycleEditorState state) async {
    final schema = await loadEditorSchema(
      templateId: state.templateId,
      variantId: state.variantId,
    );
    _validateState(state, schema);
    final definition = await catalogRepository.resolve(
      catalogVersion: catalogVersion,
      templateId: state.templateId,
      variantId: state.variantId,
    );
    final request = _request(state, schema, definition);
    final cycle = compiler.compile(definition, request);
    await snapshotRepository.save(cycle);
    final persisted = await snapshotRepository.load(cycle.id);
    if (persisted.cycleId != cycle.id) {
      throw StateError('Persisted Cycle snapshot does not match generation.');
    }
    return GeneratedCycleView(cycle, persistedSnapshot: persisted);
  }

  @override
  Future<String> exportCycleDraft(CycleEditorState state) async {
    await saveDraft(state);
    return jsonEncode({
      'schema': 'hybrid-training.cycle',
      'schemaVersion': 1,
      'kind': 'configuration',
      'templateId': state.templateId,
      'variantId': state.variantId,
      'values': state.values,
      'startDate': state.startDate?.toUtc().toIso8601String(),
      'trainingDays': state.trainingDays,
      'sessionOrder': state.sessionOrder,
      'globalTrainingMaxRatioBasisPoints':
          state.globalTrainingMaxRatioBasisPoints,
      'trainingMaxRatioByMovementBasisPoints':
          state.trainingMaxRatioByMovementBasisPoints,
      'unit': state.unit.name,
      'roundingIncrementCentiUnits': state.roundingIncrementCentiUnits,
      'barWeightCentiUnits': state.barWeightCentiUnits,
      'platesPerSideCentiUnits': state.platesPerSideCentiUnits,
    });
  }

  @override
  Future<String> exportGeneratedCycle(GeneratedCycleView view) async =>
      jsonEncode({
        'schema': 'hybrid-training.cycle',
        'schemaVersion': 1,
        'kind': 'result',
        'snapshot': view.cycle.toJson(),
      });

  CycleRequest _request(
    CycleEditorState state,
    CycleEditorSchema schema,
    ResolvedCycleDefinition definition,
  ) {
    final startDate = state.startDate ?? generationContext.startDate;
    final trainingDays = state.trainingDays.isEmpty
        ? generationContext.trainingDays
        : state.trainingDays;
    final sessionOrder = state.sessionOrder.isEmpty
        ? definition.sessionMovementIds
        : state.sessionOrder.map(MovementId.new).toList(growable: false);
    final maxInputs = state.maxInputs.isEmpty
        ? generationContext.maxInputs
        : state.maxInputs.map(
            (id, input) =>
                MapEntry(MovementId(id), _maxInput(input, state.unit)),
          );
    final globalRatio = Percentage(state.globalTrainingMaxRatioBasisPoints);
    var includeDeload = true;
    final percentages = <String, Percentage>{};
    final percentagesByMovement = <MovementId, Map<String, Percentage>>{};
    for (final option in schema.options) {
      final value = state.values[option.id] ?? option.defaultValue;
      if (option.id == 'include_deload') {
        includeDeload = value as bool;
      } else if (option.type == CycleOptionType.percentage) {
        if (option.scope == CycleOptionScope.perMovement) {
          final values = value as Map<Object?, Object?>;
          for (final entry in values.entries) {
            final movement = MovementId(entry.key! as String);
            percentagesByMovement.putIfAbsent(movement, () => {})[option.id] =
                Percentage(_integer(entry.value!, option.id));
          }
        } else {
          percentages[option.id] = Percentage(_integer(value, option.id));
        }
      }
    }
    return CycleRequest(
      cycleId: state.cycleId.isEmpty
          ? generationContext.cycleId
          : state.cycleId,
      startDate: startDate,
      trainingDays: trainingDays,
      sessionOrder: sessionOrder,
      maxInputs: maxInputs,
      globalTrainingMaxRatio: globalRatio,
      trainingMaxRatioByMovement:
          state.trainingMaxRatioByMovementBasisPoints.isEmpty
          ? generationContext.trainingMaxRatioByMovement
          : state.trainingMaxRatioByMovementBasisPoints.map(
              (id, ratio) => MapEntry(MovementId(id), Percentage(ratio)),
            ),
      percentageParameters: percentages,
      percentageParametersByMovement: percentagesByMovement,
      unit: state.unit,
      roundingIncrement: Weight(_roundingIncrement(state), state.unit),
      barProfile: BarProfile(
        weight: Weight(state.barWeightCentiUnits, state.unit),
        platesPerSide: state.platesPerSideCentiUnits
            .map((weight) => Weight(weight, state.unit))
            .toList(growable: false),
      ),
      includeDeload: includeDeload,
    );
  }

  int _roundingIncrement(CycleEditorState state) {
    final positivePlates = state.platesPerSideCentiUnits.where(
      (plate) => plate > 0,
    );
    if (positivePlates.isEmpty) {
      return generationContext.roundingIncrement.centiUnits;
    }
    return positivePlates.reduce((left, right) => left < right ? left : right) *
        2;
  }

  TrainingMaxInput _maxInput(CycleMovementMaxInput input, WeightUnit unit) {
    final weight = Weight(input.weightCentiUnits, unit);
    return switch (input.kind) {
      CycleMaxInputKind.oneRepMax => OneRepMaxInput(weight),
      CycleMaxInputKind.repMax => RepMaxInput(
        weight,
        input.repetitions ??
            (throw const FormatException('Rep-max repetitions are required.')),
      ),
      CycleMaxInputKind.directTrainingMax => DirectTrainingMaxInput(weight),
    };
  }

  void _validateState(CycleEditorState state, CycleEditorSchema schema) {
    if (schema.templateId != state.templateId ||
        schema.variantId != state.variantId) {
      throw const FormatException('Editor state does not match its schema.');
    }
    final known = schema.options.map((option) => option.id).toSet();
    final unknown = state.values.keys.where((key) => !known.contains(key));
    if (unknown.isNotEmpty) {
      throw FormatException('Unknown Cycle option ${unknown.first}.');
    }
    for (final option in schema.options) {
      if (!CycleOptionConditionEvaluator.evaluate(
        option.visibleWhen,
        state.values,
      )) {
        continue;
      }
      final value = state.values[option.id] ?? option.defaultValue;
      final required = CycleOptionConditionEvaluator.evaluate(
        option.requiredWhen,
        state.values,
      );
      if (required && value is String && value.trim().isEmpty) {
        throw FormatException('Cycle option ${option.id} is required.');
      }
      _validateType(option, value);
      if (value is num) {
        if (option.minimum case final minimum? when value < minimum) {
          throw FormatException('Cycle option ${option.id} is below minimum.');
        }
        if (option.maximum case final maximum? when value > maximum) {
          throw FormatException('Cycle option ${option.id} exceeds maximum.');
        }
      }
      if (option.scope != CycleOptionScope.perMovement &&
          option.allowedValues.isNotEmpty &&
          !option.allowedValues.contains(value)) {
        throw FormatException('Cycle option ${option.id} is not allowed.');
      }
    }
  }

  void _validateType(CycleOptionDefinition option, Object value) {
    if (option.scope == CycleOptionScope.perMovement) {
      if (value is! Map<Object?, Object?> ||
          value.entries.any(
            (entry) => entry.key is! String || entry.value is! num,
          )) {
        throw FormatException(
          'Per-movement Cycle option ${option.id} has the wrong type.',
        );
      }
      return;
    }
    final valid = switch (option.type) {
      CycleOptionType.boolean => value is bool,
      CycleOptionType.integer => value is int,
      CycleOptionType.percentage || CycleOptionType.weight => value is num,
      CycleOptionType.enumeration ||
      CycleOptionType.movement ||
      CycleOptionType.exercise ||
      CycleOptionType.prescription => value is String,
    };
    if (!valid) {
      throw FormatException('Cycle option ${option.id} has the wrong type.');
    }
  }

  int _integer(Object value, String id) {
    if (value is int) return value;
    if (value is double && value == value.roundToDouble()) return value.toInt();
    throw FormatException(
      'Cycle option $id must be an integer basis-point value.',
    );
  }
}
