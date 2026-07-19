import 'dart:convert';

import 'package:sqflite/sqflite.dart';

abstract final class DatabaseSchema {
  static const version = 5;

  static Future<void> createV1(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE athlete_profiles (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        preferred_unit TEXT NOT NULL CHECK(preferred_unit IN ('kg', 'lb')),
        rounding_increment REAL NOT NULL CHECK(rounding_increment > 0),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        name_key TEXT NOT NULL,
        category TEXT NOT NULL,
        is_main_lift INTEGER NOT NULL CHECK(is_main_lift IN (0, 1)),
        created_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');
    await database.execute('''
      CREATE TABLE training_max_history (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        one_rep_max REAL NOT NULL CHECK(one_rep_max > 0),
        training_max REAL NOT NULL CHECK(training_max > 0),
        unit TEXT NOT NULL CHECK(unit IN ('kg', 'lb')),
        effective_at TEXT NOT NULL,
        FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id),
        FOREIGN KEY(exercise_id) REFERENCES exercises(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE gyms (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        name TEXT NOT NULL,
        is_default INTEGER NOT NULL CHECK(is_default IN (0, 1)),
        created_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE gym_bars (
        id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        name TEXT NOT NULL,
        weight REAL NOT NULL CHECK(weight > 0),
        unit TEXT NOT NULL CHECK(unit IN ('kg', 'lb')),
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        deleted_at TEXT,
        FOREIGN KEY(gym_id) REFERENCES gyms(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE gym_plates (
        id TEXT PRIMARY KEY,
        gym_id TEXT NOT NULL,
        weight REAL NOT NULL CHECK(weight > 0),
        unit TEXT NOT NULL CHECK(unit IN ('kg', 'lb')),
        quantity INTEGER NOT NULL CHECK(quantity >= 0),
        deleted_at TEXT,
        FOREIGN KEY(gym_id) REFERENCES gyms(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE program_definitions (
        id TEXT PRIMARY KEY,
        schema_version INTEGER NOT NULL,
        name_key TEXT NOT NULL,
        definition_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE training_cycles (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        program_definition_id TEXT NOT NULL,
        program_definition_version INTEGER NOT NULL,
        starts_on TEXT NOT NULL,
        status TEXT NOT NULL,
        settings_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        deleted_at TEXT,
        FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id),
        FOREIGN KEY(program_definition_id)
          REFERENCES program_definitions(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE training_sessions (
        id TEXT PRIMARY KEY,
        cycle_id TEXT NOT NULL,
        scheduled_for TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        status TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(cycle_id) REFERENCES training_cycles(id) ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE training_sets (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        lift_id TEXT NOT NULL,
        sequence INTEGER NOT NULL,
        kind TEXT NOT NULL,
        training_max REAL NOT NULL,
        percentage REAL NOT NULL,
        unrounded_load REAL NOT NULL,
        rounding_increment REAL NOT NULL,
        prescribed_load REAL NOT NULL,
        prescribed_reps INTEGER NOT NULL,
        performance_set INTEGER NOT NULL CHECK(performance_set IN (0, 1)),
        result TEXT,
        completed_reps INTEGER,
        notes TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(session_id) REFERENCES training_sessions(id) ON DELETE CASCADE,
        UNIQUE(session_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE TABLE personal_records (
        id TEXT PRIMARY KEY,
        lift_id TEXT NOT NULL,
        load REAL NOT NULL,
        repetitions INTEGER NOT NULL,
        unit TEXT NOT NULL,
        achieved_at TEXT NOT NULL,
        source_set_id TEXT,
        FOREIGN KEY(source_set_id) REFERENCES training_sets(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE import_runs (
        id TEXT PRIMARY KEY,
        source_format TEXT NOT NULL,
        source_schema_version INTEGER,
        source_digest TEXT NOT NULL,
        dry_run INTEGER NOT NULL CHECK(dry_run IN (0, 1)),
        status TEXT NOT NULL,
        report_json TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE INDEX training_sessions_cycle_idx '
      'ON training_sessions(cycle_id, scheduled_for)',
    );
    await database.execute(
      'CREATE INDEX training_sets_session_idx '
      'ON training_sets(session_id, sequence)',
    );
  }

  static Future<void> migrate(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion == newVersion) return;
    if (oldVersion < 2 && newVersion >= 2) await createV2(database);
    if (oldVersion < 3 && newVersion >= 3) await createV3(database);
    if (oldVersion < 4 && newVersion >= 4) {
      await createV4(database);
      if (oldVersion >= 3) await migrateV3RuntimeToV4(database);
    }
    if (oldVersion < 5 && newVersion >= 5) await createV5(database);
    if (oldVersion >= 1 && newVersion <= 5) return;
    throw StateError(
      'No database migration registered from $oldVersion to $newVersion.',
    );
  }

  /// Additive v2 schema. The v1 cycle/session/set tables deliberately remain
  /// untouched: they are the immutable execution record for legacy plans.
  static Future<void> createV2(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE program_definition_snapshots (
        id TEXT PRIMARY KEY,
        blueprint_id TEXT NOT NULL,
        blueprint_version INTEGER NOT NULL CHECK(blueprint_version > 0),
        snapshot_json TEXT NOT NULL,
        rule_provenance_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(blueprint_id, blueprint_version)
      )
    ''');
    await database.execute('''
      CREATE TABLE training_plans (
        id TEXT PRIMARY KEY,
        athlete_id TEXT NOT NULL,
        blueprint_id TEXT NOT NULL,
        blueprint_version INTEGER NOT NULL CHECK(blueprint_version > 0),
        definition_snapshot_id TEXT NOT NULL,
        macrocycle INTEGER NOT NULL CHECK(macrocycle > 0),
        status TEXT NOT NULL CHECK(status IN ('planned','active','complete','cancelled')),
        created_at TEXT NOT NULL,
        completed_at TEXT,
        FOREIGN KEY(athlete_id) REFERENCES athlete_profiles(id),
        FOREIGN KEY(definition_snapshot_id)
          REFERENCES program_definition_snapshots(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE training_blocks (
        id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        role TEXT NOT NULL CHECK(role IN ('prep','leader','seventhWeek','anchor')),
        template_id TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('planned','active','complete','cancelled')),
        started_at TEXT,
        completed_at TEXT,
        FOREIGN KEY(plan_id) REFERENCES training_plans(id) ON DELETE CASCADE,
        UNIQUE(plan_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE TABLE plan_training_cycles (
        id TEXT PRIMARY KEY,
        block_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        starts_on TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('planned','active','complete','cancelled')),
        FOREIGN KEY(block_id) REFERENCES training_blocks(id) ON DELETE CASCADE,
        UNIQUE(block_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE TABLE plan_training_sessions (
        id TEXT PRIMARY KEY,
        cycle_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        scheduled_for TEXT NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('planned','started','complete','cancelled')),
        started_at TEXT,
        completed_at TEXT,
        notes TEXT NOT NULL DEFAULT '',
        rest_until TEXT,
        FOREIGN KEY(cycle_id) REFERENCES plan_training_cycles(id) ON DELETE CASCADE,
        UNIQUE(cycle_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE TABLE session_blocks (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        kind TEXT NOT NULL,
        movement_id TEXT,
        rule_provenance_json TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES plan_training_sessions(id)
          ON DELETE CASCADE,
        UNIQUE(session_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE TABLE set_prescriptions (
        id TEXT PRIMARY KEY,
        session_block_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        training_max REAL NOT NULL CHECK(training_max > 0),
        percentage REAL,
        unrounded_load REAL NOT NULL CHECK(unrounded_load >= 0),
        rounding_increment REAL NOT NULL CHECK(rounding_increment > 0),
        prescribed_load REAL NOT NULL CHECK(prescribed_load >= 0),
        prescribed_reps INTEGER NOT NULL CHECK(prescribed_reps >= 0),
        prescription_json TEXT NOT NULL,
        rule_provenance_json TEXT NOT NULL,
        FOREIGN KEY(session_block_id) REFERENCES session_blocks(id)
          ON DELETE CASCADE,
        UNIQUE(session_block_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE TABLE set_performances (
        id TEXT PRIMARY KEY,
        prescription_id TEXT NOT NULL UNIQUE,
        result TEXT NOT NULL CHECK(result IN ('success','failure','skipped')),
        completed_reps INTEGER NOT NULL CHECK(completed_reps >= 0),
        actual_load REAL,
        notes TEXT NOT NULL DEFAULT '',
        recorded_at TEXT NOT NULL,
        FOREIGN KEY(prescription_id) REFERENCES set_prescriptions(id)
      )
    ''');
    await database.execute('''
      CREATE TABLE plan_events (
        id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        event_type TEXT NOT NULL,
        from_block_id TEXT,
        to_block_id TEXT,
        proposed_training_maxes_json TEXT,
        confirmed_training_maxes_json TEXT,
        rule_provenance_json TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        FOREIGN KEY(plan_id) REFERENCES training_plans(id) ON DELETE CASCADE,
        FOREIGN KEY(from_block_id) REFERENCES training_blocks(id),
        FOREIGN KEY(to_block_id) REFERENCES training_blocks(id),
        UNIQUE(plan_id, sequence)
      )
    ''');
    await database.execute(
      'CREATE INDEX training_blocks_plan_idx ON training_blocks(plan_id, sequence)',
    );
    await database.execute(
      'CREATE INDEX plan_sessions_cycle_idx ON plan_training_sessions(cycle_id, sequence)',
    );
    await database.execute(
      'CREATE INDEX prescriptions_block_idx ON set_prescriptions(session_block_id, sequence)',
    );
  }

  static Future<void> createV3(DatabaseExecutor database) async {
    await database.execute(
      '''CREATE TABLE workout_runtime_sessions (session_id TEXT PRIMARY KEY, status TEXT NOT NULL CHECK(status IN ('planned','started','completed','abandoned','skipped')), active_block_sequence INTEGER NOT NULL DEFAULT 0 CHECK(active_block_sequence >= 0), notes TEXT NOT NULL DEFAULT '', started_at TEXT, ended_at TEXT, updated_at TEXT NOT NULL, FOREIGN KEY(session_id) REFERENCES plan_training_sessions(id) ON DELETE CASCADE)''',
    );
    await database.execute(
      '''CREATE TABLE workout_runtime_blocks (session_block_id TEXT PRIMARY KEY, status TEXT NOT NULL CHECK(status IN ('pending','active','completed','skipped')), rest_until TEXT, updated_at TEXT NOT NULL, FOREIGN KEY(session_block_id) REFERENCES session_blocks(id) ON DELETE CASCADE)''',
    );
    await database.execute(
      '''CREATE TABLE workout_activities (id TEXT PRIMARY KEY, session_block_id TEXT NOT NULL, sequence INTEGER NOT NULL CHECK(sequence >= 0), label TEXT NOT NULL, target_type TEXT NOT NULL CHECK(target_type IN ('setsRepsLoad','totalReps','duration','distance','rounds','completion')), target_json TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('pending','success','failure','skipped')), result_json TEXT, updated_at TEXT NOT NULL, FOREIGN KEY(session_block_id) REFERENCES session_blocks(id) ON DELETE CASCADE, UNIQUE(session_block_id, sequence))''',
    );
    await database.execute(
      'CREATE INDEX workout_activities_block_idx ON workout_activities(session_block_id, sequence)',
    );
  }

  /// Canonical immutable execution state and ordered event journal.
  /// v3 tables remain readable for backup and migration compatibility.
  static Future<void> createV4(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE workout_executions (
        session_id TEXT PRIMARY KEY,
        state TEXT NOT NULL CHECK(state IN (
          'planned','ready','activeSet','resting','paused',
          'completed','abandoned','skipped'
        )),
        active_set_index INTEGER NOT NULL CHECK(active_set_index >= 0),
        rest_until TEXT,
        paused_from TEXT CHECK(paused_from IN ('activeSet','resting')),
        notes TEXT NOT NULL DEFAULT '',
        reversible_stack_json TEXT NOT NULL DEFAULT '[]',
        updated_at TEXT NOT NULL,
        ended_at TEXT,
        FOREIGN KEY(session_id) REFERENCES plan_training_sessions(id)
          ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE workout_set_outcomes (
        prescription_id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        status TEXT NOT NULL CHECK(status IN (
          'pending','success','failure','skipped'
        )),
        actual_repetitions INTEGER CHECK(actual_repetitions >= 0),
        actual_load REAL CHECK(actual_load >= 0),
        rpe REAL CHECK(rpe >= 1 AND rpe <= 10),
        notes TEXT NOT NULL DEFAULT '',
        recorded_at TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(prescription_id) REFERENCES set_prescriptions(id)
          ON DELETE CASCADE,
        FOREIGN KEY(session_id) REFERENCES plan_training_sessions(id)
          ON DELETE CASCADE,
        UNIQUE(session_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE TABLE workout_execution_events (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        event_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES workout_executions(session_id)
          ON DELETE CASCADE,
        UNIQUE(session_id, sequence)
      )
    ''');
    await database.execute(
      'CREATE INDEX workout_outcomes_session_idx ON workout_set_outcomes(session_id, sequence)',
    );
    await database.execute(
      'CREATE INDEX workout_events_session_idx ON workout_execution_events(session_id, sequence)',
    );
  }

  /// Additive Core v5 storage. Legacy tables remain intact and readable until
  /// backup compatibility and rollback have been proven for every old schema.
  static Future<void> createV5(DatabaseExecutor database) async {
    await database.execute(
      'ALTER TABLE training_plans ADD COLUMN source_edition TEXT',
    );
    await database.execute(
      'ALTER TABLE training_plans ADD COLUMN ruleset_generation TEXT',
    );
    await database.execute(
      'ALTER TABLE training_blocks ADD COLUMN block_type TEXT',
    );
    await database.execute(
      'ALTER TABLE training_blocks ADD COLUMN ruleset_role TEXT',
    );
    await database.execute(
      'ALTER TABLE training_blocks ADD COLUMN seventh_week_purpose TEXT',
    );
    await database.execute(
      'ALTER TABLE training_blocks ADD COLUMN programming_block_number INTEGER',
    );
    await database.execute(
      'ALTER TABLE plan_training_cycles ADD COLUMN programming_cycle_number INTEGER',
    );
    await database.execute(
      'ALTER TABLE plan_training_sessions ADD COLUMN programming_week_number INTEGER',
    );
    await database.execute(
      'ALTER TABLE plan_training_sessions ADD COLUMN session_position INTEGER',
    );
    await database.execute('''
      CREATE TABLE activity_prescriptions (
        id TEXT PRIMARY KEY,
        session_block_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        movement_or_activity_id TEXT NOT NULL,
        target_type TEXT NOT NULL CHECK(target_type IN (
          'setsRepsLoad','bodyweightSets','totalRepetitions','duration',
          'distance','rounds','completion','qualitative'
        )),
        target_json TEXT NOT NULL,
        prescription_kind TEXT NOT NULL,
        rule_id TEXT NOT NULL,
        source_edition TEXT NOT NULL,
        ruleset_generation TEXT NOT NULL,
        source_reference_json TEXT NOT NULL,
        calculated_load REAL CHECK(calculated_load >= 0),
        unrounded_load REAL CHECK(unrounded_load >= 0),
        rounding_increment REAL CHECK(rounding_increment > 0),
        FOREIGN KEY(session_block_id) REFERENCES session_blocks(id)
          ON DELETE CASCADE,
        UNIQUE(session_block_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE TABLE activity_results (
        prescription_id TEXT PRIMARY KEY,
        status TEXT NOT NULL CHECK(status IN (
          'pending','success','failure','skipped'
        )),
        actual_json TEXT NOT NULL,
        rpe REAL CHECK(rpe >= 1 AND rpe <= 10),
        notes TEXT NOT NULL DEFAULT '',
        recorded_at TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(prescription_id) REFERENCES activity_prescriptions(id)
          ON DELETE CASCADE
      )
    ''');
    await database.execute('''
      CREATE TABLE training_max_timeline (
        id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        movement_id TEXT NOT NULL,
        checkpoint_type TEXT NOT NULL,
        state TEXT NOT NULL CHECK(state IN ('previewed','confirmed','cancelled')),
        previous_training_max REAL NOT NULL CHECK(previous_training_max > 0),
        proposed_training_max REAL NOT NULL CHECK(proposed_training_max > 0),
        confirmed_training_max REAL CHECK(confirmed_training_max > 0),
        effective_after_session_id TEXT,
        reason TEXT NOT NULL,
        rule_id TEXT NOT NULL,
        source_reference_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        confirmed_at TEXT,
        FOREIGN KEY(plan_id) REFERENCES training_plans(id) ON DELETE CASCADE,
        FOREIGN KEY(effective_after_session_id)
          REFERENCES plan_training_sessions(id),
        UNIQUE(plan_id, sequence, movement_id)
      )
    ''');
    await database.execute('''
      CREATE TABLE plan_amendments (
        id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL,
        version INTEGER NOT NULL CHECK(version > 0),
        state TEXT NOT NULL CHECK(state IN ('previewed','applied','rejected')),
        reason TEXT NOT NULL,
        rule_id TEXT NOT NULL,
        before_snapshot_json TEXT NOT NULL,
        after_snapshot_json TEXT NOT NULL,
        diff_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        applied_at TEXT,
        FOREIGN KEY(plan_id) REFERENCES training_plans(id) ON DELETE CASCADE,
        UNIQUE(plan_id, version)
      )
    ''');
    await database.execute('''
      CREATE TABLE plan_transitions_v5 (
        id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        from_block_id TEXT,
        to_block_id TEXT,
        transition_type TEXT NOT NULL,
        rule_id TEXT NOT NULL,
        source_reference_json TEXT NOT NULL,
        occurred_at TEXT,
        FOREIGN KEY(plan_id) REFERENCES training_plans(id) ON DELETE CASCADE,
        FOREIGN KEY(from_block_id) REFERENCES training_blocks(id),
        FOREIGN KEY(to_block_id) REFERENCES training_blocks(id),
        UNIQUE(plan_id, sequence)
      )
    ''');
    await database.execute('''
      CREATE TABLE planned_events_v5 (
        id TEXT PRIMARY KEY,
        plan_id TEXT NOT NULL,
        sequence INTEGER NOT NULL CHECK(sequence >= 0),
        event_type TEXT NOT NULL,
        programming_week_number INTEGER,
        session_id TEXT,
        payload_json TEXT NOT NULL,
        rule_id TEXT NOT NULL,
        source_reference_json TEXT NOT NULL,
        scheduled_for TEXT,
        occurred_at TEXT,
        FOREIGN KEY(plan_id) REFERENCES training_plans(id) ON DELETE CASCADE,
        FOREIGN KEY(session_id) REFERENCES plan_training_sessions(id),
        UNIQUE(plan_id, sequence)
      )
    ''');
    await database.execute(
      'CREATE INDEX activity_prescriptions_block_idx '
      'ON activity_prescriptions(session_block_id, sequence)',
    );
    await database.execute(
      'CREATE INDEX tm_timeline_plan_idx '
      'ON training_max_timeline(plan_id, sequence)',
    );
    await database.execute(
      'CREATE INDEX plan_amendments_plan_idx '
      'ON plan_amendments(plan_id, version)',
    );
  }

  /// Converts the resumable v3 runtime into the single canonical v4 model.
  /// The old tables remain untouched so backup compatibility is preserved.
  static Future<void> migrateV3RuntimeToV4(DatabaseExecutor database) async {
    final sessions = await database.query('workout_runtime_sessions');
    for (final session in sessions) {
      final sessionId = session['session_id']! as String;
      final prescriptions = await database.rawQuery(
        '''SELECT sp.id, sp.sequence, sb.sequence AS block_sequence,
                  COALESCE(p.result, NULLIF(wa.status, 'pending')) AS result,
                  p.completed_reps, p.actual_load, p.notes, p.recorded_at,
                  wa.result_json, wa.updated_at AS activity_updated_at
           FROM set_prescriptions sp
           JOIN session_blocks sb ON sb.id = sp.session_block_id
           LEFT JOIN set_performances p ON p.prescription_id = sp.id
           LEFT JOIN workout_activities wa ON wa.id = sp.id
           WHERE sb.session_id = ?
           ORDER BY sb.sequence, sp.sequence''',
        [sessionId],
      );
      if (prescriptions.isEmpty) continue;
      final completedIndexes = <int>[];
      var firstPending = 0;
      var foundPending = false;
      for (final entry in prescriptions.indexed) {
        if (entry.$2['result'] == null && !foundPending) {
          firstPending = entry.$1;
          foundPending = true;
        } else if (entry.$2['result'] != null) {
          completedIndexes.add(entry.$1);
        }
      }
      if (!foundPending) firstPending = prescriptions.length - 1;
      final legacyState = session['status']! as String;
      final state = switch (legacyState) {
        'started' => 'activeSet',
        'completed' => 'completed',
        'abandoned' => 'abandoned',
        'skipped' => 'skipped',
        _ => 'planned',
      };
      final updatedAt = session['updated_at']! as String;
      await database.insert('workout_executions', {
        'session_id': sessionId,
        'state': state,
        'active_set_index': firstPending,
        'notes': session['notes'] ?? '',
        'reversible_stack_json': '[${completedIndexes.join(',')}]',
        'updated_at': updatedAt,
        'ended_at': session['ended_at'],
      });
      for (final entry in prescriptions.indexed) {
        final row = entry.$2;
        final activityResult = row['result_json'] == null
            ? const <String, Object?>{}
            : (jsonDecode(row['result_json']! as String)
                  as Map<String, Object?>);
        await database.insert('workout_set_outcomes', {
          'prescription_id': row['id'],
          'session_id': sessionId,
          'sequence': entry.$1,
          'status': row['result'] ?? 'pending',
          'actual_repetitions':
              row['completed_reps'] ?? activityResult['completedReps'],
          'actual_load': row['actual_load'] ?? activityResult['actualLoad'],
          'notes': row['notes'] ?? '',
          'recorded_at': row['recorded_at'] ?? row['activity_updated_at'],
          'updated_at':
              row['recorded_at'] ?? row['activity_updated_at'] ?? updatedAt,
        });
      }
      await database.insert('workout_execution_events', {
        'id': '$sessionId:event:0',
        'session_id': sessionId,
        'sequence': 0,
        'event_type': 'migratedFromV3',
        'payload_json': '{"sourceSchemaVersion":3}',
        'occurred_at': updatedAt,
      });
    }
  }
}
