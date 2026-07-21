import 'package:hybrid_training/features/cycle_generation/domain/cycle_contract.dart';
import 'package:hybrid_training/features/training_log/domain/training_snapshot.dart';

abstract interface class TrainingSnapshotRepository {
  Future<void> save(GeneratedCycle cycle);
  Future<StoredTrainingSnapshot> load(String cycleId);
  Future<void> recordSetResult(String setId, ActualSetResult result);
  Future<ActualSetResult> loadSetResult(String setId);
}
