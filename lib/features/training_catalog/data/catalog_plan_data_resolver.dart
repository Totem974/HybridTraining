import '../../cycle_generation/application/catalog_plan_resolver.dart';
import '../../cycle_generation/domain/catalog_cycle_primitives.dart';
import '../../cycle_generation/domain/cycle_contract.dart';
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
    return CatalogPlan(
      catalogVersion: catalogVersion,
      definitionId: template.id,
      variantId: variant.id,
      sourceReference: sourceReference,
      sessions: [
        for (final session in schedule.single.sessions)
          PlanSession(
            id: MovementId(session.id),
            movementIds: [for (final id in session.movementIds) MovementId(id)],
          ),
      ],
      components: [
        for (final component in components)
          PlanComponent(
            reference: component.reference,
            block: component.block,
            sessionIds: [
              for (final id in [
                ..._targetIds(component.compatibilities, 'sessionIds'),
                ...sessionTargets,
              ])
                MovementId(id),
            ],
            movementIds: [
              for (final id in [
                ...component.constraints['movementRelation'] == 'sameAsMain'
                    ? scheduledMovementIds
                    : _targetIds(component.compatibilities, 'movementIds'),
                ...movementTargets,
              ])
                MovementId(id),
            ],
          ),
      ],
      weekPlans: variant.weekPlans,
      phases: variant.phases,
    );
  }

  List<String> _targetIds(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return const [];
    if (value is! List<Object?> || value.any((item) => item is! String)) {
      throw FormatException('$key must contain strings.');
    }
    return value.cast<String>();
  }

  bool _same(ComponentReference left, ComponentReference right) =>
      left.id == right.id && left.revision == right.revision;
}
