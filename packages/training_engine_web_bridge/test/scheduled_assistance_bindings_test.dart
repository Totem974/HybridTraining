import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine_web_bridge/training_engine_web_bridge.dart';

void main() {
  late BridgeService service;

  setUp(() {
    service = _initializedService();
  });

  test(
    'three-day rotating schedule uses three sessions per displayed week',
    () {
      final cycle = _generate(
        service,
        _request(
          templateId: 'classic_531',
          variantId: 'three_day_rotation',
          scheduleId: 'schedule_three_day_rotating',
          trainingDays: const [1, 3, 5],
          sessionOrder: const [
            'overhead_press',
            'deadlift',
            'bench_press',
            'squat',
          ],
        ),
      );

      final weeks = _weeks(cycle);
      expect(weeks, hasLength(4));
      expect(weeks.map((week) => _sessions(week).length), everyElement(3));
      expect(
        weeks.expand(_sessions).map((session) => session['movementId']).toSet(),
        {'overhead_press', 'deadlift', 'bench_press', 'squat'},
      );
    },
  );

  test('two-day rotating schedule unfolds twelve work sessions', () {
    final cycle = _generate(
      service,
      _request(
        templateId: 'classic_531',
        variantId: 'two_day_rotation',
        scheduleId: 'schedule_two_day_rotating_four_lifts',
        trainingDays: const [2, 5],
        sessionOrder: const [
          'overhead_press',
          'deadlift',
          'bench_press',
          'squat',
        ],
      ),
    );

    final weeks = _weeks(cycle);
    expect(weeks, hasLength(6));
    expect(weeks.map((week) => _sessions(week).length), everyElement(2));
    expect(weeks.expand(_sessions), hasLength(12));
  });

  test('multi-movement schedule preserves its two session groups', () {
    final cycle = _generate(
      service,
      _request(
        templateId: 'classic_531',
        variantId: 'two_day_rotation',
        scheduleId: 'schedule_two_day_multi_movement_option_one',
        trainingDays: const [2, 5],
        sessionOrder: const ['squat_bench_press', 'deadlift_overhead_press'],
      ),
    );

    final weeks = _weeks(cycle);
    expect(weeks, hasLength(3));
    expect(weeks.map((week) => _sessions(week).length), everyElement(2));
    final firstWeek = _sessions(weeks.first);
    expect(firstWeek.map((session) => session['movementId']), [
      'squat_bench_press',
      'deadlift_overhead_press',
    ]);
    expect(
      _blocks(firstWeek.first).map((block) => block['movementId']).toSet(),
      containsAll({'squat', 'bench_press'}),
    );
    expect(
      _blocks(firstWeek.last).map((block) => block['movementId']).toSet(),
      containsAll({'deadlift', 'overhead_press'}),
    );
  });

  test('Bodyweight 80/5 compiles exact ordered exercise blocks', () {
    final cycle = _generate(service, _bodyweightRequest(includeDeload: false));

    final firstSession = _sessions(_weeks(cycle).first).first;
    final assistance = _blocks(
      firstSession,
    ).where((block) => block['role'] == 'assistance').toList();
    expect(assistance.map((block) => block['movementId']), ['pull_up', 'dip']);
    for (final block in assistance) {
      expect(
        _sets(
          block,
        ).map((set) => (set['repetitions'] as Map<String, Object?>)['count']),
        [16, 16, 16, 16, 16],
      );
    }
  });

  test('Bodyweight assistance stays on deload and deload off removes week', () {
    final withDeload = _generate(
      service,
      _bodyweightRequest(includeDeload: true),
    );
    final withoutDeload = _generate(
      service,
      _bodyweightRequest(includeDeload: false),
    );

    expect(_weeks(withDeload), hasLength(4));
    expect(_weeks(withoutDeload), hasLength(3));
    final deloadSessions = _sessions(_weeks(withDeload).last);
    expect(deloadSessions, hasLength(4));
    for (final session in deloadSessions) {
      expect(
        _blocks(session).where((block) => block['role'] == 'assistance'),
        hasLength(2),
      );
    }
  });
}

BridgeService _initializedService() {
  final bundle =
      jsonDecode(
            File(
              '../../apps/web_generator/public/catalog.bundle.json',
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  for (final rawDocument in (bundle['documents']! as List).cast<Map>()) {
    final document = rawDocument.cast<String, Object?>();
    final content = (document['content']! as Map).cast<String, Object?>();
    final path = document['path']! as String;
    if (content['kind'] == 'schedules' ||
        content['kind'] == 'assistancePlans' ||
        path == 'classic/option_schemas.json') {
      document['content'] = jsonDecode(
        File('../../catalog_src/$path').readAsStringSync(),
      );
    }
  }
  _addBodyweightDeloadFixture(bundle);
  final service = BridgeService(LocalTrainingEngineBindings());
  service.initialize(jsonEncode(bundle));
  return service;
}

void _addBodyweightDeloadFixture(Map<String, Object?> bundle) {
  // The current Bodyweight catalog variant has no source deload week. Add one
  // only in this integration fixture so the bridge test can prove that
  // scheduled assistance is preserved on an existing deload week.
  final documents = (bundle['documents']! as List).cast<Map>();
  final templatesDocument = documents
      .map((document) => document.cast<String, Object?>())
      .singleWhere((document) => document['path'] == 'classic/templates.json');
  final content = (templatesDocument['content']! as Map)
      .cast<String, Object?>();
  final templates = (content['templates']! as List).cast<Map>();
  final bodyweight = templates
      .map((template) => template.cast<String, Object?>())
      .singleWhere((template) => template['id'] == 'classic_bodyweight');
  final variants = (bodyweight['variants']! as List).cast<Map>();
  final fourDay = variants
      .map((variant) => variant.cast<String, Object?>())
      .singleWhere((variant) => variant['id'] == 'four_day');
  (fourDay['weekPlans']! as List).add({
    'weekNumber': 4,
    'componentIds': [
      {'id': 'deload_original_40_50_60', 'revision': 1},
    ],
  });
}

Map<String, Object?> _bodyweightRequest({required bool includeDeload}) =>
    _request(
      templateId: 'classic_bodyweight',
      variantId: 'four_day',
      scheduleId: 'schedule_four_day_fixed',
      trainingDays: const [1, 2, 4, 5],
      sessionOrder: const [
        'overhead_press',
        'deadlift',
        'bench_press',
        'squat',
      ],
      options: {
        'total_repetitions': 80,
        'set_count': 5,
        'deload': {
          'enabled': includeDeload,
          if (includeDeload) 'type': 'deload1',
          if (includeDeload) 'skipWarmUp': false,
        },
      },
      includeDeload: includeDeload,
    );

Map<String, Object?> _request({
  required String templateId,
  required String variantId,
  required String scheduleId,
  required List<int> trainingDays,
  required List<String> sessionOrder,
  bool includeDeload = false,
  Map<String, Object?> options = const {
    'deload': {'enabled': false},
  },
}) => {
  'apiVersion': 'v1',
  'schemaVersion': 1,
  'cycleId': 'scheduled-$templateId-$variantId',
  'templateId': templateId,
  'variantId': variantId,
  'scheduleId': scheduleId,
  'startDate': '2026-07-27T00:00:00.000Z',
  'trainingDays': trainingDays,
  'sessionOrder': sessionOrder,
  'maxInputs': {
    for (final movement in const [
      'overhead_press',
      'deadlift',
      'bench_press',
      'squat',
    ])
      movement: {
        'type': 'directTrainingMax',
        'weight': {'centiUnits': 10000, 'unit': 'kg'},
      },
  },
  'globalTrainingMaxRatioBasisPoints': 10000,
  'trainingMaxRatioByMovement': <String, Object?>{},
  'percentageParameters': <String, Object?>{},
  'percentageParametersByMovement': <String, Object?>{},
  'options': options,
  'unit': 'kg',
  'roundingIncrement': {'centiUnits': 100, 'unit': 'kg'},
  'barProfile': {
    'weight': {'centiUnits': 2000, 'unit': 'kg'},
    'platesPerSide': [
      {'centiUnits': 2500, 'unit': 'kg'},
      {'centiUnits': 2000, 'unit': 'kg'},
      {'centiUnits': 1500, 'unit': 'kg'},
      {'centiUnits': 1000, 'unit': 'kg'},
      {'centiUnits': 500, 'unit': 'kg'},
      {'centiUnits': 250, 'unit': 'kg'},
      {'centiUnits': 125, 'unit': 'kg'},
    ],
  },
  'includeDeload': includeDeload,
};

Map<String, Object?> _generate(
  BridgeService service,
  Map<String, Object?> request,
) {
  final response =
      jsonDecode(service.generateCycle(jsonEncode(request)))
          as Map<String, Object?>;
  expect(response.keys, {
    'apiVersion',
    'schemaVersion',
    'engineVersion',
    'catalogVersion',
    'catalogHash',
    'cycle',
    'warnings',
    'snapshot',
  });
  return response['cycle']! as Map<String, Object?>;
}

List<Map<String, Object?>> _weeks(Map<String, Object?> cycle) =>
    (cycle['weeks']! as List).cast<Map<String, Object?>>();

List<Map<String, Object?>> _sessions(Map<String, Object?> week) =>
    (week['sessions']! as List).cast<Map<String, Object?>>();

List<Map<String, Object?>> _blocks(Map<String, Object?> session) =>
    (session['blocks']! as List).cast<Map<String, Object?>>();

List<Map<String, Object?>> _sets(Map<String, Object?> block) =>
    (block['sets']! as List).cast<Map<String, Object?>>();
