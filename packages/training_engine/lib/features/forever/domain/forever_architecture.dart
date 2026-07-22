import '../../cycle_generation/domain/cycle_contract.dart';
import 'forever_contract.dart';

enum ForeverArchitectureMode { preset, userDefined }

enum ForeverArchitectureIssueCode {
  emptySequence,
  duplicateNodeId,
  unconfiguredCycle,
  orphanProtocol,
  incompatibleRole,
  incompatibleCycle,
  requiredNodeRemoval,
  lockedNodeMutation,
  unknownNode,
  invalidPosition,
}

final class ForeverArchitectureIssue {
  const ForeverArchitectureIssue(this.code, {this.nodeId});

  final ForeverArchitectureIssueCode code;
  final String? nodeId;
}

final class ForeverArchitectureException implements Exception {
  const ForeverArchitectureException(this.issue);

  final ForeverArchitectureIssue issue;

  @override
  String toString() => 'ForeverArchitectureException(${issue.code.name})';
}

/// Complete, catalogue-agnostic configuration of one Cycle node.
///
/// Option identifiers and values remain opaque to Forever: they are resolved
/// and validated by the Cycle catalogue/editor before compilation.
final class ForeverNodeConfiguration {
  const ForeverNodeConfiguration({
    required this.cycle,
    required this.trainingDays,
    required this.sessionOrder,
    this.parameters = const {},
    this.percentageParameters = const {},
    this.percentageParametersByMovement = const {},
    this.globalTrainingMaxRatio = const Percentage(10000),
    this.trainingMaxRatioByMovement = const {},
    this.warmUp,
    this.joker,
    this.deload,
    this.supplemental,
    this.assistance,
    this.conditioning,
    this.scheduleId,
    this.includeDeload = true,
  });

  final ForeverCycleReference cycle;
  final List<int> trainingDays;
  final List<MovementId> sessionOrder;
  final Map<String, Object?> parameters;
  final Map<String, Percentage> percentageParameters;
  final Map<MovementId, Map<String, Percentage>> percentageParametersByMovement;
  final Percentage globalTrainingMaxRatio;
  final Map<MovementId, Percentage> trainingMaxRatioByMovement;
  final Map<String, Object?>? warmUp;
  final Map<String, Object?>? joker;
  final Map<String, Object?>? deload;
  final Map<String, Object?>? supplemental;
  final Map<String, Object?>? assistance;
  final Map<String, Object?>? conditioning;
  final String? scheduleId;
  final bool includeDeload;

  ForeverSlotRequest toSlotRequest(String slotId) => ForeverSlotRequest(
    slotId: slotId,
    cycle: cycle,
    trainingDays: List.unmodifiable(trainingDays),
    sessionOrder: List.unmodifiable(sessionOrder),
    percentageParameters: Map.unmodifiable(percentageParameters),
    percentageParametersByMovement: Map.unmodifiable(
      percentageParametersByMovement,
    ),
    globalTrainingMaxRatio: globalTrainingMaxRatio,
    trainingMaxRatioByMovement: Map.unmodifiable(trainingMaxRatioByMovement),
    includeDeload: includeDeload,
  );
}

final class ForeverArchitectureNode {
  const ForeverArchitectureNode({
    required this.id,
    required this.role,
    required this.transition,
    this.configuration,
    this.allowedRoles = ForeverPhaseRole.values,
    this.allowedCycles = const [],
    this.required = false,
    this.locked = false,
  }) : assert(id != '');

  final String id;
  final ForeverPhaseRole role;
  final ForeverTransition transition;
  final ForeverNodeConfiguration? configuration;
  final List<ForeverPhaseRole> allowedRoles;
  final List<ForeverCycleReference> allowedCycles;
  final bool required;
  final bool locked;

  bool get isProtocol => switch (role) {
    ForeverPhaseRole.transition ||
    ForeverPhaseRole.deload ||
    ForeverPhaseRole.test => true,
    _ => false,
  };

  ForeverArchitectureNode copyWith({
    String? id,
    ForeverPhaseRole? role,
    ForeverNodeConfiguration? configuration,
    bool clearConfiguration = false,
  }) => ForeverArchitectureNode(
    id: id ?? this.id,
    role: role ?? this.role,
    transition: transition,
    configuration: clearConfiguration
        ? null
        : configuration ?? this.configuration,
    allowedRoles: allowedRoles,
    allowedCycles: allowedCycles,
    required: required,
    locked: locked,
  );
}

final class ForeverArchitecture {
  ForeverArchitecture({
    required this.id,
    required this.mode,
    required List<ForeverArchitectureNode> nodes,
    this.presetDefinitionId,
    this.presetRevision,
    this.sourceRuleIds = const [],
  }) : assert(id != ''),
       assert(nodes.isNotEmpty),
       assert(
         mode == ForeverArchitectureMode.userDefined ||
             (presetDefinitionId != null && presetRevision != null),
       ),
       nodes = List.unmodifiable(nodes);

  final String id;
  final ForeverArchitectureMode mode;
  final List<ForeverArchitectureNode> nodes;
  final ForeverDefinitionId? presetDefinitionId;
  final ForeverDefinitionRevision? presetRevision;
  final List<String> sourceRuleIds;

  List<ForeverArchitectureIssue> validate() {
    final issues = <ForeverArchitectureIssue>[];
    final ids = <String>{};
    final hasTrainingCycle = nodes.any((node) => !node.isProtocol);
    for (final node in nodes) {
      if (!ids.add(node.id)) {
        issues.add(
          ForeverArchitectureIssue(
            ForeverArchitectureIssueCode.duplicateNodeId,
            nodeId: node.id,
          ),
        );
      }
      final configuration = node.configuration;
      if (configuration == null ||
          configuration.trainingDays.isEmpty ||
          configuration.sessionOrder.isEmpty) {
        issues.add(
          ForeverArchitectureIssue(
            ForeverArchitectureIssueCode.unconfiguredCycle,
            nodeId: node.id,
          ),
        );
      }
      if (!node.allowedRoles.contains(node.role)) {
        issues.add(
          ForeverArchitectureIssue(
            ForeverArchitectureIssueCode.incompatibleRole,
            nodeId: node.id,
          ),
        );
      }
      if (configuration != null &&
          node.allowedCycles.isNotEmpty &&
          !node.allowedCycles.any(
            (allowed) => allowed.key == configuration.cycle.key,
          )) {
        issues.add(
          ForeverArchitectureIssue(
            ForeverArchitectureIssueCode.incompatibleCycle,
            nodeId: node.id,
          ),
        );
      }
      if (node.isProtocol && !hasTrainingCycle) {
        issues.add(
          ForeverArchitectureIssue(
            ForeverArchitectureIssueCode.orphanProtocol,
            nodeId: node.id,
          ),
        );
      }
    }
    return List.unmodifiable(issues);
  }

  ForeverArchitecture add(ForeverArchitectureNode node, {int? at}) {
    _ensureUserDefined();
    final next = [...nodes];
    final index = at ?? next.length;
    if (index < 0 || index > next.length) {
      throw const ForeverArchitectureException(
        ForeverArchitectureIssue(ForeverArchitectureIssueCode.invalidPosition),
      );
    }
    next.insert(index, node);
    return _withNodes(next);
  }

  ForeverArchitecture remove(String nodeId) {
    _ensureUserDefined();
    final index = _indexOf(nodeId);
    final node = nodes[index];
    if (node.required) {
      throw ForeverArchitectureException(
        ForeverArchitectureIssue(
          ForeverArchitectureIssueCode.requiredNodeRemoval,
          nodeId: nodeId,
        ),
      );
    }
    if (nodes.length == 1) {
      throw const ForeverArchitectureException(
        ForeverArchitectureIssue(ForeverArchitectureIssueCode.emptySequence),
      );
    }
    return _withNodes([...nodes]..removeAt(index));
  }

  ForeverArchitecture reorder(String nodeId, int newIndex) {
    _ensureUserDefined();
    final oldIndex = _indexOf(nodeId);
    if (newIndex < 0 || newIndex >= nodes.length) {
      throw const ForeverArchitectureException(
        ForeverArchitectureIssue(ForeverArchitectureIssueCode.invalidPosition),
      );
    }
    final next = [...nodes];
    final node = next.removeAt(oldIndex);
    next.insert(newIndex, node);
    return _withNodes(next);
  }

  ForeverArchitecture duplicate(String nodeId, {required String newId}) {
    _ensureUserDefined();
    final index = _indexOf(nodeId);
    return add(nodes[index].copyWith(id: newId), at: index + 1);
  }

  ForeverArchitecture copyConfiguration({
    required String fromNodeId,
    required String toNodeId,
  }) {
    _ensureUserDefined();
    final source = nodes[_indexOf(fromNodeId)];
    final targetIndex = _indexOf(toNodeId);
    final target = nodes[targetIndex];
    if (target.locked) {
      throw ForeverArchitectureException(
        ForeverArchitectureIssue(
          ForeverArchitectureIssueCode.lockedNodeMutation,
          nodeId: toNodeId,
        ),
      );
    }
    final next = [...nodes];
    next[targetIndex] = target.copyWith(configuration: source.configuration);
    return _withNodes(next);
  }

  ForeverArchitecture configure(
    String nodeId,
    ForeverNodeConfiguration configuration,
  ) {
    _ensureUserDefined();
    final index = _indexOf(nodeId);
    final node = nodes[index];
    if (node.locked) {
      throw ForeverArchitectureException(
        ForeverArchitectureIssue(
          ForeverArchitectureIssueCode.lockedNodeMutation,
          nodeId: nodeId,
        ),
      );
    }
    final next = [...nodes];
    next[index] = node.copyWith(configuration: configuration);
    return _withNodes(next);
  }

  ResolvedForeverDefinition toResolvedDefinition({
    String? labelEn,
    String? labelFr,
  }) {
    final issues = validate();
    if (issues.isNotEmpty) throw ForeverArchitectureException(issues.first);
    final definitionId = mode == ForeverArchitectureMode.preset
        ? presetDefinitionId!
        : ForeverDefinitionId('userDefined:$id');
    final revision = presetRevision ?? const ForeverDefinitionRevision(1);
    final slots = nodes
        .map(
          (node) => ForeverCycleSlot(
            id: node.id,
            role: node.role,
            repeatCount: 1,
            defaultCycle: node.configuration!.cycle,
            allowedCycles: node.allowedCycles.isEmpty
                ? [node.configuration!.cycle]
                : node.allowedCycles,
            transition: node.transition,
            optional: !node.required,
          ),
        )
        .toList(growable: false);
    return ResolvedForeverDefinition(
      id: definitionId,
      revision: revision,
      labelEn: labelEn ?? 'Custom macrocycle',
      labelFr: labelFr ?? 'Macrocycle personnalisé',
      sourceRuleIds: mode == ForeverArchitectureMode.userDefined
          ? const ['userDefined']
          : sourceRuleIds,
      phases: [ForeverPhase(id: 'architecture', slots: slots)],
      editorSchema: ForeverEditorSchema(
        definitionId: definitionId,
        revision: revision,
        configurableSlotIds: nodes
            .where((node) => !node.locked)
            .map((node) => node.id)
            .toList(growable: false),
      ),
    );
  }

  ForeverRequest toRequest({
    required String macrocycleId,
    required DateTime startDate,
    required Map<MovementId, Weight> initialTrainingMaxes,
    required WeightUnit unit,
    required Weight roundingIncrement,
    required BarProfile barProfile,
  }) {
    final definition = toResolvedDefinition();
    return ForeverRequest(
      macrocycleId: macrocycleId,
      definitionId: definition.id,
      definitionRevision: definition.revision,
      startDate: startDate,
      initialTrainingMaxes: Map.unmodifiable(initialTrainingMaxes),
      slotRequests: {
        for (final node in nodes)
          node.id: node.configuration!.toSlotRequest(node.id),
      },
      unit: unit,
      roundingIncrement: roundingIncrement,
      barProfile: barProfile,
    );
  }

  void _ensureUserDefined() {
    if (mode != ForeverArchitectureMode.userDefined) {
      throw const ForeverArchitectureException(
        ForeverArchitectureIssue(
          ForeverArchitectureIssueCode.lockedNodeMutation,
        ),
      );
    }
  }

  int _indexOf(String nodeId) {
    final index = nodes.indexWhere((node) => node.id == nodeId);
    if (index < 0) {
      throw ForeverArchitectureException(
        ForeverArchitectureIssue(
          ForeverArchitectureIssueCode.unknownNode,
          nodeId: nodeId,
        ),
      );
    }
    return index;
  }

  ForeverArchitecture _withNodes(List<ForeverArchitectureNode> next) =>
      ForeverArchitecture(
        id: id,
        mode: mode,
        nodes: next,
        presetDefinitionId: presetDefinitionId,
        presetRevision: presetRevision,
        sourceRuleIds: sourceRuleIds,
      );
}

