import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_training/features/import_export/data/fictitious_import_handler.dart';
import 'package:hybrid_training/features/import_export/domain/backup_envelope.dart';
import 'package:hybrid_training/features/import_export/domain/import_models.dart';
import 'package:hybrid_training/features/import_export/domain/import_pipeline.dart';

void main() {
  test('new backup envelope has an explicit version and UTC timestamp', () {
    final encoded = BackupEnvelope(
      exportedAt: DateTime.utc(2026, 7, 17, 12),
      appVersion: '0.1.0',
      payload: const {'profiles': <Object?>[]},
    ).encode();
    final document = jsonDecode(encoded) as Map<String, Object?>;

    expect(document['format'], BackupEnvelope.format);
    expect(document['schemaVersion'], 1);
    expect(document['exportedAt'], '2026-07-17T12:00:00.000Z');
  });

  test('dry-run reports ignored fields and never writes', () async {
    final target = _RecordingTarget();
    final pipeline = ImportPipeline(
      handlers: [FictitiousImportHandler()],
      target: target,
    );
    final fixture = File(
      'test/fixtures/fictitious_import_v1.json',
    ).readAsStringSync();

    final report = await pipeline.run(fixture, dryRun: true);

    expect(report.applied, isFalse);
    expect(target.applied, isEmpty);
    expect(
      report.issues,
      contains(
        isA<ImportIssue>().having(
          (issue) => issue.path,
          'path',
          r'$.payload.futureField',
        ),
      ),
    );
  });

  test('valid fixture is handed to one atomic target operation', () async {
    final target = _RecordingTarget();
    final pipeline = ImportPipeline(
      handlers: [FictitiousImportHandler()],
      target: target,
    );
    final fixture = File(
      'test/fixtures/fictitious_import_v1.json',
    ).readAsStringSync();

    final report = await pipeline.run(fixture, dryRun: false);

    expect(report.applied, isTrue);
    expect(target.applied, hasLength(1));
  });

  test('unknown formats fail without writing', () async {
    final target = _RecordingTarget();
    final pipeline = ImportPipeline(
      handlers: [FictitiousImportHandler()],
      target: target,
    );

    final report = await pipeline.run(
      '{"format":"legacy-unknown","schemaVersion":1}',
      dryRun: false,
    );

    expect(report.applied, isFalse);
    expect(target.applied, isEmpty);
    expect(report.issues.single.severity, ImportSeverity.error);
  });
}

class _RecordingTarget implements AtomicImportTarget {
  final applied = <ImportCandidate>[];

  @override
  Future<void> applyAtomically(ImportCandidate candidate) async {
    applied.add(candidate);
  }
}
