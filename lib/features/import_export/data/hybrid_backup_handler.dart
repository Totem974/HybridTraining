import 'package:hybrid_training/features/import_export/domain/backup_envelope.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/import_export/domain/import_pipeline.dart';

class HybridBackupHandler implements ImportFormatHandler {
  const HybridBackupHandler();

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
  };

  @override
  bool recognizes(Map<String, Object?> document) =>
      document['format'] == BackupEnvelope.format;

  @override
  ImportInspection inspect(Map<String, Object?> document) {
    final issues = <ImportIssue>[];
    if (document['schemaVersion'] != BackupEnvelope.schemaVersion) {
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
    for (final table in tables) {
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
    return ImportInspection(
      candidate: ImportCandidate(
        sourceFormat: BackupEnvelope.format,
        schemaVersion: BackupEnvelope.schemaVersion,
        payload: payload,
      ),
      issues: issues,
    );
  }
}
