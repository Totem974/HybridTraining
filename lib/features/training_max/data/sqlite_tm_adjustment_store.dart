import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/domain/versioned_training_plan.dart';
import 'package:hybrid_training/features/training_max/domain/tm_adjustment_decision.dart';
import 'package:sqflite/sqflite.dart';

class SqliteTmAdjustmentStore {
  const SqliteTmAdjustmentStore({required this.localDatabase});

  final LocalDatabase localDatabase;

  Future<void> apply({
    required String id,
    required String planId,
    required String athleteId,
    required String unit,
    required TmAdjustmentDecision decision,
    required DateTime effectiveAt,
  }) async {
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      final history = await tx.query(
        'training_max_history',
        where: 'athlete_id = ? AND exercise_id = ?',
        whereArgs: [athleteId, decision.movement.name],
      );
      if (history.isEmpty) {
        throw StateError('The Training Max changed after the preview.');
      }
      Map<String, Object?>? latest;
      DateTime? latestEffectiveAt;
      final seenInstants = <int>{};
      for (final entry in history) {
        final rawEffectiveAt = entry['effective_at'];
        final parsedEffectiveAt = rawEffectiveAt is String
            ? DateTime.tryParse(rawEffectiveAt)?.toUtc()
            : null;
        if (parsedEffectiveAt == null) {
          throw StateError(
            'The Training Max history contains an invalid date.',
          );
        }
        if (!seenInstants.add(parsedEffectiveAt.microsecondsSinceEpoch)) {
          throw StateError(
            'The Training Max history contains an ambiguous effective date.',
          );
        }
        if (latestEffectiveAt == null ||
            parsedEffectiveAt.isAfter(latestEffectiveAt)) {
          latest = entry;
          latestEffectiveAt = parsedEffectiveAt;
        }
      }
      if ((latest!['training_max']! as num).toDouble() !=
              decision.previousTrainingMax ||
          latest['unit'] != unit) {
        throw StateError('The Training Max changed after the preview.');
      }
      if (!effectiveAt.toUtc().isAfter(latestEffectiveAt!)) {
        throw StateError(
          'The Training Max adjustment must follow the latest history entry.',
        );
      }
      final activePlan = Sqflite.firstIntValue(
        await tx.rawQuery(
          "SELECT COUNT(*) FROM training_plans WHERE id = ? AND athlete_id = ? AND status = 'active'",
          [planId, athleteId],
        ),
      );
      if (activePlan != 1) throw StateError('The active plan changed.');
      final sequence =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT COALESCE(MAX(sequence), -1) + 1 FROM plan_events WHERE plan_id = ?',
              [planId],
            ),
          ) ??
          0;
      final at = effectiveAt.toUtc().toIso8601String();
      await tx.insert('training_max_history', {
        'id': id,
        'athlete_id': athleteId,
        'exercise_id': decision.movement.name,
        'one_rep_max': latest['one_rep_max'],
        'training_max': decision.nextTrainingMax,
        'unit': unit,
        'effective_at': at,
      });
      await tx.insert('plan_events', {
        'id': '$id-event',
        'plan_id': planId,
        'sequence': sequence,
        'event_type': 'tmAdjustment',
        'proposed_training_maxes_json': canonicalJson({
          decision.movement.name: decision.nextTrainingMax,
        }),
        'confirmed_training_maxes_json': canonicalJson({
          decision.movement.name: decision.nextTrainingMax,
        }),
        'rule_provenance_json': canonicalJson({
          'kind': decision.kind.name,
          'reason': decision.reason,
          'ruleId': decision.ruleId,
          'generation': decision.generation,
          'source': decision.source,
        }),
        'occurred_at': at,
      });
    });
  }
}
