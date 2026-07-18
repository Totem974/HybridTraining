import 'training_models.dart';

enum TrainingWeekday {
  monday(1),
  tuesday(2),
  wednesday(3),
  thursday(4),
  friday(5),
  saturday(6),
  sunday(7);

  const TrainingWeekday(this.isoValue);
  final int isoValue;

  static TrainingWeekday fromIso(int value) => values.singleWhere(
    (day) => day.isoValue == value,
    orElse: () => throw ArgumentError.value(value, 'weekday'),
  );

  static TrainingWeekday fromDate(DateTime date) => fromIso(date.weekday);
}

enum TrainingScheduleMode { fixedWeekdayAssignment, rotatingAcrossSelectedDays }

class TrainingDayAssignment {
  const TrainingDayAssignment({required this.weekday, required this.lift});
  final TrainingWeekday weekday;
  final MainLift lift;
}

class TrainingScheduleDefinition {
  TrainingScheduleDefinition({
    required DateTime startsOn,
    required this.frequency,
    required List<TrainingWeekday> selectedWeekdays,
    required List<MainLift> liftOrder,
    required this.mode,
    required List<TrainingDayAssignment> weekdayAssignments,
    this.version = 1,
  }) : startsOn = DateTime(startsOn.year, startsOn.month, startsOn.day),
       selectedWeekdays = List.unmodifiable(selectedWeekdays),
       liftOrder = List.unmodifiable(liftOrder),
       weekdayAssignments = List.unmodifiable(weekdayAssignments);

  final int version;
  final DateTime startsOn;
  final int frequency;
  final List<TrainingWeekday> selectedWeekdays;
  final List<MainLift> liftOrder;
  final TrainingScheduleMode mode;
  final List<TrainingDayAssignment> weekdayAssignments;

  List<String> validate() {
    final errors = <String>[];
    if (version != 1) errors.add('Unsupported schedule version: $version');
    if (frequency != 3 && frequency != 4) {
      errors.add('Frequency must be 3 or 4.');
    }
    if (selectedWeekdays.length != frequency) {
      errors.add('Selected weekdays must match frequency.');
    }
    if (selectedWeekdays.toSet().length != selectedWeekdays.length) {
      errors.add('Selected weekdays must be unique.');
    }
    if (liftOrder.length != MainLift.values.length ||
        liftOrder.toSet().length != MainLift.values.length ||
        !liftOrder.toSet().containsAll(MainLift.values)) {
      errors.add('Lift order must contain every main lift exactly once.');
    }
    if (frequency == 4) {
      if (mode != TrainingScheduleMode.fixedWeekdayAssignment) {
        errors.add('Four-day schedules require fixed weekday assignments.');
      }
      final assignedDays = weekdayAssignments.map((item) => item.weekday);
      final assignedLifts = weekdayAssignments.map((item) => item.lift);
      if (weekdayAssignments.length != 4 ||
          assignedDays.toSet().length != 4 ||
          assignedLifts.toSet().length != 4 ||
          !assignedDays.every(selectedWeekdays.contains) ||
          !assignedLifts.toSet().containsAll(MainLift.values)) {
        errors.add(
          'Four-day assignments must map each selected day to one lift.',
        );
      }
    } else {
      if (mode != TrainingScheduleMode.rotatingAcrossSelectedDays) {
        errors.add('Three-day schedules require rotating assignments.');
      }
      if (weekdayAssignments.isNotEmpty) {
        errors.add('Rotating schedules cannot contain fixed assignments.');
      }
    }
    return List.unmodifiable(errors);
  }

  void ensureValid() {
    final errors = validate();
    if (errors.isNotEmpty) throw ArgumentError(errors.join(' '));
  }
}

class ScheduledSessionSlot {
  const ScheduledSessionSlot({
    required this.index,
    required this.programWeek,
    required this.lift,
    required this.date,
  });
  final int index;
  final int programWeek;
  final MainLift lift;
  final DateTime date;
}

class SessionScheduleBuilder {
  const SessionScheduleBuilder();

  List<ScheduledSessionSlot> build(
    TrainingScheduleDefinition schedule, {
    int programWeeks = 3,
  }) {
    schedule.ensureValid();
    final total = programWeeks * MainLift.values.length;
    final selected = schedule.selectedWeekdays.toSet();
    final fixed = {
      for (final item in schedule.weekdayAssignments) item.weekday: item.lift,
    };
    final slots = <ScheduledSessionSlot>[];
    var date = schedule.startsOn;
    while (slots.length < total) {
      final weekday = TrainingWeekday.fromDate(date);
      if (selected.contains(weekday)) {
        final index = slots.length;
        slots.add(
          ScheduledSessionSlot(
            index: index,
            programWeek: index ~/ MainLift.values.length + 1,
            lift: schedule.mode == TrainingScheduleMode.fixedWeekdayAssignment
                ? fixed[weekday]!
                : schedule.liftOrder[index % schedule.liftOrder.length],
            date: date,
          ),
        );
      }
      date = date.add(const Duration(days: 1));
    }
    return List.unmodifiable(slots);
  }
}
