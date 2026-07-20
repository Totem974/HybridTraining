import 'dart:convert';

import 'package:hybrid_training/core/database/local_database.dart';
import 'package:hybrid_training/features/active_program/application/plan_repository.dart';
import 'package:hybrid_training/features/active_program/application/program_switch.dart';
import 'package:hybrid_training/features/active_program/domain/versioned_training_plan.dart';
import 'package:hybrid_training/features/programs/domain/v2/program_domain.dart';
import 'package:sqflite/sqflite.dart';

class SqliteVersionedPlanStore
    implements PlanRepository, ProgramSwitchRepository {
  const SqliteVersionedPlanStore({required this.localDatabase});

  final LocalDatabase localDatabase;

  /// The complete aggregate must be generated and validated by the domain
  /// before this method starts its single write transaction.
  @override
  Future<void> createPlan(VersionedTrainingPlan plan) async {
    _validate(plan);
    final database = await localDatabase.open();
    await database.transaction((tx) => _insertPlan(tx, plan));
  }

  @override
  Future<ProgramSwitchPreview> previewProgramSwitch(
    ProgramSwitchRequest request,
  ) async {
    _validateSwitchRequest(request);
    final database = await localDatabase.open();
    final current = await _activePlan(database, request.currentPlanId);
    await _validateCompatibility(database, current, request.nextPlan);
    final counts = await _sessionStatusCounts(database, request.currentPlanId);
    final activeIds = await _activeSessionIds(database, request.currentPlanId);
    return ProgramSwitchPreview(
      currentPlanId: request.currentPlanId,
      nextPlanId: request.nextPlan.id,
      currentBlueprintId: current['blueprint_id']! as String,
      nextBlueprintId: request.nextPlan.blueprintId,
      completedSessionsPreserved: counts['complete'] ?? 0,
      plannedSessionsCancelled: counts['planned'] ?? 0,
      activeSessionIds: List.unmodifiable(activeIds),
      nextStartDate: _firstSessionDate(request.nextPlan),
    );
  }

  @override
  Future<void> applyProgramSwitch(ProgramSwitchRequest request) async {
    _validateSwitchRequest(request);
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      final current = await _activePlan(tx, request.currentPlanId);
      await _validateCompatibility(tx, current, request.nextPlan);
      final activeIds = await _activeSessionIds(tx, request.currentPlanId);
      if (activeIds.isNotEmpty &&
          request.activeSessionDisposition == ActiveSessionDisposition.reject) {
        throw StateError('An active session requires an explicit decision.');
      }
      final occurredAt = request.nextPlan.createdAt.toUtc().toIso8601String();
      if (activeIds.isNotEmpty) {
        await tx.rawUpdate(
          '''UPDATE plan_training_sessions
             SET status = 'cancelled', completed_at = ?,
                 notes = CASE WHEN notes = '' THEN ? ELSE notes || '\n' || ? END,
                 rest_until = NULL
             WHERE id IN (${List.filled(activeIds.length, '?').join(',')})''',
          [occurredAt, request.reason, request.reason, ...activeIds],
        );
        await tx.rawUpdate(
          '''UPDATE workout_executions
             SET state = 'abandoned', rest_until = NULL, paused_from = NULL,
                 reversible_stack_json = '[]', updated_at = ?, ended_at = ?
             WHERE session_id IN (${List.filled(activeIds.length, '?').join(',')})
               AND state NOT IN ('completed','abandoned','skipped')''',
          [occurredAt, occurredAt, ...activeIds],
        );
      }
      await tx.rawUpdate(
        '''UPDATE plan_training_sessions SET status = 'cancelled', completed_at = ?
           WHERE status = 'planned' AND cycle_id IN (
             SELECT c.id FROM plan_training_cycles c
             JOIN training_blocks b ON b.id = c.block_id WHERE b.plan_id = ?
           )''',
        [occurredAt, request.currentPlanId],
      );
      final closed = await tx.update(
        'training_plans',
        {'status': 'cancelled', 'completed_at': occurredAt},
        where: "id = ? AND status = 'active'",
        whereArgs: [request.currentPlanId],
      );
      if (closed != 1) throw StateError('The current plan changed.');
      final eventSequence =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT COALESCE(MAX(sequence), -1) + 1 FROM plan_events WHERE plan_id = ?',
              [request.currentPlanId],
            ),
          ) ??
          0;
      await tx.insert('plan_events', {
        'id': '${request.currentPlanId}-program-switch-$eventSequence',
        'plan_id': request.currentPlanId,
        'sequence': eventSequence,
        'event_type': 'programSwitch',
        'rule_provenance_json': canonicalJson({
          'reason': request.reason,
          'nextPlanId': request.nextPlan.id,
          'nextBlueprintId': request.nextPlan.blueprintId,
          'activeSessionDisposition': request.activeSessionDisposition.name,
        }),
        'occurred_at': occurredAt,
      });
      await _insertPlan(tx, request.nextPlan);
    });
  }

  @override
  Future<ForeverFutureAmendmentPreview> previewForeverFutureAmendment(
    ForeverFutureAmendmentRequest request,
  ) async {
    _validateFutureAmendment(request);
    final database = await localDatabase.open();
    return database.transaction((tx) async {
      final current = await _activePlan(tx, request.currentPlanId);
      await _validateCompatibility(tx, current, request.futurePlan);
      final sessions = await tx.rawQuery(
        '''SELECT s.id, s.status FROM plan_training_sessions s
           JOIN plan_training_cycles c ON c.id = s.cycle_id
           JOIN training_blocks b ON b.id = c.block_id
           WHERE b.plan_id = ? ORDER BY s.scheduled_for, s.id''',
        [request.currentPlanId],
      );
      final preserved = sessions
          .where((row) => row['status'] != 'planned')
          .map((row) => row['id']! as String)
          .toList(growable: false);
      final replaced = sessions
          .where((row) => row['status'] == 'planned')
          .map((row) => row['id']! as String)
          .toList(growable: false);
      final addedSessions = request.futurePlan.blocks
          .expand((block) => block.cycles)
          .expand((cycle) => cycle.sessions)
          .map((session) => session.id)
          .toList(growable: false);
      final version =
          Sqflite.firstIntValue(
            await tx.rawQuery(
              'SELECT COALESCE(MAX(version), 0) + 1 FROM plan_amendments WHERE plan_id = ?',
              [request.currentPlanId],
            ),
          ) ??
          1;
      final previewId = '${request.currentPlanId}:future-amendment:$version';
      final after = _futureAmendmentSignature(request);
      final before = await _persistedFutureSignature(tx, request.currentPlanId);
      final diff = {
        'preservedSessionIds': preserved,
        'replacedPlannedSessionIds': replaced,
        'addedPlannedSessionIds': addedSessions,
        'addedBlockIds': request.futurePlan.blocks
            .map((block) => block.id)
            .toList(),
      };
      await tx.insert('plan_amendments', {
        'id': previewId,
        'plan_id': request.currentPlanId,
        'version': version,
        'state': 'previewed',
        'reason': request.reason.trim(),
        'rule_id': request.ruleId.trim(),
        'before_snapshot_json': canonicalJson(before),
        'after_snapshot_json': canonicalJson(after),
        'diff_json': canonicalJson(diff),
        'created_at': request.futurePlan.createdAt.toUtc().toIso8601String(),
      });
      return ForeverFutureAmendmentPreview(
        previewId: previewId,
        currentPlanId: request.currentPlanId,
        preservedSessionIds: List.unmodifiable(preserved),
        replacedPlannedSessionIds: List.unmodifiable(replaced),
        addedPlannedSessionIds: List.unmodifiable(addedSessions),
        addedBlockIds: List.unmodifiable(
          request.futurePlan.blocks.map((block) => block.id),
        ),
      );
    });
  }

  @override
  Future<void> applyForeverFutureAmendment(
    ForeverFutureAmendmentRequest request, {
    required String previewId,
    required bool confirmed,
  }) async {
    _validateFutureAmendment(request);
    if (!confirmed) {
      throw StateError('A future amendment requires explicit confirmation.');
    }
    final database = await localDatabase.open();
    await database.transaction((tx) async {
      final current = await _activePlan(tx, request.currentPlanId);
      await _validateCompatibility(tx, current, request.futurePlan);
      final previews = await tx.query(
        'plan_amendments',
        where: "id = ? AND plan_id = ? AND state = 'previewed'",
        whereArgs: [previewId, request.currentPlanId],
        limit: 1,
      );
      if (previews.length != 1 ||
          previews.single['after_snapshot_json'] !=
              canonicalJson(_futureAmendmentSignature(request))) {
        throw StateError('A matching unapplied preview is required.');
      }
      final persistedFuture = await _persistedFutureSignature(
        tx,
        request.currentPlanId,
      );
      if (previews.single['before_snapshot_json'] !=
          canonicalJson(persistedFuture)) {
        throw StateError(
          'The planned future changed after the amendment preview.',
        );
      }

      // Cascades remove prescriptions only below planned sessions. Closed and
      // active rows are deliberately outside every deletion predicate.
      await tx.rawDelete(
        '''DELETE FROM plan_training_sessions WHERE status = 'planned'
           AND cycle_id IN (SELECT c.id FROM plan_training_cycles c
             JOIN training_blocks b ON b.id = c.block_id WHERE b.plan_id = ?)''',
        [request.currentPlanId],
      );
      await tx.rawDelete(
        '''DELETE FROM plan_training_cycles WHERE status = 'planned'
           AND block_id IN (SELECT id FROM training_blocks WHERE plan_id = ?)
           AND NOT EXISTS (SELECT 1 FROM plan_training_sessions s
             WHERE s.cycle_id = plan_training_cycles.id)''',
        [request.currentPlanId],
      );
      await tx.rawDelete(
        '''DELETE FROM training_blocks WHERE plan_id = ? AND status = 'planned'
           AND NOT EXISTS (SELECT 1 FROM plan_training_cycles c
             WHERE c.block_id = training_blocks.id)''',
        [request.currentPlanId],
      );
      await _insertFuture(tx, request.currentPlanId, request.futurePlan);
      await _replacePlanDefinition(
        tx,
        request.currentPlanId,
        request.futurePlan,
        previewId: previewId,
      );
      final updated = await tx.update(
        'plan_amendments',
        {
          'state': 'applied',
          'applied_at': request.futurePlan.createdAt.toUtc().toIso8601String(),
        },
        where: "id = ? AND state = 'previewed'",
        whereArgs: [previewId],
      );
      if (updated != 1) throw StateError('The amendment preview changed.');
    });
  }

  Future<void> _replacePlanDefinition(
    DatabaseExecutor tx,
    String planId,
    VersionedTrainingPlan future, {
    required String previewId,
  }) async {
    final snapshotId = '$planId-definition-$previewId';
    await tx.insert('program_definition_snapshots', {
      'id': snapshotId,
      'blueprint_id': future.blueprintId,
      'blueprint_version': future.blueprintVersion,
      'snapshot_json': canonicalJson(future.blueprintSnapshot),
      'rule_provenance_json': canonicalJson(future.ruleProvenance),
      'created_at': future.createdAt.toUtc().toIso8601String(),
    });
    final updated = await tx.update(
      'training_plans',
      {
        'blueprint_id': future.blueprintId,
        'blueprint_version': future.blueprintVersion,
        'definition_snapshot_id': snapshotId,
        'macrocycle': future.macrocycle,
        'source_edition': future.sourceEdition?.name,
        'ruleset_generation': future.generation?.name,
      },
      where: "id = ? AND status = 'active'",
      whereArgs: [planId],
    );
    if (updated != 1) throw StateError('The current plan changed.');
  }

  Future<void> _insertFuture(
    DatabaseExecutor tx,
    String planId,
    VersionedTrainingPlan future,
  ) async {
    final nextBlockSequence =
        Sqflite.firstIntValue(
          await tx.rawQuery(
            'SELECT COALESCE(MAX(sequence), -1) + 1 FROM training_blocks WHERE plan_id = ?',
            [planId],
          ),
        ) ??
        0;
    for (final blockEntry in future.blocks.indexed) {
      final block = blockEntry.$2;
      await tx.insert('training_blocks', {
        'id': block.id,
        'plan_id': planId,
        'sequence': nextBlockSequence + blockEntry.$1,
        'role': _legacyRole(block.role),
        'block_type': block.type,
        'ruleset_role': block.role,
        'seventh_week_purpose': block.seventhWeekPurpose,
        'programming_block_number': nextBlockSequence + blockEntry.$1 + 1,
        'template_id': block.templateId,
        'status': 'planned',
      });
      await _insertFutureCycles(tx, block);
    }
  }

  Future<void> _insertFutureCycles(
    DatabaseExecutor tx,
    PlannedTrainingBlock block,
  ) async {
    for (final cycle in block.cycles) {
      await tx.insert('plan_training_cycles', {
        'id': cycle.id,
        'block_id': block.id,
        'sequence': cycle.sequence,
        'starts_on': _date(cycle.startsOn),
        'status': 'planned',
        'programming_cycle_number': cycle.programmingCycleNumber,
      });
      for (final session in cycle.sessions) {
        await tx.insert('plan_training_sessions', {
          'id': session.id,
          'cycle_id': cycle.id,
          'sequence': session.sequence,
          'scheduled_for': _date(session.scheduledFor),
          'status': 'planned',
          'programming_week_number': session.programmingWeekNumber,
          'session_position': session.position,
        });
        for (final sessionBlock in session.blocks) {
          await tx.insert('session_blocks', {
            'id': sessionBlock.id,
            'session_id': session.id,
            'sequence': sessionBlock.sequence,
            'kind': sessionBlock.kind,
            'movement_id': sessionBlock.movementId,
            'rule_provenance_json': canonicalJson(sessionBlock.ruleProvenance),
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
          for (final activity in sessionBlock.activities) {
            await tx.insert('activity_prescriptions', {
              'id': activity.id,
              'session_block_id': sessionBlock.id,
              'sequence': activity.sequence,
              'movement_or_activity_id': activity.movementOrActivityId,
              'target_type': _targetType(activity.targetType),
              'target_json': canonicalJson(activity.target),
              'prescription_kind': activity.kind,
              'rule_id': activity.ruleId,
              'source_edition': activity.sourceEdition,
              'ruleset_generation': activity.generation,
              'source_reference_json': canonicalJson(activity.source),
              'calculated_load': activity.calculatedLoad,
              'unrounded_load': activity.unroundedLoad,
              'rounding_increment': activity.roundingIncrement,
            });
          }
        }
      }
    }
  }

  Future<void> _insertPlan(
    DatabaseExecutor tx,
    VersionedTrainingPlan plan,
  ) async {
    final snapshotJson = canonicalJson(plan.blueprintSnapshot);
    final provenanceJson = canonicalJson(plan.ruleProvenance);
    final snapshotId = '${plan.id}-definition';
    await tx.insert('program_definition_snapshots', {
      'id': snapshotId,
      'blueprint_id': plan.blueprintId,
      'blueprint_version': plan.blueprintVersion,
      'snapshot_json': snapshotJson,
      'rule_provenance_json': provenanceJson,
      'created_at': plan.createdAt.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
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
      'source_edition': plan.sourceEdition?.name,
      'ruleset_generation': plan.generation?.name,
    });
    for (final block in plan.blocks) {
      await tx.insert('training_blocks', {
        'id': block.id,
        'plan_id': plan.id,
        'sequence': block.sequence,
        'role': _legacyRole(block.role),
        'block_type': block.type,
        'ruleset_role': block.role,
        'seventh_week_purpose': block.seventhWeekPurpose,
        'programming_block_number': block.sequence + 1,
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
          'programming_cycle_number': cycle.programmingCycleNumber,
        });
        for (final session in cycle.sessions) {
          await tx.insert('plan_training_sessions', {
            'id': session.id,
            'cycle_id': cycle.id,
            'sequence': session.sequence,
            'scheduled_for': _date(session.scheduledFor),
            'status': 'planned',
            'programming_week_number': session.programmingWeekNumber,
            'session_position': session.position,
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
            for (final activity in sessionBlock.activities) {
              await tx.insert('activity_prescriptions', {
                'id': activity.id,
                'session_block_id': sessionBlock.id,
                'sequence': activity.sequence,
                'movement_or_activity_id': activity.movementOrActivityId,
                'target_type': _targetType(activity.targetType),
                'target_json': canonicalJson(activity.target),
                'prescription_kind': activity.kind,
                'rule_id': activity.ruleId,
                'source_edition': activity.sourceEdition,
                'ruleset_generation': activity.generation,
                'source_reference_json': canonicalJson(activity.source),
                'calculated_load': activity.calculatedLoad,
                'unrounded_load': activity.unroundedLoad,
                'rounding_increment': activity.roundingIncrement,
              });
            }
          }
        }
      }
    }
    for (final decision in plan.trainingMaxTimeline) {
      await tx.insert('training_max_timeline', {
        'id': '${plan.id}-${decision['id']}',
        'plan_id': plan.id,
        'sequence': decision['sequence'],
        'movement_id': decision['movementId'],
        'checkpoint_type': 'cycleProgression',
        'state': decision['state'],
        'previous_training_max': decision['previousTrainingMax'],
        'proposed_training_max': decision['proposedTrainingMax'],
        'confirmed_training_max': decision['confirmedTrainingMax'],
        'reason': decision['reason'],
        'rule_id': 'TM-${decision['afterProgrammingWeek']}',
        'source_reference_json': canonicalJson(decision['source']),
        'created_at': plan.createdAt.toUtc().toIso8601String(),
      });
    }
    for (final event in plan.plannedEvents) {
      await tx.insert('planned_events_v5', {
        'id': event['id'],
        'plan_id': plan.id,
        'sequence': event['sequence'],
        'event_type': event['eventType'],
        'programming_week_number': event['programmingWeekNumber'],
        'payload_json': canonicalJson(event['payload']),
        'rule_id': event['ruleId'],
        'source_reference_json': canonicalJson(event['source']),
      });
    }
    for (final transition in plan.transitions) {
      await tx.insert('plan_transitions_v5', {
        'id': transition['id'],
        'plan_id': plan.id,
        'sequence': transition['sequence'],
        'from_block_id': transition['fromBlockId'],
        'to_block_id': transition['toBlockId'],
        'transition_type': transition['transitionType'],
        'rule_id': transition['ruleId'],
        'source_reference_json': canonicalJson(transition['source']),
      });
    }
  }

  void _validateSwitchRequest(ProgramSwitchRequest request) {
    _validate(request.nextPlan);
    if (request.currentPlanId.trim().isEmpty ||
        request.reason.trim().isEmpty ||
        request.nextPlan.id == request.currentPlanId) {
      throw ArgumentError(
        'A program switch requires distinct plans and a reason.',
      );
    }
    _firstSessionDate(request.nextPlan);
  }

  Future<Map<String, Object?>> _activePlan(
    DatabaseExecutor database,
    String id,
  ) async {
    final rows = await database.query(
      'training_plans',
      where: "id = ? AND status = 'active'",
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Active plan not found: $id');
    return rows.single;
  }

  Future<void> _validateCompatibility(
    DatabaseExecutor database,
    Map<String, Object?> current,
    VersionedTrainingPlan next,
  ) async {
    if (current['athlete_id'] != next.athleteId) {
      throw StateError('A program switch cannot change the athlete.');
    }
    final profiles = await database.query(
      'athlete_profiles',
      columns: ['preferred_unit'],
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [next.athleteId],
      limit: 1,
    );
    if (profiles.isEmpty) {
      throw StateError('The athlete profile is unavailable.');
    }
    final unit = profiles.single['preferred_unit']! as String;
    final sessionBlocks = next.blocks
        .expand((block) => block.cycles)
        .expand((cycle) => cycle.sessions)
        .expand((session) => session.blocks);
    final movements = <String>{
      ...sessionBlocks.map((block) => block.movementId).whereType<String>(),
      ...sessionBlocks
          .expand((block) => block.activities)
          .where((activity) => activity.targetType == 'setsRepetitionsLoad')
          .map((activity) => activity.movementOrActivityId),
    };
    if (movements.isEmpty) {
      throw StateError('The replacement plan has no compatible movement.');
    }
    for (final movement in movements) {
      final legacyMovement = switch (movement) {
        'barbell.back-squat' => 'squat',
        'barbell.bench-press' => 'benchPress',
        'barbell.deadlift' => 'deadlift',
        'barbell.overhead-press' => 'overheadPress',
        _ => movement,
      };
      final history = await database.rawQuery(
        '''SELECT unit FROM training_max_history
           WHERE athlete_id = ? AND exercise_id IN (?, ?)
           ORDER BY effective_at DESC LIMIT 1''',
        [next.athleteId, movement, legacyMovement],
      );
      if (history.isEmpty || history.single['unit'] != unit) {
        throw StateError(
          'A compatible $unit Training Max is required for $movement.',
        );
      }
    }
  }

  Future<Map<String, int>> _sessionStatusCounts(
    DatabaseExecutor database,
    String planId,
  ) async {
    final rows = await database.rawQuery(
      '''SELECT s.status, COUNT(*) AS count FROM plan_training_sessions s
         JOIN plan_training_cycles c ON c.id = s.cycle_id
         JOIN training_blocks b ON b.id = c.block_id
         WHERE b.plan_id = ? GROUP BY s.status''',
      [planId],
    );
    return {
      for (final row in rows) row['status']! as String: row['count']! as int,
    };
  }

  Future<List<String>> _activeSessionIds(
    DatabaseExecutor database,
    String planId,
  ) async => (await database.rawQuery(
    '''SELECT s.id FROM plan_training_sessions s
           JOIN plan_training_cycles c ON c.id = s.cycle_id
           JOIN training_blocks b ON b.id = c.block_id
           WHERE b.plan_id = ? AND s.status = 'started' ORDER BY s.id''',
    [planId],
  )).map((row) => row['id']! as String).toList(growable: false);

  DateTime _firstSessionDate(VersionedTrainingPlan plan) {
    final sessions = plan.blocks
        .expand((block) => block.cycles)
        .expand((cycle) => cycle.sessions)
        .toList(growable: false);
    if (sessions.isEmpty) {
      throw ArgumentError('The replacement plan requires a scheduled session.');
    }
    sessions.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return sessions.first.scheduledFor;
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
    result['trainingMaxTimeline'] = [
      for (final row in await database.query(
        'training_max_timeline',
        where: 'plan_id = ?',
        whereArgs: [planId],
        orderBy: 'sequence, movement_id',
      ))
        {...row, 'source': jsonDecode(row['source_reference_json']! as String)}
          ..remove('source_reference_json'),
    ];
    result['plannedEvents'] = [
      for (final row in await database.query(
        'planned_events_v5',
        where: 'plan_id = ?',
        whereArgs: [planId],
        orderBy: 'sequence',
      ))
        {
            ...row,
            'payload': jsonDecode(row['payload_json']! as String),
            'source': jsonDecode(row['source_reference_json']! as String),
          }
          ..remove('payload_json')
          ..remove('source_reference_json'),
    ];
    result['transitions'] = [
      for (final row in await database.query(
        'plan_transitions_v5',
        where: 'plan_id = ?',
        whereArgs: [planId],
        orderBy: 'sequence',
      ))
        {...row, 'source': jsonDecode(row['source_reference_json']! as String)}
          ..remove('source_reference_json'),
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
          'activities': await _loadActivities(database, block['id']! as String),
        }..remove('rule_provenance_json'),
    ];
  }

  Future<List<Map<String, Object?>>> _loadActivities(
    Database database,
    String sessionBlockId,
  ) async {
    final rows = await database.rawQuery(
      '''SELECT p.*, r.actual_json, r.status AS result_status, r.rpe,
                r.notes AS result_notes, r.recorded_at, r.updated_at
         FROM activity_prescriptions p
         LEFT JOIN activity_results r ON r.prescription_id = p.id
         WHERE p.session_block_id = ?
         ORDER BY p.sequence''',
      [sessionBlockId],
    );
    return [
      for (final row in rows)
        {
            ...row,
            'target': jsonDecode(row['target_json']! as String),
            'source': jsonDecode(row['source_reference_json']! as String),
            if (row['actual_json'] != null)
              'result': {
                'status': row['result_status'],
                'actual': jsonDecode(row['actual_json']! as String),
                'rpe': row['rpe'],
                'notes': row['result_notes'],
                'recorded_at': row['recorded_at'],
                'updated_at': row['updated_at'],
              },
          }
          ..remove('target_json')
          ..remove('source_reference_json')
          ..remove('actual_json')
          ..remove('result_status')
          ..remove('rpe')
          ..remove('result_notes')
          ..remove('recorded_at')
          ..remove('updated_at'),
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

  void _validateFutureAmendment(ForeverFutureAmendmentRequest request) {
    _validate(request.futurePlan);
    if (request.currentPlanId.trim().isEmpty ||
        request.reason.trim().isEmpty ||
        request.ruleId.trim().isEmpty) {
      throw ArgumentError('A sourced future amendment is required.');
    }
    _firstSessionDate(request.futurePlan);
  }

  Future<Map<String, Object?>> _persistedFutureSignature(
    DatabaseExecutor tx,
    String planId,
  ) async {
    Future<List<Map<String, Object?>>> rows(String sql) async =>
        tx.rawQuery(sql, [planId]);

    return {
      'planDefinition': await rows('''SELECT p.blueprint_id,
             p.blueprint_version, p.definition_snapshot_id, p.macrocycle,
             d.snapshot_json, d.rule_provenance_json
           FROM training_plans p
           JOIN program_definition_snapshots d
             ON d.id = p.definition_snapshot_id
           WHERE p.id = ?'''),
      'blocks': await rows('''SELECT b.* FROM training_blocks b
           WHERE b.plan_id = ? AND b.status = 'planned'
           ORDER BY b.sequence, b.id'''),
      'cycles': await rows('''SELECT c.* FROM plan_training_cycles c
           JOIN training_blocks b ON b.id = c.block_id
           WHERE b.plan_id = ? AND c.status = 'planned'
           ORDER BY b.sequence, c.sequence, c.id'''),
      'sessions': await rows('''SELECT s.* FROM plan_training_sessions s
           JOIN plan_training_cycles c ON c.id = s.cycle_id
           JOIN training_blocks b ON b.id = c.block_id
           WHERE b.plan_id = ? AND s.status = 'planned'
           ORDER BY b.sequence, c.sequence, s.sequence, s.id'''),
      'sessionBlocks': await rows('''SELECT sb.* FROM session_blocks sb
           JOIN plan_training_sessions s ON s.id = sb.session_id
           JOIN plan_training_cycles c ON c.id = s.cycle_id
           JOIN training_blocks b ON b.id = c.block_id
           WHERE b.plan_id = ? AND s.status = 'planned'
           ORDER BY b.sequence, c.sequence, s.sequence, sb.sequence, sb.id'''),
      'setPrescriptions': await rows('''SELECT p.* FROM set_prescriptions p
           JOIN session_blocks sb ON sb.id = p.session_block_id
           JOIN plan_training_sessions s ON s.id = sb.session_id
           JOIN plan_training_cycles c ON c.id = s.cycle_id
           JOIN training_blocks b ON b.id = c.block_id
           WHERE b.plan_id = ? AND s.status = 'planned'
           ORDER BY b.sequence, c.sequence, s.sequence, sb.sequence,
                    p.sequence, p.id'''),
      'activityPrescriptions': await rows(
        '''SELECT p.* FROM activity_prescriptions p
           JOIN session_blocks sb ON sb.id = p.session_block_id
           JOIN plan_training_sessions s ON s.id = sb.session_id
           JOIN plan_training_cycles c ON c.id = s.cycle_id
           JOIN training_blocks b ON b.id = c.block_id
           WHERE b.plan_id = ? AND s.status = 'planned'
           ORDER BY b.sequence, c.sequence, s.sequence, sb.sequence,
                    p.sequence, p.id''',
      ),
    };
  }

  Map<String, Object?> _futureAmendmentSignature(
    ForeverFutureAmendmentRequest request,
  ) => {
    'futurePlanId': request.futurePlan.id,
    'athleteId': request.futurePlan.athleteId,
    'blueprintId': request.futurePlan.blueprintId,
    'blueprintVersion': request.futurePlan.blueprintVersion,
    'macrocycle': request.futurePlan.macrocycle,
    'reason': request.reason.trim(),
    'ruleId': request.ruleId.trim(),
    'blocks': [
      for (final block in request.futurePlan.blocks)
        {
          'id': block.id,
          'sequence': block.sequence,
          'role': block.role,
          'type': block.type,
          'templateId': block.templateId,
          'seventhWeekPurpose': block.seventhWeekPurpose,
          'cycles': [
            for (final cycle in block.cycles)
              {
                'id': cycle.id,
                'sequence': cycle.sequence,
                'startsOn': _date(cycle.startsOn),
                'programmingCycleNumber': cycle.programmingCycleNumber,
                'sessions': [
                  for (final session in cycle.sessions)
                    {
                      'id': session.id,
                      'sequence': session.sequence,
                      'scheduledFor': _date(session.scheduledFor),
                      'programmingWeekNumber': session.programmingWeekNumber,
                      'position': session.position,
                      'blocks': [
                        for (final sessionBlock in session.blocks)
                          {
                            'id': sessionBlock.id,
                            'sequence': sessionBlock.sequence,
                            'kind': sessionBlock.kind,
                            'movementId': sessionBlock.movementId,
                            'ruleProvenance': sessionBlock.ruleProvenance,
                            'prescriptions': [
                              for (final set in sessionBlock.prescriptions)
                                {
                                  'id': set.id,
                                  'sequence': set.sequence,
                                  'trainingMax': set.trainingMax,
                                  'percentage': set.percentage,
                                  'unroundedLoad': set.unroundedLoad,
                                  'roundingIncrement': set.roundingIncrement,
                                  'prescribedLoad': set.prescribedLoad,
                                  'prescribedReps': set.prescribedReps,
                                  'details': set.details,
                                  'ruleProvenance': set.ruleProvenance,
                                },
                            ],
                            'activities': [
                              for (final activity in sessionBlock.activities)
                                {
                                  'id': activity.id,
                                  'sequence': activity.sequence,
                                  'movementOrActivityId':
                                      activity.movementOrActivityId,
                                  'targetType': activity.targetType,
                                  'target': activity.target,
                                  'kind': activity.kind,
                                  'ruleId': activity.ruleId,
                                  'sourceEdition': activity.sourceEdition,
                                  'generation': activity.generation,
                                  'source': activity.source,
                                  'calculatedLoad': activity.calculatedLoad,
                                  'unroundedLoad': activity.unroundedLoad,
                                  'roundingIncrement':
                                      activity.roundingIncrement,
                                  'percentage': activity.percentage,
                                },
                            ],
                          },
                      ],
                    },
                ],
              },
          ],
        },
    ],
  };

  void _validate(VersionedTrainingPlan plan) {
    final roles = BlockRole.values.map((role) => role.name).toSet();
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

  String _legacyRole(String role) => switch (role) {
    'leader' || 'anchor' || 'seventhWeek' || 'prep' => role,
    _ => 'prep',
  };

  String _targetType(String value) =>
      value == 'setsRepetitionsLoad' ? 'setsRepsLoad' : value;
}
