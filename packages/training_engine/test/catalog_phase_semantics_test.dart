import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _componentReference = ComponentReference('main_work', 1);
const _scheduleReference = ComponentReference('schedule_rotating', 1);
const _assistanceReference = ComponentReference('assistance_bodyweight', 1);
const _conditioningReference = ComponentReference('conditioning_easy', 1);
const _sessionId = MovementId('day_a');
const _squat = MovementId('squat');

void main() {
  const resolver = CatalogPlanResolver();

  test('phase expansion survives resolution with schedule semantics', () {
    final resolved = resolver.resolve(
      const CatalogPlan(
        catalogVersion: 2,
        definitionId: 'synthetic',
        variantId: 'two_builds',
        sourceReference: 'test',
        scheduleReference: _scheduleReference,
        scheduleMode: CycleScheduleMode.rotating,
        assistancePlanIds: [_assistanceReference],
        conditioningDefinitionIds: [_conditioningReference],
        sessions: [
          PlanSession(
            id: _sessionId,
            movementIds: [_squat],
            sourceRole: 'multiLift',
          ),
        ],
        components: [
          PlanComponent(
            reference: _componentReference,
            mainWorkSemantics: MainWorkSemantics(
              waveRole: MainWorkWaveRole.five,
              lastSetPolicy: MainWorkLastSetPolicy.fixed,
              setRoles: [MainWorkSetRole.top],
            ),
            block: BlockDefinition(
              id: 'main',
              role: 'main',
              movementId: _squat,
              sets: [
                PrescribedSetDefinition(
                  repetitions: FixedRepetitions(5),
                  load: TrainingMaxPercentageLoad(Percentage(6500)),
                ),
              ],
            ),
          ),
        ],
        phases: [
          CatalogPhase(
            id: 'build',
            repeatCount: 2,
            weekPlans: [
              CatalogWeekPlan(weekNumber: 1, components: [_componentReference]),
            ],
          ),
        ],
      ),
    );

    expect(resolved.scheduleReference?.id, _scheduleReference.id);
    expect(resolved.scheduleMode, CycleScheduleMode.rotating);
    expect(resolved.assistancePlanIds, [_assistanceReference]);
    expect(resolved.conditioningDefinitionIds, [_conditioningReference]);
    expect(
      resolved.weeks
          .map(
            (week) => [
              week.origin?.phaseId,
              week.origin?.phaseIteration,
              week.origin?.sourceWeekNumber,
            ],
          )
          .toList(),
      [
        ['build', 1, 1],
        ['build', 2, 1],
      ],
    );
    expect(resolved.weeks.first.sessions.single.role, _sessionId.value);
    expect(resolved.weeks.first.sessions.single.sourceRole, 'multiLift');
    expect(
      resolved
          .weeks
          .first
          .sessions
          .single
          .blocks
          .single
          .mainWorkSemantics
          ?.waveRole,
      MainWorkWaveRole.five,
    );
  });

  test('direct week plans receive a stable cycle origin', () {
    final resolved = resolver.resolve(
      const CatalogPlan(
        catalogVersion: 2,
        definitionId: 'synthetic',
        variantId: 'direct',
        sourceReference: 'test',
        sessions: [
          PlanSession(id: _sessionId, movementIds: [_squat]),
        ],
        components: [
          PlanComponent(
            reference: _componentReference,
            block: BlockDefinition(
              id: 'main',
              role: 'main',
              movementId: _squat,
              sets: [
                PrescribedSetDefinition(
                  repetitions: FixedRepetitions(5),
                  load: TrainingMaxPercentageLoad(Percentage(6500)),
                ),
              ],
            ),
          ),
        ],
        weekPlans: [
          CatalogWeekPlan(weekNumber: 3, components: [_componentReference]),
        ],
      ),
    );

    final origin = resolved.weeks.single.origin;
    expect(origin?.phaseId, 'cycle');
    expect(origin?.phaseIteration, 1);
    expect(origin?.sourceWeekNumber, 3);
  });
}
