import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/programs/domain/training_schedule.dart';

void main() {
  const order = [
    MainLift.deadlift,
    MainLift.squat,
    MainLift.benchPress,
    MainLift.overheadPress,
  ];

  TrainingScheduleDefinition four({DateTime? startsOn}) =>
      TrainingScheduleDefinition(
        startsOn: startsOn ?? DateTime(2026, 7, 20),
        frequency: 4,
        selectedWeekdays: const [
          TrainingWeekday.monday,
          TrainingWeekday.tuesday,
          TrainingWeekday.thursday,
          TrainingWeekday.saturday,
        ],
        liftOrder: order,
        mode: TrainingScheduleMode.fixedWeekdayAssignment,
        weekdayAssignments: const [
          TrainingDayAssignment(
            weekday: TrainingWeekday.monday,
            lift: MainLift.deadlift,
          ),
          TrainingDayAssignment(
            weekday: TrainingWeekday.tuesday,
            lift: MainLift.squat,
          ),
          TrainingDayAssignment(
            weekday: TrainingWeekday.thursday,
            lift: MainLift.benchPress,
          ),
          TrainingDayAssignment(
            weekday: TrainingWeekday.saturday,
            lift: MainLift.overheadPress,
          ),
        ],
      );

  TrainingScheduleDefinition three({DateTime? startsOn}) =>
      TrainingScheduleDefinition(
        startsOn: startsOn ?? DateTime(2026, 7, 20),
        frequency: 3,
        selectedWeekdays: const [
          TrainingWeekday.monday,
          TrainingWeekday.wednesday,
          TrainingWeekday.friday,
        ],
        liftOrder: order,
        mode: TrainingScheduleMode.rotatingAcrossSelectedDays,
        weekdayAssignments: const [],
      );

  test('validates four-day and three-day schedules', () {
    expect(four().validate(), isEmpty);
    expect(three().validate(), isEmpty);
  });

  test('rejects bad day, lift and assignment cardinality', () {
    final duplicateDays = TrainingScheduleDefinition(
      startsOn: DateTime(2026),
      frequency: 3,
      selectedWeekdays: const [
        TrainingWeekday.monday,
        TrainingWeekday.monday,
        TrainingWeekday.friday,
      ],
      liftOrder: order,
      mode: TrainingScheduleMode.rotatingAcrossSelectedDays,
      weekdayAssignments: const [],
    );
    final duplicateLifts = TrainingScheduleDefinition(
      startsOn: DateTime(2026),
      frequency: 3,
      selectedWeekdays: const [
        TrainingWeekday.monday,
        TrainingWeekday.wednesday,
        TrainingWeekday.friday,
      ],
      liftOrder: const [
        MainLift.squat,
        MainLift.squat,
        MainLift.benchPress,
        MainLift.overheadPress,
      ],
      mode: TrainingScheduleMode.rotatingAcrossSelectedDays,
      weekdayAssignments: const [],
    );
    final incomplete = TrainingScheduleDefinition(
      startsOn: DateTime(2026),
      frequency: 4,
      selectedWeekdays: const [
        TrainingWeekday.monday,
        TrainingWeekday.tuesday,
        TrainingWeekday.thursday,
        TrainingWeekday.saturday,
      ],
      liftOrder: order,
      mode: TrainingScheduleMode.fixedWeekdayAssignment,
      weekdayAssignments: const [],
    );
    expect(duplicateDays.validate().join(), contains('unique'));
    expect(duplicateLifts.validate().join(), contains('every main lift'));
    expect(incomplete.validate().join(), contains('assignments'));
  });

  test(
    'four-day generation is fixed, chronological and spans twelve slots',
    () {
      final slots = const SessionScheduleBuilder().build(four());
      expect(slots, hasLength(12));
      expect(slots.first.date, DateTime(2026, 7, 20));
      expect(slots.map((item) => item.date).toSet(), hasLength(12));
      for (final lift in MainLift.values) {
        final liftSlots = slots.where((item) => item.lift == lift).toList();
        expect(liftSlots, hasLength(3));
        expect(
          liftSlots.map((item) => item.date.weekday).toSet(),
          hasLength(1),
        );
      }
      expect(slots.map((item) => item.programWeek).toSet(), {1, 2, 3});
    },
  );

  test('three-day generation rotates lifts across four calendar weeks', () {
    final slots = const SessionScheduleBuilder().build(three());
    expect(slots, hasLength(12));
    expect(slots.map((item) => item.date).toSet(), hasLength(12));
    expect(slots.map((item) => item.lift).toList(), [
      ...order,
      ...order,
      ...order,
    ]);
    expect(slots.last.date.difference(slots.first.date).inDays ~/ 7 + 1, 4);
    expect(slots.map((item) => item.programWeek).toSet(), {1, 2, 3});
  });

  test('uses the next selected day and crosses month and year boundaries', () {
    final month = const SessionScheduleBuilder().build(
      three(startsOn: DateTime(2026, 7, 21)),
    );
    expect(month.first.date, DateTime(2026, 7, 22));
    expect(month.any((item) => item.date.month == 8), isTrue);
    final year = const SessionScheduleBuilder().build(
      three(startsOn: DateTime(2026, 12, 29)),
    );
    expect(year.first.date, DateTime(2026, 12, 30));
    expect(year.any((item) => item.date.year == 2027), isTrue);
    for (var index = 1; index < year.length; index++) {
      expect(year[index].date.isAfter(year[index - 1].date), isTrue);
    }
  });
}
