import '../domain/training_statistics.dart';

abstract interface class TrainingStatisticsRepository {
  Future<TrainingStatistics> load({
    StatisticsScope scope = const StatisticsScope(),
  });
}
