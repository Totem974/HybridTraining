import 'dart:convert';

import 'package:hybrid_training/features/import_export/domain/import_models.dart';

abstract interface class ImportFormatHandler {
  bool recognizes(Map<String, Object?> document);

  ImportInspection inspect(Map<String, Object?> document);
}

abstract interface class AtomicImportTarget {
  Future<void> applyAtomically(ImportCandidate candidate);
}

class ImportPipeline {
  const ImportPipeline({required this.handlers, required this.target});

  final List<ImportFormatHandler> handlers;
  final AtomicImportTarget target;

  Future<ImportReport> run(String source, {required bool dryRun}) async {
    final document = _decode(source);
    if (document == null) {
      return ImportReport(
        dryRun: dryRun,
        applied: false,
        sourceFormat: null,
        issues: const [
          ImportIssue(
            path: r'$',
            message: 'The source is not a JSON object.',
            severity: ImportSeverity.error,
          ),
        ],
      );
    }

    final handler = handlers
        .where((item) => item.recognizes(document))
        .firstOrNull;
    if (handler == null) {
      return ImportReport(
        dryRun: dryRun,
        applied: false,
        sourceFormat: document['format'] as String?,
        issues: const [
          ImportIssue(
            path: r'$.format',
            message: 'No installed importer recognizes this format.',
            severity: ImportSeverity.error,
          ),
        ],
      );
    }

    final inspection = handler.inspect(document);
    if (!inspection.canImport || dryRun) {
      return ImportReport(
        dryRun: dryRun,
        applied: false,
        sourceFormat: inspection.candidate?.sourceFormat,
        issues: inspection.issues,
      );
    }

    await target.applyAtomically(inspection.candidate!);
    return ImportReport(
      dryRun: false,
      applied: true,
      sourceFormat: inspection.candidate!.sourceFormat,
      issues: inspection.issues,
    );
  }

  Map<String, Object?>? _decode(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
