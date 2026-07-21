import '../../cycle_generation/domain/cycle_contract.dart';
import '../../cycle_generation/domain/cycle_option_schema.dart';
import '../../training_catalog/domain/catalog_index.dart';
import '../../training_log/domain/training_snapshot.dart';

final class CycleEditorState {
  const CycleEditorState({
    required this.templateId,
    required this.variantId,
    this.values = const {},
    this.startDate,
    this.trainingDays = const [],
    this.sessionOrder = const [],
    this.maxInputs = const {},
    this.globalTrainingMaxRatioBasisPoints = 9000,
    this.trainingMaxRatioByMovementBasisPoints = const {},
    this.unit = WeightUnit.kg,
    this.roundingIncrementCentiUnits = 250,
    this.barWeightCentiUnits = 2000,
    this.platesPerSideCentiUnits = const [],
    this.cycleId = '',
  });

  final String templateId;
  final String variantId;
  final Map<String, Object> values;
  final DateTime? startDate;
  final List<int> trainingDays;
  final List<String> sessionOrder;
  final Map<String, CycleMovementMaxInput> maxInputs;
  final int globalTrainingMaxRatioBasisPoints;
  final Map<String, int> trainingMaxRatioByMovementBasisPoints;
  final WeightUnit unit;
  final int roundingIncrementCentiUnits;
  final int barWeightCentiUnits;
  final List<int> platesPerSideCentiUnits;
  final String cycleId;

  CycleEditorState copyWith({
    String? templateId,
    String? variantId,
    Map<String, Object>? values,
    DateTime? startDate,
    List<int>? trainingDays,
    List<String>? sessionOrder,
    Map<String, CycleMovementMaxInput>? maxInputs,
    int? globalTrainingMaxRatioBasisPoints,
    Map<String, int>? trainingMaxRatioByMovementBasisPoints,
    WeightUnit? unit,
    int? roundingIncrementCentiUnits,
    int? barWeightCentiUnits,
    List<int>? platesPerSideCentiUnits,
    String? cycleId,
  }) => CycleEditorState(
    templateId: templateId ?? this.templateId,
    variantId: variantId ?? this.variantId,
    values: values ?? this.values,
    startDate: startDate ?? this.startDate,
    trainingDays: trainingDays ?? this.trainingDays,
    sessionOrder: sessionOrder ?? this.sessionOrder,
    maxInputs: maxInputs ?? this.maxInputs,
    globalTrainingMaxRatioBasisPoints:
        globalTrainingMaxRatioBasisPoints ??
        this.globalTrainingMaxRatioBasisPoints,
    trainingMaxRatioByMovementBasisPoints:
        trainingMaxRatioByMovementBasisPoints ??
        this.trainingMaxRatioByMovementBasisPoints,
    unit: unit ?? this.unit,
    roundingIncrementCentiUnits:
        roundingIncrementCentiUnits ?? this.roundingIncrementCentiUnits,
    barWeightCentiUnits: barWeightCentiUnits ?? this.barWeightCentiUnits,
    platesPerSideCentiUnits:
        platesPerSideCentiUnits ?? this.platesPerSideCentiUnits,
    cycleId: cycleId ?? this.cycleId,
  );
}

enum CycleMaxInputKind { oneRepMax, repMax, directTrainingMax }

final class CycleMovementMaxInput {
  const CycleMovementMaxInput({
    required this.kind,
    required this.weightCentiUnits,
    this.repetitions,
  });

  final CycleMaxInputKind kind;
  final int weightCentiUnits;
  final int? repetitions;
}

sealed class CycleEditorIntent {
  const CycleEditorIntent();
}

final class SelectTemplateIntent extends CycleEditorIntent {
  const SelectTemplateIntent(this.templateId);
  final String templateId;
}

final class SelectVariantIntent extends CycleEditorIntent {
  const SelectVariantIntent(this.variantId);
  final String variantId;
}

final class SetCycleOptionIntent extends CycleEditorIntent {
  const SetCycleOptionIntent(this.optionId, this.value);
  final String optionId;
  final Object value;
}

final class GeneratedCycleView {
  const GeneratedCycleView(this.cycle, {this.persistedSnapshot});
  final GeneratedCycle cycle;
  final StoredTrainingSnapshot? persistedSnapshot;
}

abstract interface class CycleWebApplication {
  Future<CycleCatalogIndex> loadIndex();
  Future<CycleEditorSchema> loadEditorSchema({
    required String templateId,
    required String variantId,
  });
  Future<List<String>> loadMovementIds({
    required String templateId,
    required String variantId,
  });
  Future<CycleEditorState?> loadDraft();
  Future<void> saveDraft(CycleEditorState state);
  Future<GeneratedCycleView> generate(CycleEditorState state);
}
