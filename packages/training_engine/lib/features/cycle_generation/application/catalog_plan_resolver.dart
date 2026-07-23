import '../domain/catalog_cycle_primitives.dart';
import '../domain/cycle_contract.dart';
import '../domain/cycle_execution_options.dart';
import '../domain/cycle_schedule_mode.dart';
import '../domain/load_rounding_policy.dart';

final class PlanSession {
  const PlanSession({
    required this.id,
    required this.movementIds,
    this.sourceRole = 'mainLift',
  });

  final MovementId id;
  final List<MovementId> movementIds;
  final String sourceRole;
}

final class PlanComponent {
  const PlanComponent({
    required this.reference,
    required this.block,
    this.sessionIds = const [],
    this.movementIds = const [],
    this.mainWorkSemantics,
  });

  final ComponentReference reference;
  final BlockDefinition block;
  final List<MovementId> sessionIds;
  final List<MovementId> movementIds;
  final MainWorkSemantics? mainWorkSemantics;
}

final class CatalogPlan {
  const CatalogPlan({
    required this.catalogVersion,
    required this.definitionId,
    required this.variantId,
    required this.sourceReference,
    required this.sessions,
    required this.components,
    this.weekPlans = const [],
    this.phases = const [],
    this.optionRecipes = const ResolvedCycleOptionRecipes(),
    this.scheduleReference,
    this.scheduleMode,
    this.assistancePlanIds = const [],
    this.conditioningDefinitionIds = const [],
    this.loadRoundingPolicy = LoadRoundingPolicy.nearest,
  });

  final int catalogVersion;
  final String definitionId;
  final String variantId;
  final String sourceReference;
  final List<PlanSession> sessions;
  final List<PlanComponent> components;
  final List<CatalogWeekPlan> weekPlans;
  final List<CatalogPhase> phases;
  final ResolvedCycleOptionRecipes optionRecipes;
  final ComponentReference? scheduleReference;
  final CycleScheduleMode? scheduleMode;
  final List<ComponentReference> assistancePlanIds;
  final List<ComponentReference> conditioningDefinitionIds;
  final LoadRoundingPolicy loadRoundingPolicy;
}

final class CatalogPlanResolver {
  const CatalogPlanResolver({this.phaseExpander = const PhaseExpander()});

  final PhaseExpander phaseExpander;

  ResolvedCycleDefinition resolve(CatalogPlan plan) {
    if (plan.weekPlans.isEmpty == plan.phases.isEmpty) {
      throw const FormatException(
        'A plan requires exactly one of weekPlans or phases.',
      );
    }
    if (plan.sessions.isEmpty) {
      throw const FormatException('A plan requires at least one session.');
    }
    final componentByKey = <String, PlanComponent>{};
    for (final component in plan.components) {
      final key = _key(component.reference);
      if (componentByKey.containsKey(key)) {
        throw FormatException('Duplicate component reference $key.');
      }
      componentByKey[key] = component;
    }
    final expanded = plan.phases.isEmpty
        ? [
            for (final week in plan.weekPlans)
              ExpandedWeekPlan(
                number: week.weekNumber,
                phaseId: 'cycle',
                phaseIteration: 1,
                sourceWeekNumber: week.weekNumber,
                components: week.components,
              ),
          ]
        : phaseExpander.expand(plan.phases);
    return ResolvedCycleDefinition(
      catalogVersion: plan.catalogVersion,
      templateId: plan.definitionId,
      variantId: plan.variantId,
      sessionMovementIds: [for (final session in plan.sessions) session.id],
      weeks: [
        for (final week in expanded)
          WeekDefinition(
            number: week.number,
            origin: CatalogWeekOrigin(
              phaseId: week.phaseId,
              phaseIteration: week.phaseIteration,
              sourceWeekNumber: week.sourceWeekNumber,
            ),
            sessions: [
              for (final session in plan.sessions)
                SessionDefinition(
                  id: session.id,
                  role: session.id.value,
                  sourceRole: session.sourceRole,
                  blocks: _blocksFor(session, week.components, componentByKey),
                ),
            ],
          ),
      ],
      sourceReference: plan.sourceReference,
      optionRecipes: plan.optionRecipes,
      scheduleReference: plan.scheduleReference,
      scheduleMode: plan.scheduleMode,
      assistancePlanIds: List.unmodifiable(plan.assistancePlanIds),
      conditioningDefinitionIds: List.unmodifiable(
        plan.conditioningDefinitionIds,
      ),
      loadRoundingPolicy: plan.loadRoundingPolicy,
    );
  }

  List<BlockDefinition> _blocksFor(
    PlanSession session,
    List<ComponentReference> references,
    Map<String, PlanComponent> components,
  ) {
    final result = <BlockDefinition>[];
    for (final reference in references) {
      final component = components[_key(reference)];
      if (component == null) {
        throw FormatException(
          'Unknown component reference ${_key(reference)}.',
        );
      }
      if (component.sessionIds.isNotEmpty &&
          !component.sessionIds.contains(session.id)) {
        continue;
      }
      final targets = component.movementIds.isEmpty
          ? component.block.movementId == null
                ? session.movementIds.isEmpty
                      ? <MovementId>[session.id]
                      : session.movementIds
                : <MovementId>[component.block.movementId!]
          : component.movementIds
                .where(session.movementIds.contains)
                .toList(growable: false);
      for (final movement in targets) {
        result.add(
          BlockDefinition(
            id: component.block.id,
            role: component.block.role,
            sets: component.block.sets,
            movementId: movement,
            mainWorkSemantics:
                component.mainWorkSemantics ??
                component.block.mainWorkSemantics,
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }

  String _key(ComponentReference reference) =>
      '${reference.id}@${reference.revision}';
}
