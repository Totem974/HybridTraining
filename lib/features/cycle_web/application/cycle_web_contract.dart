import '../../cycle_generation/domain/cycle_contract.dart';
import '../../cycle_generation/domain/cycle_option_schema.dart';
import '../../training_catalog/domain/catalog_index.dart';

final class CycleEditorState {
  const CycleEditorState({
    required this.templateId,
    required this.variantId,
    this.values = const {},
  });

  final String templateId;
  final String variantId;
  final Map<String, Object> values;
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
  const GeneratedCycleView(this.cycle);
  final GeneratedCycle cycle;
}

abstract interface class CycleWebApplication {
  Future<CycleCatalogIndex> loadIndex();
  Future<CycleEditorSchema> loadEditorSchema({
    required String templateId,
    required String variantId,
  });
  Future<CycleEditorState?> loadDraft();
  Future<void> saveDraft(CycleEditorState state);
  Future<GeneratedCycleView> generate(CycleEditorState state);
}
