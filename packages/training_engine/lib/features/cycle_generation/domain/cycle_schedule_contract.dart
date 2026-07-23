import 'cycle_contract.dart';
import 'cycle_v2_primitives.dart';

abstract interface class ScheduledCycleCompiler {
  GeneratedCycle compileScheduled({
    required ResolvedCycleDefinition definition,
    required ResolvedCycleSchedule schedule,
    required CycleScheduleSelection selection,
    required CycleRequest request,
  });
}
