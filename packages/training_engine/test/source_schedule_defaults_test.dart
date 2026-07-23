import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

const _sourceScheduleId = 'schedule_two_day_paired_source_order';
const _scheduleRuleId = 'or.schedule.two_day_option_1';
const _deloadRuleId = 'or.deload.classic';

void main() {
  const codec = CatalogSourceDocumentCodec();
  const resolver = CatalogScheduleDataResolver();

  test('source paired schedule passes codec and source lint', () {
    final source = File(
      '../../catalog_src/schedules/cycle_schedules_v1.json',
    ).readAsStringSync();
    final document = _decodeDocument(source);
    final records = _records(document, 'schedules');
    final ids = records.map((record) => record['id']).toList(growable: false);

    expect(ids.toSet(), hasLength(ids.length));

    final record = records.singleWhere(
      (record) => record['id'] == _sourceScheduleId,
    );
    expect(record.keys.toSet(), {
      'id',
      'revision',
      'labels',
      'sourceRuleIds',
      'type',
      'sessionsPerWeek',
      'sessions',
    });
    expect(record['revision'], 1);
    expect(record['sourceRuleIds'], [_scheduleRuleId]);

    final schedule = codec
        .decodeSchedules(source)
        .singleWhere((schedule) => schedule.reference.id == _sourceScheduleId);
    expect(schedule.reference.revision, 1);
    expect(schedule.type, CycleScheduleMode.multiMovement);
    expect(schedule.sessionsPerWeek, 2);
    expect(schedule.sessions.map((session) => session.id), [
      'deadlift_overhead_press',
      'squat_bench_press',
    ]);
    expect(
      schedule.sessions.map((session) => session.role),
      everyElement('multiLift'),
    );
    expect(schedule.sessions.map((session) => session.movementIds), [
      ['deadlift', 'overhead_press'],
      ['squat', 'bench_press'],
    ]);
  });

  test('source paired schedule resolves without changing its order', () {
    final source = File(
      '../../catalog_src/schedules/cycle_schedules_v1.json',
    ).readAsStringSync();
    final schedule = codec
        .decodeSchedules(source)
        .singleWhere((schedule) => schedule.reference.id == _sourceScheduleId);

    final resolved = resolver.resolve(schedule);

    expect(resolved.id, _sourceScheduleId);
    expect(resolved.mode, CycleScheduleMode.multiMovement);
    expect(resolved.allowedFrequencies, {2});
    expect(resolved.sessions.map((session) => session.id.value), [
      'deadlift_overhead_press',
      'squat_bench_press',
    ]);
    expect(
      resolved.sessions.map(
        (session) =>
            session.movementIds.map((movement) => movement.value).toList(),
      ),
      [
        ['deadlift', 'overhead_press'],
        ['squat', 'bench_press'],
      ],
    );
  });

  test('classic deload skip-warm-up default stays source-backed', () {
    final source = File(
      '../../catalog_src/classic/option_schemas.json',
    ).readAsStringSync();
    final schemas = codec.decodeOptionSchemas(source);
    final schema = schemas.singleWhere(
      (schema) => schema['id'] == 'classic_531_options',
    );
    expect(schema['sourceRuleIds'], contains(_deloadRuleId));
    expect(schema['sourceRuleIds'], contains('or.warm_up.40_50_60'));

    final crosscut = schemas.singleWhere(
      (schema) => schema['id'] == 'classic_crosscut_options',
    );
    final parameters = (crosscut['parameters']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final parameterIds = parameters
        .map((parameter) => parameter['id'])
        .toList(growable: false);
    expect(parameterIds.toSet(), hasLength(parameterIds.length));

    final skipWarmUp = parameters.singleWhere(
      (parameter) => parameter['id'] == 'deload.skipWarmUp',
    );
    expect(skipWarmUp['type'], 'boolean');
    expect(skipWarmUp['scope'], 'global');
    expect(skipWarmUp['default'], isTrue);
    expect(skipWarmUp['allowedValues'], [true, false]);

    const condition = <String, Object?>{
      'type': 'all',
      'conditions': <Object?>[
        <String, Object?>{
          'type': 'equals',
          'parameterId': 'deload.enabled',
          'value': true,
        },
        <String, Object?>{
          'type': 'in',
          'parameterId': 'deload.type',
          'values': <Object?>[
            'deload1',
            'deload2',
            'deload3',
            'deload4',
            'deload5',
          ],
        },
      ],
    };
    expect(skipWarmUp['visibleWhen'], condition);
    expect(skipWarmUp['enabledWhen'], condition);
    expect(skipWarmUp['requiredWhen'], condition);
  });

  test('schedule and deload provenance rules exist in the source registry', () {
    final sources = _records(
      _decodeDocument(
        File('../../catalog_src/classic/sources.json').readAsStringSync(),
      ),
      'sources',
    );
    final ruleIds = sources.map((source) => source['ruleId']).toSet();

    expect(ruleIds, containsAll({_scheduleRuleId, _deloadRuleId}));
  });
}

Map<String, Object?> _decodeDocument(String source) =>
    jsonDecode(source) as Map<String, Object?>;

List<Map<String, Object?>> _records(
  Map<String, Object?> document,
  String key,
) => (document[key]! as List<Object?>).cast<Map<String, Object?>>();
