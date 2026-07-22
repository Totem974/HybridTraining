import 'package:flutter/foundation.dart';

import '../../cycle_web/application/cycle_web_contract.dart';

enum ForeverWebArchitectureMode { preset, userDefined }

@immutable
final class ForeverDraftNode {
  const ForeverDraftNode({
    required this.id,
    required this.role,
    required this.cycleKey,
    this.optionSummary = const [],
    this.configuration,
  });

  final String id;
  final String role;
  final String cycleKey;
  final List<String> optionSummary;
  final CycleEditorState? configuration;

  ForeverDraftNode copyWith({
    String? id,
    String? role,
    String? cycleKey,
    CycleEditorState? configuration,
    bool clearConfiguration = false,
  }) => ForeverDraftNode(
    id: id ?? this.id,
    role: role ?? this.role,
    cycleKey: cycleKey ?? this.cycleKey,
    optionSummary: optionSummary,
    configuration: clearConfiguration
        ? null
        : configuration ?? this.configuration,
  );
}

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
    this.architectureMode = ForeverWebArchitectureMode.preset,
    this.nodes = const [],
    this.equipment = const {},
    this.globalOptions = const {},
  });

  final String definitionId;
  final int definitionRevision;
  final DateTime startDate;
  final Map<String, int> trainingMaxCentiUnits;
  final Map<String, String> selectedCyclesBySlot;
  final ForeverWebArchitectureMode architectureMode;
  final List<ForeverDraftNode> nodes;
  final Map<String, Object?> equipment;
  final Map<String, Object?> globalOptions;

  ForeverEditorDraft copyWith({
    String? definitionId,
    int? definitionRevision,
    DateTime? startDate,
    Map<String, int>? trainingMaxCentiUnits,
    Map<String, String>? selectedCyclesBySlot,
    ForeverWebArchitectureMode? architectureMode,
    List<ForeverDraftNode>? nodes,
    Map<String, Object?>? equipment,
    Map<String, Object?>? globalOptions,
  }) => ForeverEditorDraft(
    definitionId: definitionId ?? this.definitionId,
    definitionRevision: definitionRevision ?? this.definitionRevision,
    startDate: startDate ?? this.startDate,
    trainingMaxCentiUnits: trainingMaxCentiUnits ?? this.trainingMaxCentiUnits,
    selectedCyclesBySlot: selectedCyclesBySlot ?? this.selectedCyclesBySlot,
    architectureMode: architectureMode ?? this.architectureMode,
    nodes: nodes ?? this.nodes,
    equipment: equipment ?? this.equipment,
    globalOptions: globalOptions ?? this.globalOptions,
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

/// Optional Web capability. Implementations expose the project's supported
/// export format without making the presentation serialize domain snapshots.
abstract interface class ForeverWebExportApplication {
  Future<String> exportDraft(ForeverEditorDraft draft);
  Future<String> exportMacrocycle(String macrocycleId);
}
