import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/cycle_generation/application/catalog_plan_resolver.dart';
import 'package:hybrid_training/features/cycle_generation/domain/catalog_cycle_primitives.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_compiler_impl.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/cycle_generation/domain/cycle_generation_error.dart';

void main() {
  const squat = MovementId('squat');
  const session = MovementId('full_body_a');
  const mainReference = ComponentReference('main', 1);
  const supplementalReference = ComponentReference('supplemental', 1);

  const main = BlockDefinition(
    id: 'main',
    role: 'main_work',
    sets: [
      PrescribedSetDefinition(
        repetitions: FixedRepetitions(5),
        load: TrainingMaxPercentageLoad(Percentage(6500)),
      ),
      PrescribedSetDefinition(
        repetitions: FixedRepetitions(5),
        load: TrainingMaxPercentageLoad(Percentage(7500)),
      ),
      PrescribedSetDefinition(
        repetitions: FixedRepetitions(5),
        load: TrainingMaxPercentageLoad(Percentage(8500)),
      ),
    ],
  );
  const supplemental = BlockDefinition(
    id: 'supplemental',
    role: 'supplemental',
    sets: [
      PrescribedSetDefinition(
        repetitions: FixedRepetitions(5),
        load: RelativeSetLoad(position: RelativeSetPosition.first),
        execution: SetExecution(
          kind: SetExecutionKind.restPause,
          restSeconds: 20,
          clusterRepetitions: 5,
        ),
        runtimeGates: [
          RuntimeGate(kind: RuntimeGateKind.jokerEligible, required: true),
          RuntimeGate(
            kind: RuntimeGateKind.trainingMaxCheckpoint,
            required: false,
          ),
        ],
      ),
    ],
  );

  CatalogPlan plan({List<CatalogPhase> phases = const []}) => CatalogPlan(
    catalogVersion: 2,
    definitionId: 'fixture',
    variantId: 'finite',
    sourceReference: 'fixture',
    sessions: const [
      PlanSession(id: session, movementIds: [squat]),
    ],
    components: const [
      PlanComponent(
        reference: mainReference,
        block: main,
        movementIds: [squat],
      ),
      PlanComponent(
        reference: supplementalReference,
        block: supplemental,
        movementIds: [squat],
      ),
    ],
    weekPlans: phases.isEmpty
        ? const [
            CatalogWeekPlan(
              weekNumber: 1,
              components: [mainReference, supplementalReference],
            ),
          ]
        : const [],
    phases: phases,
  );

  CycleRequest request() => CycleRequest(
    cycleId: 'cycle',
    startDate: DateTime(2026, 7, 21),
    trainingDays: const [1],
    sessionOrder: const [session],
    maxInputs: const {
      squat: DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
    },
    globalTrainingMaxRatio: const Percentage(8500),
    unit: WeightUnit.kg,
    roundingIncrement: const Weight(250, WeightUnit.kg),
    barProfile: const BarProfile(
      weight: Weight(2000, WeightUnit.kg),
      platesPerSide: [
        Weight(2000, WeightUnit.kg),
        Weight(1000, WeightUnit.kg),
        Weight(500, WeightUnit.kg),
        Weight(250, WeightUnit.kg),
        Weight(125, WeightUnit.kg),
      ],
    ),
  );

  test('resolves movement targets and compiles relative first-set load', () {
    final definition = const CatalogPlanResolver().resolve(plan());
    final generated = const CycleCompilerImpl().compile(definition, request());
    final set = generated.weeks.single.sessions.single.blocks.last.sets.single;
    expect(set.percentageBasisPoints, 6500);
    expect(set.plannedLoad!.centiUnits, 6500);
    expect(set.execution.kind, SetExecutionKind.restPause);
    expect(set.runtimeDecisions.map((decision) => decision.status), [
      RuntimeDecisionStatus.pending,
      RuntimeDecisionStatus.notRequired,
    ]);
    final json = set.toJson();
    expect(json['execution'], isA<Map<String, Object?>>());
    expect(json['runtimeDecisions'], hasLength(2));
  });

  test('expands finite phases before resolving component targets', () {
    final definition = const CatalogPlanResolver().resolve(
      plan(
        phases: const [
          CatalogPhase(
            id: 'phase',
            repeatCount: 2,
            weekPlans: [
              CatalogWeekPlan(
                weekNumber: 1,
                components: [mainReference, supplementalReference],
              ),
            ],
          ),
        ],
      ),
    );
    expect(definition.weeks.map((week) => week.number), [1, 2]);
    expect(
      definition.weeks.every((week) => week.sessions.single.blocks.length == 2),
      isTrue,
    );
  });

  test('reports a typed error when a relative target is missing', () {
    final definition = ResolvedCycleDefinition(
      catalogVersion: 1,
      templateId: 'fixture',
      variantId: 'missing',
      sessionMovementIds: const [session],
      sourceReference: 'fixture',
      weeks: const [
        WeekDefinition(
          number: 1,
          sessions: [
            SessionDefinition(
              id: session,
              role: 'full_body',
              blocks: [
                BlockDefinition(
                  id: 'supplemental',
                  role: 'supplemental',
                  movementId: squat,
                  sets: [
                    PrescribedSetDefinition(
                      repetitions: FixedRepetitions(5),
                      load: RelativeSetLoad(
                        position: RelativeSetPosition.first,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    expect(
      () => const CycleCompilerImpl().compile(definition, request()),
      throwsA(
        isA<CycleGenerationException>().having(
          (error) => error.code,
          'code',
          CycleGenerationErrorCode.missingRelativeLoadTarget,
        ),
      ),
    );
  });

  test('reports a typed error when a relative target is ambiguous', () {
    final definition = const CatalogPlanResolver().resolve(plan());
    final week = definition.weeks.single;
    final existing = week.sessions.single.blocks;
    final ambiguous = ResolvedCycleDefinition(
      catalogVersion: definition.catalogVersion,
      templateId: definition.templateId,
      variantId: definition.variantId,
      sessionMovementIds: definition.sessionMovementIds,
      sourceReference: definition.sourceReference,
      weeks: [
        WeekDefinition(
          number: 1,
          sessions: [
            SessionDefinition(
              id: session,
              role: 'full_body',
              blocks: [existing.first, existing.first, existing.last],
            ),
          ],
        ),
      ],
    );
    expect(
      () => const CycleCompilerImpl().compile(ambiguous, request()),
      throwsA(
        isA<CycleGenerationException>().having(
          (error) => error.code,
          'code',
          CycleGenerationErrorCode.ambiguousRelativeLoadTarget,
        ),
      ),
    );
  });
}
