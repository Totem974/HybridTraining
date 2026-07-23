import '../../cycle_generation/domain/cycle_contract.dart';
import '../../cycle_generation/domain/cycle_schedule_mode.dart';
import '../../cycle_generation/domain/cycle_v2_primitives.dart';
import 'catalog_source_document_codec.dart';

final class CatalogScheduleDataResolver {
  const CatalogScheduleDataResolver();

  ResolvedCycleSchedule resolve(SourceSchedule source) {
    final sessionsPerWeek = source.sessionsPerWeek;
    if (sessionsPerWeek == null) {
      throw const FormatException(
        'sessionsPerWeek is required for scheduled compilation.',
      );
    }
    _validateCadence(source, sessionsPerWeek);
    return ResolvedCycleSchedule(
      id: source.reference.id,
      mode: source.type,
      sessions: List.unmodifiable([
        for (final session in source.sessions)
          ScheduleSessionTemplate(
            id: SessionId(session.id),
            role: session.role,
            movementIds: List.unmodifiable([
              for (final movementId in session.movementIds)
                MovementId(movementId),
            ]),
          ),
      ]),
      allowedFrequencies: Set.unmodifiable({sessionsPerWeek}),
    );
  }

  void _validateCadence(SourceSchedule source, int sessionsPerWeek) {
    if (sessionsPerWeek < 1 || sessionsPerWeek > 7) {
      throw const FormatException('sessionsPerWeek must be from 1 to 7.');
    }
    switch (source.type) {
      case CycleScheduleMode.fixed || CycleScheduleMode.multiMovement:
        if (sessionsPerWeek != source.sessions.length) {
          throw FormatException(
            'sessionsPerWeek must equal the session count for ${source.type.name} schedules.',
          );
        }
      case CycleScheduleMode.rotating:
        if (sessionsPerWeek > source.sessions.length) {
          throw const FormatException(
            'sessionsPerWeek cannot exceed the session count for rotating schedules.',
          );
        }
      case CycleScheduleMode.finite:
        break;
    }
  }
}
