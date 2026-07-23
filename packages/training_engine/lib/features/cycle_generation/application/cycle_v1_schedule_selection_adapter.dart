import '../domain/cycle_contract.dart';
import '../domain/cycle_v2_primitives.dart';

final class CycleV1ScheduleSelectionAdapter {
  const CycleV1ScheduleSelectionAdapter();

  CycleScheduleSelection adapt(CycleRequest request) => CycleScheduleSelection(
    trainingDays: List.unmodifiable(request.trainingDays),
    sessionOrder: List.unmodifiable(
      request.sessionOrder.map((id) => SessionId(id.value)),
    ),
  );
}
