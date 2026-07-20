import 'dart:convert';

import 'package:hybrid_training/features/import_export/domain/backup_envelope.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/import_export/domain/import_pipeline.dart';

class HybridBackupHandler implements ImportFormatHandler {
  const HybridBackupHandler();

  static const _legacyTableCount = 12;
  static const _version2TableCount = 21;
  static const _version3TableCount = 24;
  static const _version4TableCount = 28;

  static const tables = [
    'athlete_profiles',
    'exercises',
    'training_max_history',
    'gyms',
    'gym_bars',
    'gym_plates',
    'program_definitions',
    'training_cycles',
    'training_sessions',
    'training_sets',
    'personal_records',
    'app_metadata',
    'program_definition_snapshots',
    'training_plans',
    'training_blocks',
    'plan_training_cycles',
    'plan_training_sessions',
    'session_blocks',
    'set_prescriptions',
    'set_performances',
    'plan_events',
    'workout_runtime_sessions',
    'workout_runtime_blocks',
    'workout_activities',
    'import_runs',
    'workout_executions',
    'workout_set_outcomes',
    'workout_execution_events',
    'activity_prescriptions',
    'activity_results',
    'training_max_timeline',
    'plan_amendments',
    'plan_transitions_v5',
    'planned_events_v5',
  ];

  static const columns = <String, Set<String>>{
    'athlete_profiles': {
      'id',
      'display_name',
      'preferred_unit',
      'rounding_increment',
      'created_at',
      'updated_at',
      'deleted_at',
    },
    'exercises': {
      'id',
      'name_key',
      'category',
      'is_main_lift',
      'created_at',
      'deleted_at',
    },
    'training_max_history': {
      'id',
      'athlete_id',
      'exercise_id',
      'one_rep_max',
      'training_max',
      'unit',
      'effective_at',
    },
    'gyms': {
      'id',
      'athlete_id',
      'name',
      'is_default',
      'created_at',
      'deleted_at',
    },
    'gym_bars': {
      'id',
      'gym_id',
      'name',
      'weight',
      'unit',
      'quantity',
      'deleted_at',
    },
    'gym_plates': {'id', 'gym_id', 'weight', 'unit', 'quantity', 'deleted_at'},
    'program_definitions': {
      'id',
      'schema_version',
      'name_key',
      'definition_json',
      'created_at',
    },
    'training_cycles': {
      'id',
      'athlete_id',
      'program_definition_id',
      'program_definition_version',
      'starts_on',
      'status',
      'settings_json',
      'created_at',
      'deleted_at',
    },
    'training_sessions': {
      'id',
      'cycle_id',
      'scheduled_for',
      'started_at',
      'completed_at',
      'status',
      'notes',
    },
    'training_sets': {
      'id',
      'session_id',
      'lift_id',
      'sequence',
      'kind',
      'training_max',
      'percentage',
      'unrounded_load',
      'rounding_increment',
      'prescribed_load',
      'prescribed_reps',
      'performance_set',
      'result',
      'completed_reps',
      'notes',
    },
    'personal_records': {
      'id',
      'lift_id',
      'load',
      'repetitions',
      'unit',
      'achieved_at',
      'source_set_id',
    },
    'app_metadata': {'key', 'value'},
    'program_definition_snapshots': {
      'id',
      'blueprint_id',
      'blueprint_version',
      'snapshot_json',
      'rule_provenance_json',
      'created_at',
    },
    'training_plans': {
      'id',
      'athlete_id',
      'blueprint_id',
      'blueprint_version',
      'definition_snapshot_id',
      'macrocycle',
      'status',
      'created_at',
      'completed_at',
      'source_edition',
      'ruleset_generation',
    },
    'training_blocks': {
      'id',
      'plan_id',
      'sequence',
      'role',
      'template_id',
      'status',
      'started_at',
      'completed_at',
      'block_type',
      'ruleset_role',
      'seventh_week_purpose',
      'programming_block_number',
    },
    'plan_training_cycles': {
      'id',
      'block_id',
      'sequence',
      'starts_on',
      'status',
      'programming_cycle_number',
    },
    'plan_training_sessions': {
      'id',
      'cycle_id',
      'sequence',
      'scheduled_for',
      'status',
      'started_at',
      'completed_at',
      'notes',
      'rest_until',
      'programming_week_number',
      'session_position',
    },
    'session_blocks': {
      'id',
      'session_id',
      'sequence',
      'kind',
      'movement_id',
      'rule_provenance_json',
    },
    'set_prescriptions': {
      'id',
      'session_block_id',
      'sequence',
      'training_max',
      'percentage',
      'unrounded_load',
      'rounding_increment',
      'prescribed_load',
      'prescribed_reps',
      'prescription_json',
      'rule_provenance_json',
    },
    'set_performances': {
      'id',
      'prescription_id',
      'result',
      'completed_reps',
      'actual_load',
      'notes',
      'recorded_at',
    },
    'plan_events': {
      'id',
      'plan_id',
      'sequence',
      'event_type',
      'from_block_id',
      'to_block_id',
      'proposed_training_maxes_json',
      'confirmed_training_maxes_json',
      'rule_provenance_json',
      'occurred_at',
    },
    'workout_runtime_sessions': {
      'session_id',
      'status',
      'active_block_sequence',
      'notes',
      'started_at',
      'ended_at',
      'updated_at',
    },
    'workout_runtime_blocks': {
      'session_block_id',
      'status',
      'rest_until',
      'updated_at',
    },
    'workout_activities': {
      'id',
      'session_block_id',
      'sequence',
      'label',
      'target_type',
      'target_json',
      'status',
      'result_json',
      'updated_at',
    },
    'import_runs': {
      'id',
      'source_format',
      'source_schema_version',
      'source_digest',
      'dry_run',
      'status',
      'report_json',
      'created_at',
    },
    'workout_executions': {
      'session_id',
      'state',
      'active_set_index',
      'rest_until',
      'paused_from',
      'notes',
      'reversible_stack_json',
      'updated_at',
      'ended_at',
    },
    'workout_set_outcomes': {
      'prescription_id',
      'session_id',
      'sequence',
      'status',
      'actual_repetitions',
      'actual_load',
      'rpe',
      'notes',
      'recorded_at',
      'updated_at',
    },
    'workout_execution_events': {
      'id',
      'session_id',
      'sequence',
      'event_type',
      'payload_json',
      'occurred_at',
    },
    'activity_prescriptions': {
      'id',
      'session_block_id',
      'sequence',
      'movement_or_activity_id',
      'target_type',
      'target_json',
      'prescription_kind',
      'rule_id',
      'source_edition',
      'ruleset_generation',
      'source_reference_json',
      'calculated_load',
      'unrounded_load',
      'rounding_increment',
    },
    'activity_results': {
      'prescription_id',
      'status',
      'actual_json',
      'rpe',
      'notes',
      'recorded_at',
      'updated_at',
    },
    'training_max_timeline': {
      'id',
      'plan_id',
      'sequence',
      'movement_id',
      'checkpoint_type',
      'state',
      'previous_training_max',
      'proposed_training_max',
      'confirmed_training_max',
      'effective_after_session_id',
      'reason',
      'rule_id',
      'source_reference_json',
      'created_at',
      'confirmed_at',
    },
    'plan_amendments': {
      'id',
      'plan_id',
      'version',
      'state',
      'reason',
      'rule_id',
      'before_snapshot_json',
      'after_snapshot_json',
      'diff_json',
      'created_at',
      'applied_at',
    },
    'plan_transitions_v5': {
      'id',
      'plan_id',
      'sequence',
      'from_block_id',
      'to_block_id',
      'transition_type',
      'rule_id',
      'source_reference_json',
      'occurred_at',
    },
    'planned_events_v5': {
      'id',
      'plan_id',
      'sequence',
      'event_type',
      'programming_week_number',
      'session_id',
      'payload_json',
      'rule_id',
      'source_reference_json',
      'scheduled_for',
      'occurred_at',
    },
  };

  static const requiredColumns = <String, Set<String>>{
    'athlete_profiles': {'id', 'display_name', 'preferred_unit'},
    'exercises': {'id', 'name_key'},
    'training_max_history': {'id', 'athlete_id', 'exercise_id'},
    'gyms': {'id', 'athlete_id', 'name'},
    'gym_bars': {'id', 'gym_id', 'name'},
    'gym_plates': {'id', 'gym_id', 'weight'},
    'program_definitions': {'id', 'schema_version', 'definition_json'},
    'training_cycles': {'id', 'athlete_id', 'program_definition_id'},
    'training_sessions': {'id', 'cycle_id', 'scheduled_for'},
    'training_sets': {'id', 'session_id', 'lift_id', 'sequence'},
    'personal_records': {'id', 'lift_id', 'load', 'repetitions'},
    'app_metadata': {'key', 'value'},
    'program_definition_snapshots': {
      'id',
      'blueprint_id',
      'blueprint_version',
      'snapshot_json',
    },
    'training_plans': {'id', 'athlete_id', 'definition_snapshot_id'},
    'training_blocks': {'id', 'plan_id', 'sequence', 'role'},
    'plan_training_cycles': {'id', 'block_id', 'sequence'},
    'plan_training_sessions': {'id', 'cycle_id', 'sequence'},
    'session_blocks': {'id', 'session_id', 'sequence', 'kind'},
    'set_prescriptions': {'id', 'session_block_id', 'sequence'},
    'set_performances': {'id', 'prescription_id', 'result'},
    'plan_events': {'id', 'plan_id', 'sequence', 'event_type'},
    'workout_runtime_sessions': {'session_id', 'status', 'updated_at'},
    'workout_runtime_blocks': {'session_block_id', 'status', 'updated_at'},
    'workout_activities': {
      'id',
      'session_block_id',
      'sequence',
      'label',
      'target_type',
      'target_json',
      'status',
      'updated_at',
    },
    'import_runs': {
      'id',
      'source_format',
      'source_digest',
      'dry_run',
      'status',
      'report_json',
      'created_at',
    },
    'workout_executions': {
      'session_id',
      'state',
      'active_set_index',
      'reversible_stack_json',
      'updated_at',
    },
    'workout_set_outcomes': {
      'prescription_id',
      'session_id',
      'sequence',
      'status',
      'updated_at',
    },
    'workout_execution_events': {
      'id',
      'session_id',
      'sequence',
      'event_type',
      'payload_json',
      'occurred_at',
    },
    'activity_prescriptions': {
      'id',
      'session_block_id',
      'sequence',
      'movement_or_activity_id',
      'target_type',
      'target_json',
      'prescription_kind',
      'rule_id',
      'source_edition',
      'ruleset_generation',
      'source_reference_json',
    },
    'activity_results': {
      'prescription_id',
      'status',
      'actual_json',
      'updated_at',
    },
    'training_max_timeline': {
      'id',
      'plan_id',
      'sequence',
      'movement_id',
      'checkpoint_type',
      'state',
      'previous_training_max',
      'proposed_training_max',
      'reason',
      'rule_id',
      'source_reference_json',
      'created_at',
    },
    'plan_amendments': {
      'id',
      'plan_id',
      'version',
      'state',
      'reason',
      'rule_id',
      'before_snapshot_json',
      'after_snapshot_json',
      'diff_json',
      'created_at',
    },
    'plan_transitions_v5': {
      'id',
      'plan_id',
      'sequence',
      'transition_type',
      'rule_id',
      'source_reference_json',
    },
    'planned_events_v5': {
      'id',
      'plan_id',
      'sequence',
      'event_type',
      'payload_json',
      'rule_id',
      'source_reference_json',
    },
  };

  @override
  bool recognizes(Map<String, Object?> document) =>
      document['format'] == BackupEnvelope.format;

  @override
  ImportInspection inspect(Map<String, Object?> document) {
    final issues = <ImportIssue>[];
    final sourceVersion = document['schemaVersion'];
    if (sourceVersion != 1 &&
        sourceVersion != 2 &&
        sourceVersion != 3 &&
        sourceVersion != 4 &&
        sourceVersion != BackupEnvelope.schemaVersion) {
      issues.add(
        const ImportIssue(
          path: r'$.schemaVersion',
          message: 'Unsupported backup schema version.',
          severity: ImportSeverity.error,
        ),
      );
    }
    final payload = document['payload'];
    if (payload is! Map<String, Object?>) {
      return ImportInspection(
        candidate: null,
        issues: const [
          ImportIssue(
            path: r'$.payload',
            message: 'A payload object is required.',
            severity: ImportSeverity.error,
          ),
        ],
      );
    }
    for (final key in payload.keys.where((key) => !tables.contains(key))) {
      issues.add(
        ImportIssue(
          path: r'$.payload.' + key,
          message: 'Unknown table would be ignored.',
          severity: ImportSeverity.warning,
        ),
      );
    }
    final normalizedPayload = Map<String, Object?>.from(payload);
    final expectedTableCount = switch (sourceVersion) {
      1 => _legacyTableCount,
      2 => _version2TableCount,
      3 => _version3TableCount,
      4 => _version4TableCount,
      _ => tables.length,
    };
    final expectedTables = tables.take(expectedTableCount);
    for (final table in expectedTables) {
      final rows = payload[table];
      if (rows is! List<Object?>) {
        issues.add(
          ImportIssue(
            path: r'$.payload.' + table,
            message: 'A table array is required.',
            severity: ImportSeverity.error,
          ),
        );
        continue;
      }
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        if (row is! Map<String, Object?>) {
          issues.add(
            ImportIssue(
              path: '\$.payload.$table[$index]',
              message: 'Every table row must be an object.',
              severity: ImportSeverity.error,
            ),
          );
          continue;
        }
        final unknown = row.keys.where((key) => !columns[table]!.contains(key));
        for (final key in unknown) {
          issues.add(
            ImportIssue(
              path: '\$.payload.$table[$index].$key',
              message: 'Unknown column.',
              severity: ImportSeverity.error,
            ),
          );
        }
        final missing = requiredColumns[table]!.where(
          (column) => !row.containsKey(column),
        );
        for (final column in missing) {
          issues.add(
            ImportIssue(
              path: '\$.payload.$table[$index].$column',
              message: 'Required column is missing.',
              severity: ImportSeverity.error,
            ),
          );
        }
      }
    }
    if (sourceVersion == 1 ||
        sourceVersion == 2 ||
        sourceVersion == 3 ||
        sourceVersion == 4) {
      for (final table in tables.skip(expectedTableCount)) {
        normalizedPayload[table] = <Object?>[];
      }
    }
    if (!issues.any((issue) => issue.severity == ImportSeverity.error)) {
      _validateUsableLegacySnapshot(normalizedPayload, issues);
      _quarantineUnsourcedLegacyPlans(normalizedPayload, issues);
      _validateExecutableProvenance(normalizedPayload, issues);
    }
    return ImportInspection(
      candidate: ImportCandidate(
        sourceFormat: BackupEnvelope.format,
        schemaVersion: sourceVersion is int ? sourceVersion : 0,
        payload: normalizedPayload,
      ),
      issues: issues,
    );
  }

  static void _validateExecutableProvenance(
    Map<String, Object?> payload,
    List<ImportIssue> issues,
  ) {
    final activePlans = _rows(payload, 'training_plans')
        .where((row) => const {'planned', 'active'}.contains(row['status']))
        .toList(growable: false);
    if (activePlans.isEmpty) return;

    final activePlanIds = activePlans.map((row) => row['id']).toSet();
    final snapshotIds = activePlans
        .map((row) => row['definition_snapshot_id'])
        .toSet();
    for (final entry in activePlans.indexed) {
      if (!const {
            'original',
            'powerlifting',
            'beyond',
            'forever',
          }.contains(entry.$2['source_edition']) ||
          !const {
            'original',
            'powerlifting',
            'beyond',
            'forever',
          }.contains(entry.$2['ruleset_generation'])) {
        _provenanceIssue('\$.payload.training_plans[${entry.$1}]', issues);
      }
    }
    final blockIds = _rows(payload, 'training_blocks')
        .where((row) => activePlanIds.contains(row['plan_id']))
        .map((row) => row['id'])
        .toSet();
    final cycleIds = _rows(payload, 'plan_training_cycles')
        .where((row) => blockIds.contains(row['block_id']))
        .map((row) => row['id'])
        .toSet();
    final executableSessionIds = _rows(payload, 'plan_training_sessions')
        .where(
          (row) =>
              cycleIds.contains(row['cycle_id']) &&
              !const {'complete', 'cancelled'}.contains(row['status']),
        )
        .map((row) => row['id'])
        .toSet();
    final executableBlocks = _indexedRows(payload, 'session_blocks')
        .where((entry) => executableSessionIds.contains(entry.$2['session_id']))
        .toList(growable: false);
    final executableBlockIds = executableBlocks
        .map((entry) => entry.$2['id'])
        .toSet();

    final activeSnapshots = _indexedRows(
      payload,
      'program_definition_snapshots',
    ).where((entry) => snapshotIds.contains(entry.$2['id'])).toList();
    if (activeSnapshots.map((entry) => entry.$2['id']).toSet().length !=
        snapshotIds.length) {
      _provenanceIssue(r'$.payload.program_definition_snapshots', issues);
    }
    for (final entry in activeSnapshots) {
      _requireProvenanceJson(
        entry.$2['rule_provenance_json'],
        '\$.payload.program_definition_snapshots[${entry.$1}].rule_provenance_json',
        issues,
        allowList: true,
      );
      _rejectNeedsReviewJson(
        entry.$2['snapshot_json'],
        '\$.payload.program_definition_snapshots[${entry.$1}].snapshot_json',
        issues,
      );
    }
    for (final entry in executableBlocks) {
      _requireProvenanceJson(
        entry.$2['rule_provenance_json'],
        '\$.payload.session_blocks[${entry.$1}].rule_provenance_json',
        issues,
      );
    }
    for (final entry in _indexedRows(payload, 'set_prescriptions')) {
      if (!executableBlockIds.contains(entry.$2['session_block_id'])) continue;
      _requireProvenanceJson(
        entry.$2['rule_provenance_json'],
        '\$.payload.set_prescriptions[${entry.$1}].rule_provenance_json',
        issues,
      );
      _rejectNeedsReviewJson(
        entry.$2['prescription_json'],
        '\$.payload.set_prescriptions[${entry.$1}].prescription_json',
        issues,
      );
    }
    for (final entry in _indexedRows(payload, 'activity_prescriptions')) {
      if (!executableBlockIds.contains(entry.$2['session_block_id'])) continue;
      _requireSourcedRule(entry, 'activity_prescriptions', issues);
      _rejectNeedsReviewJson(
        entry.$2['target_json'],
        '\$.payload.activity_prescriptions[${entry.$1}].target_json',
        issues,
      );
      if (!const {
            'original',
            'powerlifting',
            'beyond',
            'forever',
          }.contains(entry.$2['source_edition']) ||
          !const {
            'original',
            'powerlifting',
            'beyond',
            'forever',
          }.contains(entry.$2['ruleset_generation'])) {
        _provenanceIssue(
          '\$.payload.activity_prescriptions[${entry.$1}]',
          issues,
        );
      }
    }
    for (final table in const [
      'training_max_timeline',
      'plan_transitions_v5',
      'planned_events_v5',
    ]) {
      for (final entry in _indexedRows(payload, table)) {
        if (!activePlanIds.contains(entry.$2['plan_id'])) continue;
        _requireSourcedRule(entry, table, issues);
        if (table == 'planned_events_v5') {
          _rejectNeedsReviewJson(
            entry.$2['payload_json'],
            '\$.payload.planned_events_v5[${entry.$1}].payload_json',
            issues,
          );
        }
      }
    }
  }

  static void _quarantineUnsourcedLegacyPlans(
    Map<String, Object?> payload,
    List<ImportIssue> issues,
  ) {
    final candidatePlans = _rows(
      payload,
      'training_plans',
    ).where((row) => const {'planned', 'active'}.contains(row['status']));
    for (final plan in candidatePlans) {
      final planId = plan['id'];
      final snapshots = _rows(
        payload,
        'program_definition_snapshots',
      ).where((row) => row['id'] == plan['definition_snapshot_id']);
      final missingLegacyProvenance =
          plan['source_edition'] == null ||
          plan['ruleset_generation'] == null ||
          snapshots.isEmpty ||
          snapshots.any((row) => row['rule_provenance_json'] == null);
      if (!missingLegacyProvenance) continue;

      final blockIds = _rows(payload, 'training_blocks')
          .where((row) => row['plan_id'] == planId)
          .map((row) => row['id'])
          .toSet();
      final cycleIds = _rows(payload, 'plan_training_cycles')
          .where((row) => blockIds.contains(row['block_id']))
          .map((row) => row['id'])
          .toSet();
      final sessionIds = _rows(payload, 'plan_training_sessions')
          .where((row) => cycleIds.contains(row['cycle_id']))
          .map((row) => row['id'])
          .toSet();
      final sessionBlockIds = _rows(payload, 'session_blocks')
          .where((row) => sessionIds.contains(row['session_id']))
          .map((row) => row['id'])
          .toSet();

      plan['status'] = 'cancelled';
      for (final row in _rows(payload, 'training_blocks')) {
        if (blockIds.contains(row['id']) &&
            const {'planned', 'active'}.contains(row['status'])) {
          row['status'] = 'cancelled';
        }
      }
      for (final row in _rows(payload, 'plan_training_cycles')) {
        if (cycleIds.contains(row['id']) &&
            const {'planned', 'active'}.contains(row['status'])) {
          row['status'] = 'cancelled';
        }
      }
      for (final row in _rows(payload, 'plan_training_sessions')) {
        if (sessionIds.contains(row['id']) &&
            const {'planned', 'started'}.contains(row['status'])) {
          row['status'] = 'cancelled';
        }
      }
      for (final row in _rows(payload, 'workout_runtime_sessions')) {
        if (sessionIds.contains(row['session_id']) &&
            !const {
              'completed',
              'abandoned',
              'skipped',
            }.contains(row['status'])) {
          row['status'] = 'abandoned';
        }
      }
      for (final row in _rows(payload, 'workout_runtime_blocks')) {
        if (sessionBlockIds.contains(row['session_block_id']) &&
            const {'pending', 'active'}.contains(row['status'])) {
          row['status'] = 'skipped';
        }
      }
      for (final row in _rows(payload, 'workout_executions')) {
        if (sessionIds.contains(row['session_id']) &&
            !const {
              'completed',
              'abandoned',
              'skipped',
            }.contains(row['state'])) {
          row['state'] = 'abandoned';
          row['rest_until'] = null;
          row['paused_from'] = null;
          row['reversible_stack_json'] = '[]';
        }
      }
      for (final row in _rows(payload, 'training_max_timeline')) {
        if (row['plan_id'] == planId && row['state'] == 'previewed') {
          row['state'] = 'cancelled';
        }
      }
      issues.add(
        ImportIssue(
          path: r'$.payload.training_plans',
          message:
              'A legacy plan without executable provenance was preserved in quarantine and cannot be resumed.',
          severity: ImportSeverity.warning,
        ),
      );
    }
  }

  static Iterable<(int, Map<String, Object?>)> _indexedRows(
    Map<String, Object?> payload,
    String table,
  ) sync* {
    final rows = payload[table] as List<Object?>? ?? const [];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row is Map<String, Object?>) yield (index, row);
    }
  }

  static void _requireSourcedRule(
    (int, Map<String, Object?>) entry,
    String table,
    List<ImportIssue> issues,
  ) {
    final ruleId = entry.$2['rule_id'];
    if (ruleId is! String || ruleId.trim().isEmpty || _isNeedsReview(ruleId)) {
      _provenanceIssue('\$.payload.$table[${entry.$1}].rule_id', issues);
    }
    _requireProvenanceJson(
      entry.$2['source_reference_json'],
      '\$.payload.$table[${entry.$1}].source_reference_json',
      issues,
    );
  }

  static void _requireProvenanceJson(
    Object? encoded,
    String path,
    List<ImportIssue> issues, {
    bool allowList = false,
  }) {
    Object? decoded;
    try {
      decoded = encoded is String ? jsonDecode(encoded) : null;
    } on FormatException {
      _provenanceIssue(path, issues);
      return;
    }
    final sources = allowList && decoded is List<Object?>
        ? decoded
        : <Object?>[decoded];
    if (sources.isEmpty ||
        sources.any((source) => !_isSourcedReference(source))) {
      _provenanceIssue(path, issues);
    }
  }

  static bool _isSourcedReference(Object? value) {
    if (value is! Map<String, Object?>) return false;
    final document = value['document'];
    final location = value['location'];
    return document is String &&
        document.trim().isNotEmpty &&
        !_isNeedsReview(document) &&
        const {
          '5/3/1 Original — Second Edition',
          '5/3/1 — Second Edition',
          '5/3/1 for Powerlifting',
          '5/3/1 Forever',
          'Beyond 5/3/1',
          'Core v5 reviewed historical compatibility contract',
          'TM-PROG-001',
          'forever-original-fsl-v1',
          'forever-program-catalog.md',
        }.contains(document) &&
        location is String &&
        location.trim().isNotEmpty &&
        !_isNeedsReview(location);
  }

  static void _rejectNeedsReviewJson(
    Object? encoded,
    String path,
    List<ImportIssue> issues,
  ) {
    try {
      final decoded = encoded is String ? jsonDecode(encoded) : null;
      if (decoded == null || _containsNeedsReview(decoded)) {
        _provenanceIssue(path, issues);
      }
    } on FormatException {
      _provenanceIssue(path, issues);
    }
  }

  static bool _containsNeedsReview(Object? value) => switch (value) {
    String text => _isNeedsReview(text),
    List<Object?> values => values.any(_containsNeedsReview),
    Map<String, Object?> values => values.entries.any(
      (entry) => _isNeedsReview(entry.key) || _containsNeedsReview(entry.value),
    ),
    _ => false,
  };

  static bool _isNeedsReview(String value) =>
      value.toUpperCase().contains('NEEDS_REVIEW');

  static void _provenanceIssue(String path, List<ImportIssue> issues) {
    issues.add(
      ImportIssue(
        path: path,
        message: 'Executable rules require valid reviewed source provenance.',
        severity: ImportSeverity.error,
      ),
    );
  }

  static void _validateUsableLegacySnapshot(
    Map<String, Object?> payload,
    List<ImportIssue> issues,
  ) {
    final profiles = _rows(payload, 'athlete_profiles');
    if (profiles.isEmpty) return;
    final definitions = _rows(payload, 'program_definitions');
    final cycles = _rows(
      payload,
      'training_cycles',
    ).where((row) => row['status'] == 'active').toList(growable: false);
    if (cycles.isEmpty) {
      issues.add(
        const ImportIssue(
          path: r'$.payload.training_cycles',
          message: 'A profile requires an active compatible training cycle.',
          severity: ImportSeverity.error,
        ),
      );
      return;
    }
    final definitionIds = definitions.map((row) => row['id']).toSet();
    if (cycles.any(
      (cycle) => !definitionIds.contains(cycle['program_definition_id']),
    )) {
      issues.add(
        const ImportIssue(
          path: r'$.payload.program_definitions',
          message: 'The active cycle requires its program definition.',
          severity: ImportSeverity.error,
        ),
      );
    }
    final cycleIds = cycles.map((row) => row['id']).toSet();
    final sessions = _rows(payload, 'training_sessions')
        .where((row) => cycleIds.contains(row['cycle_id']))
        .toList(growable: false);
    if (sessions.isEmpty) {
      issues.add(
        const ImportIssue(
          path: r'$.payload.training_sessions',
          message: 'The active cycle requires at least one session.',
          severity: ImportSeverity.error,
        ),
      );
      return;
    }
    final sessionIds = sessions.map((row) => row['id']).toSet();
    final setSessionIds = _rows(
      payload,
      'training_sets',
    ).map((row) => row['session_id']).toSet();
    if (sessionIds.any((id) => !setSessionIds.contains(id))) {
      issues.add(
        const ImportIssue(
          path: r'$.payload.training_sets',
          message: 'Every session in the active cycle requires a set.',
          severity: ImportSeverity.error,
        ),
      );
    }
  }

  static List<Map<String, Object?>> _rows(
    Map<String, Object?> payload,
    String table,
  ) =>
      (payload[table] as List<Object?>?)
          ?.whereType<Map<String, Object?>>()
          .toList(growable: false) ??
      const [];
}
