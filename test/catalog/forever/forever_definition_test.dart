import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> readDocument(String name) =>
    jsonDecode(File('catalog_src/forever/$name').readAsStringSync())
        as Map<String, Object?>;

void main() {
  test('publishes exactly one finite, fully referenced Forever definition', () {
    final document = readDocument('definitions.json');
    expect(document.keys.toSet(), {
      'schemaVersion',
      'kind',
      'foreverDefinitions',
    });
    expect(document['schemaVersion'], 1);
    expect(document['kind'], 'foreverDefinitions');

    final definitions = (document['foreverDefinitions']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(definitions, hasLength(1));
    final definition = definitions.single;
    expect(definition['id'], 'forever_bbb_2_leader_1_anchor');
    expect(definition['revision'], 1);

    final phases = (definition['phases']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(phases.map((phase) => phase['role']), [
      'leader',
      'deload',
      'anchor',
      'test',
    ]);
    expect(phases.map((phase) => phase['repeatCount']), [2, 1, 1, 1]);
    expect(
      phases.fold<int>(
        0,
        (total, phase) => total + (phase['repeatCount']! as int),
      ),
      5,
    );
    expect(
      phases.map((phase) => phase['cycle']).every((value) => value is Map),
      isTrue,
    );
  });

  test('roles resolve only to published Cycle variants', () {
    final templates =
        (readDocument('cycle_templates.json')['templates']! as List<Object?>)
            .cast<Map<String, Object?>>();
    final published = <String>{};
    for (final template in templates) {
      for (final variant
          in (template['variants']! as List<Object?>)
              .cast<Map<String, Object?>>()) {
        published.add('${template['id']}/${variant['id']}');
      }
    }

    final definition =
        (readDocument('definitions.json')['foreverDefinitions']!
                as List<Object?>)
            .cast<Map<String, Object?>>()
            .single;
    for (final phase
        in (definition['phases']! as List<Object?>)
            .cast<Map<String, Object?>>()) {
      final cycle = phase['cycle']! as Map<String, Object?>;
      expect(
        published,
        contains('${cycle['templateId']}/${cycle['variantId']}'),
        reason: phase['id']! as String,
      );
    }
  });

  test('7th Week protocols reproduce the reviewed percentages and reps', () {
    final components =
        (readDocument('components.json')['components']! as List<Object?>)
            .cast<Map<String, Object?>>();
    final byId = {
      for (final component in components) component['id']: component,
    };

    List<Map<String, Object?>> sets(String id) =>
        (((byId[id]!['block']! as Map<String, Object?>)['sets']!)
                as List<Object?>)
            .cast<Map<String, Object?>>();

    final deload = sets('forever_7th_week_deload');
    expect(
      deload.map(
        (set) => (set['load']! as Map<String, Object?>)['basisPoints'],
      ),
      [7000, 8000, 9000, 10000],
    );
    expect(
      deload.map(
        (set) => (set['repetitions']! as Map<String, Object?>)['count'],
      ),
      [5, 3, 1, 1],
    );

    final testSets = sets('forever_7th_week_tm_test');
    expect(
      testSets.map(
        (set) => (set['load']! as Map<String, Object?>)['basisPoints'],
      ),
      [7000, 8000, 9000, 10000],
    );
    expect(testSets.last['repetitions'], {
      'type': 'range',
      'minimum': 3,
      'maximum': 5,
    });
  });

  test('Training Max rules preserve projected and confirmed values', () {
    final definition =
        (readDocument('definitions.json')['foreverDefinitions']!
                as List<Object?>)
            .cast<Map<String, Object?>>()
            .single;
    final phases = (definition['phases']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final leaderRule = phases.first['trainingMaxRule']! as Map<String, Object?>;
    expect(leaderRule, {
      'type': 'add',
      'upperBody': 5,
      'lowerBody': 10,
      'unit': 'lb',
      'valueState': 'projected',
    });
    expect(phases[1]['trainingMaxRule'], {'type': 'keep'});
    expect(phases.last['trainingMaxRule'], {
      'type': 'testThenConfirm',
      'projectedValuePolicy': 'preserveUntilConfirmed',
    });
  });

  test('all executable records cite reviewed primary-source rules', () {
    final sources = (readDocument('sources.json')['sources']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final sourceIds = sources.map((source) => source['ruleId']).toSet();
    expect(
      sources.every((source) => source['reviewStatus'] == 'reviewed'),
      isTrue,
    );

    for (final file in [
      'definitions.json',
      'cycle_templates.json',
      'components.json',
    ]) {
      final encoded = File('catalog_src/forever/$file').readAsStringSync();
      expect(encoded.toLowerCase(), isNot(contains('placeholder')));
      expect(encoded.toLowerCase(), isNot(contains('todo')));
      expect(encoded.toLowerCase(), isNot(contains('needs_review')));
    }

    final definitions =
        (readDocument('definitions.json')['foreverDefinitions']!
                as List<Object?>)
            .cast<Map<String, Object?>>();
    final templates =
        (readDocument('cycle_templates.json')['templates']! as List<Object?>)
            .cast<Map<String, Object?>>();
    final components =
        (readDocument('components.json')['components']! as List<Object?>)
            .cast<Map<String, Object?>>();
    final records = <Map<String, Object?>>[
      ...definitions,
      ...templates,
      ...templates.expand(
        (template) => (template['variants']! as List<Object?>)
            .cast<Map<String, Object?>>(),
      ),
      ...components,
    ];
    for (final record in records) {
      for (final ruleId in record['sourceRuleIds']! as List<Object?>) {
        expect(sourceIds, contains(ruleId), reason: '${record['id']}: $ruleId');
      }
    }
  });
}
