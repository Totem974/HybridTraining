import 'cycle_contract.dart';

extension type const SessionId(String value) {}

extension type const ExerciseId(String value) {}

enum CycleScheduleMode { fixed, rotating, multiMovement }

final class ScheduleSessionTemplate {
  const ScheduleSessionTemplate({
    required this.id,
    required this.role,
    required this.movementIds,
  }) : assert(role != ''),
       assert(movementIds.length > 0);

  final SessionId id;
  final String role;
  final List<MovementId> movementIds;
}

final class ResolvedCycleSchedule {
  const ResolvedCycleSchedule({
    required this.id,
    required this.mode,
    required this.sessions,
    required this.allowedFrequencies,
  }) : assert(id != ''),
       assert(sessions.length > 0),
       assert(allowedFrequencies.length > 0);

  final String id;
  final CycleScheduleMode mode;
  final List<ScheduleSessionTemplate> sessions;
  final Set<int> allowedFrequencies;
}

final class CycleScheduleSelection {
  const CycleScheduleSelection({
    required this.trainingDays,
    required this.sessionOrder,
  }) : assert(trainingDays.length > 0),
       assert(sessionOrder.length > 0);

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
