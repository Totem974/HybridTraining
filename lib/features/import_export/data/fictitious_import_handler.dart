import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/import_export/domain/import_pipeline.dart';

class FictitiousImportHandler implements ImportFormatHandler {
  static const format = 'hybrid-training-fixture';
  static const schemaVersion = 1;

  @override
  bool recognizes(Map<String, Object?> document) =>
      document['format'] == format;

  @override
  ImportInspection inspect(Map<String, Object?> document) {
    final issues = <ImportIssue>[];
    if (document['schemaVersion'] != schemaVersion) {
      issues.add(
        const ImportIssue(
          path: r'$.schemaVersion',
          message: 'Only fictitious schema version 1 is supported.',
          severity: ImportSeverity.error,
        ),
      );
    }

    final payload = document['payload'];
    if (payload is! Map<String, Object?>) {
      issues.add(
        const ImportIssue(
          path: r'$.payload',
          message: 'A payload object is required.',
          severity: ImportSeverity.error,
        ),
      );
      return ImportInspection(candidate: null, issues: issues);
    }

    final allowed = {'profile', 'trainingMaxes'};
    for (final key in payload.keys.where((key) => !allowed.contains(key))) {
      issues.add(
        ImportIssue(
          path: r'$.payload.' + key,
          message: 'This field would be ignored.',
          severity: ImportSeverity.warning,
        ),
      );
    }
    if (payload['profile'] is! Map<String, Object?>) {
      issues.add(
        const ImportIssue(
          path: r'$.payload.profile',
          message: 'A profile object is required.',
          severity: ImportSeverity.error,
        ),
      );
    }
    if (payload['trainingMaxes'] is! List<Object?>) {
      issues.add(
        const ImportIssue(
          path: r'$.payload.trainingMaxes',
          message: 'A trainingMaxes array is required.',
          severity: ImportSeverity.error,
        ),
      );
    }

    return ImportInspection(
      candidate: ImportCandidate(
        sourceFormat: format,
        schemaVersion: schemaVersion,
        payload: payload,
      ),
      issues: issues,
    );
  }
}
