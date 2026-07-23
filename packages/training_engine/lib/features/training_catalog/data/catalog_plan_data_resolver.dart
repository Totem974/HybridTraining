import '../../cycle_generation/application/catalog_plan_resolver.dart';
import '../../cycle_generation/domain/catalog_cycle_primitives.dart';
import '../../cycle_generation/domain/cycle_contract.dart';
import '../../cycle_generation/domain/cycle_execution_options.dart';
import 'catalog_source_document_codec.dart';

final class CatalogPlanDataResolver {
  const CatalogPlanDataResolver();

  CatalogPlan resolve({
    required int catalogVersion,
    required SourceTemplate template,
    required SourceVariant variant,
    required ComponentReference scheduleReference,
    required List<SourceSchedule> schedules,
    required List<SourceComponent> components,
    required String sourceReference,
    Map<String, Object?> optionValues = const {},
    Map<String, Object?> optionDefaults = const {},
    List<SourceCycleOptionRecipe> optionRecipes = const [],
  }) {
    if (!variant.scheduleIds.any((item) => _same(item, scheduleReference))) {
      throw const FormatException(
        'Selected schedule is not allowed by variant.',
      );
    }
    final schedule = schedules
        .where((item) => _same(item.reference, scheduleReference))
        .toList();
    if (schedule.length != 1) {
      throw const FormatException(
        'Schedule reference must resolve exactly once.',
      );
    }
    final scheduledMovementIds = schedule.single.sessions
        .expand((session) => session.movementIds)
        .toSet()
        .toList(growable: false);
    final sessionTargets = _targetIds(variant.compatibilities, 'sessionIds');
    final movementTargets = _targetIds(variant.compatibilities, 'movementIds');
    final selectedWeekPlans = _applyComponentSelections(
      variant.weekPlans,
      variant.componentSelections,
      optionValues,
      optionDefaults,
    );
    final selectedPhases = [
      for (final phase in variant.phases)
        CatalogPhase(
          id: phase.id,
          repeatCount: phase.repeatCount,
          weekPlans: _applyComponentSelections(
            phase.weekPlans,
            variant.componentSelections,
            optionValues,
            optionDefaults,
          ),
        ),
    ];
    final planSessions = [
      for (final session in schedule.single.sessions)
        PlanSession(
          id: MovementId(session.id),
          movementIds: [for (final id in session.movementIds) MovementId(id)],
          sourceRole: session.role,
        ),
    ];
    final planComponents = [
      for (final component in components)
        PlanComponent(
          reference: component.reference,
          block: component.block,
          mainWorkSemantics: component.mainWorkSemantics,
          sessionIds: [
            for (final id in [
              ..._targetIds(component.compatibilities, 'sessionIds'),
              ...sessionTargets,
            ])
              MovementId(id),
          ],
          movementIds: [
            for (final id in _movementTargetIds(
              component,
              scheduledMovementIds,
              movementTargets,
            ))
              MovementId(id),
          ],
        ),
    ];
    return CatalogPlan(
      catalogVersion: catalogVersion,
      definitionId: template.id,
      variantId: variant.id,
      sourceReference: sourceReference,
      sessions: planSessions,
      components: planComponents,
      weekPlans: selectedWeekPlans,
      phases: selectedPhases,
      scheduleReference: scheduleReference,
      scheduleMode: schedule.single.type,
      assistancePlanIds: List.unmodifiable(variant.assistancePlanIds),
      conditioningDefinitionIds: List.unmodifiable(
        variant.conditioningDefinitionIds,
      ),
      loadRoundingPolicy: variant.loadRoundingPolicy,
      optionRecipes: _resolveOptionRecipes(
        variant,
        optionRecipes,
        planSessions,
        planComponents,
        selectedWeekPlans,
        selectedPhases,
      ),
    );
  }

  ResolvedCycleOptionRecipes _resolveOptionRecipes(
    SourceVariant variant,
    List<SourceCycleOptionRecipe> recipes,
    List<PlanSession> sessions,
    List<PlanComponent> components,
    List<CatalogWeekPlan> weekPlans,
    List<CatalogPhase> phases,
  ) {
    final reference = variant.optionRecipeId;
    if (reference == null) return const ResolvedCycleOptionRecipes();
    final matches = recipes
        .where((recipe) => _same(recipe.reference, reference))
        .toList(growable: false);
    if (matches.length != 1) {
      throw const FormatException(
        'Option recipe reference must resolve exactly once.',
      );
    }
    final recipe = matches.single;
    final expanded = phases.isEmpty
        ? [
            for (final week in weekPlans)
              ExpandedWeekPlan(
                number: week.weekNumber,
                phaseId: 'cycle',
                phaseIteration: 1,
                sourceWeekNumber: week.weekNumber,
                components: week.components,
              ),
          ]
        : const PhaseExpander().expand(phases);
    return ResolvedCycleOptionRecipes(
      warmUp: {
        for (final entry in recipe.warmUp.entries)
          entry.key: _resolveBlockRecipe(
            entry.value,
            expanded,
            sessions,
            components,
            deloadOnly: false,
          ),
      },
      joker: recipe.joker,
      deload: {
        for (final entry in recipe.deload.entries)
          entry.key: _resolveBlockRecipe(
            entry.value,
            expanded,
            sessions,
            components,
            deloadOnly: true,
          ),
      },
    );
  }

  ResolvedBlockRecipe _resolveBlockRecipe(
    SourceBlockRecipe recipe,
    List<ExpandedWeekPlan> weeks,
    List<PlanSession> sessions,
    List<PlanComponent> components, {
    required bool deloadOnly,
  }) => ResolvedBlockRecipe(
    unitIndependent: recipe.componentIds.isEmpty
        ? const []
        : _expandRecipeReferences(
            recipe.componentIds,
            weeks,
            sessions,
            components,
            deloadOnly: deloadOnly,
          ),
    byUnit: {
      for (final entry in recipe.byUnit.entries)
        entry.key: _expandRecipeReferences(
          entry.value,
          weeks,
          sessions,
          components,
          deloadOnly: deloadOnly,
        ),
    },
  );

  List<ResolvedBlockOverlay> _expandRecipeReferences(
    List<ComponentReference> references,
    List<ExpandedWeekPlan> weeks,
    List<PlanSession> sessions,
    List<PlanComponent> components, {
    required bool deloadOnly,
  }) {
    final byReference = <String, PlanComponent>{
      for (final component in components) _key(component.reference): component,
    };
    final recipeComponents = [
      for (final reference in references)
        byReference[_key(reference)] ??
            (throw FormatException(
              'Unknown option recipe component ${_key(reference)}.',
            )),
    ];
    return [
      for (final week in weeks)
        for (final session in sessions)
          if (_isApplicableRecipeSession(
            week,
            session,
            byReference,
            deloadOnly: deloadOnly,
          ))
            ResolvedBlockOverlay(
              weekNumber: week.number,
              sessionId: session.id,
              blocks: [
                for (final component in recipeComponents)
                  if (_targetsSession(component, session)) component.block,
              ],
            ),
    ];
  }

  bool _isApplicableRecipeSession(
    ExpandedWeekPlan week,
    PlanSession session,
    Map<String, PlanComponent> components, {
    required bool deloadOnly,
  }) {
    final base = [
      for (final reference in week.components)
        if (components[_key(reference)] case final component?)
          if (_targetsSession(component, session)) component,
    ];
    if (deloadOnly) return base.any((item) => item.block.role == 'deload');
    return base.any((item) => item.block.role != 'warm_up');
  }

  bool _targetsSession(PlanComponent component, PlanSession session) =>
      (component.sessionIds.isEmpty ||
          component.sessionIds.contains(session.id)) &&
      (component.movementIds.isEmpty ||
          component.movementIds.any(session.movementIds.contains));

  String _key(ComponentReference reference) =>
      '${reference.id}@${reference.revision}';

  List<CatalogWeekPlan> _applyComponentSelections(
    List<CatalogWeekPlan> plans,
    List<SourceComponentSelection> selections,
    Map<String, Object?> values,
    Map<String, Object?> defaults,
  ) {
    if (selections.isEmpty) return plans;
    final replacements = <ComponentReference, ComponentReference>{};
    for (final selection in selections) {
      final value = values.containsKey(selection.parameterId)
          ? values[selection.parameterId]
          : defaults[selection.parameterId];
      if (value == null) {
        throw FormatException(
          'No value or default for component selection ${selection.parameterId}.',
        );
      }
      final matches = selection.choices
          .where((choice) => choice.value == value)
          .toList(growable: false);
      if (matches.length != 1) {
        throw FormatException(
          'Unknown or ambiguous value for component selection ${selection.parameterId}.',
        );
      }
      if (replacements.keys.any(
        (key) => _same(key, selection.targetComponentId),
      )) {
        throw FormatException(
          'Component ${selection.targetComponentId.id} is selected more than once.',
        );
      }
      replacements[selection.targetComponentId] = matches.single.componentId;
    }
    return [
      for (final plan in plans)
        CatalogWeekPlan(
          weekNumber: plan.weekNumber,
          components: [
            for (final reference in plan.components)
              _replacementFor(reference, replacements) ?? reference,
          ],
        ),
    ];
  }

  ComponentReference? _replacementFor(
    ComponentReference reference,
    Map<ComponentReference, ComponentReference> replacements,
  ) {
    for (final entry in replacements.entries) {
      if (_same(entry.key, reference)) return entry.value;
    }
    return null;
  }

  List<String> _targetIds(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return const [];
    if (value is! List<Object?> || value.any((item) => item is! String)) {
      throw FormatException('$key must contain strings.');
    }
    return value.cast<String>();
  }

  List<String> _movementTargetIds(
    SourceComponent component,
    List<String> scheduledMovementIds,
    List<String> variantMovementTargets,
  ) {
    final explicit = _targetIds(component.compatibilities, 'movementIds');
    final componentTargets = explicit.isNotEmpty
        ? explicit
        : component.constraints['movementRelation'] == 'sameAsMain'
        ? scheduledMovementIds
        : const <String>[];
    return {
      ...componentTargets,
      ...variantMovementTargets,
    }.toList(growable: false);
  }

  bool _same(ComponentReference left, ComponentReference right) =>
      left.id == right.id && left.revision == right.revision;
}
