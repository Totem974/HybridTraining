import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  const codec = CatalogSourceDocumentCodec();

  test('source schedules preserve their type, role, and movement groups', () {
    final schedules = <SourceSchedule>[
      for (final path in const [
        '../../catalog_src/schedules/cycle_schedules_v1.json',
        '../../catalog_src/classic/extended/schedules.json',
        '../../catalog_src/classic/library/prepared_schedules.v1.json',
      ])
        ...codec.decodeSchedules(File(path).readAsStringSync()),
    ];

    expect(schedules, hasLength(10));
    expect(
      schedules.where((item) => item.type == CycleScheduleMode.fixed),
      hasLength(1),
    );
    expect(
      schedules.where((item) => item.type == CycleScheduleMode.rotating),
      hasLength(3),
    );
    expect(
      schedules.where((item) => item.type == CycleScheduleMode.multiMovement),
      hasLength(6),
    );
    expect(
      schedules.where((item) => item.type == CycleScheduleMode.finite),
      isEmpty,
    );

    final grouped = schedules.singleWhere(
      (item) =>
          item.reference.id == 'schedule_two_day_multi_movement_option_one',
    );
    expect(
      grouped.sessions.map((item) => item.role),
      everyElement('multiLift'),
    );
    expect(grouped.sessions.first.movementIds, ['squat', 'bench_press']);
    expect(grouped.sessions.last.movementIds, ['deadlift', 'overhead_press']);
  });

  test('source variants preserve assistance and conditioning references', () {
    final templates = codec.decodeTemplates(
      File('../../catalog_src/classic/templates.json').readAsStringSync(),
    );

    final expected = {
      'classic_triumvirate': 'original_triumvirate_classic',
      'classic_periodization_bible': 'original_periodization_bible',
      'classic_bodyweight': 'original_bodyweight',
    };
    for (final entry in expected.entries) {
      final variant = templates
          .singleWhere((template) => template.id == entry.key)
          .variants
          .singleWhere((variant) => variant.id == 'four_day');
      expect(variant.assistancePlanIds, hasLength(1));
      expect(variant.assistancePlanIds.single.id, entry.value);
      expect(variant.assistancePlanIds.single.revision, 1);
      expect(variant.conditioningDefinitionIds, isEmpty);
    }
  });

  test('source schedules reject an unknown type', () {
    final source = File(
      '../../catalog_src/schedules/cycle_schedules_v1.json',
    ).readAsStringSync();
    final invalid = source.replaceFirst(
      '"type": "fixed"',
      '"type": "unsupported"',
    );

    expect(
      () => codec.decodeSchedules(invalid),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Unknown schedule type unsupported'),
        ),
      ),
    );
  });
}
