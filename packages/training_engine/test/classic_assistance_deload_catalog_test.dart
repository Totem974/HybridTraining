import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _scheduleReference = ComponentReference('schedule_four_day_fixed', 1);
const _scenarios = [
  (
    templateId: 'classic_triumvirate',
    assistancePlanId: 'original_triumvirate_classic',
    assistanceBlocksPerSession: 2,
  ),
  (
    templateId: 'classic_periodization_bible',
    assistancePlanId: 'original_periodization_bible',
    assistanceBlocksPerSession: 3,
  ),
  (
    templateId: 'classic_bodyweight',
    assistancePlanId: 'original_bodyweight',
    assistanceBlocksPerSession: 2,
  ),
];

void main() {
  late List<SourceTemplate> templates;
  late List<SourceComponent> components;
  late SourceSchedule sourceSchedule;
  late ResolvedCycleSchedule schedule;
  late List<SourceCycleOptionRecipe> optionRecipes;
  late List<ResolvedAssistancePlan> assistancePlans;

  setUpAll(() {
    const codec = CatalogSourceDocumentCodec();
    templates = codec.decodeTemplates(
      File('../../catalog_src/classic/templates.json').readAsStringSync(),
    );
    components = codec.decodeComponents(
      File(
        '../../catalog_src/shared/cycle_components_v1.json',
      ).readAsStringSync(),
    );
    sourceSchedule = codec
        .decodeSchedules(
          File(
            '../../catalog_src/schedules/cycle_schedules_v1.json',
          ).readAsStringSync(),
        )
        .singleWhere(
          (candidate) => candidate.reference.id == _scheduleReference.id,
        );
    schedule = const CatalogScheduleDataResolver().resolve(sourceSchedule);
    optionRecipes = codec.decodeCycleOptionRecipes(
      File(
        '../../catalog_src/shared/cycle_option_recipes_v1.json',
      ).readAsStringSync(),
    );
    assistancePlans = const AssistancePlanResolver().decodeDocument(
      File(
        '../../catalog_src/classic/library/assistance_plans.v1.json',
      ).readAsStringSync(),
    );
  });

  for (final scenario in _scenarios) {
    test(
      '${scenario.templateId} resolves a source deload and schedules its assistance',
      () {
        final template = templates.singleWhere(
          (candidate) => candidate.id == scenario.templateId,
        );
        final variant = template.variants.singleWhere(
          (candidate) => candidate.id == 'four_day',
        );
        final definition = const CatalogPlanResolver().resolve(
          const CatalogPlanDataResolver().resolve(
            catalogVersion: 2,
            template: template,
            variant: variant,
            scheduleReference: _scheduleReference,
            schedules: [sourceSchedule],
            components: components,
            sourceReference: 'classic-assistance-deload-catalog-test',
            optionRecipes: optionRecipes,
          ),
        );
        final assistance = assistancePlans.singleWhere(
          (candidate) => candidate.id == scenario.assistancePlanId,
        );

        expect(variant.weekPlans.map((week) => week.weekNumber), [1, 2, 3, 4]);
        expect(definition.weeks.map((week) => week.number), [1, 2, 3, 4]);
        expect(
          definition.weeks.last.sessions,
          everyElement(
            predicate<SessionDefinition>(
              (session) =>
                  session.blocks.length == 1 &&
                  session.blocks.single.id == 'deload' &&
                  session.blocks.single.role == 'deload',
            ),
          ),
        );
        expect(
          definition.assistancePlanIds.map(
            (reference) => (reference.id, reference.revision),
          ),
          [(scenario.assistancePlanId, 1)],
        );

        final withDeload = _compile(
          definition: definition,
          schedule: schedule,
          assistance: assistance,
          includeDeload: true,
        );
        expect(withDeload.weeks.map((week) => week.number), [1, 2, 3, 4]);
        final deloadWeek = withDeload.weeks.last;
        expect(deloadWeek.sessions, hasLength(4));
        expect(deloadWeek.sessions.map((session) => session.id), [
          '${scenario.templateId}-w4-s1',
          '${scenario.templateId}-w4-s2',
          '${scenario.templateId}-w4-s3',
          '${scenario.templateId}-w4-s4',
        ]);
        for (final session in deloadWeek.sessions) {
          expect(
            session.blocks.where((block) => block.role == 'deload'),
            hasLength(1),
          );
          expect(
            session.blocks.where((block) => block.role == 'main_work'),
            isEmpty,
          );
          expect(
            session.blocks.where((block) => block.role == 'assistance'),
            hasLength(scenario.assistanceBlocksPerSession),
          );
        }

        final withoutDeload = _compile(
          definition: definition,
          schedule: schedule,
          assistance: assistance,
          includeDeload: false,
        );
        expect(withoutDeload.weeks.map((week) => week.number), [1, 2, 3]);
        expect(
          withoutDeload.weeks
              .expand((week) => week.sessions)
              .map((session) => session.id),
          everyElement(isNot(contains('-w4-'))),
        );
        expect(
          withoutDeload.weeks
              .expand((week) => week.sessions)
              .expand((session) => session.blocks)
              .where((block) => block.role == 'deload'),
          isEmpty,
        );
      },
    );
  }
}

GeneratedCycle _compile({
  required ResolvedCycleDefinition definition,
  required ResolvedCycleSchedule schedule,
  required ResolvedAssistancePlan assistance,
  required bool includeDeload,
}) {
  final request = CycleRequest(
    cycleId: definition.templateId,
    startDate: DateTime(2026, 1, 5),
    trainingDays: const [1, 2, 4, 5],
    sessionOrder: const [
      MovementId('overhead_press'),
      MovementId('deadlift'),
      MovementId('bench_press'),
      MovementId('squat'),
    ],
    maxInputs: const {
      MovementId('overhead_press'): DirectTrainingMaxInput(
        Weight(10000, WeightUnit.kg),
      ),
      MovementId('deadlift'): DirectTrainingMaxInput(
        Weight(10000, WeightUnit.kg),
      ),
      MovementId('bench_press'): DirectTrainingMaxInput(
        Weight(10000, WeightUnit.kg),
      ),
      MovementId('squat'): DirectTrainingMaxInput(Weight(10000, WeightUnit.kg)),
    },
    globalTrainingMaxRatio: const Percentage(10000),
    unit: WeightUnit.kg,
    roundingIncrement: const Weight(100, WeightUnit.kg),
    barProfile: const BarProfile(
      weight: Weight(0, WeightUnit.kg),
      platesPerSide: [
        Weight(50, WeightUnit.kg),
        Weight(100, WeightUnit.kg),
        Weight(200, WeightUnit.kg),
        Weight(400, WeightUnit.kg),
        Weight(800, WeightUnit.kg),
        Weight(1600, WeightUnit.kg),
        Weight(3200, WeightUnit.kg),
      ],
    ),
    includeDeload: includeDeload,
    cycleOptions: CycleExecutionOptions(
      warmUp: const WarmUpExecutionOptions(
        enabled: true,
        type: WarmUpType.original,
      ),
      deload: includeDeload
          ? const DeloadExecutionOptions(
              enabled: true,
              type: DeloadType.type1,
              skipWarmUp: false,
            )
          : const DeloadExecutionOptions.disabled(),
    ),
  );
  const selection = CycleScheduleSelection(
    trainingDays: [1, 2, 4, 5],
    sessionOrder: [
      SessionId('overhead_press'),
      SessionId('deadlift'),
      SessionId('bench_press'),
      SessionId('squat'),
    ],
  );
  return const CycleCompilerImpl().compileScheduled(
    definition: definition,
    schedule: schedule,
    selection: selection,
    request: request,
    assistancePlans: [assistance],
  );
}
