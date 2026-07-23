import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/features/cycle_generation/application/assistance_plan_resolver.dart';
import 'package:training_engine/features/cycle_generation/domain/assistance_compiler.dart';
import 'package:training_engine/features/cycle_generation/domain/assistance_contract.dart';
import 'package:training_engine/features/cycle_generation/domain/cycle_contract.dart';
import 'package:training_engine/features/cycle_generation/domain/cycle_v2_primitives.dart';

void main() {
  group('rounded-average edge-remainder distribution', () {
    const distributor = RoundedAverageEdgeRemainderDistributor();

    for (final scenario in const [
      (total: 77, sets: 5, expected: [17, 15, 15, 15, 15]),
      (total: 78, sets: 5, expected: [16, 16, 16, 16, 14]),
      (total: 75, sets: 10, expected: [8, 8, 8, 8, 8, 8, 8, 8, 8, 3]),
      (total: 75, sets: 1, expected: [75]),
    ]) {
      test('${scenario.total}/${scenario.sets}', () {
        expect(
          distributor.distribute(
            total: scenario.total,
            setCount: scenario.sets,
          ),
          scenario.expected,
        );
      });
    }
  });

  test('strict resolver preserves slot and exercise order', () {
    final plan = const AssistancePlanResolver()
        .decodeDocument(_bodyweightDocument)
        .single;

    expect(plan.id, 'original_bodyweight');
    expect(plan.revision, 2);
    expect(plan.slots.map((slot) => slot.sessionRole), [
      'overhead_press',
      'bench_press',
      'squat',
      'deadlift',
    ]);
    expect(
      plan.slots.map(
        (slot) => slot.prescriptions
            .map((prescription) => prescription.exerciseId)
            .toList(),
      ),
      [
        ['pull_up', 'dip'],
        ['pull_up', 'push_up'],
        ['single_leg_squat', 'sit_up'],
        ['glute_ham_raise', 'hanging_leg_raise'],
      ],
    );
  });

  test('resolver decodes every published classic assistance plan', () {
    final plans = const AssistancePlanResolver().decodeDocument(
      File(
        '../../catalog_src/classic/library/assistance_plans.v1.json',
      ).readAsStringSync(),
    );

    expect(plans.map((plan) => plan.id), [
      'original_triumvirate_classic',
      'original_periodization_bible',
      'original_bodyweight',
    ]);
    final bodyweight = plans.last;
    expect(
      bodyweight.slots
          .expand((slot) => slot.prescriptions)
          .map((prescription) => prescription.exerciseId),
      [
        'pull_up',
        'dip',
        'glute_ham_raise',
        'hanging_leg_raise',
        'pull_up',
        'push_up',
        'single_leg_squat',
        'sit_up',
      ],
    );
  });

  test('compiler emits exercise blocks in source order with exact reps', () {
    final plan = const AssistancePlanResolver()
        .decodeDocument(_bodyweightDocument)
        .single;
    final blocks = const AssistanceCompiler().compileSession(
      plans: [plan],
      sessionRole: 'overhead_press',
      optionValues: const CycleOptionValues(
        global: {'total_repetitions': 80, 'set_count': 5},
      ),
    );

    expect(blocks.map((block) => block.movementId.value), ['pull_up', 'dip']);
    for (final block in blocks) {
      expect(block.role, 'assistance');
      expect(block.sets.map((set) => set.repetitions['count']), [
        16,
        16,
        16,
        16,
        16,
      ]);
      expect(block.sets.map((set) => set.index), [0, 1, 2, 3, 4]);
      expect(
        block.sets,
        everyElement(predicate<GeneratedSet>((set) => set.plannedLoad == null)),
      );
    }
  });

  test('assistance has no deload suppression of its own', () {
    final plan = const AssistancePlanResolver()
        .decodeDocument(_bodyweightDocument)
        .single;
    const compiler = AssistanceCompiler();

    final normal = compiler.compileSession(
      plans: [plan],
      sessionRole: 'deadlift',
    );
    // The scheduled compiler decides whether a deload week exists. Once its
    // session exists, assistance is compiled identically on that week.
    final deload = compiler.compileSession(
      plans: [plan],
      sessionRole: 'deadlift',
    );

    expect(
      deload.map((block) => block.toJson()),
      normal.map((block) => block.toJson()),
    );
    expect(deload.map((block) => block.movementId.value), [
      'glute_ham_raise',
      'hanging_leg_raise',
    ]);
  });

  test('fixed prescriptions compile five identical sets', () {
    const plan = ResolvedAssistancePlan(
      id: 'triumvirate',
      revision: 2,
      slots: [
        AssistanceSessionSlot(
          id: 'press',
          sessionRole: 'overhead_press',
          prescriptions: [
            AssistanceExercisePrescription(
              exerciseId: 'dip',
              volume: FixedAssistanceVolume(setCount: 5, repetitions: 15),
              load: AssistanceLoadKind.unconfigured,
            ),
            AssistanceExercisePrescription(
              exerciseId: 'pull_up',
              volume: FixedAssistanceVolume(setCount: 5, repetitions: 10),
              load: AssistanceLoadKind.unconfigured,
            ),
          ],
        ),
      ],
    );

    final blocks = const AssistanceCompiler().compileSession(
      plans: [plan],
      sessionRole: 'overhead_press',
    );
    expect(blocks.map((block) => block.movementId.value), ['dip', 'pull_up']);
    expect(blocks.first.sets.map((set) => set.repetitions['count']), [
      15,
      15,
      15,
      15,
      15,
    ]);
    expect(blocks.last.sets.map((set) => set.repetitions['count']), [
      10,
      10,
      10,
      10,
      10,
    ]);
  });

  test('resolver refuses implicit recommended exercises', () {
    expect(
      () => const AssistancePlanResolver().decodeDocument(
        _bodyweightDocument.replaceFirst(
          '"prescriptions": [',
          '"recommendedExerciseIds":["pull_up"],"prescriptions": [',
        ),
      ),
      throwsFormatException,
    );
  });

  test('resolver rejects an unknown total distribution', () {
    expect(
      () => const AssistancePlanResolver().decodeDocument(
        _bodyweightDocument.replaceFirst(
          'rounded_average_edge_remainder',
          'mystery',
        ),
      ),
      throwsFormatException,
    );
  });
}

const _bodyweightDocument = r'''
{
  "schemaVersion": 1,
  "kind": "assistancePlans",
  "assistancePlans": [{
    "id": "original_bodyweight",
    "revision": 2,
    "labels": {"en": "Bodyweight", "fr": "Poids du corps"},
    "sourceRuleIds": ["or.assistance.bodyweight"],
    "slots": [
      {
        "id": "press_assistance",
        "sessionRole": "overhead_press",
        "minimumExercises": 2,
        "maximumExercises": 2,
        "allowedCategories": ["push", "pull"],
        "prescriptions": [
          {
            "exerciseId": "pull_up",
            "sets": {"type": "parameterized", "parameterId": "set_count", "default": 5, "minimum": 1, "maximum": 10, "step": 1},
            "repetitions": {"type": "distributed_total", "parameterId": "total_repetitions", "default": 75, "minimum": 75, "maximum": 150, "step": 5, "distribution": "rounded_average_edge_remainder"},
            "load": {"type": "bodyweight"}
          },
          {
            "exerciseId": "dip",
            "sets": {"type": "parameterized", "parameterId": "set_count", "default": 5, "minimum": 1, "maximum": 10, "step": 1},
            "repetitions": {"type": "distributed_total", "parameterId": "total_repetitions", "default": 75, "minimum": 75, "maximum": 150, "step": 5, "distribution": "rounded_average_edge_remainder"},
            "load": {"type": "bodyweight"}
          }
        ]
      },
      {
        "id": "bench_assistance",
        "sessionRole": "bench_press",
        "minimumExercises": 2,
        "maximumExercises": 2,
        "allowedCategories": ["push", "pull"],
        "prescriptions": [
          {
            "exerciseId": "pull_up",
            "sets": {"type": "parameterized", "parameterId": "set_count", "default": 5, "minimum": 1, "maximum": 10, "step": 1},
            "repetitions": {"type": "distributed_total", "parameterId": "total_repetitions", "default": 75, "minimum": 75, "maximum": 150, "step": 5, "distribution": "rounded_average_edge_remainder"},
            "load": {"type": "bodyweight"}
          },
          {
            "exerciseId": "push_up",
            "sets": {"type": "parameterized", "parameterId": "set_count", "default": 5, "minimum": 1, "maximum": 10, "step": 1},
            "repetitions": {"type": "distributed_total", "parameterId": "total_repetitions", "default": 75, "minimum": 75, "maximum": 150, "step": 5, "distribution": "rounded_average_edge_remainder"},
            "load": {"type": "bodyweight"}
          }
        ]
      },
      {
        "id": "squat_assistance",
        "sessionRole": "squat",
        "minimumExercises": 2,
        "maximumExercises": 2,
        "allowedCategories": ["singleLegCore"],
        "prescriptions": [
          {
            "exerciseId": "single_leg_squat",
            "sets": {"type": "parameterized", "parameterId": "set_count", "default": 5, "minimum": 1, "maximum": 10, "step": 1},
            "repetitions": {"type": "distributed_total", "parameterId": "total_repetitions", "default": 75, "minimum": 75, "maximum": 150, "step": 5, "distribution": "rounded_average_edge_remainder"},
            "load": {"type": "bodyweight"}
          },
          {
            "exerciseId": "sit_up",
            "sets": {"type": "parameterized", "parameterId": "set_count", "default": 5, "minimum": 1, "maximum": 10, "step": 1},
            "repetitions": {"type": "distributed_total", "parameterId": "total_repetitions", "default": 75, "minimum": 75, "maximum": 150, "step": 5, "distribution": "rounded_average_edge_remainder"},
            "load": {"type": "bodyweight"}
          }
        ]
      },
      {
        "id": "deadlift_assistance",
        "sessionRole": "deadlift",
        "minimumExercises": 2,
        "maximumExercises": 2,
        "allowedCategories": ["singleLegCore"],
        "prescriptions": [
          {
            "exerciseId": "glute_ham_raise",
            "sets": {"type": "parameterized", "parameterId": "set_count", "default": 5, "minimum": 1, "maximum": 10, "step": 1},
            "repetitions": {"type": "distributed_total", "parameterId": "total_repetitions", "default": 75, "minimum": 75, "maximum": 150, "step": 5, "distribution": "rounded_average_edge_remainder"},
            "load": {"type": "bodyweight"}
          },
          {
            "exerciseId": "hanging_leg_raise",
            "sets": {"type": "parameterized", "parameterId": "set_count", "default": 5, "minimum": 1, "maximum": 10, "step": 1},
            "repetitions": {"type": "distributed_total", "parameterId": "total_repetitions", "default": 75, "minimum": 75, "maximum": 150, "step": 5, "distribution": "rounded_average_edge_remainder"},
            "load": {"type": "bodyweight"}
          }
        ]
      }
    ],
    "constraints": ["distributeTotalDeterministicallyAcrossSets"],
    "compatibleExerciseCategories": ["push", "pull", "singleLegCore"]
  }]
}
''';
