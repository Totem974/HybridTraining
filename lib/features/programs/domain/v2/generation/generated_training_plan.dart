import '../program_domain.dart';
import '../../training_models.dart';

enum GeneratedSessionBlockKind {
  warmup,
  athletic,
  mainWork,
  supplemental,
  assistance,
  conditioning,
  transition,
}

enum PlannedEventKind { trainingMaxProgression, trainingMaxTest, prTest }

class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime value) =>
      LocalDate(value.year, value.month, value.day);

  final int year;
  final int month;
  final int day;

  LocalDate addDays(int days) {
    final value = DateTime(year, month, day + days);
    return LocalDate(value.year, value.month, value.day);
  }

  int get weekday => DateTime(year, month, day).weekday;
  String get iso8601 =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) => iso8601.compareTo(other.iso8601);
  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;
  @override
  int get hashCode => Object.hash(year, month, day);
}

class GeneratedPrescription {
  const GeneratedPrescription({
    required this.movement,
    required this.setKind,
    required this.percentage,
    required this.repetitions,
    required this.trainingMax,
    required this.unroundedLoad,
    required this.load,
    required this.roundingIncrement,
    required this.rule,
    this.isPerformanceSet = false,
  });

  final MainLift movement;
  final SetKind setKind;
  final double percentage;
  final int repetitions;
  final double trainingMax;
  final double unroundedLoad;
  final double load;
  final double roundingIncrement;
  final RuleReference rule;
  final bool isPerformanceSet;

  Map<String, Object?> toJson() => {
    'movement': movement.name,
    'setKind': setKind.name,
    'percentage': percentage,
    'repetitions': repetitions,
    'trainingMax': trainingMax,
    'unroundedLoad': unroundedLoad,
    'load': load,
    'roundingIncrement': roundingIncrement,
    'isPerformanceSet': isPerformanceSet,
    'rule': {'document': rule.document, 'location': rule.location},
  };
}

class GeneratedSessionBlock {
  GeneratedSessionBlock({
    required this.kind,
    required List<GeneratedPrescription> prescriptions,
    List<String> instructions = const [],
  }) : prescriptions = List.unmodifiable(prescriptions),
       instructions = List.unmodifiable(instructions);
  final GeneratedSessionBlockKind kind;
  final List<GeneratedPrescription> prescriptions;
  final List<String> instructions;
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'prescriptions': prescriptions.map((e) => e.toJson()).toList(),
    if (instructions.isNotEmpty) 'instructions': instructions,
  };
}

class GeneratedSession {
  GeneratedSession({
    required this.id,
    required this.date,
    required List<GeneratedSessionBlock> blocks,
  }) : blocks = List.unmodifiable(blocks);
  final String id;
  final LocalDate date;
  final List<GeneratedSessionBlock> blocks;
  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.iso8601,
    'blocks': blocks.map((e) => e.toJson()).toList(),
  };
}

class GeneratedProgrammingWeek {
  GeneratedProgrammingWeek({
    required this.number,
    required List<GeneratedSession> sessions,
  }) : sessions = List.unmodifiable(sessions);
  final int number;
  final List<GeneratedSession> sessions;
  Map<String, Object?> toJson() => {
    'number': number,
    'sessions': sessions.map((e) => e.toJson()).toList(),
  };
}

class GeneratedCycle {
  GeneratedCycle({
    required this.number,
    required List<GeneratedProgrammingWeek> weeks,
  }) : weeks = List.unmodifiable(weeks);
  final int number;
  final List<GeneratedProgrammingWeek> weeks;
  Map<String, Object?> toJson() => {
    'number': number,
    'weeks': weeks.map((e) => e.toJson()).toList(),
  };
}

class GeneratedPlanBlock {
  GeneratedPlanBlock({
    required this.id,
    required this.role,
    required this.rule,
    required List<GeneratedCycle> cycles,
    this.seventhWeekPurpose,
  }) : cycles = List.unmodifiable(cycles);
  final String id;
  final BlockRole role;
  final SeventhWeekPurpose? seventhWeekPurpose;
  final RuleReference rule;
  final List<GeneratedCycle> cycles;
  Map<String, Object?> toJson() => {
    'id': id,
    'role': role.name,
    'seventhWeekPurpose': seventhWeekPurpose?.name,
    'rule': {'document': rule.document, 'location': rule.location},
    'cycles': cycles.map((e) => e.toJson()).toList(),
  };
}

class GeneratedTransition {
  const GeneratedTransition({
    required this.fromBlockId,
    required this.toBlockId,
    required this.rule,
  });
  final String fromBlockId;
  final String toBlockId;
  final RuleReference rule;
  Map<String, Object?> toJson() => {
    'fromBlockId': fromBlockId,
    'toBlockId': toBlockId,
    'rule': {'document': rule.document, 'location': rule.location},
  };
}

class PlannedTrainingEvent {
  const PlannedTrainingEvent({
    required this.kind,
    required this.afterBlockId,
    required this.rule,
    this.afterCycleNumber,
  });
  final PlannedEventKind kind;
  final String afterBlockId;
  final RuleReference rule;
  final int? afterCycleNumber;
  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'afterBlockId': afterBlockId,
    'afterCycleNumber': afterCycleNumber,
    'rule': {'document': rule.document, 'location': rule.location},
  };
}

class GeneratedTrainingPlan {
  GeneratedTrainingPlan({
    required this.schemaVersion,
    required this.blueprintId,
    required this.blueprintVersion,
    required this.blueprintSnapshot,
    required this.unit,
    required this.seed,
    required List<GeneratedPlanBlock> blocks,
    required List<GeneratedTransition> transitions,
    required List<PlannedTrainingEvent> events,
  }) : blocks = List.unmodifiable(blocks),
       transitions = List.unmodifiable(transitions),
       events = List.unmodifiable(events);

  final int schemaVersion;
  final ProgramBlueprintId blueprintId;
  final ProgramVersion blueprintVersion;
  final String blueprintSnapshot;
  final WeightUnit unit;
  final int seed;
  final List<GeneratedPlanBlock> blocks;
  final List<GeneratedTransition> transitions;
  final List<PlannedTrainingEvent> events;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'blueprintId': blueprintId.value,
    'blueprintVersion': blueprintVersion.value,
    'blueprintSnapshot': blueprintSnapshot,
    'unit': unit.name,
    'seed': seed,
    'blocks': blocks.map((e) => e.toJson()).toList(),
    'transitions': transitions.map((e) => e.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
  };
}
