import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final plans = _records(
    'catalog_src/classic/library/assistance_plans.v1.json',
    'assistancePlans',
  );
  final exerciseIds = _records(
    'catalog_src/exercises/exercises.v1.json',
    'exercises',
  ).map((exercise) => exercise['id']! as String).toSet();

  test('classic assistance mappings preserve the observed source program', () {
    expect(
      _fixedPrescriptionMap(_plan(plans, 'original_triumvirate_classic')),
      {
        'overhead_press': [('dip', 15), ('pull_up', 10)],
        'deadlift': [('good_morning', 12), ('hanging_leg_raise', 15)],
        'bench_press': [('dumbbell_bench_press', 15), ('dumbbell_row', 10)],
        'squat': [('leg_press', 15), ('hamstring_curl', 10)],
      },
    );
    expect(
      _fixedPrescriptionMap(_plan(plans, 'original_periodization_bible')),
      {
        'overhead_press': [
          ('dip', 15),
          ('pull_up', 10),
          ('triceps_pushdown', 15),
        ],
        'deadlift': [
          ('hamstring_curl', 10),
          ('leg_press', 15),
          ('hanging_leg_raise', 15),
        ],
        'bench_press': [
          ('dumbbell_bench_press', 15),
          ('dumbbell_row', 10),
          ('triceps_extension', 15),
        ],
        'squat': [
          ('good_morning', 12),
          ('leg_press', 15),
          ('hanging_leg_raise', 15),
        ],
      },
    );
  });

  test('bodyweight assigns two exercises and a total to each main lift', () {
    final bodyweight = _plan(plans, 'original_bodyweight');

    expect(_recommendedExerciseMap(bodyweight), {
      'overhead_press': ['pull_up', 'dip'],
      'deadlift': ['glute_ham_raise', 'hanging_leg_raise'],
      'bench_press': ['pull_up', 'push_up'],
      'squat': ['single_leg_squat', 'sit_up'],
    });
    expect(
      bodyweight['constraints'],
      containsAll([
        'totalRepetitionsPerExercise',
        'distributeTotalDeterministicallyAcrossSets',
      ]),
    );
    expect(bodyweight['constraints'], isNot(contains('omitDuringDeload')));
    expect(bodyweight['prescription'], {
      'sets': {'minimum': 1, 'maximum': 10, 'step': 1},
      'totalRepetitions': {'minimum': 75, 'maximum': 150, 'step': 5},
      'load': {'type': 'bodyweight'},
    });
  });

  test(
    'every observed classic assistance exercise resolves in the catalog',
    () {
      final referenced = <String>{};
      for (final plan in plans) {
        for (final slot in _slots(plan)) {
          referenced.addAll(
            (slot['recommendedExerciseIds'] as List<Object?>? ?? const [])
                .cast<String>(),
          );
          for (final prescription
              in (slot['prescriptions'] as List<Object?>? ?? const [])
                  .cast<Map<String, Object?>>()) {
            referenced.add(prescription['exerciseId']! as String);
          }
        }
      }

      expect(exerciseIds, containsAll(referenced));
      expect(
        exerciseIds,
        containsAll({
          'dumbbell_bench_press',
          'hamstring_curl',
          'hanging_leg_raise',
          'leg_press',
          'sit_up',
        }),
      );
    },
  );
}

List<Map<String, Object?>> _records(String path, String key) {
  final document =
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
  return (document[key]! as List<Object?>).cast<Map<String, Object?>>();
}

Map<String, Object?> _plan(List<Map<String, Object?>> plans, String id) =>
    plans.singleWhere((plan) => plan['id'] == id);

List<Map<String, Object?>> _slots(Map<String, Object?> plan) =>
    (plan['slots']! as List<Object?>).cast<Map<String, Object?>>();

Map<String, List<(String, int)>> _fixedPrescriptionMap(
  Map<String, Object?> plan,
) => {
  for (final slot in _slots(plan))
    slot['sessionRole']! as String: [
      for (final prescription
          in (slot['prescriptions']! as List<Object?>)
              .cast<Map<String, Object?>>())
        (
          prescription['exerciseId']! as String,
          ((prescription['repetitions']! as Map<String, Object?>)['count']!
              as int),
        ),
    ],
};

Map<String, List<String>> _recommendedExerciseMap(Map<String, Object?> plan) =>
    {
      for (final slot in _slots(plan))
        slot['sessionRole']! as String:
            (slot['recommendedExerciseIds']! as List<Object?>).cast<String>(),
    };
