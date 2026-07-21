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

final class CycleWebApplicationImpl implements CycleWebApplication {
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
    return GeneratedCycleView(cycle);
  }

  CycleRequest _request(
    CycleEditorState state,
    CycleEditorSchema schema,
    ResolvedCycleDefinition definition,
  ) {
    var globalRatio = generationContext.globalTrainingMaxRatio;
    var includeDeload = true;
    final percentages = <String, Percentage>{};
    final percentagesByMovement = <MovementId, Map<String, Percentage>>{};
    for (final option in schema.options) {
      final value = state.values[option.id] ?? option.defaultValue;
      if (option.id == 'training_max_ratio') {
        globalRatio = Percentage(_integer(value, option.id));
      } else if (option.id == 'include_deload') {
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
      cycleId: generationContext.cycleId,
      startDate: generationContext.startDate,
      trainingDays: generationContext.trainingDays,
      sessionOrder: definition.sessionMovementIds,
      maxInputs: generationContext.maxInputs,
      globalTrainingMaxRatio: globalRatio,
      trainingMaxRatioByMovement: generationContext.trainingMaxRatioByMovement,
      percentageParameters: percentages,
      percentageParametersByMovement: percentagesByMovement,
      unit: generationContext.unit,
      roundingIncrement: generationContext.roundingIncrement,
      barProfile: generationContext.barProfile,
      includeDeload: includeDeload,
    );
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
