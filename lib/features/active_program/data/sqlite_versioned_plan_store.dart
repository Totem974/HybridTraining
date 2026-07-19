import 'dart:convert';

import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/application/plan_repository.dart';
import 'package:hybrid_training/features/active_program/domain/versioned_training_plan.dart';
import 'package:sqflite/sqflite.dart';

class SqliteVersionedPlanStore implements PlanRepository {
  const SqliteVersionedPlanStore({required this.localDatabase});

  final LocalDatabase localDatabase;

  /// The complete aggregate must be generated and validated by the domain
  /// before this method starts its single write transaction.
  @override
  Future<void> createPlan(VersionedTrainingPlan plan) async {
    _validate(plan);
    final snapshotJson = canonicalJson(plan.blueprintSnapshot);
    final provenanceJson = canonicalJson(plan.ruleProvenance);
    final snapshotId = '${plan.blueprintId}-v${plan.blueprintVersion}';
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      await tx.insert(
        'program_definition_snapshots',
        {
          'id': snapshotId,
          'blueprint_id': plan.blueprintId,
          'blueprint_version': plan.blueprintVersion,
          'snapshot_json': snapshotJson,
          'rule_provenance_json': provenanceJson,
          'created_at': plan.createdAt.toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      final existing = await tx.query(
        'program_definition_snapshots',
        where: 'id = ?',
        whereArgs: [snapshotId],
        limit: 1,
      );
      if (existing.length != 1 ||
          existing.single['snapshot_json'] != snapshotJson ||
          existing.single['rule_provenance_json'] != provenanceJson) {
        throw StateError('A blueprint snapshot is immutable.');
      }
      await tx.insert('training_plans', {
        'id': plan.id,
        'athlete_id': plan.athleteId,
        'blueprint_id': plan.blueprintId,
        'blueprint_version': plan.blueprintVersion,
        'definition_snapshot_id': snapshotId,
        'macrocycle': plan.macrocycle,
        'status': 'active',
        'created_at': plan.createdAt.toUtc().toIso8601String(),
      });
      for (final block in plan.blocks) {
        await tx.insert('training_blocks', {
          'id': block.id,
          'plan_id': plan.id,
          'sequence': block.sequence,
          'role': block.role,
          'template_id': block.templateId,
          'status': block.sequence == 0 ? 'active' : 'planned',
          'started_at': block.sequence == 0
              ? plan.createdAt.toUtc().toIso8601String()
              : null,
        });
        for (final cycle in block.cycles) {
          await tx.insert('plan_training_cycles', {
            'id': cycle.id,
            'block_id': block.id,
            'sequence': cycle.sequence,
            'starts_on': _date(cycle.startsOn),
            'status': 'planned',
          });
          for (final session in cycle.sessions) {
            await tx.insert('plan_training_sessions', {
              'id': session.id,
              'cycle_id': cycle.id,
              'sequence': session.sequence,
              'scheduled_for': _date(session.scheduledFor),
              'status': 'planned',
            });
            for (final sessionBlock in session.blocks) {
              await tx.insert('session_blocks', {
                'id': sessionBlock.id,
                'session_id': session.id,
                'sequence': sessionBlock.sequence,
                'kind': sessionBlock.kind,
                'movement_id': sessionBlock.movementId,
                'rule_provenance_json': canonicalJson(
                  sessionBlock.ruleProvenance,
                ),
              });
              for (final set in sessionBlock.prescriptions) {
                await tx.insert('set_prescriptions', {
                  'id': set.id,
                  'session_block_id': sessionBlock.id,
                  'sequence': set.sequence,
                  'training_max': set.trainingMax,
                  'percentage': set.percentage,
                  'unrounded_load': set.unroundedLoad,
                  'rounding_increment': set.roundingIncrement,
                  'prescribed_load': set.prescribedLoad,
                  'prescribed_reps': set.prescribedReps,
                  'prescription_json': canonicalJson(set.details),
                  'rule_provenance_json': canonicalJson(set.ruleProvenance),
                });
              }
            }
          }
        }
      }
    });
  }

  Future<void> recordPerformance({
    required String id,
    required String prescriptionId,
    required String result,
    required int completedReps,
    double? actualLoad,
    String notes = '',
    required DateTime recordedAt,
  }) async {
    final database = await localDatabase.open();
    await database.insert('set_performances', {
      'id': id,
      'prescription_id': prescriptionId,
      'result': result,
      'completed_reps': completedReps,
      'actual_load': actualLoad,
      'notes': notes,
      'recorded_at': recordedAt.toUtc().toIso8601String(),
    });
  }

  Future<void> transitionBlock({
    required String eventId,
    required String planId,
    required String fromBlockId,
    required String toBlockId,
    required int eventSequence,
    required Map<String, double> proposedTrainingMaxes,
    required Map<String, double> confirmedTrainingMaxes,
    required Map<String, Object?> ruleProvenance,
    required DateTime occurredAt,
  }) async {
    if (proposedTrainingMaxes.keys
        .toSet()
        .difference(confirmedTrainingMaxes.keys.toSet())
        .isNotEmpty) {
      throw ArgumentError('Every proposed Training Max must be confirmed.');
    }
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      final completed = await tx.update(
        'training_blocks',
        {
          'status': 'complete',
          'completed_at': occurredAt.toUtc().toIso8601String(),
        },
        where: "id = ? AND plan_id = ? AND status = 'active'",
        whereArgs: [fromBlockId, planId],
      );
      final activated = await tx.update(
        'training_blocks',
        {
          'status': 'active',
          'started_at': occurredAt.toUtc().toIso8601String(),
        },
        where: "id = ? AND plan_id = ? AND status = 'planned'",
        whereArgs: [toBlockId, planId],
      );
      if (completed != 1 || activated != 1) {
        throw StateError('Block transition preconditions were not met.');
      }
      await tx.insert('plan_events', {
        'id': eventId,
        'plan_id': planId,
        'sequence': eventSequence,
        'event_type': 'blockTransition',
        'from_block_id': fromBlockId,
        'to_block_id': toBlockId,
        'proposed_training_maxes_json': canonicalJson(proposedTrainingMaxes),
        'confirmed_training_maxes_json': canonicalJson(confirmedTrainingMaxes),
        'rule_provenance_json': canonicalJson(ruleProvenance),
        'occurred_at': occurredAt.toUtc().toIso8601String(),
      });
    });
  }

  @override
  Future<Map<String, Object?>?> loadPlan(String planId) async {
    final database = await localDatabase.open();
    final plans = await database.rawQuery(
      '''SELECT p.*, s.snapshot_json, s.rule_provenance_json
         FROM training_plans p
         JOIN program_definition_snapshots s ON s.id = p.definition_snapshot_id
         WHERE p.id = ?''',
      [planId],
    );
    if (plans.isEmpty) return null;
    final result = Map<String, Object?>.from(plans.single);
    result['snapshot'] = jsonDecode(result.remove('snapshot_json')! as String);
    result['ruleProvenance'] = jsonDecode(
      result.remove('rule_provenance_json')! as String,
    );
    final blocks = await database.query(
      'training_blocks',
      where: 'plan_id = ?',
      whereArgs: [planId],
      orderBy: 'sequence',
    );
    result['blocks'] = <Map<String, Object?>>[
      for (final block in blocks)
        {
          ...block,
          'cycles': await _loadCycles(database, block['id']! as String),
        },
    ];
    return result;
  }

  Future<List<Map<String, Object?>>> _loadCycles(
    Database database,
    String blockId,
  ) async {
    final cycles = await database.query(
      'plan_training_cycles',
      where: 'block_id = ?',
      whereArgs: [blockId],
      orderBy: 'sequence',
    );
    return [
      for (final cycle in cycles)
        {
          ...cycle,
          'sessions': await _loadSessions(database, cycle['id']! as String),
        },
    ];
  }

  Future<List<Map<String, Object?>>> _loadSessions(
    Database database,
    String cycleId,
  ) async {
    final sessions = await database.query(
      'plan_training_sessions',
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
      orderBy: 'sequence',
    );
    return [
      for (final session in sessions)
        {
          ...session,
          'blocks': await _loadSessionBlocks(
            database,
            session['id']! as String,
          ),
        },
    ];
  }

  Future<List<Map<String, Object?>>> _loadSessionBlocks(
    Database database,
    String sessionId,
  ) async {
    final blocks = await database.query(
      'session_blocks',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sequence',
    );
    return [
      for (final block in blocks)
        {
          ...block,
          'ruleProvenance': jsonDecode(
            block['rule_provenance_json']! as String,
          ),
          'prescriptions': await _loadPrescriptions(
            database,
            block['id']! as String,
          ),
        }..remove('rule_provenance_json'),
    ];
  }

  Future<List<Map<String, Object?>>> _loadPrescriptions(
    Database database,
    String sessionBlockId,
  ) async {
    final rows = await database.rawQuery(
      '''SELECT p.*, f.id AS performance_id, f.result,
                f.completed_reps, f.actual_load, f.notes AS performance_notes,
                f.recorded_at
         FROM set_prescriptions p
         LEFT JOIN set_performances f ON f.prescription_id = p.id
         WHERE p.session_block_id = ?
         ORDER BY p.sequence''',
      [sessionBlockId],
    );
    return [
      for (final row in rows)
        {
            ...row,
            'details': jsonDecode(row['prescription_json']! as String),
            'ruleProvenance': jsonDecode(
              row['rule_provenance_json']! as String,
            ),
            if (row['performance_id'] != null)
              'performance': {
                'id': row['performance_id'],
                'result': row['result'],
                'completed_reps': row['completed_reps'],
                'actual_load': row['actual_load'],
                'notes': row['performance_notes'],
                'recorded_at': row['recorded_at'],
              },
          }
          ..remove('prescription_json')
          ..remove('rule_provenance_json')
          ..remove('performance_id')
          ..remove('result')
          ..remove('completed_reps')
          ..remove('actual_load')
          ..remove('performance_notes')
          ..remove('recorded_at'),
    ];
  }

  void _validate(VersionedTrainingPlan plan) {
    const roles = {'prep', 'leader', 'seventhWeek', 'anchor'};
    if (plan.blocks.any((block) => !roles.contains(block.role))) {
      throw ArgumentError('Unknown training block role.');
    }
    void unique(Iterable<int> values, String label) {
      final list = values.toList();
      if (list.toSet().length != list.length) {
        throw ArgumentError('Duplicate $label sequence.');
      }
    }

    unique(plan.blocks.map((item) => item.sequence), 'block');
    for (final block in plan.blocks) {
      unique(block.cycles.map((item) => item.sequence), 'cycle');
      for (final cycle in block.cycles) {
        unique(cycle.sessions.map((item) => item.sequence), 'session');
        for (final session in cycle.sessions) {
          unique(session.blocks.map((item) => item.sequence), 'session block');
          for (final sessionBlock in session.blocks) {
            unique(
              sessionBlock.prescriptions.map((item) => item.sequence),
              'prescription',
            );
          }
        }
      }
    }
  }

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);
}
