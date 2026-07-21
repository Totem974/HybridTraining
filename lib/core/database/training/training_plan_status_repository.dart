import 'package:sqflite/sqflite.dart';

enum TrainingPlanStatus { draft, scheduled, active, completed, cancelled }

final class TrainingPlanTransitionException implements Exception {
  const TrainingPlanTransitionException(this.code);

  final String code;

  @override
  String toString() => 'TrainingPlanTransitionException($code)';
}

final class TrainingPlanStatusRepository {
  const TrainingPlanStatusRepository();

  Future<void> transition(
    Database database, {
    required String planId,
    required TrainingPlanStatus to,
  }) => database.transaction((transaction) async {
    final rows = await transaction.query(
      'plans',
      columns: const ['status'],
      where: 'id=?',
      whereArgs: [planId],
    );
    if (rows.length != 1) {
      throw const TrainingPlanTransitionException('plan.not_found');
    }
    final currentName = rows.single['status'];
    final current = TrainingPlanStatus.values
        .where((status) => status.name == currentName)
        .firstOrNull;
    if (current == null || !(_allowedTransitions[current] ?? {}).contains(to)) {
      throw const TrainingPlanTransitionException(
        'plan.invalid_status_transition',
      );
    }
    final updated = await transaction.update(
      'plans',
      {'status': to.name},
      where: 'id=? AND status=?',
      whereArgs: [planId, current.name],
    );
    if (updated != 1) {
      throw const TrainingPlanTransitionException(
        'plan.concurrent_status_transition',
      );
    }
  });
}

const _allowedTransitions = <TrainingPlanStatus, Set<TrainingPlanStatus>>{
  TrainingPlanStatus.draft: {
    TrainingPlanStatus.scheduled,
    TrainingPlanStatus.cancelled,
  },
  TrainingPlanStatus.scheduled: {
    TrainingPlanStatus.active,
    TrainingPlanStatus.cancelled,
  },
  TrainingPlanStatus.active: {
    TrainingPlanStatus.completed,
    TrainingPlanStatus.cancelled,
  },
};
