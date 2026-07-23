import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> readDocument(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

List<Map<String, Object?>> records(
  Map<String, Object?> document,
  String kind,
) => (document[kind] as List<Object?>).cast<Map<String, Object?>>();

void expectDocumentShape(Map<String, Object?> document, String kind) {
  expect(document.keys.toSet(), {'schemaVersion', 'kind', kind});
  expect(document['schemaVersion'], 1);
  expect(document['kind'], kind);
}

void expectStableRecords(List<Map<String, Object?>> values) {
  const calculatorSourceRuleIds = {
    'app.source_calculator.gvt_assistance',
    'app.source_calculator.two_day_assistance',
  };
  final ids = <String>{};
  for (final record in values) {
    final id = record['id']! as String;
    expect(id, matches(RegExp(r'^[a-z][a-z0-9_]*$')));
    expect(ids.add(id), isTrue, reason: 'duplicate stable id: $id');
    expect(record['revision'], 1);
    expect((record['labels']! as Map<String, Object?>).keys.toSet(), {
      'en',
      'fr',
    });
    final sourceRuleIds = (record['sourceRuleIds']! as List<Object?>)
        .cast<String>();
    expect(sourceRuleIds, isNotEmpty, reason: '$id must be sourced');
    for (final sourceRuleId in sourceRuleIds) {
      final isPublishedBookRule = RegExp(
        r'^(or|by|fv|pl)\.',
      ).hasMatch(sourceRuleId);
      expect(
        isPublishedBookRule || calculatorSourceRuleIds.contains(sourceRuleId),
        isTrue,
        reason: '$id has an unrecognized source rule: $sourceRuleId',
      );
    }
    expect(
      jsonEncode(record).toLowerCase(),
      isNot(
        anyOf(contains('todo'), contains('placeholder'), contains('review')),
      ),
    );
  }
}

void main() {
  group('catalogue libraries', () {
    final movementsDocument = readDocument(
      'catalog_src/exercises/movements.v1.json',
    );
    final exercisesDocument = readDocument(
      'catalog_src/exercises/exercises.v1.json',
    );
    final assistanceDocument = readDocument(
      'catalog_src/assistance/plans.v1.json',
    );
    final conditioningDocument = readDocument(
      'catalog_src/conditioning/definitions.v1.json',
    );

    test('documents and stable records follow the frozen envelope', () {
      for (final pair in <(Map<String, Object?>, String)>[
        (movementsDocument, 'movements'),
        (exercisesDocument, 'exercises'),
        (assistanceDocument, 'assistancePlans'),
        (conditioningDocument, 'conditioningDefinitions'),
      ]) {
        expectDocumentShape(pair.$1, pair.$2);
        expectStableRecords(records(pair.$1, pair.$2));
      }
    });

    test('all main movements expose equipment capabilities', () {
      final movements = records(movementsDocument, 'movements');
      expect(
        movements.map((movement) => movement['id']),
        containsAll([
          'back_squat',
          'bench_press',
          'deadlift',
          'overhead_press',
        ]),
      );
      for (final movement in movements) {
        expect(movement.keys.toSet(), {
          'id',
          'revision',
          'labels',
          'sourceRuleIds',
          'pattern',
          'trainingMaxEligible',
          'requiredCapabilities',
        });
        expect(movement['requiredCapabilities'], isNotEmpty);
      }
    });

    test('exercise library covers every assistance category and unit', () {
      final exercises = records(exercisesDocument, 'exercises');
      final categories = exercises
          .expand((exercise) => exercise['categories']! as List<Object?>)
          .toSet();
      final units = exercises
          .expand((exercise) => exercise['measurementModes']! as List<Object?>)
          .toSet();
      expect(
        categories,
        containsAll(['push', 'pull', 'singleLegCore', 'neck']),
      );
      expect(units, containsAll(['repetitions', 'duration', 'distance']));
      for (final exercise in exercises) {
        expect(exercise.keys.toSet(), {
          'id',
          'revision',
          'labels',
          'sourceRuleIds',
          'categories',
          'measurementModes',
          'requiredCapabilities',
          'loadingModes',
        });
      }
    });

    test('assistance slots only refer to covered exercise categories', () {
      final coveredCategories = records(
        exercisesDocument,
        'exercises',
      ).expand((exercise) => exercise['categories']! as List<Object?>).toSet();
      for (final plan in records(assistanceDocument, 'assistancePlans')) {
        expect(plan.keys.toSet(), {
          'id',
          'revision',
          'labels',
          'sourceRuleIds',
          'slots',
          'constraints',
          'compatibleExerciseCategories',
        });
        for (final slot
            in (plan['slots']! as List<Object?>).cast<Map<String, Object?>>()) {
          expect(coveredCategories, contains(slot['category']));
          expect(
            slot['minimumTotal']! as num,
            lessThanOrEqualTo(slot['maximumTotal']! as num),
          );
          expect(
            slot['minimumExercises']! as num,
            lessThanOrEqualTo(slot['maximumExercises']! as num),
          );
        }
      }
    });

    test(
      'conditioning keeps repetition, distance and duration semantics apart',
      () {
        final definitions = records(
          conditioningDocument,
          'conditioningDefinitions',
        );
        expect(
          definitions.map((definition) => definition['intensity']).toSet(),
          {'easy', 'hard', 'test'},
        );
        for (final definition in definitions) {
          expect(definition.keys.toSet(), {
            'id',
            'revision',
            'labels',
            'sourceRuleIds',
            'intensity',
            'modality',
            'measurementModes',
            'frequency',
            'prescription',
            'placement',
            'requiredCapabilities',
          });
          final frequency = definition['frequency']! as Map<String, Object?>;
          expect(
            frequency['minimumPerWeek']! as num,
            lessThanOrEqualTo(frequency['maximumPerWeek']! as num),
          );
        }
        final farmerPlan = records(
          assistanceDocument,
          'assistancePlans',
        ).singleWhere((plan) => plan['id'] == 'forever_farmer_walk_distance');
        expect(
          ((farmerPlan['slots']! as List<Object?>).single
              as Map<String, Object?>)['unit'],
          'yards',
        );
      },
    );
  });
}
