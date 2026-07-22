import 'package:flutter/foundation.dart';

@immutable
final class ForeverDefinitionItem {
  const ForeverDefinitionItem({
    required this.id,
    required this.revision,
    required this.labelEn,
    required this.labelFr,
    required this.phases,
    required this.movementIds,
  });

  final String id;
  final int revision;
  final String labelEn;
  final String labelFr;
  final List<ForeverPhaseItem> phases;
  final List<String> movementIds;
}

@immutable
final class ForeverPhaseItem {
  const ForeverPhaseItem({required this.id, required this.slots});
  final String id;
  final List<ForeverSlotItem> slots;
}

@immutable
final class ForeverSlotItem {
  const ForeverSlotItem({
    required this.id,
    required this.role,
    required this.repeatCount,
    required this.defaultCycleKey,
    required this.allowedCycles,
    this.optional = false,
  });

  final String id;
  final String role;
  final int repeatCount;
  final String defaultCycleKey;
  final List<ForeverCycleChoice> allowedCycles;
  final bool optional;
}

@immutable
final class ForeverCycleChoice {
  const ForeverCycleChoice({required this.key, required this.label});
  final String key;
  final String label;
}

@immutable
final class ForeverEditorDraft {
  const ForeverEditorDraft({
    required this.definitionId,
    required this.definitionRevision,
    required this.startDate,
    required this.trainingMaxCentiUnits,
    required this.selectedCyclesBySlot,
  });

  final String definitionId;
  final int definitionRevision;
  final DateTime startDate;
  final Map<String, int> trainingMaxCentiUnits;
  final Map<String, String> selectedCyclesBySlot;

  ForeverEditorDraft copyWith({
    String? definitionId,
    int? definitionRevision,
    DateTime? startDate,
    Map<String, int>? trainingMaxCentiUnits,
    Map<String, String>? selectedCyclesBySlot,
  }) => ForeverEditorDraft(
    definitionId: definitionId ?? this.definitionId,
    definitionRevision: definitionRevision ?? this.definitionRevision,
    startDate: startDate ?? this.startDate,
    trainingMaxCentiUnits: trainingMaxCentiUnits ?? this.trainingMaxCentiUnits,
    selectedCyclesBySlot: selectedCyclesBySlot ?? this.selectedCyclesBySlot,
  );
}

@immutable
final class GeneratedMacrocycleView {
  const GeneratedMacrocycleView({
    required this.id,
    required this.state,
    required this.nodes,
    required this.wasReloaded,
  });

  final String id;
  final String state;
  final List<GeneratedMacrocycleNodeView> nodes;
  final bool wasReloaded;
}

@immutable
final class GeneratedMacrocycleNodeView {
  const GeneratedMacrocycleNodeView({
    required this.index,
    required this.role,
    required this.cycleLabel,
    required this.startDate,
    required this.endDate,
    required this.trainingMaxesBefore,
    required this.trainingMaxesAfter,
    required this.weeks,
  });

  final int index;
  final String role;
  final String cycleLabel;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, int> trainingMaxesBefore;
  final Map<String, int> trainingMaxesAfter;
  final List<ForeverCycleWeekView> weeks;
}

@immutable
final class ForeverCycleWeekView {
  const ForeverCycleWeekView({required this.number, required this.sessions});
  final int number;
  final List<String> sessions;
}

abstract interface class ForeverWebApplication {
  Future<List<ForeverDefinitionItem>> loadDefinitions();
  Future<ForeverEditorDraft?> loadDraft();
  Future<void> saveDraft(ForeverEditorDraft draft);
  Future<GeneratedMacrocycleView> generateSaveAndReload(
    ForeverEditorDraft draft,
  );
  Future<GeneratedMacrocycleView?> loadSavedMacrocycle();
}
