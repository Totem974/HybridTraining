import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Cycle schedules are strict, sourced and cover fixed rotations', () {
    final root =
        jsonDecode(
              File(
                'catalog_src/schedules/cycle_schedules_v1.json',
              ).readAsStringSync(),
            )!
            as Map<String, Object?>;
    expect(root.keys.toSet(), {'schemaVersion', 'kind', 'schedules'});
    expect(root['schemaVersion'], 1);
    expect(root['kind'], 'schedules');
    final schedules = (root['schedules']! as List).cast<Map>();
    expect(
      schedules.map((schedule) => schedule['id']).toSet(),
      hasLength(schedules.length),
    );
    expect(schedules.map((schedule) => schedule['type']).toSet(), {
      'fixed',
      'rotating',
      'multiMovement',
    });
    const keys = {
      'id',
      'revision',
      'labels',
      'sourceRuleIds',
      'type',
      'sessionsPerWeek',
      'sessions',
    };
    for (final schedule in schedules) {
      expect(schedule.keys.toSet(), keys);
      expect(schedule['revision'], 1);
      expect(schedule['sourceRuleIds'], isNotEmpty);
      expect(schedule['sessionsPerWeek'], inInclusiveRange(1, 7));
      final sessions = (schedule['sessions']! as List).cast<Map>();
      expect(sessions, isNotEmpty);
      for (final session in sessions) {
        expect(session.keys.toSet(), {'id', 'role', 'movementIds'});
        expect(session['movementIds'], isNotEmpty);
      }
    }
    expect(
      {
        for (final schedule in schedules)
          schedule['id']: schedule['sessionsPerWeek'],
      },
      {
        'schedule_four_day_fixed': 4,
        'schedule_three_day_rotating': 3,
        'schedule_two_day_multi_movement_option_one': 2,
        'schedule_two_day_rotating_four_lifts': 2,
      },
    );
  });

  test(
    'standard fixed and reduced-frequency schedules preserve lift order',
    () {
      final schedules = _schedulesById();
      expect(_flatten(schedules['schedule_four_day_fixed']!), [
        'overhead_press',
        'deadlift',
        'bench_press',
        'squat',
      ]);
      expect(_flatten(schedules['schedule_three_day_rotating']!), [
        'overhead_press',
        'deadlift',
        'bench_press',
        'squat',
      ]);
      expect(
        _flatten(schedules['schedule_two_day_multi_movement_option_one']!),
        ['squat', 'bench_press', 'deadlift', 'overhead_press'],
      );
    },
  );
}

Map<String, Map> _schedulesById() {
  final root =
      jsonDecode(
            File(
              'catalog_src/schedules/cycle_schedules_v1.json',
            ).readAsStringSync(),
          )!
          as Map<String, Object?>;
  return {
    for (final schedule in (root['schedules']! as List).cast<Map>())
      schedule['id']! as String: schedule,
  };
}

List<String> _flatten(Map schedule) => [
  for (final session in (schedule['sessions']! as List).cast<Map>())
    ...(session['movementIds']! as List).cast<String>(),
];
