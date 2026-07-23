import 'cycle_contract.dart';
import 'cycle_schedule_mode.dart';

extension type const SessionId(String value) {}

extension type const ExerciseId(String value) {}

final class ScheduleSessionTemplate {
  const ScheduleSessionTemplate({
    required this.id,
    required this.role,
    required this.movementIds,
  }) : assert(role != '');

  final SessionId id;
  final String role;
  final List<MovementId> movementIds;
}

final class FiniteScheduleSource {
  const FiniteScheduleSource({
    required this.definitionWeekNumber,
    required this.sessionId,
  }) : assert(definitionWeekNumber > 0);

  final int definitionWeekNumber;
  final SessionId sessionId;
}

final class FiniteScheduleSlot {
  const FiniteScheduleSlot({required this.sources});

  final List<FiniteScheduleSource> sources;
}

final class ResolvedCycleSchedule {
  const ResolvedCycleSchedule({
    required this.id,
    required this.mode,
    required this.sessions,
    required this.allowedFrequencies,
    this.finiteSlots = const [],
  }) : assert(id != '');

  final String id;
  final CycleScheduleMode mode;
  final List<ScheduleSessionTemplate> sessions;
  final Set<int> allowedFrequencies;
  final List<FiniteScheduleSlot> finiteSlots;
}

final class CycleScheduleSelection {
  const CycleScheduleSelection({
    required this.trainingDays,
    required this.sessionOrder,
  });

  final List<int> trainingDays;
  final List<SessionId> sessionOrder;
}

final class CycleOptionValues {
  const CycleOptionValues({
    this.global = const {},
    this.byMovement = const {},
    this.bySession = const {},
  });

  final Map<String, Object> global;
  final Map<MovementId, Map<String, Object>> byMovement;
  final Map<SessionId, Map<String, Object>> bySession;
}
