import 'package:hybrid_training/features/programs/domain/training_models.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/programs/domain/program_identity.dart';
import 'package:hybrid_training/features/programs/domain/training_schedule.dart';

class FoundationProfileInput {
  FoundationProfileInput({
    required this.displayName,
    required this.unit,
    required this.oneRepMaxes,
    required this.roundingIncrement,
    TrainingScheduleDefinition? schedule,
    DateTime? startDate,
    int? trainingDaysPerWeek,
    this.persistentPresetId = 'forever-original-fsl-v1',
    this.presetVersion = 1,
  }) : schedule =
           schedule ??
           _legacyCompatibleSchedule(
             startDate: startDate!,
             frequency: trainingDaysPerWeek!,
           );

  final String displayName;
  final WeightUnit unit;
  final Map<MainLift, double> oneRepMaxes;
  final double roundingIncrement;
  final TrainingScheduleDefinition schedule;
  DateTime get startDate => schedule.startsOn;
  int get trainingDaysPerWeek => schedule.frequency;
  final String persistentPresetId;
  final int presetVersion;
}

class StoredSet {
  const StoredSet({
    required this.id,
    required this.sequence,
    required this.kind,
    required this.load,
    required this.repetitions,
    required this.isPerformanceSet,
    required this.isComplete,
    this.completedRepetitions,
    this.result,
  });

  final String id;
  final int sequence;
  final SetKind kind;
  final double load;
  final int repetitions;
  final bool isPerformanceSet;
  final bool isComplete;
  final int? completedRepetitions;
  final SetResult? result;
}

enum SetResult { success, failure, skipped }

class StoredSession {
  const StoredSession({
    required this.id,
    required this.lift,
    required this.scheduledFor,
    required this.unit,
    required this.sets,
    required this.isComplete,
    required this.notes,
    this.startedAt,
    this.restUntil,
  });

  final String id;
  final MainLift lift;
  final DateTime scheduledFor;
  final WeightUnit unit;
  final List<StoredSet> sets;
  final bool isComplete;
  final String notes;
  final DateTime? startedAt;
  final DateTime? restUntil;

  bool get isStarted => startedAt != null;
}

class TrainingSnapshot {
  const TrainingSnapshot({
    required this.displayName,
    required this.nextSession,
    required this.history,
    required this.trainingMaxes,
    required this.activeProgram,
    this.activeCycle,
  });

  final String displayName;
  final StoredSession? nextSession;
  final List<StoredSession> history;
  final Map<MainLift, double> trainingMaxes;
  final ProgramDefinitionRef activeProgram;
  final ActiveCycleSummary? activeCycle;
}

TrainingScheduleDefinition _legacyCompatibleSchedule({
  required DateTime startDate,
  required int frequency,
}) {
  const order = [
    MainLift.deadlift,
    MainLift.squat,
    MainLift.benchPress,
    MainLift.overheadPress,
  ];
  final offsets = frequency == 4 ? const [0, 1, 3, 5] : const [0, 2, 4];
  final days = [
    for (final offset in offsets)
      TrainingWeekday.fromDate(startDate.add(Duration(days: offset))),
  ];
  return TrainingScheduleDefinition(
    startsOn: startDate,
    frequency: frequency,
    selectedWeekdays: days,
    liftOrder: order,
    mode: frequency == 4
        ? TrainingScheduleMode.fixedWeekdayAssignment
        : TrainingScheduleMode.rotatingAcrossSelectedDays,
    weekdayAssignments: frequency == 4
        ? [
            for (var index = 0; index < days.length; index++)
              TrainingDayAssignment(weekday: days[index], lift: order[index]),
          ]
        : const [],
  );
}

class ActiveCycleSummary {
  const ActiveCycleSummary({
    required this.startsOn,
    required this.firstSession,
    required this.lastSession,
    required this.frequency,
    required this.selectedWeekdays,
    required this.totalSessions,
    required this.completedSessions,
    required this.hasStructuredSchedule,
  });

  final DateTime startsOn;
  final DateTime firstSession;
  final DateTime lastSession;
  final int frequency;
  final List<TrainingWeekday> selectedWeekdays;
  final int totalSessions;
  final int completedSessions;
  final bool hasStructuredSchedule;

  int get calendarWeeks => lastSession.difference(firstSession).inDays ~/ 7 + 1;
}

abstract interface class TrainingStore {
  Future<void> initialize();

  Future<bool> hasProfile();

  Future<void> createFoundation(FoundationProfileInput input);

  Future<TrainingSnapshot> loadSnapshot();

  Future<void> completeSet(String setId, {required int repetitions});

  Future<void> startSession(String sessionId);

  Future<void> recordSet(
    String setId, {
    required int repetitions,
    required SetResult result,
  });

  Future<void> setRestUntil(String sessionId, DateTime? restUntil);

  Future<void> updateTrainingMaxes(Map<MainLift, double> trainingMaxes);

  Future<String> exportBackup();

  Future<ImportReport> importBackup(String source, {required bool dryRun});

  Future<void> deleteAllData();

  Future<void> finishSession(String sessionId);

  Future<void> updateSessionNotes(String sessionId, String notes);

  Future<void> close();
}
