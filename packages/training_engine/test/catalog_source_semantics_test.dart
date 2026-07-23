import 'dart:io';

import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  const codec = CatalogSourceDocumentCodec();

  test('source main-work constraints become typed execution semantics', () {
    final components = codec.decodeComponents(
      File(
        '../../catalog_src/shared/cycle_components_v1.json',
      ).readAsStringSync(),
    );
    final standardFive = components.singleWhere(
      (component) => component.reference.id == 'main_standard_5_week',
    );
    final fivesPro = components.singleWhere(
      (component) => component.reference.id == 'main_fives_pro_5_week',
    );

    expect(standardFive.mainWorkSemantics?.waveRole, MainWorkWaveRole.five);
    expect(
      standardFive.mainWorkSemantics?.lastSetPolicy,
      MainWorkLastSetPolicy.amrapPermitted,
    );
    expect(standardFive.mainWorkSemantics?.setRoles, [
      MainWorkSetRole.first,
      MainWorkSetRole.second,
      MainWorkSetRole.top,
    ]);
    expect(
      fivesPro.mainWorkSemantics?.lastSetPolicy,
      MainWorkLastSetPolicy.fixed,
    );
  });

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
    expect(
      {
        for (final schedule in schedules)
          schedule.reference.id: schedule.sessionsPerWeek,
      },
      {
        'schedule_four_day_fixed': 4,
        'schedule_three_day_rotating': 3,
        'schedule_two_day_multi_movement_option_one': 2,
        'schedule_two_day_rotating_four_lifts': 2,
        'classic_extended_two_day_option_one': 2,
        'classic_extended_two_day_option_two': 2,
        'classic_for_beginners_three_day': 3,
        'classic_full_body_three_day': 3,
        'classic_full_body_full_boring_three_day': 3,
        'schedule_original_for_beginners_fixed_three_day': 3,
      },
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

  test('source schedules reject invalid explicit weekly cadence', () {
    final source = File(
      '../../catalog_src/schedules/cycle_schedules_v1.json',
    ).readAsStringSync();

    expect(
      () => codec.decodeSchedules(
        source.replaceFirst('"sessionsPerWeek": 4', '"sessionsPerWeek": 0'),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('sessionsPerWeek must be positive'),
        ),
      ),
    );
    expect(
      () => codec.decodeSchedules(
        source.replaceFirst('"sessionsPerWeek": 4', '"sessionsPerWeek": 3'),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('must equal the session count for fixed schedules'),
        ),
      ),
    );
    expect(
      () => codec.decodeSchedules(
        source.replaceFirst('"sessionsPerWeek": 3', '"sessionsPerWeek": 5'),
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('cannot exceed the session count for rotating schedules'),
        ),
      ),
    );
  });

  test('source codec remains compatible with schedules without cadence', () {
    final source = File(
      '../../catalog_src/schedules/cycle_schedules_v1.json',
    ).readAsStringSync();
    final legacy = source.replaceAll(RegExp(r'\s*"sessionsPerWeek": \d+,'), '');

    expect(
      codec.decodeSchedules(legacy).map((item) => item.sessionsPerWeek),
      everyElement(isNull),
    );
  });
}
